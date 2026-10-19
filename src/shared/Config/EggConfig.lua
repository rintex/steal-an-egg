--!strict
export type EggDefinition = {
    Id:string, Name:string, Rarity:string, Biome:string, Size:number, Weight:number,
    Value:number, HatchTime:number, SpawnWeight:number, Color:{number}, Pattern:string,
    Pets:{string}, PetName:string,
}
local catalog: {[string]: EggDefinition} = {
    ["clover"] = {Id="clover", Name="Клеверное", Rarity="COMMON", Biome="Meadow", Size=1, Weight=1, Value=25, HatchTime=8, SpawnWeight=50, Color={235, 244, 194}, Pattern="Spots", Pets={"clover".."_pet"}, PetName="Клеверыш"},
    ["speckle"] = {Id="speckle", Name="Веснушка", Rarity="UNCOMMON", Biome="Meadow", Size=1.1, Weight=1.5, Value=38, HatchTime=12, SpawnWeight=28, Color={255, 218, 153}, Pattern="Spots", Pets={"speckle".."_pet"}, PetName="Пятныш"},
    ["dew"] = {Id="dew", Name="Роса рассвета", Rarity="RARE", Biome="Meadow", Size=0.9, Weight=1, Value=60, HatchTime=18, SpawnWeight=14, Color={112, 231, 215}, Pattern="Spots", Pets={"dew".."_pet"}, PetName="Росинка"},
    ["honey"] = {Id="honey", Name="Медовый вихрь", Rarity="EPIC", Biome="Meadow", Size=1.35, Weight=3, Value=95, HatchTime=25, SpawnWeight=6, Color={255, 188, 65}, Pattern="Spots", Pets={"honey".."_pet"}, PetName="Медокрыл"},
    ["sunseed"] = {Id="sunseed", Name="Семя солнца", Rarity="LEGENDARY", Biome="Meadow", Size=1.2, Weight=2, Value=140, HatchTime=35, SpawnWeight=1.8, Color={255, 236, 117}, Pattern="Spots", Pets={"sunseed".."_pet"}, PetName="Лучелис"},
    ["moonbud"] = {Id="moonbud", Name="Лунный бутон", Rarity="SECRET", Biome="Meadow", Size=0.85, Weight=1, Value=180, HatchTime=40, SpawnWeight=0.2, Color={211, 163, 255}, Pattern="Spots", Pets={"moonbud".."_pet"}, PetName="Лунозай"},
    ["quartz"] = {Id="quartz", Name="Кварцевое эхо", Rarity="RARE", Biome="Crystal", Size=1.2, Weight=3, Value=90, HatchTime=25, SpawnWeight=60, Color={164, 214, 255}, Pattern="Spots", Pets={"quartz".."_pet"}, PetName="Кварцик"},
    ["amethyst"] = {Id="amethyst", Name="Аметистовый звон", Rarity="EPIC", Biome="Crystal", Size=1.4, Weight=4, Value=125, HatchTime=35, SpawnWeight=35, Color={187, 126, 255}, Pattern="Spots", Pets={"amethyst".."_pet"}, PetName="Звонокрыл"},
    ["prism"] = {Id="prism", Name="Сердце призмы", Rarity="MYTHIC", Biome="Crystal", Size=1, Weight=2, Value=210, HatchTime=55, SpawnWeight=5, Color={255, 174, 232}, Pattern="Spots", Pets={"prism".."_pet"}, PetName="Призмалис"},
    ["snowdrop"] = {Id="snowdrop", Name="Подснежник", Rarity="UNCOMMON", Biome="Frozen", Size=1, Weight=2, Value=85, HatchTime=22, SpawnWeight=60, Color={214, 244, 255}, Pattern="Spots", Pets={"snowdrop".."_pet"}, PetName="Снежок"},
    ["aurora"] = {Id="aurora", Name="Полярное сияние", Rarity="LEGENDARY", Biome="Frozen", Size=1.4, Weight=4, Value=170, HatchTime=45, SpawnWeight=35, Color={125, 255, 206}, Pattern="Spots", Pets={"aurora".."_pet"}, PetName="Аврорик"},
    ["wintercrown"] = {Id="wintercrown", Name="Корона зимы", Rarity="DIVINE", Biome="Frozen", Size=1.6, Weight=5, Value=240, HatchTime=60, SpawnWeight=5, Color={164, 189, 255}, Pattern="Spots", Pets={"wintercrown".."_pet"}, PetName="Ледокнязь"},
    ["ember"] = {Id="ember", Name="Тлеющий уголь", Rarity="RARE", Biome="Volcanic", Size=0.9, Weight=2, Value=100, HatchTime=28, SpawnWeight=60, Color={255, 138, 74}, Pattern="Spots", Pets={"ember".."_pet"}, PetName="Уголёк"},
    ["basalt"] = {Id="basalt", Name="Базальтовое", Rarity="EPIC", Biome="Volcanic", Size=1.6, Weight=6, Value=175, HatchTime=40, SpawnWeight=35, Color={104, 88, 105}, Pattern="Spots", Pets={"basalt".."_pet"}, PetName="Базальтик"},
    ["phoenix"] = {Id="phoenix", Name="Искра возрождения", Rarity="MYTHIC", Biome="Volcanic", Size=1.3, Weight=3, Value=230, HatchTime=55, SpawnWeight=5, Color={255, 99, 84}, Pattern="Spots", Pets={"phoenix".."_pet"}, PetName="Жаропёрыш"},
    ["fern"] = {Id="fern", Name="Папоротниковое", Rarity="UNCOMMON", Biome="Jungle", Size=1.1, Weight=2, Value=95, HatchTime=24, SpawnWeight=60, Color={148, 206, 83}, Pattern="Spots", Pets={"fern".."_pet"}, PetName="Листозавр"},
    ["relic"] = {Id="relic", Name="Забытая реликвия", Rarity="LEGENDARY", Biome="Jungle", Size=1.5, Weight=5, Value=190, HatchTime=48, SpawnWeight=35, Color={214, 183, 110}, Pattern="Spots", Pets={"relic".."_pet"}, PetName="Реликт"},
    ["roots"] = {Id="roots", Name="Сердце корней", Rarity="SECRET", Biome="Jungle", Size=1.2, Weight=3, Value=260, HatchTime=65, SpawnWeight=5, Color={71, 151, 121}, Pattern="Spots", Pets={"roots".."_pet"}, PetName="Корнелис"},
    ["dusk"] = {Id="dusk", Name="Сумеречное", Rarity="EPIC", Biome="Shadow", Size=1, Weight=2, Value=140, HatchTime=35, SpawnWeight=85, Color={136, 104, 181}, Pattern="Spots", Pets={"dusk".."_pet"}, PetName="Сумрак"},
    ["eclipse"] = {Id="eclipse", Name="Тихое затмение", Rarity="MYTHIC", Biome="Shadow", Size=1.3, Weight=4, Value=240, HatchTime=60, SpawnWeight=15, Color={90, 75, 132}, Pattern="Spots", Pets={"eclipse".."_pet"}, PetName="Тенекот"},
    ["breeze"] = {Id="breeze", Name="Попутный ветер", Rarity="RARE", Biome="Sky", Size=0.8, Weight=0.6, Value=130, HatchTime=30, SpawnWeight=85, Color={191, 234, 255}, Pattern="Spots", Pets={"breeze".."_pet"}, PetName="Ветрокрыл"},
    ["thunder"] = {Id="thunder", Name="Грозовой узел", Rarity="DIVINE", Biome="Sky", Size=1.4, Weight=3, Value=250, HatchTime=60, SpawnWeight=15, Color={255, 242, 153}, Pattern="Spots", Pets={"thunder".."_pet"}, PetName="Громопух"},
    ["orbit"] = {Id="orbit", Name="Малая орбита", Rarity="LEGENDARY", Biome="Cosmic", Size=1.2, Weight=2, Value=200, HatchTime=45, SpawnWeight=90, Color={152, 153, 255}, Pattern="Spots", Pets={"orbit".."_pet"}, PetName="Орбитыш"},
    ["nebula"] = {Id="nebula", Name="Колыбель туманности", Rarity="SECRET", Biome="Cosmic", Size=1.6, Weight=5, Value=300, HatchTime=70, SpawnWeight=10, Color={240, 162, 239}, Pattern="Spots", Pets={"nebula".."_pet"}, PetName="Звездосплюш"},
}
return catalog
