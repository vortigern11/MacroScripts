-- hardcore professions: herb + alchemy

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
        local hasRiposteTalent = MS:GetTalent(2, 8)

        if hasRiposteTalent then
            local hasParried = arg1 == "player" and arg2 == "PARRY"

            if hasParried then
                rg.lastParry = GetTime()
            end
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
        -- local hp = MS:HPPercent("player")

        if not inCombat then
            hasStealth = MS:CastSpell("Stealth")
        end
    end

    return hasStealth
end

function MS:R_CrowdControl()
    -- try to get in Stealth
    local hasStealth = MS:FindBuff("Stealth", "player")

    if not hasStealth then
        hasStealth = MS:R_Stealth()
        if hasStealth then return end
    end

    local isValidMouseover =
        not UnitIsUnit("target", "mouseover") and UnitExists("mouseover") and
        not UnitIsDeadOrGhost("mouseover") and not UnitIsFriend("player", "mouseover") and
        CheckInteractDistance("mouseover", 3)

    local hasCast = false
    local targetShouldBeStunned = false
    local mouseoverShouldBeStunned = false
    local hp = MS:HPPercent("player")

    local isClose = CheckInteractDistance("target", 3)
    local hasGouge = MS:FindBuff("Gouge", "target")
    local hasBlind = MS:FindBuff("Blind", "target")
    local hasKidney = MS:FindBuff("Kidney Shot", "target")
    local hasCheapShot = MS:FindBuff("Cheap Shot", "target")

    targetShouldBeStunned = isClose and not hasGouge and not hasBlind and not hasKidney and not hasCheapShot

    if isValidMouseover then
        isClose = CheckInteractDistance("mouseover", 3)
        hasGouge = MS:FindBuff("Gouge", "mouseover")
        hasBlind = MS:FindBuff("Blind", "mouseover")
        hasKidney = MS:FindBuff("Kidney Shot", "mouseover")
        hasCheapShot = MS:FindBuff("Cheap Shot", "mouseover")

        -- it is ok for mouseover to only be sapped
        local hasSap = MS:FindBuff("Sap", "mouseover")

        mouseoverShouldBeStunned = isClose and not hasGouge and not hasBlind and not hasKidney and not hasCheapShot and not hasSap

        if mouseoverShouldBeStunned then TargetUnit("mouseover") end
    end

    -- maybe target doesn't need CC
    if not mouseoverShouldBeStunned and not targetShouldBeStunned then
        if hp < 60 then
            local usedHPPot = MS:UseHealthConsumable()
            if usedHPPot then return end
        end

        -- return to main target
        if mouseoverShouldBeStunned then TargetLastTarget() end
        return
    end

    local imSafe = not UnitIsUnit("player", "targettarget")

    if hasStealth and imSafe then
        -- cast Sap
        local enemyInCombat = UnitAffectingCombat("target")
        local enemyIsPlayer = UnitIsPlayer("target")
        local isHumanoid = UnitCreatureType("target") == "Humanoid"
        local hasSap = MS:FindBuff("Sap", "target")

        if not hasCast and not hasSap and not enemyInCombat and (enemyIsPlayer or isHumanoid) then
            hasCast = MS:CastSpell("Sap")
        end

        -- cast Cheap Shot
        if not hasCast then
            hasCast = MS:CastSpell("Cheap Shot")
        end

        -- don't get out of stealth
        local energy = UnitMana("player")
        if energy < 60 then
            -- return to main target
            if mouseoverShouldBeStunned then TargetLastTarget() end
            return
        end
    end

    -- try to Kidney Shot
    if not hasCast then
        local unitLvl = UnitLevel("target")
        local isBoss = type(unitLvl) ~= "number" or unitLvl < 1
        local comboPoints = GetComboPoints("player", "target")
        local shouldKidneyShot = not isBoss and comboPoints > 2

        if shouldKidneyShot then
            hasCast = MS:CastSpell("Kidney Shot")
        end
    end

    -- try to Kick
    if not hasCast then hasCast = MS:Silence("Kick") end

    -- try to Gauge
    if not hasCast then hasCast = MS:CastSpell("Gouge") end

    -- try to Blind
    if not hasCast then hasCast = MS:CastSpell("Blind") end

    -- return to main target
    if mouseoverShouldBeStunned then TargetLastTarget() end
    return
end

