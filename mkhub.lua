print('Exec')
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character
repeat task.wait()
until game.Players.LocalPlayer:GetAttribute("DataFullyLoaded") and game.Players.LocalPlayer:GetAttribute("Finished_Loading")

local Services = setmetatable({}, {
	__index = function(self, Ind)
		local Success, Result = pcall(function()
			return cloneref(game:GetService(Ind) :: any)
		end)
		if Success and Result then
			rawset(self, Ind, Result)
			return Result
		end
		return nil
	end
})

local ReplicatedStorage: ReplicatedStorage = Services.ReplicatedStorage
local Http: HttpService = Services.HttpService
local Players: Players = Services.Players
local Player = Players.LocalPlayer

local FavoriteRemote: RemoteEvent = ReplicatedStorage.GameEvents.Favorite_Item
local PetsService: RemoteEvent = ReplicatedStorage.GameEvents.PetsService
local SellPet_RE: RemoteEvent = ReplicatedStorage.GameEvents.SellPet_RE
local PetEggService: RemoteEvent = ReplicatedStorage.GameEvents.PetEggService

local PetList = require(ReplicatedStorage.Data.PetRegistry).PetList
local DataService = require(ReplicatedStorage.Modules.DataService):GetData()
local PetsData = DataService.PetsData
local PetMutationMachine = DataService.PetMutationMachine
local TypeEnums = require(ReplicatedStorage.Data.EnumRegistry.ItemTypeEnums)
local InventoryEnums = require(ReplicatedStorage.Data.EnumRegistry.InventoryServiceEnums)
local PetMutationEnums = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry).EnumToPetMutation

getgenv().Config = getgenv().Config or {
    PLACE_EGGS = {""},
    EQUIP_PETS = {[""] = 8},
    LOCK_PET_AGE = 60
}

-- getgenv().Config = {
--     PLACE_EGGS = {"Common Egg"},
--     EQUIP_PETS = {["Ostrich"] = 8},
--     LOCK_PET_AGE = 60
-- }

local Config = getgenv().Config

local module = {}

function module.PrintDebug(...)
    print(string.format('[DEBUG] %s', tostring(...)))
end

function module.UnEquip()
    Player.Character.Humanoid:UnequipTools()
end

function module.CountVarbTable(table)
    local count = 0
    if table then
        for i, v in table do
            count = count + 1
        end
    end
    return count
end

function module.PetData(PET_UUID)
    local PetData = PetsData.PetInventory.Data[PET_UUID]
    if PetData and PetData.PetData then
        local PetInfo = PetList[PetData.PetType]
        return {
            ["Name"] = PetData.PetType,
            ["DisplayName"] = PetData.PetData.Name,
            ["UUID"] = PET_UUID,
            ["EggType"] = PetData.PetData.HatchedFrom,
            ["Rarity"] = PetInfo and PetInfo.Rarity or "Unknown",
            ["AssetId"] = PetInfo and PetInfo.Icon or 0,
            ["Weight"] = PetData.PetData.BaseWeight or 0,
            ["Age"] = PetData.PetData.Level or 0,
            ["AgeProgress"] = PetData.PetData.LevelProgress or 0,
            ["Mutation"] = PetData.PetData.MutationType and PetMutationEnums[PetData.PetData.MutationType] or nil,
            ["Hunger"] = PetData.PetData.Hunger or 0,
            ["Boosts"] = PetData.PetData.Boosts or {},
            ["Ability"] = PetData.PetAbility,
            ["Equipped"] = table.find(PetsData.EquippedPets, PET_UUID) and true or false
        }
    end
    return nil
end

function module.ListPets()
    local listPet = {}
    module.UnEquip()
    for i, pet in Player.Backpack:GetChildren() do
        if pet:GetAttribute('PET_UUID') then
            table.insert(listPet, pet)
        end
    end

    return listPet
end

function module.PetEquippedData()
    local listPet = {}
    for i, v in PetsData.EquippedPets do
        local petData = module.PetData(v)
        if petData then
            table.insert(listPet, petData)
        end
    end
    return listPet
end

function module.FindPetEquipped(petName)
    local listPet = {}
    for i, petData in module.PetEquippedData() do
        if petData.Name == petName then
            table.insert(listPet, petData)
        end
    end
    return listPet
end

function module.ListSlots()
    local dataSlot = PetsData.MutableStats
    return {
        ["PetSlots"] = dataSlot.MaxPetsInInventory,
        ["PetEquippedSlots"] = dataSlot.MaxEquippedPets,
        ["EggSlots"] = dataSlot.MaxEggsInFarm,
        ["PurchasedPetSlots"] = PetsData.PurchasedPetInventorySlots,
        ["PurchasedEquipSlots"] = PetsData.PurchasedEquipSlots,
        ["PurchasedEggSlots"] = PetsData.PurchasedEggSlots
    }
end

function module.SellPet(petData)
    module.PrintDebug('Selling Pet: ' .. petData['Name'] .. ' [' .. petData['UUID'] .. ']')
    SellPet_RE:FireServer()
end

function module.LockPet(instance, petData)
    if not instance:GetAttribute(InventoryEnums['Favorite']) then
        module.PrintDebug(string.format('Lock [Favorite] Pet: %s', petData.Name))
        FavoriteRemote:FireServer(instance)
    end
