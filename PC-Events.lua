-- PC-Events v1.1 - 3.3.5 - ProChat IA Module
-- Por El Rey Flahs
-- v1.1: Tooltips en cursor, menú custom, 3 columnas por rol, cebra, headers ordenables, favoritos

ProChat = ProChat or {}
ProChat.Events = {}

local Data   = ProChat.Data
local L      = ProChat.L
local UI     = ProChat.UI
local Frames = ProChat.Frames

local LFM_DIFF_CODES = {
    ["SR_10N"]  = "D4",  ["SR_10H"]  = "3V",
    ["SR_25N"]  = "621", ["SR_25H"]  = "YF",
    ["ICC_10N"] = "9Q8", ["ICC_10H"] = "XC1",
    ["ICC_25N"] = "33A", ["ICC_25H"] = "1W",
}

-- =============================================================
-- FAVORITOS: guardados en ProChatDB.lfmFavorites[name] = true
-- =============================================================
local function IsFavorite(name)
    return ProChatDB and ProChatDB.lfmFavorites and ProChatDB.lfmFavorites[name] == true
end

local function ToggleFavorite(name)
    if not ProChatDB then return end
    if not ProChatDB.lfmFavorites then ProChatDB.lfmFavorites = {} end
    if ProChatDB.lfmFavorites[name] then
        ProChatDB.lfmFavorites[name] = nil
    else
        ProChatDB.lfmFavorites[name] = true
    end
end

-- =============================================================
-- MENÚ CONTEXTUAL CUSTOM  (click izquierdo sobre jugador)
-- Se cierra automáticamente cuando el cursor lo abandona.
-- Click derecho sigue usando el menú de WoW.
-- =============================================================
local _pcMenu = nil

local function ClosePCMenu()
    if _pcMenu then _pcMenu:Hide() end
end

local function OpenPCMenu(playerData, rawX, rawY)
    local lang = (ProChatDB and ProChatDB.lang) or "es"

    -- Crear el frame una sola vez
    if not _pcMenu then
        local mf = CreateFrame("Frame", "PC_LFMContextMenu", UIParent)
        mf:SetFrameStrata("TOOLTIP")
        mf:SetFrameLevel(500)
        mf:SetWidth(110)
        mf:EnableMouse(true)
        mf:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = {left=0, right=0, top=0, bottom=0}
        })
        mf:SetBackdropColor(0, 0.05, 0.05, 0.97)
        mf:SetBackdropBorderColor(0, 1, 0.8, 0.9)
        mf:Hide()

        -- Título (nombre del jugador)
        local title = mf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT",  mf, "TOPLEFT",  8, -6)
        title:SetPoint("TOPRIGHT", mf, "TOPRIGHT", -8, -6)
        title:SetFont("Fonts\\FRIZQT__.TTF", 9)
        title:SetJustifyH("LEFT")
        title:SetTextColor(0, 1, 0.8, 1)
        mf._title = title

        -- Separador
        local sep = mf:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  mf, "TOPLEFT",  4, -18)
        sep:SetPoint("TOPRIGHT", mf, "TOPRIGHT", -4, -18)
        sep:SetTexture(0, 1, 0.8, 0.3)

        -- Definición de ítems
        local ITEMS = {
            { key="invite",  esText="Invitar",        enText="Invite"           },
            { key="whisper", esText="Susurrar",       enText="Whisper"          },
            { key="fav",     esText="|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Favorito", enText="|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Favorite"   },
        }
        mf._btns = {}

        for i, item in ipairs(ITEMS) do
            local btn = CreateFrame("Button", nil, mf)
            btn:SetHeight(20)
            btn:SetPoint("TOPLEFT",  mf, "TOPLEFT",  2, -20 - (i-1)*22)
            btn:SetPoint("TOPRIGHT", mf, "TOPRIGHT", -2, -20 - (i-1)*22)
            btn:SetFrameLevel(mf:GetFrameLevel() + 2)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(0, 0, 0, 0)
            btn._bg = bg

            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetFont("Fonts\\FRIZQT__.TTF", 9)
            fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
            fs:SetJustifyH("LEFT")
            fs:SetTextColor(1, 1, 1, 0.9)
            btn._fs      = fs
            btn._key     = item.key
            btn._esText  = item.esText
            btn._enText  = item.enText

            btn:SetScript("OnEnter", function(self)
                self._bg:SetTexture(0, 0.2, 0.2, 0.8)
            end)
            btn:SetScript("OnLeave", function(self)
                self._bg:SetTexture(0, 0, 0, 0)
            end)
            btn:SetScript("OnClick", function(self)
                local pd = mf._playerData
                if not pd then ClosePCMenu() return end
                if self._key == "invite" then
                    InviteUnit(pd.name)
                elseif self._key == "whisper" then
                    ChatFrame_OpenChat("/w "..pd.name.." ", DEFAULT_CHAT_FRAME)
                elseif self._key == "fav" then
                    ToggleFavorite(pd.name)
                    local L2 = (ProChatDB and ProChatDB.lang) or "es"
                    if IsFavorite(pd.name) then
                        self._fs:SetText(L2=="es" and "|cffffff00|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Quitar Favorito|r" or "|cffffff00|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Remove Favorite|r")
                    else
                        self._fs:SetText(L2=="es" and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Favorito" or "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Favorite")
                    end
                    ProChat.Events:RefreshLFMTable()
                end
                ClosePCMenu()
            end)

            mf._btns[i] = btn
        end

        -- Auto-cerrar al salir el cursor del menú.
        -- _graceT: tiempo de gracia para que el frame se posicione antes de comprobar.
        mf._graceT = 0
        mf:SetScript("OnUpdate", function(self, elapsed)
            if not self:IsShown() then return end
            self._graceT = self._graceT + elapsed
            if self._graceT < 0.15 then return end  -- 150ms de gracia al abrir
            local mx, my = GetCursorPosition()
            local sc     = self:GetEffectiveScale()
            -- Margen de 6px para no cerrar accidentalmente en los bordes
            local l = self:GetLeft()   * sc - 6
            local r = self:GetRight()  * sc + 6
            local b = self:GetBottom() * sc - 6
            local t = self:GetTop()    * sc + 6
            if mx < l or mx > r or my < b or my > t then
                self:Hide()
            end
        end)

        _pcMenu = mf
    end

    -- Poblar datos del jugador actual
    _pcMenu._playerData = playerData

    local classColor = (playerData.classEn and ProChat.Data.classColors[playerData.classEn]) or "ffffff"
    _pcMenu._title:SetText("|cff"..classColor..playerData.name.."|r")

    for _, btn in ipairs(_pcMenu._btns) do
        local txt = (lang=="es") and btn._esText or btn._enText
        if btn._key == "fav" then
            if IsFavorite(playerData.name) then
                txt = (lang=="es") and "|cffffff00|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Quitar Favorito|r" or "|cffffff00|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Remove Favorite|r"
            else
                txt = (lang=="es") and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Favorito" or "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Favorite"
            end
        end
        btn._fs:SetText(txt)
    end

    -- Altura total: título(18) + sep(1px ya incluida en offset) + 3 ítems × 22 + padding(6)
    _pcMenu:SetHeight(18 + 3*22 + 6)

    -- Posicionar junto al cursor con offset, ajustando para no salir de pantalla
    local cx, cy    = rawX or GetCursorPosition(), rawY or select(2, GetCursorPosition())
    local uiScale   = UIParent:GetEffectiveScale()
    local ux        = cx / uiScale + 12   -- offset horizontal del cursor
    local uy        = cy / uiScale - 4    -- offset vertical del cursor
    local mw        = _pcMenu:GetWidth()
    local mh        = _pcMenu:GetHeight()
    local sw        = GetScreenWidth()
    local sh        = GetScreenHeight() / uiScale

    if ux + mw > sw then ux = (cx / uiScale) - mw - 4 end
    if uy - mh < 0  then uy = (cy / uiScale) + mh + 4 end

    _pcMenu:ClearAllPoints()
    _pcMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ux, uy)
    _pcMenu._graceT = 0   -- reset timer de gracia
    _pcMenu:Show()
    _pcMenu:SetFrameLevel(500)
