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
wl:SetScript("OnEvent", function()
    local playerIsNotWarlock = UnitClass("player") ~= "Warlock"

    if playerIsNotWarlock then return end

    if event == "ADDON_LOADED" then
        SetupSoulshardRemoval()
    elseif event == "PLAYER_XP_UPDATE" then
        LimitSoulshards()
    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        LimitSoulshards()
    end
end)

function MS:WL_Soulstone()
    -- 0) Find highest level of the spell learned
    local spellToItemDict =
    {
        { "Create Soulstone (Major)", "Major Soulstone" },
        { "Create Soulstone (Greater)", "Greater Soulstone" },
        { "Create Soulstone", "Soulstone" },
        { "Create Soulstone (Lesser)", "Lesser Soulstone" },
        { "Create Soulstone (Minor)", "Minor Soulstone" },
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
    local spellToItemDict =
    {
        { "Create Healthstone (Major)", "Major Healthstone" },
        { "Create Healthstone (Greater)", "Greater Healthstone" },
        { "Create Healthstone", "Healthstone" },
        { "Create Healthstone (Lesser)", "Lesser Healthstone" },
        { "Create Healthstone (Minor)", "Minor Healthstone" },
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
    local isStoneInBag = MS:IsItemInBag(stoneItemName)

    if not isStoneInBag then
        MS:CastSpell(stoneSpellName)
        return
    end
end

function MS:WL_Spellstone()
    -- 0) Find highest level of the spell learned
    local spellToItemDict =
    {
        { "Create Spellstone (Major)", "Major Spellstone" },
        { "Create Spellstone (Greater)", "Greater Spellstone" },
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
    local notInCombat = MS.isRegenEnabled

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

    -- 1) if low on mana - regen
    if mp < 98 then
        -- 0) Maybe use Life Tap?
        local hp = MS:HPPercent("player")
        if hp > 80 then
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

    -- 2) otherwise cast self-buff
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

    --3) create Healthstone
    MS:WL_Healthstone()
end

function MS:WL_ApplyDOT()
    -- 0) Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or not UnitIsEnemy("player", "target")

    if isNotValidTarget then
        TargetNearestEnemy()
    end

    -- 1) Attack with pet
    local hasPet = HasPetUI()

    if hasPet then
        local isNotImp = UnitCreatureFamily("pet") ~= "Imp"
        local petHasNoTarget = not UnitExists("pettarget") or UnitIsDeadOrGhost("pettarget")

        if isNotImp and petHasNoTarget then
            PetAttack()
        end
    end

    -- 2) Cast Shadowbolt if I have Shadow Trance
    local haveShadowTrance = MS:FindBuff("Shadow Trance", "player")
    local mp = MS:MPPercent("player")

    if haveShadowTrance and mp > 50 then
        local hasCast = MS:CastSpell("Shadow Bolt")
        if hasCast then return end
    end

    -- 3) Apply dot
    local spells = { "Siphon Life", "Corruption", "Curse of Agony" }

    MS:TraverseTable(spells, function(_, spellName)
        -- dot on target, cast by me and long time remaining
        local wasFound = MS:FindBuff(spellName, "target")

        if not wasFound then
            -- cast Amplify Curse if about to cast Curse of Agony
            local _, isGCD = MS:FindSpell("Curse of Agony")
            local spellIsAgony = spellName == "Curse of Agony"

            if not isGCD and spellIsAgony then
                local hasCastAmplify = MS:CastSpell("Amplify Curse")
                if hasCastAmplify then return "break loop" end
            end

            local hasCast = MS:CastSpell(spellName)
            if hasCast then return "break loop" end
        end
    end)
end

function MS:WL_Exhaust()
    -- 0) Check if valid target
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or not UnitIsEnemy("player", "target")

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
    local isNotValidTarget = not UnitExists("target") or UnitIsDeadOrGhost("target") or not UnitIsEnemy("player", "target")

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
    local isNotPlayer = not UnitIsUnit("player", "target")
    local isPartyMember = UnitInParty("target") or UnitInRaid("target")
    local creatureType = UnitCreatureType("target")
    local isValidCreatureType = creatureType == "Demon" or creatureType == "Elemental"

    if isAlive and isNotPlayer and isPartyMember then
        local targetName = UnitName("target")

        MS:Say("I'm summoning " .. targetName)
        MS:CastSpell("Ritual of Summoning")
    elseif validCreatureType then
        MS:CastSpell("Banish")
    end
end

function MS:WS_Immolate()
    -- if not wearing Firestone:
        -- check if two-handed -> return if true
        -- try to equip firestone (if in the bag)
    -- else
        -- cast Immolate
end

function MS:WL_Drain()
    -- differentiate if enemy is PVP target and mana class

    -- if myHP > 60% and enemyHP < 25%
    -- cast Drain Soul
    -- elseif myHP > 90% and enemy has mana
    -- cast Drain Mana
    -- elseif myHP < 80% then
    -- cast Dran Life
end
