local function LimitSoulshards()
    local shards = {}
    local shardsAmount = 0
    local firstShardId = 1

    local itemName = "Soul Shard"
    local onlyOnce = false

    MS:DoForItemInBags(itemName, onlyOnce, function(bag, slot)
        table.insert(shards, { bag, slot })
        shardsAmount = shardsAmount + 1

        if shardsAmount > MS_CONFIG.soulshards then
            local a, b = unpack(shards[firstShardId])

            MS:DestroyInBagAtSlot(a, b)
            firstShardId = firstShardId + 1
        end
    end)
end

local function SetupSoulshardRemoval()
    -- Set default to max from Felcloth Bag
    if not MS_CONFIG then
        MS_CONFIG = { soulshards = 28 }
    end

    -- Limit Soul Shard amount to `/soulshards X` amount
    SLASH_SOULSHARDS1 = "/soulshards";
    SlashCmdList["SOULSHARDS"] = function(arg)
        if arg == "info" then
            MS:Print("Soulshard limit is " .. MS_CONFIG.soulshards)
            return
        end

        local amount = tonumber(arg)
        local isAmountValid = amount ~= nil and amount > 1

        if isAmountValid then
            MS_CONFIG.soulshards = math.floor(amount)
            MS:Print("New Soulshard limit is " .. MS_CONFIG.soulshards)
        end

        LimitSoulshards()
    end

end

local wl = CreateFrame("Frame")

wl:RegisterEvent("ADDON_LOADED")
wl:RegisterEvent("PLAYER_XP_UPDATE")
wl:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
MS:RegisterEvent("PLAYER_TARGET_CHANGED")

wl:SetScript("OnEvent", function()
    local playerIsNotWarlock = UnitClass("player") ~= "Warlock"

    if playerIsNotWarlock then return end

    if event == "ADDON_LOADED" then
        SetupSoulshardRemoval()
    elseif event == "PLAYER_XP_UPDATE" then
        LimitSoulshards()
    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        LimitSoulshards()
    elseif event == "PLAYER_TARGET_CHANGED" then
        MS.warlockDotIdx = 1
    end
end)

function MS:WL_Soulstone()
    -- Find highest level of the spell learned
    local spellToItemDict = {
        { "Create Soulstone (Major)()", "Major Soulstone" },
        { "Create Soulstone (Greater)()", "Greater Soulstone" },
        { "Create Soulstone", "Soulstone" },
        { "Create Soulstone (Lesser)()", "Lesser Soulstone" },
        { "Create Soulstone (Minor)()", "Minor Soulstone" },
    }
    local stoneSpellName = ""
    local stoneItemName = ""

    MS:TraverseTable(spellToItemDict, function(_, val)
        local spell, item = unpack(val)
        local wasFound = MS:FindSpell(spell)

        if wasFound then
            stoneSpellName = spell
            stoneItemName = item

            return "break loop"
        end
    end)

    -- If stone in bag, use it
    local onlyOnce = true
    local wasStoneInBag = MS:DoForItemInBags(stoneItemName, onlyOnce, function(bag, slot)
        local mustRetarget = not UnitInParty("target") and not UnitInRaid("target")

        if mustRetarget then TargetUnit("player") end

        local wasUsed = MS:UseBagItem(stoneItemName)

        if mustRetarget then TargetLastTarget() end
    end)

    if wasStoneInBag then return end

    -- Create stone
    MS:CastSpell(stoneSpellName)
end

function MS:WL_Healthstone()
    -- Find highest level of the spell learned
    local spellToItemDict = {
        { "Create Healthstone (Major)()", "Major Healthstone" },
        { "Create Healthstone (Greater)()", "Greater Healthstone" },
        { "Create Healthstone", "Healthstone" },
        { "Create Healthstone (Lesser)()", "Lesser Healthstone" },
        { "Create Healthstone (Minor)()", "Minor Healthstone" },
    }
    local stoneSpellName = ""
    local stoneItemName = ""

    MS:TraverseTable(spellToItemDict, function(_, val)
        local spell, item = unpack(val)
        local wasFound = MS:FindSpell(spell)

        if wasFound then
            stoneSpellName = spell
            stoneItemName = item

            return "break loop"
        end
    end)

    -- Use any health consumable
    local wasItemUsed = MS:UseHealthConsumable()

    if wasItemUsed then return end

    -- If spell not on cd, create stone
    if not MS.inCombat then
        local isStoneInBag = MS:IsItemInBag(stoneItemName)

        if not isStoneInBag then
            MS:CastSpell(stoneSpellName)
            return
        end
    end