end

-- =============================================================
-- CREATE LFM DROPDOWN  (sin cambios funcionales respecto a v1.0)
-- =============================================================
function ProChat.Events:CreateLFMDropdown(parent)
    local raids = {"SR","ICC","TOC","ARCHA","ULDUAR","ONY","EOE","SO","NAXX","SEMANAL","FOSO","VIAJEROS"}
    local hasDiffMap = {}
    for k, v in pairs(ProChat.Data.dungeonDifficulties or {}) do
        if v then hasDiffMap[k] = true end
    end

    local CYAN        = {0, 0.08, 0.08, 0.97}
    local CYAN_BORDER = {0, 1, 0.8, 0.8}
    local COLOR_INACTIVE = "666666"

    local function applyBackdrop(f)
        f:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = {left=0,right=0,top=0,bottom=0}
        })
        f:SetBackdropColor(unpack(CYAN))
        f:SetBackdropBorderColor(unpack(CYAN_BORDER))
    end

    local openMenu1, openMenu2 = nil, nil
    local W = 80

    local function closeAll()
        if openMenu2 and openMenu2.Hide then openMenu2:Hide() end
        openMenu2 = nil
        if openMenu1 and openMenu1.Hide then openMenu1:Hide() end
        openMenu1 = nil
    end

    local btn = CreateFrame("Button", "PC_LFMDrop", parent)
    btn:SetSize(W, 18)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -30)
    btn:SetFrameLevel(parent:GetFrameLevel() + 3)
    applyBackdrop(btn)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btnText:SetText(ProChat.Data.lfmCurrentRaid and
        ("|cff"..(ProChat.Data.filterColors[ProChat.Data.lfmCurrentRaid] or "B0B0B0")..ProChat.Data.lfmCurrentRaid.."|r") or
        "|cffB0B0B0Seleccionar|r")

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0, 1, 0.8, 1)

    -- Sub-menú: dificultades
    local function openSubMenu(anchorRow, key)
        if openMenu2 then openMenu2:Hide() openMenu2 = nil end
        local diffs = ProChat.Data.dungeonDifficulties[key]
        if not diffs or #diffs == 0 then return end

        local _meas = UIParent:CreateFontString(nil, "ARTWORK")
        _meas:SetFont("Fonts\\FRIZQT__.TTF", 9)
        local _maxW = 0
        for _, d in ipairs(diffs) do
            _meas:SetText(d)
            local tw = _meas:GetStringWidth()
            if tw > _maxW then _maxW = tw end
        end
        _meas:SetText("")
        local menu2W = math.ceil(_maxW) + 30

        local menu2 = CreateFrame("Frame", nil, UIParent)
        menu2:SetFrameStrata("TOOLTIP")
        menu2:SetFrameLevel(360)
        applyBackdrop(menu2)
        menu2:SetWidth(menu2W)
        menu2:SetHeight(#diffs * 20 + 4)
        menu2:SetPoint("TOPLEFT", anchorRow, "TOPRIGHT", 1, 0)
        menu2:Show()
        openMenu2 = menu2

        for i, diff in ipairs(diffs) do
            local isActive = (ProChat.Data.lfmCurrentRaid == key) and (ProChat.Data.lfmCurrentSize == diff)
            local color = isActive and (ProChat.Data.filterColors[key] or "ffffff") or COLOR_INACTIVE

            local row2 = CreateFrame("Button", nil, menu2)
            row2:SetFrameLevel(menu2:GetFrameLevel() + 2)
            row2:SetSize(menu2W - 2, 20)
            row2:SetPoint("TOPLEFT", menu2, "TOPLEFT", 1, -(i-1)*20 - 2)

            local row2Bg = row2:CreateTexture(nil, "BACKGROUND")
            row2Bg:SetAllPoints()
            row2Bg:SetTexture(0, 0, 0, 0)

            local row2Text = row2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row2Text:SetPoint("LEFT", row2, "LEFT", 8, 0)
            row2Text:SetText("|cff"..color..diff.."|r")

            row2:SetScript("OnEnter", function()
                row2Bg:SetTexture(0, 0.15, 0.15, 0.8)
                local minData = ProChat.Data.minGS and ProChat.Data.minGS[key]
                local gsMin   = minData and minData[diff]
                if gsMin then
                    GameTooltip:SetOwner(row2, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(key.." "..diff, 1,1,1)
                    local r, g, b = (ProChat.Utils and ProChat.Utils.GetGSColor)
                        and ProChat.Utils:GetGSColor(gsMin) or 1,1,1
                    GameTooltip:AddLine("GS mínimo recomendado: "..gsMin, r, g, b)
                    GameTooltip:Show()
                end
            end)
            row2:SetScript("OnLeave", function()
                row2Bg:SetTexture(0, 0, 0, 0)
                GameTooltip:Hide()
            end)
            row2:SetScript("OnClick", function()
                ProChat.Data.lfmCurrentRaid = key
                ProChat.Data.lfmCurrentSize = diff
                local dungColor = ProChat.Data.filterColors[key] or "B0B0B0"
                btnText:SetText("|cff"..dungColor..key.." "..diff.."|r")
                closeAll()
                ProChat.Events:SelectLFMRaid(key, diff)
            end)
        end
        menu2:SetScript("OnHide", function() openMenu2 = nil end)
    end

    -- Menú principal: mazmorras
    local function openMainMenu()
        if openMenu1 then closeAll() return end

        local visibleRaids = {}
        for _, k in ipairs(raids) do
            if ProChat.Data:IsDungeonVisible(k) then
                table.insert(visibleRaids, k)
            end
        end

        local _meas = UIParent:CreateFontString(nil, "ARTWORK")
        _meas:SetFont("Fonts\\FRIZQT__.TTF", 9)
        local _maxW = 0
        for _, k in ipairs(visibleRaids) do
            _meas:SetText(k)
            local tw = _meas:GetStringWidth()
            if tw > _maxW then _maxW = tw end
        end
        _meas:SetText("")
        local menu1W = math.ceil(_maxW) + 30

        local menu1 = CreateFrame("Frame", nil, UIParent)
        menu1:SetFrameStrata("TOOLTIP")
        menu1:SetFrameLevel(310)
        applyBackdrop(menu1)
        menu1:SetWidth(menu1W)
        menu1:SetHeight(#visibleRaids * 20 + 4)
        menu1:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
        menu1:Show()
        openMenu1 = menu1

        for i, key in ipairs(visibleRaids) do
            local isActive  = (ProChat.Data.lfmCurrentRaid == key)
            local dungColor = ProChat.Data.filterColors[key]
            local color     = isActive and (dungColor or "ffffff") or COLOR_INACTIVE
            local hasDiff   = hasDiffMap[key]

            local row = CreateFrame("Button", nil, menu1)
            row:SetFrameLevel(menu1:GetFrameLevel() + 2)
            row:SetSize(menu1W - 2, 20)
            row:SetPoint("TOPLEFT", menu1, "TOPLEFT", 1, -(i-1)*20 - 2)

            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            rowBg:SetTexture(0, 0, 0, 0)

            local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowText:SetPoint("LEFT", row, "LEFT", 8, 0)
            rowText:SetText("|cff"..color..key.."|r")

            if hasDiff then
                local arrowTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                arrowTxt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                arrowTxt:SetText("|cff"..color..">|r")
            end

            row:SetScript("OnEnter", function()
                rowBg:SetTexture(0, 0.15, 0.15, 0.8)
                if hasDiff then
                    openSubMenu(row, key)
                else
                    if openMenu2 then openMenu2:Hide() openMenu2 = nil end
                    local minData = ProChat.Data.minGS and ProChat.Data.minGS[key]
                    if minData then
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(key, 1, 1, 1)
                        if minData.all then
                            local r, g, b = (ProChat.Utils and ProChat.Utils.GetGSColor)
                                and ProChat.Utils:GetGSColor(minData.all) or 1,1,1
                            GameTooltip:AddLine("GS mínimo recomendado: "..minData.all, r, g, b)
                        else
                            GameTooltip:AddLine("GS mínimo: Variado", 1, 1, 0.6)
                        end
                        GameTooltip:Show()
                    end
                end
            end)
            row:SetScript("OnLeave", function()
                rowBg:SetTexture(0, 0, 0, 0)
                if not hasDiff then GameTooltip:Hide() end
            end)
            row:SetScript("OnClick", function()
                if not hasDiff then
                    ProChat.Data.lfmCurrentRaid = key
                    ProChat.Data.lfmCurrentSize = nil
                    local dc = ProChat.Data.filterColors[key] or "B0B0B0"
                    btnText:SetText("|cff"..dc..key.."|r")
                    closeAll()
                    ProChat.Events:SelectLFMRaid(key, nil)
                end
            end)
        end
        menu1:SetScript("OnHide", function() openMenu1 = nil end)
    end

    btn:SetScript("OnClick", function()
        if openMenu1 then closeAll() else openMainMenu() end
    end)

    btn:Hide()
    btn._btnText        = btnText
    ProChat.UI.lfmDrop      = btn
    ProChat.UI.lfmDropText   = btnText
    return btn
end

-- =============================================================
-- SELECT LFM RAID
-- =============================================================
local SPECIAL_LFM_IDS = {
    ["FOSO"]     = { searchID = 46, code = "I61Q" },
    ["SEMANAL"]  = { searchID = 46, code = "CP"   },
    ["VIAJEROS"] = { searchID = 46, code = "JJ2"  },
}

function ProChat.Events:SelectLFMRaid(raidKey, size)
    ProChat.Data.lfmCurrentSize = size or "25"
    ProChat.Data.lfmCurrentRaid = raidKey

    if ProChat.UI.lfmDropText then
        local dungColor = ProChat.Data.filterColors and ProChat.Data.filterColors[raidKey] or "B0B0B0"
        local hasDiff   = ProChat.Data.dungeonDifficulties[raidKey]
        local sizeLabel = (hasDiff and size) and (" "..size) or ""
        ProChat.UI.lfmDropText:SetText("|cff"..dungColor..raidKey..sizeLabel.."|r")
    end

    local searchID
    if SPECIAL_LFM_IDS[raidKey] then
        searchID = SPECIAL_LFM_IDS[raidKey].searchID
    else
        local ids = ProChat.Data.dungeonIDs[raidKey]
        if not ids then return end
        local sizeKey = size
        if sizeKey and not ids[sizeKey] then sizeKey = size:match("^(%d+)") end
        searchID = (sizeKey and ids[sizeKey]) or ids["25"] or ids["10"]
        if not searchID then return end
    end

    SearchLFGJoin(2, searchID)

    local f = CreateFrame("Frame")
    f.t = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        if self.t >= 1.0 then
            self:SetScript("OnUpdate", nil)
            ProChat.Events:RefreshLFMTable()
        end
    end)
end

-- =============================================================
-- DECODIFICACIÓN DE GS
-- =============================================================
local GS_DECODE = {
    ["HH"]="0",["A0"]="1",["ZW"]="2",["KQ"]="3",
    ["6J"]="4",["PF"]="5",["E0"]="6",["IG"]="7",
    ["C8"]="8",["4T"]="9",
}

local function DecodeGS(encoded)
    if not encoded or encoded == "" then return 0 end
    local result, i = "", 1
    while i <= #encoded do
        local chunk = encoded:sub(i, i+2)
        if GS_DECODE[chunk] then
            result = result..GS_DECODE[chunk]; i = i + 3
        else
            chunk = encoded:sub(i, i+1)
            if GS_DECODE[chunk] then
                result = result..GS_DECODE[chunk]; i = i + 2
            else
                i = i + 1
            end
        end
    end
    return tonumber(result) or 0
end

-- =============================================================
-- TOOLTIP EN CURSOR
-- =============================================================
local function ShowPlayerTooltip(anchorFrame, p)
    local lang  = (ProChatDB and ProChatDB.lang) or "es"
    local stats = p.stats

    -- Anclar al cursor con pequeño offset para que no tape el elemento
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()

    -- Nombre
    local classColor = (p.classEn and ProChat.Data.classColors[p.classEn]) or "ffffff"
    GameTooltip:AddLine("|cff"..classColor..p.name.."|r", 1,1,1)

    -- Rol
    local roleParts = {}
    if p.isTank   then table.insert(roleParts, lang=="es" and "|cff4FC3F7Tanque|r"  or "|cff4FC3F7Tank|r")   end
    if p.isHealer then table.insert(roleParts, lang=="es" and "|cff81C784Sanador|r" or "|cff81C784Healer|r") end
    if p.isDps    then table.insert(roleParts, "|cffE57373DPS|r") end
    if #roleParts == 0 then table.insert(roleParts, "|cffE57373DPS|r") end
    GameTooltip:AddLine((lang=="es" and "Rol: " or "Role: ")..table.concat(roleParts,"/"), 1,1,1)

    GameTooltip:AddLine(" ", 1,1,1)

    -- Stats por rol (Tank > Healer > DPS)
    if p.isTank then
        GameTooltip:AddDoubleLine(
            lang=="es" and "Armadura:"    or "Armor:",
            tostring(stats.armor     or 0), 0.7,0.7,1, 1,1,1)
        GameTooltip:AddDoubleLine(
            lang=="es" and "Vida Máxima:" or "Max Health:",
            tostring(stats.maxHealth or 0), 0.7,0.7,1, 1,1,1)
    elseif p.isHealer then
        local sp = (stats.healPower and stats.healPower > 0) and stats.healPower or (stats.spellPower or 0)
        GameTooltip:AddDoubleLine(
            lang=="es" and "Poder de Hechizo:" or "Spell Power:",
            tostring(sp),                    0.7,1,0.7, 1,1,1)
        GameTooltip:AddDoubleLine(
            lang=="es" and "Maná Máximo:"      or "Max Mana:",
            tostring(stats.maxMana or 0),    0.7,1,0.7, 1,1,1)
    elseif p.isDps then
        local dpsCasters = {["MAGE"]=true,["WARLOCK"]=true,["PRIEST"]=true}
        local dpsHybrid  = {["DRUID"]=true,["SHAMAN"]=true,["PALADIN"]=true}
        local isCaster   = dpsCasters[p.classEn]
        if dpsHybrid[p.classEn] then
            isCaster = (stats.spellPower or 0) >= (stats.ap or 0)
        end
        if isCaster then
            GameTooltip:AddDoubleLine(
                lang=="es" and "Poder de Hechizo:" or "Spell Power:",
                tostring(stats.spellPower or 0), 1,0.7,1, 1,1,1)
            GameTooltip:AddDoubleLine(
                lang=="es" and "Maná Máximo:"      or "Max Mana:",
                tostring(stats.maxMana    or 0), 1,0.7,1, 1,1,1)
        else
            GameTooltip:AddDoubleLine(
                lang=="es" and "Poder de Ataque:" or "Attack Power:",
                tostring(stats.ap or 0), 1,0.8,0.4, 1,1,1)
        end
    else
        GameTooltip:AddDoubleLine(
            lang=="es" and "Poder de Ataque:" or "Attack Power:",
            tostring(stats.ap or 0), 1,0.8,0.4, 1,1,1)
    end

    if IsFavorite(p.name) then
        GameTooltip:AddLine("|cffffff00|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Favorito|r", 1,1,1)
    end

    GameTooltip:Show()
end

-- =============================================================
-- INFRAESTRUCTURA DE LOS 3 PANELES (DPS / Healer / Tank)
-- =============================================================
local FONT     = "Fonts\\FRIZQT__.TTF"
local HEADER_H = 16   -- altura del título del panel  (⚔ DPS, etc.)
local COL_H    = 13   -- altura de la fila de columnas ordenables
local ROW_H    = 13   -- altura de cada fila de datos
local ROW_GAP  = 1    -- separación entre filas
local TOP_OFF  = HEADER_H + 4 + COL_H + 3  -- offset vertical donde empiezan las filas de datos
local FAV_W    = 10   -- ancho reservado para el ★

local PANEL_DEFS = {
    { key="dps",    titleES="[DPS]",     titleEN="[DPS]",     color={1,    0.35, 0.35} },
    { key="healer", titleES="[Healers]", titleEN="[Healers]", color={0.4,  1,    0.5 } },
    { key="tank",   titleES="[Tanks]",   titleEN="[Tanks]",   color={0.45, 0.7,  1   } },
}

local COL_DEFS = {
    { key="class", labelES="Clase",  labelEN="Class", flex=0.30, justify="LEFT"   },
    { key="gs",    labelES="GS",     labelEN="GS",    flex=0.22, justify="CENTER" },
    { key="name",  labelES="Nombre", labelEN="Name",  flex=0.48, justify="LEFT"   },
}

local function ApplyPanelBackdrop(f, color)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = {left=0,right=0,top=0,bottom=0}
    })
    f:SetBackdropColor(0, 0.04, 0.04, 0.92)
    f:SetBackdropBorderColor(color[1]*0.7, color[2]*0.7, color[3]*0.7, 0.6)
