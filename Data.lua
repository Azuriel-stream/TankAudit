-- Data.lua
-- Contains all static data for Spells, Consumables, and Icons.

TA_DATA = {
    -- 1. CLASS BUFFS (Self-Buffs & Party Buffs)
    -- Format: ["Display Name"] = "Icon_Filename_Partial_String"
    -- We use partial strings to avoid path issues (e.g. "Ability_Warrior_BattleShout")
    
    CLASSES = {
        WARRIOR = {
            SELF = {
                ["Battle Shout"] = "Ability_Warrior_BattleShout",
            },
            GROUP = {} -- Warriors generally don't provide long-term party buffs other than shout
        },
        DRUID = {
            SELF = {
                ["Bear Form"] = "Ability_Racial_BearForm", 
                ["Dire Bear Form"] = "Ability_Racial_BearForm", -- Same icon usually
                ["Thorns"] = "Spell_Nature_Thorns",
                ["Omen of Clarity"] = "Spell_Nature_CrystalBall",
            },
            GROUP = {
                ["Mark of the Wild"] = "Spell_Nature_Regeneration",
                ["Gift of the Wild"] = "Spell_Nature_Regeneration",
            }
        },
        PALADIN = {
            SELF = {
                ["Righteous Fury"] = "Spell_Holy_SealOfFury",
                ["Holy Shield"] = "Spell_Holy_BlessingOfProtection", -- Check icon logic later, sometimes overlaps
            },
            GROUP = {
                ["Blessing of Kings"] = "Spell_Magic_MageArmor", -- Vanilla icon is often MageArmor or similar
                ["Blessing of Might"] = "Spell_Holy_FistOfJustice",
                ["Blessing of Light"] = "Spell_Holy_PrayerOfHealing02",
                ["Blessing of Sanctuary"] = "Spell_Nature_LightningShield",
                ["Blessing of Salvation"] = "Spell_Holy_SealOfSalvation",
            }
        },
        SHAMAN = {
            SELF = {
                ["Lightning Shield"] = "Spell_Nature_LightningShield",
                -- Rockbiter is handled via GetWeaponEnchantInfo(), not UnitBuff
            },
            GROUP = {
                ["Strength of Earth Totem"] = "Spell_Nature_EarthBindTotem", -- Totems are tricky, usually check aura
                ["Windfury Totem"] = "Spell_Nature_Windfury",
            }
        },
        PRIEST = {
            GROUP = {
                ["Power Word: Fortitude"] = "Spell_Holy_WordFortitude",
                ["Prayer of Fortitude"] = "Spell_Holy_PrayerOfFortitude",
                ["Divine Spirit"] = "Spell_Holy_DivineSpirit",
            }
        },
        MAGE = {
            GROUP = {
                ["Arcane Intellect"] = "Spell_Holy_MagicalSentry",
                ["Arcane Brilliance"] = "Spell_Holy_ArcaneIntellect",
            }
        },
        WARLOCK = {
            GROUP = {
                ["Blood Pact"] = "Spell_Shadow_BloodBoil", -- Actually the Imp's aura
            }
        }
    },

    -- 2. CONSUMABLES (General)
    CONSUMABLES = {
        -- Food
        FOOD = {
            ["Well Fed"] = "Spell_Misc_Food",
        },
        -- Flasks (Raid Mode)
        FLASKS = {
            ["Flask of the Titans"] = "INV_Potion_62",
            ["Flask of Distilled Wisdom"] = "INV_Potion_97",
            ["Flask of Supreme Power"] = "INV_Potion_41",
            ["Flask of Chromatic Resistance"] = "INV_Potion_48",
        },
        -- Elixirs (Fallback if no flask)
        ELIXIRS = {
            ["Elixir of the Mongoose"] = "INV_Potion_32",
            ["Elixir of Fortitude"] = "INV_Potion_44",
            ["Elixir of Superior Defense"] = "INV_Potion_86",
            ["Greater Arcane Elixir"] = "INV_Potion_25",
        }
    },

    -- 3. WEAPON ENCHANTS (Temporary)
    -- These are checked via GetWeaponEnchantInfo, not UnitBuff icons.
    -- This table is for the "Request" button text.
    WEAPON_ENCHANTS = {
        SHARPENING_STONE = "Sharpening Stone",
        WEIGHTSTONE = "Weightstone",
        WIZARD_OIL = "Wizard Oil",
        ROCKBITER = "Rockbiter Weapon", -- Shaman Specific
        WINDFURY = "Windfury Weapon",   -- Shaman Specific
    },
    
    -- 4. DEBUFF MAP (For the Dispel System)
    -- Maps Debuff Type -> Class that can dispel it
    DISPEL_TYPES = {
        ["Magic"] = { "PRIEST", "PALADIN" },
        ["Poison"] = { "DRUID", "PALADIN", "SHAMAN" },
        ["Curse"] = { "MAGE", "DRUID" },
        ["Disease"] = { "PRIEST", "PALADIN", "SHAMAN" }
    }
}