end

function MS:WL_Spellstone()
    -- Find highest level of the spell learned
    local spellToItemDict = {
        { "Create Spellstone (Major)()", "Major Spellstone" },
        { "Create Spellstone (Greater)()", "Greater Spellstone" },
        { "Create Spellstone", "Spellstone" },
    }
    local stoneSpellName = ""
    local stoneItemName = ""

    MS:TraverseTable(spellToItemDict, function(_, val)
        local spell, item = unpack(val)
        local wasFound, onCooldown = MS:FindSpell(spell)

        if wasFound then
            stoneSpellName = spell
            stoneItemName = item

            return "break loop"
        end
    end)

    -- If spellstone is equipped, use it
    local offhandItemLink = MS:GetEquipmentItemLink("off")
    local offhandItem = MS:ItemLinkToName(offhandItemLink)
    local stoneIsEquipped = offhandItem == stoneName

    if (stoneIsEquipped and not MS.inCombat) then
        MS:UseEquipment("off")
        return
    end

    -- If spell not on cd, create stone
    local isStoneInBag = MS:IsItemInBag(stoneItemName)

    if not isStoneInBag then
        MS:CastSpell(stoneSpellName)
        return
    end
end

function MS:WL_Replenish()
    local mp = MS:MPPercent("player")

    -- if enough mana -> cast buff
    if mp > 30 and not MS.inCombat then
        -- cast Soul Link if possible
        local hasPet = HasPetUI()
        local hasSoulLink = MS:FindBuff("Soul Link", "player")

        if hasPet and not hasSoulLink then
            local hasCastSoulLink = MS:CastSpell("Soul Link")

            if hasCastSoulLink then return end
        end

        -- cast Demon Buff
        local buffs = { "Demon Armor", "Demon Skin" }
        local wasFound = false

        MS:TraverseTable(buffs, function(_, buffName)
            wasFound = MS:FindBuff(buffName, "player")
            if wasFound then return "break loop" end
        end)

        if not wasFound then
            local hasCast = MS:CastSpell(buffs[0])

            if not hasCast then
                hasCast = MS:CastSpell(buffs[1])
                if hasCast then return end
            end
        end
    end

    -- if low on mana -> regen
    if mp < 90 then
        -- Life Tap if more hp than mana
        local hp = MS:HPPercent("player")

        if hp > mp then
            local hasCast = MS:CastSpell("Life Tap")
            if hasCast then return end
        end

        -- Else try to use Dark Pact
        local hasPet = HasPetUI()

        if hasPet then
            local petMP = MS:MPPercent("pet")

            if petMP > 1 then
                local hasCast = MS:CastSpell("Dark Pact")
                if hasCast then return end
            end
        end

        -- Use other mana consumable
        local wasItemUsed = MS:UseManaConsumable()
        if wasItemUsed then return end

        return
    end
end

