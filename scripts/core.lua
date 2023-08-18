MS = CreateFrame("Frame")

MS:RegisterEvent("ADDON_LOADED")
MS:RegisterEvent("PLAYER_REGEN_ENABLED")
MS:RegisterEvent("PLAYER_REGEN_DISABLED")
MS:RegisterEvent("PLAYER_ENTER_COMBAT")
MS:RegisterEvent("PLAYER_LEAVE_COMBAT")
MS:RegisterEvent("START_AUTOREPEAT_SPELL")
MS:RegisterEvent("STOP_AUTOREPEAT_SPELL")

MS:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if not MS_CONFIG then MS_CONFIG = {} end
        if not MS_GLOBAL_CONFIG then MS_GLOBAL_CONFIG = {} end

        MS:SetupSoulshardRemoval()
    elseif event == "PLAYER_REGEN_ENABLED" then
        MS.isRegenEnabled = true
    elseif event == "PLAYER_REGEN_DISABLED" then
        MS.isRegenEnabled = false
    elseif event == "PLAYER_ENTER_COMBAT" then
        MS.isAttacking = true
    elseif event == "PLAYER_LEAVE_COMBAT" then
        MS.isAttacking = false
    elseif event == "START_AUTOREPEAT_SPELL" then
        MS.isShooting = true
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        MS.isShooting = false
    end
end)

-- Don't toggle Attack and Shoot "spells"
do
    local orig_CastSpell = CastSpell
    local orig_CastSpellByName = CastSpellByName

    local function GetIsActive(name)
        name = strlower(name)
        local isAttackCast = name == "attack"
        local isShootCast = name == "auto shot" or name == "shoot"

        return (isAttackCast and MS.isAttacking) or (isShootCast and MS.isShooting)
    end

    function CastSpell(index, booktype)
        if GetIsActive(GetSpellName(index, booktype)) then return end
        return orig_CastSpell(index, booktype)
    end

    function CastSpellByName(text, onself)
        if GetIsActive(text) then return end
        return orig_CastSpellByName(text, onself)
    end
end
