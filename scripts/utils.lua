-- Traverse Lua table
-- if the provited `func` returns "break loop" then... the loop breaks
function MS:TraverseTable(tbl, func)
    local isArray = tbl[0] ~= nil
    local getPairs = pairs

    if isArray then getPairs = ipairs end

    for key, val in getPairs(tbl) do
        local shouldBreak = func(key, val) == "break loop"
        if shouldBreak then break end
    end
end

-- Whether a Lua table includes an element
function MS:CheckIfTableIncludes(tbl, el)
    local doesInclude = false

    MS:TraverseTable(tbl, function(_, val)
        if val == el then doesInclude = true end
    end)

    return doesInclude
end

-- Print function
function MS:Print(msg)
    print("|cff3ffca4MacroScripts: " .. msg)
end

-- Say function
function MS:Say(msg)
    SendChatMessage(msg, "SAY")
end

-- Parses the `unit` to a valid one
function MS:ParseUnit(unit)
    if not unit then
        unit = "player"
    elseif unit == "mouseover" then
        local frame = GetMouseFocus()
        local unit = nil

        if (frame.label and frame.id) then
            unit = frame.label .. frame.id
        end
    end

    local doesntExist = not UnitExists(unit)

    if doesntExist then
        unit = "player"
    end

    return unit
end

-- Health percentage of unit
function MS:HPPercent(unit)
    unit = MS:ParseUnit(unit)
    local currentHP = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)

    return (currentHP / maxHP) * 100
end

-- Mana/rage/energy percentage of unit
function MS:MPPercent(unit)
    unit = MS:ParseUnit(unit)
    local currentMP = UnitMana(unit)
    local maxMP = UnitManaMax(unit)

    return (currentMP / maxMP) * 100
end

-- Whether player is spell casting
function MS:IsCasting()
    return CastingBarFrame.casting
end

-- Whether player is spell channeling
function MS:IsChanneling()
    return CastingBarFrame.channeling
end

-- Item Link to Item Name
function MS:ItemLinkToName(itemLink)
    return string.gsub(itemLink,"^.*%[(.*)%].*$","%1")
end

-- Execute function for first or for every found item in the bags
-- returns `wasFound`
function MS:DoForItemInBags(wantedItem, onlyOnce, func)
    local wasFound = false
    local emptySlotIsWanted = wantedItem == nil

    for bag = 0, NUM_BAG_SLOTS do
        local slots = GetContainerNumSlots(bag)

        for slot = 1, slots do
            local itemLink = GetContainerItemLink(bag, slot)
            local isItemInSlot = type(itemLink) == "string"
            local slotIsEmpty = itemLink == nil

            if (emptySlotIsWanted and slotIsEmpty) then
                func(bag, slot)
                wasFound = true

                if onlyOnce then return wasFound end
            elseif isItemInSlot then
                local itemName = MS:ItemLinkToName(itemLink)

                if (itemName == wantedItem) then
                    func(bag, slot)
                    wasFound = true

                    if onlyOnce then return wasFound end
                end
            end
        end
    end

    return wasFound
end

-- Destroy by bag and slot ids
function MS:DestroyInBagAtSlot(bag, slot)
    PickupContainerItem(bag, slot)
    DeleteCursorItem()
end

-- Destroy by item name
function MS:DestroyItemInBag(itemName, onlyOnce)
    MS:DoForItemInBags(itemName, onlyOnce, function(bag, slot)
        MS:DestroyInBagAtSlot(bag, slot)
    end)
end

-- Use item and prevent selling it
function MS:UseBagItem(itemName)
    local onlyOnce = true
    local wasUsed = false

    MS:DoForItemInBags(itemName, onlyOnce, function(bag, slot)
        local onCooldown = GetContainerItemCooldown(bag, slot) ~= 0

        if (not onCooldown) then
            CloseMerchant() -- prevent accidental selling
            UseContainerItem(bag, slot)
            wasUsed = true
        end
    end)

    return wasUsed
end

-- Traverse a list of items in order until an item is used
function MS:UseBagItemFromList(items)
    local wasUsed = false

    MS:TraverseTable(items, function(_, itemName)
        wasUsed = MS:UseBagItem(itemName)

        if wasUsed then
            return "break loop"
        end
    end)

    return wasUsed
end

function MS:IsItemInBag(itemName)
    local onlyOnce = true
    local isItemInBag = MS:DoForItemInBags(itemName, onlyOnce, function() end)

    return isItemInBag
end

-- Get itemlink of equipped item in `part` slot
function MS:GetEquipmentItemLink(part)
    local equipId = MS.equipments[part].id
    local itemLink = GetInventoryItemLink("player", equipId)
    local isItem = type(itemLink) == "string"

    if not isItem then itemLink = "" end

    return itemLink
