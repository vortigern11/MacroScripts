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
    -- 0) Find highest level of the spell learned
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

    -- 1) If stone in bag, use it
    local onlyOnce = true
    local wasStoneInBag = MS:DoForItemInBags(stoneItemName, onlyOnce, function(bag, slot)
        local mustRetarget = not UnitInParty("target") and not UnitInRaid("target")

        if mustRetarget then TargetUnit("player") end

        local wasUsed = MS:UseBagItem(stoneItemName)

        if mustRetarget then TargetLastTarget() end
    end)

    if wasStoneInBag then return end

    -- 2) Create stone
    MS:CastSpell(stoneSpellName)
end

function MS:WL_Healthstone()
    -- 0) Find highest level of the spell learned
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

    -- 1) Use any health consumable
    local wasItemUsed = MS:UseHealthConsumable()

    if wasItemUsed then return end

    -- 2) If spell not on cd, create stone
    local notInCombat = not MS.inCombat

    if notInCombat then
        local isStoneInBag = MS:IsItemInBag(stoneItemName)

        if not isStoneInBag then
            MS:CastSpell(stoneSpellName)
            return
        end
    end
end

function MS:WL_Spellstone()
    -- 0) Find highest level of the spell learned
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

    -- 1) If spellstone is equipped, use it
    local offhandItemLink = MS:GetEquipmentItemLink("off")
    local offhandItem = MS:ItemLinkToName(offhandItemLink)
    local stoneIsEquipped = offhandItem == stoneName
    local notInCombat = not MS.inCombat

    if (stoneIsEquipped and notInCombat) then
        MS:UseEquipment("off")
        return
    end


    -- 2) If spell not on cd, create stone
    local isStoneInBag = MS:IsItemInBag(stoneItemName)

    if not isStoneInBag then
        MS:CastSpell(stoneSpellName)
        return
    end
end

function MS:WL_Replenish()
    local mp = MS:MPPercent("player")

    -- 0) cast Soul Link if possible
    local hasPet = HasPetUI()
    local hasSoulLink = MS:FindBuff("Soul Link", "player")

    if hasPet and not hasSoulLink and mp > 20 then
        local hasCastSoulLink = MS:CastSpell("Soul Link")

        if hasCastSoulLink then return end
    end

    -- 1) otherwise cast self-buff
    if mp > 20 then
        local buffs = { "Demon Armor", "Demon Skin" }
        local wasFound = false

        MS:TraverseTable(buffs, function(_, buffName)
            wasFound = MS:FindBuff(buffName, "player")
            if wasFound then return "break loop" end
        end)

        if not wasFound then
            local hasCast = MS:CastSpell(buffs[0])

            if not hasCast then
                MS:CastSpell(buffs[1])
                return
            end
        end
    end

    -- 2) if low on mana - regen
    if mp < 95 then
        -- 0) Maybe use Life Tap?
        local hp = MS:HPPercent("player")
        if hp > 70 then
            MS:CastSpell("Life Tap")
            return
        end

        -- 1) Maybe use Dark Pact?
        local hasPet = HasPetUI()
        if hasPet then
            local petMP = MS:MPPercent("pet")

            if petMP > 1 then
                MS:CastSpell("Dark Pact")
                return
            end
        end

        -- 2) Use other mana consumable
        local wasItemUsed = MS:UseManaConsumable()
        if wasItemUsed then return end

        return
    end

    --3) create Healthstone
    MS:WL_Healthstone()
end

function MS:WL_AffliDots()
    -- 0) Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then
        TargetNearestEnemy()
    end

    -- 1) Attack with pet
    MS:PetAttack()

    -- 2) Cast Shadowbolt if I have Shadow Trance
    local haveShadowTrance = MS:FindBuff("Shadow Trance", "player")
    local mp = MS:MPPercent("player")

    if haveShadowTrance and mp > 30 then
        local hasCast = MS:CastSpell("Shadow Bolt")
        if hasCast then return end
    end

    -- 3) Apply dot in solo
    local spellIsCast = false
    local spells = { "Siphon Life", "Corruption", "Curse of Agony" }
    local otherCurses = {
        "Curse of Recklessness",
        "Curse of Exhaustion",
        "Curse of Shadow",
        "Curse of the Elements",
        "Curse of Tongues",
        "Curse of Weakness"
    }

    MS:TraverseTable(spells, function(_, spellName)
        -- dot on target, cast by me
        local wasFound = MS:FindBuff(spellName, "target")

        if not wasFound then
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
        end
    end)

    -- 4) In case there are other warlocks in the group
    -- since in vanilla you can't get info about who cast the DOT.....
    local inParty = UnitExists("party1")

    if not spellIsCast and inParty then
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

            local hasCast = MS:CastSpell(spells[idx])

            if hasCast then
                idx = idx + 1
                if idx > 3 then idx = 1 end
                MS.warlockDotIdx = idx
                return
            end
        end
    end
end

