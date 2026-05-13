-- PC-Control.lua - ProChat IA v1.0 - 3.3.5
-- Cola LFG / Auto-LFG: AutoLFGUpdate, LeaveQueue, QueueForDungeons
-- Migrado desde PC-Core.lua
-- Por Elreyflahs

ProChat = ProChat or {}
ProChat.Core = ProChat.Core or {}

-- Aliases locales (mismos que Core para consistencia)
local Data   = ProChat.Data
local Utils  = ProChat.Utils
local L      = ProChat.L
local UI     = ProChat.UI
local Frames = ProChat.Frames

-- ===== CODIFICACIÓN DE GS =====
-- Duplicada aquí para que Control sea autónomo sin depender del orden de carga de Core.
local GS_ENCODE = {
    ["0"]="HH", ["1"]="A0", ["2"]="ZW", ["3"]="KQ",
    ["4"]="6J", ["5"]="PF", ["6"]="E0", ["7"]="IG",
    ["8"]="C8", ["9"]="4T",
}

local function EncodeGS(gs)
    local s = tostring(gs or 0)
    local result = ""
    for i = 1, #s do
        result = result .. (GS_ENCODE[s:sub(i,i)] or "HH")
    end
    return result
end

-- Códigos de dificultad para SR e ICC en el comentario del buscador
local DIFF_CODES = {
    ["SR"]      = "KS",   ["ICC"]     = "6H",
    ["SR_10N"]  = "D4",   ["SR_10H"]  = "3V",
    ["SR_25N"]  = "621",  ["SR_25H"]  = "YF",
    ["ICC_10N"] = "9Q8",  ["ICC_10H"] = "XC1",
    ["ICC_25N"] = "33A",  ["ICC_25H"] = "1W",
}

-- ===== AUTO-LFG UPDATE =====
-- Re-apuntarse cuando cambia función o mazmorras seleccionadas.
function ProChat.Core:AutoLFGUpdate()
    if not ProChat.Data.autoLFGActive then return end
    LeaveLFG()
    ProChat.Data.isQueued = false
    local f = CreateFrame("Frame")
    f.t = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        if self.t >= 0.5 then
            self:SetScript("OnUpdate", nil)
            ProChat.Core:QueueForDungeons()
        end
    end)
end

-- ===== LEAVE QUEUE =====
function ProChat.Core:LeaveQueue()
    LeaveLFG()
    ProChat.Data.isQueued      = false
    ProChat.Data.autoLFGActive = false
    if UI.autoLFGSwitch then UI.autoLFGSwitch:SetChecked(false) end
    if UI.autoLFGEye    then UI.autoLFGEye:UpdateState(false)   end
    if ProChat.Frames.minimap and ProChat.Frames.minimap.UpdateQueueState then
        ProChat.Frames.minimap:UpdateQueueState(false)
    end
    if MiniMapLFGFrame then MiniMapLFGFrame:Show() end
    local chatWin = Frames.chatWin
    if chatWin and chatWin._minEyeBtn then
        if chatWin._minEyeBtn.anim then chatWin._minEyeBtn.anim:Stop() end
        chatWin._minEyeBtn:Hide()
    end
    if chatWin and chatWin._minEyeIcon and chatWin._minEyeIcon ~= chatWin._minEyeBtn then
        chatWin._minEyeIcon:Hide()
    end
    print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " ..
        (L["LEAVE_QUEUE_MSG"] or "Te has quitado de la cola."))
end

