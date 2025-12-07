-- TankAudit.lua

-- 1. Constants & Variables
local TA_VERSION = "1.0.0"
local TA_PLAYER_CLASS = nil
local TA_IS_TANK = false

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

-- 7. Logic Stubs
function TankAudit_InitializeDefaults()
    -- Set DB values if nil
end

function TankAudit_SetCombatState(inCombat)
    -- Combat toggle logic
end

function TankAudit_RunBuffScan()
    -- Main logic loop
end

function TankAudit_CheckHealthstone()
    -- Bag scanning logic
end

function TankAudit_RequestButton_OnClick(btn)
    -- Chat logic
end