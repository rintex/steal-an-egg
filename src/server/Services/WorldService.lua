--!strict
-- Authored, asset-free geometry. Ornament stays static and nonblocking.
local Lighting = game:GetService("Lighting")
local World = {}
local C = {
    Grass=Color3.fromRGB(113,177,108), GrassLight=Color3.fromRGB(145,194,115),
    Pine=Color3.fromRGB(45,109,89), Leaf=Color3.fromRGB(79,150,99),
    Teal=Color3.fromRGB(48,106,111), Ink=Color3.fromRGB(35,63,73),
    Cream=Color3.fromRGB(244,231,198), Gold=Color3.fromRGB(241,190,88),
    Wood=Color3.fromRGB(140,104,76), Earth=Color3.fromRGB(121,98,80),
    Stone=Color3.fromRGB(133,159,151), Mint=Color3.fromRGB(132,225,189),
    Water=Color3.fromRGB(100,193,202), White=Color3.fromRGB(249,247,228),
}
local nestPositions={Vector3.new(0,1,132),Vector3.new(-43,1,200),Vector3.new(51,1,226)}
function World.part(parent, name, size, cf, color, material, shape)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size; p.CFrame=cf; p.Color=color
    p.Anchored=true; p.Material=material or Enum.Material.SmoothPlastic
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    if shape then p.Shape=shape end
    p.Parent=parent
    return p
end
local function decor(parent,name,size,cf,color,material,shape)
    local p=World.part(parent,name,size,cf,color,material,shape)
    p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
    return p
end
local function disc(parent,name,pos,radius,height,color,material,blocking)
    local create=if blocking then World.part else decor
    return create(parent,name,Vector3.new(height,radius*2,radius*2),
        CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2),color,material,Enum.PartType.Cylinder)
end
local function ring(parent,name,pos,radius,width,color,segments)
    local count=segments or 12
    for i=1,count do
        local a=(i-.5)*math.pi*2/count
        decor(parent,name,Vector3.new(width,.18,2*radius*math.tan(math.pi/count)+.08),
            CFrame.new(pos+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius))*CFrame.Angles(0,-a,0),color)
    end
end
function World.label(part, text, color)
    local gui=Instance.new("BillboardGui"); gui.Name="Label"; gui.Size=UDim2.fromOffset(246,68)
    gui.StudsOffset=Vector3.new(0,3,0); gui.MaxDistance=80; gui.AlwaysOnTop=false; gui.Parent=part
    local l=Instance.new("TextLabel"); l.Size=UDim2.fromScale(1,1); l.BackgroundTransparency=1
    l.Text=text; l.TextColor3=color or C.Cream; l.TextStrokeColor3=C.Ink; l.TextStrokeTransparency=.18
    l.Font=Enum.Font.GothamBold; l.TextScaled=true; l.Parent=gui
    local limit=Instance.new("UITextSizeConstraint"); limit.MaxTextSize=21; limit.MinTextSize=11; limit.Parent=l
    return l
end
function World.prompt(part, action, object, hold, callback)
    local p=Instance.new("ProximityPrompt"); p.ActionText=action; p.ObjectText=object
    p.HoldDuration=hold; p.MaxActivationDistance=10; p.RequiresLineOfSight=true; p.Parent=part
    local began=setmetatable({},{__mode="k"})
    local function validRoot(player)
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not p.Enabled or not part:IsDescendantOf(workspace) or not root or not root:IsA("BasePart")
            or not humanoid or humanoid.Health<=0 or (root.Position-part.Position).Magnitude>12 then return nil end
        return root
    end
    p.PromptButtonHoldBegan:Connect(function(player)
        if validRoot(player) then began[player]={At=os.clock(),Character=player.Character} end
    end)
    p.PromptButtonHoldEnded:Connect(function(player)
        local stamp=began[player]
        -- Touch/gamepad may deliver HoldEnded before the final Triggered event.
        task.delay(.45,function() if began[player]==stamp then began[player]=nil end end)
    end)
    p.Triggered:Connect(function(player)
        local root=validRoot(player); if not root then return end
        local stamp=began[player]
        if hold>0 then
            if not stamp or stamp.Character~=player.Character then return end
            local elapsed=os.clock()-stamp.At
            if elapsed<math.max(0,hold-.15) or elapsed>hold+4 then return end
        end
        local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances={player.Character}
        local ray=workspace:Raycast(root.Position,part.Position-root.Position,params)
        if ray and ray.Instance~=part and not (part.Parent:IsA("Model") and ray.Instance:IsDescendantOf(part.Parent)) then return end
        began[player]=nil; callback(player)
    end)
    return p
