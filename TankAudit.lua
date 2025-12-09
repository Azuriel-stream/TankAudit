-- TankAudit.lua

-- 1. Constants & Variables
local TA_VERSION = "1.0.0"
local TA_PLAYER_CLASS = nil
local TA_IS_TANK = false
-- State Variables
local TA_ROSTER_CLASSES = {} -- Stores classes present in group: { ["PRIEST"] = true, ["DRUID"] = true }
local TA_MISSING_BUFFS = {}  -- Stores result of scan
local TA_EXPIRING_BUFFS = {} -- Stores result of scan
local TA_SCAN_QUEUED = false  -- NEW: Track if a scan is waiting
-- UI Variables
local TA_BUTTON_POOL = {}
local TA_MAX_BUTTONS = 10
local TA_BUTTON_SIZE = 30
local TA_BUTTON_SPACING = 2
local TA_FRAME_ANCHOR = "CENTER" -- Default position
-- Timers
local timeSinceLastScan = 0
local SCAN_INTERVAL = 3      -- UPDATED: Faster checks (was 15)
local timeSinceLastHS = 0
local HS_INTERVAL = 60       -- Keep Healthstone at 60s
-- Default Settings
local TA_DEFAULTS = {
    enabled = true,
    scale = 1.0,
    checkFood = true,
    checkBuffs = true,
    checkSelf = true,
    checkHealthstone = true,
    paladinPriority = { "Blessing of Kings", "Blessing of Might", "Blessing of Light", "Blessing of Sanctuary" }
}

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

    -- Event-Driven Updates
    this:RegisterEvent("UNIT_AURA")
    this:RegisterEvent("UNIT_INVENTORY_CHANGED")
    
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
    end
end

-- 6. The Timer Loop (OnUpdate)
function TankAudit_OnUpdate(elapsed)
    if not TA_IS_TANK then 
        this:SetScript("OnUpdate", nil) 
        return 
    end

    -- 1. Process Queued Scans (The Fix for Instant Updates)
    -- This runs 1 frame after the Event fired, ensuring GetPlayerBuff is ready.
    if TA_SCAN_QUEUED then
        TankAudit_RunBuffScan()
        TA_SCAN_QUEUED = false
    end

    -- 2. Run Visual Updates (Every Frame)
    TankAudit_UpdateButtonVisuals()

    -- 3. Update Buff Scan Timer (Safety Net - Every 3s)
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
                -- Check for Warrior in MY subgroup
                if class == "WARRIOR" and subgroup == TA_ROSTER_INFO.MY_SUBGROUP then
                    TA_ROSTER_INFO.HAS_GROUP_WARRIOR = true
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
            if class == "WARRIOR" then
                TA_ROSTER_INFO.HAS_GROUP_WARRIOR = true
            end
        end
    end
end

-- B. Buff Scanner
function TankAudit_GetBuffStatus(iconList)
    local i = 0
    while i < 32 do
        local buffIndex = GetPlayerBuff(i, "HELPFUL")
        if buffIndex < 0 then break end
        
        local texture = GetPlayerBuffTexture(buffIndex)
        if texture then
            for _, validIcon in pairs(iconList) do
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

-- C. Healthstone Scanner
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

-- Helper: Check Weapon Enchants
function TankAudit_CheckWeapon()
    local hasMainHand, _, _, _, _, _ = GetWeaponEnchantInfo()
    if not hasMainHand then
        return false -- Missing
    end
    return true -- Found
end

-- D. MAIN SCAN ROUTINE
function TankAudit_RunBuffScan()
    if not TankAuditDB.enabled then 
        TankAudit_UpdateUI()
        return 
    end

    TankAudit_UpdateRoster()

    TA_MISSING_BUFFS = {}
    TA_EXPIRING_BUFFS = {}

    -- SOLO SILENCE
    local isSolo = (GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0)
    local inCombat = UnitAffectingCombat("player")
    
    if isSolo and not inCombat then
        TankAudit_UpdateUI() 
        return
    end

    -- 1. Self Buffs
    local selfBuffs = TA_DATA.CLASSES[TA_PLAYER_CLASS].SELF
    if TankAuditDB.checkSelf and selfBuffs then
        for name, iconList in pairs(selfBuffs) do
            local hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
            if not hasBuff then
                table.insert(TA_MISSING_BUFFS, name)
            elseif timeLeft > 0 and timeLeft < 30 then
                -- FIX: Store name AND time together
                table.insert(TA_EXPIRING_BUFFS, { name = name, time = timeLeft })
            end
        end
    end

    -- 2. Group Buffs
    for class, data in pairs(TA_DATA.CLASSES) do
        local classCount = TA_ROSTER_INFO.CLASSES[class] or 0
        
        if TankAuditDB.checkBuffs and classCount > 0 and data.GROUP then
            -- Paladin Priority Logic
            local validPaladinBuffs = {}
            if class == "PALADIN" then
                local priority = TankAuditDB.paladinPriority
                for p = 1, classCount do
                    if priority[p] then validPaladinBuffs[priority[p]] = true end
                end
            end

            for name, iconList in pairs(data.GROUP) do
                local shouldCheck = true
                
                -- FILTER: Paladin Priority
                if class == "PALADIN" and not validPaladinBuffs[name] then shouldCheck = false end
                
                -- FILTER: Warrior Arcane Intellect
                if name == "Arcane Intellect" and TA_PLAYER_CLASS == "WARRIOR" then shouldCheck = false end
                
                -- FILTER: Battle Shout Logic
                if name == "Battle Shout" then
                    if TA_PLAYER_CLASS == "WARRIOR" then
                        shouldCheck = false
                    elseif not TA_ROSTER_INFO.HAS_GROUP_WARRIOR then
                        shouldCheck = false
                    end
                end

                if shouldCheck then
                    local hasBuff, timeLeft = TankAudit_GetBuffStatus(iconList)
                    if not hasBuff then
                        table.insert(TA_MISSING_BUFFS, name)
                    elseif timeLeft > 0 and timeLeft < 120 then
                        -- FIX: Store name AND time together
                        table.insert(TA_EXPIRING_BUFFS, { name = name, time = timeLeft })
                    end
                end
            end
        end
    end

    -- 3. Consumables
    local suppressConsumables = (isSolo and inCombat)
    if TankAuditDB.checkFood and not suppressConsumables then
        if not TankAudit_GetBuffStatus(TA_DATA.CONSUMABLES.FOOD["Well Fed"]) then
            table.insert(TA_MISSING_BUFFS, "Well Fed")
        end
        if TA_PLAYER_CLASS ~= "DRUID" then 
            if not TankAudit_CheckWeapon() then table.insert(TA_MISSING_BUFFS, "Weapon Buff") end
        end
    end

    -- 4. Healthstone
    if TankAuditDB.checkHealthstone and not TankAudit_CheckHealthstone() then
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
                
                local timeStr = ""
                if timeLeft > 60 then
                    timeStr = math.ceil(timeLeft / 60) .. "m"
                else
                    timeStr = math.ceil(timeLeft)
                end
                
                -- Red text for < 10s, Yellow for > 10s
                if timeLeft < 10 then
                    textObj:SetText("|cFFFF0000" .. timeStr .. "|r")
                else
                    textObj:SetText("|cFFFFFF00" .. timeStr .. "|r")
                end
            end
        end
    end