end

-- Crea los 3 paneles la primera vez; en llamadas posteriores solo los muestra/reposiciona
local function EnsurePanels(lfmWin)
    if lfmWin._panels then return end

    lfmWin._panels    = {}
    lfmWin._sortState = {}
    lfmWin._rowPools  = {}

    for _, def in ipairs(PANEL_DEFS) do
        lfmWin._sortState[def.key] = { col="gs", asc=false }

        -- Panel contenedor externo (fijo, sin scroll)
        local pf = CreateFrame("Frame", nil, lfmWin)
        pf:SetFrameLevel(lfmWin:GetFrameLevel() + 1)
        ApplyPanelBackdrop(pf, def.color)
        pf._def = def

        -- Título del panel
        local titleFS = pf:CreateFontString(nil, "OVERLAY")
        titleFS:SetFont(FONT, 9, "OUTLINE")
        titleFS:SetPoint("TOPLEFT",  pf, "TOPLEFT",  4, -3)
        titleFS:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -4, -3)
        titleFS:SetHeight(HEADER_H)
        titleFS:SetJustifyH("CENTER")
        titleFS:SetTextColor(def.color[1], def.color[2], def.color[3], 1)
        pf._titleFS = titleFS

        -- Línea separadora bajo título
        local sepTitle = pf:CreateTexture(nil, "ARTWORK")
        sepTitle:SetHeight(1)
        sepTitle:SetPoint("TOPLEFT",  pf, "TOPLEFT",  2, -(HEADER_H + 2))
        sepTitle:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -2, -(HEADER_H + 2))
        sepTitle:SetTexture(def.color[1], def.color[2], def.color[3], 0.5)

        -- Botones de columna (header fijo, no entra en el ScrollFrame)
        pf._colBtns = {}
        for ci, cdef in ipairs(COL_DEFS) do
            local cb = CreateFrame("Button", nil, pf)
            cb:SetHeight(COL_H)
            cb:SetFrameLevel(pf:GetFrameLevel() + 2)

            local cbBg = cb:CreateTexture(nil, "BACKGROUND")
            cbBg:SetAllPoints()
            cbBg:SetTexture(0, 0, 0, 0)
            cb._bg = cbBg

            local cbFS = cb:CreateFontString(nil, "OVERLAY")
            cbFS:SetFont(FONT, 8)
            cbFS:SetAllPoints()
            cbFS:SetJustifyH("CENTER")
            cbFS:SetJustifyV("MIDDLE")
            cb._fs       = cbFS
            cb._key      = cdef.key
            cb._flex     = cdef.flex
            cb._labelES  = cdef.labelES
            cb._labelEN  = cdef.labelEN
            cb._panelKey = def.key

            cb:SetScript("OnEnter", function(self) self._bg:SetTexture(0,0.15,0.15,0.7) end)
            cb:SetScript("OnLeave", function(self) self._bg:SetTexture(0,0,0,0) end)
            cb:SetScript("OnClick", function(self)
                local st = lfmWin._sortState[self._panelKey]
                if st.col == self._key then
                    st.asc = not st.asc
                else
                    st.col = self._key
                    st.asc = (self._key == "name" or self._key == "class")
                end
                ProChat.Events:RefreshLFMTable()
            end)

            pf._colBtns[ci] = cb
        end

        -- Línea separadora bajo columnas
        local sepCols = pf:CreateTexture(nil, "ARTWORK")
        sepCols:SetHeight(1)
        sepCols:SetPoint("TOPLEFT",  pf, "TOPLEFT",  2, -(HEADER_H + 4 + COL_H + 1))
        sepCols:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -2, -(HEADER_H + 4 + COL_H + 1))
        sepCols:SetTexture(0, 1, 0.8, 0.15)

        -- ScrollFrame: ocupa el espacio bajo los headers, se adapta al resize
        local sf = CreateFrame("ScrollFrame", nil, pf)
        sf:SetPoint("TOPLEFT",     pf, "TOPLEFT",     2,  -(TOP_OFF))
        sf:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", -10, 2)
        sf:SetFrameLevel(pf:GetFrameLevel() + 2)
        pf._scrollFrame = sf

        -- ===== SCROLLBAR CUSTOM (sin flechas, solo thumb gris) =====
        -- Track: fondo oscuro estrecho a la derecha del panel
        local track = CreateFrame("Frame", nil, pf)
        track:SetWidth(6)
        track:SetPoint("TOPRIGHT",    pf, "TOPRIGHT",    -2, -(TOP_OFF))
        track:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", -2,  2)
        track:SetFrameLevel(pf:GetFrameLevel() + 3)
        local trackBg = track:CreateTexture(nil, "BACKGROUND")
        trackBg:SetAllPoints()
        trackBg:SetTexture(0.05, 0.05, 0.05, 0.7)
        track:Hide()  -- se muestra solo cuando hay overflow

        -- Thumb (el rectángulo que se arrastra)
        local thumb = CreateFrame("Button", nil, track)
        thumb:SetWidth(6)
        thumb:SetHeight(20)  -- se recalcula en UpdateThumb
        thumb:SetPoint("TOP", track, "TOP", 0, 0)
        thumb:SetFrameLevel(track:GetFrameLevel() + 1)
        local thumbTex = thumb:CreateTexture(nil, "BACKGROUND")
        thumbTex:SetAllPoints()
        thumbTex:SetTexture(0.45, 0.45, 0.45, 0.9)
        thumb:SetScript("OnEnter", function() thumbTex:SetTexture(0.65, 0.65, 0.65, 1) end)
        thumb:SetScript("OnLeave", function() thumbTex:SetTexture(0.45, 0.45, 0.45, 0.9) end)

        -- Estado del scroll
        local scrollValue = 0  -- valor actual en píxeles (0 = top)
        local scrollMax   = 0  -- máximo desplazamiento posible

        local function SetScroll(val)
            local mn, mx = 0, scrollMax
            if val < mn then val = mn end
            if val > mx then val = mx end
            scrollValue = val
            sf:SetVerticalScroll(val)
            -- Actualizar posición del thumb
            local trackH = track:GetHeight() or 0
            local sfH    = sf:GetHeight()    or 0
            if mx > 0 and trackH > 0 and sfH > 0 then
                local thumbH = math.max(12, trackH * (sfH / (sfH + mx)))
                thumb:SetHeight(thumbH)
                local ratio    = val / mx
                local travel   = trackH - thumbH
                thumb:ClearAllPoints()
                thumb:SetPoint("TOP", track, "TOP", 0, -math.floor(ratio * travel))
            end
        end

        -- Actualiza min/max y visibilidad de la barra custom
        local function SetScrollRange(maxVal)
            scrollMax = maxVal
            if maxVal > 0 then
                track:Show()
                SetScroll(math.min(scrollValue, maxVal))
            else
                track:Hide()
                scrollValue = 0
                sf:SetVerticalScroll(0)
            end
        end

        -- Arrastrar thumb
        thumb._dragging = false
        thumb._dragStartY = 0
        thumb._dragStartVal = 0
        thumb:SetScript("OnMouseDown", function(self, btn)
            if btn == "LeftButton" then
                self._dragging    = true
                self._dragStartY  = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
                self._dragStartVal = scrollValue
                self:SetScript("OnUpdate", function()
                    if not self._dragging then self:SetScript("OnUpdate", nil) return end
                    local curY    = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
                    local delta   = self._dragStartY - curY
                    local trackH  = track:GetHeight() or 0
                    local sfH     = sf:GetHeight()    or 0
                    if trackH > 0 and sfH > 0 and scrollMax > 0 then
                        local thumbH = math.max(12, trackH * (sfH / (sfH + scrollMax)))
                        local travel = trackH - thumbH
                        if travel > 0 then
                            SetScroll(self._dragStartVal + delta * scrollMax / travel)
                        end
                    end
                end)
            end
        end)
        thumb:SetScript("OnMouseUp", function(self)
            self._dragging = false
            self:SetScript("OnUpdate", nil)
        end)

        -- Guardar referencias compatibles con el resto del código
        local sb = { -- tabla que imita la API mínima usada en BuildPanelRows
            SetMinMaxValues = function(_, mn, mx) SetScrollRange(mx) end,
            SetValue        = function(_, v)      SetScroll(v) end,
            GetValue        = function()          return scrollValue end,
            GetMinMaxValues = function()          return 0, scrollMax end,
            Show            = function()          track:Show() end,
            Hide            = function()          track:Hide() end,
        }
        pf._scrollBar   = sb
        pf._scrollTrack = track

        -- Contenedor dentro del ScrollFrame (tamaño ajustado con el número de filas)
        local sc = CreateFrame("Frame", nil, sf)
        sc:SetWidth(sf:GetWidth())
        sc:SetHeight(1)  -- se recalcula en BuildPanelRows
        sf:SetScrollChild(sc)
        pf._scrollChild = sc

        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local step   = (ROW_H + ROW_GAP) * 3
            SetScroll(scrollValue - delta * step)
        end)

        -- Pool de filas (ahora parented en scrollChild)
        lfmWin._rowPools[def.key] = {}

        table.insert(lfmWin._panels, pf)
        lfmWin._panels[def.key] = pf
    end
