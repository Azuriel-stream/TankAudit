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
TA_RP_MESSAGES = {
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
    ["Mark of the Wild"] = {
        "Druid, grant me the Mark of the Wild!",
        "The spirits whisper... I need the Mark!",
        "My fur needs thickening. Mark of the Wild, please!"
    },
    ["Arcane Intellect"] = {
        "Mage, I need some brilliance! (Arcane Intellect)",
        "My mind feels dull. Arcane Intellect, if you please!",
        "Grant me the intellect to hold this aggro!"
    },
    ["Thorns"] = {
        "Druid, cover me in Thorns!",
        "I need Thorns to make them pay for striking me!",
        "Let them bleed when they strike. Thorns, please!"
    },
    ["Battle Shout"] = {
        "Warrior, let me hear your Battle Shout!",
        "Roar for glory! I need Battle Shout!",
        "Strengthen our arms, Warrior! Battle Shout, please!"
    },
    -- Fallback for any undefined buff
    ["DEFAULT"] = {
        "I need %s!",
        "Can I get %s please?",
        "Buff %s please!"
    }
}