function MS:R_Damage()
    -- target a valid enemy
    local hasTarget = MS:TargetEnemy()
    if not hasTarget then return end

    -- can't attack if they are not close
    local isClose = CheckInteractDistance("target", 3)

    if not isClose then
        ClearTarget()
        return
    end

    local hasCast = false
    local comboPoints = GetComboPoints("player", "target")
    local hp = MS:HPPercent("player")
    local energy = UnitMana("player")

    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")
    local enemyInCombat = UnitAffectingCombat("target")

    local _, mainSubType = MS:GetItemType(MS:GetEquipmentItemLink("main"))
    local hasDagger = mainSubType == "Daggers"
    local hasStealth = MS:FindBuff("Stealth", "player")
    local imSafe = not UnitIsUnit("player", "targettarget")

    -- get in Stealth if appropriate
    if not hasStealth and enemyIsPlayer then
        hasStealth = MS:R_Stealth()
        if hasStealth then return end
    end

    -- do the stealth combo
    if hasStealth and imSafe then
        -- cast Pick Pocket
        if not enemyIsPlayer and not rg.hasPickedPockets then
            hasCast = MS:CastSpell("Pick Pocket")

            if hasCast then
                rg.hasPickedPockets = true
                return
            end
        end

        -- cast Garrote
        local unitLvl = UnitLevel("target")
        local isBoss = type(unitLvl) ~= "number" or unitLvl < 1
        local hasOpportunityTalent = MS:GetTalent(3, 2)
        local shouldGarrote = not hasDagger and hasOpportunityTalent

        if isBoss or shouldGarrote then
            hasCast = MS:CastSpell("Garrote")
            if hasCast then return end
        end

        -- cast Cheap Shot
        if not hasDagger or enemyIsPlayer then
            hasCast = MS:CastSpell("Cheap Shot")
            if hasCast then return end

            -- for low lvl
            hasCast = MS:CastSpell("Sinister Strike")
            if hasCast then return end
        end

        -- cast Ambush
        if hasDagger then
            hasCast = MS:CastSpell("Ambush")
            if hasCast then return end

            -- for low lvl
            hasCast = MS:CastSpell("Backstab")
            if hasCast then return end
        end

        -- don't get out of stealth unintentionally
        return
    end

    -- cast low hp spells
    if hp < 50 then
        -- cast Evasion
        local hasEvasion = MS:FindBuff("Evasion", "player")
        if not hasEvasion and not imSafe then
            hasCast = MS:CastSpell("Evasion")
            if hasCast then return end
        end

        -- cast Berserking (troll racial)
        local hasBerserking = MS:FindBuff("Berserking", "player")
        if not hasBerserking then
            hasCast = MS:CastSpell("Berserking")
            if hasCast then return end
        end

        local wasUsed = MS:UseHealthConsumable()
        if wasUsed then return end
    end

    -- start melee auto attacking
    if not MS.isMeleeAttacking then AttackTarget("target") end

    -- try to Backstab before anything else during stun
    local hasGouge = MS:FindBuff("Gouge", "target")
    local hasBlind = MS:FindBuff("Blind", "target")
    local hasKidney = MS:FindBuff("Kidney Shot", "target")
    local hasCheapShot = MS:FindBuff("Cheap Shot", "target")
    local hasSap = MS:FindBuff("Sap", "target")
    local targetIsStunned = hasGouge or hasBlind or hasKidney or hasCheapShot or hasSap

    if targetIsStunned and hasDagger then
        hasCast = MS:CastSpell("Backstab")
        return -- wait for Backstab
    end

    -- cast Kick
    hasCast = MS:Silence("Kick")
    if hasCast then return end

    -- cast Riposte
    local hasRiposteTalent = MS:GetTalent(2, 8)

    if hasRiposteTalent then
        -- don't check if debuff is active on purpose (more dmg)
        local canRiposte = ((GetTime() - rg.lastParry) < 5)

        if canRiposte then
            hasCast = MS:CastSpell("Riposte")
            if hasCast then return end
        end
    end

    -- cast Expose Armor
    local hasSunderArmor = MS:FindBuff("Sunder Armor", "target")
    local hasExposeArmor = MS:FindBuff("Expose Armor", "target")
    local shouldExposeArmor = comboPoints > 2 and enemyHP > 50 and not hasExposeArmor and not hasSunderArmor

    if shouldExposeArmor then
        hasCast = MS:CastSpell("Expose Armor")
        if hasCast then return end
    end

    -- cast Eviscerate
    local shouldEvis = comboPoints == 5 or (comboPoints > 1 and enemyHP < 30)

    if shouldEvis then
        hasCast = MS:CastSpell("Eviscerate")
        if hasCast then return end
    end

    -- cast Ghostly Strike
    local hasGhostlyStrike = MS:FindBuff("Ghostly Strike", "player")

    if not hasGhostlyStrike and not imSafe and enemyHP > 30 then
        hasCast = MS:CastSpell("Ghostly Strike")
        if hasCast then return end
    end

    -- cast Backstab
    if hasDagger and rg.tryBackstab then
        hasCast = MS:CastSpell("Backstab")
        if hasCast then return end

        -- wait for energy
        if energy < 60 then return end
    else
        -- reset the variable
        rg.tryBackstab = true
    end

    -- cast Slice and Dice
    local hasSliceAndDice = MS:FindBuff("Slice and Dice", "player")
    local shouldSliceDice = comboPoints == 1 and not hasSliceAndDice

    if shouldSliceDice then
        hasCast = MS:CastSpell("Slice and Dice")
        if hasCast then return end
    end

    -- cast Sinister Strike
    hasCast = MS:CastSpell("Sinister Strike")
    if hasCast then return end
end

function MS:R_Speed()
    -- cast Sprint
    local hasCast = MS:CastSpell("Sprint")
    if hasCast then return end

    -- use Swiftness Potion
    local wasUsed = MS:UseBagItem("Swiftness Potion")
    if wasUsed then return end
end
