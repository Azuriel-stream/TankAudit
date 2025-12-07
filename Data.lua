-- Data.lua
TA_DATA = {
    -- 1. CLASS BUFFS
    CLASSES = {
        WARRIOR = {
            SELF = { ["Battle Shout"] = { "Ability_Warrior_BattleShout" } },
            GROUP = {}
        },
        DRUID = {
            SELF = {
                ["Thorns"] = { "Spell_Nature_Thorns" },
                ["Omen of Clarity"] = { "Spell_Nature_CrystalBall" },
                ["Bear Form"] = { "Ability_Racial_BearForm" }
            },
            GROUP = {
                ["Mark of the Wild"] = { "Spell_Nature_Regeneration", "Spell_Nature_Regeneration" }
            }
        },
        PALADIN = {
            SELF = {
                ["Righteous Fury"] = { "Spell_Holy_SealOfFury" },
                ["Holy Shield"] = { "Spell_Holy_BlessingOfProtection" } 
            },
            GROUP = {
                ["Blessing of Kings"] = { "Spell_Magic_MageArmor", "Spell_Magic_GreaterBlessingofKings" },
                ["Blessing of Might"] = { "Spell_Holy_FistOfJustice", "Spell_Holy_GreaterBlessingofKings" },
                ["Blessing of Light"] = { "Spell_Holy_PrayerOfHealing02" },
                ["Blessing of Sanctuary"] = { "Spell_Nature_LightningShield", "Spell_Holy_GreaterBlessingofSanctuary" },
                ["Blessing of Salvation"] = { "Spell_Holy_SealOfSalvation" } -- Included for completeness
            }
        },
        SHAMAN = {
            SELF = { ["Lightning Shield"] = { "Spell_Nature_LightningShield" } },
            GROUP = {}
        },
        PRIEST = {
            GROUP = {
                -- FIXED: Lowercase "of" in PrayerofSpirit based on your debug
                ["Divine Spirit"] = { "Spell_Holy_DivineSpirit", "Spell_Holy_PrayerofSpirit" },
                ["Power Word: Fortitude"] = { "Spell_Holy_WordFortitude", "Spell_Holy_PrayerOfFortitude" }
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
        FOOD = { ["Well Fed"] = { "Spell_Misc_Food" } },
        -- Added Healthstone Icon for the button
        HEALTHSTONE = { ["Healthstone"] = { "INV_Stone_04" } }, -- Generic healthstone icon
        FLASKS = {
            ["Flask"] = { "INV_Potion_62", "INV_Potion_97", "INV_Potion_41", "INV_Potion_48" }
        }
    }
}