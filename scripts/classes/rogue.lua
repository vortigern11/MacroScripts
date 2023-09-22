-- For hardcore professions:
-- Start with skinning + herbalism
-- Leave herbalism items in the bank
-- When you have enough gold for lvl 40 mount, switch skinning for alchemy

-- Ideas for leveling:
-- Ambush (1/2 cp) -> Ghost Strike (2/3 cp) -> Expose Armor (0/1 cp) ->
-- Slice and Dice(0/1 cp) -> pool energy -> Gauge (1/2 cp) -> Backstab(2/3 cp)

local rg = CreateFrame("Frame")

rg.hasPickedPockets = false
rg.tryBackstab = true
rg.lastParry = 0

rg:RegisterEvent("UI_ERROR_MESSAGE")
rg:RegisterEvent("UNIT_COMBAT")
rg:RegisterEvent("PLAYER_TARGET_CHANGED")

rg:SetScript("OnEvent", function()
    local playerIsNotRogue = UnitClass("player") ~= "Rogue"

    if playerIsNotRogue then
        rg:UnregisterAllEvents()
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        -- Backstab not being behind the enemy error happens after the
        -- spell is "successfully" cast. If that happens -> cast Sinister Strike
        local isFailedBackstab = type(arg1) == "string" and string.gfind(arg1, "behind")

        -- Can't just cast Sinister Strike here, the game throws you out for some reason...
        if isFailedBackstab and MS.prevSpellCast == "Backstab" then
            rg.tryBackstab = false
        end
    elseif event == "UNIT_COMBAT" then
        local hasParried = arg1 == "player" and arg2 == PARRY

        if hasParried then
            rg.lastParry = GetTime()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        rg.hasPickedPockets = false
    end
end)

function MS:R_Stealth()
    local hasStealth = MS:FindBuff("Stealth", "player")
    local isAltKey = IsAltKeyDown()

    -- get out or in Stealth
    if isAltKey and hasStealth then
        CastShapeshiftForm(1) -- doesn't work with cancel debuff
        hasStealth = false

    elseif not hasStealth then
        -- stop melee auto attacking
        if MS.isMeleeAttacking then AttackTarget("target") end

        local inCombat = UnitAffectingCombat("player")

        if not inCombat then
            hasStealth = MS:CastSpell("Stealth")
        else
            hasStealth = MS:CastSpell("Vanish")
        end
    end

    return hasStealth
end

function MS:R_CrowdControl()
    local isValidMouseover = not UnitIsUnit("target", "mouseover") and
                             UnitExists("mouseover") and
                             not UnitIsDeadOrGhost("mouseover") and
                             not UnitIsFriend("player", "mouseover")

    local hasChangedTarget = false
    local hasCast = false
    local hasGouge = false
    local hasBlind = false
    local enemyInCombat = false

    -- maybe change to mouseover target
    if isValidMouseover then
        enemyInCombat = UnitAffectingCombat("mouseover")
        hasGouge = MS:FindBuff("Gouge", "mouseover")
        hasBlind = MS:FindBuff("Blind", "mouseover")

        if enemyInCombat and not hasGouge and not hasBlind then
            TargetUnit("mouseover")
            hasChangedTarget = true
        end
    end

    -- maybe target doesn't need CC
    if not hasChangedTarget then
        enemyInCombat = UnitAffectingCombat("target")
        hasGouge = MS:FindBuff("Gouge", "target")
        hasBlind = MS:FindBuff("Blind", "target")

        if not enemyInCombat or hasGouge or hasBlind then
            return
        end
    end

    -- try to Gauge
    hasCast = MS:CastSpell("Gouge")
    if hasCast then
        -- retarget and start melee auto attacking
        if hasChangedTarget then
            TargetLastTarget()
            if not MS.isMeleeAttacking then AttackTarget("target") end
        end

        return
    end

    -- try to Blind
    hasCast = MS:CastSpell("Blind")
    if hasCast then
        -- retarget and start melee auto attacking
        if hasChangedTarget then
            TargetLastTarget()
            if not MS.isMeleeAttacking then AttackTarget("target") end
        end

        return
    end
end

