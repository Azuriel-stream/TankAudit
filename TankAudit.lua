-- TankAudit.lua

-- 1. Constants & Variables
local TA_VERSION = "1.1.1"
local TA_PLAYER_CLASS = nil
local TA_IS_TANK = false
-- State Variables
local TA_ROSTER_CLASSES = {} -- Stores classes present in group: { ["PRIEST"] = true, ["DRUID"] = true }
local TA_MISSING_BUFFS = {}  -- Stores result of scan
local TA_EXPIRING_BUFFS = {} -- Stores result of scan
local TA_SCAN_QUEUED = false  -- NEW: Track if a scan is waiting
local TA_KNOWN_SPELLS = {}
local TA_HAS_PROT_PALADIN = false
local TA_ACTIVE_DEBUFFS = {} -- Stores debuffs that need removal
-- UI Variables
local TA_BUTTON_POOL = {}
local TA_MAX_BUTTONS = 16
local TA_BUTTON_SIZE = 30
local TA_BUTTON_SPACING = 2
local TA_FRAME_ANCHOR = "CENTER" -- Default position
local TA_TooltipScanner = nil
-- Timers
local timeSinceLastScan = 0
local SCAN_INTERVAL = 3      -- UPDATED: Faster checks (was 15)
local timeSinceLastHS = 0
local HS_INTERVAL = 60       -- Keep Healthstone at 60s

-- Thresholds & Limits
local MAX_BUFF_SLOTS = 32                -- Maximum buff slots to scan per player
local BUFF_WARNING_SELF = 15             -- Seconds before self-buff expiry warning
local BUFF_WARNING_GROUP = 120           -- Seconds before group-buff expiry warning
local REQUEST_THROTTLE = 5               -- Seconds between buff requests
local TIMER_WARNING_THRESHOLD = 10       -- Seconds to display timer in red
local MAIN_HAND_SLOT = 16                -- Inventory slot ID for main hand weapon

-- Default Settings
local TA_DEFAULTS = {
    enabled = true,
    scale = 1.0,
    x = 0,      -- NEW
    y = -100,   -- NEW (Default vertical position)
    checkFood = true,
    checkBuffs = true,
    checkSelf = true,
    checkHealthstone = true,
    paladinPriority = { "Blessing of Kings", "Blessing of Might", "Blessing of Light", "Blessing of Sanctuary" }
}

-- ================================================================
-- LOCALIZE GLOBAL FUNCTIONS (Performance & Safety - 1.12 Best Practice)
-- ================================================================
local _strfind = string.find
local _strlower = string.lower
local _strformat = string.format
local _tinsert = table.insert
local _tgetn = table.getn
local _mathceil = math.ceil
local _mathabs = math.abs
local _mathrandom = math.random

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

-- Format seconds into readable time string
-- @param seconds (number) - Time remaining in seconds
-- @return (string) - Formatted string like "2m" or "15"
local function FormatTimeLeft(seconds)
    if seconds > 60 then
        return _mathceil(seconds / 60) .. "m"
    else
        return tostring(_mathceil(seconds)) .. "s"
    end
end


-- 2. Slash Command Registration
SLASH_TANKAUDIT1 = "/taudit"
SlashCmdList["TANKAUDIT"] = function(msg)
    TankAudit_SlashHandler(msg)
end

-- 3. Initialization
function TankAudit_OnLoad()
    -- Determine Class immediately
    local _, class = UnitClass("player")
    TA_PLAYER_CLASS = class

    -- Define Valid Tank Classes (Including Shaman for Turtle WoW)
    if class == "WARRIOR" or class == "DRUID" or class == "PALADIN" or class == "SHAMAN" then
        TA_IS_TANK = true
    else
        TA_IS_TANK = false
    end

    -- If NOT a tank, stop here.
    if not TA_IS_TANK then
        return 
    end

    -- Register Events
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("PLAYER_REGEN_DISABLED")
    this:RegisterEvent("PLAYER_REGEN_ENABLED")
    this:RegisterEvent("LEARNED_SPELL_IN_TAB")

    -- Event-Driven Updates
    this:RegisterEvent("UNIT_AURA")
    this:RegisterEvent("UNIT_INVENTORY_CHANGED")
    this:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    -- Create the UI Button Pool
    TankAudit_CreateButtonPool()

    -- Print Loaded Message
    -- Formats the string: "[TankAudit] v1.0.0 active. Type /taudit to open settings."
    DEFAULT_CHAT_FRAME:AddMessage(_strformat(TA_STRINGS.LOADED, TA_VERSION))
end

-- 4. Slash Command Handler
function TankAudit_SlashHandler(msg)
    if not TA_IS_TANK then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000TankAudit:|r Disabled for non-tanks.")
        return
    end

    if msg == "config" or msg == "" then
        TankAudit_ConfigFrame:Show() -- Show the new window
    elseif msg == "debug" then
        TankAudit_DebugBuffs()
    elseif msg == "test" then
        TankAudit_RunBuffScan()
    else
        DEFAULT_CHAT_FRAME:AddMessage("TankAudit usage: /taudit config")
    end
end

-- 5. Event Handling
function TankAudit_OnEvent(event)
    if not TA_IS_TANK then return end

    if event == "PLAYER_ENTERING_WORLD" then
        TankAudit_InitializeDefaults()
        TankAudit_CacheSpells()
        
    elseif event == "LEARNED_SPELL_IN_TAB" then
        TankAudit_CacheSpells()

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- Combat State Change: Queue Scan
        TA_SCAN_QUEUED = true
        
    elseif event == "UNIT_AURA" then
        -- Buffs Changed: Queue Scan
        if arg1 == "player" then
            TA_SCAN_QUEUED = true
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        -- Items Looted/Consumed: Queue Scan
        if arg1 == "player" then
            TA_SCAN_QUEUED = true
        end
    
    elseif event == "PLAYER_TARGET_CHANGED" then
        TA_SCAN_QUEUED = true
    end
end

