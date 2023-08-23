MS = CreateFrame("Frame", nil, UIParent)

-- for MS:GetBuffInfo and maybe others
MS.t = CreateFrame("GameTooltip", "MS_T", UIParent, "GameTooltipTemplate")

MS:RegisterEvent("ADDON_LOADED")
MS:RegisterEvent("PLAYER_REGEN_ENABLED")
MS:RegisterEvent("PLAYER_REGEN_DISABLED")

MS:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if not MS_CONFIG then MS_CONFIG = {} end
        if not MS_GLOBAL_CONFIG then MS_GLOBAL_CONFIG = {} end
    elseif event == "PLAYER_REGEN_ENABLED" then
        MS.isRegenEnabled = true
    elseif event == "PLAYER_REGEN_DISABLED" then
        MS.isRegenEnabled = false
    end
end)
