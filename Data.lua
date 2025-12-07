-- Data.lua
TA_DATA = {
    -- 1. CLASS BUFFS
    -- Format: ["Readable Name"] = { "Icon_1", "Icon_2" }
    -- If ANY icon in the list is found, the buff is considered active.
    
    CLASSES = {
        WARRIOR = {
            SELF = {
                ["Battle Shout"] = { "Ability_Warrior_BattleShout" }
            },
            GROUP = {}
        },
        DRUID = {
            SELF = {
                ["Thorns"] = { "Spell_Nature_Thorns" },
                ["Omen of Clarity"] = { "Spell_Nature_CrystalBall" },
                ["Bear Form"] = { "Ability_Racial_BearForm" }
            },
            GROUP = {
                ["Mark of the Wild"] = { "Spell_Nature_Regeneration", "Spell_Nature_Regeneration" } -- GOTW and MOTW share icon
            }
        },
        PALADIN = {
            SELF = {
                ["Righteous Fury"] = { "Spell_Holy_SealOfFury" },
                ["Holy Shield"] = { "Spell_Holy_BlessingOfProtection" } 
            },
            GROUP = {
                -- We will treat Blessings as a special category in the main loop later, 
                -- but for now, generic mapping:
                ["Blessing of Kings"] = { "Spell_Magic_MageArmor", "Spell_Magic_GreaterBlessingofKings" },
                ["Blessing of Might"] = { "Spell_Holy_FistOfJustice", "Spell_Holy_GreaterBlessingofKings" }, -- Check icons later
                ["Blessing of Sanctuary"] = { "Spell_Nature_LightningShield", "Spell_Holy_GreaterBlessingofSanctuary" }
            }
        },
        SHAMAN = {
            SELF = {
                ["Lightning Shield"] = { "Spell_Nature_LightningShield" }
            },
            GROUP = {
                -- Totems are usually auras, tricky to track via UnitBuff, leaving empty for now
            }
        },
        PRIEST = {
            GROUP = {
                -- Combining Single and Group buffs into one check
                ["Power Word: Fortitude"] = { "Spell_Holy_WordFortitude", "Spell_Holy_PrayerOfFortitude" },
                ["Divine Spirit"] = { "Spell_Holy_DivineSpirit", "Spell_Holy_PrayerOfSpirit" }
            }
        },
        MAGE = {
            GROUP = {
                ["Arcane Intellect"] = { "Spell_Holy_MagicalSentry", "Spell_Holy_ArcaneIntellect" }
            }
        },
        WARLOCK = {
            GROUP = {
                ["Blood Pact"] = { "Spell_Shadow_BloodBoil" } 
            }
        }
    },

    -- 2. CONSUMABLES
    CONSUMABLES = {
        FOOD = {
            ["Well Fed"] = { "Spell_Misc_Food" }
        },
        FLASKS = {
            ["Flask"] = { 
                "INV_Potion_62", -- Titans
                "INV_Potion_97", -- Wisdom
                "INV_Potion_41", -- Supreme Power
                "INV_Potion_48"  -- Chromatic
            }
        }
    }
}