function MS:R_Damage()
    -- target a valid enemy
    local hasTarget = MS:TargetEnemy()
    if not hasTarget then return end

    local hasCast = false
    local comboPoints = GetComboPoints("player", "target")
    local hp = MS:HPPercent("player")
    local energy = UnitMana("player")
    local level = UnitLevel("player")
    local inCombat = UnitAffectingCombat("player")

    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")
    local enemyInCombat = UnitAffectingCombat("target")

    local _, mainSubType = MS:GetItemType(MS:GetEquipmentItemLink("main"))
    local hasDagger = mainSubType == "Daggers"
    local hasStealth = MS:FindBuff("Stealth", "player")

    local imTarget = UnitIsUnit("player", "targettarget")
    local isClose = CheckInteractDistance("target", 3)
    local imNotSafe = imTarget and isClose

    -- get in Stealth if appropriate
    local shouldPrestealth = (hasDagger and level > 20) or (not hasDagger and level > 26)

    if not hasStealth and not inCombat and not enemyInCombat and shouldPrestealth then
        hasStealth = MS:R_Stealth()
        if hasStealth then return end
    end

    -- do the stealth combo
    if hasStealth then
        -- try to cast Pick Pocket
        if not enemyIsPlayer and not rg.hasPickedPockets then
            hasCast = MS:CastSpell("Pick Pocket")

            if hasCast then
                rg.hasPickedPockets = true
                return
            end
        end

        -- try to cast Cheap Shot
        if not hasDagger or (enemyIsPlayer and enemyHP > 90) then
            hasCast = MS:CastSpell("Cheap Shot")
            if hasCast then return end
        end

        -- try to cast Ambush or Backstab
        if hasDagger then
            hasCast = MS:CastSpell("Ambush")
            if hasCast then return end

            hasCast = MS:CastSpell("Backstab")
            if hasCast then return end
        end

        -- don't get out of stealth unintentionally
        return
    end

    -- try to Backstab before anything else during Gouge
    local hasGouge = MS:FindBuff("Gouge", "target")

    if hasGouge and hasDagger then
        hasCast = MS:CastSpell("Backstab")
        return -- wait for Backstab
    end

    -- start melee auto attacking
    if not MS.isMeleeAttacking then AttackTarget("target") end

    -- cast low hp spells
    if hp < 60 then
        -- emergency HP
        if hp < 40 then
            local wasUsed = MS:UseHealthConsumable()
            if wasUsed then return end
        end

        -- cast Evasion
        local hasEvasion = MS:FindBuff("Evasion", "player")
        if not hasEvasion and imNotSafe then
            hasCast = MS:CastSpell("Evasion")
            if hasCast then return end
        end

        -- cast Berserking (troll racial)
        local hasBerserking = MS:FindBuff("Berserking", "player")
        if not hasBerserking then
            hasCast = MS:CastSpell("Berserking")
            if hasCast then return end
        end
    end

    -- cast Kick
    local hasCast = MS:Silence("Kick")
    if hasCast then return end

    -- cast Riposte
    local hasRiposte = MS:FindBuff("Riposte", "target")
    local canRiposte = not hasRiposte and ((GetTime() - rg.lastParry) < 5)

    if canRiposte then
        hasCast = MS:CastSpell("Riposte")
        if hasCast then return end
    end

    -- cast Ghostly Strike
    local hasGhostlyStrike = MS:FindBuff("Ghostly Strike", "player")

    if not hasGhostlyStrike and imNotSafe then
        hasCast = MS:CastSpell("Ghostly Strike")
        if hasCast then return end
    end

    -- cast Expose Armor
    local hasSunderArmor = MS:FindBuff("Sunder Armor", "target")
    local hasExposeArmor = MS:FindBuff("Expose Armor", "target")
    local shouldExposeArmor = comboPoints > 2 and enemyHP > 60 and not hasExposeArmor and not hasSunderArmor

    if shouldExposeArmor then
        hasCast = MS:CastSpell("Expose Armor")
        if hasCast then return end
    end

    -- cast Slice and Dice
    local hasSliceAndDice = MS:FindBuff("Slice and Dice", "player")
    local shouldSliceDice = comboPoints == 1 and not hasSliceAndDice

    if shouldSliceDice then
        hasCast = MS:CastSpell("Slice and Dice")
        if hasCast then return end
    end

    -- cast Eviscerate
    local shouldEvis = comboPoints == 5 or (comboPoints > 0 and enemyHP < 25)

    if shouldEvis then
        hasCast = MS:CastSpell("Eviscerate")
        if hasCast then return end
    end

    -- cast Backstab
    if hasDagger and rg.tryBackstab then
        hasCast = MS:CastSpell("Backstab")
        if hasCast then return end
    else
        -- reset the variable
        rg.tryBackstab = true
    end

    -- cast Sinister Strike
    hasCast = MS:CastSpell("Sinister Strike")
    if hasCast then return end
end
