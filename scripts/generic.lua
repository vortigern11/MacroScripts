-- Reset dungeon/raid/whatever instance
function MS:ResetInstances()
    local canReset = CanShowResetInstances()

    if canReset then
        ResetInstances()
        MS:Say("The instances are reset.")
    end
end

-- Get bonus exp for TurtleWoW. Max is 30 bubbles. Replenish at tents.
function MS:GetRestBonus()
    local exp = UnitXP("player")
    local maxExp = UnitXPMax("player")
    local restExp = GetXPExhaustion()
    local msg = ""

    if not restExp then
        msg = "No rest."
    else
        local bubbles = math.floor(20 * restExp / maxExp + 0.5)
        local totalExp = restExp + exp

        msg = "Rest: " .. bubbles .. " bubbles ("

        if totalExp < maxExp then
            msg = msg .. restExp
        else
            msg = msg .. "level +" .. (totalExp - maxExp)
        end

        msg = msg .. "XP)"
    end

    MS:Print(msg)
end

-- Use best bandage for the instance
function MS:UseBandage()
    local zone = string.lower(GetRealZoneText())
    local isNotInBG = not MS:CheckIfTableIncludes(MS.bgs, zone)

    if isNotInBG then zone = "normal" end

    local hp = MS:HPPercent("player")
    local items = MS.bandages[zone]

    if hp > 70 then return end

    local wasUsed = MS:UseBagItemFromList(items)

    return wasUsed
end

-- Use best health consumable
function MS:UseHealthConsumable()
    local zone = string.lower(GetRealZoneText())
    local isNotInBG = not MS:CheckIfTableIncludes(MS.bgs, zone)

    if isNotInBG then
        zone = "normal"
    else
        zone = "bg"
    end

    local hp = MS:HPPercent("player")
    local items = MS.hpConsumables[zone]

    if hp > 60 then return end

    local wasUsed = MS:UseBagItemFromList(items)

    return wasUsed
end

-- Use best mana consumable
function MS:UseManaConsumable()
    local zone = string.lower(GetRealZoneText())
    local isNotInBG = not MS:CheckIfTableIncludes(MS.bgs, zone)

    if isNotInBG then
        zone = "normal"
    else
        zone = "bg"
    end

    local isRogue = UnitClass("player") == "Rogue"
    local mp = MS:MPPercent("player")
    local items = MS.mpConsumables[zone]
    local wasUsed = false

    if mp > 60 then return end

    if (isRogue and mp < 40) then
        wasUsed = MS:UseBagItem("Thistle Tea")
    else
        wasUsed = MS:UseBagItemFromList(items)
    end

    return wasUsed
end

-- Use best battleground food which restores both health and mana
function MS:UseBGFood()
    local zone = string.lower(GetRealZoneText())
    local isNotInBG = not MS:CheckIfTableIncludes(MS.bgs, zone)

    if isNotInBG then return end

    local hp = MS:HPPercent("player")
    local mp = MS:MPPercent("player")
    local items = MS.bgFoods[zone]

    if (hp > 60 and mp > 60) then return end

    local wasUsed = MS:UseBagItemFromList(items)

    return wasUsed
end

function MS:SwapFishing()
    local mainItemLink = MS:GetEquipmentItemLink("main")
    local mainItem = MS:ItemLinkToName(mainItemLink)
    local poles = MS.fishing.poles
    local isPoleEquipped = MS:CheckIfTableIncludes(poles, mainItem)

    if isPoleEquipped then
        local prevMainItemLink = MS.equipments["main"].prev
        local prevMainItemName = MS:ItemLinkToName(prevMainItemLink)

        -- equip main hand
        MS:EquipItem(prevMainItemName, "main")
    else
        local mainItemLink = MS:GetEquipmentItemLink("main")
        local isTwoHanded = MS:CheckIfTwoHanded(mainItemLink)
        local prevOffItemLink = MS.equipments["off"].prev
        local hadOffhand = prevOffItemLink ~= ""

        if not isTwoHanded and hadOffhand then
            -- equip offhand if necessary
            local prevOffItemName = MS:ItemLinkToName(prevOffItemLink)

            MS:EquipItem(prevOffItemName, "off")
        else
            -- swap main with fishing pole
            MS:TraverseTable(poles, function(_, pole)
                -- strip off hand
                MS:StripItem("off")

                local wasEquipped = MS:EquipItem(pole, "main")
                if wasEquipped then return "break loop" end
            end)
        end
    end
end

function MS:ApplyLure()
    local mainItemLink = MS:GetEquipmentItemLink("main")
    local mainItem = MS:ItemLinkToName(mainItemLink)
    local poles = MS.fishing.poles
    local isPoleEquipped = MS:CheckIfTableIncludes(poles, mainItem)

    if isPoleEquipped then
        local lures = MS.fishing.lures
        local wasUsed = MS:UseBagItemFromList(lures)

        if wasUsed then
            PickupInventoryItem(MS.equipments["main"].id)
            ReplaceEnchant()
        end
    end
end

function MS:PetFollow()
    local hasPet = HasPetUI()

    if hasPet then
        PetFollow()
        PetStopAttack()
    end
end

function MS:PetAttack()
    local hasPet = HasPetUI()

    if hasPet then
        local isImp = UnitCreatureFamily("pet") == "Imp"
        local hasPhaseShift = MS:FindBuff("Phase Shift", "pet")
        local impInPhase = isImp and hasPhaseShift
        local petHasNoTarget = not UnitExists("pettarget") or UnitIsDeadOrGhost("pettarget")
        local shouldAttackNewTarget = petHasNoTarget or MS.petIsAttacking

        if not impInPhase and shouldAttackNewTarget then
            PetAttack()
        end
    end
end
