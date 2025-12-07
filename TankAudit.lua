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
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000TankAudit:|r Addon disabled. Your class (" .. (TA_PLAYER_CLASS or "Unknown") .. ") is not supported.")
        return
    end

    if msg == "config" or msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[TankAudit]|r Configuration coming soon.")
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

-- 7. Logic Core

-- Helper: Check who is in the party/raid so we know what buffs to expect
function TankAudit_UpdateRoster()
    TA_ROSTER_CLASSES = {} -- Reset
    
    -- If not in group, we only care about ourselves
    if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
        TA_ROSTER_CLASSES[TA_PLAYER_CLASS] = true
        return
    end

    -- Scan Party/Raid
    local numMembers = GetNumRaidMembers()
    local prefix = "raid"
    if numMembers == 0 then
        numMembers = GetNumPartyMembers()
        prefix = "party"
        -- Don't forget player in a 5-man group (party1..4 doesn't include player)
        TA_ROSTER_CLASSES[TA_PLAYER_CLASS] = true
    end

    for i = 1, numMembers do
        local unit = prefix .. i
        local _, class = UnitClass(unit)
        if class then
            TA_ROSTER_CLASSES[class] = true
        end
    end
end

-- Helper: Check if player has ANY icon from a provided list
-- Returns: boolean (found), number (time left in seconds)
function TankAudit_GetBuffStatus(iconList)
    -- We scan through all buffs on the player ONCE to be efficient
    local i = 1
    while true do
        local icon, stacks = UnitBuff("player", i)
        if not icon then break end -- End of buffs

        -- Compare this buff icon against our list of valid icons
        for _, validIcon in pairs(iconList) do
            if string.find(icon, validIcon) then
                -- Found a match!
                local buffIndex = GetPlayerBuff(i - 1, "HELPFUL")
                local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
                return true, timeLeft
            end
        end
        i = i + 1
    end
    return false, 0
end

-- Helper: Check Weapon Enchants (Stones/Oils)
function TankAudit_CheckWeapon()
    -- GetWeaponEnchantInfo returns: hasMainHand, mainHandTime, mainHandCharges, hasOffHand...
    local hasMainHand, _, _, _, _, _ = GetWeaponEnchantInfo()
    if not hasMainHand then
        return false -- Missing
    end
    return true -- Found
end

-- Helper to fetch icon texture from Data.lua
function TankAudit_GetIconForName(buffName)
    -- 1. Check Class Buffs
    for class, data in pairs(TA_DATA.CLASSES) do
        -- Check Self
        if data.SELF and data.SELF[buffName] then return "Interface\\Icons\\" .. data.SELF[buffName][1] end
        -- Check Group
        if data.GROUP and data.GROUP[buffName] then return "Interface\\Icons\\" .. data.GROUP[buffName][1] end
    end
    
    -- 2. Check Consumables
    if TA_DATA.CONSUMABLES.FOOD[buffName] then return "Interface\\Icons\\" .. TA_DATA.CONSUMABLES.FOOD[buffName][1] end
    
    -- 3. Check Weapon (Hardcoded icon for now)
    if buffName == "Weapon Buff" then return "Interface\\Icons\\INV_Stone_SharpeningStone_01" end

    return "Interface\\Icons\\INV_Misc_QuestionMark" -- Fallback
end

