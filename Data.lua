-- Data.lua
TA_DATA = {
    -- 1. CLASS BUFFS
    CLASSES = {
        WARRIOR = {
            SELF = {
                ["Battle Shout"] = { "Ability_Warrior_BattleShout" },
                ["Defensive Stance"] = { "Ability_Warrior_DefensiveStance" }
            },
            GROUP = {
                -- Rank 7 (AQ20)
                ["Battle Shout"] = { "Ability_Warrior_BattleShout", id = 25289 } 
            }
        },
        DRUID = {
            SELF = {
                ["Thorns"] = { "Spell_Nature_Thorns" },
                ["Bear Form"] = { "Ability_Racial_BearForm" }
            },
            GROUP = {
                -- Rank 7
                ["Mark of the Wild"] = { "Spell_Nature_Regeneration", "Spell_Nature_Regeneration", id = 9885 },
                -- Rank 6
                ["Thorns"] = { "Spell_Nature_Thorns", id = 9910 }
            }
        },
        PALADIN = {
            SELF = {
                ["Righteous Fury"] = { "Spell_Holy_SealOfFury" }
            },
            GROUP = {
                -- Rank 1 (Scaling)
                ["Blessing of Kings"] = { "Spell_Magic_MageArmor", "Spell_Magic_GreaterBlessingofKings", id = 20217 },
                -- Rank 7 (AQ20)
                ["Blessing of Might"] = { "Spell_Holy_FistOfJustice", "Spell_Holy_GreaterBlessingofKings", id = 25291 },
                -- Rank 3
                ["Blessing of Light"] = { "Spell_Holy_PrayerOfHealing02", id = 19979 },
                -- Rank 4
                ["Blessing of Sanctuary"] = { "Spell_Nature_LightningShield", "Spell_Holy_GreaterBlessingofSanctuary", id = 20914 },
                -- Rank 7
                ["Devotion Aura"] = { "Spell_Holy_DevotionAura", id = 10293 }
            }
        },
        SHAMAN = {
            SELF = {
                ["Lightning Shield"] = { "Spell_Nature_LightningShield" },
                ["Rockbiter Weapon"] = { "Spell_Nature_RockBiter" }
            },
            GROUP = {}
        },
        PRIEST = {
            GROUP = {
                -- Rank 4
                ["Divine Spirit"] = { "Spell_Holy_DivineSpirit", "Spell_Holy_PrayerofSpirit", id = 27841 },
                -- Rank 6
                ["Power Word: Fortitude"] = { "Spell_Holy_WordFortitude", "Spell_Holy_PrayerOfFortitude", id = 10938 }
            }
        },
        MAGE = {
            GROUP = {
                -- Rank 5
                ["Arcane Intellect"] = { "Spell_Holy_MagicalSentry", "Spell_Holy_ArcaneIntellect", id = 10157 }
            }
        },
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
    },

    -- 3. DISPEL CAPABILITIES (1.12)
    -- Maps Debuff Type -> List of Classes that can remove it
    DISPEL_MAP = {
        ["Magic"]   = { PRIEST = true, PALADIN = true },
        ["Curse"]   = { MAGE = true, DRUID = true },
        ["Poison"]  = { DRUID = true, PALADIN = true, SHAMAN = true },
        ["Disease"] = { PRIEST = true, PALADIN = true, SHAMAN = true }
    }
}