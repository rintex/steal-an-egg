-- Native Roblox data types/instances via Lune; events and layout engine are controlled stubs.
-- This catches real construction/action/lifecycle errors, but does NOT render pixels or run physics.
local fs=require('@lune/fs')
local r=require('@lune/roblox')
local screen=r.Vector2.new(1280,720)
local signals=setmetatable({},{__mode='k'})
local function signal()
 local handlers={}
 return {Connect=function(_,fn)
  local c={Connected=true,Disconnect=function(self) self.Connected=false end}
  table.insert(handlers,{c,fn}); return c
 end,Fire=function(_,...)
  for _,item in ipairs(handlers) do if item[1].Connected then item[2](...) end end
 end}
end
local function event(instance,key)
 if not signals[instance] then signals[instance]={} end
 if not signals[instance][key] then signals[instance][key]=signal() end
 return signals[instance][key]
end
for _,name in ipairs({'Destroying','MouseEnter','MouseLeave','MouseButton1Down','MouseButton1Up','SelectionGained','SelectionLost','Activated','DescendantAdded'}) do
 r.implementProperty('Instance',name,function(instance) return event(instance,name) end)
end
r.implementMethod('Instance','GetPropertyChangedSignal',function(instance,key) return event(instance,'prop_'..key) end)
r.implementMethod('Instance','GetAttributeChangedSignal',function(instance,key) return event(instance,'attr_'..key) end)
r.implementMethod('Instance','WaitForChild',function(instance,name) return assert(instance:FindFirstChild(name),name) end)
local function absoluteSize(object)
 local parent=object.Parent
 local psize=if parent and parent:IsA('GuiObject') then absoluteSize(parent) else screen
 local s=object.Size
 return r.Vector2.new(s.X.Scale*psize.X+s.X.Offset,s.Y.Scale*psize.Y+s.Y.Offset)
end
r.implementProperty('GuiObject','AbsoluteSize',absoluteSize)
local function absolutePosition(object)
 local parent=object.Parent
 local ppos=if parent and parent:IsA('GuiObject') then absolutePosition(parent) else r.Vector2.zero
 local psize=if parent and parent:IsA('GuiObject') then absoluteSize(parent) else screen
 local pos=object.Position
 local x,y=pos.X.Scale*psize.X+pos.X.Offset,pos.Y.Scale*psize.Y+pos.Y.Offset
 local grid=parent and parent:FindFirstChildOfClass('UIGridLayout')
 if grid and object:IsA('Frame') then
  local cw,ch=grid.CellSize.X.Offset,grid.CellSize.Y.Offset
  local px,py=grid.CellPadding.X.Offset,grid.CellPadding.Y.Offset
  local columns=math.max(1,math.floor((psize.X+px)/(cw+px)))
  local index=math.max(0,object.LayoutOrder-1)
  x=(index%columns)*(cw+px); y=math.floor(index/columns)*(ch+py)
 end
 local size=absoluteSize(object)
 local scroll=if parent and parent:IsA('ScrollingFrame') then parent.CanvasPosition else r.Vector2.zero
 return ppos+r.Vector2.new(x-size.X*object.AnchorPoint.X,y-size.Y*object.AnchorPoint.Y)-scroll
end
r.implementProperty('GuiObject','AbsolutePosition',absolutePosition)
local playerGui=r.Instance.new('PlayerGui')
local character=r.Instance.new('Model')
local root=r.Instance.new('Part'); root.Name='HumanoidRootPart'; root.Position=r.Vector3.new(-59,4,-34); root.Parent=character
local player={Character=character,CharacterAdded=signal(),CharacterRemoving=signal(),WaitForChild=function(_,name) assert(name=='PlayerGui'); return playerGui end}
local input={PreferredInput=r.Enum.PreferredInput.KeyboardAndMouse,InputBegan=signal(),GetFocusedTextBox=function() return nil end}
function input:GetPropertyChangedSignal(name) return event(self,name) end
local guiService={PreferredTransparency=1,ReducedMotionEnabled=true}
function guiService:GetPropertyChangedSignal(name) return event(self,name) end
local run={Heartbeat=signal(),PreSimulation=signal(),RenderStepped=signal()}
local tween={Create=function(_,target,_,goal)
 return {Play=function() for key,value in pairs(goal) do target[key]=value end end,Cancel=function() end}
end}
local shared={Config={EggConfig='Config/EggConfig',EconomyConfig='Config/EconomyConfig',UpgradeConfig='Config/UpgradeConfig',AudioConfig='Config/AudioConfig'},Domain={Rules='Domain/Rules'}}
local services={Players={LocalPlayer=player},UserInputService=input,GuiService=guiService,RunService=run,TweenService=tween,
 ReplicatedStorage={Shared=shared,WaitForChild=function(_,name) assert(name=='Shared'); return shared end},SoundService={},Debris={}}
