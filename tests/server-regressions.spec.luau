-- Runs against the actual service modules via scripts/check_server_regressions.py.
local Rules=require("../src/shared/Domain/Rules")
local Profile=require("../src/shared/Domain/Profile")
local Catalog=require("../src/shared/Config/EggConfig")
local Economy=require("../src/shared/Config/EconomyConfig")
local count=0
local function test(name,callback)
    local ok,err=pcall(callback)
    if not ok then error("FAIL "..name..": "..tostring(err)) end
    count+=1; print("PASS "..name)
end

local records={}; local writes=0; local mode="normal"; local guid=0
local store={}
function store:UpdateAsync(key,callback)
    local value=callback(Profile.copy(records[key]))
    if mode=="cancel" then return Profile.copy(records[key]) end
    if value then records[key]=Profile.copy(value); writes+=1 end
    if mode=="response-lost" then mode="normal"; error("committed write response lost") end
    return Profile.copy(records[key])
end
local players={}
local services={
    Players=players,DataStoreService={GetDataStore=function() return store end},
    HttpService={GenerateGUID=function() guid+=1; return "regression-"..guid end},
    RunService={IsStudio=function() return false end},
    ReplicatedStorage={Shared={Domain={Rules="Rules",Profile="Profile"},Config={EconomyConfig="Economy",EggConfig="Catalog"}}},
}
local mockGame={JobId="regressions",GetService=function(_,name) return services[name] end}
local loadRequire=function(name) return ({Rules=Rules,Profile=Profile,Economy=Economy,Catalog=Catalog,World={}})[name] end
local immediateTask={wait=function() end}
local Data=makeData(mockGame,{GetAttribute=function() return false end},immediateTask,loadRequire,function() end)
local function user(id) return {UserId=id,Kick=function(self,message) self.Kicked=message end} end
local function reset() records={}; mode="normal"; writes=0 end

test("lease: canceled UpdateAsync callback cannot establish a session",function()
    reset(); mode="cancel"; local p=user(101); local d=Data.new()
    assert(d:load(p)==nil and d.Entries[p]==nil and records.u_101==nil)
end)
test("lease: duplicate load returns the live profile without discarding progress",function()
    reset(); local p=user(102); local d=Data.new(); local a=d:load(p); a.Coins=123
    local before=writes; assert(d:load(p)==a and d:load(p).Coins==123 and writes==before)
end)
test("lease: reacquiring a released profile gets a new lease identity",function()
    reset(); local p=user(103); local d=Data.new(); assert(d:load(p)); local first=d.Entries[p].Lease
    assert(d:save(p,true)); assert(d:load(p)); assert(d.Entries[p].Lease~=first)
end)
test("lease: an expired writer cannot silently extend its own old lease",function()
    reset(); local p=user(104); local d=Data.new(); local a=d:load(p); a.Coins=99
    records.u_104.Expires=0; assert(not d:save(p,false)); assert(p.Kicked and not d:isActive(p))
    assert(records.u_104.Profile.Coins==0)
end)
test("lease: response loss after commit is retried without losing the snapshot",function()
    reset(); local p=user(105); local d=Data.new(); local a=d:load(p); a.Coins=73
    mode="response-lost"; assert(d:save(p,false)); assert(records.u_105.Profile.Coins==73 and d:isActive(p))
end)
test("lease: a competing owner freezes the old session immediately",function()
    reset(); local p=user(106); local d=Data.new(); assert(d:load(p))
    records.u_106.Session="another-server"; assert(not d:save(p,false)); assert(p.Kicked and not d:isActive(p))
end)
test("lease: repeated release cannot write a stale profile",function()
    reset(); local p=user(107); local d=Data.new(); local a=d:load(p); a.Coins=10
    assert(d:save(p,true)); local before=writes; a.Coins=999
    assert(not d:save(p,true)); assert(writes==before and records.u_107.Profile.Coins==10)
end)
test("lease: gameplay freezes before a stuck request's confirmed lease expires",function()
    reset(); local p=user(108); local d=Data.new(); assert(d:load(p)); assert(d:isActive(p))
    d.Entries[p].LeaseExpires=os.time()+10; assert(not d:isActive(p))
end)
test("rules: pickup refuses a non-finite position",function()
    local e={State="Nest",LockUntil=0,Transfers=0}; local p={Alive=true,Carrying=false}
    assert(not Rules.pickup(e,p,0,0/0)); assert(not Rules.pickup(e,p,0,math.huge)); assert(not Rules.pickup(e,p,0,-1))
end)

