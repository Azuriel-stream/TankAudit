-- TankAudit.lua

-- 1. Constants & Variables
local TA_VERSION = "1.0.0"
local TA_PLAYER_CLASS = nil
local TA_IS_TANK = false
-- State Variables
local TA_ROSTER_CLASSES = {} -- Stores classes present in group: { ["PRIEST"] = true, ["DRUID"] = true }
local TA_MISSING_BUFFS = {}  -- Stores result of scan
local TA_EXPIRING_BUFFS = {} -- Stores result of scan
-- UI Variables
local TA_BUTTON_POOL = {}
local TA_MAX_BUTTONS = 10
local TA_BUTTON_SIZE = 30
local TA_BUTTON_SPACING = 2
local TA_FRAME_ANCHOR = "CENTER" -- Default position

-- Timers
local timeSinceLastScan = 0
local SCAN_INTERVAL = 15     -- 15 seconds for Buffs
local timeSinceLastHS = 0
local HS_INTERVAL = 60       -- 60 seconds for Healthstones

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
    
    -- Create the UI Button Pool
    TankAudit_CreateButtonPool()

    -- Print Loaded Message
    -- Formats the string: "[TankAudit] v1.0.0 active. Type /taudit to open settings."
    DEFAULT_CHAT_FRAME:AddMessage(string.format(TA_STRINGS.LOADED, TA_VERSION))
end

-- 4. Slash Command Handler
function TankAudit_SlashHandler(msg)
    if not TA_IS_TANK then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000TankAudit:|r Disabled for non-tanks.")
        return
    end

    if msg == "debug" then
        TankAudit_DebugBuffs()
    elseif msg == "test" then
        TankAudit_RunBuffScan()
    else
        DEFAULT_CHAT_FRAME:AddMessage("TankAudit: Type /taudit debug to list current buff paths.")
    end
end

-- 5. Event Handling
function TankAudit_OnEvent(event)
    if not TA_IS_TANK then return end

    if event == "PLAYER_ENTERING_WORLD" then
        TankAudit_InitializeDefaults()
    elseif event == "PLAYER_REGEN_DISABLED" then
        TankAudit_SetCombatState(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        TankAudit_SetCombatState(false)
    end
end

-- 6. The Timer Loop (OnUpdate)
function TankAudit_OnUpdate(elapsed)
    if not TA_IS_TANK then 
        this:SetScript("OnUpdate", nil) 
        return 
    end

    -- Update Buff Timer
    timeSinceLastScan = timeSinceLastScan + elapsed
    if timeSinceLastScan > SCAN_INTERVAL then
        TankAudit_RunBuffScan()
        timeSinceLastScan = 0
    end

    -- Update Healthstone Timer
    timeSinceLastHS = timeSinceLastHS + elapsed
    if timeSinceLastHS > HS_INTERVAL then
        TankAudit_CheckHealthstone()
        timeSinceLastHS = 0
    end
end

-- =============================================================
-- 7. LOGIC CORE
-- =============================================================

-- State Variables
local TA_ROSTER_INFO = {
    CLASSES = {},              -- Count: ["PALADIN"] = 2
    HAS_GROUP_WARLOCK = false, -- Is there a warlock in MY subgroup?
    MY_SUBGROUP = 1
}

-- A. Roster Analysis (Subgroups & Counts)
function TankAudit_UpdateRoster()
    TA_ROSTER_INFO.CLASSES = {}
    TA_ROSTER_INFO.HAS_GROUP_WARLOCK = false
    
    local numRaid = GetNumRaidMembers()
    local numParty = GetNumPartyMembers()
    
    -- Case 1: Solo
    if numRaid == 0 and numParty == 0 then
        TA_ROSTER_INFO.CLASSES[TA_PLAYER_CLASS] = 1
        return
    end

    -- Case 2: Raid
    if numRaid > 0 then
        -- 1. Find my subgroup
        for i = 1, numRaid do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name == UnitName("player") then
                TA_ROSTER_INFO.MY_SUBGROUP = subgroup
                break
            end
        end
        -- 2. Scan roster
        for i = 1, numRaid do
            local _, _, subgroup, _, _, class, _, online = GetRaidRosterInfo(i)
            if online then
                TA_ROSTER_INFO.CLASSES[class] = (TA_ROSTER_INFO.CLASSES[class] or 0) + 1
                if class == "WARLOCK" and subgroup == TA_ROSTER_INFO.MY_SUBGROUP then
                    TA_ROSTER_INFO.HAS_GROUP_WARLOCK = true
                end
            end
        end
        return
    end

    -- Case 3: Party
    TA_ROSTER_INFO.CLASSES[TA_PLAYER_CLASS] = 1
    for i = 1, numParty do
        local unit = "party"..i
        local _, class = UnitClass(unit)
        if class and UnitIsConnected(unit) then
            TA_ROSTER_INFO.CLASSES[class] = (TA_ROSTER_INFO.CLASSES[class] or 0) + 1
            if class == "WARLOCK" then
                TA_ROSTER_INFO.HAS_GROUP_WARLOCK = true -- In 5-man, everyone is same group
            end
        end
    end
end

-- B. Buff Scanner (Uses Internal Index for Accuracy)
function TankAudit_GetBuffStatus(iconList)
    local i = 0
    while i < 32 do
        local buffIndex = GetPlayerBuff(i, "HELPFUL")
        if buffIndex < 0 then break end
        
        local texture = GetPlayerBuffTexture(buffIndex)
        if texture then
            for _, validIcon in pairs(iconList) do
                -- Case-insensitive check just to be safe
                if string.find(string.lower(texture), string.lower(validIcon)) then
                    local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
                    return true, timeLeft
                end
            end
        end
        i = i + 1
    end
    return false, 0
end

-- C. Healthstone Scanner (Bag Check)
function TankAudit_CheckHealthstone()
    -- Only check if Warlock exists in raid (any group)
    if (TA_ROSTER_INFO.CLASSES["WARLOCK"] or 0) == 0 then return true end
    
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, "Healthstone") then
                return true -- Found one
            end
        end
    end
    return false -- Missing