end

-- Reposiciona paneles, actualiza anchos de filas y recalcula scrollbar en tiempo real
local function LayoutPanels(lfmWin)
    local W   = lfmWin:GetWidth()
    local H   = lfmWin:GetHeight()
    local gap = 4
    local n   = #PANEL_DEFS
    local panW = math.floor((W - gap*(n-1)) / n)

    for i, pf in ipairs(lfmWin._panels) do
        pf:ClearAllPoints()
        pf:SetPoint("TOPLEFT",     lfmWin, "TOPLEFT",  (i-1)*(panW+gap), 0)
        pf:SetPoint("BOTTOMRIGHT", lfmWin, "TOPLEFT",  (i-1)*(panW+gap) + panW, -H)
        pf:Show()

        -- Ancho del scrollChild = panel menos la scrollbar custom (6px) + margen
        local innerW = math.max(1, panW - 10)
        if pf._scrollChild then
            pf._scrollChild:SetWidth(innerW)
        end

        -- Anchos de columna proporcionales al nuevo ancho
        local xOff = FAV_W + 2
        local colWidths = {}
        for ci, cb in ipairs(pf._colBtns) do
            local cbW = math.floor(panW * cb._flex)
            cb:ClearAllPoints()
            cb:SetWidth(cbW)
            cb:SetPoint("TOPLEFT", pf, "TOPLEFT", xOff, -(HEADER_H + 4))
            table.insert(colWidths, cbW)
            xOff = xOff + cbW
        end

        -- Bug 1: Actualizar anchos de TODAS las filas existentes en el pool
        local pool = lfmWin._rowPools and lfmWin._rowPools[pf._def.key]
        if pool then
            local panWRow = math.max(1, panW - 16)
            local colW = {}
            for _, cb in ipairs(pf._colBtns) do
                table.insert(colW, math.floor(panWRow * cb._flex))
            end
            local xClass = FAV_W + 2
            local xGS    = xClass + colW[1]
            local xName  = xGS   + colW[2]
            for _, row in ipairs(pool) do
                if row and row:IsShown() then
                    row._favFS:SetWidth(FAV_W)
                    row._classFS:ClearAllPoints()
                    row._classFS:SetPoint("LEFT", row, "LEFT", xClass, 0)
                    row._classFS:SetWidth(colW[1] - 2)
                    row._gsFS:ClearAllPoints()
                    row._gsFS:SetPoint("LEFT", row, "LEFT", xGS, 0)
                    row._gsFS:SetWidth(colW[2] - 2)
                    row._nameFS:ClearAllPoints()
                    row._nameFS:SetPoint("LEFT",  row, "LEFT",  xName, 0)
                    row._nameFS:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                end
            end
        end

        -- Bug 2: Recalcular scrollbar con el nuevo alto del ScrollFrame
        local sb = pf._scrollBar
        if sb and pf._scrollChild then
            local totalH = pf._scrollChild:GetHeight() or 0
            local sfH    = (pf._scrollFrame and pf._scrollFrame:GetHeight()) or 0
            local overflow = totalH - sfH
            if overflow > 0 then
                sb:SetMinMaxValues(0, overflow)
                sb:Show()
            else
                sb:SetMinMaxValues(0, 0)
                sb:SetValue(0)
                sb:Hide()
            end
        end
    end
