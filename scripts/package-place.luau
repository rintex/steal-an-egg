-- Bake the actual game map into both published formats. Roblox Studio can show
-- the place before Play; runtime reuses these parts and replaces display actors.
local fs=require('@lune/fs')
local roblox=require('@lune/roblox')
local model=roblox.deserializePlace(fs.readFile('build/StealAnEgg.rbxl'))
local world=model:GetService('Workspace')
world:SetAttribute('HeistBuild','STUDIO-FIX-04')
world.StreamingEnabled=false
-- An engine-replicated screen remains visible even if the client bootstrap
-- cannot start; the bootstrap replaces its message and hides it on success.
local starterGui=model:GetService('StarterGui')
local boot=roblox.Instance.new('ScreenGui'); boot.Name='EggHeistStartup'; boot.ResetOnSpawn=false; boot.DisplayOrder=200; boot.Parent=starterGui
local panel=roblox.Instance.new('Frame'); panel.Name='Card'; panel.AnchorPoint=roblox.Vector2.new(.5,0); panel.Position=roblox.UDim2.new(.5,0,0,24); panel.Size=roblox.UDim2.new(.9,0,0,116); panel.BackgroundColor3=roblox.Color3.fromRGB(21,32,48); panel.BorderSizePixel=0; panel.Parent=boot
local status=roblox.Instance.new('TextLabel'); status.Name='Status'; status.BackgroundTransparency=1; status.Position=roblox.UDim2.fromOffset(14,10); status.Size=roblox.UDim2.new(1,-28,1,-20); status.TextColor3=roblox.Color3.fromRGB(242,247,250); status.FontFace=roblox.Font.fromEnum(roblox.Enum.Font.GothamBold); status.TextSize=16; status.TextWrapped=true; status.Text='STUDIO-FIX-04 / START\nЗапускаем игру. Если надпись не меняется, запусти Play (F5) с игроком.'; status.Parent=panel
local originalSources={}
for _,object in model:GetDescendants() do
 if object:IsA('LuaSourceContainer') then originalSources[object:GetFullName()]=object.Source end
end
local environment=setmetatable({game=model,workspace=world},{__index=getfenv()})
for _,name in {'Instance','Enum','Vector2','Vector3','CFrame','Color3','ColorSequence','ColorSequenceKeypoint','NumberRange','NumberSequence','NumberSequenceKeypoint','UDim','UDim2','Font','BrickColor','Rect'} do
 environment[name]=roblox[name]
end
-- Offline-only deterministic scenery. The packaged world is reused in Studio,
-- so local play does not have to recreate or rerandomize these static parts.
environment.Random={new=function(seed)
 local state=math.floor(seed or 1)%2147483647
 local function unit() state=(state*48271)%2147483647; return (state-1)/2147483646 end
 return {NextNumber=function(_,a,b) a=a or 0; b=b or 1; return a+(b-a)*unit() end,
 NextInteger=function(_,a,b) return math.min(b,a+math.floor(unit()*(b-a+1))) end}
end}
local cache={}
local function module(object)
 if cache[object] then return cache[object] end
 local chunk,err=loadstring(object.Source,object:GetFullName()); assert(chunk,err)
 local scope=setmetatable({script=object,require=module},{__index=environment})
 setfenv(chunk,scope); local result=chunk(); cache[object]=result; return result
end
local services=model:GetService('ServerScriptService').Server.Services
local World=module(services.WorldService)
local scene=World.build()
scene.Map:SetAttribute('HeistBakedVersion',1)
for i=1,8 do
 local base=World.base(scene,i,{UserId=i,DisplayName='Убежище '..i})
 base.Model:SetAttribute('HeistEditorDisplay',true)
end
local catalog=module(model:GetService('ReplicatedStorage').Shared.Config.EggConfig)
local guards=module(services.GuardianService).new({World=scene})
for i,nest in ipairs(scene.Nests) do
 local id=({'clover','dew','honey'})[i]
 local egg=World.egg(scene.Eggs,catalog[id],nest.Part.CFrame.Position+roblox.Vector3.new(0,2.2,0),false)
 egg:SetAttribute('HeistEditorDisplay',true)
 guards:add(nest); guards.Actors[i].Model:SetAttribute('HeistEditorDisplay',true)
end
local camera=roblox.Instance.new('Camera')
camera.Name='Camera'; camera.FieldOfView=70; camera.CameraType=roblox.Enum.CameraType.Custom
local focus=roblox.Vector3.new(0,1,65)
camera.CFrame=roblox.CFrame.lookAt(roblox.Vector3.new(190,165,-150),focus)
camera.Focus=roblox.CFrame.new(focus); camera.Parent=world; world.CurrentCamera=camera
-- Normalize Lune's legacy Font alias for its serializer. This changes only
-- already-generated text instances, never the game Script sources.
for _,object in model:GetDescendants() do
 if object:IsA('TextLabel') then object.FontFace=roblox.Font.fromEnum(roblox.Enum.Font.GothamBold) end
end
local binary=roblox.serializePlace(model)
local xml=roblox.serializePlace(model,true)
for _,payload in {binary,xml} do
 local reopened=roblox.deserializePlace(payload)
 local sceneMap=reopened:GetService('Workspace'):FindFirstChild('Map')
 assert(sceneMap and #sceneMap:GetDescendants()>600,'Map missing from saved place')
 local scripts=0
 for _,object in reopened:GetDescendants() do
  if object:IsA('LuaSourceContainer') then
   scripts+=1; assert(originalSources[object:GetFullName()]==object.Source,'Source changed during packaging')
  end
 end
 assert(scripts==27,'Unexpected script count')
end
-- Exercise actual runtime handover: static geometry is retained and editor-only
-- eggs, guardians and sample bases disappear before real services spawn them.
local before=scene.Map
local retained=scene.Hub
local live=World.build()
assert(live.Map==before and live.Hub==retained and #live.Nests==3)
assert(#live.Eggs:GetChildren()==0 and #live.Bases:GetChildren()==0)
for _,child in live.Map:GetChildren() do assert(child:GetAttribute('HeistEditorDisplay')~=true) end
fs.writeFile('build/StealAnEgg.rbxl',binary)
fs.writeFile('build/StealAnEgg.rbxlx',xml)
print('PASS packaged place: visible editor map, 27 exact scripts, binary/XML roundtrip and runtime handover ('..#binary..' bytes)')