end

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

function TankAudit_UpdateUI()
    -- 1. Get current scale 
    local scale = TankAuditDB.scale or 1.0
    
    -- FIX: Use BASE sizes. Do NOT pre-multiply by scale.
    -- The SetPoint function will apply the scale multiplier for us.
    local btnSize = TA_BUTTON_SIZE      -- 30
    local spacing = TA_BUTTON_SPACING   -- 5

    -- 2. Count active buttons
    local numMissing = table.getn(TA_MISSING_BUFFS)
    local numExpiring = table.getn(TA_EXPIRING_BUFFS)
    local totalActive = numMissing + numExpiring

    -- 3. Calculate the starting Left Edge (in base coordinate space)
    local currentXPosition = 0
    if totalActive > 0 then
        -- Total base width
        local totalBaseWidth = (totalActive * btnSize) + ((totalActive - 1) * spacing)
        
        -- Start at the left edge, add half a button to target the center anchor
        currentXPosition = -(totalBaseWidth / 2) + (btnSize / 2)
    end

    local usedButtons = 0
    local index = 1

    local function SetupButton(buffName, isExpiring, timeLeft)
        if index > TA_MAX_BUTTONS then return end
        
        local btn = TA_BUTTON_POOL[index]
        local iconTexture = TankAudit_GetIconForName(buffName)
        local iconObj = getglobal(btn:GetName().."Icon")
        local textObj = btn.timerText

        iconObj:SetTexture(iconTexture)
        btn.buffName = buffName
        btn.tooltipText = buffName
        
        if btn.isExpiring ~= isExpiring then
            btn.isExpiring = isExpiring
            btn.expiresAt = nil 
        end

        if isExpiring then
            iconObj:SetDesaturated(0)
            local newExpiry = GetTime() + timeLeft
            if not btn.expiresAt then btn.expiresAt = newExpiry
            elseif math.abs(newExpiry - btn.expiresAt) > 2 then btn.expiresAt = newExpiry end

            local displayTime = btn.expiresAt - GetTime()
            local timeStr = ""
            if displayTime > 60 then timeStr = math.ceil(displayTime / 60) .. "m"
            else timeStr = math.ceil(displayTime) end
            
            if displayTime < 10 then textObj:SetText("|cFFFF0000" .. timeStr .. "|r")
            else textObj:SetText("|cFFFFFF00" .. timeStr .. "|r") end
            textObj:Show()
        else
            iconObj:SetDesaturated(1)
            textObj:SetText("")
            textObj:Hide()
            btn.expiresAt = nil
        end

        -- 4. ABSOLUTE POSITIONING (Corrected)
        btn:ClearAllPoints()
        btn:SetScale(scale)
        
        -- We pass the BASE coordinates (currentXPosition). 
        -- Because the button is scaled, the game draws it at (currentXPosition * scale).
        -- We DIVIDE the Y offset by scale to keep the vertical position visually fixed on screen.
        btn:SetPoint("CENTER", UIParent, "CENTER", currentXPosition, -100/scale)
        
        -- Advance by base units
        currentXPosition = currentXPosition + btnSize + spacing

        btn:Show()
        usedButtons = usedButtons + 1
        index = index + 1
    end

    for _, buffName in pairs(TA_MISSING_BUFFS) do 
        SetupButton(buffName, false, 0) 
    end
    
    for _, buffData in pairs(TA_EXPIRING_BUFFS) do 
        SetupButton(buffData.name, true, buffData.time) 
    end 
    
    for i = usedButtons + 1, TA_MAX_BUTTONS do
        local btn = TA_BUTTON_POOL[i]
        if btn:IsVisible() then
            btn:Hide()
        end
    end
end

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
end

function TankAudit_UpdateScale()
    local scale = TankAuditDB.scale or 1.0
    for _, btn in pairs(TA_BUTTON_POOL) do
        btn:SetScale(scale)
    end
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
        getglobal(sldScale:GetName().."Text"):SetText(string.format("Button Scale: %.1f", TankAuditDB.scale))
    end

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
end