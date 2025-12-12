-- Data.lua
TA_DATA = {
    -- 1. CLASS BUFFS
    CLASSES = {
        WARRIOR = {
            SELF = { 
                ["Battle Shout"] = { "Ability_Warrior_BattleShout" },
                -- NEW: Defensive Stance (Checked via Stance Bar)
                ["Defensive Stance"] = { "Ability_Warrior_DefensiveStance" }
            },
            GROUP = {
                ["Battle Shout"] = { "Ability_Warrior_BattleShout" }
            }
        },
        DRUID = {
            SELF = {
                ["Thorns"] = { "Spell_Nature_Thorns" },
                -- REMOVED: Omen of Clarity (Talent dependent)
                ["Bear Form"] = { "Ability_Racial_BearForm" }
            },
            GROUP = {
                ["Mark of the Wild"] = { "Spell_Nature_Regeneration", "Spell_Nature_Regeneration" },
                -- Added Thorns to Group so Warriors can ask Druids for it
                ["Thorns"] = { "Spell_Nature_Thorns" }
            }
        },
        PALADIN = {
            SELF = {
                ["Righteous Fury"] = { "Spell_Holy_SealOfFury" }
                -- REMOVED: Holy Shield (Talent dependent / Deep Prot only)
            },
            GROUP = {
                ["Blessing of Kings"] = { "Spell_Magic_MageArmor", "Spell_Magic_GreaterBlessingofKings" },
                ["Blessing of Might"] = { "Spell_Holy_FistOfJustice", "Spell_Holy_GreaterBlessingofKings" },
                ["Blessing of Light"] = { "Spell_Holy_PrayerOfHealing02" },
                ["Blessing of Sanctuary"] = { "Spell_Nature_LightningShield", "Spell_Holy_GreaterBlessingofSanctuary" },
                -- REMOVED: Blessing of Salvation (Tanks don't want threat reduction)
                ["Devotion Aura"] = { "Spell_Holy_DevotionAura" }
            }
        },
        SHAMAN = {
            SELF = { 
                ["Lightning Shield"] = { "Spell_Nature_LightningShield" },
                -- NEW: Rockbiter (Checked via Tooltip Scan)
                ["Rockbiter Weapon"] = { "Spell_Nature_RockBiter" }
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
        -- WARLOCK (Empty) so the Roster Scanner counts them for Healthstones
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