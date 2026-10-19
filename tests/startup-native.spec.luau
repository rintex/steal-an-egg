-- Run the actual packaged server bootstrap with native Roblox instances and
-- controlled engine boundaries. This is not a Roblox Studio engine session.
local fs=require('@lune/fs')
local r=require('@lune/roblox')
local dm=r.deserializePlace(fs.readFile('build/StealAnEgg.rbxl'))
local world=dm:GetService('Workspace')
local players=dm:GetService('Players')
local now=0
local baseTime=os.time()
local jobs={}
local warnings={}
local events=setmetatable({},{__mode='k'})
local function signal()
 local listeners={}
 return {Connect=function(_,fn)
  local c={Connected=true,Disconnect=function(self) self.Connected=false end}
  table.insert(listeners,{c,fn}); return c
 end,Fire=function(_,...)
  for _,item in ipairs(listeners) do if item[1].Connected then item[2](...) end end
 end}
end
local function event(object,key)
 if not events[object] then events[object]={} end
 if not events[object][key] then events[object][key]=signal() end
 return events[object][key]
end
for _,name in {'Destroying','Died','CharacterAdded','CharacterRemoving','PlayerAdded','PlayerRemoving','PromptButtonHoldBegan','PromptButtonHoldEnded','Triggered','OnServerEvent'} do
 r.implementProperty('Instance',name,function(object) return event(object,name) end)
end
r.implementMethod('Instance','WaitForChild',function(object,name) return assert(object:FindFirstChild(name),name) end)
local snapshots={}
r.implementMethod('RemoteEvent','FireClient',function(object,player,...)
 if object.Name=='State' then table.insert(snapshots,{Player=player,State=(...)}) end
end)
r.implementMethod('DataModel','BindToClose',function() end)
r.implementMethod('Workspace','GetServerTimeNow',function() return baseTime+now end)
r.implementMethod('Workspace','Raycast',function(_,origin,direction)
 if direction.Y< -5 then return {Position=r.Vector3.new(origin.X,.65,origin.Z),Instance=world.Map.Hub.Plaza,Distance=origin.Y-.65} end
 return nil
end)
r.implementMethod('Workspace','Blockcast',function() return nil end)
-- Lune stores CFrame and Position independently; native Roblox derives the latter.
for _,object in dm:GetDescendants() do if object:IsA('BasePart') then object.Position=object.CFrame.Position end end
r.implementMethod('Model','GetPivot',function(object) return if object.PrimaryPart then object.PrimaryPart.CFrame else object.WorldPivot end)
r.implementMethod('Model','PivotTo',function(object,target)
 local previous=if object.PrimaryPart then object.PrimaryPart.CFrame else object.WorldPivot
 for _,part in object:GetDescendants() do if part:IsA('BasePart') then
  part.CFrame=target*previous:ToObjectSpace(part.CFrame); part.Position=part.CFrame.Position
 end end
 object.WorldPivot=target
end)
local player=r.Instance.new('Player'); player.Name='StartupTester'; player.DisplayName='Startup Tester'; player.UserId=9001; player.Parent=players
local character=r.Instance.new('Model'); character.Name='StartupTester'; character.Parent=world
local root=r.Instance.new('Part'); root.Name='HumanoidRootPart'; root.CFrame=r.CFrame.new(0,4,0); root.Position=root.CFrame.Position; root.Parent=character
local humanoid=r.Instance.new('Humanoid'); humanoid.Health=100; humanoid.MoveDirection=r.Vector3.zero; humanoid.Parent=character
player.Character=character
r.implementMethod('Players','GetPlayers',function() return {player} end)
local guid=0
r.implementMethod('HttpService','GenerateGUID',function() guid+=1; return string.format('00000000-0000-4000-8000-%012d',guid) end)
local kicked={}
r.implementMethod('Player','Kick',function(object,message) kicked[object]=message end)
local services={RunService={IsStudio=function() return true end},DataStoreService={GetDataStore=function() error('unpublished Studio must not request a store') end},PathfindingService={CreatePath=function()
 return {Status=r.Enum.PathStatus.Success,ComputeAsync=function(self,from,to) self.Points={{Position=from},{Position=to}} end,GetWaypoints=function(self) return self.Points end}
end}}
local gameFacade={JobId='studio-native-test',GetService=function(_,name) return services[name] or dm:GetService(name) end,
 BindToClose=function() end}
local scope=setmetatable({game=gameFacade,workspace=world},{__index=getfenv()})
for _,name in {'Instance','Enum','Vector2','Vector3','CFrame','Color3','ColorSequence','ColorSequenceKeypoint','NumberRange','NumberSequence','NumberSequenceKeypoint','UDim','UDim2','Font','BrickColor','Rect'} do scope[name]=r[name] end
scope.os={clock=function() return now end,time=function() return baseTime+math.floor(now) end}
scope.warn=function(...) table.insert(warnings,table.concat({...},' ')) end
scope.RaycastParams={new=function() return {} end}
scope.task={}
local function resume(job,...)
 local ok,delay=coroutine.resume(job.Thread,...)
 assert(ok,delay)
 if coroutine.status(job.Thread)~='dead' then job.Due=now+(delay or 0); table.insert(jobs,job) end
end
scope.task.spawn=function(fn,...) resume({Thread=coroutine.create(fn)},...) end
scope.task.defer=scope.task.spawn
scope.task.delay=function(delay,fn) table.insert(jobs,{Thread=coroutine.create(fn),Due=now+delay}) end
scope.task.wait=function(delay) return coroutine.yield(delay or .03) end
local cached={}
local function module(object)
 if cached[object] then return cached[object] end
 local chunk,err=loadstring(object.Source,object:GetFullName()); assert(chunk,err)
 local env=setmetatable({script=object,require=module},{__index=scope})
 setfenv(chunk,env); local result=chunk(); cached[object]=result; return result
end
-- Build newly-created parts with Position derived as in Roblox.
scope.Instance={new=function(class)
 local object=r.Instance.new(class)
 if object:IsA('BasePart') then object.Position=r.Vector3.zero end
 return object
end}
-- Wrap the shared part helper to synchronize derived values in this offline VM.
local World=module(dm:GetService('ServerScriptService').Server.Services.WorldService)
local part=World.part
World.part=function(...)
 local object=part(...); object.Position=object.CFrame.Position; return object
end
local bootstrap=dm:GetService('ServerScriptService').Server.Bootstrap
module(bootstrap)
for tick=1,15 do
 now=tick*.2
 local current=jobs; jobs={}
 for _,job in current do if job.Due<=now then resume(job) else table.insert(jobs,job) end end
end
assert(not kicked[player],kicked[player])
assert(#snapshots>=3,'Server bootstrap never sent player state')
local first=snapshots[1].State
assert(first.Profile and first.Profile.Level==1 and first.Memory==true)
assert(world.Map.PlayerBases:FindFirstChild('Base_9001'),'Personal base not allocated')
assert(#world.Map.Eggs:GetChildren()==3,'Playable eggs did not spawn')
for _,message in warnings do
 assert(string.find(message,'Studio memory mode',1,true),message)
end
print('PASS full server startup: packaged map reused, unpublished Studio profile, 3 playable eggs, player base, state snapshots, no scheduler errors')
