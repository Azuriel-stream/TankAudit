-- Data.lua
TA_DATA = {
    -- 1. CLASS BUFFS
    CLASSES = {
        WARRIOR = {
            SELF = { ["Battle Shout"] = { "Ability_Warrior_BattleShout" } },
            GROUP = {
                ["Battle Shout"] = { "Ability_Warrior_BattleShout" }
            }
        },
        DRUID = {
            SELF = {
                ["Thorns"] = { "Spell_Nature_Thorns" },
                ["Omen of Clarity"] = { "Spell_Nature_CrystalBall" },
                ["Bear Form"] = { "Ability_Racial_BearForm" }
            },
            GROUP = {
                ["Mark of the Wild"] = { "Spell_Nature_Regeneration", "Spell_Nature_Regeneration" },
                -- NEW: Added Thorns so other tanks can request it from a Druid
                ["Thorns"] = { "Spell_Nature_Thorns" }
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
                -- NEW: Added Devotion Aura only (to avoid conflict with Retribution Aura)
                ["Devotion Aura"] = { "Spell_Holy_DevotionAura" }
            }
        },
        SHAMAN = {
            SELF = { 
                ["Lightning Shield"] = { "Spell_Nature_LightningShield" } 
            },
            GROUP = {}
        },
        PRIEST = {
            GROUP = {
                ["Divine Spirit"] = { "Spell_Holy_DivineSpirit", "Spell_Holy_PrayerofSpirit" },
                ["Power Word: Fortitude"] = { "Spell_Holy_WordFortitude", "Spell_Holy_PrayerOfFortitude" }
            }
        },
        MAGE = {
            GROUP = {
                ["Arcane Intellect"] = { "Spell_Holy_MagicalSentry", "Spell_Holy_ArcaneIntellect" }
            }
        },
        -- NEW: Added Warlock (Empty) so the Roster Scanner counts them for Healthstones
        WARLOCK = {
            GROUP = {} 
        }
    },

    -- 2. CONSUMABLES
    CONSUMABLES = {
        FOOD = { ["Well Fed"] = { "Spell_Misc_Food" } },
        HEALTHSTONE = { ["Healthstone"] = { "INV_Stone_04" } }, 
        FLASKS = {
            ["Flask"] = { "INV_Potion_62", "INV_Potion_97", "INV_Potion_41", "INV_Potion_48" }
        }
    }
}