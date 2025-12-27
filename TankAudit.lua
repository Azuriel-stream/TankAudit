-- TankAudit.lua

-- 1. Constants & Variables
local TA_VERSION = "1.4.0 (AURA-DEBUG)" 
local TA_PLAYER_CLASS = nil
local TA_IS_TANK = false

-- State Variables
-- UPDATED: Now stores names per class for "Thank You" deduction
local TA_ROSTER_INFO = {
    CLASSES = {},              
    NAMES = {},                -- New: { ["PALADIN"] = {"Bob", "Alice"} }
    HAS_GROUP_WARRIOR = false, 
    MY_SUBGROUP = 1
}

local TA_MISSING_BUFFS = {}  
local TA_EXPIRING_BUFFS = {} 
local TA_SCAN_QUEUED = false  
local TA_KNOWN_SPELLS = {}
local TA_HAS_PROT_PALADIN = false
local TA_ACTIVE_DEBUFFS = {} 
-- UI Variables
local TA_BUTTON_POOL = {}
local TA_MAX_BUTTONS = 16
local TA_BUTTON_SIZE = 30
local TA_BUTTON_SPACING = 2
local TA_FRAME_ANCHOR = "CENTER" 
local TA_TooltipScanner = nil

-- NEW: Request Tracking (For Thank You messages)
local TA_LAST_REQUEST = {
    buffName = nil,
    timestamp = 0
}

-- Timers
local timeSinceLastScan = 0
local SCAN_INTERVAL = 3      
local timeSinceLastHS = 0
local HS_INTERVAL = 60       

-- Thresholds & Limits
local MAX_BUFF_SLOTS = 32                
local BUFF_WARNING_SELF = 15             
local BUFF_WARNING_GROUP = 60            
local REQUEST_THROTTLE = 5               
local TIMER_WARNING_THRESHOLD = 10       
local MAIN_HAND_SLOT = 16                

-- Default Settings
local TA_DEFAULTS = {
    enabled = true,
    scale = 1.0,
    x = 0,      
    y = -100,   
    checkFood = true,
    checkBuffs = true,
    checkSelf = true,
    checkHealthstone = true,
    paladinPriority = { "Blessing of Kings", "Blessing of Might", "Blessing of Light", "Blessing of Sanctuary" }
}

-- Fallback Generic Messages (Local definition to avoid editing Localization.lua again)
local TA_MSG_GENERIC_THANKS = {
    "Thanks for the %s!",
    "Got the %s, thanks!",
    "Much appreciated, %s received."
}

-- ================================================================
-- LOCALIZE GLOBAL FUNCTIONS
-- ================================================================
local _strfind = string.find
local _strlower = string.lower
local _strformat = string.format
local _gsub = string.gsub
local _tinsert = table.insert
local _tgetn = table.getn
local _mathceil = math.ceil
local _mathabs = math.abs
local _mathrandom = math.random
local _mathfloor = math.floor 

-- ================================================================
-- HELPER FUNCTIONS
-- ================================================================

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
    local _, class = UnitClass("player")
    TA_PLAYER_CLASS = class

    if class == "WARRIOR" or class == "DRUID" or class == "PALADIN" or class == "SHAMAN" then
        TA_IS_TANK = true
    else
        TA_IS_TANK = false
    end

    if not TA_IS_TANK then return end

    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("PLAYER_REGEN_DISABLED")
    this:RegisterEvent("PLAYER_REGEN_ENABLED")
    this:RegisterEvent("LEARNED_SPELL_IN_TAB")

    this:RegisterEvent("UNIT_AURA")
    this:RegisterEvent("UNIT_INVENTORY_CHANGED")
    this:RegisterEvent("PLAYER_TARGET_CHANGED")

    -- Removed the unreliable CHAT_MSG events
    
    TankAudit_CreateButtonPool()

    DEFAULT_CHAT_FRAME:AddMessage(_strformat(TA_STRINGS.LOADED, TA_VERSION))
end