-- 6. The Timer Loop (OnUpdate)
function TankAudit_OnUpdate(elapsed)
    if not TA_IS_TANK then 
        this:SetScript("OnUpdate", nil) 
        return 
    end

    -- 1. CRITICAL FIX: Process Queued Scans (Instant Response)
    -- If an event (like targeting) set this flag, run the scan NOW.
    if TA_SCAN_QUEUED then
        TankAudit_RunBuffScan()
        TA_SCAN_QUEUED = false
        timeSinceLastScan = 0 -- Reset the safety timer so we don't double-scan
    end

    -- 2. Run Visual Updates (Every Frame)
    -- Keeps the countdown timers smooth
    TankAudit_UpdateButtonVisuals()

    -- 3. Update Buff Scan Timer (Safety Net - Every 3s)
    -- This catches buffs expiring naturally if no events fire
    timeSinceLastScan = timeSinceLastScan + elapsed
    if timeSinceLastScan > SCAN_INTERVAL then
        TankAudit_RunBuffScan()
        timeSinceLastScan = 0
    end

    -- 4. Update Healthstone Timer (Every 60s)
    timeSinceLastHS = timeSinceLastHS + elapsed
    if timeSinceLastHS > HS_INTERVAL then
        TankAudit_CheckHealthstone()
        timeSinceLastHS = 0
    end
end

-- =============================================================
-- 7. LOGIC CORE (Battle Shout Edition)
-- =============================================================

-- State Variables
local TA_ROSTER_INFO = {
    CLASSES = {},              -- Global Counts
    HAS_GROUP_WARRIOR = false, -- Is there a Warrior in my subgroup?
    MY_SUBGROUP = 1
}

-- A. Roster Analysis (Subgroups & Counts)
function TankAudit_UpdateRoster()
    TA_ROSTER_INFO.CLASSES = {}
    TA_ROSTER_INFO.HAS_GROUP_WARRIOR = false
    TA_ROSTER_INFO.HAS_GROUP_PALADIN = false -- NEW: Track Party Paladins
    
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    
    -- Case 1: Solo
    if numRaid == 0 and numParty == 0 then
        TA_ROSTER_INFO.CLASSES[TA_PLAYER_CLASS] = 1
        return
    end

    -- Case 2: Raid
    if numRaid > 0 then
        -- Find my subgroup
        for i = 1, numRaid do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name == UnitName("player") then
                TA_ROSTER_INFO.MY_SUBGROUP = subgroup
                break
            end
        end
        -- Scan members
        for i = 1, numRaid do
            local _, _, subgroup, _, _, class, _, online = GetRaidRosterInfo(i)
            if online then
                TA_ROSTER_INFO.CLASSES[class] = (TA_ROSTER_INFO.CLASSES[class] or 0) + 1
                
                -- Check for Classes in MY subgroup
                if subgroup == TA_ROSTER_INFO.MY_SUBGROUP then
                    if class == "WARRIOR" then TA_ROSTER_INFO.HAS_GROUP_WARRIOR = true end
                    if class == "PALADIN" then TA_ROSTER_INFO.HAS_GROUP_PALADIN = true end
                end
            end
        end
        return
    end

    -- Case 3: Party (Everyone is in your group)
    TA_ROSTER_INFO.CLASSES[TA_PLAYER_CLASS] = 1
    for i = 1, numParty do
        local unit = "party"..i
        local _, class = UnitClass(unit)
        if class and UnitIsConnected(unit) then
            TA_ROSTER_INFO.CLASSES[class] = (TA_ROSTER_INFO.CLASSES[class] or 0) + 1
            if class == "WARRIOR" then TA_ROSTER_INFO.HAS_GROUP_WARRIOR = true end
            if class == "PALADIN" then TA_ROSTER_INFO.HAS_GROUP_PALADIN = true end
        end
    end
end

-- B. Buff Scanner
-- Scan player buffs for a specific buff by icon name
-- @param iconList (table) - Array of icon texture names to search for
-- @return hasBuff (boolean) - True if buff is active
-- @return timeLeft (number) - Seconds remaining on the buff (0 if not found)
function TankAudit_GetBuffStatus(iconList)
    local i = 0
    while i < MAX_BUFF_SLOTS do
        local buffIndex = GetPlayerBuff(i, "HELPFUL")
        if buffIndex < 0 then break end
        
        local texture = GetPlayerBuffTexture(buffIndex)
        if texture then
            for _, validIcon in pairs(iconList) do
                if _strfind(_strlower(texture), _strlower(validIcon)) then
                    local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
                    return true, timeLeft
                end
            end
        end
        i = i + 1
    end
    return false, 0
end

-- C. Healthstone Scanner
function TankAudit_CheckHealthstone()
    -- Only check if Warlock exists in raid (any group)
    if (TA_ROSTER_INFO.CLASSES["WARLOCK"] or 0) == 0 then return true end
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and _strfind(link, "Healthstone") then
                return true -- Found one
            end
        end
    end
    return false -- Missing
end

-- Helper: Check Weapon Enchants (Returns: hasEnchant, timeLeftInSeconds)
function TankAudit_CheckWeapon()
    -- GetWeaponEnchantInfo returns: hasMainHand, mainHandExpiration(ms), ..., hasOffHand, offHandExpiration(ms)
    local hasMH, expMH, _, hasOH, expOH = GetWeaponEnchantInfo()
    
    if hasMH then
        local timeSeconds = (expMH or 0) / 1000
        return true, timeSeconds
    end
    
    if hasOH then
        local timeSeconds = (expOH or 0) / 1000
        return true, timeSeconds
    end
    
    return false, 0
end

-- Helper: Check cache for spell by Icon Texture (Locale Independent)
-- @param iconList (table) - List of icon names (e.g. {"Ability_Warrior_BattleShout"})
function TankAudit_HasSpell(iconList)
    if not iconList or type(iconList) ~= "table" then return false end
    
    for _, iconName in pairs(iconList) do
        -- Construct the standard path (lowercase for matching)
        -- We assume standard WoW icon path structure
        local path = "interface\\icons\\" .. _strlower(iconName)
        if TA_KNOWN_SPELLS[path] then
            return true
        end
    end
    return false
end

-- Helper: Check Stance/Form by Icon Name (Works for Warrior/Druid)
function TankAudit_CheckStance(iconName)
    local numForms = GetNumShapeshiftForms()
    for i=1, numForms do
        local texture, name, isActive = GetShapeshiftFormInfo(i)
        if isActive and texture then
            -- We check if the texture string contains our target icon name
            if _strfind(_strlower(texture), _strlower(iconName)) then
                return true
            end
        end
    end
    return false
end

