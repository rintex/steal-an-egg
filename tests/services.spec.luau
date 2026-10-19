-- Loaded by scripts/check.py with the ACTUAL DataService and EventService wrapped in injected service mocks.
local Rules=require("../src/shared/Domain/Rules")
local Profile=require("../src/shared/Domain/Profile")
local Catalog=require("../src/shared/Config/EggConfig")
local Economy=require("../src/shared/Config/EconomyConfig")
local count=0
local function test(name,f)
    local ok,err=pcall(f); if not ok then error("FAIL "..name..": "..tostring(err)) end
    count+=1; print("PASS "..name)
end
local records={}; local failure=false; local studio=false; local guid=0
local writes=0
local store={}
function store:UpdateAsync(key,callback)
    if failure then error("simulated service outage") end
    local value=callback(Profile.copy(records[key]))
    if value~=nil then records[key]=Profile.copy(value); writes+=1 end
    return Profile.copy(records[key])
end
local services={
    DataStoreService={GetDataStore=function() return store end},
    HttpService={GenerateGUID=function() guid+=1; return tostring(guid) end},
    RunService={IsStudio=function() return studio end},
    ReplicatedStorage={Shared={Domain={Rules="Rules",Profile="Profile"},Config={EconomyConfig="Economy",EggConfig="Catalog"}}},
}
local mockGame={JobId="test-server",GetService=function(_,name) assert(services[name],name); return services[name] end}
local mockWorkspace={GetAttribute=function() return false end}
local mockTask={wait=function() end}
local mockRequire=function(name) return ({Rules=Rules,Profile=Profile,Economy=Economy,Catalog=Catalog,World={part=function() return {} end}})[name] end
local Data=makeDataService(mockGame,mockWorkspace,mockTask,mockRequire,function() end)
local function user(id) return {UserId=id,Kick=function(self,message) self.Kicked=message end} end

test("DataService: new profile saves and reloads with exact inventory",function()
    records={}; local p=user(1); local a=Data.new(); local profile=a:load(p)
    profile.Coins=88; profile.OwnedEggs={{Uid="durable-a",Id="clover",ReadyAt=0,Mutation=false}}
    assert(a:save(p,true)); local b=Data.new(); local restored=b:load(p)
    assert(restored.Coins==88 and restored.OwnedEggs[1].Uid=="durable-a"); b:save(p,true)
end)
test("DataService: concurrent server cannot load an active lease",function()
    records={}; local p=user(2); local a=Data.new(); assert(a:load(p))
    local before=Profile.copy(records.u_2); local b=Data.new(); assert(b:load(p)==nil)
    assert(records.u_2.Session==before.Session and records.u_2.Profile.Coins==before.Profile.Coins)
    a:save(p,true)
end)
test("DataService: failed load never writes an empty profile",function()
    records={u_3={Profile=Rules.newProfile(0),Session=nil,Expires=0}}
    records.u_3.Profile.Coins=999; local p=user(3); local a=Data.new(); failure=true
    assert(a:load(p)==nil); assert(not a:save(p,true)); failure=false
    assert(records.u_3.Profile.Coins==999)
end)
test("DataService: unknown schema is refused without overwriting",function()
    records={u_4={Profile=Rules.newProfile(0),Expires=0}}; records.u_4.Profile.Version=99
    local a=Data.new(); assert(a:load(user(4))==nil); assert(records.u_4.Profile.Version==99)
end)
test("DataService: expired lease can be reclaimed; old owner cannot save",function()
    records={}; local p=user(5); local a=Data.new(); assert(a:load(p)); records.u_5.Expires=0
    local b=Data.new(); assert(b:load(p)); assert(not a:save(p,false)); assert(b:save(p,true))
end)
test("DataService: failed autosave leaves last durable state intact",function()
    records={}; local p=user(6); local a=Data.new(); local profile=a:load(p); profile.Coins=55
    assert(a:save(p,false)); profile.Coins=66; failure=true; assert(not a:save(p,false)); failure=false
    assert(records.u_6.Profile.Coins==55); assert(a:save(p,true)); assert(records.u_6.Profile.Coins==66)
end)
test("DataService: prolonged outage kicks before the lease can expire",function()
    records={}; local p=user(7); local a=Data.new(); assert(a:load(p)); a.Entries[p].LastSave=os.time()-120
    failure=true; assert(not a:save(p,false)); failure=false; assert(p.Kicked)
end)
test("DataService: unpublished Studio can start when GetDataStore is forbidden",function()
    studio=true
    local original=services.DataStoreService.GetDataStore
    services.DataStoreService.GetDataStore=function() error("You must publish this place to the web to access DataStore") end
    local ok,result=pcall(function()
        local a=Data.new(); local p=user(81)
        assert(a.Memory and a:load(p)); assert(a:save(p,true))
        return a
    end)
    services.DataStoreService.GetDataStore=original; studio=false
    assert(ok,result)
end)
test("DataService: Studio mode never writes persistent storage",function()
    studio=true; local before=writes; local a=Data.new(); local p=user(8)
    assert(a.Memory and a:load(p)); assert(a:save(p,true)); assert(writes==before); studio=false
end)