-- 4. Slash Command Handler
function TankAudit_SlashHandler(msg)
    if not TA_IS_TANK then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000TankAudit:|r Disabled for non-tanks.")
        return
    end

    if msg == "config" or msg == "" then
        TankAudit_ConfigFrame:Show() 
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
        TA_SCAN_QUEUED = true
        
    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            -- 1. Queue visual update
            TA_SCAN_QUEUED = true
            
            -- 2. Check Gratitude immediately (Reliable "Gain" detection)
            TankAudit_CheckGratitude_BuffGain()
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then TA_SCAN_QUEUED = true end
    
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

    if TA_SCAN_QUEUED then
        TankAudit_RunBuffScan()
        TA_SCAN_QUEUED = false
        timeSinceLastScan = 0 
    end

    TankAudit_UpdateButtonVisuals()

    timeSinceLastScan = timeSinceLastScan + elapsed
    if timeSinceLastScan > SCAN_INTERVAL then
        TankAudit_RunBuffScan()
        timeSinceLastScan = 0
    end

    timeSinceLastHS = timeSinceLastHS + elapsed
    if timeSinceLastHS > HS_INTERVAL then
        TankAudit_CheckHealthstone()
        timeSinceLastHS = 0
    end
end

-- =============================================================
-- 7. LOGIC CORE
-- =============================================================

-- A. Roster Analysis
-- UPDATED: Now tracks NAMES of classes to help identify who buffed us
function TankAudit_UpdateRoster()
    TA_ROSTER_INFO.CLASSES = {}
    TA_ROSTER_INFO.NAMES = {} -- Clear names
    TA_ROSTER_INFO.HAS_GROUP_WARRIOR = false
    TA_ROSTER_INFO.HAS_GROUP_PALADIN = false 
    
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    
    -- Helper to add name
    local function AddToRoster(class, name)
        TA_ROSTER_INFO.CLASSES[class] = (TA_ROSTER_INFO.CLASSES[class] or 0) + 1
        if not TA_ROSTER_INFO.NAMES[class] then TA_ROSTER_INFO.NAMES[class] = {} end
        _tinsert(TA_ROSTER_INFO.NAMES[class], name)
    end

    if numRaid == 0 and numParty == 0 then
        AddToRoster(TA_PLAYER_CLASS, UnitName("player"))
        return
    end

    if numRaid > 0 then
        for i = 1, numRaid do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name == UnitName("player") then
                TA_ROSTER_INFO.MY_SUBGROUP = subgroup
                break
            end
        end
        for i = 1, numRaid do
            local name, _, subgroup, _, _, class, _, online = GetRaidRosterInfo(i)
            if online and class then
                AddToRoster(class, name)
                if subgroup == TA_ROSTER_INFO.MY_SUBGROUP then
                    if class == "WARRIOR" then TA_ROSTER_INFO.HAS_GROUP_WARRIOR = true end
                    if class == "PALADIN" then TA_ROSTER_INFO.HAS_GROUP_PALADIN = true end
                end
            end
        end
        return
    end

    AddToRoster(TA_PLAYER_CLASS, UnitName("player"))
    for i = 1, numParty do
        local unit = "party"..i
        local _, class = UnitClass(unit)
        local name = UnitName(unit)
        if class and UnitIsConnected(unit) then
            AddToRoster(class, name)
            if class == "WARRIOR" then TA_ROSTER_INFO.HAS_GROUP_WARRIOR = true end
            if class == "PALADIN" then TA_ROSTER_INFO.HAS_GROUP_PALADIN = true end
        end
    end
end

-- B. Buff Scanner
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
    if (TA_ROSTER_INFO.CLASSES["WARLOCK"] or 0) == 0 then return true end
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and _strfind(link, "Healthstone") then
                return true 
            end
        end
    end
    return false 
end

-- Helper: Check Weapon Enchants
function TankAudit_CheckWeapon()
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

-- Helper: Check cache for spell by Icon Texture
function TankAudit_HasSpell(iconList)
    if not iconList or type(iconList) ~= "table" then return false end
    for _, iconName in pairs(iconList) do
        local path = "interface\\icons\\" .. _strlower(iconName)
        if TA_KNOWN_SPELLS[path] then
            return true
        end
    end
    return false
end

-- Helper: Check Stance/Form by Icon Name
function TankAudit_CheckStance(iconName)
    local numForms = GetNumShapeshiftForms()
    for i=1, numForms do
        local texture, name, isActive = GetShapeshiftFormInfo(i)
        if isActive and texture then
            if _strfind(_strlower(texture), _strlower(iconName)) then
                return true
            end
        end
    end
    return false
end