end

-- Actualiza texto de cabeceras con flecha de orden
local function RefreshColHeaders(pf, sortState, lang)
    for _, cb in ipairs(pf._colBtns) do
        local label = (lang=="es") and cb._labelES or cb._labelEN
        if sortState.col == cb._key then
            label = "|cff00FFCC"..label..(sortState.asc and " ^" or " v").."|r"
        else
            label = "|cff777777"..label.."|r"
        end
        cb._fs:SetText(label)
    end
end

-- Construye/actualiza filas de datos de un panel concreto
local function BuildPanelRows(lfmWin, panelKey, players)
    local pf        = lfmWin._panels[panelKey]
    local rowPool   = lfmWin._rowPools[panelKey]
    local sortState = lfmWin._sortState[panelKey]
    local lang      = (ProChatDB and ProChatDB.lang) or "es"
    local def       = pf._def
    local sc        = pf._scrollChild
    local sb        = pf._scrollBar

    -- Título con conteo
    local titleText = (lang=="es") and def.titleES or def.titleEN
    pf._titleFS:SetText(titleText.." |cff888888("..#players..")|r")

    -- Cabeceras
    RefreshColHeaders(pf, sortState, lang)

    -- Ordenar copia (favoritos primero si el switch está activo)
    local sorted = {}
    for _, p in ipairs(players) do table.insert(sorted, p) end
    local favFirst = ProChat.Data.lfmFavFirst
    table.sort(sorted, function(a, b)
        if favFirst then
            local fa, fb = IsFavorite(a.name), IsFavorite(b.name)
            if fa ~= fb then return fa end
        end
        local col = sortState.col
        local va, vb
        if col == "gs" then
            va, vb = a.gsRaw or 0,    b.gsRaw or 0
        elseif col == "class" then
            va, vb = a.className or "", b.className or ""
        else
            va, vb = a.name or "",     b.name or ""
        end
        if sortState.asc then return va < vb else return va > vb end
    end)

    -- Ocultar filas sobrantes del pool
    for idx = #sorted + 1, #rowPool do
        if rowPool[idx] then rowPool[idx]:Hide() end
    end

    -- Ancho real del contenido (descontando track 6px + márgenes)
    local panW = math.max(1, pf:GetWidth() - 10)

    for idx, p in ipairs(sorted) do
        -- Crear fila dentro del scrollChild si no existe
        local row = rowPool[idx]
        if not row then
            row = CreateFrame("Button", nil, sc)
            row:SetFrameLevel(pf:GetFrameLevel() + 6)
            row:EnableMouse(true)
            row:SetToplevel(false)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            row._bg = bg

            local favFS = row:CreateFontString(nil, "OVERLAY")
            favFS:SetFont(FONT, 8)
            favFS:SetJustifyH("CENTER")
            row._favFS = favFS

            local classFS = row:CreateFontString(nil, "OVERLAY")
            classFS:SetFont(FONT, 8)
            classFS:SetJustifyH("LEFT")
            row._classFS = classFS

            local gsFS = row:CreateFontString(nil, "OVERLAY")
            gsFS:SetFont(FONT, 8)
            gsFS:SetJustifyH("CENTER")
            row._gsFS = gsFS

            local nameFS = row:CreateFontString(nil, "OVERLAY")
            nameFS:SetFont(FONT, 8)
            nameFS:SetJustifyH("LEFT")
            row._nameFS = nameFS

            rowPool[idx] = row
        end

        -- Posición dentro del scrollChild (no del panel)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  sc, "TOPLEFT",  2, -((idx-1)*(ROW_H+ROW_GAP)))
        row:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -2, -((idx-1)*(ROW_H+ROW_GAP)))
        row:SetHeight(ROW_H)

        -- Cebra
        local zebraR, zebraG, zebraB, zebraA
        if idx % 2 == 0 then
            zebraR, zebraG, zebraB, zebraA = 0.07, 0.07, 0.07, 0.75
        else
            zebraR, zebraG, zebraB, zebraA = 0.02, 0.02, 0.02, 0.55
        end
        row._bg:SetTexture(zebraR, zebraG, zebraB, zebraA)

        -- Calcular anchos de columna
        local xOff   = FAV_W + 2
        local colWidths = {}
        for _, cb in ipairs(pf._colBtns) do
            table.insert(colWidths, math.floor(panW * cb._flex))
        end
        local xClass = xOff
        local xGS    = xClass + colWidths[1]
        local xName  = xGS   + colWidths[2]

        row._favFS:ClearAllPoints()
        row._favFS:SetPoint("LEFT", row, "LEFT", 2, 0)
        row._favFS:SetWidth(FAV_W)

        row._classFS:ClearAllPoints()
        row._classFS:SetPoint("LEFT", row, "LEFT", xClass, 0)
        row._classFS:SetWidth(colWidths[1] - 2)

        row._gsFS:ClearAllPoints()
        row._gsFS:SetPoint("LEFT", row, "LEFT", xGS, 0)
        row._gsFS:SetWidth(colWidths[2] - 2)

        row._nameFS:ClearAllPoints()
        row._nameFS:SetPoint("LEFT",  row, "LEFT",  xName, 0)
        row._nameFS:SetPoint("RIGHT", row, "RIGHT", -2, 0)

        local classColor = (p.classEn and ProChat.Data.classColors[p.classEn]) or "ffffff"
        row._favFS:SetText(IsFavorite(p.name) and "|cffffff00|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t|r" or "")
        row._classFS:SetText("|cff"..classColor..(p.className or "?").."|r")

        local gsColorHex  = (ProChat.Utils and ProChat.Utils.GetGSColorHex)
            and ProChat.Utils:GetGSColorHex(p.gsRaw) or "ffffff"
        local gsFormatted = (p.gsRaw and p.gsRaw > 0)
            and string.format("%.1fk", p.gsRaw/1000) or "?"
        row._gsFS:SetText("|cff"..gsColorHex..gsFormatted.."|r")
        row._nameFS:SetText("|cff"..classColor..p.name.."|r")

        local pData = p

        row:SetScript("OnEnter", function(self)
            self._bg:SetTexture(0.18, 0.18, 0.18, 0.9)
            ShowPlayerTooltip(self, pData)
        end)
        row:SetScript("OnLeave", function(self)
            self._bg:SetTexture(zebraR, zebraG, zebraB, zebraA)
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                -- Usar posición guardada en MouseDown si existe
                local cx = self._clickX or select(1, GetCursorPosition())
                local cy = self._clickY or select(2, GetCursorPosition())
                OpenPCMenu(pData, cx, cy)
            elseif button == "RightButton" then
                if ProChat.ContextMenu then
                    ProChat.ContextMenu:SetLFGTarget(pData.name)
                end
                FriendsFrame_ShowDropdown(pData.name, 1)
            end
        end)
        row:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self._clickX, self._clickY = GetCursorPosition()
            end
        end)

        row:Show()
    end

    -- Actualizar scrollChild y scrollbar
    local totalH = #sorted * (ROW_H + ROW_GAP)
    sc:SetHeight(math.max(1, totalH))
    local sfH = pf._scrollFrame and pf._scrollFrame:GetHeight() or 0
    local overflow = totalH - sfH
    if overflow > 0 and sb then
        sb:SetMinMaxValues(0, overflow)
        sb:Show()
    elseif sb then
        sb:SetMinMaxValues(0, 0)
        sb:SetValue(0)
        sb:Hide()
    end