local mockWorld={part=function() return {} end}
local fakeRequire=function(name) if name=="World" then return mockWorld elseif name=="Economy" then return Economy end; error(name) end
local vector={new=function(...) return {...} end}
local frame={new=function(...) return {...} end}
local color={fromRGB=function(...) return {...} end}
local Events=makeEventService(mockGame,fakeRequire,{Parent={WorldService="World"}},vector,frame,color)
test("EventService: event starts once and finishes with nest cleanup",function()
    local spawned=0; local removed=false; local p=user(9)
    local g={World={Map={}},Guardians={add=function() end},Sessions={[p]={Dirty=false}},notify=function() end,
        Eggs={NestEggs={},Eggs={}}}
    g.Eggs.spawn=function(_,nest,id)
        spawned+=1; assert(id=="sunseed" and nest.Temporary)
        local e={Uid="gold-event",State="Nest",Model={Destroy=function() removed=true end}}
        g.Eggs.Eggs[e.Uid]=e; return e
    end
    local e=Events.new(g); e.NextAt=0; e:update(); assert(e.Active and g.EventActive and spawned==1)
    e:update(); assert(spawned==1); e.Ends=0; e:update()
    assert(not e.Active and not g.EventActive and removed and g.Eggs.Eggs["gold-event"]==nil)
end)
test("EventService: event ending preserves an egg already carried",function()
    local removed=false
    local g={World={Map={}},Guardians={add=function() end},Sessions={},notify=function() end,Eggs={NestEggs={},Eggs={}}}
    g.Eggs.spawn=function() return {Uid="carried",State="Carried",Model={Destroy=function() removed=true end}} end
    local e=Events.new(g); e.NextAt=0; e:update(); e.Ends=0; e:update(); assert(not removed)
end)
print(string.format("%d mocked service tests passed",count))

-- Vector/motion stubs exercise actual FSM transitions, not Roblox navigation or physics.
local vmeta={}
vmeta.__index=function(v,k)
    if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    if k=="Unit" then return setmetatable({X=v.X/v.Magnitude,Y=v.Y/v.Magnitude,Z=v.Z/v.Magnitude},vmeta) end
end
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmeta) end
vmeta.__add=function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmeta.__sub=function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmeta.__mul=function(a,b) return vec(a.X*b,a.Y*b,a.Z*b) end
local gv={new=vec}
local cf={lookAt=function(pos) return {Position=pos} end,new=function(x,y,z) return {Position=if type(x)=="table" then x else vec(x,y,z)} end}
local enum={PathStatus={Success="success"},RaycastFilterType={Exclude="exclude"},Material={Neon="neon"},PartType={Ball="ball"}}
local navCalls=0
services.PathfindingService={CreatePath=function()
    return {Status="success",ComputeAsync=function(self,from,to) self.Points={{Position=from},{Position=to}}; navCalls+=1 end,
        GetWaypoints=function(self) return self.Points end}
end}
local observedPlayers={}
services.Players={GetPlayers=function() return observedPlayers end}
local GuardianConfig=require("../src/shared/Config/GuardianConfig")
services.ReplicatedStorage.Shared.Config.GuardianConfig="Guardian"
local gworld={part=function() return {Destroy=function(self) self.Destroyed=true end} end}
local gRequire=function(name) if name=="Guardian" then return GuardianConfig elseif name=="World" then return gworld end; error(name) end
local guardianWorkspace={Obstruction=nil,NoGround=false,LastFilter=nil}
function guardianWorkspace:Blockcast(_,_,_,params)
    self.LastFilter=params.FilterDescendantsInstances
    return self.Obstruction
end
function guardianWorkspace:Raycast(origin,delta,params)
    self.LastFilter=params.FilterDescendantsInstances
    if delta.Y<= -10 then return if self.NoGround then nil else {Position=vec(origin.X,.5,origin.Z)} end
    return nil
end
local guardianTasks={Deferred=false,Pending={}}
function guardianTasks.spawn(f)
    if guardianTasks.Deferred then table.insert(guardianTasks.Pending,f) else f() end