-- Helper: Scan Weapon Tooltip for Specific Enchant Name
function TankAudit_CheckSpecificEnchant(enchantName)
    local hasMH, expMH, _, hasOH, expOH = GetWeaponEnchantInfo()
    if not hasMH then return false, 0 end

    if not TA_TooltipScanner then
        TA_TooltipScanner = CreateFrame("GameTooltip", "TA_TooltipScanner_Private", nil, "GameTooltipTemplate")
        TA_TooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    end

    TA_TooltipScanner:ClearLines()
    TA_TooltipScanner:SetInventoryItem("player", MAIN_HAND_SLOT) 

    for i=1, TA_TooltipScanner:NumLines() do
        local lineObj = getglobal("TA_TooltipScanner_PrivateTextLeft"..i)
        if lineObj then
            local text = lineObj:GetText()
            if text and _strfind(text, enchantName) then
                local timeLeft = (expMH or 0) / 1000
                return true, timeLeft
            end
        end
    end
    return false, 0
end

-- Helper: Cache Known Spells
function TankAudit_CacheSpells()
    TA_KNOWN_SPELLS = {} -- Clear cache
    local i = 1
    while true do
       local name, rank = GetSpellName(i, "spell")
       if not name then break end
       local texture = GetSpellTexture(i, "spell")
       if texture then
           TA_KNOWN_SPELLS[_strlower(texture)] = true
       end
       i = i + 1
    end
end

-- Helper: Check specific unit for Sanctuary icons
local function TA_CheckUnitForSanctuary(unit, icons)
    local i = 1
    while true do
        local texture = UnitBuff(unit, i)
        if not texture then break end
        for _, validIcon in pairs(icons) do
            if _strfind(_strlower(texture), _strlower(validIcon)) then
                return true 
            end
        end
        i = i + 1
    end
    return false
end

-- Helper: Detect if a Prot Paladin is active
function TankAudit_ScanForSanctuary()
    local icons = TA_DATA.CLASSES["PALADIN"].GROUP["Blessing of Sanctuary"]
    if not icons then return false end
    if TA_CheckUnitForSanctuary("player", icons) then return true end

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
function TankAudit_ScanDebuffs()
    TA_ACTIVE_DEBUFFS = {}
    local i = 0
    while true do
        local buffIndex = GetPlayerBuff(i, "HARMFUL")
        if buffIndex < 0 then break end
        local texture, applications, debuffType = UnitDebuff("player", i + 1)
        if debuffType and texture then
            local canDispel = false
            if TankAudit_CanUnitDispel("player", debuffType) then
                canDispel = true
            else
                local numParty = GetNumPartyMembers()
                local numRaid = GetNumRaidMembers()
                if numRaid > 0 then
                    if TA_DATA.DISPEL_RULES[debuffType] then
                        for class, _ in pairs(TA_DATA.DISPEL_RULES[debuffType]) do
                            if TA_ROSTER_INFO.CLASSES[class] and TA_ROSTER_INFO.CLASSES[class] > 0 then
                                canDispel = true
                                break
                            end
                        end
                    end
                elseif numParty > 0 then
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

-- Helper: Generate a Chat Link
function TankAudit_GetSpellLink(buffName)
    local spellID = nil
    for class, data in pairs(TA_DATA.CLASSES) do
        if data.GROUP and data.GROUP[buffName] then
            spellID = data.GROUP[buffName].id
            break
        end
    end
    if not spellID then return buffName end
    return "|cff71d5ff|Hspell:" .. spellID .. "|h[" .. buffName .. "]|h|r"
end

-- Helper: Check if a specific unit can remove a debuff
function TankAudit_CanUnitDispel(unit, debuffType)
    local _, class = UnitClass(unit)
    if not class then return false end
    local rules = TA_DATA.DISPEL_RULES[debuffType]
    if not rules or not rules[class] then return false end
    local requirement = rules[class]
    if UnitIsUnit(unit, "player") then
        local level = UnitLevel(unit)
        return level >= requirement.level
    else
        local level = UnitLevel(unit)
        if level and level > 0 then
            return level >= requirement.level
        end
        return true 
    end
end

