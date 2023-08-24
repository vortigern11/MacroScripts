MS = CreateFrame("Frame", nil, UIParent)

-- For tooltip info
MS.t = CreateFrame("GameTooltip", "MS_T", UIParent, "GameTooltipTemplate")

MS:RegisterEvent("ADDON_LOADED")
MS:RegisterEvent("PLAYER_REGEN_ENABLED")
MS:RegisterEvent("PLAYER_REGEN_DISABLED")
MS:RegisterEvent("PLAYER_TARGET_CHANGED")

MS:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if not MS_CONFIG then MS_CONFIG = {} end
        if not MS_GLOBAL_CONFIG then MS_GLOBAL_CONFIG = {} end
    elseif event == "PLAYER_REGEN_ENABLED" then
        MS.isRegenEnabled = true
    elseif event == "PLAYER_REGEN_DISABLED" then
        MS.isRegenEnabled = false
    elseif event == "PLAYER_TARGET_CHANGED" then
        MS.warlockDotIdx = 1
    end
end)

-- Don't toggle Attack, Shoot and Auto Shoot "spells"
local orig_UseAction = UseAction

UseAction = function(slot, clicked, onself)
    local isAutoRepeat = IsAutoRepeatAction(slot)

    if isAutoRepeat then return end

    return orig_UseAction(slot, clicked, onself)
end
