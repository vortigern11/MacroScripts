-- Battle or Berserker skills: "Execute", "Hamstring"
-- Battle or Defensive skills: "Rend", "Shield Bash", "Thunder Clap"

-- Battle skills: "Charge", "Mocking Blow", "Overpower", "Retaliation"
-- Defensive skills: "Disarm", "Revenge", "Shield Block", "Shield Wall", "Taunt"
-- Berserker skills: "Berserker Rage", "Intercept", "Pummel", "Recklessness", "Whirlwind"

-- [Tank vs DPS mode] is different than [Equipped Weapons]
-- 1) if in tank mode: stay in defensive stance generally and use taunting abilities
-- 2) depending on how much HP I have and which skills I have to use, switch weapons

local BAT_STANCE = "Battle Stance"
local DEF_STANCE = "Defensive Stance"
local BER_STANCE = "Berserker Stance"

local war = CreateFrame("Frame")

war.lastDodge = 0
war.lastMitigate = 0
war.imTank = false

war:RegisterEvent("UNIT_COMBAT")
war:RegisterEvent("PLAYER_REGEN_ENABLED")

war:SetScript("OnEvent", function()
    if UnitClass("player") ~= "Warrior" then
        war:UnregisterAllEvents()
        return
    end

    if event == "UNIT_COMBAT" then
        -- get last dodge/parry/block time
        local hasTargetDodged = arg1 == "target" and arg2 == "DODGE"
        local hasParried = arg1 == "player" and arg2 == "PARRY"
        local hasBlocked = arg1 == "player" and arg2 == "BLOCK"
        local hasDodged = arg1 == "player" and arg2 == "DODGE"

        if hasTargetDodged then
            war.lastDodge = GetTime()
        end

        if hasParried or hasBlocked or hasDodged then
            war.lastMitigate = GetTime()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        local hasCast = false
        local hp = MS:HPPercent("player")
        local _, _, isDefStance = GetShapeshiftFormInfo(2)
        local inParty = UnitExists("party1")
        local _, offSubType = MS:GetItemType(MS:GetEquipmentItemLink("off"))
        local hasShield = offSubType == "Shields"

        -- change to Damage mode outside of dungeon/raid
        if not inParty and war.imTank then
            MS:Print("DAMAGE MODE")
            war.imTank = false
        end

        if not war.imTank and hasShield and hp > 50 then
            MS:WAR_SwitchWeapons()
        end

        if not war.imTank and isDefStance then
            if hp > 50 then
                hasCast = MS:CastSpell(BER_STANCE)
                if hasCast then return end
            end

            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end
    end
end)

-- top right action bar slots (under minimap)
-- first 2 are for 1h+shield
-- below are for 2h or 1h+1h
function MS:WAR_SwitchWeapons()
    local _, offSubType = MS:GetItemType(MS:GetEquipmentItemLink("off"))
    local hasShield = offSubType == "Shields"

    if not hasShield then
        UseAction(37)
        UseAction(25)
    else
        UseAction(38)
        UseAction(26)
    end
end

-- switches between tank and damage mode
function MS:WAR_SwitchMode()
    local inCombat = UnitAffectingCombat("player")
    local _, _, isBatStance = GetShapeshiftFormInfo(1)
    local _, _, isDefStance = GetShapeshiftFormInfo(2)
    local _, offSubType = MS:GetItemType(MS:GetEquipmentItemLink("off"))
    local hasShield = offSubType == "Shields"

    if war.imTank then
        if not inCombat and not isBatStance then
            MS:CastSpell(BAT_STANCE)
        end

        if hasShield then MS:WAR_SwitchWeapons() end

        MS:Print("DAMAGE MODE")
        war.imTank = false
    else
        if not inCombat and not isDefStance then
            MS:CastSpell(DEF_STANCE)
        end

        if not hasShield then MS:WAR_SwitchWeapons() end

        MS:Print("TANK MODE")
        war.imTank = true
    end
end