end

-- D. MAIN SCAN ROUTINE
function TankAudit_RunBuffScan()
    TankAudit_UpdateRoster()

    TA_MISSING_BUFFS = {}
    TA_EXPIRING_BUFFS = {}

    -- 1. Self Buffs (Warn at 30s)
    local selfBuffs = TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF
    if selfBuffs then
        for name, iconList in pairs(selfBuffs) do
            local hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
            if not hasBuff then
                table.insert(TA_MISSING_BUFFS, name)
            elseif timeLeft > 0 and timeLeft < 30 then
                table.insert(TA_EXPIRING_BUFFS, name)
            end
        end
    end

    -- 2. Group Buffs (Smart Filtering)
    for class, data in pairs(TA_DATA.CLASSES) do
        local classCount = TA_ROSTER_INFO.CLASSES[class] or 0
        
        if classCount > 0 and data.GROUP then
            -- Paladin Priority Logic
            local validPaladinBuffs = {}
            if class == "PALADIN" then
                local priority = { "Blessing of Kings", "Blessing of Might", "Blessing of Light", "Blessing of Sanctuary" }
                for p = 1, classCount do
                    if priority[p] then validPaladinBuffs[priority[p]] = true end
                end
            end

            for name, iconList in pairs(data.GROUP) do
                local shouldCheck = true
                
                -- Filters
                if class == "PALADIN" and not validPaladinBuffs[name] then shouldCheck = false end
                if name == "Blood Pact" and not TA_ROSTER_INFO.HAS_GROUP_WARLOCK then shouldCheck = false end
                if name == "Arcane Intellect" and TA_PLAYER_CLASS == "WARRIOR" then shouldCheck = false end

                if shouldCheck then
                    local hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
                    if not hasBuff then
                        table.insert(TA_MISSING_BUFFS, name)
                    elseif timeLeft > 0 and timeLeft < 120 then
                        table.insert(TA_EXPIRING_BUFFS, name)
                    end
                end
            end
        end
    end

    -- 3. Consumables
    if not TankAudit_GetBuffStatus(TA_DATA.CONSUMABLES.FOOD["Well Fed"]) then
        table.insert(TA_MISSING_BUFFS, "Well Fed")
    end
    
    if TA_PLAYER_CLASS ~= "DRUID" then 
        if not TankAudit_CheckWeapon() then table.insert(TA_MISSING_BUFFS, "Weapon Buff") end
    end

    -- 4. Healthstone
    if not TankAudit_CheckHealthstone() then
        table.insert(TA_MISSING_BUFFS, "Healthstone")
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
        btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        tinsert(TA_BUTTON_POOL, btn)
    end
end