-- Helper: Scan Weapon Tooltip for Specific Enchant Name (e.g. "Rockbiter")
-- Returns: hasEnchant (boolean), timeLeft (number)
function TankAudit_CheckSpecificEnchant(enchantName)
    -- GetWeaponEnchantInfo returns: hasMainHand, mainHandExpiration(ms), ...
    local hasMH, expMH, _, hasOH, expOH = GetWeaponEnchantInfo()

    -- We primarily check Main Hand for Rockbiter
    if not hasMH then return false, 0 end

    -- Initialize Scanner Tip if missing (using local variable)
    if not TA_TooltipScanner then
        -- We create it without a name (arg 2 is nil) to avoid global pollution, 
        -- but we need to assign it to our local variable.
        TA_TooltipScanner = CreateFrame("GameTooltip", "TA_TooltipScanner_Private", nil, "GameTooltipTemplate")
        TA_TooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    TA_TooltipScanner:ClearLines()
    TA_TooltipScanner:SetInventoryItem("player", MAIN_HAND_SLOT) -- Main Hand

    for i=1, TA_TooltipScanner:NumLines() do
        -- We must dynamically get the text line. 
        -- Since we named the frame "TA_TooltipScanner_Private", the regions are named similarly.
        local lineObj = getglobal("TA_TooltipScanner_PrivateTextLeft"..i)
        if lineObj then
            local text = lineObj:GetText()
            if text and _strfind(text, enchantName) then
                -- Found it! Calculate seconds remaining
                local timeLeft = (expMH or 0) / 1000
                return true, timeLeft
            end
        end
    end

    return false, 0
end

-- Helper: Cache Known Spells by Texture (Optimization)
-- Stores all known spell icons as keys: TA_KNOWN_SPELLS["interface\icons\my_icon"] = true
function TankAudit_CacheSpells()
    TA_KNOWN_SPELLS = {} -- Clear cache
    local i = 1
    while true do
       -- GetSpellName returns (name, rank) - we don't need name anymore for logic
       local name, rank = GetSpellName(i, "spell")
       if not name then break end
       
       -- GetSpellTexture returns the full texture path (e.g. "Interface\Icons\Ability_Warrior_BattleShout")
       local texture = GetSpellTexture(i, "spell")
       if texture then
           -- Store as lowercase to avoid case-sensitivity issues
           TA_KNOWN_SPELLS[_strlower(texture)] = true
       end
       i = i + 1
    end
end

-- Helper: Inner function to check a specific unit for Sanctuary icons
-- Moved outside to avoid closure creation overhead
local function TA_CheckUnitForSanctuary(unit, icons)
    local i = 1
    while true do
        -- UnitBuff returns texture, rank, index (1.12 API)
        local texture = UnitBuff(unit, i)
        if not texture then break end

        for _, validIcon in pairs(icons) do
            if _strfind(_strlower(texture), _strlower(validIcon)) then
                return true -- Found it!
            end
        end
        i = i + 1
    end
    return false
end

-- Helper: Detect if a Prot Paladin is active by looking for Sanctuary on ANYONE
function TankAudit_ScanForSanctuary()
    -- Get the Sanc icons from our data table
    local icons = TA_DATA.CLASSES["PALADIN"].GROUP["Blessing of Sanctuary"]
    if not icons then return false end

    -- 1. Check Player (Fastest)
    if TA_CheckUnitForSanctuary("player", icons) then return true end

    -- 2. Check Raid/Party (Deep Scan)
    -- We scan this every 3s. To save CPU, we return immediately upon finding one instance.
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i=1, numRaid do
            if TA_CheckUnitForSanctuary("raid"..i, icons) then return true end
        end
    else
        local numParty = GetNumPartyMembers()
        for i=1, numParty do
            if TA_CheckUnitForSanctuary("party"..i, icons) then return true end
        end
    end

    return false
end

-- D. MAIN SCAN ROUTINE