end


-- =============================================================
-- REFRESH LFM TABLE  (punto de entrada principal)
-- =============================================================
function ProChat.Events:RefreshLFMTable()
    local lfmWin = ProChat.Frames.chatWin and ProChat.Frames.chatWin.lfmWin
    if not lfmWin then return end

    if ProChat.Data.currentTab == "LFM" then lfmWin:Show() end

    -- Actualizar dropdown
    if ProChat.UI.lfmDropText and ProChat.Data.lfmCurrentRaid then
        local dungColor = ProChat.Data.filterColors and ProChat.Data.filterColors[ProChat.Data.lfmCurrentRaid] or "B0B0B0"
        local hasDiff   = ProChat.Data.dungeonDifficulties[ProChat.Data.lfmCurrentRaid]
        local sizeLabel = (hasDiff and ProChat.Data.lfmCurrentSize) and (" "..ProChat.Data.lfmCurrentSize) or ""
        ProChat.UI.lfmDropText:SetText("|cff"..dungColor..ProChat.Data.lfmCurrentRaid..sizeLabel.."|r")
    end

    -- Ocultar FontString legacy
    if lfmWin.text then lfmWin.text:SetText("") end

    -- Crear/reusar paneles y reposicionarlos
    EnsurePanels(lfmWin)
    LayoutPanels(lfmWin)

    -- ===== FILTROS =====
    local currentRaid   = ProChat.Data.lfmCurrentRaid
    local specialFilter = SPECIAL_LFM_IDS[currentRaid] and SPECIAL_LFM_IDS[currentRaid].code
    local isONYNormal   = (currentRaid == "ONY")
    local currentSize   = ProChat.Data.lfmCurrentSize
    local diffCode      = (currentSize and (currentRaid=="SR" or currentRaid=="ICC" or currentRaid=="TOC"))
        and LFM_DIFF_CODES[currentRaid.."_"..currentSize] or nil

    -- ===== RECOPILAR =====
    local byRole = { dps={}, healer={}, tank={} }
    local n = SearchLFGGetNumResults()

    if n and n > 0 then
        for i = 1, n do
            local results   = {SearchLFGGetResults(i)}
            local name      = results[1]
            local level     = results[2]
            local className = results[4]
            local comment   = results[5]
            local classEn   = results[8]
            local isTank    = results[12]
            local isHealer  = results[13]
            local isDps     = results[14]

            if name and comment then
                local gsEncoded, hash = comment:match("ProChat IA%].*/%s*([A-Z0-9]+)%s*/%s*(%x+)%s*$")
                if gsEncoded and hash then
                    local gs           = DecodeGS(gsEncoded)
                    local expectedHash = ProChat.Utils:GenerateSignature(gs, name)
                    if hash:upper() == expectedHash:upper() then
                        -- Filtro especial / ONY
                        local passSpecial = false
                        if specialFilter then
                            passSpecial = comment:find(specialFilter, 1, true) ~= nil
                        elseif isONYNormal then
                            local hasSpecialCode = false
                            for _, sp in pairs(SPECIAL_LFM_IDS) do
                                if comment:find(sp.code, 1, true) then hasSpecialCode = true; break end
                            end
                            passSpecial = not hasSpecialCode
                        else
                            passSpecial = true
                        end

                        if passSpecial then
                            local passDiff = not diffCode or comment:find(diffCode, 1, true) ~= nil
                            if passDiff then
                                local pEntry = {
                                    name      = name,
                                    level     = level,
                                    className = className,
                                    classEn   = classEn,
                                    isTank    = isTank,
                                    isHealer  = isHealer,
                                    isDps     = isDps,
                                    gsRaw     = gs,
                                    stats = {
                                        armor      = results[20] or 0,
                                        spellPower = results[21] or 0,
                                        healPower  = results[22] or 0,
                                        critMelee  = results[23] or 0,
                                        critRanged = results[24] or 0,
                                        critSpell  = results[25] or 0,
                                        ap         = results[28] or 0,
                                        agility    = results[29] or 0,
                                        maxHealth  = results[30] or 0,
                                        maxMana    = results[31] or 0,
                                        hitRating  = results[32] or 0,
                                        defense    = results[33] or 0,
                                        haste      = results[37] or 0,
                                    },
                                }
                                -- Distribuir a paneles (un jugador puede ir a varios)
                                if isTank                            then table.insert(byRole.tank,   pEntry) end
                                if isHealer                          then table.insert(byRole.healer, pEntry) end
                                if isDps or (not isTank and not isHealer) then table.insert(byRole.dps, pEntry) end
                            end
                        end
                    end
                end
            end
        end
    end

    -- ===== POBLAR PANELES =====
    local lang = (ProChatDB and ProChatDB.lang) or "es"

    for _, def in ipairs(PANEL_DEFS) do
        local key    = def.key
        local pf     = lfmWin._panels[key]
        local pool   = lfmWin._rowPools[key]

        if #byRole[key] == 0 then
            -- Ocultar filas existentes
            for _, r in ipairs(pool) do r:Hide() end
            -- Actualizar título con (0) y cabeceras
            local titleText = (lang=="es") and def.titleES or def.titleEN
            pf._titleFS:SetText(titleText.." |cff555555(0)|r")
            RefreshColHeaders(pf, lfmWin._sortState[key], lang)
        else
            BuildPanelRows(lfmWin, key, byRole[key])
        end
    end