local Game=makeGame(mockGame,{Parent={WorldService="World"}},loadRequire,{spawn=function(callback) callback() end})
test("join: PlayerAdded and initial sweep cannot start two overlapping loads",function()
    local loads=0; local released=0; local p=user(110)
    local data={load=function() loads+=1; coroutine.yield(); return Rules.newProfile(0) end,
        save=function() released+=1; return true end}
    local g=setmetatable({Closing=false,Sessions={},Joining={},Removing={},Data=data},Game)
    local co=coroutine.create(function() g:add(p) end)
    assert(coroutine.resume(co)); g:add(p); assert(loads==1 and not p.Kicked)
    assert(coroutine.resume(co)); assert(released==1 and next(g.Joining)==nil)
end)
local function characterFixture(stall)
    local hum={Health=100,Died={Connect=function(_,callback) return {Callback=callback,Disconnect=function(self) self.Disconnected=true end} end}}
    local root={Position={X=0,Y=4,Z=0}}
    local character={WaitForChild=function(_,name)
        if stall and name=="Humanoid" then coroutine.yield() end
        return if name=="Humanoid" then hum else root
    end}
    return character,hum,root
end
test("respawn: a stale WaitForChild callback cannot overwrite a new character",function()
    local p=user(111); local old=characterFixture(true); p.Character=old
    local drops=0; local s={LastPosition="new-position"}
    local g=setmetatable({Sessions={[p]=s},Eggs={drop=function() drops+=1 end}},Game)
    local co=coroutine.create(function() g:character(p,old) end)
    assert(coroutine.resume(co)); p.Character=characterFixture(false)
    assert(coroutine.resume(co)); assert(s.LastPosition=="new-position" and drops==0)
end)
test("respawn: upgraded stamina refills and an old death signal cannot drop a new egg",function()
    local p=user(112); local character=characterFixture(false); p.Character=character
    local profile=Rules.newProfile(0); profile.Upgrades.Stamina=4
    local drops=0; local s={Profile=profile}
    local g=setmetatable({Sessions={[p]=s},Eggs={drop=function() drops+=1 end}},Game)
    g:character(p,character); assert(s.Stamina==148 and s.Character==character)
    local old=s.DeathConnection; local current=characterFixture(false); p.Character=current; g:character(p,current)
    local before=drops; old.Callback(); assert(drops==before and old.Disconnected)
    s.DeathConnection.Callback(); assert(drops==before+1)
end)
test("input: sprint release survives another action's throttle",function()
    local p=user(113); local s={Sprint=true,Limits={},InvalidAt=-100}
    local g=setmetatable({Sessions={[p]=s},Closing=false,Data={isActive=function() return true end}},Game)
    g:action(p,"Sprint",false); assert(not s.Sprint)
end)

local vectorMeta={}
vectorMeta.__index=function(v,key)
    if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if key=="Unit" then return setmetatable({X=v.X/v.Magnitude,Y=v.Y/v.Magnitude,Z=v.Z/v.Magnitude},vectorMeta) end
end
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
vectorMeta.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
local frameMeta={}
local function frame(x,y,z)
    return setmetatable({Position=if type(x)=="table" then x else vec(x,y,z),LookVector=vec(1,0,0),Rotation={}},frameMeta)