-- Main audit routine
function TankAudit_RunBuffScan()
    if not TankAuditDB.enabled then
        TankAudit_UpdateUI()
        return
    end

    TankAudit_UpdateRoster()

    TA_MISSING_BUFFS = {}
    TA_EXPIRING_BUFFS = {}

    TankAudit_ScanDebuffs()

    local isSolo = (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0)
    local inCombat = UnitAffectingCombat("player")

    -- 1. SCAN SELF BUFFS
    local selfBuffs = TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF
    if TankAuditDB.checkSelf and selfBuffs then
        for name, iconList in pairs(selfBuffs) do
            local knowsSpell = true
            if name == "Bear Form" then
                if not TankAudit_HasSpell(iconList) then knowsSpell = false end
            elseif name == "Thorns" or name == "Righteous Fury" or name == "Lightning Shield" or name == "Battle Shout" then
                if not TankAudit_HasSpell(iconList) then knowsSpell = false end
            end
            local skipCheck = false
            if isSolo then
                if name == "Bear Form" or name == "Defensive Stance" or name == "Rockbiter Weapon" then
                    skipCheck = true
                end
            end
            if knowsSpell and not skipCheck then
                local hasBuff = false
                local timeLeft = 0
                if name == "Defensive Stance" then
                    hasBuff = TankAudit_CheckStance("Ability_Warrior_DefensiveStance")
                elseif name == "Bear Form" then
                    hasBuff = TankAudit_GetBuffStatus(iconList) or TankAudit_CheckStance("BearForm")
                elseif name == "Rockbiter Weapon" then
                    hasBuff, timeLeft = TankAudit_CheckSpecificEnchant("Rockbiter")
                else
                    hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
                end
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

    -- 2. SMART VISIBILITY FILTER
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
                        if not TA_ROSTER_INFO.HAS_GROUP_PALADIN then
                            shouldCheck = false
                        end
                    elseif name == "Blessing of Sanctuary" then
                        if not TA_HAS_PROT_PALADIN then shouldCheck = false end
                        if not validPaladinBuffs[name] then shouldCheck = false end
                    else
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
    local checkConsumables = TankAuditDB.checkFood and not isSolo
    if checkConsumables then
        local hasFood, foodTime = TankAudit_GetBuffStatus(TA_DATA.CONSUMABLES.FOOD["Well Fed"])
        if not hasFood then
            _tinsert(TA_MISSING_BUFFS, "Well Fed")
        elseif foodTime > 0 and foodTime < 60 then
            _tinsert(TA_EXPIRING_BUFFS, { name = "Well Fed", time = foodTime })
        end
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
function TankAudit_CreateButtonPool()
    for i = 1, TA_MAX_BUTTONS do
        local btn = CreateFrame("Button", "TankAudit_Btn_"..i, UIParent, "TankAudit_RequestBtnTemplate")
        btn:SetWidth(TA_BUTTON_SIZE)
        btn:SetHeight(TA_BUTTON_SIZE)
        btn:SetID(i)
        
        local textObj = getglobal(btn:GetName().."Text")
        textObj:SetWidth(50) 
        textObj:SetHeight(20)
        textObj:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        textObj:SetJustifyH("CENTER")
        textObj:SetTextColor(1, 1, 1) 
        
        btn.timerText = textObj
        btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        tinsert(TA_BUTTON_POOL, btn)
    end
end