end
function World.egg(parent, config, pos, mutation)
    local color=Color3.fromRGB(table.unpack(config.Color)); local size=config.Size
    local model=Instance.new("Model"); model.Name="Egg_"..config.Id; model.Parent=parent
    local p=World.part(model,"Egg",Vector3.new(2.1,2.8,2.1)*size,CFrame.new(pos),color,nil,Enum.PartType.Ball)
    p.CanCollide=false; p.CanTouch=false; p.Massless=true; model.PrimaryPart=p
    local accent=if config.Rarity=="COMMON" then C.Pine else color:Lerp(C.White,.72)
    local function ornament(name,dimensions,offset,shade,shape,rotation)
        local detail=decor(model,name,dimensions*size,p.CFrame*CFrame.new(offset*size)*(rotation or CFrame.identity),shade,nil,shape)
        detail.Massless=true
        local weld=Instance.new("WeldConstraint"); weld.Part0=p; weld.Part1=detail; weld.Parent=detail
        detail.Anchored=false; return detail
    end
    local pattern=string.lower(config.Pattern or "Spots")
    local specialRing=pattern=="rings" or pattern=="stripes" or pattern=="swirl" or config.Id=="honey" or config.Id=="sunseed" or config.Id=="orbit"
    if specialRing then
        for _,y in ipairs({-.52,.37}) do
            local radius=math.sqrt(1-(y/1.4)^2)*1.07
            ornament("ShellBand",Vector3.new(.1,radius*2,radius*2),Vector3.new(0,y,0),accent,Enum.PartType.Cylinder,CFrame.Angles(0,0,math.pi/2))
        end
    end
    for i=1,if specialRing then 4 else 7 do
        local angle=i*2.39996; local y=((i%3)-1)*.48
        local radius=math.sqrt(1-(y/1.4)^2)*1.035
        local offset=Vector3.new(math.cos(angle)*radius,y,math.sin(angle)*radius)
        local orientation=CFrame.lookAt(Vector3.zero,Vector3.new(offset.X,offset.Y*.6,offset.Z))
        ornament("ShellMark",Vector3.new(.29+(i%2)*.12,.38,.12),offset,accent,Enum.PartType.Ball,orientation)
    end
    if config.Id=="clover" or config.Id=="moonbud" or pattern=="leaves" then
        for i=1,3 do
            local a=i*math.pi*2/3
            ornament("LeafCrown",Vector3.new(.36,.13,.65),Vector3.new(math.sin(a)*.21,1.38,math.cos(a)*.21),
                if config.Id=="clover" then C.Leaf else accent,Enum.PartType.Ball,CFrame.Angles(0,a,.18))
        end
    end
    if config.Rarity~="COMMON" and config.Rarity~="UNCOMMON" then
        local light=Instance.new("PointLight"); light.Color=color; light.Range=6; light.Brightness=.4; light.Shadows=false; light.Parent=p
    end
    if config.Rarity=="LEGENDARY" or config.Rarity=="SECRET" or config.Rarity=="MYTHIC" or config.Rarity=="DIVINE" or mutation then
        local emitter=Instance.new("ParticleEmitter"); emitter.Name="RareSparkles"
        emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
        emitter.Rate=2; emitter.Lifetime=NumberRange.new(.55,.85); emitter.Speed=NumberRange.new(.25,.6)
        emitter.LightEmission=.5; emitter.Color=ColorSequence.new(accent)
        emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,0)}); emitter.Parent=p
    end
    if mutation then
        local h=Instance.new("Highlight"); h.FillTransparency=.88; h.OutlineTransparency=.35
        h.OutlineColor=C.Gold; h.DepthMode=Enum.HighlightDepthMode.Occluded; h.Parent=model
    end
    return model
