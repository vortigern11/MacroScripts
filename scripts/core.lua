MS = CreateFrame("Frame", nil, UIParent)

-- For tooltip info
MS.t = CreateFrame("GameTooltip", "MS_T", UIParent, "GameTooltipTemplate")

MS:RegisterEvent("ADDON_LOADED")
MS:RegisterEvent("PLAYER_REGEN_ENABLED")
MS:RegisterEvent("PLAYER_REGEN_DISABLED")
MS:RegisterEvent("PET_ATTACK_START")
MS:RegisterEvent("PET_ATTACK_STOP")
MS:RegisterEvent("SPELLCAST_FAILED")
MS:RegisterEvent("SPELLCAST_INTERRUPTED")

MS:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if not MS_CONFIG then MS_CONFIG = {} end
        if not MS_GLOBAL_CONFIG then MS_GLOBAL_CONFIG = {} end
    elseif event == "PLAYER_REGEN_ENABLED" then
        MS.inCombat = false
    elseif event == "PLAYER_REGEN_DISABLED" then
        MS.inCombat = false
    elseif event == "PET_ATTACK_START" then
        MS.petIsAttacking = true
    elseif event == "PET_ATTACK_STOP" then
        MS.petIsAttacking = false
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        MS.castHasFailed = true
    end
end)

-- Don't toggle off Attack, Shoot and Auto Shoot "spells"
local orig_UseAction = UseAction

UseAction = function(slot, clicked, onself)
    local isAutoRepeat = IsAutoRepeatAction(slot)

    if isAutoRepeat then return end

    return orig_UseAction(slot, clicked, onself)
end