-- ===== QUEUE FOR DUNGEONS =====
function ProChat.Core:QueueForDungeons()
    local hasRole = false
    for _ in pairs(ProChat.Data.selectedRoles) do hasRole = true; break end
    if not hasRole then
        print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " ..
            (L["NO_ROLE_SELECTED"] or "Debes seleccionar al menos un rol."))
        if UI.autoLFGSwitch then UI.autoLFGSwitch:SetChecked(false) end
        ProChat.Data.autoLFGActive = false
        return
    end

    local function getIDForDiff(dData, diff)
        if dData[diff] then return dData[diff] end
        if diff == "10N" or diff == "10H" then return dData["10"] end
        if diff == "25N" or diff == "25H" then return dData["25"] end
        return nil
    end

    local dungeonsToQueue = {}
    local addedIDs        = {}
    local srCodes         = ""
    local iccCodes        = ""

    local SPECIAL_CODES = {
        ["FOSO"]     = "I61Q",
        ["SEMANAL"]  = "CP",
        ["VIAJEROS"] = "JJ2",
    }
    local ONY10_CODE = "2TZ"
    local ONY10_ID   = 46

    local specialCodes = {}
    local needsONY10   = false

    local keysToCheck = {}
    if ProChat.Data.selectedDungeons["TODAS"] then
        for _, key in ipairs(ProChat.Data.keywords) do
            table.insert(keysToCheck, key)
        end
    else
        for _, key in ipairs(ProChat.Data.keywords) do
            if ProChat.Data.selectedDungeons[key] then
                table.insert(keysToCheck, key)
            end
        end
    end

    for _, key in ipairs(keysToCheck) do
        if SPECIAL_CODES[key] then
            table.insert(specialCodes, SPECIAL_CODES[key])
            needsONY10 = true
        else
            local dData = ProChat.Data.dungeonIDs[key]
            if dData then
                local diffs = ProChat.Data.selectedDifficulties[key]
                if diffs then
                    for diff, enabled in pairs(diffs) do
                        if enabled then
                            local id = getIDForDiff(dData, diff)
                            if id and not addedIDs[id] then
                                addedIDs[id] = true
                                table.insert(dungeonsToQueue, {id=id, key=key, diff=diff})
                            end
                            if key == "SR" then
                                local code = DIFF_CODES["SR_"..diff]
                                if code then srCodes = srCodes .. code end
                            elseif key == "ICC" then
                                local code = DIFF_CODES["ICC_"..diff]
                                if code then iccCodes = iccCodes .. code end
                            end
                        end
                    end
                end
            end
        end
    end

    if needsONY10 and not addedIDs[ONY10_ID] then
        addedIDs[ONY10_ID] = true
        table.insert(dungeonsToQueue, {id=ONY10_ID, key="ONY", diff="10"})
        table.insert(specialCodes, 1, ONY10_CODE)
    end

    if #dungeonsToQueue == 0 and #specialCodes == 0 then
        print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " ..
            (L["NO_DUNGEONS_SELECTED"] or "No hay mazmorras seleccionadas."))
        if UI.autoLFGSwitch then UI.autoLFGSwitch:SetChecked(false) end
        ProChat.Data.autoLFGActive = false
        return
    end

    -- Construir comentario
    local gs         = ProChat.Core:GetGearScore()
    local playerName = UnitName("player")
    local gsEncoded  = EncodeGS(gs)
    local signature  = ProChat.Utils:GenerateSignature(gs, playerName)

    local dungeonFragment = ""
    if srCodes  ~= "" then
        dungeonFragment = DIFF_CODES["SR"] .. srCodes
    end
    if iccCodes ~= "" then
        if dungeonFragment ~= "" then dungeonFragment = dungeonFragment .. " / " end
        dungeonFragment = dungeonFragment .. DIFF_CODES["ICC"] .. iccCodes
    end
    if #specialCodes > 0 then
        local specialFragment = table.concat(specialCodes, " ")
        if dungeonFragment ~= "" then dungeonFragment = dungeonFragment .. " / " end
        dungeonFragment = dungeonFragment .. specialFragment
    end

    local parts = {}
    if dungeonFragment ~= "" then table.insert(parts, dungeonFragment) end
    table.insert(parts, gsEncoded)
    table.insert(parts, signature)
    local comment = "[ProChat IA] " .. table.concat(parts, " / ")

    local isTank   = ProChat.Data.selectedRoles["TANK"]   and true or false
    local isHealer = ProChat.Data.selectedRoles["HEALER"] and true or false
    local isDps    = ProChat.Data.selectedRoles["DPS"]    and true or false

    SetLFGRoles(true, isTank, isHealer, isDps)
    ClearAllLFGDungeons()
    for _, dq in ipairs(dungeonsToQueue) do SetLFGDungeon(dq.id) end
    SetLFGComment(comment)

    -- Silenciar señales de Blizzard durante la cola
    ProChat.IsInternalAction = true
    JoinLFG()

    local sfxTimer = CreateFrame("Frame")
    sfxTimer.t = 0
    sfxTimer:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        if self.t >= 0.6 then
            self:SetScript("OnUpdate", nil)
            ProChat.IsInternalAction = false
        end
    end)

    ProChat.Data.isQueued = true

    if UI.autoLFGEye then UI.autoLFGEye:UpdateState(true) end
    if ProChat.Frames.minimap and ProChat.Frames.minimap.UpdateQueueState then
        ProChat.Frames.minimap:UpdateQueueState(true)
    end
    if MiniMapLFGFrame then MiniMapLFGFrame:Hide() end

    local chatWin   = Frames.chatWin
    local optVisible = UI.checkOptions and UI.checkOptions:GetChecked()
    if chatWin.roleButtons then
        for _, btn in pairs(chatWin.roleButtons) do
            if optVisible then btn:Show() else btn:Hide() end
        end
    end
    if chatWin.roleTitleLabel then
        if optVisible then chatWin.roleTitleLabel:Show()
        else               chatWin.roleTitleLabel:Hide() end
    end
    if chatWin.isMinimized and chatWin._minEyeBtn then
        chatWin._minEyeBtn:Show()
        if chatWin._minEyeBtn.anim then chatWin._minEyeBtn.anim:Play() end
    end
end