end
local function lamp(parent,pos)
    decor(parent,"LanternFoot",Vector3.new(1.5,.5,1.5),CFrame.new(pos+Vector3.new(0,.9,0)),C.Teal)
    decor(parent,"LanternPost",Vector3.new(.38,6,.38),CFrame.new(pos+Vector3.new(0,3.9,0)),C.Teal)
    decor(parent,"LanternGlass",Vector3.new(1.1,1.35,1.1),CFrame.new(pos+Vector3.new(0,7.2,0)),C.Gold,Enum.Material.Neon)
    decor(parent,"LanternCap",Vector3.new(1.7,.32,1.7),CFrame.new(pos+Vector3.new(0,8,0)),C.Teal)
end
local function sign(parent,pos,title,subtitle)
    decor(parent,"SignPost",Vector3.new(.8,5.8,.8),CFrame.new(pos+Vector3.new(0,3,0)),C.Wood)
    local face=decor(parent,"Wayfinding",Vector3.new(10,4,.6),CFrame.new(pos+Vector3.new(0,5.6,0)),C.Teal)
    decor(parent,"SignCap",Vector3.new(10.5,.25,.8),face.CFrame*CFrame.new(0,2.1,0),C.Gold)
    local text=World.label(face,title.."\n"..subtitle,C.White)
    text.Parent.StudsOffset=Vector3.new(0,.1,0); text.Parent.Size=UDim2.fromOffset(225,58)
    return face,text
end
local function tree(parent,pos,scale,index)
    local frame=CFrame.new(pos)*CFrame.Angles(0,index*.79,0)
    World.part(parent,"CloverTrunk",Vector3.new(1.9,7,1.9)*scale,frame*CFrame.new(0,4*scale,0),C.Wood,Enum.Material.Wood)
    for j=1,3 do
        local a=j*math.pi*2/3
        decor(parent,"LeafCloud",Vector3.new(8.2,7,8)*scale,
            frame*CFrame.new(math.sin(a)*2.4*scale,(9+(j%2))*scale,math.cos(a)*2.4*scale),
            if j==2 then C.GrassLight else C.Leaf,nil,Enum.PartType.Ball)
    end
    decor(parent,"CloverCrown",Vector3.new(7,6,7)*scale,frame*CFrame.new(0,13*scale,0),C.Leaf,nil,Enum.PartType.Ball)
end
local function clearMeadow(pos,margin)
    if math.abs(pos.X)<18 then return false end
    for _,nest in ipairs(nestPositions) do
        if (Vector3.new(pos.X,1,pos.Z)-nest).Magnitude<margin then return false end
        if (Vector3.new(pos.X,1,pos.Z)-(nest+Vector3.new(10,0,5))).Magnitude<margin then return false end
    end
    return true
end
-- Packaged places contain this exact geometry for the editor. Reuse it at
-- runtime and remove only explicitly tagged display actors, never user objects.
local function preparedWorld()
    local map=workspace:FindFirstChild("Map")
    if not map or map:GetAttribute("HeistBakedVersion")~=1 then return nil end
    local hub=map:FindFirstChild("Hub")
    local bases=map:FindFirstChild("PlayerBases")
    local eggs=map:FindFirstChild("Eggs")
    local nests=map:FindFirstChild("Nests")
    local biomes=map:FindFirstChild("Biomes")
    local meadow=biomes and biomes:FindFirstChild("GreenMeadow")
    local secret=meadow and meadow:FindFirstChild("SecretShrine")
    local board=hub and hub:FindFirstChild("ServerScores")
    local gui=board and board:FindFirstChild("Label")
    local boardText=gui and gui:FindFirstChildWhichIsA("TextLabel")
    if not hub or not bases or not eggs or not nests or not secret or not boardText then return nil end
    local entries={}
    for i=1,3 do
        local nest=nests:FindFirstChild("Nest"..i)
        if not nest or not nest:IsA("BasePart") then return nil end
        table.insert(entries,{Part=nest,Home=nest.CFrame.Position+Vector3.new(10,3,5),Index=i})
    end
    for _,folder in ipairs({map,bases,eggs}) do
        for _,object in ipairs(folder:GetChildren()) do
            if object:GetAttribute("HeistEditorDisplay")==true then object:Destroy() end
        end
    end
    return {Map=map,Hub=hub,Bases=bases,Eggs=eggs,Nests=entries,Secret=secret,Board=boardText}