local world=r.Instance.new('Workspace')
local environment=setmetatable({game={GetService=function(_,name) return assert(services[name],name) end},workspace=world},{__index=getfenv()})
for key,value in pairs(r) do environment[key]=value end
-- Lune has no layout engine. Explicitly provide computed read-only layout outputs.
environment.Instance={new=function(class)
 local object=r.Instance.new(class)
 if object:IsA('GuiObject') then object.AbsoluteSize=screen; object.AbsolutePosition=r.Vector2.zero end
 return object
end}
local deferred,delayed={},{}
environment.task={defer=function(fn) table.insert(deferred,fn) end,delay=function(_,fn) table.insert(delayed,fn) end}
environment.TweenInfo={new=function(...) return {...} end}
local cache={}
local function module(name)
 if cache[name] then return cache[name] end
 local client=not string.find(name,'/',1,true)
 local path=if client then 'src/client/Controllers/'..name..'.lua' else 'src/shared/'..name..'.lua'
 local chunk,err=loadstring(fs.readFile(path),path); assert(chunk,err)
 local scope=setmetatable({script={Parent={UITheme='UITheme',UILayout='UILayout',UIComponents='UIComponents'}}},{__index=environment})
 scope.require=module; setfenv(chunk,scope); cache[name]=chunk(); return cache[name]
end
local function flush()
 local callbacks=deferred; deferred={}
 for _,fn in ipairs(callbacks) do fn() end
end
local sent={}
local ui=module('UIController').new({Action={FireServer=function(_,...) table.insert(sent,{...}) end}})
local profile=module('Domain/Rules').newProfile(os.time())
profile.Coins=1000
profile.OwnedEggs={{Uid='same-uid',Id='clover',ReadyAt=0,Mutation=false}}
local state={Profile=profile,Stamina=100,MaxStamina=100,Combo=0,Dash=0,Intercept=0,Protection=180,Safe=true,Carry=false,
 Event=false,EventSeconds=300,Memory=true,Base={X=-51,Z=-29,IncubatorX=-59,IncubatorY=2.5,IncubatorZ=-34},ServerTime=os.time()}
ui:update(state)
local function settle()
 for _,object in ui.Gui:GetDescendants() do
  if object:IsA('GuiObject') then object.AbsoluteSize=absoluteSize(object); object.AbsolutePosition=absolutePosition(object) end
 end
 flush()
end
for _,dims in ipairs({{320,568},{390,844},{568,320},{844,390},{1280,720}}) do
 screen=r.Vector2.new(dims[1],dims[2]); ui.Canvas.AbsoluteSize=screen; ui:resize(); settle()
 for _,tab in ipairs({'Collection','Upgrades','Quests','Achievements','Settings'}) do
  ui:open(tab,true); settle(); ui:refreshDynamic()
  assert(ui.Panel.AbsoluteSize.X<=screen.X and ui.Panel.AbsoluteSize.Y<=screen.Y)
 end
 ui:close()
end
ui:open('Collection'); settle()
local original=ui.Cards['same-uid'].Frame
state.Profile.Coins+=5; ui:update(state); settle()
assert(ui.Cards['same-uid'].Frame==original,'ordinary updates must retain card identity')
profile.OwnedEggs={}; profile.Pets={{Uid='same-uid',Id='clover_pet',EggId='clover',Mutation=false}}
ui:update(state); settle()
assert(ui.Cards['same-uid'].Kind=='Pets' and ui.Cards['same-uid'].Frame~=original,'hatching must replace egg actions with pet actions')
assert(ui.Cards['same-uid'].Button.Text=='✓ Активен')
-- Even an unusually large visible region must retain the eight-preview cap.
for i=2,100 do table.insert(profile.Pets,{Uid='pet-'..i,Id='clover_pet',EggId='clover',Mutation=false}) end
ui:update(state); settle()
local inventory=ui.Views.Collection.Scroll
inventory.AbsolutePosition=r.Vector2.zero; inventory.AbsoluteSize=r.Vector2.new(2000,20000)
for _,card in pairs(ui.Cards) do card.Frame.AbsolutePosition=r.Vector2.new(0,20) end
ui:updateViewports()
local previews=0
for _,card in pairs(ui.Cards) do if card.Viewport then previews+=1 end end
assert(previews==8,'large collections must not allocate more than eight 3D scenes')
ui:close()
for _,card in pairs(ui.Cards) do assert(card.Viewport==nil,'closed menus must release 3D previews') end
-- Build reveal using native Instances as well, then skip before delayed callbacks.
local effects=module('EffectsController').new(ui)
effects:hatch('clover'); assert(effects.Hatch and ui.Gui:GetAttribute('HatchOpen'))
effects:closeHatch(); assert(not effects.Hatch and not ui.Gui:GetAttribute('HatchOpen'))
for _,fn in ipairs(delayed) do fn() end
assert(effects.Hatch==nil,'skipped reveal must not revive when old callbacks run')
effects:Destroy()
print('PASS native UI integration: 5 viewports × 5 panels, stable updates, egg-to-pet transition, viewport cleanup, hatch skip lifecycle')
