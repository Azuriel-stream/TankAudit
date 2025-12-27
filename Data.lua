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
                ["Battle Shout"] = { "Ability_Warrior_BattleShout", id = 25289 } 
            }
        },
        DRUID = {
            SELF = {
                ["Thorns"] = { "Spell_Nature_Thorns" },
                ["Bear Form"] = { "Ability_Racial_BearForm" }
            },
            GROUP = {
                ["Mark of the Wild"] = { "Spell_Nature_Regeneration", "Spell_Nature_Regeneration", id = 9885 },
                ["Thorns"] = { "Spell_Nature_Thorns", id = 9910 }
            }
        },
        PALADIN = {
            SELF = {
                ["Righteous Fury"] = { "Spell_Holy_SealOfFury" }
            },
            GROUP = {
                ["Blessing of Kings"] = { "Spell_Magic_MageArmor", "Spell_Magic_GreaterBlessingofKings", id = 20217 },
                ["Blessing of Might"] = { "Spell_Holy_FistOfJustice", "Spell_Holy_GreaterBlessingofKings", id = 25291 },
                -- UPDATED: Added Greater Blessing of Light icon
                ["Blessing of Light"] = { "Spell_Holy_PrayerOfHealing02", "Spell_Holy_GreaterBlessingofLight", id = 19979 },
                ["Blessing of Sanctuary"] = { "Spell_Nature_LightningShield", "Spell_Holy_GreaterBlessingofSanctuary", id = 20914 },
                -- UPDATED: Renamed to "Paladin Aura" and added Retribution Aura icon
                ["Paladin Aura"] = { "Spell_Holy_DevotionAura", "Spell_Holy_AuraOfLight", id = 10293 }
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
                ["Divine Spirit"] = { "Spell_Holy_DivineSpirit", "Spell_Holy_PrayerofSpirit", id = 27841 },
                ["Power Word: Fortitude"] = { "Spell_Holy_WordFortitude", "Spell_Holy_PrayerOfFortitude", id = 10938 }
            }
        },
        MAGE = {
            GROUP = {
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
        ELIXIRS = {
            ["Elixir"] = { 
                "INV_Potion_32", "INV_Potion_61", "INV_Potion_86", "INV_Potion_43", 
                "INV_Potion_33", "INV_Potion_62", "INV_Potion_97", "INV_Potion_41", "INV_Potion_48" 
            }
        },
        FLASKS = {
            ["Flask"] = { "INV_Potion_62", "INV_Potion_97", "INV_Potion_41", "INV_Potion_48" }
        }
    },

    -- 3. DISPEL RULES (1.12)
    DISPEL_RULES = {
        ["Magic"] = {
            PRIEST = { level = 18, spell = "Dispel Magic" },
            PALADIN = { level = 42, spell = "Cleanse" }
        },
        ["Curse"] = {
            MAGE = { level = 18, spell = "Remove Lesser Curse" },
            DRUID = { level = 24, spell = "Remove Curse" }
        },
        ["Poison"] = {
            DRUID = { level = 14, spell = "Cure Poison" },
            PALADIN = { level = 8, spell = "Purify" }, 
            SHAMAN = { level = 16, spell = "Cure Poison" }
        },
        ["Disease"] = {
            PRIEST = { level = 14, spell = "Cure Disease" },
            PALADIN = { level = 8, spell = "Purify" },
            SHAMAN = { level = 22, spell = "Cure Disease" }
        }
    },

    -- 4. UNWANTED BUFFS (For Tanks)
    -- These will appear in the Debuff bar to be clicked off
    UNWANTED = {
        ["Blessing of Salvation"] = { "Spell_Holy_SealOfSalvation", "Spell_Holy_GreaterBlessingofSalvation" }
    }
}