function MS:WL_AffliDamage()
    -- Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then TargetNearestEnemy() end

    -- Attack with pet
    MS:PetAttack()

    -- Cast Shadowbolt if I have Shadow Trance
    local haveShadowTrance = MS:FindBuff("Shadow Trance", "player")
    local mp = MS:MPPercent("player")

    if haveShadowTrance and mp > 30 then
        local hasCast = MS:CastSpell("Shadow Bolt")
        if hasCast then return end
    end

    -- Apply dot in solo
    local spellIsCast = false
    local spells = { "Corruption", "Siphon Life", "Curse of Agony" }
    local lastSpellIdx = 3
    local otherCurses = {
        "Curse of Recklessness",
        "Curse of Exhaustion",
        "Curse of Shadow",
        "Curse of the Elements",
        "Curse of Tongues",
        "Curse of Weakness",
        "Curse of Doom"
    }

    MS:TraverseTable(spells, function(_, spellName)
        -- dot on target, cast by me
        local wasFound = MS:FindBuff(spellName, "target")

        -- go to next spell
        if wasFound then return end

        local spellIsAgony = spellName == "Curse of Agony"

        if spellIsAgony then
            -- Don't cast Agony if target has another curse
            local hasOtherCurse = false

            MS:TraverseTable(otherCurses, function(_, curseName)
                hasOtherCurse = MS:FindBuff(curseName, "target")
                if hasOtherCurse then return "break loop" end
            end)

            if hasOtherCurse then return end

            -- cast Amplify Curse if about to cast Curse of Agony
            local _, isGCD = MS:FindSpell("Curse of Agony")

            if not isGCD then
                local hasCastAmplify = MS:CastSpell("Amplify Curse")

                if hasCastAmplify then
                    spellIsCast = true
                    return "break loop"
                end
            end
        end

        local hasCast = MS:CastSpell(spellName)

        if hasCast then
            spellIsCast = true
            return "break loop"
        end
    end)

    if spellIsCast then return end

    -- In case there are other warlocks in the group
    -- since in vanilla you can't get info about who cast the DOT.....
    local inParty = UnitExists("party1")

    if inParty then
        -- assume there is another warlock if in raid
        local hasAnotherWarlock = UnitExists("raid1")

        for i = 1, 4 do
            local currUnit = "party" .. i
            hasAnotherWarlock = UnitExists(currUnit) and UnitClass(currUnit) == "Warlock"
            if hasAnotherWarlock then break end
        end

        if hasAnotherWarlock then
            local idx = MS.warlockDotIdx
            local spellIsAgony = spells[idx] == "Curse of Agony"

            if spellIsAgony then
                -- Don't cast Agony if target has another curse
                local hasOtherCurse = false

                MS:TraverseTable(otherCurses, function(_, curseName)
                    hasOtherCurse = MS:FindBuff(curseName, "target")
                    if hasOtherCurse then return "break loop" end
                end)

                if hasOtherCurse then
                    -- CoA is the last index, so start from the beginning
                    idx = 1
                else
                    -- cast Amplify Curse if about to cast Curse of Agony
                    local _, isGCD = MS:FindSpell("Curse of Agony")

                    if not isGCD then
                        local hasCastAmplify = MS:CastSpell("Amplify Curse")
                        if hasCastAmplify then return end
                    end
                end
            end

            spellIsCast = MS:CastSpell(spells[idx])

            if spellIsCast then
                idx = idx + 1
                if idx > lastSpellIdx then idx = 1 end
                MS.warlockDotIdx = idx
                return
            end
        end
    end
end