end

function module.UnLockPet(instance, petData)
    if instance:GetAttribute(InventoryEnums['Favorite']) then
        module.PrintDebug(string.format('Detect Pet Locked -> UnLocking...: %s', petData.Name))
        FavoriteRemote:FireServer(instance)
    end
end

function module.EquipPet(petData)
    module.PrintDebug('Equip Pet: ' .. petData['Name'] .. ' [' .. petData['UUID'] .. ']')
    PetsService:FireServer("EquipPet", petData['UUID'], CFrame.new())
end

function module.UnEquipPet(petData)
    module.PrintDebug('UnEquip Pet: ' .. petData['Name'] .. ' [' .. petData['UUID'] .. ']')
    PetsService:FireServer("UnequipPet", petData['UUID'])
end

function module.BuyEggShop()
    for i, v in DataService.PetEggStock.Stocks do
        if v.Stock > 0 then
            if table.find({"Rainbow Lollipop", "Pet Name Reroller", "Pet Lead"}, v.EggName) then
                continue
            end
                
            if true then
                local count = 0
                module.PrintDebug(string.format('Buying %s...', v.EggName))
                repeat task.wait(0.1)
                    ReplicatedStorage.GameEvents.BuyPetEgg:FireServer(v.EggName)
                    count = count + 1
                until v.Stock == 0 or count >= 3
            end
        end
    end
end

local currentGarden, posSpawn, posLeft, posRight, posUnknown
for i, farm in workspace.Farm:GetChildren() do
    if farm.Important.Data.Owner.Value == Player.Name then
        currentGarden = farm
        posSpawn = farm.Spawn_Point.CFrame * CFrame.new(0, -2, 0)
        for i, v in farm.Important.Plant_Locations:GetChildren() do
            if v:GetAttribute('Side') == 'Left' then
                posLeft = v.Position
            elseif v:GetAttribute('Side') == 'Right' then
                posRight = v.Position
            else
                posUnknown = v.Position
            end
        end

        if posUnknown then
            if posLeft then
                posRight = posUnknown
            elseif posRight then
                posLeft = posUnknown
            end
        end
    else
        farm:Destroy()
    end
end

if not currentGarden or not posSpawn or not posLeft or not posRight then
    game:Shutdown()
end

function module.CountEgg()
    local count = 0
    for i, v in currentGarden.Important.Objects_Physical:GetChildren() do
        if v.Name == 'PetEgg' then
            count = count + 1
        end
    end
    return count
end

function module.HatchEgg()
    for i, v in currentGarden.Important.Objects_Physical:GetChildren() do
        local eggName = v:GetAttribute('EggName')
        if eggName and v:GetAttribute('TimeToHatch') == 0 then
            module.PrintDebug('Hatch Pet: ' .. eggName .. ' [' .. v:GetAttribute('OBJECT_UUID') .. ']')
            PetEggService:FireServer("HatchPet", v)
        end
    end
end

while task.wait(3) do
    module.BuyEggShop()

    if Config.EQUIP_PETS and module.CountVarbTable(Config.EQUIP_PETS) > 0 then
        local listPetName = {}
        for petName, petCount in Config.EQUIP_PETS do
            table.insert(listPetName, petName)
        end

        task.wait(1)
        for i, pet in module.ListPets() do
            if #PetsData.EquippedPets >= module.ListSlots().PetEquippedSlots then
                break
            end

            local petData = module.PetData(pet:GetAttribute('PET_UUID'))
            if not petData then
                continue
            end
            
            if not table.find(listPetName, petData.Name) then
                continue
            end

            if #module.FindPetEquipped(petData.Name) >= Config.EQUIP_PETS[petData.Name] then
                continue
            end

            module.EquipPet(petData)
            task.wait(0.5)
        end
    end

    module.HatchEgg()

    if Config.PLACE_EGGS then
        for i, eggName in Config.PLACE_EGGS do
            module.UnEquip()
            for i, v in Player.Backpack:GetChildren() do
                if string.find(v.Name, eggName) then
                    module.UnEquip()
                    v.Parent = Player.Character
                    task.wait()
                    local count = 0
                    while task.wait(0.5) do 
                        count = count + 1
                        if not v.Parent or module.CountEgg() >= module.ListSlots().EggSlots or count > 8 then
                            break
                        end

                        module.PrintDebug('Place Egg: ' .. eggName)
                        PetEggService:FireServer("CreateEgg", posLeft + Vector3.new(math.random(-10, 10), 1, math.random(-10, 10)))
                    end
                end
            end
        end
    end

    local listPet = module.ListPets()
    for i, pet in listPet do
        local petData = module.PetData(pet:GetAttribute('PET_UUID'))
        if petData and petData.Age and Config.LOCK_PET_AGE and type(petData.Age) == "number" and type(Config.LOCK_PET_AGE) == "number" then
            if petData.Age >= Config.LOCK_PET_AGE then
                module.LockPet(pet, petData)
                continue
            end

            module.UnLockPet(pet, petData)
            if #listPet + module.ListSlots().PetEquippedSlots >= module.ListSlots().PetSlots then
                module.UnEquip()
                pet.Parent = Player.Character
                module.SellPet(petData)
                task.wait(1)
            end
        end
    end
end
