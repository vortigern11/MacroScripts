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

-- Health percentage of unit
function MS:HPPercent(unit)
    local currentHP = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)

    return (currentHP / maxHP) * 100
end

-- Mana/rage/energy percentage of unit
function MS:MPPercent(unit)
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
    local onlyOnce = false
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
                PutItemInBag(bag + 19)
            end
        end

        wasStripped = true
    end)

    return wasStripped
end

function MS:GetItemType(itemLink)
    local _, _, istring  = string.find(itemLink, "|H(.+)|h")
    local _, _, _, _, itemType, itemSubType = GetItemInfo(istring)

    return itemType, itemSubType
end

-- Checks if the item is two-handed weapon
-- arg is `itemLink` so the function can work with both bag and equipment items
function MS:CheckIfTwoHanded(itemLink)
    local _, itemSubType = MS:GetItemType(itemLink)
    local isTwoHanded = MS:CheckIfTableIncludes(MS.twoHandedTypes, itemSubType)

    return isTwoHanded
end

-- Checks if spell is learned and if on cooldown
function MS:FindSpell(name)
    local wasFound, onCooldown = false, false

    local function Partial(booktype)
        local spellAndRank = ""
        local spellId = 1
        local wasFound, onCooldown = false, false

        local spell, rank = GetSpellName(spellId, booktype)

        if type(rank) == "string" then
            spellAndRank = spell .. "(" .. rank .. ")"
        end

        while(spell) do
            if name == spell or name == spellAndRank then
                wasFound = true
                onCooldown = GetSpellCooldown(spellId, booktype) ~= 0
                break
            end

            spellId = spellId + 1
            spell, rank = GetSpellName(spellId, booktype)

            if type(rank) == "string" then
                spellAndRank = spell .. "(" .. rank .. ")"
            end
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
        MS.prevSpellCast = name
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

    return wasFound, stacks, idx
end

-- Checks if the aura/buff/debuff is applied on the unit
-- returns `wasFound, stacks`
function MS:FindBuff(wantedBuff, unit)
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

-- Cancels a buff on the player
function MS:CancelBuff(wantedBuff)
    local wasFound, _, buffIdx = FindBuffPartial(wantedBuff, "player", "buff")
    if wasFound then CancelPlayerBuff(buffIdx) end
end

-- If invalid target to attack, target nearest enemy
function MS:TargetEnemy()
    -- skip check for death, in order to not retarget just after killing an enemy
    local isNotValidTarget = not UnitExists("target") or UnitIsFriend("player", "target") or UnitIsDeadOrGhost("target")
    if isNotValidTarget then TargetNearestEnemy() end

    isNotValidTarget = not UnitExists("target") or UnitIsFriend("player", "target") or UnitIsDeadOrGhost("target")
    return not isNotValidTarget
end

-- returns isEnemyPlayerCaster
function MS:IsEnemyCaster()
    local enemyIsPlayer = UnitIsPlayer("target")
    local enemyClass = UnitClass("target")
    local isEnemyCaster = enemyIsPlayer and (enemyClass == "Warlock" or enemyClass == "Mage" or enemyClass == "Priest")

    return isEnemyCaster
end

-- Whether exp or honor
function MS:YieldsHonorOrExp()
    local enemyIsPlayer = UnitIsPlayer("target")
    local lvlDiff = UnitLevel("player") - UnitLevel("target")
    local mobIsGreen = lvlDiff <= GetQuestGreenRange()
    local yieldsHonorOrExp = enemyIsPlayer or mobIsGreen

    return yieldsHonorOrExp
end

-- Get the rank of the talent at tab and idx
function MS:GetTalentRank(tab, idx)
    local _, _, _, _, talentRank = GetTalentInfo(tab, idx)
    return talentRank
end

-- Casts a silencing `spell` at the right time
function MS:Silence(spell)
    local hasCast = false
    local targetIsCasting = ShaguTargetCastbar and ShaguTargetCastbar:IsVisible()

    if targetIsCasting then
        local _, castTime = ShaguTargetCastbar:GetMinMaxValues()
        local cur = ShaguTargetCastbar:GetValue()
        local percent = (cur / castTime) * 100

        if castTime < 1 or percent > 60 then
            hasCast = MS:CastSpell(spell)
        end
    end

    return hasCast
end