function TankAudit_UpdateUI()
    for _, btn in pairs(TA_BUTTON_POOL) do btn:Hide() end
    local index = 1

    local function SetupButton(buffName, isExpiring, timeLeft)
        if index > TA_MAX_BUTTONS then return end
        local btn = TA_BUTTON_POOL[index]
        local iconTexture = TankAudit_GetIconForName(buffName)
        local iconObj = getglobal(btn:GetName().."Icon")
        local textObj = getglobal(btn:GetName().."Text")

        iconObj:SetTexture(iconTexture)
        if isExpiring then
            iconObj:SetDesaturated(0)
            local mins = math.floor(timeLeft / 60)
            if mins < 1 then mins = "<1" end
            textObj:SetText("|cFFFFFF00" .. mins .. "m|r")
        else
            iconObj:SetDesaturated(1)
            textObj:SetText("")
        end

        btn:ClearAllPoints()
        if index == 1 then
            btn:SetPoint("CENTER", UIParent, "CENTER", -100, -100)
        else
            btn:SetPoint("LEFT", TA_BUTTON_POOL[index-1], "RIGHT", TA_BUTTON_SPACING, 0)
        end

        btn.buffName = buffName
        btn.tooltipText = buffName
        btn.isExpiring = isExpiring
        btn:Show()
        index = index + 1
    end

    for _, buffName in pairs(TA_MISSING_BUFFS) do SetupButton(buffName, false, 0) end
    for _, buffName in pairs(TA_EXPIRING_BUFFS) do SetupButton(buffName, true, 60) end -- Placeholder time, works for visuals
end

function TankAudit_GetIconForName(buffName)
    -- Lookups
    for class, data in pairs(TA_DATA.CLASSES) do
        if data.SELF and data.SELF[buffName] then return "Interface\\Icons\\" .. data.SELF[buffName][1] end
        if data.GROUP and data.GROUP[buffName] then return "Interface\\Icons\\" .. data.GROUP[buffName][1] end
    end
    if TA_DATA.CONSUMABLES.FOOD[buffName] then return "Interface\\Icons\\" .. TA_DATA.CONSUMABLES.FOOD[buffName][1] end
    if buffName == "Healthstone" then return "Interface\\Icons\\" .. TA_DATA.CONSUMABLES.HEALTHSTONE["Healthstone"][1] end
    if buffName == "Weapon Buff" then return "Interface\\Icons\\INV_Stone_SharpeningStone_01" end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function TankAudit_RequestButton_OnClick(btn)
    local buffName = btn.buffName
    if not buffName then return end

    -- SILENCE LOCAL BUFFS
    if buffName == "Well Fed" then
        DEFAULT_CHAT_FRAME:AddMessage(TA_STRINGS.MSG_LOCAL_FOOD)
        return
    elseif buffName == "Weapon Buff" then
        DEFAULT_CHAT_FRAME:AddMessage(TA_STRINGS.MSG_LOCAL_WEAPON)
        return
    elseif TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF and TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF[buffName] then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Audit]|r Cast " .. buffName .. "!")
        return
    end

    -- THROTTLE
    if btn.lastClick and (GetTime() - btn.lastClick) < 5 then
        DEFAULT_CHAT_FRAME:AddMessage(TA_STRINGS.MSG_WAIT_THROTTLE)
        return
    end
    btn.lastClick = GetTime()

    -- CHANNEL
    local channel = "SAY"
    if GetNumRaidMembers() > 0 then channel = "RAID"
    elseif GetNumPartyMembers() > 0 then channel = "PARTY"
    end

    -- RP MESSAGE SELECTION
    local msg = ""
    if btn.isExpiring then
        local timeText = getglobal(btn:GetName().."Text"):GetText() or "soon"
        msg = string.format(TA_STRINGS.MSG_BUFF_EXPIRING, buffName, timeText)
    else
        if TA_RP_MESSAGES[buffName] then
            local options = TA_RP_MESSAGES[buffName]
            local choice = math.random(1, table.getn(options))
            msg = options[choice]
        else
            msg = string.format(TA_STRINGS.MSG_NEED_BUFF, buffName)
        end
    end
    SendChatMessage(msg, channel)
end

function TankAudit_DebugBuffs()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[Audit] Current Buffs:|r")
    local i = 0
    while i < 32 do
        local buffIndex = GetPlayerBuff(i, "HELPFUL")
        if buffIndex < 0 then break end
        local texture = GetPlayerBuffTexture(buffIndex)
        if texture then DEFAULT_CHAT_FRAME:AddMessage(i .. ": " .. texture) end
        i = i + 1
    end
end

-- Default Stubs
function TankAudit_InitializeDefaults() end
function TankAudit_SetCombatState(inCombat) end