-- The shared native UI environment is prefixed by scripts/check_client_startup.py.
-- Roblox accepts nil Highlight.Adornee; Lune 0.11 cannot encode nil Ref.
-- Only that engine boundary is proxied, the controller source stays unchanged.
local nativeCreate=environment.Instance.new
environment.Instance.new=function(class)
 local object=nativeCreate(class)
 if class~='Highlight' then return object end
 return setmetatable({}, {__index=function(_,key) return object[key] end,
  __newindex=function(_,key,value) if key=='Adornee' and value==nil then return end; object[key]=value end})
end
input.InputEnded=signal(); input.WindowFocusReleased=signal(); input.TextBoxFocused=signal(); input.GamepadDisconnected=signal()
guiService.MenuIsOpen=false; guiService.MenuOpened=signal(); guiService.MenuClosed=signal()
services.ContextActionService={BindAction=function() end,UnbindAction=function() end,SetPosition=function() end,SetTitle=function() end,GetButton=function() return nil end}
services.RunService.IsStudio=function() return true end
player.UserId=9001
local humanoid=r.Instance.new('Humanoid'); humanoid.Name='Humanoid'; humanoid.Parent=character
local camera=r.Instance.new('Camera'); camera.Parent=world; world.CurrentCamera=camera
local remoteFolder=r.Instance.new('Folder'); remoteFolder.Name='Remotes'
for _,name in {'Action','State','Notice','Effect'} do local object=r.Instance.new('RemoteEvent'); object.Name=name; object.Parent=remoteFolder end
r.implementProperty('RemoteEvent','OnClientEvent',function(object) return event(object,'OnClientEvent') end)
local requests={}
r.implementMethod('RemoteEvent','FireServer',function(object,...) table.insert(requests,{object.Name,...}) end)
services.ReplicatedStorage.WaitForChild=function(_,name) return if name=='Shared' then shared elseif name=='Remotes' then remoteFolder else nil end
environment.task.spawn=function(fn,...) return fn(...) end
local capturedWarnings={}
environment.warn=function(...) table.insert(capturedWarnings,{...}) end
local packaged=r.deserializePlace(fs.readFile('build/StealAnEgg.rbxl'))
local source=packaged:GetService('StarterPlayer').StarterPlayerScripts.Client.Bootstrap.Source
local scriptBoundary={Parent={Controllers={UIController='UIController',EffectsController='EffectsController',TutorialController='TutorialController',MovementController='MovementController'}},Destroying=signal()}
local bootstrapScope=setmetatable({script=scriptBoundary,require=module},{__index=environment})
local chunk,err=loadstring(source,'PackagedClientBootstrap'); assert(chunk,err); setfenv(chunk,bootstrapScope); chunk()
local boot=playerGui:FindFirstChild('EggHeistStartup'); assert(boot and boot.Enabled)
assert(string.find(boot.Card.Status.Text,'PROFILE',1,true),'Client did not subscribe and reach profile phase')
assert(camera.CameraSubject==humanoid,'Client did not repair the player camera')
assert(#requests>=1 and requests[1][2]=='Ready')
-- Show a real server failure without needing Output, and recover on a good profile.
world:SetAttribute('HeistServerState','Failed'); world:SetAttribute('HeistStartupError','Controlled startup failure')
run.Heartbeat:Fire(1)
assert(string.find(boot.Card.Status.Text,'SERVER-ERROR',1,true),'Server failure remained invisible')
world:SetAttribute('HeistServerState','Ready')
local profile=module('Domain/Rules').newProfile(os.time())
local state={Profile=profile,Stamina=100,MaxStamina=100,Combo=0,Dash=0,Intercept=0,Protection=180,Shield=0,Safe=true,Carry=false,
 Event=false,EventSeconds=300,Memory=true,Base={X=-51,Z=-29,IncubatorX=-59,IncubatorY=2.5,IncubatorZ=-34},ServerTime=os.time()}
remoteFolder.State.OnClientEvent:Fire(state)
assert(not boot.Enabled,'Profile delivery did not finish client loading: '..boot.Card.Status.Text)
assert(playerGui:FindFirstChild('EggHeistHUD'),'Main game HUD not constructed')
local late=r.Instance.new('ScreenGui'); late.Name='EggHeistStartup'; late.Parent=playerGui
playerGui.ChildAdded:Fire(late)
assert(late.Parent==nil,'Late StarterGui template must not cover the loaded game')
for _,warning in capturedWarnings do error('Unexpected controller warning: '..tostring(warning[1])) end
-- A later controller/UI error must be readable rather than an endless spinner.
local invalid={Profile={Coins=0},Stamina=100,MaxStamina=100}
remoteFolder.State.OnClientEvent:Fire(invalid)
assert(boot.Enabled and string.find(boot.Card.Status.Text,'CLIENT-ERROR',1,true))
print('PASS full client startup: packaged bootstrap, remote subscription, game HUD, camera subject, profile acknowledgement, visible server/client diagnostics')
