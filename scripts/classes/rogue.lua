-- hardcore professions: herb + alchemy

local rg = CreateFrame("Frame")

rg.hasPickedPockets = false
rg.tryBackstab = true
rg.lastParry = 0

rg:RegisterEvent("UI_ERROR_MESSAGE")
rg:RegisterEvent("UNIT_COMBAT")
rg:RegisterEvent("PLAYER_TARGET_CHANGED")

rg:SetScript("OnEvent", function()
    if UnitClass("player") ~= "Rogue" then
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

    local hasStealth = MS:FindBuff("Stealth", "player")
    local hasBleed = MS:FindBuff("Garrote", "target")
    hasBleed = hasBleed or MS:FindBuff("Rupture", "target")

    if hasStealth then
        -- cast Sap
        local enemyInCombat = UnitAffectingCombat("target")
        local enemyIsPlayer = UnitIsPlayer("target")
        local isHumanoid = UnitCreatureType("target") == "Humanoid"
        local hasSap = MS:FindBuff("Sap", "target")

        if not hasCast and not hasSap and not enemyInCombat and not hasBleed and (enemyIsPlayer or isHumanoid) then
            hasCast = MS:CastSpell("Sap")
        end

        -- cast Cheap Shot
        if not hasCast then
            hasCast = MS:CastSpell("Cheap Shot")
        end

        -- don't get out of stealth
        local inCombat = UnitAffectingCombat("player")

        if not inCombat then
            if mouseoverShouldBeStunned then TargetLastTarget() end
            return
        end
    end

    -- try to Kidney Shot
    if not hasCast then
        local targetLvl = UnitLevel("target")
        local isBoss = type(targetLvl) ~= "number" or targetLvl < 1
        local comboPoints = GetComboPoints("player", "target")

        if not isBoss and comboPoints > 3 then
            hasCast = MS:CastSpell("Kidney Shot")
        end
    end

    -- try to Kick
    if not hasCast then hasCast = MS:Silence("Kick") end

    if not hasBleed then
        -- try to Gauge
        if not hasCast then hasCast = MS:CastSpell("Gouge") end

        -- try to Blind
        if not hasCast then hasCast = MS:CastSpell("Blind") end
    end

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
    local level = UnitLevel("player")
    local inCombat = UnitAffectingCombat("target")

    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")
    local enemyInCombat = UnitAffectingCombat("target")
    local enemyWarrior = enemyIsPlayer and UnitClass("target") == "Warrior"

    local _, mainSubType = MS:GetItemType(MS:GetEquipmentItemLink("main"))
    local hasDagger = mainSubType == "Daggers"
    local hasStealth = MS:FindBuff("Stealth", "player")

    local hasGouge = MS:FindBuff("Gouge", "target")
    local hasBlind = MS:FindBuff("Blind", "target")
    local hasKidney = MS:FindBuff("Kidney Shot", "target")
    local hasCheapShot = MS:FindBuff("Cheap Shot", "target")
    local hasSap = MS:FindBuff("Sap", "target")
    local targetIsStunned = hasGouge or hasBlind or hasKidney or hasCheapShot or hasSap

    local imSafe = targetIsStunned or not UnitIsUnit("player", "targettarget")
    local inInstance, instanceType = IsInInstance()
    local inDungOrRaid = inInstance and (instanceType == "party" or instanceType == "raid")

    -- get in Stealth if appropriate
    if not hasStealth and enemyIsPlayer then
        hasStealth = MS:R_Stealth()
        if hasStealth then return end
    end

    -- do the stealth combo
    if hasStealth then
        -- cast Pick Pocket
        if not enemyIsPlayer and not rg.hasPickedPockets then
            hasCast = MS:CastSpell("Pick Pocket")

            if hasCast then
                rg.hasPickedPockets = true
                return
            end
        end

        -- cast Sap
        local enemyInCombat = UnitAffectingCombat("target")
        local enemyIsPlayer = UnitIsPlayer("target")
        local hasSap = MS:FindBuff("Sap", "target")
        local hasBleed = MS:FindBuff("Garrote", "target")
        hasBleed = hasBleed or MS:FindBuff("Rupture", "target")

        if enemyIsPlayer and not hasSap and not enemyInCombat and not hasBleed then
            hasCast = MS:CastSpell("Sap")
            if hasCast then return end
        end

        -- cast Garrote
        local targetLvl = UnitLevel("target")
        local isBoss = type(targetLvl) ~= "number" or targetLvl < 1
        local hasOpportunityTalent = MS:GetTalent(3, 2)

        if isBoss or (not hasDagger and hasOpportunityTalent) then
            hasCast = MS:CastSpell("Garrote")
            if hasCast then return end
        end

        -- cast Cheap Shot
        if not hasDagger or (comboPoints == 0 and enemyIsPlayer) then
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
        if not inCombat then return end
    end

    -- start melee attack
    if not MS.isMeleeAttacking and not targetIsStunned then
        AttackTarget("target")
    end

    -- cast low hp spells
    if hp < 50 then
        -- cast Berserking (troll racial)
        local hasBerserking = MS:FindBuff("Berserking", "player")

        if not hasBerserking then
            hasCast = MS:CastSpell("Berserking")
            if hasCast then return end
        end

        -- consume for HP
        local wasUsed = MS:UseHealthConsumable()
        if wasUsed then return end

        -- cast Evasion
        local hasEvasion = MS:FindBuff("Evasion", "player")

        if not hasEvasion and not imSafe and not enemyWarrior then
            hasCast = MS:CastSpell("Evasion")
            if hasCast then return end
        end
    end

    -- cast Feint
    if inDungOrRaid and not imSafe then
        hasCast = MS:CastSpell("Feint")
        if hasCast then return end
    end

    -- cast Adrenaline Rush
    local hasBladeFlurry = MS:FindBuff("Blade Flurry", "player")

    if hasBladeFlurry then
        hasCast = MS:CastSpell("Adrenaline Rush")
        if hasCast then return end
    end

    -- cast Kidney Shot
    if enemyIsPlayer and comboPoints == 5 then
        hasCast = MS:CastSpell("Kidney Shot")
        if hasCast then return end
    end

    -- cast Backstab
    local hasBackstab = MS:FindSpell("Backstab")

    if hasBackstab and hasDagger and comboPoints < 5 and (imSafe or rg.tryBackstab) then
        hasCast = MS:CastSpell("Backstab")
        if hasCast or (imSafe and (comboPoints < 3 or enemyHP > 40)) then return end
    end

    -- reset the Backstab variable
    rg.tryBackstab = true

    -- cast Riposte
    local hasRiposteTalent = MS:GetTalent(2, 8)

    if hasRiposteTalent then
        local canRiposte = ((GetTime() - rg.lastParry) < 5)

        if canRiposte then
            hasCast = MS:CastSpell("Riposte")
            if hasCast then return end
        end
    end

    -- cast Slice and Dice
    local hasSliceAndDice = MS:FindBuff("Slice and Dice", "player")

    if not hasSliceAndDice and comboPoints > 0 and not enemyIsPlayer then
        if comboPoints == 1 or (level >= 60 and inDungOrRaid) then
            hasCast = MS:CastSpell("Slice and Dice")
            if hasCast then return end
        end
    end

    -- cast Rupture or Expose Armor
    if comboPoints > 1 and enemyHP > 50 then
        local hasRuptureTalent = MS:GetTalent(3, 11)

        if hasRuptureTalent then
            local hasRupture = MS:FindBuff("Rupture", "target")

            if not hasRupture then
                hasCast = MS:CastSpell("Rupture")
                if hasCast then return end
            end
        else
            local hasSunderArmor = MS:FindBuff("Sunder Armor", "target")
            local hasExposeArmor = MS:FindBuff("Expose Armor", "target")

            if inDungOrRaid and not hasExposeArmor and not hasSunderArmor then
                hasCast = MS:CastSpell("Expose Armor")
                if hasCast then return end
            end
        end
    end

    -- cast Eviscerate
    if comboPoints == 5 or (comboPoints > 2 and enemyHP < 40) then
        hasCast = MS:CastSpell("Eviscerate")
        if hasCast then return end
    end

    -- cast Hemmorhage
    local hasHemmorhage = MS:FindBuff("Hemmorhage", "target")

    if not hasHemmorhage then
        hasCast = MS:CastSpell("Hemmorhage")
        if hasCast then return end
    end

    -- cast Ghostly Strike
    local hasGhostlyStrike = MS:FindBuff("Ghostly Strike", "player")

    if not hasGhostlyStrike and not imSafe and enemyHP > 30 and not enemyWarrior then
        hasCast = MS:CastSpell("Ghostly Strike")
        if hasCast then return end
    end

    -- cast Sinister Strike
    hasCast = MS:CastSpell("Sinister Strike")
    if hasCast then return end
end

function MS:R_Speed()
    local hasCast = false

    -- cast Exit Strategy(gnome racial)
    hasCast = MS:CastSpell("Exit Strategy")
    if hasCast then return end

    -- cast Sprint
    hasCast = MS:CastSpell("Sprint")
    if hasCast then return end

    -- use Swiftness Potion
    hasCast = MS:UseBagItem("Swiftness Potion")
    if hasCast then return end
end

function MS:R_Vanish()
    local hasStealth = MS:FindBuff("Stealth", "player")

    -- cast Vanish or Preparation
    if not hasStealth then
        hasStealth = MS:CastSpell("Vanish")
        if hasStealth then return end

        local hasCast = MS:CastSpell("Preparation")
        if hasCast then return end
    end
end
