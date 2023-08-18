-- As a reference:
-- SLASH_MACROSCRIPTS1 = "/macroscripts";
-- SlashCmdList["MACROSCRIPTS"] = function(msg)
--     local args, word = {}, "";
--     for word in string.gfind(msg, "[^%s]+") do
--         table.insert(args, word)
--     end
--     local cmd = args[1]

--     if cmd == "bla" then
--     end
-- end

MS.isRegenEnabled = true
MS.isAttacking = false
MS.isShooting = false

-- Equipment dictionary
MS.equipments =
{
    head = 1,
    neck = 2,
    shoulder = 3,
    shirt = 4,
    chest = 5,
    waist = 6,
    legs = 7,
    feet = 8,
    wrist = 9,
    hands = 10,
    ring1 = 11,
    ring2 = 12,
    trinket1 = 13,
    trinket2 = 14,
    back = 15,
    main = 16,
    off = 17,
    relic = 18,
    tabard = 19
}

-- Battlegrounds
MS.bgs = { "warsong gulch", "arathi basin", "alterac valley"}

-- Bandages
MS.bandages =
{
    [MS.bgs[1]] =
    {
        "Warsong Gulch Runecloth Bandage",
        "Warsong Gulch Mageweave Bandage",
        "Warsong Gulch Silk Bandage",
    },

    [MS.bgs[2]] =
    {
        "Highlander's Runecloth Bandage",
        "Defiler's Runecloth Bandage",
        "Arathi Basin Runecloth Bandage",
        "Highlander's Mageweave Bandage",
        "Defiler's Mageweave Bandage",
        "Arathi Basin Mageweave Bandage",
        "Highlander's Silk Bandage",
        "Defiler's Silk Bandage",
        "Arathi Basin Silk Bandage",
    },

    [MS.bgs[3]] =
    {
        "Alterac Heavy Runecloth Bandage",
    },

    normal =
    {
        "Heavy Runecloth Bandage",
        "Runecloth Bandage",
        "Heavy Mageweave Bandage",
        "Mageweave Bandage",
        "Heavy Silk Bandage",
        "Silk Bandage",
        "Heavy Wool Bandage",
        "Wool Bandage",
        "Heavy Linen Bandage",
        "Linen Bandage",
    },
}

-- Add the normal bandages in each battleground list
MS:ForTableElem(MS.bandages.normal, function(_, val)
    table.insert(MS.bandages[MS.bgs[1]], val)
    table.insert(MS.bandages[MS.bgs[2]], val)
    table.insert(MS.bandages[MS.bgs[3]], val)
end)
