-- Reset dungeon/raid/whatever instance
function MS:ResetInstance()
    ResetInstances()
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
    local hp = MS:HPPercent("player")

    if hp > 70 then return end

    local zone = string.lower(GetRealZoneText())
    local isNotInBG = not MS:CheckIfTableIncludes(MS.bgs, zone)

    if isNotInBG then zone = "normal" end

    local wasBandageFound = false

    MS:ForTableElem(MS.bandages[zone], function(_, bandageName)
        if wasBandageFound then return end

        local wantedItem = bandageName
        local onlyOnce = true

        wasBandageFound = MS:DoForItemInBags(wantedItem, onlyOnce, function(bag, slot)
            UseContainerItem(bag, slot)
        end)
    end)
end
