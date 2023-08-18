function MS:SetupSoulshardRemoval()
    local playerIsNotWarlock = UnitClass("player") ~= "Warlock"

    if playerIsNotWarlock then return end

    -- Set default to max from Felcloth Bag
    if not MS_CONFIG.soulshards then
        MS_CONFIG.soulshards = 28
    end

    -- Limit Soul Shard amount to `/soulshards X` amount
    local function LimitSoulshards()
        local itemName = "Soul Shard"
        local onlyOnce = false
        local shards = 0

        MS:DoForItemInBags(itemName, onlyOnce, function(bag, slot)
            shards = shards + 1

            if shards > MS_CONFIG.soulshards then
                MS:DestroyInBagAtSlot(bag, slot)
                shards = shards - 1
            end
        end)
    end

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

    local wl = CreateFrame("Frame")

    -- Soul Shards are gained only on XP or Honor increase
    wl:RegisterEvent("PLAYER_XP_UPDATE")
    wl:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
    wl:SetScript("OnEvent", LimitSoulshards)
end

function MS:WL_Spellstone()
    -- if Spellstone is equipped, use it
    -- elseif Spellstone is in inventory,
        -- save the name of currently equipped main and off
        -- equip Spellstone
        -- use it
        -- equip previous main/off
    -- else create Spellstone
end

function MS:WL_Soulstone()
    -- create or use Soulstone on target
    -- if no friendly target, target self
    CastSpellByName("Soulstone")
end

function MS:WL_Healthstone()
    -- if hp < 60% then
        -- if Healthstone not on cd then
            -- use Healthstone
        -- else
            -- find Healing Potion
            -- use Healing Potion
    -- else
        -- create Healthstone

    CastSpellByName("Healthstone")
end

function MS:WL_GainManaOrBuff()
    -- if mana < 90% then
        -- if hp > 90% then
            -- use Life Tap
        -- elseif pet has mana
            -- use Dark Pact
        -- else
            -- find Mana Potion
            -- use Mana Potion
    -- else
        -- cast Demon Armor
end

function MS:WL_Drain()
    -- if myHP > 60% and enemyHP < 25%
        -- cast Drain Soul
    -- elseif myHP > 90% and enemy has mana
        -- cast Drain Mana
    -- elseif myHP < 80% then
        -- cast Dran Life
end

function MS:WL_SoulFire()
    -- if target doesn't have Curse Of Elements
        -- cast Curse Of Elements
    -- else
        -- cast Soul Fire
end

function MS:WL_SummonOrBanish()
    -- if is friend then
        -- say who I summon
        -- cast Summon
    -- else
        -- cast Banish
end

function MS:WL_Exhaust()
    -- if not on cd Amplify then
        -- cast Amplify
    -- else
        -- cast Curse of Exhaustion
end
