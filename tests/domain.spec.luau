local Rules=require("../src/shared/Domain/Rules")
local State=require("../src/shared/Domain/EggState")
local Profile=require("../src/shared/Domain/Profile")
local Incubation=require("../src/shared/Domain/Incubation")
local Eggs=require("../src/shared/Config/EggConfig")
local Upgrades=require("../src/shared/Config/UpgradeConfig")
local passed=0
local function test(name,f)
    local ok,err=pcall(f)
    if not ok then error("FAIL "..name..": "..tostring(err)) end
    passed+=1; print("PASS "..name)
end
local function egg() return {State="Nest",Uid="egg-a",Id="clover",LockUntil=0,Transfers=0} end
local function player() return {Alive=true,Carrying=false} end
test("catalog: 24 unique eggs, valid values and 8 rarities",function()
    local count=0; local rarities={}
    for id,e in pairs(Eggs) do
        count+=1; assert(e.Id==id and e.Value>0 and e.Weight>0 and e.SpawnWeight>0 and e.HatchTime>=3)
        assert(#e.Color==3 and #e.Pets>0 and e.Size>0); rarities[e.Rarity]=true
    end
    local n=0; for _ in pairs(rarities) do n+=1 end
    assert(count==24 and n==8)
end)
test("weighted spawn selects only configured biome at boundary rolls",function()
    for i=0,10000 do
        local id=Rules.roll(Eggs,"Meadow",i/10000)
        assert(id and Eggs[id].Biome=="Meadow")
    end
end)
test("pickup rejects distance, death and occupied hands",function()
    assert(Rules.pickup(egg(),player(),10,10))
    assert(not Rules.pickup(egg(),player(),10,11.01))
    assert(not Rules.pickup(egg(),{Alive=false},10,1))
    assert(not Rules.pickup(egg(),{Alive=true,Carrying=true},10,1))
end)
test("two players claim one egg: only first wins",function()
    local e=egg(); assert(State.claim(e,1,10)); assert(not State.claim(e,2,10)); assert(e.Owner==1)
end)
test("drop removes owner and enforces pickup grace",function()
    local e=egg(); State.claim(e,1,10); assert(State.drop(e,11)); assert(e.Owner==nil)
    assert(not State.claim(e,2,12)); assert(State.claim(e,2,12.5)); assert(e.Owner==2)
end)
test("transfer budget prevents endless stealing",function()
    local e=egg(); State.claim(e,1,1)
    for i=1,3 do assert(State.drop(e,i*3)); assert(State.claim(e,i+1,i*3+2)) end
    assert(State.drop(e,20)); assert(not State.claim(e,9,30))
end)
test("only owner may deliver; delivery is one-shot",function()
    local e=egg(); State.claim(e,1,0)
    assert(not State.deliver(e,2)); assert(State.deliver(e,1)); assert(not State.deliver(e,1)); assert(not State.claim(e,2,30))
end)
test("death and disconnect cleanup can drop once without duplication",function()
    local e=egg(); State.claim(e,1,0); assert(State.drop(e,1)); assert(not State.drop(e,1)); assert(e.State=="Dropped")
end)
test("safe zones, novice shield and range block interception",function()
    local a={Alive=true,Carrying=false,Safe=false,Protected=false,InterceptAt=0}
    local v={Alive=true,Carrying=true,Safe=false,Protected=false,ShieldUntil=0}
    assert(Rules.canIntercept(a,v,100,6))
    v.Safe=true; assert(not Rules.canIntercept(a,v,100,6)); v.Safe=false
    v.Protected=true; assert(not Rules.canIntercept(a,v,100,6)); v.Protected=false
    v.ShieldUntil=101; assert(not Rules.canIntercept(a,v,100,6)); v.ShieldUntil=0
    assert(not Rules.canIntercept(a,v,100,7.1)); a.Carrying=true; assert(not Rules.canIntercept(a,v,100,1))
end)
test("combo, mutations and events have bounded rewards",function()
    assert(Rules.reward(100,0,false,false)==100)
    assert(Rules.reward(100,100,false,false)==125)
    assert(Rules.reward(100,5,true,true)<=172)
end)
test("buy uses authoritative price; insufficient funds cannot change state",function()
    local p=Rules.newProfile(0)
    assert(not Rules.buy(p,"Speed",Upgrades)); assert(p.Coins==0 and p.Upgrades.Speed==0)
    p.Coins=60; assert(Rules.buy(p,"Speed",Upgrades)); assert(p.Coins==0 and p.Upgrades.Speed==1)
    assert(not Rules.buy(p,"Fake",Upgrades)); p.Coins=100000
    for _=1,3 do assert(Rules.buy(p,"Speed",Upgrades)) end
    local coins=p.Coins; assert(not Rules.buy(p,"Speed",Upgrades)); assert(p.Coins==coins)
end)
test("incubation is idempotent and completes once at server deadline",function()
    local p=Rules.newProfile(0); p.OwnedEggs={{Uid="a",Id="clover",ReadyAt=0}}
    assert(Incubation.start(p,"a",100,Eggs)); assert(p.OwnedEggs[1].ReadyAt==108)
    assert(not Incubation.start(p,"a",102,Eggs)); assert(#Incubation.finish(p,107,100)==0)
    assert(#Incubation.finish(p,108,100)==1); assert(#p.Pets==1 and #p.OwnedEggs==0)
    assert(#Incubation.finish(p,109,100)==0); assert(p.Pets[1].Uid=="a")
end)
test("full pet collection retains ready egg instead of deleting it",function()
    local p=Rules.newProfile(0); p.OwnedEggs={{Uid="b",Id="clover",ReadyAt=1}}
    p.Pets={{Uid="a"}}; assert(#Incubation.finish(p,10,1)==0); assert(#p.OwnedEggs==1)
end)
test("daily quests reset precisely at UTC midnight",function()
    local p=Rules.newProfile(86399); p.QuestProgress.Deliveries=3; p.QuestProgress.Claimed=true
    assert(Rules.daily(p,86399).Claimed); assert(not Rules.daily(p,86400).Claimed)
    assert(p.QuestProgress.Deliveries==0 and p.QuestProgress.Day==1)
end)
test("XP carries over correctly through multiple levels",function()
    local p=Rules.newProfile(0); Rules.xp(p,650); assert(p.Level==4 and p.XP==50)
end)
test("snapshot deep copy does not change while live profile changes",function()
    local p=Rules.newProfile(0); local snapshot=Profile.copy(p)
    p.Coins=90; p.Upgrades.Speed=1; assert(snapshot.Coins==0 and snapshot.Upgrades.Speed==0)
end)
test("schema rejects unknown versions, NaN and duplicated item UIDs",function()
    local p=Rules.newProfile(0); assert(Profile.validate(p)); p.Version=2; assert(not Profile.validate(p)); p.Version=1
    p.Coins=0/0; assert(not Profile.validate(p)); p.Coins=0
    p.OwnedEggs={{Uid="a"}}; p.Pets={{Uid="a"}}; assert(not Profile.validate(p))
end)
test("escape rating rewards fast undamaged escapes",function()
    assert(Rules.rating(10,0,0)=="S+"); assert(Rules.rating(90,40,0)=="C")
end)
print(string.format("%d domain tests passed",passed))