end
frameMeta.__add=function(a,b) return frame(a.Position+b) end
frameMeta.__mul=function(a) return a end
local now=0; local hasFloor=true; local wall=false
local motionWorkspace={Raycast=function(_,origin,direction)
    if direction.Y<0 then return if hasFloor then {Position=vec(origin.X,0,origin.Z),Distance=3} else nil end
    return if wall then {Position=origin,Distance=1} else nil
end}
local Movement=makeMovement(mockGame,loadRequire,{new=vec,zero=vec(0,0,0)},{new=frame},{new=function() return {} end},
    {RaycastFilterType={Exclude="exclude"}},motionWorkspace,{clock=function() return now end})
local function movementFixture()
    now=0; hasFloor=true; wall=false
    local root=setmetatable({StoredFrame=frame(0,3,0)}, {
        __index=function(t,k) if k=="Position" then return t.StoredFrame.Position elseif k=="CFrame" then return t.StoredFrame end end,
        __newindex=function(t,k,v) if k=="CFrame" then rawset(t,"StoredFrame",v) else rawset(t,k,v) end end,
    })
    local hum={MoveDirection=vec(1,0,0)}
    local p={Character={FindFirstChildOfClass=function() return hum end}}
    local s={Profile=Rules.newProfile(0),Stamina=100,Sprint=true,DashAt=0,MoveBudget=7,
        LastPosition=vec(0,3,0),GroundedPosition=vec(0,3,0),MovementAt=0,SpawnGrace=-1,LastActive=0}
    local drops=0; local effects=0
    local g={Sessions={[p]=s},Eggs={Eggs={},drop=function() drops+=1 end},World={Eggs={}},root=function() return root end,
        Remotes={Effect={FireClient=function() effects+=1 end}}}
    return Movement.new(g),p,s,root,hum,function() return drops,effects end
end
test("movement: a legitimate sprint burst after a one-second stall is accepted",function()
    local movement,p,s,root=movementFixture(); now=1; root.CFrame=frame(24,3,0)
    movement:update(p,.5); assert(root.Position.X==24 and s.InvalidAt==nil and s.MoveBudget>=0)
end)
test("movement: allowance remains bounded and rejects continued excess speed",function()
    local movement,p,s,root=movementFixture(); now=1; root.CFrame=frame(24,3,0); movement:update(p,.5)
    now=1.2; root.CFrame=frame(64,3,0); movement:update(p,.2)
    assert(root.Position.X==24 and s.InvalidAt==now and s.MoveBudget<41)
end)
test("movement: rejected teleport cannot poison the recovery checkpoint",function()
    local movement,p,s,root=movementFixture(); now=.2; root.CFrame=frame(150,3,0)
    movement:update(p,.2); assert(root.Position.X==0 and s.GroundedPosition.X==0)
end)
test("dash: unsupported destination preserves stamina and cooldown",function()
    local movement,p,s,root,_,counts=movementFixture(); hasFloor=false; now=1
    movement:dash(p); local _,effects=counts()
    assert(s.Stamina==100 and s.DashAt==0 and root.Position.X==0 and effects==0)
end)
test("dash: a nearby wall cannot consume an unusable dash",function()
    local movement,p,s,root=movementFixture(); wall=true; now=1; movement:dash(p)
    assert(s.Stamina==100 and s.DashAt==0 and root.Position.X==0)
end)
test("dash: successful travel charges once and refreshes validation state",function()
    local movement,p,s,root,_,counts=movementFixture(); now=1; movement:dash(p)
    local _,effects=counts(); assert(root.Position.X==13 and s.Stamina==75 and s.DashAt==5 and effects==1)
    movement:dash(p); assert(s.Stamina==75 and effects==1 and s.LastPosition.X==13 and s.GroundedPosition.X==13)
end)
print(string.format("%d server regression tests passed",count))
