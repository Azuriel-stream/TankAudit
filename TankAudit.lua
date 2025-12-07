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

-- 2. Slash Command Registration (Must run for everyone to handle the command)
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

    -- If NOT a tank, we stop here. We do NOT register events.
    if not TA_IS_TANK then
        -- Optional: You can print a message here, or stay silent until they type /taudit
        return 
    end

    -- If we are a tank, proceed with full registration
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("PLAYER_REGEN_DISABLED") -- Enter Combat
    this:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leave Combat
    
    -- Note: We do not need to register "OnUpdate" here because it is defined in the XML.
    -- However, the OnUpdate function has a guard clause at the top to prevent CPU usage for non-tanks.

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00TankAudit|r " .. TA_VERSION .. " Loaded. Type /taudit for options.")
end

-- 4. Slash Command Handler
function TankAudit_SlashHandler(msg)
    if not TA_IS_TANK then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000TankAudit:|r Addon disabled. Your class (" .. (TA_PLAYER_CLASS or "Unknown") .. ") is not supported.")
        return
    end

    -- If tank, open config (Logic to be added later)
    if msg == "config" or msg == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00TankAudit:|r Opening Configuration... (Feature coming soon)")
        -- TankAudit_OpenConfig() -- Future function
    elseif msg == "test" then
        -- Useful for debugging later
        TankAudit_RunBuffScan()
    else
        DEFAULT_CHAT_FRAME:AddMessage("TankAudit usage: /taudit config")
    end
end

-- 5. Event Handling
function TankAudit_OnEvent(event)
    -- Double check safety, though non-tanks shouldn't receive these events anyway
    if not TA_IS_TANK then return end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Load SavedVariables or defaults
        TankAudit_InitializeDefaults()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- ENTER COMBAT
        TankAudit_SetCombatState(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- LEAVE COMBAT
        TankAudit_SetCombatState(false)
    end
end

-- 6. The Timer Loop (OnUpdate)
function TankAudit_OnUpdate(elapsed)
    -- CRITICAL OPTIMIZATION:
    -- If not a tank, return immediately. This creates a near-zero footprint.
    if not TA_IS_TANK then 
        this:SetScript("OnUpdate", nil) -- Permanently disable OnUpdate for this session to save max CPU
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
    if inCombat then
        -- Hide Request Bar?
        -- Enable Critical Alert Frame?
    else
        -- Show Request Bar?
    end
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