function MS:WL_DestroDamage()
    -- Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then TargetNearestEnemy() end

    local spellIsCast = false
    local mp = MS:MPPercent("player")
    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")

    -- Pet attack
    MS:PetAttack()

    -- Cast Shadowbolt if Shadow Trance
    local haveShadowTrance = MS:FindBuff("Shadow Trance", "player")
    local isFirstAttack = not MS.inCombat

    if mp > 20 and (haveShadowTrance or isFirstAttack) then
        local hasCast = MS:CastSpell("Shadow Bolt")
        if hasCast then return end
    end

    -- Apply DOT
    if enemyHP > 35 then
        local spells = { "Immolate", "Corruption" }
        local lastSpellIdx = 2

        MS:TraverseTable(spells, function(_, spellName)
            -- dot on target, cast by me
            local wasFound = MS:FindBuff(spellName, "target")

            if not wasFound then
                spellIsCast = MS:CastSpell(spellName)
                if spellIsCast then return "break loop" end
            end
        end)

        if spellIsCast then return end

        -- cast curse if enemy is a player or in instance
        local inInstance = IsInInstance()

        if enemyIsPlayer or inInstance then
            local curses = {
                "Curse of Agony",
                "Curse of Weakness",
                "Curse of Tongues",
                "Curse of Recklessness",
                "Curse of Exhaustion",
                "Curse of Shadow",
                "Curse of the Elements",
                "Curse of Doom"
            }

            -- Don't cast curse if target has another curse
            local hasOtherCurse = false

            MS:TraverseTable(curses, function(_, curseName)
                hasOtherCurse = MS:FindBuff(curseName, "target")
                if hasOtherCurse then return "break loop" end
            end)

            if not hasOtherCurse then
                local enemyClass = UnitClass("target")
                local enemyIsPriest = enemyClass == "Priest"

                -- cast Amplify Curse if about to cast curse
                local _, isGCD = MS:FindSpell("Curse of Agony")

                if not isGCD and not enemyIsPriest then
                    spellIsCast = MS:CastSpell("Amplify Curse")
                    if spellIsCast then return end
                end

                -- choose a curse depending on class
                if enemyClass == "Warlock" or enemyClass == "Mage" then
                    spellIsCast = MS:CastSpell("Curse of Agony")
                elseif enemyIsPriest then
                    spellIsCast = MS:CastSpell("Curse of Tongues")
                else
                    spellIsCast = MS:CastSpell("Curse of Weakness")
                end

                if spellIsCast then return end
            end
        end
    end

    -- Cast Shadowbolts if I'm safe
    local imTarget = UnitIsUnit("player", "targettarget")

    if not imTarget and enemyHP > 20 then
        local hasCast = MS:CastSpell("Shadow Bolt")
        if hasCast then return end
    end

    -- Burst if enemy is low hp
    if enemyHP < 35 then
        -- Try casting Conflagrate
        local hasImmolate = MS:FindBuff("Immolate", "target")

        if hasImmolate then
            spellIsCast = MS:CastSpell("Conflagrate")
            if spellIsCast then return end
        end

        -- Try casting Shadowburn
        local lvlDiff = UnitLevel("player") - UnitLevel("target")
        local mobIsGreen = lvlDiff <= GetQuestGreenRange()
        local yieldsHonor = enemyIsPlayer or mobIsGreen

        if yieldsHonor then
            spellIsCast = MS:CastSpell("Shadowburn")
            if spellIsCast then return end
        end
    end

    -- As a last resort, when I already have aggro -> Searing Pain
    spellIsCast = MS:CastSpell("Searing Pain")
    if spellIsCast then return end
end

function MS:WL_Exhaust()
    -- Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then TargetNearestEnemy() end

    -- Cast Exhaust
    local spellName = "Curse of Exhaustion"
    local wasFound = MS:FindBuff(spellName, "target")

    if not wasFound then
        local hasCastAmplify = MS:CastSpell("Amplify Curse")
        if hasCastAmplify then return end

        local hasCastDot = MS:CastSpell(spellName)
        if hasCastDot then return end
    end
end

function MS:WL_SoulFire()
    -- Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then TargetNearestEnemy() end

    -- Don't cast on low hp enemies
    local enemyHP = MS:HPPercent("target")
    if enemyHP < 60 then return end

    -- Cast curse
    local wasFound = MS:FindBuff("Curse of the Elements", "target")

    if not wasFound then
        local hasCastCurse = MS:CastSpell("Curse of the Elements")
        if hasCastCurse then return end
    end

    -- Cast main spell
    local hasCastSpell = MS:CastSpell("Soul Fire")
    if hasCastSpell then return end
end

function MS:WL_SummonOrFear()
    local isAlive = UnitExists("target") and not UnitIsDeadOrGhost("target")
    local isNotMe = not UnitIsUnit("player", "target")
    local isPartyMember = UnitInParty("target") or UnitInRaid("target")
    local isNotFriendly = not UnitIsFriend("player", "target")
    local creatureType = UnitCreatureType("target")
    local isValidCreatureType = creatureType == "Demon" or creatureType == "Elemental"

    if isAlive and isNotMe and isPartyMember then
        local targetName = UnitName("target")

        MS:Say("I'm summoning " .. targetName)
        MS:CastSpell("Ritual of Summoning")
    else
        local hp = MS:HPPercent("player")

        if hp < 60 then
            local hasCast = MS:CastSpell("Death Coil")
            if hasCast then return end
        end

        MS:CastSpell("Fear")
    end