-- MAIN SCAN FUNCTION
function TankAudit_RunBuffScan()
    TankAudit_UpdateRoster()

    TA_MISSING_BUFFS = {}
    TA_EXPIRING_BUFFS = {}

    -- A. Check Self Buffs
    local selfBuffs = TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF
    if selfBuffs then
        for name, iconList in pairs(selfBuffs) do
            local hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
            if not hasBuff then
                table.insert(TA_MISSING_BUFFS, name)
            end
        end
    end

    -- B. Check Group Buffs
    for class, data in pairs(TA_DATA.CLASSES) do
        if TA_ROSTER_CLASSES[class] and data.GROUP then
            for name, iconList in pairs(data.GROUP) do
                local hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
                if not hasBuff then
                    table.insert(TA_MISSING_BUFFS, name)
                end
            end
        end
    end

    -- C. Check Consumables (Always check Food + Weapon)
    -- 1. Food
    local hasFood = TankAudit_GetBuffStatus(TA_DATA.CONSUMABLES.FOOD["Well Fed"])
    if not hasFood then
        table.insert(TA_MISSING_BUFFS, "Well Fed")
    end

    -- 2. Weapon Enchant (Skip for Druids as they don't use stones in form usually, or check config later)
    if TA_PLAYER_CLASS ~= "DRUID" then 
        if not TankAudit_CheckWeapon() then
            table.insert(TA_MISSING_BUFFS, "Weapon Buff")
        end
    end

    if table.getn(TA_MISSING_BUFFS) > 0 then
        -- Update the visual UI
        TankAudit_UpdateUI()
    end
end

function TankAudit_CreateButtonPool()
    for i = 1, TA_MAX_BUTTONS do
        -- Create a button using the XML template "TankAudit_RequestBtnTemplate"
        local btn = CreateFrame("Button", "TankAudit_Btn_"..i, UIParent, "TankAudit_RequestBtnTemplate")
        
        -- Set base properties
        btn:SetWidth(TA_BUTTON_SIZE)
        btn:SetHeight(TA_BUTTON_SIZE)
        btn:SetID(i) -- Remember its index
        
        -- Default Position (We will move them dynamically later)
        btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        
        -- Store in our pool
        tinsert(TA_BUTTON_POOL, btn)
    end
end

function TankAudit_UpdateUI()
    -- 1. Hide all buttons first (Reset state)
    for _, btn in pairs(TA_BUTTON_POOL) do
        btn:Hide()
    end

    -- 2. Loop through the missing buffs list
    local index = 1
    for _, buffName in pairs(TA_MISSING_BUFFS) do
        if index > TA_MAX_BUTTONS then break end -- Safety cap

        local btn = TA_BUTTON_POOL[index]
        
        -- A. Find the Icon for this buff name
        local iconTexture = TankAudit_GetIconForName(buffName)
        
        -- B. Set the Icon
        getglobal(btn:GetName().."Icon"):SetTexture(iconTexture)
        
        -- C. Position the button (Horizontal Row)
        btn:ClearAllPoints()
        if index == 1 then
            -- First button anchors to the center
            btn:SetPoint("CENTER", UIParent, "CENTER", -100, -100) 
        else
            -- Subsequent buttons anchor to the right of the previous one
            btn:SetPoint("LEFT", TA_BUTTON_POOL[index-1], "RIGHT", TA_BUTTON_SPACING, 0)
        end

        -- D. Store Data for Click and Tooltip
        btn.buffName = buffName
        btn.tooltipText = buffName -- <--- THIS IS THE FIX
        
        -- E. Show it
        btn:Show()
        
        index = index + 1
    end
end

-- Stubs for future steps
function TankAudit_InitializeDefaults() end
function TankAudit_SetCombatState(inCombat) end
function TankAudit_CheckHealthstone() end
function TankAudit_RequestButton_OnClick(btn)
    local buffName = btn.buffName
    if not buffName then return end

    -- Chat Throttle: Don't spam
    if btn.lastClick and (GetTime() - btn.lastClick) < 5 then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Audit]|r Wait before asking again.")
        return
    end
    btn.lastClick = GetTime()

    -- Determine Channel (Party or Raid)
    local channel = "SAY" -- Default for solo
    if GetNumRaidMembers() > 0 then channel = "RAID"
    elseif GetNumPartyMembers() > 0 then channel = "PARTY"
    end

    -- Send Message
    local msg = string.format(TA_STRINGS.MSG_NEED_BUFF, buffName)
    SendChatMessage(msg, channel)
end