function MS:WAR_GodSkill()
    -- target a valid enemy
    local hasTarget = MS:TargetEnemy()
    if not hasTarget then return end

    local hasCast = false
    local hp = MS:HPPercent("player")
    local isClose = CheckInteractDistance("target", 3)
    local imTarget = UnitIsUnit("player", "targettarget")
    local _, _, isBatStance = GetShapeshiftFormInfo(1)
    local _, _, isDefStance = GetShapeshiftFormInfo(2)
    local _, _, isBerStance = GetShapeshiftFormInfo(3)

    -- cast Recklessness
    local hasReck, isReckOnCD = MS:FindSpell("Recklessness")

    if hasReck and not isReckOnCD and isClose and not imTarget and hp > 65 then
        if not isBerStance then
            hasCast = MS:CastSpell(BER_STANCE)
            if hasCast then return end
        end

        hasCast = MS:CastSpell("Recklessness")
        if hasCast then return end
    end

    -- cast Retaliation
    local hasReta, isRetaOnCD = MS:FindSpell("Retaliation")

    if hasReta and not isRetaOnCD and isClose and imTarget then
        if not isBatStance then
            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end

        hasCast = MS:CastSpell("Retaliation")
        if hasCast then return end
    end
end

function MS:WAR_CC()
    -- target a valid enemy
    local hasTarget = MS:TargetEnemy()
    if not hasTarget then return false end

    local hasCast = false
    local hp = MS:HPPercent("player")
    local rage = UnitMana("player")
    local isClose = CheckInteractDistance("target", 3)
    local isSlowed = MS:FindBuff("Hamstring", "target")
    local targetIsCasting = ShaguTargetCastbar and ShaguTargetCastbar:IsVisible()
    local _, _, isDefStance = GetShapeshiftFormInfo(2)
    local _, _, isBerStance = GetShapeshiftFormInfo(3)
    local _, offSubType = MS:GetItemType(MS:GetEquipmentItemLink("off"))
    local hasShield = offSubType == "Shields"

    if isClose and rage >= 10 then
        if targetIsCasting then
            if isBerStance then
                -- cast Pummel
                if not hasCast then
                    hasCast = MS:Silence("Pummel")
                end
            elseif hasShield then
                -- cast Shield Bash
                if not hasCast then
                    hasCast = MS:Silence("Shield Bash")
                end
            end
        elseif not isSlowed then
            -- switch stance
            if isDefStance then
                if not hasCast and hp > 50 then
                    hasCast = MS:CastSpell(BER_STANCE)
                end

                if not hasCast then
                    hasCast = MS:CastSpell(BAT_STANCE)
                end
            end

            -- cast Hamstring
            if not hasCast then
                hasCast = MS:CastSpell("Hamstring")
            end
        end
    end

    return hasCast
end

function MS:WAR_Shout()
    local hasCast = false
    local hp = MS:HPPercent("player")

    if hp > 50 then
        hasCast = MS:CastSpell("Challenging Shout")
        if hasCast then return end
    else
        hasCast = MS:CastSpell("Intimidating Shout")
        if hasCast then return end
    end
end

function MS:WAR_RunAway()
    local hasCast = false
    local hp = MS:HPPercent("player")
    local level = UnitLevel("player")
    local enemyIsPlayer = UnitIsPlayer("target")
    local _, offSubType = MS:GetItemType(MS:GetEquipmentItemLink("off"))
    local hasShield = offSubType == "Shields"
    local _, _, isDefStance = GetShapeshiftFormInfo(2)

    -- use health consumable
    local wasUsed = MS:UseHealthConsumable()
    if wasUsed then return end

    -- switch to Defensive Stance
    if not isDefStance then
        hasCast = MS:CastSpell(DEF_STANCE)
        if hasCast then return end
    end

    -- cast Shield Wall
    if not enemyIsPlayer and level >= 10 then
        -- equip Shield
        if not hasShield then MS:WAR_SwitchWeapons() end

        -- stop melee auto attacking
        if MS.isMeleeAttacking then AttackTarget("target") end

        -- cast Shield Wall
        local hasWall, isWallOnCD = MS:FindSpell("Shield Wall")

        if hasWall and not isWallOnCD then
            hasCast = MS:CastSpell("Shield Wall")
            if hasCast then return end
        end
    end
end

