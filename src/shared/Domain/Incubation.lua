--!strict
export type StoredEgg = {Uid:string, Id:string, ReadyAt:number, Mutation:boolean}
export type Pet = {Uid:string, Id:string, EggId:string, Mutation:boolean}
type IncubatorProfile = {OwnedEggs:{StoredEgg}, Pets:{Pet}, Upgrades:{Incubator:number}}
type EggCatalog = {[string]:{HatchTime:number}}
local Incubation = {}
function Incubation.start(profile: IncubatorProfile, uid: string, now: number, catalog: EggCatalog)
    for _,egg in ipairs(profile.OwnedEggs) do
        if egg.Uid==uid then
            if egg.ReadyAt~=0 or not catalog[egg.Id] then return false end
            egg.ReadyAt=now+math.max(3,math.floor(catalog[egg.Id].HatchTime*(1-profile.Upgrades.Incubator*.1)))
            return true
        end
    end
    return false
end
function Incubation.finish(profile: IncubatorProfile, now: number, maxPets: number)
    local hatched={}
    for i=#profile.OwnedEggs,1,-1 do
        local egg=profile.OwnedEggs[i]
        if egg.ReadyAt>0 and egg.ReadyAt<=now and #profile.Pets<maxPets then
            table.remove(profile.OwnedEggs,i)
            table.insert(profile.Pets,{Uid=egg.Uid,Id=egg.Id.."_pet",EggId=egg.Id,Mutation=egg.Mutation})
            table.insert(hatched,egg)
        end
    end
    return hatched
end
return Incubation