function MS:WL_DemoDots()
    -- 0) Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then
        TargetNearestEnemy()
    end

    -- 1) Attack with pet
    MS:PetAttack()

    -- 2) Apply dot in solo
    local spellIsCast = false
    local spells = { "Immolate", "Corruption", "Curse of Agony" }
    local otherCurses = {
        "Curse of Recklessness",
        "Curse of Exhaustion",
        "Curse of Shadow",
        "Curse of the Elements",
        "Curse of Tongues",
        "Curse of Weakness"
    }

    MS:TraverseTable(spells, function(_, spellName)
        -- dot on target, cast by me
        local wasFound = MS:FindBuff(spellName, "target")

        if not wasFound then
            local spellIsAgony = spellName == "Curse of Agony"

            if spellIsAgony then
                -- Don't cast Agony if target has another curse
                local hasOtherCurse = false

                MS:TraverseTable(otherCurses, function(_, curseName)
                    hasOtherCurse = MS:FindBuff(curseName, "target")
                    if hasOtherCurse then return "break loop" end
                end)

                if hasOtherCurse then return end
            end

            local hasCast = MS:CastSpell(spellName)

            if hasCast then
                spellIsCast = true
                return "break loop"
            end
        end
    end)

    -- 3) In case there are other warlocks in the group
    -- since in vanilla you can't get info about who cast the DOT.....
    local inParty = UnitExists("party1")

    if not spellIsCast and inParty then
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
                end
            end

            local hasCast = MS:CastSpell(spells[idx])

            if hasCast then
                idx = idx + 1
                if idx > 3 then idx = 1 end
                MS.warlockDotIdx = idx
                return
            end
        end
    end
end

function MS:WL_Exhaust()
    -- 0) Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then
        TargetNearestEnemy()
    end

    -- 1) Cast Exhaust
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
    -- 0) Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then
        TargetNearestEnemy()
    end

    -- 1) Cast curse
    local wasFound = MS:FindBuff("Curse of the Elements", "target")

    if not wasFound then
        local hasCastCurse = MS:CastSpell("Curse of the Elements")
        if hasCastCurse then return end
    end

    -- 2) Cast main spell
    local hasCastSpell = MS:CastSpell("Soul Fire")
    if hasCastSpell then return end
end

function MS:WL_SummonOrBanish()
    local isAlive = UnitExists("target") and not UnitIsDeadOrGhost("target")
    local isNotMe = not UnitIsUnit("player", "target")
    local isPartyMember = UnitInParty("target") or UnitInRaid("target")
    local creatureType = UnitCreatureType("target")
    local isValidCreatureType = creatureType == "Demon" or creatureType == "Elemental"

    if isAlive and isNotMe and isPartyMember then
        local targetName = UnitName("target")

        MS:Say("I'm summoning " .. targetName)
        MS:CastSpell("Ritual of Summoning")
    elseif isValidCreatureType then
        MS:CastSpell("Banish")
    else
        MS:CastSpell("Fear")
    end
end

function MS:WL_DevourMagic()
    local isAlive = UnitExists("target") and not UnitIsDeadOrGhost("target")
    local isFriend = isAlive and UnitIsPlayer("target") and UnitIsFriend("player", "target")

    if not isFriend then TargetUnit("player") end

    local hasCast = MS:CastSpell("Devour Magic")

    if not isFriend then TargetLastTarget() end
end

function MS:WL_Sacrifice()
    local hasPet = HasPetUI()
    local hasVoid = hasPet and UnitCreatureFamily("pet") == "Voidwalker"
    local hasBubble = MS:FindBuff("Sacrifice", "player")
    local hasDemSac = MS:FindBuff("Demonic Sacrifice", "player")
    local hasSoulLink = MS:FindBuff("Soul Link", "player")
    local hasFelDom = MS:FindBuff("Fel Domination", "player")
    local hp = MS:HPPercent("player")

    if hasVoid then
        if not hasBubble then
            local hasSacrificed = MS:CastSpell("Sacrifice")
            if hasSacrificed then return end
        end

        if not hasDemSac and hp < 40 then
            local hasCastDemSac = MS:CastSpell("Demonic Sacrifice")
            if hasCastDemSac then return end
        end

        if not hasSoulLink then
            local hasCastSoulLink = MS:CastSpell("Soul Link")
            if hasCastSoulLink then return end
        end
    else
        local hasCastFel = MS:CastSpell("Fel Domination")

        if hasCastFel or hasFelDom then
            local hasCastVoid = MS:CastSpell("Summon Voidwalker")

            if hasCastVoid then return end
        end
    end

    MS:WL_Healthstone()
end

function MS:WL_Shadowbolt()
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then
        TargetNearestEnemy()
    end

    MS:PetAttack()
    MS:CastSpell("Shadow Bolt")
end

function MS:WL_Drain()
    -- 0) Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or UnitIsFriend("player", "target")

    if isNotValidTarget then
        TargetNearestEnemy()
    end

    local myHP = MS:HPPercent("player")
    local enemyHP = MS:HPPercent("target")
    local enemyIsPlayer = UnitIsPlayer("target")
    local enemyHasMana = false
    local shardsAmount = 0
    local onlyOnce = false

    MS:DoForItemInBags("Soul Shard", onlyOnce, function(bag, slot)
        shardsAmount = shardsAmount + 1
    end)

    local needShards = shardsAmount < MS_CONFIG.soulshards

    if enemyIsPlayer then
        local targetClass = isPlayer and UnitClass("target")
        local enemyMP = MS:MPPercent("target")

        enemyHasMana = targetClass ~= "Warrior" and targetClass ~= "Rogue" and enemyMP > 0
    end

    if needShards and myHP > 60 and enemyHP < 30 then
        local hasCast MS:CastSpell("Drain Soul")
        if hasCast then return end
    end

    if enemyHasMana and myHP > 70 then
        local hasCast = MS:CastSpell("Drain Mana")
        if hasCast then return end
    end

    local hasCast = MS:CastSpell("Drain Life")
    if hasCast then return end
end

function MS:WL_Fear()
    local petShouldStopAttacking = MS.petIsAttacking and UnitIsUnit("target", "pettarget")

    if petShouldStopAttacking then
        MS:PetFollow()
    end

    MS:CastSpell("Fear")
end