function TankAudit_Button_OnEnter(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if btn.buffIndex and btn.buffIndex > -1 then
        GameTooltip:SetPlayerBuff(btn.buffIndex)
    else
        GameTooltip:SetText(btn.tooltipText, 1, 1, 1)
    end
    GameTooltip:Show()
end

function TankAudit_UpdateButtonVisuals()
    local currentTime = GetTime()
    for _, btn in pairs(TA_BUTTON_POOL) do
        if btn:IsVisible() and btn.expiresAt then
            local timeLeft = btn.expiresAt - currentTime
            local textObj = btn.timerText
            local iconObj = getglobal(btn:GetName().."Icon")
            if timeLeft <= 0 then
                textObj:SetText("|cFFFF00000|r") 
                iconObj:SetDesaturated(1)
            else
                iconObj:SetDesaturated(0)
                local timeStr = FormatTimeLeft(timeLeft)
                if timeLeft < TIMER_WARNING_THRESHOLD then
                    textObj:SetText("|cFFFF0000" .. timeStr .. "|r")
                else
                    textObj:SetText("|cFFFFFF00" .. timeStr .. "|r")
                end
            end
        end
    end
end

function TankAudit_MovePriority(index, direction)
    local newIndex = index + direction
    if newIndex < 1 or newIndex > 4 then return end
    local list = TankAuditDB.paladinPriority
    local temp = list[newIndex]
    list[newIndex] = list[index]
    list[index] = temp
    TankAuditDB.paladinPriority = list
    TankAudit_Config_OnShow() 
end

function TankAudit_UpdateUI()
    local scale = TankAuditDB.scale or 1.0
    local btnSize = TA_BUTTON_SIZE
    local spacing = TA_BUTTON_SPACING
    
    local renderDebuffs = TA_ACTIVE_DEBUFFS
    local renderMissing = TA_MISSING_BUFFS
    local renderExpiring = TA_EXPIRING_BUFFS
    
    local configFrame = getglobal("TankAudit_ConfigFrame")
    if configFrame and configFrame:IsVisible() then
        renderDebuffs = { { name = "Magic", texture = "Interface\\Icons\\Spell_Holy_WordFortitude", index = -1, isTest = true } }
        renderMissing = { "Test Button 1", "Test Button 2" }
        renderExpiring = {}
    end

    local usedButtons = 0
    local index = 1

    local function SetupButton(data, mode, xOffset, yOffset)
        if index > TA_MAX_BUTTONS then return end
        local btn = TA_BUTTON_POOL[index]
        btn:SetScale(scale)
        local iconObj = getglobal(btn:GetName().."Icon")
        local textObj = btn.timerText
        btn.isDebuff = false
        btn.isExpiring = false 
        btn.buffIndex = -1
        btn.expiresAt = nil
        iconObj:SetDesaturated(0)
        textObj:Hide()
        
        if mode == "DEBUFF" then
            btn.isDebuff = true
            btn.buffName = data.type or "Debuff"
            btn.buffIndex = data.index 
            btn.tooltipText = "Dispel: " .. (data.type or "Unknown")
            iconObj:SetTexture(data.texture)
            textObj:SetText("|cFFFF0000DISPEL|r") 
            textObj:Show()
            
        elseif mode == "MISSING" then
            local buffName = data
            btn.buffName = buffName
            btn.tooltipText = buffName
            iconObj:SetTexture(TankAudit_GetIconForName(buffName))
            iconObj:SetDesaturated(1) 
            
        elseif mode == "EXPIRING" then
            local buffName = data.name
            btn.buffName = buffName
            btn.isExpiring = true 
            btn.tooltipText = buffName
            iconObj:SetTexture(TankAudit_GetIconForName(buffName))
            local timeLeft = data.time
            local newExpiry = GetTime() + timeLeft
            if not btn.expiresAt then btn.expiresAt = newExpiry
            elseif _mathabs(newExpiry - btn.expiresAt) > 2 then btn.expiresAt = newExpiry end
            textObj:Show()
        end
        
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", "TankAudit_Anchor", "CENTER", xOffset, yOffset)
        btn:Show()
        usedButtons = usedButtons + 1
        index = index + 1
    end

    local numDebuffs = _tgetn(renderDebuffs)
    if numDebuffs > 0 then
        local rowWidth = (numDebuffs * btnSize) + ((numDebuffs - 1) * spacing)
        local startX = -(rowWidth / 2) + (btnSize / 2)
        local yPos = btnSize + 5 
        for _, debuff in pairs(renderDebuffs) do
            SetupButton(debuff, "DEBUFF", startX, yPos)
            startX = startX + btnSize + spacing
        end
    end

    local numMissing = _tgetn(renderMissing)
    local numExpiring = _tgetn(renderExpiring)
    local totalBuffs = numMissing + numExpiring
    if totalBuffs > 0 then
        local rowWidth = (totalBuffs * btnSize) + ((totalBuffs - 1) * spacing)
        local startX = -(rowWidth / 2) + (btnSize / 2)
        local yPos = 0 
        for _, buffName in pairs(renderMissing) do
            SetupButton(buffName, "MISSING", startX, yPos)
            startX = startX + btnSize + spacing
        end
        for _, buffData in pairs(renderExpiring) do
            SetupButton(buffData, "EXPIRING", startX, yPos)
            startX = startX + btnSize + spacing
        end
    end

    for i = usedButtons + 1, TA_MAX_BUTTONS do
        if TA_BUTTON_POOL[i] then TA_BUTTON_POOL[i]:Hide() end
    end
end

function TankAudit_GetIconForName(buffName)
    for class, data in pairs(TA_DATA.CLASSES) do
        if data.SELF and data.SELF[buffName] then return "Interface\\Icons\\" .. data.SELF[buffName][1] end
        if data.GROUP and data.GROUP[buffName] then return "Interface\\Icons\\" .. data.GROUP[buffName][1] end
    end
    if TA_DATA.CONSUMABLES.FOOD[buffName] then return "Interface\\Icons\\" .. TA_DATA.CONSUMABLES.FOOD[buffName][1] end
    if buffName == "Healthstone" then return "Interface\\Icons\\INV_Stone_04" end
    if buffName == "Weapon Buff" then return "Interface\\Icons\\INV_Stone_SharpeningStone_01" end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function TankAudit_GetDebuffName(buffIndex)
    if not buffIndex or buffIndex < 0 then return "Unknown" end
    if not TA_TooltipScanner then
        TA_TooltipScanner = CreateFrame("GameTooltip", "TA_TooltipScanner_Private", nil, "GameTooltipTemplate")
        TA_TooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    TA_TooltipScanner:ClearLines()
    TA_TooltipScanner:SetPlayerBuff(buffIndex)
    local textObj = getglobal("TA_TooltipScanner_PrivateTextLeft1")
    if textObj then return textObj:GetText() or "Unknown" end
    return "Unknown"
end

-- =============================================================
-- NEW 1.4.0 LOGIC: GRATITUDE (AURA DEDUCTION)
-- =============================================================

function TankAudit_CheckGratitude_BuffGain()
    -- 1. Do we have a pending request?
    if not TA_LAST_REQUEST.buffName then return end

    -- 2. Check Expiry (30s timeout)
    if (GetTime() - TA_LAST_REQUEST.timestamp) > 30 then
        TA_LAST_REQUEST.buffName = nil
        return
    end

    -- 3. Verify we actually HAVE the buff now
    local buffName = TA_LAST_REQUEST.buffName
    local iconList = nil

    -- Find icons for this buff name to check status
    for class, data in pairs(TA_DATA.CLASSES) do
        if data.GROUP and data.GROUP[buffName] then
            iconList = data.GROUP[buffName]
            break
        end
    end

    if not iconList then return end
    
    -- Check if active
    local hasBuff = TankAudit_GetBuffStatus(iconList)

    if hasBuff then
        -- SUCCESS! We received the buff we asked for.
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[TA Debug] Buff Received: " .. buffName .. "|r")
        
        -- 4. Deduce Provider
        -- Find which class provides this buff
        local providerClass = nil
        for class, data in pairs(TA_DATA.CLASSES) do
            if data.GROUP and data.GROUP[buffName] then
                providerClass = class
                break
            end
        end

        local providerName = nil
        
        -- If we know the class (e.g. PALADIN), check our Roster Info
        if providerClass and TA_ROSTER_INFO.NAMES[providerClass] then
            local names = TA_ROSTER_INFO.NAMES[providerClass]
            local count = _tgetn(names)
            
            if count == 1 then
                -- Precise Match: Only one person could have done it!
                providerName = names[1]
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[TA Debug] Provider identified: " .. providerName .. "|r")
            else
                -- Ambiguous: Multiple Paladins.
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[TA Debug] Multiple providers ("..count.."), using generic thanks.|r")
            end
        end
        
        TankAudit_SendThankYou(providerName, buffName)
        TA_LAST_REQUEST.buffName = nil
    end
end

function TankAudit_SendThankYou(caster, spell)
    local channel = "SAY"
    if GetNumRaidMembers() > 0 then channel = "RAID"
    elseif GetNumPartyMembers() > 0 then channel = "PARTY"
    end

    local rawMsg = ""
    local spellLink = TankAudit_GetSpellLink(spell)

    if caster then
        -- We know the name: "Thanks for the [Kings], PaladinBob!"
        local options = TA_STRINGS.MSG_THANK_YOU
        local choice = _mathrandom(1, _tgetn(options))
        rawMsg = options[choice]
        rawMsg = _strformat(rawMsg, spellLink, caster)
    else
        -- We don't know the name: "Thanks for the [Kings]!"
        local options = TA_MSG_GENERIC_THANKS
        local choice = _mathrandom(1, _tgetn(options))
        rawMsg = options[choice]
        rawMsg = _strformat(rawMsg, spellLink)
    end
    
    SendChatMessage(rawMsg, channel)
end


-- =============================================================
-- CLICK HANDLER
-- =============================================================

function TankAudit_RequestButton_OnClick(btn)
    local buffName = btn.buffName
    if not buffName then return end

    if _strfind(buffName, "Test Button") then
        local msg = _strformat("Message from %s", buffName)
        DEFAULT_CHAT_FRAME:AddMessage(msg)
        return
    end

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

    local selfBuffs = TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF
    if selfBuffs and selfBuffs[buffName] then
        if buffName == "Bear Form" or buffName == "Defensive Stance" then
             CastSpellByName(buffName)
             return
        end
        CastSpellByName(buffName, 1)
        return
    end

    if btn.lastClick and (GetTime() - btn.lastClick) < REQUEST_THROTTLE then
        DEFAULT_CHAT_FRAME:AddMessage(TA_STRINGS.MSG_WAIT_THROTTLE)
        return
    end
    btn.lastClick = GetTime()

    -- NEW: Record Request for "Thank You" tracking
    TA_LAST_REQUEST.buffName = buffName
    TA_LAST_REQUEST.timestamp = GetTime()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[TA Debug] Request Stored: " .. buffName .. "|r")

    local channel = "SAY"
    if GetNumRaidMembers() > 0 then channel = "RAID"
    elseif GetNumPartyMembers() > 0 then channel = "PARTY"
    end

    local msg = ""

    if btn.isDebuff then
        local debuffType = btn.buffName 
        local myClassRule = TA_DATA.DISPEL_RULES[debuffType] and TA_DATA.DISPEL_RULES[debuffType][TA_PLAYER_CLASS]
        if myClassRule and UnitLevel("player") >= myClassRule.level then
            CastSpellByName(myClassRule.spell, 1)
            return
        end
        local specificName = TankAudit_GetDebuffName(btn.buffIndex)
        msg = _strformat(TA_STRINGS.MSG_NEED_DISPEL, specificName, debuffType)
        
    else
        local spellLink = TankAudit_GetSpellLink(buffName)
        if TA_RP_MESSAGES[buffName] then
            local options = TA_RP_MESSAGES[buffName]
            local choice = _mathrandom(1, _tgetn(options))
            local rawMsg = options[choice]
            msg = _strformat(rawMsg, spellLink)
        else
            local fallback = TA_RP_MESSAGES["DEFAULT"][1] 
            msg = _strformat(fallback, spellLink)
        end
        if btn.isExpiring and btn.expiresAt then
             local timeLeft = btn.expiresAt - GetTime()
             if timeLeft > 0 then
                 local timeStr = FormatTimeLeft(timeLeft)
                 msg = msg .. _strformat(TA_STRINGS.MSG_EXPIRING_SUFFIX, timeStr)
             end
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

function TankAudit_InitializeDefaults()
    if not TankAuditDB then
        TankAuditDB = {}
    end
    for k, v in pairs(TA_DEFAULTS) do
        if TankAuditDB[k] == nil then
            TankAuditDB[k] = v
        end
    end
    TankAudit_UpdateScale()
    TankAudit_SetPosition(TankAuditDB.x, TankAuditDB.y)
end

function TankAudit_UpdateScale()
    local scale = TankAuditDB.scale or 1.0
    for _, btn in pairs(TA_BUTTON_POOL) do
        btn:SetScale(scale)
    end
end

function TankAudit_SetPosition(x, y)
    TankAuditDB.x = x
    TankAuditDB.y = y
    local anchor = getglobal("TankAudit_Anchor")
    if anchor then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
    if TankAudit_InputX then TankAudit_InputX:SetNumber(x) end
    if TankAudit_InputY then TankAudit_InputY:SetNumber(y) end
end

-- =============================================================
-- CONFIGURATION UI HANDLER
-- =============================================================
function TankAudit_Config_OnShow(frame)
    if not frame then frame = getglobal("TankAudit_ConfigFrame") end
    if not frame then return end
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
        getglobal(sldScale:GetName().."Text"):SetText(_strformat("Button Scale: %.1f", TankAuditDB.scale))
    end
    if TankAudit_InputX then TankAudit_InputX:SetNumber(TankAuditDB.x) end
    if TankAudit_InputY then TankAudit_InputY:SetNumber(TankAuditDB.y) end
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