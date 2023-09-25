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

MS.isMeleeAttacking = false
MS.petIsAttacking = false
MS.castHasFailed = false
MS.prevSpellCast = ""

-- Equipment dictionary
MS.equipments = {
    ammo = { id = 0, prev = "" },
    head = { id = 1, prev = "" },
    neck = { id = 2, prev = "" },
    shoulders = { id = 3, prev = "" },
    shirt = { id = 4, prev = "" },
    chest = { id = 5, prev = "" },
    waist = { id = 6, prev = "" },
    legs = { id = 7, prev = "" },
    feet = { id = 8, prev = "" },
    wrist = { id = 9, prev = "" },
    hands = { id = 10, prev = "" },
    ring1 = { id = 11, prev = "" },
    ring2 = { id = 12, prev = "" },
    trinket1 = { id = 13, prev = "" },
    trinket2 = { id = 14, prev = "" },
    back = { id = 15, prev = "" },
    main = { id = 16, prev = "" },
    off = { id = 17, prev = "" },
    ranged = { id = 18, prev = "" },
    tabard = { id = 19, prev = "" },
}

MS.twoHandedTypes = {
    "Two-Handed Axes",
    "Two-Handed Maces",
    "Two-Handed Swords",
    "Polearms",
    "Staves",
    "Fishing Poles"
}

-- Battlegrounds
MS.bgs = { "warsong gulch", "arathi basin", "alterac valley"}

-- Bandages
MS.bandages = {
    [MS.bgs[1]] = {
        "Warsong Gulch Runecloth Bandage",
        "Warsong Gulch Mageweave Bandage",
        "Warsong Gulch Silk Bandage",
    },

    [MS.bgs[2]] = {
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

    [MS.bgs[3]] = {
        "Alterac Heavy Runecloth Bandage",
    },

    normal = {
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
MS:TraverseTable(MS.bandages.normal, function(_, val)
    table.insert(MS.bandages[MS.bgs[1]], val)
    table.insert(MS.bandages[MS.bgs[2]], val)
    table.insert(MS.bandages[MS.bgs[3]], val)
end)

MS.hpConsumables = {
    bg = {
        "Major Healing Draught",
        "Superior Healing Draught",
    },

    normal = {
        "Major Healthstone",
        "Greater Healthstone",
        "Healthstone",
        "Lesser Healthstone",
        "Minor Healthstone",

        "Major Healing Potion",
        "Superior Healing Potion",
        "Combat Healing Potion",
        "Greater Healing Potion",
        "Healing Potion",
        "Lesser Healing Potion",
        "Discolored Healing Potion",
        "Minor Healing Potion",
    }
}

MS:TraverseTable(MS.hpConsumables.normal, function(_, val)
    table.insert(MS.hpConsumables.bg, val)
end)

MS.mpConsumables = {
    bg = {
        "Major Mana Draught",
        "Superior Mana Draught",
    },

    normal = {
        "Mana Ruby",
        "Mana Citrine",
        "Mana Jade",
        "Mana Agate",

        "Major Mana Potion",
        "Superior Mana Potion",
        "Combat Mana Potion",
        "Greater Mana Potion",
        "Mana Potion",
        "Lesser Mana Potion",
        "Minor Mana Potion",
    }
}

MS:TraverseTable(MS.mpConsumables.normal, function(_, val)
    table.insert(MS.mpConsumables.bg, val)
end)

MS.bgFoods = {
    [MS.bgs[1]] = {
        "Warsong Gulch Enriched Ration",
        "Warsong Gulch Iron Ration",
        "Warsong Gulch Field Ration"
    },

    [MS.bgs[2]] = {
        "Highlander's Enriched Ration",
        "Defiler's Enriched Ration",
        "Arathi Basin Enriched Ration",
        "Highlander's Iron Ration",
        "Defiler's Iron Ration",
        "Arathi Basin Iron Ration",
        "Highlander's Field Ration",
        "Defiler's Field Ration",
        "Arathi Basin Field Ration"
    },

    [MS.bgs[3]] = {
        "Alterac Manna Biscuit"
    }
}

MS.fishing = {
    poles = {
        "Arcanite Fishing Pole",
        "Nat Pagle's Extreme Angler FC-5000",
        "Dwarven Fishing Pole",
        "Goblin Fishing Pole",
        "Big Iron Fishing Pole",
        "Darkwood Fishing Pole",
        "Strong Fishing Pole",
        "Blump Family Fishing Pole",
        "Fishing Pole",
    },
    lures = {
        "Aquadynamic Fish Attractor",
        "Flesh Eating Worm",
        "Bright Baubles",
        "Aquadynamic Fish Lens",
        "Nightcrawlers",
        "Shiny Bauble",
    }
}
