MS = CreateFrame("Frame", nil, UIParent)

-- For tooltip info
MS.t = CreateFrame("GameTooltip", "MS_T", UIParent, "GameTooltipTemplate")

MS:RegisterEvent("ADDON_LOADED")
MS:RegisterEvent("PET_ATTACK_START")
MS:RegisterEvent("PET_ATTACK_STOP")
MS:RegisterEvent("SPELLCAST_FAILED")
MS:RegisterEvent("SPELLCAST_INTERRUPTED")
MS:RegisterEvent("PLAYER_ENTER_COMBAT")
MS:RegisterEvent("PLAYER_LEAVE_COMBAT")
MS:RegisterEvent("PLAYER_TARGET_CHANGED")

MS:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if not MS_CONFIG then MS_CONFIG = {} end
        if not MS_GLOBAL_CONFIG then MS_GLOBAL_CONFIG = {} end
    elseif event == "PET_ATTACK_START" then
        MS.petIsAttacking = true
    elseif event == "PET_ATTACK_STOP" then
        MS.petIsAttacking = false
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        MS.castHasFailed = true
    elseif event == "PLAYER_ENTER_COMBAT" then
        MS.isMeleeAttacking = true
    elseif event == "PLAYER_LEAVE_COMBAT" then
        MS.isMeleeAttacking = false
    elseif event == "PLAYER_TARGET_CHANGED" then
        MS.prevSpellCast = ""
    end
end)

-- Don't toggle off Attack, Shoot and Auto Shoot "spells"
local orig_UseAction = UseAction

UseAction = function(slot, clicked, onself)
    -- Don't disable Shoot and Auto-shoot
    local isAutoRepeat = IsAutoRepeatAction(slot)
    if isAutoRepeat then return end

    -- Don't disable Attack
    local isAttackAction = IsAttackAction(slot)
    if isAttackAction and MS.isMeleeAttacking then return end

    return orig_UseAction(slot, clicked, onself)
end