end
function World.build()
    local existing=preparedWorld()
    if existing then return existing end
    local previous=workspace:FindFirstChild("Map")
    if previous and previous:GetAttribute("HeistBakedVersion")==1 then previous:Destroy() end
    local map=Instance.new("Folder"); map.Name="Map"; map.Parent=workspace
    local hub=Instance.new("Folder"); hub.Name="Hub"; hub.Parent=map
    local biomes=Instance.new("Folder"); biomes.Name="Biomes"; biomes.Parent=map
    local meadow=Instance.new("Folder"); meadow.Name="GreenMeadow"; meadow.Parent=biomes
    local bases=Instance.new("Folder"); bases.Name="PlayerBases"; bases.Parent=map
    local nests=Instance.new("Folder"); nests.Name="Nests"; nests.Parent=map
    local objects=Instance.new("Folder"); objects.Name="Eggs"; objects.Parent=map
    World.part(hub,"HubIsland",Vector3.new(150,8,230),CFrame.new(0,-4,-40),C.Teal)
    World.part(hub,"IslandFoundation",Vector3.new(142,7,222),CFrame.new(0,-10,-40),C.Ink)
    World.part(hub,"Plaza",Vector3.new(142,1,224),CFrame.new(0,.15,-40),C.Cream,Enum.Material.Sandstone)
    for _,x in ipairs({-73,73}) do
        decor(hub,"GardenBorder",Vector3.new(3,1,226),CFrame.new(x,.6,-40),C.Pine)
        decor(hub,"GoldIslandTrim",Vector3.new(.35,.35,230),CFrame.new(x*1.022,-2,-40),C.Gold)
    end
    World.part(meadow,"MeadowIsland",Vector3.new(190,9,185),CFrame.new(0,-4,166),C.Grass,Enum.Material.Grass)
    World.part(meadow,"EarthRim",Vector3.new(196,6,190),CFrame.new(0,-9,166),C.Earth,Enum.Material.Slate)
    World.part(meadow,"DeepEarth",Vector3.new(180,6,177),CFrame.new(0,-14,166),C.Ink,Enum.Material.Slate)
    for _,x in ipairs({-91,91}) do
        decor(meadow,"MeadowLip",Vector3.new(5,1,180),CFrame.new(x,.2,166),C.GrassLight,Enum.Material.Grass)
    end
    decor(hub,"MainAvenue",Vector3.new(20,.12,143),CFrame.new(0,.72,-8),Color3.fromRGB(220,209,177))
    for _,z in ipairs({-110,-83,-56,-29}) do
        decor(hub,"BaseAvenue",Vector3.new(104,.12,5),CFrame.new(0,.76,z+6),Color3.fromRGB(226,215,186))
    end
    World.part(hub,"Bridge",Vector3.new(24,1,30),CFrame.new(0,.3,82),C.Wood,Enum.Material.WoodPlanks)
    for _,x in ipairs({-13,13}) do
        for _,z in ipairs({69,82,95}) do
            World.part(hub,"BridgePost",Vector3.new(.9,4,.9),CFrame.new(x,2.3,z),C.Teal)
            decor(hub,"BridgeFinial",Vector3.new(1.3,.7,1.3),CFrame.new(x,4.6,z),C.Gold,nil,Enum.PartType.Ball)
        end
        decor(hub,"BridgeRail",Vector3.new(.5,.65,28),CFrame.new(x,3,82),C.Cream)
    end
    for z=4,124,8 do
        decor(if z<97 then hub else meadow,"GoldenTrail",Vector3.new(4,.12,4.6),CFrame.new(0,.9,z),C.Gold)
    end
    local spawn=Instance.new("SpawnLocation"); spawn.Name="SpawnArea"; spawn.Size=Vector3.new(11,.4,11)
    spawn.CFrame=CFrame.new(0,1,0); spawn.Anchored=true; spawn.Neutral=true; spawn.Duration=3; spawn.Transparency=1; spawn.Parent=hub
    disc(hub,"ArrivalSeal",Vector3.new(0,.83,0),7,.16,C.Teal)
    ring(hub,"ArrivalInlay",Vector3.new(0,.97,0),7.2,.25,C.Gold,16)
    -- The fountain and oversized egg anchor the hub, behind the spawn.
    disc(hub,"FountainFoundation",Vector3.new(0,1,-30),12,.7,C.Teal,nil,true)
    disc(hub,"FountainBasin",Vector3.new(0,1.55,-30),10.9,.45,C.Cream)
    disc(hub,"StillWater",Vector3.new(0,1.84,-30),10.1,.12,C.Water,Enum.Material.Glass)
    ring(hub,"FountainRim",Vector3.new(0,2,-30),10.8,.65,C.Cream,20)
    disc(hub,"FountainPedestal",Vector3.new(0,3.1,-30),3,2.7,C.Teal)
    disc(hub,"PedestalGilt",Vector3.new(0,4.6,-30),3.4,.3,C.Gold)
    decor(hub,"HeistEggMonument",Vector3.new(5.7,7.7,5.7),CFrame.new(0,8.3,-30),C.Gold,Enum.Material.Metal,Enum.PartType.Ball)
    ring(hub,"MonumentHalo",Vector3.new(0,8,-30),4,.16,C.Cream,12)
    local emblem=decor(hub,"FountainPlaque",Vector3.new(7,.7,2),CFrame.new(0,2.1,-18),C.Teal)
    World.label(emblem,"STEAL AN EGG\nКлуб великих побегов",C.Gold)
    local gate=decor(hub,"MeadowGate",Vector3.new(25,2.4,3.4),CFrame.new(0,16,60),C.Teal)
    decor(hub,"GateCornice",Vector3.new(27,.5,4.2),CFrame.new(0,17.5,60),C.Gold)
    for _,x in ipairs({-12,12}) do
        World.part(hub,"GatePillar",Vector3.new(2.6,15,3.3),CFrame.new(x,7.5,60),C.Teal)
        decor(hub,"GateBase",Vector3.new(4.2,1.5,4.5),CFrame.new(x,.9,60),C.Cream)
        decor(hub,"GateMedallion",Vector3.new(1.4,1.8,.25),CFrame.new(x,12,58.2),C.Gold,nil,Enum.PartType.Ball)
    end
    local gateText=World.label(gate,"КЛЕВЕРНЫЕ ЛУГА\nУкради → убеги → вылупи",C.White)
    gateText.Parent.StudsOffset=Vector3.new(0,1.7,0)
    sign(hub,Vector3.new(18,.3,45),"ВПЕРЁД · ЛУГА","По золотой дорожке")
    sign(hub,Vector3.new(-18,.3,10),"УБЕЖИЩА · НАЗАД","Доставь яйцо на свою платформу")
    World.part(hub,"OutfitterDeck",Vector3.new(23,1,18),CFrame.new(-42,1,14),C.Wood,Enum.Material.WoodPlanks)
    World.part(hub,"Outfitter",Vector3.new(19,8,2),CFrame.new(-42,5.5,21),C.Teal)
    decor(hub,"ShopCounter",Vector3.new(17,3,3),CFrame.new(-42,3,8),C.Teal)
    decor(hub,"CounterTop",Vector3.new(18,.45,4),CFrame.new(-42,4.7,8),C.Cream)
    for i=1,6 do
        decor(hub,"ShopAwning",Vector3.new(3.5,.6,15),CFrame.new(-52.5+i*3,10,14)*CFrame.Angles(-.08,0,0),if i%2==0 then C.Gold else C.Cream)
    end
    for _,x in ipairs({-52,-32}) do decor(hub,"ShopPost",Vector3.new(.65,9,.65),CFrame.new(x,5.5,7),C.Teal) end
    sign(hub,Vector3.new(-42,6,22),"СНАРЯЖЕНИЕ","Улучшения в меню")
    for i=1,3 do
        disc(hub,"EquipmentStand",Vector3.new(-48+i*3,5.15,8),.8,.4,C.Gold)
        decor(hub,"EquipmentCrate",Vector3.new(1.3,1.2,1.4),CFrame.new(-48+i*3,5.9,8)*CFrame.Angles(0,i*.4,0),C.Mint)
    end
    local board=sign(hub,Vector3.new(38,.8,17),"ЕЖЕДНЕВНЫЕ ЦЕЛИ","3 доставки · 1 питомец"); board.Name="QuestBoard"
    local leaderboard,boardText=sign(hub,Vector3.new(38,.8,-1),"ЛУЧШИЕ ПОБЕГИ","Таблица игроков: Tab"); leaderboard.Name="ServerScores"
    disc(hub,"EventStage",Vector3.new(-42,1.1,41),8,1.1,C.Teal,nil,true)
    ring(hub,"EventTrim",Vector3.new(-42,1.75,41),7,.3,C.Gold,12)
    local event=decor(hub,"EventPlinth",Vector3.new(4,3,4),CFrame.new(-42,3,41),C.Gold)
    World.label(event,"ЗОЛОТАЯ ЛИХОРАДКА\nКаждые 5 минут",C.Gold)
    for _,pos in ipairs({Vector3.new(-23,0,-7),Vector3.new(23,0,-7),Vector3.new(-22,0,41),Vector3.new(24,0,27),
        Vector3.new(-23,0,-62),Vector3.new(23,0,-62),Vector3.new(-23,0,-117),Vector3.new(23,0,-117)}) do lamp(hub,pos) end
    local rng=Random.new(1907)
    for i=1,24 do
        local x=if i%2==0 then rng:NextNumber(28,85) else rng:NextNumber(-85,-28)
        local pos=Vector3.new(x,.5,rng:NextNumber(108,248))
        if clearMeadow(pos,22) then tree(meadow,pos,rng:NextNumber(.8,1.25),i) end
    end
    for i=1,28 do
        local pos=Vector3.new(rng:NextNumber(-86,86),.8,rng:NextNumber(104,250))
        if clearMeadow(pos,14) then
            decor(meadow,"FlowerLeaf",Vector3.new(1.3,.3,.7),CFrame.new(pos),C.Pine,nil,Enum.PartType.Ball)
            local shade=if i%3==0 then Color3.fromRGB(231,161,177) elseif i%3==1 then C.Gold else C.White
            for j=1,3 do
                local a=j*math.pi*2/3
                decor(meadow,"CloverPetal",Vector3.new(.55,.3,.55),CFrame.new(pos+Vector3.new(math.sin(a)*.28,.33,math.cos(a)*.28)),shade,nil,Enum.PartType.Ball)
            end
        end
    end
    for i=1,12 do
        local x=if i%2==0 then -87 else 87
        decor(meadow,"LayeredCliff",Vector3.new(12,8+(i%3)*3,12),CFrame.new(x,-1,98+i*12)*CFrame.Angles(.1,i*.73,.15),
            if i%2==0 then C.Stone else C.Earth,Enum.Material.Slate)
    end
    for _,v in ipairs({Vector3.new(-27,3,160),Vector3.new(32,3,182),Vector3.new(-27,2,229),Vector3.new(48,3,132)}) do
        World.part(meadow,"CoverRock",Vector3.new(11,6,8),CFrame.new(v)*CFrame.Angles(.12,v.Z,.12),C.Stone,Enum.Material.Slate,Enum.PartType.Ball)
        decor(meadow,"RockMoss",Vector3.new(8,1,5),CFrame.new(v+Vector3.new(0,2.5,0)),C.GrassLight,nil,Enum.PartType.Ball)
    end
    World.part(meadow,"FallenLog",Vector3.new(6,6,22),CFrame.new(-54,3.2,174)*CFrame.Angles(0,.3,0),C.Wood,Enum.Material.Wood)
    for z=130,215,14 do disc(meadow,"SecretSteps",Vector3.new(-71,.7,z),2.8,.25,C.Cream,nil,true) end
    disc(meadow,"ShrineFloor",Vector3.new(-73,.7,220),6,.4,C.Stone,nil,true)
    local secret=World.part(meadow,"SecretShrine",Vector3.new(3.4,2,3.4),CFrame.new(-73,1.7,220),C.Mint)
    for _,x in ipairs({-79,-67}) do decor(meadow,"ShrinePillar",Vector3.new(1.5,8,1.8),CFrame.new(x,4.7,224),C.Teal) end
    decor(meadow,"ShrineLintel",Vector3.new(15,2,3),CFrame.new(-73,9.6,224),C.Teal)
    decor(meadow,"ShrineJewel",Vector3.new(2,2.5,1),CFrame.new(-73,10.8,223),C.Gold,nil,Enum.PartType.Ball)
    World.label(secret,"ТРОПА ТИХИХ ШАГОВ\nИсследуй древний клевер",C.Mint)
    sign(meadow,Vector3.new(-23,.5,111),"ТИХАЯ ТРОПА · ВЛЕВО","Исследуй край острова")
    local nestsList={}
    for i,pos in ipairs(nestPositions) do
        disc(nests,"NestClearing",pos+Vector3.new(0,-.38,0),8.6,.2,Color3.fromRGB(177,188,117))
        local nest=disc(nests,"Nest"..i,pos,4.2,.7,C.Wood,nil,true)
        disc(nests,"NestStraw",pos+Vector3.new(0,.45,0),3.65,.25,C.Gold)
        for j=1,12 do
            local a=j*math.pi/6
            decor(nests,"WovenTwig",Vector3.new(3.2,.6,.6),CFrame.new(pos+Vector3.new(math.sin(a)*3.6,.7,math.cos(a)*3.6))*CFrame.Angles(.1,a,.12),
                if j%2==0 then C.Wood else Color3.fromRGB(202,159,96),Enum.Material.Wood)
        end
        for j=1,3 do decor(nests,"LooseStraw",Vector3.new(2,.12,.24),CFrame.new(pos+Vector3.new(j-2,.63,(j%2)*1.3-.6))*CFrame.Angles(0,j,0),C.Cream) end
        table.insert(nestsList,{Part=nest,Home=pos+Vector3.new(10,3,5),Index=i})
    end
    for _,name in ipairs({"HeistAtmosphere","HeistGrade","HeistBloom","HeistSunRays"}) do
        local old=Lighting:FindFirstChild(name); if old then old:Destroy() end
    end
    local atmosphere=Instance.new("Atmosphere"); atmosphere.Name="HeistAtmosphere"
    atmosphere.Density=.19; atmosphere.Offset=.1; atmosphere.Color=Color3.fromRGB(219,237,235)
    atmosphere.Decay=Color3.fromRGB(150,177,182); atmosphere.Glare=.08; atmosphere.Haze=.7; atmosphere.Parent=Lighting
    local cc=Instance.new("ColorCorrectionEffect"); cc.Name="HeistGrade"
    cc.Saturation=.08; cc.Contrast=.035; cc.Brightness=.015; cc.TintColor=Color3.fromRGB(255,250,240); cc.Parent=Lighting
    local bloom=Instance.new("BloomEffect"); bloom.Name="HeistBloom"; bloom.Intensity=.14; bloom.Size=20; bloom.Threshold=1.45; bloom.Parent=Lighting
    local rays=Instance.new("SunRaysEffect"); rays.Name="HeistSunRays"; rays.Intensity=.025; rays.Spread=.6; rays.Parent=Lighting
    Lighting.ClockTime=14.2; Lighting.Brightness=2.2; Lighting.GlobalShadows=true
    Lighting.Ambient=Color3.fromRGB(115,133,143); Lighting.OutdoorAmbient=Color3.fromRGB(148,162,153)
    Lighting.EnvironmentDiffuseScale=.7; Lighting.EnvironmentSpecularScale=.45
    return {Map=map,Hub=hub,Bases=bases,Eggs=objects,Nests=nestsList,Secret=secret,Board=boardText}