end
local Guardian=makeGuardianService(mockGame,gRequire,{Parent={WorldService="World"}},gv,cf,color,enum,guardianTasks,{new=function() return {} end},guardianWorkspace)
local function guardianFixture()
    local p=user(11); local root={Position=vec(0,3,146)}; local hits=0
    local g={World={Map={},Eggs={}},Sessions={[p]={Carry="egg",Dodges=0}},
        root=function() return root end,isSafe=function(_,pos) return pos.Z<94 end,
        notify=function() end,hit=function() hits+=1 end}
    local ai=Guardian.new(g)
    local m={Pos=vec(0,3,140),GetPivot=function(self) return {Position=self.Pos} end,
        PivotTo=function(self,newFrame) self.Pos=newFrame.Position end,SetAttribute=function() end}
    local a={Model=m,Home=vec(0,3,140),Nest={Index=1},State="IDLE",Until=0,Target=nil,NextPath=0,PathIndex=1,Computing=false,Label={},Patrol=1}
    ai.Actors[1]=a; ai.visible=function() return true end
    return ai,a,p,root,g,function() return hits end
end
test("GuardianService: alarm winds up before attacking; hit then recovers",function()
    local ai,a,p,root,g,hits=guardianFixture()
    ai:alarm(1,p); assert(a.State=="ALERT"); ai:update(.2); assert(a.State=="ALERT" and hits()==0)
    a.Until=0; ai:update(.2); assert(a.State=="ATTACK" and a.Warning and hits()==0)
    a.Until=0; ai:update(.2); assert(a.State=="RECOVER" and hits()==1 and a.Warning==nil)
end)
test("GuardianService: moving out of telegraphed area dodges the hit",function()
    local ai,a,p,root,g,hits=guardianFixture()
    ai:alarm(1,p); a.Until=0; ai:update(.2); assert(a.State=="ATTACK")
    root.Position=vec(30,3,146); a.Until=0; ai:update(.2)
    assert(hits()==0 and g.Sessions[p].Dodges==1)
end)
test("GuardianService: safe-zone entry aborts chase and returns home",function()
    local ai,a,p,root=guardianFixture(); ai:alarm(1,p); root.Position=vec(0,3,80); ai:update(.2); ai:update(.2)
    assert(a.Target==nil and a.State=="IDLE")
end)
test("GuardianService: blocked visibility requests a navigation path",function()
    local ai,a,p,root=guardianFixture(); ai.visible=function() return false end
    root.Position=vec(30,3,160); ai:alarm(1,p); a.Until=0
    local before=navCalls; ai:update(.2); assert(a.State=="CHASE" and navCalls>before)
    assert(a.Model.Pos.X>0)
end)
test("GuardianService: a dropped egg stops pursuit",function()
    local ai,a,p,root,g=guardianFixture(); ai:alarm(1,p); g.Sessions[p].Carry=nil; ai:update(.2); ai:update(.2)
    assert(a.Target==nil and a.State=="IDLE")
end)
test("GuardianService: body obstruction stops movement and requests path",function()
    local ai,a,p,root=guardianFixture(); root.Position=vec(30,3,160)
    guardianWorkspace.Obstruction={Distance=1}
    ai:alarm(1,p); a.Until=0; local before=navCalls; local previous=a.Model.Pos
    ai:update(.2)
    assert(a.Model.Pos==previous and navCalls>before and a.NeedsPathUntil>os.clock())
    guardianWorkspace.Obstruction=nil
end)
test("GuardianService: missing ground prevents movement over a cliff",function()
    local ai,a=guardianFixture(); guardianWorkspace.NoGround=true
    local previous=a.Model.Pos; local arrived,blocked=ai:walk(a,vec(30,3,160),.2,17)
    assert(not arrived and blocked and a.Model.Pos==previous)
    guardianWorkspace.NoGround=false
end)
test("GuardianService: cover during windup prevents damage through a wall",function()
    local ai,a,p,root,g,hits=guardianFixture()
    ai:alarm(1,p); a.Until=0; ai:update(.2); assert(a.State=="ATTACK")
    ai.visible=function() return false end; a.Until=0; ai:update(.2)
    assert(hits()==0)
end)
test("GuardianService: blocked charge cannot damage through low cover",function()
    local ai,a,p,root,g,hits=guardianFixture()
    ai:alarm(1,p); a.Until=0; ai:update(.2); assert(a.State=="ATTACK")
    guardianWorkspace.Obstruction={Distance=1}; a.Until=0; ai:update(.2)
    assert(hits()==0)
    guardianWorkspace.Obstruction=nil
end)
test("GuardianService: stale async path does not overwrite a new target",function()
    local ai,a=guardianFixture(); guardianTasks.Deferred=true
    ai:path(a,vec(30,3,160)); assert(a.Computing and #guardianTasks.Pending==1)
    a.PathEpoch=1; guardianTasks.Pending[1](); guardianTasks.Pending={}; guardianTasks.Deferred=false
    assert(a.Waypoints==nil and not a.Computing)
end)
test("GuardianService: carried eggs are excluded from detection rays",function()
    local ai,a,p,root,g=guardianFixture()
    assert(Guardian.visible(ai,a,root))
    assert(guardianWorkspace.LastFilter[2]==g.World.Eggs)
end)
print(string.format("%d total mocked service tests passed",count))
