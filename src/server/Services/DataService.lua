--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Rules = require(Shared.Domain.Rules)
local Profile = require(Shared.Domain.Profile)
local Catalog = require(Shared.Config.EggConfig)
local Data = {}
Data.__index = Data
local LEASE_SECONDS = 180
local FAILURE_LIMIT = 110
function Data.new()
    local self = setmetatable({}, Data)
    self.Session = game.JobId .. HttpService:GenerateGUID(false)
    self.Entries = {}
    self.Loading = {}
    -- Studio defaults to isolated volatile sessions. Opt in using a server attribute, on a TEST place.
    self.Memory = RunService:IsStudio() and workspace:GetAttribute("EnableStudioDataStore") ~= true
    if self.Memory then
        warn("EggHeist: Studio memory mode; progress is NOT saved between play sessions")
    else
        -- Merely obtaining a store can fail for an unpublished Studio file.
        -- Local play does not need any DataStore API or publication permission.
        self.Store = DataStoreService:GetDataStore("EggHeist_Profiles_v1")
    end
    return self
end
function Data:load(player)
    if self.Entries[player] then return self.Entries[player].Profile end
    -- PlayerAdded and the initial GetPlayers sweep may observe the same player.
    if self.Loading[player] then return nil end
    self.Loading[player] = true
    local lease = self.Session .. ":" .. HttpService:GenerateGUID(false)
    if self.Memory then
        local p = Rules.newProfile(os.time())
        self.Entries[player] = {Profile=p, Busy=false, LastSave=os.time(), Lease=lease, LeaseExpires=math.huge}
        self.Loading[player] = nil
        return p
    end
    for attempt=1,3 do
        local ok, result = pcall(function()
            return self.Store:UpdateAsync("u_"..player.UserId, function(record)
                if record and record.Session ~= lease and (record.Expires or 0) > os.time() then return nil end
                local p = if record then record.Profile else Rules.newProfile(os.time())
                if not Profile.validate(p,Catalog) then error("Unsupported/corrupt profile; refusing replacement") end
                return {Profile=p, Session=lease, Expires=os.time()+LEASE_SECONDS}
            end)
        end)
        -- UpdateAsync may rerun or cancel its callback. Only its committed result
        -- establishes ownership; a callback's local side effects do not.
        if ok and result and result.Session == lease then
            local loaded = Profile.copy(result.Profile)
            self.Entries[player] = {Profile=loaded, Busy=false, LastSave=os.time(), Lease=lease, LeaseExpires=result.Expires}
            self.Loading[player] = nil
            return loaded
        end
        warn("Profile load failed", player.UserId, attempt, if ok then "session locked" else tostring(result))
        if attempt<3 then task.wait(attempt) end
    end
    self.Loading[player] = nil
    return nil
end
function Data:save(player, release: boolean?)
    local entry = self.Entries[player]
    if not entry or entry.Released or entry.Lost then return false end
    -- If a leave races a slow autosave, that writer must still release the final
    -- profile even when the caller's bounded wait runs out.
    if release then entry.ReleaseRequested=true end
    local deadline = os.clock()+12
    while entry.Busy and os.clock()<deadline do task.wait(0.1) end
    if entry.Busy or entry.Released or entry.Lost or self.Entries[player]~=entry then return false end
    entry.Busy = true
    if self.Memory then
        entry.Busy = false
        if release then entry.Released=true; self.Entries[player] = nil end
        return true
    end
    local snapshot = Profile.copy(entry.Profile)
    if not Profile.validate(snapshot,Catalog) then
        entry.Busy=false
        entry.Lost=true
        warn("Invalid in-memory profile refused",player.UserId)
        player:Kick("Обнаружена ошибка данных. Предыдущее сохранение защищено.")
        return false
    end
    local saved = false
    local savedExpires
    local lostLease = false
    local writeId = HttpService:GenerateGUID(false)
    for attempt=1,3 do
        local ok, result = pcall(function()
            return self.Store:UpdateAsync("u_"..player.UserId, function(record)
                if not record or record.Session ~= entry.Lease or (record.Expires or 0)<=os.time() then return nil end
                return {Profile=snapshot, Session=if release then nil else entry.Lease,
                    Expires=if release then 0 else os.time()+LEASE_SECONDS, WriteId=writeId}
            end)
        end)
        saved = ok and result~=nil and result.WriteId==writeId
        if saved then savedExpires=result.Expires; break end
        if ok then lostLease=true; break end
        if attempt<3 then task.wait(attempt) end
    end
    entry.Busy = false
    if saved then entry.LastSave = os.time(); entry.LeaseExpires=savedExpires end
    if release then entry.Released=true; self.Entries[player] = nil
    elseif lostLease or (not saved and os.time()-entry.LastSave > FAILURE_LIMIT) then
        entry.Lost=true
        player:Kick("Сохранение временно недоступно. Перезайди позже — старые данные защищены.")
    end
    if not release and entry.ReleaseRequested and not entry.Lost then return self:save(player,true) end
    return saved
end
function Data:isActive(player)
    local entry = self.Entries[player]
    -- A request can be stuck in flight. Stop gameplay before its last confirmed
    -- lease expires even while no autosave result has returned yet.
    return entry~=nil and not entry.Lost and not entry.Released
        and (self.Memory or os.time()<entry.LeaseExpires-15)
end
return Data
