-- Traverse Lua table
function MS:ForTableElem(tbl, func)
    for key, val in ipairs(tbl) do func(key, val) end
end

-- Whether a Lua table includes an element
function MS:CheckIfTableIncludes(tbl, el)
    local doesInclude = false

    MS:ForTableItems(list, function(_, val)
        if val == el then doesInclude = true end
    end)

    return doesInclude
end

-- Print function
function MS:Print(msg)
    print("|cff3ffca4MacroScripts: " .. msg)
end

-- Use item and prevent selling it
function MS:UseItem(bag, slot)
    CloseMerchant()
    UseContainerItem(bag, slot)
end

-- Execute function for first or every found item in the bags
-- returns `wasFound, funcResult`
function MS:DoForItemInBags(wantedItem, onlyOnce, func)
    local wasFound = false

    for bag = 0, NUM_BAG_SLOTS do
        local slots = GetContainerNumSlots(bag)

        for slot = 1, slots do
            local itemLink = GetContainerItemLink(bag, slot)
            local isValidItemLink = type(itemLink) == "string"

            if isValidItemLink then
                local itemName = string.gsub(itemLink,"^.*%[(.*)%].*$","%1")

                if (itemName == wantedItem) then
                    wasFound = true

                    local funcResult = func(bag, slot)

                    if onlyOnce then
                        return true, funcResult
                    end
                end
            end
        end
    end

    return wasFound, nil
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

-- Health percentage of target
function MS:HPPercent(target)
    local currentHP = UnitHealth(target)
    local maxHP = UnixHealthMax(target)

    return (currentHP / maxHP) * 100
end

-- Mana/rage/energy percentage of target
function MS:MPPercent(target)
    local currentMP = UnitMana(target)
    local maxMP = UnixManaMax(target)

    return (currentMP / maxMP) * 100
end

-- Use specific equipped item, where `part` is string
-- look at MS.equipments in variables.lua
function MS:UseEquipment(part)
    UseInventoryItem(MS.equipments[part])
end