end

-- Save the equipped item link in MS.equipment[part].prev
function MS:SaveEquipmentItemLink(part)
    MS.equipments[part].prev = MS:GetEquipmentItemLink(part)
end

-- Use specific equipped item, where `part` is string
function MS:UseEquipment(part)
    local equipId = MS.equipments[part].id
    local isItem = MS:GetEquipmentItemLink(part) ~= ""
    local wasUsed = false

    if isItem then
        local onCooldown = GetInventoryItemCooldown("player", equipId) ~= 0

        if not onCooldown then
            UseInventoryItem(equipId)
            wasUsed = true
        end
    end

    return wasUsed
end

-- Equips `itemName` in `part` slot
-- saves the name of the last equipped item in that slot
function MS:EquipItem(itemName, part)
    local equipId = MS.equipments[part].id
    local onlyOnce = true
    local wasEquipped = false

    MS:DoForItemInBags(itemName, onlyOnce, function(bag, slot)
        MS:SaveEquipmentItemLink(part)
        PickupContainerItem(bag, slot)
        EquipCursorItem(equipId)
        wasEquipped = true
    end)

    return wasEquipped
end

-- Put `part` equipment in a bag, returns `wasStripped`
function MS:StripItem(part)
    local itemName = nil
    local onlyOnce = true
    local wasStripped = false

    MS:DoForItemInBags(itemName, onlyOnce, function(bag, slot)
        MS:SaveEquipmentItemLink(part)

        local hasItemEquipped = MS:GetEquipmentItemLink(part) ~= ""

        if hasItemEquipped then
            local equipId = MS.equipments[part].id

            PickupInventoryItem(equipId)

            if bag == 0 then
                PutItemInBackpack()
            else
                PutItemInBag(bag + 20)
            end
        end

        wasStripped = true
    end)

    return wasStripped
end

-- Checks if the item is two-handed weapon
-- arg is `itemLink` so the function can work with both bag and equipment items
function MS:CheckIfTwoHanded(itemLink)
    local _, _, _, _, _, _, itemSubType = GetItemInfo(itemLink)
    local isTwoHanded = MS:CheckIfTableIncludes(MS.twoHandedTypes, itemSubType)

    return isTwoHanded
end

-- Checks if spell is learned and if on cooldown
function MS:FindSpell(name)
    local wasFound, onCooldown = false, false

    local function Partial(booktype)
        local spellId = 1
        local spell = GetSpellName(spellId, booktype)
        local wasFound, onCooldown = false, false

        while(spell) do
            if spell == name then
                wasFound = true
                onCooldown = GetSpellCooldown(spellId, booktype) ~= 0
                break
            end

            spellId = spellId + 1
            spell = GetSpellName(spellId, booktype)
        end

        return wasFound, onCooldown
    end

    wasFound, onCooldown = Partial(BOOKTYPE_SPELL)

    if not wasFound then
        wasFound, onCooldown = Partial(BOOKTYPE_PET)
    end

    return wasFound, onCooldown
end

-- Cast the spell if possible
function MS:CastSpell(name)
    local wasFound, onCooldown = MS:FindSpell(name)
    local hasCast = false

    if wasFound and not onCooldown then
        -- reset global
        MS.castHasFailed = false

        CastSpellByName(name)
        hasCast = not MS.castHasFailed

        -- reset global
        MS.castHasFailed = false
    end

    return hasCast
end

local function FindBuffPartial(wantedBuff, unit, auraType)
    local getBuff = UnitBuff

    if (auraType == "debuff") then
        getBuff = UnitDebuff
    end

    local wasFound = false
    local idx = 1
    local icon, stacks = getBuff(unit, idx)

    while icon do
        MS_T:SetOwner(UIParent, "ANCHOR_NONE")

        if auraType == "debuff" then
            MS_T:SetUnitDebuff(unit, idx)
        else
            MS_T:SetUnitBuff(unit, idx)
        end

        local currBuff = MS_TTextLeft1:GetText()
        MS_T:Hide()

        if currBuff == wantedBuff then
            wasFound = true
            break
        end

        icon, stacks = getBuff(unit, idx)
        idx = idx + 1
    end

    if type(stacks) ~= "number" then stacks = 0 end

    return wasFound, stacks
end

-- Checks if the aura/buff/debuff is applied on the unit
-- returns `wasFound, stacks`
function MS:FindBuff(wantedBuff, unit)
    unit = MS:ParseUnit(unit)

    local wasFound = false
    local stacks = 0

    if not wasFound then
        wasFound, stacks = FindBuffPartial(wantedBuff, unit, "buff")
    end
    if not wasFound then
        wasFound, stacks = FindBuffPartial(wantedBuff, unit, "debuff")
    end

    return wasFound, stacks
end