function MS:WAR_AOE()
    -- target a valid enemy
    local hasTarget = MS:TargetEnemy()
    if not hasTarget then return end

    local hasCast = false
    local hp = MS:HPPercent("player")
    local rage = UnitMana("player")
    local _, _, isBatStance = GetShapeshiftFormInfo(1)
    local _, _, isBerStance = GetShapeshiftFormInfo(3)

    local isClose = CheckInteractDistance("target", 3)

    if not isClose then
        MS:WAR_Damage()
        return
    end

    -- start melee auto attacking
    if not MS.isMeleeAttacking then AttackTarget("target") end

    if rage >= 20 then
        -- cast Thunder Clap
        if not isBerStance then
            hasCast = MS:CastSpell("Thunder Clap")
            if hasCast then return end
        end

        -- cast Whirlwind
        if isBerStance then
            hasCast = MS:CastSpell("Whirlwind")
            if hasCast then return end
        end

        -- cast Sweeping Strikes
        if isBatStance then
            hasCast = MS:CastSpell("Sweeping Strikes")
            if hasCast then return end
        end

        -- cast Cleave
        hasCast = MS:CastSpell("Cleave")
        if hasCast then return end

        -- switch stance for Thunder Clap
        local hasClap, isClapOnCD = MS:FindSpell("Thunder Clap")

        if hasClap and not isClapOnCD and isBerStance then
            if war.imTank or hp < 50 then
                hasCast = MS:CastSpell(DEF_STANCE)
                if hasCast then return end
            end

            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end

        -- switch stance for Whirlwind
        local hasWhirl, isWhirlOnCD = MS:FindSpell("Whirlwind")

        if hasWhirl and not isWhirlOnCD and not isBerStance and hp > 50 then
            hasCast = MS:CastSpell(BER_STANCE)
            if hasCast then return end
        end

        -- switch stance for Sweeping Strikes
        local hasSS, isSSOnCD = MS:FindSpell("Sweeping Strikes")

        if haSS and not isSSOnCD and not isBatStance then
            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end

    end

    -- cast Bloodrage
    if rage < 40 and hp > 70 then
        hasCast = MS:CastSpell("Bloodrage")
        if hasCast then return end
    end

    -- do the normal damage macro
    if rage >= 20 then MS:WAR_Damage() end
end

