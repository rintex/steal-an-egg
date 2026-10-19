local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local types = {'Instance','Enum','Vector2','Vector3','CFrame','Color3','ColorSequence','ColorSequenceKeypoint','NumberRange','NumberSequence','NumberSequenceKeypoint','UDim','UDim2','Font','BrickColor','Rect'}
local model = roblox.Instance.new('DataModel')
local world = model:GetService('Workspace')
local scope = getfenv()
local env = setmetatable({game=model,workspace=world}, {__index=scope})
for _, name in types do env[name] = roblox[name] end
-- Lune does not expose Roblox.Random. A deterministic offline-only generator
-- exercises generated geometry, but does not assert identical Roblox samples.
env.Random = {new=function(seed)
 local state=math.floor(seed or 1)%2147483647
 local function unit() state=(state*48271)%2147483647; return (state-1)/2147483646 end
 return {NextNumber=function(_,a,b) a=a or 0; b=b or 1; return a+(b-a)*unit() end,
  NextInteger=function(_,a,b) return math.min(b,a+math.floor(unit()*(b-a+1))) end}
end}
local source=fs.readFile('src/server/Services/WorldService.lua')
local chunk,err=loadstring(source,'WorldService.lua'); assert(chunk,err); setfenv(chunk,env)
local World=chunk()
local built=World.build()
assert(built.Map.Parent==world)
assert(#built.Nests==3)
for i=1,8 do
 local base=World.base(built,i,{UserId=i,DisplayName='Native Smoke '..i})
 assert(base.Pad and base.Incubator and base.Ward and base.Index==i)
end
local catalogChunk, catalogErr=loadstring(fs.readFile('src/shared/Config/EggConfig.lua'),'EggConfig.lua'); assert(catalogChunk,catalogErr); setfenv(catalogChunk,env)
local catalog=catalogChunk(); local eggCount=0
for id, config in catalog do
 local egg=World.egg(built.Eggs,config,roblox.Vector3.new(0,10,0),false)
 assert(egg.PrimaryPart and egg.PrimaryPart.Parent==egg)
 eggCount+=1
end
local counts={}; for _,object in model:GetDescendants() do counts[object.ClassName]=(counts[object.ClassName] or 0)+1 end
local json=require('@lune/serde')
print(json.encode('json',{Result='PASS',Instances=#model:GetDescendants(),Eggs=eggCount,Counts=counts},true))
-- Lune's legacy Font setter stores an enum in the FontFace alias. Normalize
-- this offline serializer representation; Roblox Engine supports the original setter.
for _,object in model:GetDescendants() do
 if object:IsA('TextLabel') then object.FontFace=roblox.Font.fromEnum(roblox.Enum.Font.GothamBold) end
end
local binary=roblox.serializePlace(model)
local roundtrip=roblox.deserializePlace(binary)
assert(#roundtrip:GetDescendants()==#model:GetDescendants(),'Native RBXL roundtrip changed instance count')
fs.writeFile('build/World-native-smoke.rbxl',binary)
print('RBXL roundtrip PASS ('..#binary..' bytes)')