end

function MS:WL_PetSpell()
    local hasPet = HasPetUI()

    if not hasPet then
        local hasCastFel = MS:CastSpell("Fel Domination")
        local hasFelDom = MS:FindBuff("Fel Domination", "player")

        if hasCastFel or hasFelDom then
            local hasCastVoid = MS:CastSpell("Summon Voidwalker")

            if hasCastVoid then return end
        end

        -- don't try to full cast pet
        return
    end

    local petType = UnitCreatureFamily("pet")
    local hasVoid = petType == "Voidwalker"
    local hasSucc = petType == "Succubus"
    local hasImp = petType == "Imp"
    local hasFelhunter = petType == "Felhunter"

    if hasVoid then
        local hasBubble = MS:FindBuff("Sacrifice", "player")
        local hasDemSac = MS:FindBuff("Demonic Sacrifice", "player")
        local hp = MS:HPPercent("player")

        if not hasBubble and MS.inCombat then
            MS:PetFollow()

            local hasSacrificed = MS:CastSpell("Sacrifice")
            if hasSacrificed then return end

        elseif not hasDemSac and hp < 50 then

            local hasCastDemSac = MS:CastSpell("Demonic Sacrifice")
            if hasCastDemSac then return end
        end

    elseif hasSucc then
        local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

        if isNotValidTarget then TargetNearestEnemy() end

        -- in order to get in range for Seduction
        MS:PetAttack()

        local hasCastSeduction = MS:CastSpell("Seduction")
        if hasCastSeduction then return end

    elseif hasImp then
        TargetUnit("player")
        local hasCastShield = MS:CastSpell("Fire Shield")
        TargetLastTarget()

        if hasCastShield then return end

    elseif hasFelhunter then
        local isAlive = UnitExists("target") and not UnitIsDeadOrGhost("target")
        local isEnemy = isAlive and UnitIsPlayer("target") and not UnitIsFriend("player", "target")

        -- depends on ShaguTweaks
        local targetIsCasting = ShaguTargetCastbar:IsVisible()

        -- cast Spell Lock
        if isEnemy and targetIsCasting then
            local hasCast = MS:CastSpell("Spell Lock")
            if hasCast then return end
        end

        -- cast Devour Magic on enemy or myself
        local shouldRetarget = not isEnemy

        if shouldRetarget then TargetUnit("player") end

        local hasCastDevour = MS:CastSpell("Devour Magic")

        if shouldRetarget then TargetLastTarget() end

        if hasCastDevour then return end
    end
end

function MS:WL_Shadowbolt()
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then TargetNearestEnemy() end

    MS:PetAttack()
    MS:CastSpell("Shadow Bolt")
end

function MS:WL_Drain()
    -- Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then TargetNearestEnemy() end

    local myHP = MS:HPPercent("player")
    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")
    local lvlDiff = UnitLevel("player") - UnitLevel("target")
    local mobIsGreen = lvlDiff <= GetQuestGreenRange()
    local yieldsHonor = enemyIsPlayer or mobIsGreen
    local enemyHasMana = false
    local shardsAmount = 0
    local onlyOnce = false

    MS:DoForItemInBags("Soul Shard", onlyOnce, function(bag, slot)
        shardsAmount = shardsAmount + 1
    end)

    local needShards = shardsAmount < MS_CONFIG.soulshards

    if enemyIsPlayer then
        local targetClass = UnitClass("target")
        local mpClasses = { "Warrior", "Rogue", "Druid" }
        local isManaClass = not MS:CheckIfTableIncludes(mpClasses, targetClass)
        local enemyMP = MS:MPPercent("target")

        enemyHasMana = isManaClass and enemyMP > 0
    end

    if yieldsHonor and needShards and myHP > 60 and enemyHP < 30 then
        local hasCast MS:CastSpell("Drain Soul")
        if hasCast then return end
    end

    if enemyHasMana and myHP > 80 then
        local hasCast = MS:CastSpell("Drain Mana")
        if hasCast then return end
    end

    local hasCast = MS:CastSpell("Drain Life")
    if hasCast then return end
end