-- Helper: Scan for actionable Debuffs
-- Checks if player has a debuff that a SPECIFIC group member can dispel
function TankAudit_ScanDebuffs()
    TA_ACTIVE_DEBUFFS = {}
    
    local i = 0
    while true do
        local buffIndex = GetPlayerBuff(i, "HARMFUL")
        if buffIndex < 0 then break end
        
        local texture, applications, debuffType = UnitDebuff("player", i + 1)
        
        if debuffType and texture then
            local canDispel = false
            
            -- 1. Check Self (Solo or Group)
            if TankAudit_CanUnitDispel("player", debuffType) then
                canDispel = true
            else
                -- 2. Check Group (if we can't do it ourselves)
                local numParty = GetNumPartyMembers()
                local numRaid = GetNumRaidMembers()
                
                if numRaid > 0 then
                    -- Optimization: For Raid, we assume competence and just check if the class exists
                    -- (As per your request to not worry about detailed raid checks)
                    if TA_DATA.DISPEL_RULES[debuffType] then
                        for class, _ in pairs(TA_DATA.DISPEL_RULES[debuffType]) do
                            if TA_ROSTER_INFO.CLASSES[class] and TA_ROSTER_INFO.CLASSES[class] > 0 then
                                canDispel = true
                                break
                            end
                        end
                    end
                elseif numParty > 0 then
                    -- Detailed Party Scan
                    for p = 1, numParty do
                        if TankAudit_CanUnitDispel("party"..p, debuffType) then
                            canDispel = true
                            break
                        end
                    end
                end
            end
            
            if canDispel then
                _tinsert(TA_ACTIVE_DEBUFFS, { 
                    name = debuffType, 
                    texture = texture, 
                    type = debuffType, 
                    index = buffIndex 
                })
            end
        end
        
        i = i + 1
    end
end

-- Helper: Generate a Chat Link for a spell
-- Uses hardcoded IDs from Data.lua because we cannot query links for spells we don't know
function TankAudit_GetSpellLink(buffName)
    -- 1. Find the ID in our data table
    local spellID = nil
    for class, data in pairs(TA_DATA.CLASSES) do
        if data.GROUP and data.GROUP[buffName] then
            spellID = data.GROUP[buffName].id
            break
        end
    end

    -- 2. If no ID found, return plain text
    if not spellID then return buffName end

    -- 3. Construct the Link string
    -- Color: 71d5ff (Spell Blue)
    -- |Hspell:ID|h[Name]|h
    return "|cff71d5ff|Hspell:" .. spellID .. "|h[" .. buffName .. "]|h|r"
end

-- Helper: Check if a specific unit is capable of removing a debuff type
-- Uses "Known Spells" for player, and "Level" for party members
function TankAudit_CanUnitDispel(unit, debuffType)
    local _, class = UnitClass(unit)
    if not class then return false end
    
    -- 1. Check if this class can EVER handle this debuff
    local rules = TA_DATA.DISPEL_RULES[debuffType]
    if not rules or not rules[class] then return false end
    
    local requirement = rules[class]
    
    -- 2. "Smart" Check
    if UnitIsUnit(unit, "player") then
        -- SELF: Strict check. Do we actually know the spell?
        -- We check the English name against our icon cache via the helper we made earlier
        -- NOTE: We need the icon for this to work perfectly, but for now checking the name 
        -- via a new helper or assuming the player trained if they are high enough level is safer.
        -- Let's stick to the Level check for consistency, OR use the Spellbook if we have the data.
        
        -- Robust fallback: Check Level. If we are high enough level, we SHOULD have it.
        local level = UnitLevel(unit)
        return level >= requirement.level
    else
        -- PARTY: Heuristic check. Are they high enough level?
        local level = UnitLevel(unit)
        
        -- Note: UnitLevel returns -1 for high level mobs, but usually returns correct # for party.
        -- If 0 or -1 (unlikely in party), we assume they are high enough.
        if level and level > 0 then
            return level >= requirement.level
        end
        return true -- Assume yes if level is unknown (safe fallback)
    end
end

-- Main audit routine - scans all buffs and updates missing/expiring lists
function TankAudit_RunBuffScan()
    if not TankAuditDB.enabled then
        TankAudit_UpdateUI()
        return
    end

    TankAudit_UpdateRoster()

    TA_MISSING_BUFFS = {}
    TA_EXPIRING_BUFFS = {}

    TankAudit_ScanDebuffs()

    -- Define Context Variables
    local isSolo = (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0)
    local inCombat = UnitAffectingCombat("player")

    -- 1. SCAN SELF BUFFS
    local selfBuffs = TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF
    if TankAuditDB.checkSelf and selfBuffs then
        for name, iconList in pairs(selfBuffs) do
            local knowsSpell = true

            -- Spellbook Checks (UPDATED: Now checks Icons, not Names)
            if name == "Bear Form" then
                -- Special handling: Druids might have "Dire Bear Form" which shares the icon
                -- or slightly differs. We check the iconList provided in TA_DATA.
                if not TankAudit_HasSpell(iconList) then knowsSpell = false end
            elseif name == "Thorns" or name == "Righteous Fury" or name == "Lightning Shield" or name == "Battle Shout" then
                -- Standard check using the icon list from TA_DATA
                if not TankAudit_HasSpell(iconList) then knowsSpell = false end
            end

            -- SOLO SUPPRESSION: Stances & Forms
            -- If we are Solo, do NOT alert for missing Forms/Stances (let the player farm in peace)
            local skipCheck = false
            if isSolo then
                if name == "Bear Form" or name == "Defensive Stance" or name == "Rockbiter Weapon" then
                    skipCheck = true
                end
            end

            if knowsSpell and not skipCheck then
                local hasBuff = false
                local timeLeft = 0

                -- SPECIAL HANDLERS
                if name == "Defensive Stance" then
                    -- Special Stance Check for Warriors
                    hasBuff = TankAudit_CheckStance("Ability_Warrior_DefensiveStance")

                elseif name == "Bear Form" then
                    -- Standard Buff check works for Bear, but let's double check Stance bar for robustness
                    hasBuff = TankAudit_GetBuffStatus(iconList) or TankAudit_CheckStance("BearForm")

                elseif name == "Rockbiter Weapon" then
                    -- Special Tooltip Scan for Shamans (Now returns time)
                    hasBuff, timeLeft = TankAudit_CheckSpecificEnchant("Rockbiter")

                else
                    -- Standard Buff Scan
                    hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
                end

                -- Determine Warning Threshold
                -- Default is 15s (BUFF_WARNING_SELF), but Rockbiter gets 60s
                local warningThreshold = BUFF_WARNING_SELF
                if name == "Rockbiter Weapon" then warningThreshold = 60 end

                if not hasBuff then
                    _tinsert(TA_MISSING_BUFFS, name)
                elseif timeLeft > 0 and timeLeft < warningThreshold then
                    _tinsert(TA_EXPIRING_BUFFS, { name = name, time = timeLeft })
                end
            end
        end
    end

    -- 2. SMART VISIBILITY FILTER (Solo & Out of Combat)
    if isSolo and not inCombat then
        local hasEnemyTarget = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
        local hasMissingSelfBuffs = (_tgetn(TA_MISSING_BUFFS) > 0)
        
        if not (hasEnemyTarget and hasMissingSelfBuffs) then
            TA_MISSING_BUFFS = {}
            TA_EXPIRING_BUFFS = {}
            TankAudit_UpdateUI()
            return
        end
    end

    -- 3. Group Buffs
    if TA_ROSTER_INFO.CLASSES["PALADIN"] then
        TA_HAS_PROT_PALADIN = TankAudit_ScanForSanctuary()
    else
        TA_HAS_PROT_PALADIN = false
    end

    for class, data in pairs(TA_DATA.CLASSES) do
        local classCount = TA_ROSTER_INFO.CLASSES[class] or 0
        
        if TankAuditDB.checkBuffs and classCount > 0 and data.GROUP then
            local validPaladinBuffs = {}
            if class == "PALADIN" then
                local priority = TankAuditDB.paladinPriority
                for p = 1, classCount do
                    if priority[p] then validPaladinBuffs[priority[p]] = true end
                end
            end

            for name, iconList in pairs(data.GROUP) do
                local shouldCheck = true
                
                if class == "PALADIN" then
                    if name == "Devotion Aura" then
                        -- Aura Check: STRICTLY requires a Paladin in your subgroup
                        if not TA_ROSTER_INFO.HAS_GROUP_PALADIN then
                            shouldCheck = false
                        end
                    elseif name == "Blessing of Sanctuary" then
                        -- Only ask for Sanc if we have PROOF a Prot Paladin exists
                        if not TA_HAS_PROT_PALADIN then shouldCheck = false end
                        -- Also respect the manual priority list
                        if not validPaladinBuffs[name] then shouldCheck = false end
                    else
                        -- Blessing Check: Allow from any Raid Paladin, but respect Priority List
                        if not validPaladinBuffs[name] then
                            shouldCheck = false
                        end
                    end
                end

                if name == "Arcane Intellect" and TA_PLAYER_CLASS == "WARRIOR" then shouldCheck = false end
                
                if name == "Battle Shout" then
                    if TA_PLAYER_CLASS == "WARRIOR" then shouldCheck = false
                    elseif not TA_ROSTER_INFO.HAS_GROUP_WARRIOR then shouldCheck = false end
                end
                
                if name == "Thorns" and TA_PLAYER_CLASS == "DRUID" then shouldCheck = false end

                if shouldCheck then
                    local hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
                    if not hasBuff then
                        _tinsert(TA_MISSING_BUFFS, name)
                    elseif timeLeft > 0 and timeLeft < BUFF_WARNING_GROUP then
                        _tinsert(TA_EXPIRING_BUFFS, { name = name, time = timeLeft })
                    end
                end
            end
        end
    end

    -- 4. Consumables
    -- SOLO SUPPRESSION: Ignore Food & Weapon Enchants if Solo
    local checkConsumables = TankAuditDB.checkFood and not isSolo
    
    if checkConsumables then
        -- MODIFIED: Capture time left
        local hasFood, foodTime = TankAudit_GetBuffStatus(TA_DATA.CONSUMABLES.FOOD["Well Fed"])
        if not hasFood then
            _tinsert(TA_MISSING_BUFFS, "Well Fed")
        elseif foodTime > 0 and foodTime < 60 then
            -- NEW: Alert if expiring in 1 minute or less
            _tinsert(TA_EXPIRING_BUFFS, { name = "Well Fed", time = foodTime })
        end

        -- Generic Weapon Check (for non-Shaman/non-Druid)
        if TA_PLAYER_CLASS ~= "DRUID" and TA_PLAYER_CLASS ~= "SHAMAN" then
            local hasWep, wepTime = TankAudit_CheckWeapon()
            if not hasWep then
                _tinsert(TA_MISSING_BUFFS, "Weapon Buff")
            elseif wepTime > 0 and wepTime <= 60 then
                _tinsert(TA_EXPIRING_BUFFS, { name = "Weapon Buff", time = wepTime })
            end
        end
    end

    -- 5. Healthstone
    if TankAuditDB.checkHealthstone and not TankAudit_CheckHealthstone() then
        _tinsert(TA_MISSING_BUFFS, "Healthstone")
    end

    TankAudit_UpdateUI()
end

-- UI Helpers
-- Create reusable button pool for displaying audit alerts
-- Initializes all buttons with proper sizing, fonts, and references
-- Called once during addon initialization
function TankAudit_CreateButtonPool()
    for i = 1, TA_MAX_BUTTONS do
        local btn = CreateFrame("Button", "TankAudit_Btn_"..i, UIParent, "TankAudit_RequestBtnTemplate")
        btn:SetWidth(TA_BUTTON_SIZE)
        btn:SetHeight(TA_BUTTON_SIZE)
        btn:SetID(i)
        
        -- 1. Get the FontString object
        local textObj = getglobal(btn:GetName().."Text")
        
        -- 2. CRITICAL FIX: Force the text box to be wide enough
        -- If this is 0 or too small, "18" gets cut off. 
        -- We set it to 50 (wider than the 30px button) to allow overflow.
        textObj:SetWidth(50) 
        textObj:SetHeight(20)
        
        -- 3. MPOWA Style: Explicitly set Font, Size, and Outline
        -- "Fonts\\FRIZQT__.TTF" is the standard WoW font.
        -- "14" is the size.
        -- "OUTLINE" creates the black border around the text so it's readable.
        textObj:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        
        -- 4. Alignment
        textObj:SetJustifyH("CENTER")
        textObj:SetTextColor(1, 1, 1) -- Default to white (updated to Red/Yellow later)
        
        -- Store reference
        btn.timerText = textObj
        
        btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        tinsert(TA_BUTTON_POOL, btn)
    end
end

-- Handle mouseover tooltips for buttons
-- Shows standard text for missing buffs, or full spell tooltip for active debuffs
function TankAudit_Button_OnEnter(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    
    -- If it's a real in-game debuff/buff that exists, show the full tooltip
    if btn.buffIndex and btn.buffIndex > -1 then
        GameTooltip:SetPlayerBuff(btn.buffIndex)
    else
        -- Fallback for "Missing" buffs (static text)
        GameTooltip:SetText(btn.tooltipText, 1, 1, 1)
    end
    
    GameTooltip:Show()
end

-- Update button timers and visual states every frame
-- Refreshes countdown text and icon desaturation for expiring buffs
-- Called by OnUpdate to keep timers smooth
function TankAudit_UpdateButtonVisuals()
    local currentTime = GetTime()
    
    for _, btn in pairs(TA_BUTTON_POOL) do
        if btn:IsVisible() and btn.expiresAt then
            local timeLeft = btn.expiresAt - currentTime
            
            -- Use the direct reference we established in CreateButtonPool
            local textObj = btn.timerText
            local iconObj = getglobal(btn:GetName().."Icon")
            
            if timeLeft <= 0 then
                -- Timer hit zero: Show "0" in red and desaturate
                textObj:SetText("|cFFFF00000|r") 
                iconObj:SetDesaturated(1)
            else
                -- Timer running: Ensure icon is colored
                iconObj:SetDesaturated(0)
                
                local timeStr = FormatTimeLeft(timeLeft)
                
                -- Red text for < 10s, Yellow for > 10s
                if timeLeft < TIMER_WARNING_THRESHOLD then
                    textObj:SetText("|cFFFF0000" .. timeStr .. "|r")
                else
                    textObj:SetText("|cFFFFFF00" .. timeStr .. "|r")
                end
            end
        end
    end
end

-- Move a Paladin blessing priority up or down in the list
-- @param index (number) - Current position in priority list (1-4)
-- @param direction (number) - Move direction: -1 (up) or 1 (down)
function TankAudit_MovePriority(index, direction)
    -- Direction: -1 (Up), 1 (Down)
    local newIndex = index + direction
    
    -- Bounds check
    if newIndex < 1 or newIndex > 4 then return end
    
    -- Swap
    local list = TankAuditDB.paladinPriority
    local temp = list[newIndex]
    list[newIndex] = list[index]
    list[index] = temp
    
    -- Save & Refresh UI
    TankAuditDB.paladinPriority = list
    TankAudit_Config_OnShow() -- Re-runs layout/text update
end

-- Rebuild and position all audit buttons based on current scan results
-- Handles scaling, positioning, test mode, and button state management
-- Creates centered horizontal row of icons showing missing/expiring buffs
-- Rebuild and position all audit buttons based on current scan results
-- Row 1 (Top): Active Debuffs (Red borders)
-- Row 2 (Bottom): Missing/Expiring Buffs
function TankAudit_UpdateUI()
    -- 1. Get Settings
    local scale = TankAuditDB.scale or 1.0
    local btnSize = TA_BUTTON_SIZE
    local spacing = TA_BUTTON_SPACING
    
    -- Config Mode Logic
    local renderDebuffs = TA_ACTIVE_DEBUFFS
    local renderMissing = TA_MISSING_BUFFS
    local renderExpiring = TA_EXPIRING_BUFFS
    
    local configFrame = getglobal("TankAudit_ConfigFrame")
    if configFrame and configFrame:IsVisible() then
        renderDebuffs = { 
            { name = "Magic", texture = "Interface\\Icons\\Spell_Holy_WordFortitude", index = -1, isTest = true } 
        }
        renderMissing = { "Test Button 1", "Test Button 2" }
        renderExpiring = {}
    end

    local usedButtons = 0
    local index = 1

    -- HELPER: Button Setup
    local function SetupButton(data, mode, xOffset, yOffset)
        if index > TA_MAX_BUTTONS then return end
        local btn = TA_BUTTON_POOL[index]
        
        btn:SetScale(scale)
        local iconObj = getglobal(btn:GetName().."Icon")
        local textObj = btn.timerText
        
        -- Reset State
        btn.isDebuff = false
        btn.buffIndex = -1
        btn.expiresAt = nil
        iconObj:SetDesaturated(0)
        textObj:Hide()
        
        if mode == "DEBUFF" then
            btn.isDebuff = true
            btn.buffName = data.type or "Debuff"
            btn.buffIndex = data.index -- For Tooltip
            btn.tooltipText = "Dispel: " .. (data.type or "Unknown")
            
            iconObj:SetTexture(data.texture)
            -- Red text to indicate danger
            textObj:SetText("|cFFFF0000DISPEL|r") 
            textObj:Show()
            
            -- Debuff Visuals: Maybe color the border red? 
            -- For now, the text "DISPEL" is clear enough.
            
        elseif mode == "MISSING" then
            local buffName = data
            btn.buffName = buffName
            btn.tooltipText = buffName
            iconObj:SetTexture(TankAudit_GetIconForName(buffName))
            iconObj:SetDesaturated(1) -- Greyed out
            
        elseif mode == "EXPIRING" then
            local buffName = data.name
            btn.buffName = buffName
            btn.tooltipText = buffName
            iconObj:SetTexture(TankAudit_GetIconForName(buffName))
            
            -- Timer Logic
            local timeLeft = data.time
            local newExpiry = GetTime() + timeLeft
            if not btn.expiresAt then btn.expiresAt = newExpiry
            elseif _mathabs(newExpiry - btn.expiresAt) > 2 then btn.expiresAt = newExpiry end
            
            textObj:Show()
            -- (Timer text update handled by OnUpdate loop)
        end
        
        -- POSITIONING
        btn:ClearAllPoints()
        -- Row 1 (Debuffs) is higher up. Row 2 (Buffs) is at anchor.
        btn:SetPoint("CENTER", "TankAudit_Anchor", "CENTER", xOffset, yOffset)
        
        btn:Show()
        usedButtons = usedButtons + 1
        index = index + 1
    end

    -- 2. CALCULATE ROW 1 (DEBUFFS) - Positioned ABOVE anchor
    local numDebuffs = _tgetn(renderDebuffs)
    if numDebuffs > 0 then
        local rowWidth = (numDebuffs * btnSize) + ((numDebuffs - 1) * spacing)
        local startX = -(rowWidth / 2) + (btnSize / 2)
        local yPos = btnSize + 5 -- Attached ABOVE the main bar
        
        for _, debuff in pairs(renderDebuffs) do
            SetupButton(debuff, "DEBUFF", startX, yPos)
            startX = startX + btnSize + spacing
        end
    end

    -- 3. CALCULATE ROW 2 (BUFFS) - Positioned AT anchor
    local numMissing = _tgetn(renderMissing)
    local numExpiring = _tgetn(renderExpiring)
    local totalBuffs = numMissing + numExpiring
    
    if totalBuffs > 0 then
        local rowWidth = (totalBuffs * btnSize) + ((totalBuffs - 1) * spacing)
        local startX = -(rowWidth / 2) + (btnSize / 2)
        local yPos = 0 -- Main bar
        
        for _, buffName in pairs(renderMissing) do
            SetupButton(buffName, "MISSING", startX, yPos)
            startX = startX + btnSize + spacing
        end
        for _, buffData in pairs(renderExpiring) do
            SetupButton(buffData, "EXPIRING", startX, yPos)
            startX = startX + btnSize + spacing
        end
    end

    -- Hide unused
    for i = usedButtons + 1, TA_MAX_BUTTONS do
        if TA_BUTTON_POOL[i] then TA_BUTTON_POOL[i]:Hide() end
    end
end

-- Look up the icon texture path for a given buff name
-- Searches class buffs, consumables, and hardcoded entries
-- @param buffName (string) - Name of the buff/item
-- @return (string) - Full texture path (e.g., "Interface\\Icons\\Spell_Nature_Thorns")
function TankAudit_GetIconForName(buffName)
    -- 1. Check Class Buffs
    for class, data in pairs(TA_DATA.CLASSES) do
        if data.SELF and data.SELF[buffName] then return "Interface\\Icons\\" .. data.SELF[buffName][1] end
        if data.GROUP and data.GROUP[buffName] then return "Interface\\Icons\\" .. data.GROUP[buffName][1] end
    end
    
    -- 2. Check Consumables
    if TA_DATA.CONSUMABLES.FOOD[buffName] then return "Interface\\Icons\\" .. TA_DATA.CONSUMABLES.FOOD[buffName][1] end
    
    -- 3. Healthstone (Specific Check)
    if buffName == "Healthstone" then 
        -- Hardcoded fallback if the table lookup fails for any reason
        return "Interface\\Icons\\INV_Stone_04" 
    end
    
    -- 4. Weapon
    if buffName == "Weapon Buff" then return "Interface\\Icons\\INV_Stone_SharpeningStone_01" end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Helper: Get the specific name of a debuff by scanning the tooltip
-- Required because UnitDebuff returns texture/type, but NOT the name in 1.12.
function TankAudit_GetDebuffName(buffIndex)
    -- Safety check
    if not buffIndex or buffIndex < 0 then return "Unknown" end

    -- Use the local scanner we defined in Step 2
    if not TA_TooltipScanner then
        -- Just in case it wasn't initialized yet
        TA_TooltipScanner = CreateFrame("GameTooltip", "TA_TooltipScanner_Private", nil, "GameTooltipTemplate")
        TA_TooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    TA_TooltipScanner:ClearLines()
    -- Set the scanner to look at the specific debuff slot
    TA_TooltipScanner:SetPlayerBuff(buffIndex)
    
    -- Read the Title (Line 1)
    local textObj = getglobal("TA_TooltipScanner_PrivateTextLeft1")
    if textObj then
        return textObj:GetText() or "Unknown"
    end
    
    return "Unknown"
end

-- Handle click events on audit buttons
-- Behavior depends on buff type:
--   • Self-buffs: Auto-cast the spell
--   • Consumables: Open bags with reminder message
--   • Group buffs: Send request message to party/raid chat
-- Includes throttling to prevent spam
-- @param btn (frame) - The button that was clicked
-- Handle click events on audit buttons
function TankAudit_RequestButton_OnClick(btn)
    local buffName = btn.buffName
    if not buffName then return end

    -- 1. HANDLE CONFIG TEST BUTTONS
    if _strfind(buffName, "Test Button") then
        local msg = _strformat("Message from %s", buffName)
        DEFAULT_CHAT_FRAME:AddMessage(msg)
        return
    end

    -- 2. HANDLE CONSUMABLES (Open Bags)
    if buffName == "Well Fed" or buffName == "Weapon Buff" then
        local bagsOpen = false
        if ContainerFrame1 and ContainerFrame1:IsVisible() then
            bagsOpen = true
        end
        if not bagsOpen then
            OpenAllBags()
        end

        if buffName == "Well Fed" then
            DEFAULT_CHAT_FRAME:AddMessage(TA_STRINGS.MSG_LOCAL_FOOD)
        elseif buffName == "Weapon Buff" then
            DEFAULT_CHAT_FRAME:AddMessage(TA_STRINGS.MSG_LOCAL_WEAPON)
        end
        return
    end

    -- 3. HANDLE SELF-CASTS (Smart Action)
    local selfBuffs = TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF
    if selfBuffs and selfBuffs[buffName] then
        if buffName == "Bear Form" or buffName == "Defensive Stance" then
             CastSpellByName(buffName)
             return
        end
        CastSpellByName(buffName, 1)
        return
    end

    -- 4. STANDARD GROUP REQUEST (Chat Message)
    -- Throttle check
    if btn.lastClick and (GetTime() - btn.lastClick) < REQUEST_THROTTLE then
        DEFAULT_CHAT_FRAME:AddMessage(TA_STRINGS.MSG_WAIT_THROTTLE)
        return
    end
    btn.lastClick = GetTime()

    -- Dynamic Channel Selection
    local channel = "SAY"
    if GetNumRaidMembers() > 0 then channel = "RAID"
    elseif GetNumPartyMembers() > 0 then channel = "PARTY"
    end

    local msg = ""

    -- NEW: Handle Debuffs
    if btn.isDebuff then
        local debuffType = btn.buffName -- e.g. "Magic", "Poison"
        
        -- 1. SELF-DISPEL CHECK
        -- Check if the player is the one who can remove this
        local myClassRule = TA_DATA.DISPEL_RULES[debuffType] and TA_DATA.DISPEL_RULES[debuffType][TA_PLAYER_CLASS]
        
        if myClassRule and UnitLevel("player") >= myClassRule.level then
            -- We can do it! Cast the spell on ourselves.
            -- CastSpellByName(spell, onSelf) -> onSelf is 1
            CastSpellByName(myClassRule.spell, 1)
            return
        end

        -- 2. GROUP REQUEST (Fallback)
        -- If we can't do it (or are too low level), ask the group.
        local specificName = TankAudit_GetDebuffName(btn.buffIndex)
        msg = _strformat(TA_STRINGS.MSG_NEED_DISPEL, specificName, debuffType)
        
    elseif btn.isExpiring then
        local timeText = getglobal(btn:GetName().."Text"):GetText() or "soon"
        msg = _strformat(TA_STRINGS.MSG_BUFF_EXPIRING, buffName, timeText)
    else
        -- 5. GROUP BUFF REQUEST (RP Flavor)
        
        -- Generate the Link (e.g. "[Blessing of Kings]" in blue)
        local spellLink = TankAudit_GetSpellLink(buffName)
        
        -- Check for RP Messages
        if TA_RP_MESSAGES[buffName] then
            local options = TA_RP_MESSAGES[buffName]
            local choice = _mathrandom(1, _tgetn(options))
            local rawMsg = options[choice]
            
            -- Insert the link into the %s placeholder
            msg = _strformat(rawMsg, spellLink)
        else
            -- Fallback default message
            -- Ensure fallback strings also have a %s in Localization, or handle it here
            local fallback = TA_RP_MESSAGES["DEFAULT"][1] 
            msg = _strformat(fallback, spellLink)
        end
    end
    
    SendChatMessage(msg, channel)
end

function TankAudit_DebugBuffs()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Audit] Current Buffs:|r")
    local i = 0
    while i < MAX_BUFF_SLOTS do
        local buffIndex = GetPlayerBuff(i, "HELPFUL")
        if buffIndex < 0 then break end
        local texture = GetPlayerBuffTexture(buffIndex)
        if texture then DEFAULT_CHAT_FRAME:AddMessage(i .. ": " .. texture) end
        i = i + 1
    end
end

-- Initialize saved variables with default values if missing
-- Called on PLAYER_ENTERING_WORLD to ensure TankAuditDB is populated
function TankAudit_InitializeDefaults()
    if not TankAuditDB then
        TankAuditDB = {}
    end
    
    -- Loop through defaults and set them if missing
    for k, v in pairs(TA_DEFAULTS) do
        if TankAuditDB[k] == nil then
            TankAuditDB[k] = v
        end
    end
    
    -- Apply Scale immediately
    TankAudit_UpdateScale()
    TankAudit_SetPosition(TankAuditDB.x, TankAuditDB.y)
end

function TankAudit_UpdateScale()
    local scale = TankAuditDB.scale or 1.0
    for _, btn in pairs(TA_BUTTON_POOL) do
        btn:SetScale(scale)
    end
end

-- Update the anchor position and sync with config UI
-- @param x (number) - Horizontal offset from screen center
-- @param y (number) - Vertical offset from screen center
function TankAudit_SetPosition(x, y)
    -- Update Database
    TankAuditDB.x = x
    TankAuditDB.y = y
    
    -- Move the Invisible Anchor
    local anchor = getglobal("TankAudit_Anchor")
    if anchor then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end

    -- Update Config Inputs (if window is open)
    if TankAudit_InputX then TankAudit_InputX:SetNumber(x) end
    if TankAudit_InputY then TankAudit_InputY:SetNumber(y) end
end

-- Default Stubs
function TankAudit_SetCombatState(inCombat) end

-- =============================================================
-- CONFIGURATION UI HANDLER
-- =============================================================
function TankAudit_Config_OnShow(frame)
    -- Safety: If frame wasn't passed, try global, otherwise stop
    if not frame then frame = getglobal("TankAudit_ConfigFrame") end
    if not frame then return end

    -- 1. Sync Checkbox States
    -- Use safe access (getglobal) to ensure objects exist
    local chkEnable = getglobal("TankAudit_CheckEnable")
    if chkEnable then chkEnable:SetChecked(TankAuditDB.enabled) end
    
    local chkFood = getglobal("TankAudit_CheckFood")
    if chkFood then chkFood:SetChecked(TankAuditDB.checkFood) end
    
    local chkBuffs = getglobal("TankAudit_CheckBuffs")
    if chkBuffs then chkBuffs:SetChecked(TankAuditDB.checkBuffs) end
    
    local chkSelf = getglobal("TankAudit_CheckSelf")
    if chkSelf then chkSelf:SetChecked(TankAuditDB.checkSelf) end
    
    local chkHS = getglobal("TankAudit_CheckHS")
    if chkHS then chkHS:SetChecked(TankAuditDB.checkHealthstone) end
    
    local sldScale = getglobal("TankAudit_ScaleSlider")
    if sldScale then
        sldScale:SetValue(TankAuditDB.scale)
        -- NEW: Force the label to update immediately on show
        getglobal(sldScale:GetName().."Text"):SetText(_strformat("Button Scale: %.1f", TankAuditDB.scale))
    end

    if TankAudit_InputX then TankAudit_InputX:SetNumber(TankAuditDB.x) end
    if TankAudit_InputY then TankAudit_InputY:SetNumber(TankAuditDB.y) end

    -- 2. Sync Priority List Text
    for i=1, 4 do
        local nameText = getglobal("TankAudit_Pri"..i.."Name")
        if nameText then
            local blessing = TankAuditDB.paladinPriority[i] or "Unknown"
            nameText:SetText(i..". "..blessing)
        end
        
        local upBtn = getglobal("TankAudit_Pri"..i.."Up")
        local downBtn = getglobal("TankAudit_Pri"..i.."Down")
        
        if upBtn then 
            if i == 1 then upBtn:Disable() else upBtn:Enable() end
        end
        if downBtn then
            if i == 4 then downBtn:Disable() else downBtn:Enable() end
        end
    end

    -- 3. Header Fix
    local headerTexture = getglobal("TankAudit_ConfigFrameHeader")
    local titleText = getglobal("TankAudit_ConfigFrameTitle")
    
    if headerTexture then
        headerTexture:ClearAllPoints()
        headerTexture:SetPoint("TOP", frame, "TOP", 0, 12)
    end
    if titleText and headerTexture then
        titleText:ClearAllPoints()
        titleText:SetPoint("TOP", headerTexture, "TOP", 0, -14)
    end

    -- 4. LAYOUT
    local startY = -40
    
    local divGeneral = getglobal("TankAudit_Div_General")
    if divGeneral then
        divGeneral:ClearAllPoints()
        divGeneral:SetPoint("TOP", frame, "TOP", 0, startY)
    end
    
    if chkEnable then
        chkEnable:ClearAllPoints()
        chkEnable:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, startY - 20)
    end
    
    local filterY = startY - 60
    local divFilters = getglobal("TankAudit_Div_Filters")
    if divFilters then
        divFilters:ClearAllPoints()
        divFilters:SetPoint("TOP", frame, "TOP", 0, filterY)
    end
    
    if chkFood then
        chkFood:ClearAllPoints()
        chkFood:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, filterY - 20)
    end
    if chkBuffs then
        chkBuffs:ClearAllPoints()
        chkBuffs:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, filterY - 50)
    end
    if chkSelf then
        chkSelf:ClearAllPoints()
        chkSelf:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, filterY - 80)
    end
    if chkHS then
        chkHS:ClearAllPoints()
        chkHS:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, filterY - 110)
    end

    local paladinY = filterY - 150
    local divPaladin = getglobal("TankAudit_Div_Paladin")
    if divPaladin then
        divPaladin:ClearAllPoints()
        divPaladin:SetPoint("TOP", frame, "TOP", 0, paladinY)
    end
    
    for i=1, 4 do
        local row = getglobal("TankAudit_Pri"..i)
        if row then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, paladinY - 20 - ((i-1)*20))
        end
    end

    local visualY = paladinY - 120
    local divVisuals = getglobal("TankAudit_Div_Visuals")
    if divVisuals then
        divVisuals:ClearAllPoints()
        divVisuals:SetPoint("TOP", frame, "TOP", 0, visualY)
    end
    
    if sldScale then
        sldScale:ClearAllPoints()
        sldScale:SetPoint("TOP", frame, "TOP", 0, visualY - 30)
    end

    TankAudit_UpdateUI()
end