end
function World.base(world, index, player)
    local x=if index%2==0 then 51 else -51; local z=-29-math.floor((index-1)/2)*27
    local model=Instance.new("Model"); model.Name="Base_"..player.UserId; model.Parent=world.Bases
    local tint=if index%2==0 then C.Teal else Color3.fromRGB(78,118,111)
    World.part(model,"Foundation",Vector3.new(31,.8,25),CFrame.new(x,.6,z),C.Teal)
    World.part(model,"Deck",Vector3.new(29,1,24),CFrame.new(x,1,z),C.Cream,Enum.Material.Sandstone)
    World.part(model,"BackWall",Vector3.new(29,8.5,1),CFrame.new(x,5.6,z-12),tint)
    decor(model,"BackWallTrim",Vector3.new(29,.35,.3),CFrame.new(x,8.3,z-11.4),C.Gold)
    decor(model,"Canopy",Vector3.new(31,1,12),CFrame.new(x,10.3,z-6)*CFrame.Angles(-.055,0,0),tint)
    decor(model,"CanopyFascia",Vector3.new(31,.65,.5),CFrame.new(x,9.9,z),C.Gold)
    for _,offset in ipairs({-13.5,13.5}) do
        decor(model,"CanopyPost",Vector3.new(.7,8,.7),CFrame.new(x+offset,5.5,z-.4),tint)
        decor(model,"CornerCap",Vector3.new(1.2,.5,1.2),CFrame.new(x+offset,1.8,z+10.5),C.Gold)
    end
    local pad=World.part(model,"DeliveryPad",Vector3.new(12,.25,9),CFrame.new(x,1.7,z+5),C.Mint)
    decor(model,"DeliveryMark",Vector3.new(8,.04,.3),pad.CFrame*CFrame.new(0,.15,3.3),C.Teal)
    for _,side in ipairs({-1,1}) do decor(model,"DeliveryEdge",Vector3.new(.25,.08,8),pad.CFrame*CFrame.new(side*5.6,.17,0),C.Teal) end
    local name=decor(model,"OwnerPlaque",Vector3.new(10,1,.5),CFrame.new(x,7.4,z-11.3),C.Teal)
    local ownerText=World.label(name,player.DisplayName.."\nУБЕЖИЩЕ "..string.format("%02d",index),C.White)
    ownerText.Parent.StudsOffset=Vector3.new(0,.2,0); ownerText.Parent.MaxDistance=65
    local padText=World.label(pad,"ДОСТАВКА ЯЙЦА",C.Mint); padText.Parent.StudsOffset=Vector3.new(0,1.2,0); padText.Parent.MaxDistance=28
    disc(model,"IncubatorFoot",Vector3.new(x-8,1.8,z-5),3,.5,tint)
    local incubator=World.part(model,"Incubator",Vector3.new(4.7,1.5,4.7),CFrame.new(x-8,2.6,z-5),C.Gold)
    disc(model,"IncubatorNest",Vector3.new(x-8,3.45,z-5),2.15,.25,C.Cream)
    for _,offset in ipairs({-2.4,2.4}) do decor(model,"IncubatorHoop",Vector3.new(.3,3.2,.3),CFrame.new(x-8+offset,4.15,z-5),C.Teal) end
    decor(model,"IncubatorLamp",Vector3.new(5.5,.35,1),CFrame.new(x-8,5.8,z-5),C.Mint,Enum.Material.Neon)
    local incubatorText=World.label(incubator,"ИНКУБАТОР",C.Gold); incubatorText.Parent.MaxDistance=35
    local ward=World.part(model,"Ward",Vector3.new(1.5,2.5,1.5),CFrame.new(x+11,3,z+2),C.Mint)
    disc(model,"WardFoot",Vector3.new(x+11,1.8,z+2),1.3,.4,tint)
    decor(model,"WardBell",Vector3.new(2,1.6,2),CFrame.new(x+11,4.4,z+2),C.Gold,Enum.Material.Metal,Enum.PartType.Ball)
    local wardText=World.label(ward,"ЩИТ",C.Mint); wardText.Parent.MaxDistance=26
    local display=World.part(model,"PetPedestal",Vector3.new(6,1,6),CFrame.new(x+7,2,z-5),tint)
    disc(model,"PetDisplayTrim",Vector3.new(x+7,2.55,z-5),2.8,.16,C.Gold)
    return {Model=model,Pad=pad,Incubator=incubator,Ward=ward,Display=display,Center=Vector3.new(x,2,z),Index=index}
end
return World