end

-- =============================================================
-- INIT LFM PANELS  (llamado desde SelectTab al entrar al tab LFM)
-- Crea los 3 paneles vacíos inmediatamente, sin esperar búsqueda.
-- =============================================================
function ProChat.Events:InitLFMPanels()
    local lfmWin = ProChat.Frames.chatWin and ProChat.Frames.chatWin.lfmWin
    if not lfmWin then return end

    -- Ocultar FontString legacy
    if lfmWin.text then lfmWin.text:SetText("") end

    -- Crear paneles si aún no existen
    EnsurePanels(lfmWin)

    -- Registrar hooks de resize la primera vez
    if not lfmWin._sizeHookSet then
        lfmWin._sizeHookSet = true
        lfmWin:SetScript("OnSizeChanged", function()
            if lfmWin._panels then LayoutPanels(lfmWin) end
        end)
        local chatWin = ProChat.Frames.chatWin
        if chatWin and not chatWin._lfmSizeHook then
            chatWin._lfmSizeHook = true
            chatWin:HookScript("OnSizeChanged", function()
                if lfmWin:IsShown() and lfmWin._panels then
                    LayoutPanels(lfmWin)
                end
            end)
        end
    end

    -- Posicionar paneles y mostrarlos vacíos (0 resultados)
    LayoutPanels(lfmWin)

    local lang = (ProChatDB and ProChatDB.lang) or "es"
    for _, def in ipairs(PANEL_DEFS) do
        local pf   = lfmWin._panels[def.key]
        local pool = lfmWin._rowPools[def.key]
        -- Ocultar filas sobrantes del ciclo anterior
        if pool then
            for _, r in ipairs(pool) do r:Hide() end
        end
        -- Título con (0)
        local titleText = (lang=="es") and def.titleES or def.titleEN
        pf._titleFS:SetText(titleText.." |cff555555(0)|r")
        RefreshColHeaders(pf, lfmWin._sortState[def.key], lang)
        pf:Show()
    end
end