function MS:WAR_Damage()
    -- target a valid enemy
    local hasTarget = MS:TargetEnemy()
    if not hasTarget then return end

    local hasCast = false
    local hp = MS:HPPercent("player")
    local rage = UnitMana("player")
    local level = UnitLevel("player")
    local inCombat = UnitAffectingCombat("player")

    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")
    local enemyInCombat = UnitAffectingCombat("target")
    local isEliteMob = UnitIsPlusMob("target")
    local isTrivial = UnitIsTrivial("target")
    local isMechanical = UnitCreatureType("target") == "Mechanical"

    local _, offSubType = MS:GetItemType(MS:GetEquipmentItemLink("off"))
    local hasShield = offSubType == "Shields"
    local imTarget = UnitIsUnit("player", "targettarget")
    local inInstance, instanceType = IsInInstance()
    local inDungOrRaid = inInstance and (instanceType == "party" or instanceType == "raid")

    local _, _, isBatStance = GetShapeshiftFormInfo(1)
    local _, _, isDefStance = GetShapeshiftFormInfo(2)
    local _, _, isBerStance = GetShapeshiftFormInfo(3)

    -- cast Berserker Rage before all other casts
    if inCombat and isBerStance and not isTrivial and (enemyHP > 50 or enemyIsPlayer) then
        hasCast = MS:CastSpell("Berserker Rage")
        if hasCast then return end
    end

    -- cast Charge or Intercept when not close
    local isClose = CheckInteractDistance("target", 3)

    if not isClose and not inDungOrRaid then
        if not inCombat and hp > 50 then
            if not isBatStance then
                hasCast = MS:CastSpell(BAT_STANCE)
                if hasCast then return end
            else
                hasCast = MS:CastSpell("Charge")
                if hasCast then return end
            end
        else
            if not isBerStance then
                hasCast = MS:CastSpell(BER_STANCE)
                if hasCast then return end
            else
                hasCast = MS:CastSpell("Intercept")
                if hasCast then return end
            end
        end

        -- do nothing if didn't Charge
        return
    end

    -- start melee auto attacking
    if not MS.isMeleeAttacking then AttackTarget("target") end

    -- cast low hp spells
    if hp < 50 and inCombat then
        -- cast Berserking (troll racial)
        local hasBerserking = MS:FindBuff("Berserking", "player")

        if not hasBerserking then
            hasCast = MS:CastSpell("Berserking")
            if hasCast then return end
        end
    end

    -- cast Execute
    local hasExecute = MS:FindSpell("Execute")

    if hasExecute and enemyHP <= 20 and rage >= 10 then
        if isDefStance then
            if hp > 50 then
                hasCast = MS:CastSpell(BER_STANCE)
                if hasCast then return end
            end

            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end

        hasCast = MS:CastSpell("Execute")
        if hasCast then return end
    end

    -- cast Overpower
    local hasOverpower, isOverpowerOnCD = MS:FindSpell("Overpower")
    local canOverpower = (GetTime() - war.lastDodge) < 5

    if hasOverpower and not isOverpowerOnCD and canOverpower then
        if not isBatStance then
            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end

        hasCast = MS:CastSpell("Overpower")
        if hasCast then return end
    end

    -- cast Revenge
    local hasRevenge, isRevengeOnCD = MS:FindSpell("Revenge")
    local canRevenge = (GetTime() - war.lastMitigate) < 5

    if hasRevenge and not isRevengeOnCD and canRevenge and (war.imTank or not inDungOrRaid) then
        if not isDefStance then
            hasCast = MS:CastSpell(DEF_STANCE)
            if hasCast then return end
        end

        hasCast = MS:CastSpell("Revenge")
        if hasCast then return end
    end

    -- cast Taunt
    local hasTaunt, isTauntOnCD = MS:FindSpell("Taunt")

    if hasTaunt and not isTauntOnCD and war.imTank and not imTarget and hp > 50 then
        if not isDefStance then
            hasCast = MS:CastSpell(DEF_STANCE)
            if hasCast then return end
        end

        hasCast = MS:CastSpell("Taunt")
        if hasCast then return end
    end

    -- cast Mocking Blow
    local hasMocking, isMockingOnCD = MS:FindSpell("Mocking Blow")

    if hasMocking and not isMockingOnCD and war.imTank and not imTarget and hp > 50 then
        if not isBatStance then
            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end

        hasCast = MS:CastSpell("Mocking Blow")
        if hasCast then return end
    end

    -- change to main stance
    if war.imTank then
        if not isDefStance then
            hasCast = MS:CastSpell(DEF_STANCE)
            if hasCast then return end
        end
    else
        if not isBerStance and hp > 50 then
            hasCast = MS:CastSpell(BER_STANCE)
            if hasCast then return end
        end

        if not isBatStance then
            hasCast = MS:CastSpell(BAT_STANCE)
            if hasCast then return end
        end
    end

    -- DON'T CHANGE STANCE AFTER THIS LINE

    -- cast Demo Shout
    local hasDemoShout = MS:FindBuff("Demoralizing Shout", "target")

    if not hasDemoShout and not isTrivial and enemyHP > 30 then
        hasCast = MS:CastSpell("Demoralizing Shout")
        if hasCast then return end
    end

    -- cast Battle Shout
    local hasBattleShout = MS:FindBuff("Battle Shout", "player")

    if not hasBattleShout then
        hasCast = MS:CastSpell("Battle Shout")
        if hasCast then return end
    end

    if isDefStance and not isTrivial then
        -- cast Shield Block
        local hasShieldBlock = MS:FindBuff("Shield Block", "player")

        if hasShield and not hasShieldBlock then
            hasCast = MS:CastSpell("Shield Block")
            if hasCast then return end
        end

        -- cast Disarm
        local hasDisarm = MS:FindBuff("Disarm", "target")

        if not hasDisarm then
            hasCast = MS:CastSpell("Disarm")
            if hasCast then return end
        end
    end

    -- cast Sunder Armor
    local hasSunder, sunderStacks = MS:FindBuff("Sunder Armor", "target")
    local shouldSunder = isEliteMob or (level >= 22 and not isTrivial)

    if shouldSunder and enemyHP > 50 and (not hasSunder or sunderStacks < 5) then
        hasCast = MS:CastSpell("Sunder Armor")
        if hasCast then return end
    end

    -- cast Rend
    if not isBerStance and not isTrivial and (level < 40 or enemyIsPlayer) then
        local hasRend = MS:FindBuff("Rend", "target")

        if not hasRend and enemyHP > 50 and not isMechanical then
            hasCast = MS:CastSpell("Rend")
            if hasCast then return end
        end
    end

    -- cast Heroic Strike
    if rage >= 20 and (war.imTank or not inDungOrRaid) then
        hasCast = MS:CastSpell("Heroic Strike")
        if hasCast then return end
    end

    -- cast Bloodrage
    if rage < 40 and hp > 70 and enemyHP > 30 then
        hasCast = MS:CastSpell("Bloodrage")
        if hasCast then return end
    end
end
