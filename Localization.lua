-- Localization.lua
TA_STRINGS = {
    LOADED = "|cFF00FF00[TankAudit]|r v%s active. Type /taudit to open settings.",
    MISSING_HEADER = "Missing Buffs:",
    EXPIRING_HEADER = "Expiring Soon:",
    WARRIOR = "Warrior",
    DRUID = "Druid",
    PALADIN = "Paladin",
    SHAMAN = "Shaman",
    
    -- Standard Messages
    MSG_NEED_BUFF = "I need %s!",
    MSG_BUFF_EXPIRING = "I need %s - expiring in %s!",
    MSG_NEED_DISPEL = "I have %s - Dispel me please!",
    MSG_NEED_HS = "I need a Healthstone please!",
    
    -- Local Alerts (Self-Reminders)
    MSG_LOCAL_FOOD = "|cFFFF0000[Audit]|r You need to eat! Check your bags.",
    MSG_LOCAL_WEAPON = "|cFFFF0000[Audit]|r Your weapon needs a Sharpening Stone/Oil!",
    MSG_WAIT_THROTTLE = "|cFFFF0000[Audit]|r Wait before asking again.",
}

-- RP FLAVOR MESSAGES
-- The addon will pick a random line from these lists.
-- RP FLAVOR MESSAGES
-- The addon will pick a random line from these lists based on the missing buff name.
TA_RP_MESSAGES = {
    -- PRIEST
    ["Power Word: Fortitude"] = {
        "Priest, I require the blessing of Fortitude!",
        "My shield is strong, but my health is low. Power Word: Fortitude, please!",
        "Fortify me, Priest, so I may hold the line!"
    },
    ["Divine Spirit"] = {
        "I need the guidance of the Divine Spirit.",
        "Priest, grant me your Spirit buff!",
        "My spirit is willing, but the buff is missing. Divine Spirit, please."
    },

    -- DRUID
    ["Mark of the Wild"] = {
        "Druid, grant me the Mark of the Wild!",
        "The spirits whisper... I need the Mark!",
        "My fur needs thickening. Mark of the Wild, please!"
    },
    ["Thorns"] = {
        "Druid, cover me in Thorns!",
        "I need Thorns to make them pay for striking me!",
        "Let them bleed when they strike. Thorns, please!"
    },

    -- MAGE
    ["Arcane Intellect"] = {
        "Mage, I need some brilliance! (Arcane Intellect)",
        "My mind feels dull. Arcane Intellect, if you please!",
        "Grant me the intellect to hold this aggro!"
    },

    -- WARRIOR
    ["Battle Shout"] = {
        "Warrior, let me hear your Battle Shout!",
        "Roar for glory! I need Battle Shout!",
        "Strengthen our arms, Warrior! Battle Shout, please!"
    },

    -- PALADIN
    ["Blessing of Kings"] = {
        "Paladin, grant me the majesty of Kings!",
        "A tank is nothing without his crown. Blessing of Kings, please!",
        "By the Light, I require the Blessing of Kings!"
    },
    ["Blessing of Might"] = {
        "Paladin, grant me the strength to crush my foes! (Might)",
        "My swings are weak. I need the Blessing of Might!",
        "Empower me, Paladin! Blessing of Might!"
    },
    ["Blessing of Wisdom"] = {
        "Paladin, my mana is draining fast. Blessing of Wisdom, please!",
        "Grant me the clarity of the Light. Blessing of Wisdom!",
        "I need mana to hold the line! Wisdom, please!"
    },
    ["Blessing of Sanctuary"] = {
        "Paladin, ward me against harm! Blessing of Sanctuary!",
        "I need the Light's protection. Sanctuary, please!",
        "Shield me from their blows with the Blessing of Sanctuary!"
    },
    ["Blessing of Light"] = {
        "Illumine my path and my healing! Blessing of Light!",
        "Let the healers' light shine brighter on me! Blessing of Light!",
        "I need the holy light to mend me faster. Blessing of Light, please!"
    },
    ["Devotion Aura"] = {
        "Paladin, I need your Devotion Aura for armor!",
        "My armor is paper! Devotion Aura, please!",
        "Protect us with your Devotion Aura!"
    },

    -- WARLOCK (Healthstone)
    ["Healthstone"] = {
        "Summoning cookie, please!",
        "I require a green rock, Warlock.",
        "The tank requires a soul shard... in cookie form.",
        "Healthstone me!",
        "My bags feel empty without a Healthstone."
    },

    -- FALLBACK
    ["DEFAULT"] = {
        "I need %s!",
        "Can I get %s please?",
        "Buff %s please!"
    }
}