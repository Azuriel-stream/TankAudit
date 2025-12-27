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
    MSG_NEED_DISPEL = "I have %s (%s) - Dispel me please!",
    MSG_NEED_HS = "I need a Healthstone please!",
    
    -- New 1.4.0 Strings
    MSG_EXPIRING_SUFFIX = " (fading in %s)",
    MSG_THANK_YOU = {
        "Thanks for the %s, %s!",
        "Much appreciated, %s.",
        "Got the %s, thank you %s!"
    },
    
    -- Local Alerts (Self-Reminders)
    MSG_LOCAL_FOOD = "|cFFFF0000[Audit]|r You need to eat! Check your bags.",
    MSG_LOCAL_WEAPON = "|cFFFF0000[Audit]|r Your weapon needs a Sharpening Stone/Oil!",
    MSG_WAIT_THROTTLE = "|cFFFF0000[Audit]|r Wait before asking again.",
}

-- RP FLAVOR MESSAGES
-- %s will be replaced by the clickable Spell Link
-- v1.4.0: Tones softened from "Demand" to "Request"
TA_RP_MESSAGES = {
    -- PRIEST
    ["Power Word: Fortitude"] = {
        "Priest, could you bolster my health with %s?",
        "My shield is strong, but my health is low. %s please!",
        "Fortify me, Priest! I could use %s."
    },
    ["Divine Spirit"] = {
        "I need the guidance of the %s.",
        "Priest, if you can spare the mana, %s please!",
        "My spirit is willing, but the buff is missing. %s please."
    },

    -- DRUID
    ["Mark of the Wild"] = {
        "Druid, grant me the %s if you can!",
        "The spirits whisper... I need %s!",
        "My fur needs thickening. %s please!"
    },
    ["Thorns"] = {
        "Druid, a layer of %s would help with threat.",
        "I could use %s to make them pay for striking me!",
        "Let them bleed when they strike. %s please!"
    },

    -- MAGE
    ["Arcane Intellect"] = {
        "Mage, I need some brilliance! %s please!",
        "My mind feels dull. %s, if you please!",
        "Grant me the intellect to hold this aggro! (%s)"
    },

    -- WARRIOR
    ["Battle Shout"] = {
        "Warrior, let me hear your %s!",
        "Roar for glory! I need %s!",
        "Strengthen our arms, Warrior! %s please!"
    },

    -- PALADIN
    ["Blessing of Kings"] = {
        "Paladin, grant me the majesty of %s!",
        "A tank is nothing without his crown. %s please!",
        "A touch of royalty would help, Paladin. %s please!"
    },
    ["Blessing of Might"] = {
        "Paladin, grant me the strength to crush my foes! %s!",
        "My swings are weak. I need %s!",
        "Empower me, Paladin! %s!"
    },
    ["Blessing of Wisdom"] = {
        "Paladin, my mana is draining fast. %s please!",
        "Grant me the clarity of the Light. %s!",
        "I need mana to hold the line! %s please!"
    },
    ["Blessing of Sanctuary"] = {
        "Paladin, ward me against harm! %s!",
        "I need the Light's protection. %s please!",
        "Shield me from their blows with %s!"
    },
    ["Blessing of Light"] = {
        "Illumine my path and my healing! %s!",
        "Let the healers' light shine brighter on me! %s!",
        "I need the holy light to mend me faster. %s please!"
    },
    ["Devotion Aura"] = {
        "Paladin, I need your %s for armor!",
        "My armor is paper! %s please!",
        "Protect us with your %s!"
    },

    -- FALLBACK
    ["DEFAULT"] = {
        "I could use %s!",
        "Can I get %s please?",
        "Buff %s please!"
    }
}