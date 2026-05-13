-- ProChat IA v1.0 - 3.3.5 - Core Module
-- Por Elreyflahs

ProChat = ProChat or {}
ProChat.Core = {}

local Data = ProChat.Data
local Utils = ProChat.Utils
local Locales = ProChat.Locales
local L = ProChat.L
local UI = ProChat.UI
local Frames = ProChat.Frames

-- ===== SILENCE LFG QUEUE SIGNALS =====
-- Mientras ProChat.IsInternalAction == true, bloqueamos:
--   1. El mensaje de sistema "Ahora apareces en el buscador de banda."
--   2. El sonido de entrada en cola (bajando SFX a 0 brevemente)
--   3. Reaparición de MiniMapLFGFrame via hooksecurefunc
ProChat.IsInternalAction = false

-- ===== HOOK SELECTIVO DE PlaySound =====
-- Solo bloquea el sonido de cola (ID 8462) cuando ProChat está anotando internamente.
-- Para cualquier otro sonido, o si ProChat no está en acción, reproduce normalmente.
do
    local _origPlaySound = PlaySound
    PlaySound = function(soundID, ...)
        if ProChat.IsInternalAction and soundID == 8462 then
            return  -- bloquear solo el "clink" de cola durante una acción de ProChat
        end
        return _origPlaySound(soundID, ...)
    end
end

local function PC_LFGQueueChatFilter(self, event, msg, ...)
    if ProChat.IsInternalAction and msg then
        local block = false
        if _G.ERR_LFR_LISTED and msg == _G.ERR_LFR_LISTED then
            block = true
        elseif msg:find("buscador de banda") or msg:find("Looking For Raid") or
               msg:find("looking for raid") or msg:find("buscador de mazmorra") or
               msg:find("Looking For Dungeon") then
            block = true
        end
        if block then return true end
    end
    return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", PC_LFGQueueChatFilter)

-- ===== INITIALIZE ADDON =====
function ProChat.Core:Initialize()
    if not ProChatDB then ProChatDB = {} end
    
    Locales:InitializeLanguage()
    Locales:SetLanguage(ProChatDB.lang or "es")
    
    -- ===== PATCH RefreshChatWindow para limitar re-render =====
    -- El problema de freeze: RefreshChatWindow re-inserta hasta 256 entradas
    -- síncronamente. Este patch la reemplaza con una versión que solo
    -- re-inserta las últimas MAX_RENDER entradas, eliminando el cuello de botella.
    local MAX_RENDER = 80  -- máximo de líneas a re-insertar en un refresh
    if ProChat.Utils and ProChat.Utils.RefreshChatWindow then
        local _originalRefresh = ProChat.Utils.RefreshChatWindow
        ProChat.Utils.RefreshChatWindow = function(self)
            local chatWin = ProChat.Frames and ProChat.Frames.chatWin
            if not chatWin or not chatWin.text then
                return _originalRefresh(self)
            end

            local Data = ProChat.Data
            -- FIX BUG 1: Siempre leer desde history["TODAS"] y aplicar el filtro
            -- completo de mazmorra+dificultad, igual que hace OnChatMessage en tiempo real.
            local hist = Data.history["TODAS"] or {}
            local total = #hist
            local startIdx = math.max(1, total - MAX_RENDER + 1)

            chatWin.text:Clear()
            local searchTerm = Data.searchTerm or ""
            local hideGrays  = Data.hideGrays
            local filterActivo = not Data.selectedDungeons["TODAS"]

            for i = startIdx, total do
                local entry = hist[i]
                if entry then
                    local show = true

                    -- Filtro de mazmorra / dificultad (mismo criterio que OnChatMessage)
                    if filterActivo then
                        if entry.dungeon then
                            if not Data.selectedDungeons[entry.dungeon] then
                                show = false
                            elseif Data.dungeonDifficulties[entry.dungeon] then
                                -- Mazmorra con dificultades: verificar la dificultad de la entrada
                                if entry.difficulty then
                                    if not (Data.selectedDifficulties[entry.dungeon] and
                                            Data.selectedDifficulties[entry.dungeon][entry.difficulty]) then
                                        show = false
                                    end
                                else
                                    -- Sin dificultad detectada para una mazmorra que sí las tiene → ocultar
                                    show = false
                                end
                            end
                            -- Mazmorras sin dificultades (SEMANAL, FOSO, VIAJEROS): solo selectedDungeons basta
                        else
                            show = false  -- sin mazmorra y filtro activo → no mostrar
                        end
                    end

                    -- Filtro hideGrays
                    if show and hideGrays and not entry.dungeon then
                        show = false
                    end

                    -- Filtro de búsqueda
                    if show and searchTerm ~= "" then
                        show = false
                        for word in searchTerm:gmatch("%S+") do
                            if string.find(entry.formatted:upper(), word:upper(), 1, true) then
                                show = true
                                break
                            end
                        end
                    end

                    if show then
                        chatWin.text:AddMessage(entry.formatted)
                    end
                end
            end
        end
    end
    -- ===== FIN PATCH =====

    -- Initialize frames
    Frames.credWin = ProChat.FrameFactory:CreateCreditsWindow()
    Frames.welcomeWin = ProChat.FrameFactory:CreateWelcomeWindow()
    Frames.chatWin = ProChat.FrameFactory:CreateMainWindow("PC_ChatWin", "|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r |cffFF6666v"..ProChat.CURRENT_VERSION.."|r")
    Frames.minimap = ProChat.FrameFactory:CreateMinimapButton()
    Frames.scrollBottom = ProChat.FrameFactory:CreateScrollButton(Frames.chatWin)
    ProChat.FrameFactory:CreateAutoLFGStatusBar(Frames.chatWin)
    
    self:CreateUI()
    self:SetupEventListener()
    
    -- Hook MiniMapLFGFrame: evitar que reaparezca solo mientras ProChat.autoLFGActive == true.
    -- Cuando el jugador sale de la cola de ProChat, el frame de Blizzard puede mostrarse normalmente.
    if MiniMapLFGFrame then
        hooksecurefunc(MiniMapLFGFrame, "Show", function(self)
            if ProChat.Data.autoLFGActive then
                self:Hide()
            end
        end)
    end
    
    -- Apply saved settings
    self:ApplySavedSettings()
    
    -- Show welcome window if first run
    if ProChatDB.firstRun == nil then 
        Frames.welcomeWin:Show()
        ProChatDB.firstRun = false 
    end
    
    -- Forzar visibilidad según estado guardado
    if ProChatDB.showWindows then
        Frames.chatWin:Show()
    end
end

local function ProChatPrint(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
    PlaySound("TellMessage")
end

-- ===== DEBOUNCE SYSTEM =====
-- Evita freezes al cambiar filtros/pestañas con historial lleno.
-- En lugar de ejecutar RefreshChatWindow/UpdateRaidList síncronamente
-- en cada evento, los marca como pendientes y los corre UNA sola vez
-- al inicio del siguiente frame. Elimina el trabajo O(N) acumulado.
local _refreshPending  = false
local _raidPending     = false
local _debounceFrame   = nil

local function _activateDebounce()
    _debounceFrame:SetScript("OnUpdate", function(self)
        local didWork = false
        if _refreshPending then
            _refreshPending = false
            didWork = true
            if Utils and Utils.RefreshChatWindow then
                Utils:RefreshChatWindow()
            end
        end
        if _raidPending then
            _raidPending = false
            didWork = true
            if Utils and Utils.UpdateRaidList then
                Utils:UpdateRaidList()
            end
        end
        -- Sin trabajo pendiente → retirar el handler para no consumir CPU cada frame
        if not _refreshPending and not _raidPending then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function _ensureFrame()
    if not _debounceFrame then
        _debounceFrame = CreateFrame("Frame")
    end
end

-- Encola un refresh diferido (seguro llamar muchas veces seguidas)
local function DeferRefresh()
    if _refreshPending then return end
    _refreshPending = true
    _ensureFrame()
    _activateDebounce()
end

-- Encola un UpdateRaidList diferido
local function DeferRaidList()
    if _raidPending then return end
    _raidPending = true
    _ensureFrame()
    _activateDebounce()
end
-- ===== SLIDER MOUSE WHEEL HELPER (Fix #7) =====
local function EnableSliderMouseWheel(slider)
    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + (delta > 0 and 1 or -1))
    end)
end

-- ===== GET PLAYER CLASS (Apuntar) =====
function ProChat.Core:GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

-- ===== GET GEARSCORE (Apuntar) =====
-- Usa GearScoreLite si está instalado; si no, usa el motor nativo de ProChat.
function ProChat.Core:GetGearScore()
    if GearScore_GetScore then
        local gs, _ = GearScore_GetScore(UnitName("player"), "player")
        local n = tonumber(gs)
        if n and n > 0 then return n end
    end
    -- Motor nativo (extraído de GearScoreLite en PC-Utils.lua)
    if ProChat.Utils and ProChat.Utils.CalculatePlayerGS then
        return ProChat.Utils:CalculatePlayerGS()
    end
    return 0
end

-- ===== APPLY RAID VISIBILITY (Fix #12) =====
function ProChat.Core:ApplyRaidVisibility(show)
    ProChat.Data.showRaidWin = show
    if ProChatDB then ProChatDB.showRaidWin = show end
    if show then
        if Frames.chatWin.raidText then Frames.chatWin.raidText:Show() end
        if Frames.chatWin.resizer and ProChat.Data.showRaidWin then Frames.chatWin.resizer:Show() end
        Frames.chatWin.text:SetPoint("BOTTOMRIGHT", Frames.chatWin.resizer or Frames.chatWin, "BOTTOMLEFT", -5, 0)
        DeferRaidList()
    else
        if Frames.chatWin.raidText then Frames.chatWin.raidText:Hide() end
        if Frames.chatWin.resizer then Frames.chatWin.resizer:Hide() end
        Frames.chatWin.text:SetPoint("BOTTOMRIGHT", Frames.chatWin, "BOTTOMRIGHT", -30, 65)
    end
end

    -- Advertir al editar comentarios del buscador
    local prefix = "[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: "
    local warnCount = 0
    
    if LFRQueueFrameCommentTextButton then
        LFRQueueFrameCommentTextButton:HookScript("OnClick", function()
            warnCount = warnCount + 1
            local msg = warnCount == 1 and L["COMMENT_WARN_1"] or L["COMMENT_WARN_2"]
            ProChatPrint(prefix .. "|cffFF4D4D" .. msg)
        end)
    end
    
    if LFRQueueFrameAcceptCommentButton then
        LFRQueueFrameAcceptCommentButton:HookScript("OnClick", function()
            ProChatPrint(prefix .. "|cffFF4D4D" .. L["COMMENT_WARN_BTN"])
            RaidNotice_AddMessage(RaidBossEmoteFrame, L["ALERTA_BANDA"], {r=1, g=0.3, b=0})
            PlaySound("RaidWarning")
        end)
    end

    

-- ===== REFRESH FILTER DROPDOWN TEXT (FIX #4 - Unificado) =====
function ProChat.Core:RefreshFilterDropBtnText()
    local UI = ProChat.UI
    local Data = ProChat.Data
    local L = ProChat.L
    
    if UI.filterDropBtnText then
        if Data.selectedDungeons["TODAS"] then
            UI.filterDropBtnText:SetText("|cff"..(Data.filterColors["TODAS"] or "B0B0B0")..(L["ALL_TEXT"] or "TODAS").."|r")
        else
            local count = 0
            for _, k in ipairs(Data.keywords) do
                if Data.selectedDungeons[k] then count = count + 1 end
            end
            UI.filterDropBtnText:SetText("|cff00FFCC"..count.." "..(L["DUNGEONS_TEXT"] or "Mazmorras").."|r")
        end
    end
end

-- ===== CENTRALIZED OPTIONS UI ELEMENTS (Fix #5) =====
-- NOTA: checkOptions NO va aquí — nunca debe ocultarse por sí mismo (fix 6)
ProChat.Core.OptionsElements = {
    "chanDrop", "filterDropBtn", "timeDrop",
    "labelChan", "labelDung", "labelSpam",
    "checkMM", "checkGrays", "checkRaid",
    "autoLFGSwitch",
}
-- Labels de los switches controlados por Opciones (fix 5)
-- Se manejan vía switchLabel de cada switch en SetupCheckboxScripts

-- ===== SISTEMA GLOBAL DE CIERRE DE MENÚS =====
-- Registro central de todos los menús abiertos y función para cerrarlos todos
ProChat.Core._openMenuClosers = {}

function ProChat.Core:RegisterOpenMenu(closeFn)
    table.insert(self._openMenuClosers, closeFn)
end

function ProChat.Core:CloseAllMenus()
    for _, fn in ipairs(self._openMenuClosers) do
        pcall(fn)
    end
    self._openMenuClosers = {}
    -- Ocultar el frame de click-fuera
    if self._menuClickCatcher then
        self._menuClickCatcher:Hide()
    end
end

-- Frame transparente único que captura click fuera de cualquier menú
local function GetMenuClickCatcher()
    if not ProChat.Core._menuClickCatcher then
        local f = CreateFrame("Frame", "PC_MenuClickCatcher", UIParent)
        f:SetAllPoints(UIParent)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(50)
        f:EnableMouse(true)
        f:Hide()
        f:SetScript("OnMouseDown", function()
            ProChat.Core:CloseAllMenus()
        end)
        ProChat.Core._menuClickCatcher = f
    end
    return ProChat.Core._menuClickCatcher
end

-- Helper: añadir cierre por OnLeave con delay a un menuFrame
-- Cancela si el cursor regresa al menuFrame o al botón que lo abrió
local function AddLeaveTimer(menuFrame, closeFn, btnParent)
    local leaveTimer = nil
    local DELAY = 0.4

    local ticker = CreateFrame("Frame")
    ticker.t = 0
    ticker.active = false
    ticker:SetScript("OnUpdate", function(self, elapsed)
        if not self.active then return end
        self.t = self.t + elapsed
        if self.t >= DELAY then
            self.active = false
            self:SetScript("OnUpdate", nil)
            -- Verificar que cursor no esté sobre el menuFrame ni sobre btnParent
            if menuFrame:IsShown() then
                closeFn()
            end
        end
    end)

    menuFrame:SetScript("OnEnter", function() ticker.active = false ticker.t = 0 end)
    menuFrame:SetScript("OnLeave", function()
        -- Solo iniciar timer si el cursor no se fue hacia un submenu
        ticker.t = 0
        ticker.active = true
    end)
end
local function HideAllTabContent()
    ProChat.Core:CloseAllMenus()  -- cerrar menús al cambiar de pestaña
    local UI = ProChat.UI
    local Frames = ProChat.Frames
    local chatWin = Frames.chatWin
    
    if chatWin.text then chatWin.text:Hide() end
    if chatWin.raidText then chatWin.raidText:Hide() end
    if UI.raidWin then UI.raidWin:Hide() end

    for _, elementName in ipairs(ProChat.Core.OptionsElements) do
        if UI[elementName] then UI[elementName]:Hide() end
    end
    
    if UI.searchBox then UI.searchBox:Hide() end
    if UI.filterDropBtn then UI.filterDropBtn:Hide() end
    if UI.searchLabel then UI.searchLabel:Hide() end
    -- Fix 6: checkOptions NUNCA se oculta aquí
    if UI.checkOptions then UI.checkOptions:Hide() end
    if UI.checkOptions and UI.checkOptions.switchLabel then UI.checkOptions.switchLabel:Hide() end
    if UI.globalClear then UI.globalClear:Hide() end
    if UI.autoLFGSwitch then UI.autoLFGSwitch:Hide() end
    if UI.fontSlider then UI.fontSlider:Hide() end
    if chatWin.resizer then chatWin.resizer:Hide() end
    if UI.lfmDrop then UI.lfmDrop:Hide() end
    if chatWin.lfmWin then chatWin.lfmWin:Hide() end
    if UI.lfmRefreshBtn then UI.lfmRefreshBtn:Hide() end
    if UI.lfmGenerateBtn then UI.lfmGenerateBtn:Hide() end
    if UI.lfmFavSwitch then UI.lfmFavSwitch:Hide() end
    if UI.lfmFavSwitch and UI.lfmFavSwitch._label then UI.lfmFavSwitch._label:Hide() end
    if UI.lfmTypeDrop then UI.lfmTypeDrop:Hide() end
    if UI.lfmAddonDrop then UI.lfmAddonDrop:Hide() end
    -- FIX BUG 5: Ocultar ojo y texto de estado de Auto-LFG al cambiar de pestaña
    if UI.autoLFGEye then UI.autoLFGEye:Hide() end
    if UI.autoLFGEye and UI.autoLFGEye.statusText then UI.autoLFGEye.statusText:Hide() end
    -- Fix 5: ocultar switchLabels también
    local switchKeys = {"checkGrays", "autoLFGSwitch", "checkMM", "checkRaid"}
    for _, key in ipairs(switchKeys) do
        local sw = UI[key]
        if sw and sw.switchLabel then sw.switchLabel:Hide() end
    end
    if UI.checkRaidTitle then UI.checkRaidTitle:Hide() end

    if chatWin.roleButtons then
        for _, btn in pairs(chatWin.roleButtons) do
            btn:Hide()
        end
    end
    -- Ocultar título de roles (cambio 5)
    if chatWin.roleTitleLabel then chatWin.roleTitleLabel:Hide() end

    -- Desactivar todas las pestañas
    if UI.tabLFG  then UI.tabLFG:SetActive(false)  end
    if UI.tabLFM  then UI.tabLFM:SetActive(false)  end
    if UI.tabRAID then UI.tabRAID:SetActive(false) end
    if UI.tabREG  then UI.tabREG:SetActive(false)  end
end

-- ===== SELECT TAB (FIX #6 - Refactorizado) =====
function ProChat.Core:SelectTab(tabName)
    local chatWin = ProChat.Frames.chatWin
    local UI = ProChat.UI
    local Frames = ProChat.Frames
    ProChatDB.currentTab = tabName
    
    if chatWin.isMinimized then
        chatWin:HideContent()
        return
    end
    
    ProChat.Data.currentTab = tabName
    
    -- Ocultar todo primero
    HideAllTabContent()
    
    local showOptions = false
    if UI.checkOptions and UI.checkOptions:GetChecked() then
        showOptions = true
    end
    
    if tabName == "LFG" then
        -- === MOSTRAR ELEMENTOS DE LFG ===
        if Frames.chatWin.text then Frames.chatWin.text:Show() end
        
        -- Raid panel según configuración
        if UI.raidWin then
            if ProChat.Data.showRaidWin then
                UI.raidWin:Show()
            end
        end
        
        -- Elementos siempre visibles en LFG
        if UI.langDrop then UI.langDrop:Show() end
        if UI.searchBox then UI.searchBox:Show() end
        if UI.searchLabel then UI.searchLabel:Show() end
        if UI.checkOptions then UI.checkOptions:Show() end 
        if UI.checkOptions and UI.checkOptions.switchLabel then UI.checkOptions.switchLabel:Show() end -- siempre visible (fix 6)
        if UI.globalClear then UI.globalClear:Show() end
        if UI.fontSlider then UI.fontSlider:Show() end      -- siempre visible en LFG, independiente de opciones
        if Frames.chatWin.resizer then Frames.chatWin.resizer:Show() end

        -- Elementos condicionales (opciones)
        if showOptions then
            if UI.chanDrop then UI.chanDrop:Show() end
            if UI.filterDropBtn then UI.filterDropBtn:Show() end
            if UI.timeDrop then UI.timeDrop:Show() end
            if UI.labelChan then UI.labelChan:Show() end
            if UI.labelDung then UI.labelDung:Show() end
            if UI.labelSpam then UI.labelSpam:Show() end
            if UI.checkMM then UI.checkMM:Show() end
            if UI.checkGrays then UI.checkGrays:Show() end
            if UI.checkRaid then UI.checkRaid:Show() end
            if UI.autoLFGSwitch then UI.autoLFGSwitch:Show() end
            -- Fix 5: mostrar labels de switches cuando opciones está activo
            local switchKeys = {"checkGrays", "autoLFGSwitch", "checkMM", "checkRaid"}
            for _, key in ipairs(switchKeys) do
                local sw = UI[key]
                if sw and sw.switchLabel then sw.switchLabel:Show() end
            end
            if UI.checkRaidTitle then UI.checkRaidTitle:Show() end
            -- Botones de roles y su título SOLO si Auto-LFG está activo
            local autoLFGActive = ProChat.Data.autoLFGActive
            if Frames.chatWin.roleButtons then
                for _, btn in pairs(Frames.chatWin.roleButtons) do
                    if autoLFGActive then btn:Show() else btn:Hide() end
                end
            end
            if Frames.chatWin.roleTitleLabel then
                if autoLFGActive then Frames.chatWin.roleTitleLabel:Show() else Frames.chatWin.roleTitleLabel:Hide() end
            end
        end
        
        if UI.tabLFG then UI.tabLFG:SetActive(true) end
        -- FIX BUG 5: Mostrar ojo y estado de Auto-LFG solo en pestaña LFG
        if UI.autoLFGEye then UI.autoLFGEye:Show() end
        if UI.autoLFGEye and UI.autoLFGEye.statusText then UI.autoLFGEye.statusText:Show() end
        DeferRefresh()
        
    elseif tabName == "Raid" then
        -- === MOSTRAR ELEMENTOS DE RAID ===
        if chatWin.text then chatWin.text:Hide() end
        if chatWin.raidText then chatWin.raidText:Show() end
        if chatWin.resizer then chatWin.resizer:Show() end
        if UI.lfmRefreshBtn then UI.lfmRefreshBtn:Show() end
        if UI.tabRAID then UI.tabRAID:SetActive(true) end
        DeferRaidList()
        
    elseif tabName == "RAID" then
        -- Pestaña RAID (nueva, vacía por ahora)
        if UI.tabRAID then UI.tabRAID:SetActive(true) end
        
    elseif tabName == "REG" then
        -- Pestaña REG (nueva, vacía por ahora)
        if UI.tabREG then UI.tabREG:SetActive(true) end

    else
        -- === LFM ===
        if not UI.lfmDrop then
            UI.lfmDrop = ProChat.Events:CreateLFMDropdown(Frames.chatWin)
        end
        if UI.lfmDrop then UI.lfmDrop:Show() end
        if Frames.chatWin.lfmWin then
            Frames.chatWin.lfmWin:Show()
            -- Mostrar los 3 paneles vacíos de inmediato, sin esperar búsqueda
            if ProChat.Events and ProChat.Events.InitLFMPanels then
                ProChat.Events:InitLFMPanels()
            end
        end
        
        if UI.tabLFM then UI.tabLFM:SetActive(true) end

        -- ===== SWITCH "Fav. primero" (Bug 2) =====
        if not UI.lfmFavSwitch then
            local sw = CreateFrame("Button", "PC_LFMFavSwitch", Frames.chatWin)
            sw:SetSize(10, 10)
            -- Se posiciona a la derecha del lfmDrop
            sw:SetPoint("LEFT", UI.lfmDrop, "RIGHT", 6, 0)
            sw:SetFrameLevel(Frames.chatWin:GetFrameLevel() + 3)

            local swBg = sw:CreateTexture(nil, "BACKGROUND")
            swBg:SetAllPoints()
            swBg:SetTexture(0.15, 0.15, 0.15, 1)
            sw._bg = swBg

            local swDot = sw:CreateTexture(nil, "OVERLAY")
            swDot:SetSize(6, 6)
            swDot:SetPoint("CENTER")
            swDot:SetTexture(0.3, 0.3, 0.3, 1)
            sw._dot = swDot

            local swLabel = Frames.chatWin:CreateFontString(nil, "OVERLAY")
            swLabel:SetFont("Fonts\\FRIZQT__.TTF", 8)
            swLabel:SetPoint("LEFT", sw, "RIGHT", 3, 0)
            swLabel:SetText(L["FAV_TITLE"])
            swLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            sw._label = swLabel

            sw._active = ProChat.Data.lfmFavFirst or false

            local function updateSwitch(self)
                if self._active then
                    self._dot:SetTexture(1, 0.84, 0, 1)
                    self._label:SetTextColor(1, 0.84, 0, 1)
                else
                    self._dot:SetTexture(0.3, 0.3, 0.3, 1)
                    self._label:SetTextColor(0.7, 0.7, 0.7, 1)
                end
            end
            updateSwitch(sw)

            sw:SetScript("OnClick", function(self)
                self._active = not self._active
                ProChat.Data.lfmFavFirst = self._active
                updateSwitch(self)
                ProChat.Events:RefreshLFMTable()
            end)
            sw:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["FAV_FIRST"], 1, 0.84, 0)
                GameTooltip:AddLine(L["FAV_FIRST_DESC"], 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end)
            sw:SetScript("OnLeave", function() GameTooltip:Hide() end)

            UI.lfmFavSwitch = sw
        end
        if UI.lfmFavSwitch then UI.lfmFavSwitch:Show() end
        if UI.lfmFavSwitch and UI.lfmFavSwitch._label then UI.lfmFavSwitch._label:Show() end

        -- ===== DROPDOWN "Tipo de Raid" (Bug 7a) =====
        if not UI.lfmTypeDrop then
            local TIPOS = {
                { key="farm",    esText="Por Farm",      enText="Farm Run"   },
                { key="abalorios", esText="Por Abalorios", enText="Gear Run" },
                { key="todo",    esText="Por Todo",      enText="Any"        },
            }

            local tBtn = CreateFrame("Button", "PC_LFMTypeDrop", Frames.chatWin)
            tBtn:SetSize(80, 18)
            -- Posicionar a la derecha del switch de favoritos
            tBtn:SetPoint("LEFT", UI.lfmFavSwitch._label, "RIGHT", 8, 0)
            tBtn:SetFrameLevel(Frames.chatWin:GetFrameLevel() + 3)
            tBtn:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = {left=0,right=0,top=0,bottom=0}
            })
            tBtn:SetBackdropColor(0, 0.08, 0.08, 0.97)
            tBtn:SetBackdropBorderColor(0, 1, 0.8, 0.8)

            local tText = tBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tText:SetPoint("LEFT", tBtn, "LEFT", 6, 0)
            tText:SetFont("Fonts\\FRIZQT__.TTF", 9)
            tText:SetText("|cff00FFCCTipo|r")

            local tArrow = tBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tArrow:SetPoint("RIGHT", tBtn, "RIGHT", -4, 0)
            tArrow:SetText("v")
            tArrow:SetTextColor(0, 1, 0.8, 1)

            local tMenu = nil
            local function closeTypeMenu()
                if tMenu then tMenu:Hide() tMenu = nil end
            end

            tBtn:SetScript("OnClick", function()
                if tMenu then closeTypeMenu() return end
                local lang = (ProChatDB and ProChatDB.lang) or "es"
                tMenu = CreateFrame("Frame", nil, UIParent)
                tMenu:SetFrameStrata("TOOLTIP")
                tMenu:SetFrameLevel(400)
                tMenu:SetWidth(90)
                tMenu:SetHeight(#TIPOS * 20 + 4)
                tMenu:SetPoint("TOPLEFT", tBtn, "BOTTOMLEFT", 0, -1)
                tMenu:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = true, tileSize = 16, edgeSize = 1,
                    insets = {left=0,right=0,top=0,bottom=0}
                })
                tMenu:SetBackdropColor(0, 0.08, 0.08, 0.97)
                tMenu:SetBackdropBorderColor(0, 1, 0.8, 0.8)
                tMenu:Show()

                for i, item in ipairs(TIPOS) do
                    local row = CreateFrame("Button", nil, tMenu)
                    row:SetSize(88, 20)
                    row:SetPoint("TOPLEFT", tMenu, "TOPLEFT", 1, -(i-1)*20 - 2)
                    row:SetFrameLevel(tMenu:GetFrameLevel() + 2)
                    local rowBg = row:CreateTexture(nil, "BACKGROUND")
                    rowBg:SetAllPoints()
                    rowBg:SetTexture(0,0,0,0)
                    local rowTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    rowTxt:SetPoint("LEFT", row, "LEFT", 8, 0)
                    rowTxt:SetFont("Fonts\\FRIZQT__.TTF", 9)
                    local label = (lang=="es") and item.esText or item.enText
                    local isActive = (ProChat.Data.lfmRaidType == item.key)
                    rowTxt:SetText(isActive and ("|cff00FFCC"..label.."|r") or ("|cff666666"..label.."|r"))
                    row:SetScript("OnEnter", function() rowBg:SetTexture(0,0.15,0.15,0.8) end)
                    row:SetScript("OnLeave", function() rowBg:SetTexture(0,0,0,0) end)
                    row:SetScript("OnClick", function()
                        ProChat.Data.lfmRaidType = item.key
                        local lbl = (lang=="es") and item.esText or item.enText
                        tText:SetText("|cff00FFCC"..lbl.."|r")
                        closeTypeMenu()
                    end)
                end

                tMenu:SetScript("OnUpdate", function(self)
                    if not self:IsShown() then return end
                    local mx, my = GetCursorPosition()
                    local sc = self:GetEffectiveScale()
                    if mx < self:GetLeft()*sc or mx > self:GetRight()*sc
                    or my < self:GetBottom()*sc or my > self:GetTop()*sc then
                        closeTypeMenu()
                    end
                end)
            end)

            UI.lfmTypeDrop = tBtn
        end
        if UI.lfmTypeDrop then UI.lfmTypeDrop:Show() end

        -- ===== DROPDOWN "Complementos" (Bug 7b) =====
        if not UI.lfmAddonDrop then
            local ADDONS = { "Discord", "DBM", "WeakAuras", "PallyPower" }
            if not ProChat.Data.lfmSelectedAddons then
                ProChat.Data.lfmSelectedAddons = {}
            end

            local aBtn = CreateFrame("Button", "PC_LFMAddonDrop", Frames.chatWin)
            aBtn:SetSize(85, 18)
            aBtn:SetPoint("LEFT", UI.lfmTypeDrop, "RIGHT", 4, 0)
            aBtn:SetFrameLevel(Frames.chatWin:GetFrameLevel() + 3)
            aBtn:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = {left=0,right=0,top=0,bottom=0}
            })
            aBtn:SetBackdropColor(0, 0.08, 0.08, 0.97)
            aBtn:SetBackdropBorderColor(0, 1, 0.8, 0.8)

            local aText = aBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            aText:SetPoint("LEFT", aBtn, "LEFT", 6, 0)
            aText:SetFont("Fonts\\FRIZQT__.TTF", 9)
            aText:SetText("|cff00FFCCComps.|r")

            local aArrow = aBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            aArrow:SetPoint("RIGHT", aBtn, "RIGHT", -4, 0)
            aArrow:SetText("v")
            aArrow:SetTextColor(0, 1, 0.8, 1)

            local aMenu = nil
            local function closeAddonMenu()
                if aMenu then aMenu:Hide() aMenu = nil end
            end

            local function refreshAddonText()
                local sel = {}
                for _, a in ipairs(ADDONS) do
                    if ProChat.Data.lfmSelectedAddons[a] then
                        table.insert(sel, a)
                    end
                end
                if #sel == 0 then
                    aText:SetText("|cff00FFCCComps.|r")
                else
                    aText:SetText("|cff00FFCC"..#sel.." sel.|r")
                end
            end

            aBtn:SetScript("OnClick", function()
                if aMenu then closeAddonMenu() return end
                aMenu = CreateFrame("Frame", nil, UIParent)
                aMenu:SetFrameStrata("TOOLTIP")
                aMenu:SetFrameLevel(400)
                aMenu:SetWidth(95)
                aMenu:SetHeight(#ADDONS * 20 + 4)
                aMenu:SetPoint("TOPLEFT", aBtn, "BOTTOMLEFT", 0, -1)
                aMenu:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = true, tileSize = 16, edgeSize = 1,
                    insets = {left=0,right=0,top=0,bottom=0}
                })
                aMenu:SetBackdropColor(0, 0.08, 0.08, 0.97)
                aMenu:SetBackdropBorderColor(0, 1, 0.8, 0.8)
                aMenu:Show()

                for i, addon in ipairs(ADDONS) do
                    local row = CreateFrame("Button", nil, aMenu)
                    row:SetSize(93, 20)
                    row:SetPoint("TOPLEFT", aMenu, "TOPLEFT", 1, -(i-1)*20 - 2)
                    row:SetFrameLevel(aMenu:GetFrameLevel() + 2)
                    local rowBg = row:CreateTexture(nil, "BACKGROUND")
                    rowBg:SetAllPoints()
                    rowBg:SetTexture(0,0,0,0)
                    local rowTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    rowTxt:SetPoint("LEFT", row, "LEFT", 8, 0)
                    rowTxt:SetFont("Fonts\\FRIZQT__.TTF", 9)
                    local function updateRow()
                        local checked = ProChat.Data.lfmSelectedAddons[addon]
                        rowTxt:SetText(checked and ("|cff00FFCC[x] "..addon.."|r") or ("|cff666666[ ] "..addon.."|r"))
                    end
                    updateRow()
                    row:SetScript("OnEnter", function() rowBg:SetTexture(0,0.15,0.15,0.8) end)
                    row:SetScript("OnLeave", function() rowBg:SetTexture(0,0,0,0) end)
                    row:SetScript("OnClick", function()
                        ProChat.Data.lfmSelectedAddons[addon] = not ProChat.Data.lfmSelectedAddons[addon] or nil
                        updateRow()
                        refreshAddonText()
                    end)
                end

                aMenu:SetScript("OnUpdate", function(self)
                    if not self:IsShown() then return end
                    local mx, my = GetCursorPosition()
                    local sc = self:GetEffectiveScale()
                    if mx < self:GetLeft()*sc or mx > self:GetRight()*sc
                    or my < self:GetBottom()*sc or my > self:GetTop()*sc then
                        closeAddonMenu()
                    end
                end)
            end)

            UI.lfmAddonDrop = aBtn
        end
        if UI.lfmAddonDrop then UI.lfmAddonDrop:Show() end

        -- ===== BOTÓN ACTUALIZAR con efecto push (Bug 1) =====
        if not UI.lfmRefreshBtn then
            local btn = CreateFrame("Button", "PC_LFMRefreshBtn", Frames.chatWin)
            btn:SetSize(60, 16)
            btn:SetPoint("BOTTOMLEFT", Frames.chatWin, "BOTTOMLEFT", 8, 8)
            btn:SetFrameLevel(Frames.chatWin:GetFrameLevel() + 3)

            -- Textura de fondo normal
            local bgNormal = btn:CreateTexture(nil, "BACKGROUND")
            bgNormal:SetAllPoints()
            bgNormal:SetTexture(0, 0.08, 0.08, 1)
            btn._bgN = bgNormal

            -- Borde
            btn:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = {left=0,right=0,top=0,bottom=0}
            })
            btn:SetBackdropColor(0, 0.08, 0.08, 1)
            btn:SetBackdropBorderColor(0, 1, 0.8, 0.8)

            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btnText:SetAllPoints()
            btnText:SetJustifyH("CENTER")
            btnText:SetJustifyV("MIDDLE")
            btnText:SetFont("Fonts\\FRIZQT__.TTF", 9)
            btnText:SetText(ProChat.L["LFM_REFRESH"] or "Actualizar")
            btnText:SetTextColor(0, 1, 0.8, 1)

            -- Efecto push real: mover contenido 1px al presionar
            btn:SetScript("OnMouseDown", function(self)
                self:SetBackdropColor(0, 0.18, 0.18, 1)
                btnText:ClearAllPoints()
                btnText:SetPoint("CENTER", self, "CENTER", 1, -1)
            end)
            btn:SetScript("OnMouseUp", function(self)
                self:SetBackdropColor(0, 0.08, 0.08, 1)
                btnText:ClearAllPoints()
                btnText:SetAllPoints()
            end)
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(0, 1, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(ProChat.L["LFM_REFRESH"] or "Actualizar", 0, 1, 0.8)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(0, 1, 0.8, 0.8)
                GameTooltip:Hide()
            end)
            btn:SetScript("OnClick", function()
                if LFRBrowseFrameRefreshButton then
                    LFRBrowseFrameRefreshButton:Click()
                end
                local f = CreateFrame("Frame")
                f.t = 0
                f:SetScript("OnUpdate", function(self, elapsed)
                    self.t = self.t + elapsed
                    if self.t >= 1.0 then
                        self:SetScript("OnUpdate", nil)
                        ProChat.Events:RefreshLFMTable()
                    end
                end)
            end)

            UI.lfmRefreshBtn = btn
        end
        if UI.lfmRefreshBtn then UI.lfmRefreshBtn:Show() end

        -- ===== BOTÓN GENERAR (Bug 8b) =====
        if not UI.lfmGenerateBtn then
            local gBtn = CreateFrame("Button", "PC_LFMGenerateBtn", Frames.chatWin)
            gBtn:SetSize(60, 16)
            gBtn:SetPoint("LEFT", UI.lfmRefreshBtn, "RIGHT", 6, 0)
            gBtn:SetFrameLevel(Frames.chatWin:GetFrameLevel() + 3)
            gBtn:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = {left=0,right=0,top=0,bottom=0}
            })
            gBtn:SetBackdropColor(0.05, 0.02, 0.1, 1)
            gBtn:SetBackdropBorderColor(0.5, 0.2, 1, 0.8)

            local gText = gBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            gText:SetAllPoints()
            gText:SetJustifyH("CENTER")
            gText:SetJustifyV("MIDDLE")
            gText:SetFont("Fonts\\FRIZQT__.TTF", 9)
            gText:SetText("Generar")
            gText:SetTextColor(0.7, 0.4, 1, 1)

            gBtn:SetScript("OnMouseDown", function(self)
                self:SetBackdropColor(0.1, 0.04, 0.2, 1)
                gText:ClearAllPoints()
                gText:SetPoint("CENTER", self, "CENTER", 1, -1)
            end)
            gBtn:SetScript("OnMouseUp", function(self)
                self:SetBackdropColor(0.05, 0.02, 0.1, 1)
                gText:ClearAllPoints()
                gText:SetAllPoints()
            end)
            gBtn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(0.7, 0.4, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Generar", 0.7, 0.4, 1)
                GameTooltip:AddLine("Proximamente...", 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            gBtn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(0.5, 0.2, 1, 0.8)
                GameTooltip:Hide()
            end)
            gBtn:SetScript("OnClick", function() end)  -- por ahora no hace nada

            UI.lfmGenerateBtn = gBtn
        end
        if UI.lfmGenerateBtn then UI.lfmGenerateBtn:Show() end
    end
    if UI.langDrop then UI.langDrop:Show() end
end


-- ===== REFRESH UI ICONS AND LABELS (FIX #7 - Unificado) =====
function ProChat.Core:RefreshUIIconsAndLabels()
    -- Actualizar etiquetas de texto (Labels)
    if UI.labelChan then UI.labelChan:SetText(L["SELECT_CHAN"] or "Seleccionar canales:") end
    if UI.labelDung then UI.labelDung:SetText(L["SELECT_DUNGEON"] or "Seleccionar mazmorra:") end
    if UI.labelSpam then UI.labelSpam:SetText(L["SELECT_SPAM"] or "Tiempo por msg:") end
    if UI.searchLabel then UI.searchLabel:SetText(L["SEARCH_LABEL"] or ":Buscar") end

    -- Botones y Checkboxes
    if UI.globalClear then UI.globalClear:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT") GameTooltip:AddLine(L["CLEAN_BTN"] or "Limpiar",1,1,1) GameTooltip:Show() end) end

    -- Títulos de Ventanas
    if Frames.chatWin and Frames.chatWin.titleText then 
        Frames.chatWin.titleText:SetText("|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r |cffFF4D4Dv"..ProChat.CURRENT_VERSION.."|r") 
    end
    
    if UI.welcomeTitle then UI.welcomeTitle:SetText(L["WELCOME_TITLE"]) end
    if UI.welcomeText then UI.welcomeText:SetText(L["WELCOME_TEXT"] .. ProChat.CURRENT_VERSION .. "\n\nUsa |cffFFD100/pc|r para empezar.") end
    if UI.welcomeButton then UI.welcomeButton:SetText(L["WELCOME_BTN"]) end
    
    if UI.credTitle then UI.credTitle:SetText(L["CREDITS_TITLE"]) end
    if UI.credText then UI.credText:SetText(L["CREDITS_TEXT"]) end
    if UI.credButton then UI.credButton:SetText(L["CREDITS_BTN"]) end

    -- Dropdowns (Texto superior/visible)
    if UI.chanDrop and UI.chanDrop._refreshText then 
        UI.chanDrop._refreshText()
    end
    ProChat.Core:RefreshFilterDropBtnText()

    if UI.langDrop and UI.langDropText then
        local currentLangText = (ProChatDB.lang == "es") and "Esp" or "Eng"
        UI.langDropText:SetText(currentLangText)
    end
end

-- ===== CREATE UI ELEMENTS =====
function ProChat.Core:CreateUI()
    local chatWin = Frames.chatWin

    -- Language dropdown (header, esquina izquierda)
    UI.langDrop = self:CreateLanguageDropdown(chatWin)

    -- Opacity slider (header, pegado al langDrop)
    UI.opacitySlider = self:CreateOpacitySlider(chatWin)

    UI.checkGrays    = self:CreateSwitch("PC_SwitchGrays",   chatWin, "TOPLEFT", 20, -30, L["HIDE_GRAYS"] or "Ocultar Spam", false)
    UI.autoLFGSwitch = self:CreateSwitch("PC_SwitchAutoLFG", chatWin, "TOPLEFT", 0, -20, "|cff00FFCCAuto-LFG|r", false, true)
    UI.autoLFGSwitch:ClearAllPoints()
    UI.autoLFGSwitch:SetPoint("LEFT", UI.checkGrays.switchLabel, "RIGHT", 60, 0)
    UI.checkMM = self:CreateSwitch("PC_SwitchMM", chatWin, "TOPLEFT", 0, -20, "Minimap", false)
    UI.checkMM:ClearAllPoints()
    UI.checkMM:SetPoint("LEFT", UI.autoLFGSwitch.switchLabel, "RIGHT", 70, 0)
    UI.checkRaid = self:CreateSwitch("PC_SwitchRaid", chatWin, "TOPRIGHT", -40, -35, "", true)
    do
        local raidTitle = chatWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        raidTitle:SetPoint("BOTTOM", UI.checkRaid, "TOP", 0, 2)
        raidTitle:SetFont("Fonts\\FRIZQT__.TTF", 8)
        raidTitle:SetText(L["SHOW_LEADERS"] or "Raids Activas")
        raidTitle:SetTextColor(1, 1, 1, 0.9)
        UI.checkRaidTitle = raidTitle
    end

    -- ===== FILA 2: Dropdowns anclados BAJO su switch correspondiente =====
    UI.chanDrop      = self:CreateChannelDropdown(chatWin)
    UI.filterDropBtn = self:CreateFilterDropdown(chatWin)
    if Frames.chatWin.roleButtons then
        for role, btn in pairs(Frames.chatWin.roleButtons) do
            local idx = btn._roleIndex or 1
            btn:ClearAllPoints()
            btn:SetPoint("LEFT", UI.filterDropBtn, "RIGHT", 6 + ((idx-1) * 22), 0)
        end
    end
    if Frames.chatWin.roleTitleLabel then
        local firstBtn = nil
        local firstIdx = 999
        for _, btn in pairs(Frames.chatWin.roleButtons or {}) do
            if (btn._roleIndex or 1) < firstIdx then
                firstIdx = btn._roleIndex or 1
                firstBtn = btn
            end
        end
        Frames.chatWin.roleTitleLabel:ClearAllPoints()
        if firstBtn then
            Frames.chatWin.roleTitleLabel:SetPoint("BOTTOMLEFT", firstBtn, "TOPLEFT", 0, 2)
        else
            Frames.chatWin.roleTitleLabel:SetPoint("LEFT", UI.filterDropBtn, "RIGHT", 6, 12)
        end
    end   -- bajo autoLFGSwitch
    UI.timeDrop      = self:CreateTimeDropdown(chatWin)

    -- Font slider: izquierda del selector canales, a la altura de Raids Activas
    UI.fontSlider = self:CreateFontSlider(chatWin)

    -- Checkbox Opciones (esquina superior derecha del header, marco morado custom)
    UI.checkOptions = self:CreateOptionsCheckbox("PC_CheckOptions", chatWin)

    -- Botón Limpiar (escoba) — esquina inferior izquierda
    UI.globalClear = self:CreateBroomButton(chatWin)

    -- Search box — a la derecha del botón limpiar; label a la derecha de la caja
    UI.searchBox = self:CreateSearchBox(chatWin)
    UI.searchLabel = chatWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.searchLabel:SetPoint("LEFT", UI.searchBox, "RIGHT", 6, 0)
    UI.searchLabel:SetText(L["SEARCH_LABEL"] or ":Buscar")
    UI.searchLabel:SetTextColor(1, 1, 1, 1)

    -- Labels legacy (ocultos, por compatibilidad)
    UI.labelChan = chatWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.labelDung = chatWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.labelSpam = chatWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.labelChan:Hide() UI.labelDung:Hide() UI.labelSpam:Hide()

    self:SetupCheckboxScripts()

    self.uiElements = {
        UI.chanDrop, UI.filterDropBtnText, UI.timeDrop,
        UI.labelChan, UI.labelDung, UI.labelSpam,
        UI.checkMM, UI.checkGrays, UI.checkRaid,
    }

    if chatWin.UpdateLayout then chatWin.UpdateLayout() end

    if Frames.chatWin.raidText then
        Frames.chatWin.raidText:EnableMouseWheel(true)
        Frames.chatWin.raidText:SetScript("OnMouseWheel", function(self, delta)
            if delta > 0 then self:ScrollDown() else self:ScrollUp() end
        end)
    end
end

-- ===== CREATE OPTIONS CHECKBOX (cuadrado morado custom) =====
function ProChat.Core:CreateOptionsCheckbox(name, parent)
    local SIZE = 12
    local container = CreateFrame("Frame", name, parent)
    container:SetSize(SIZE, SIZE)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -52, -3)
    container:SetFrameLevel(parent:GetFrameLevel() + 10)

    -- Marco exterior morado
    local border = container:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetTexture(0.55, 0.1, 0.75, 1)

    -- Interior negro (fondo)
    local inner = container:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    inner:SetTexture(0.05, 0.05, 0.05, 1)

    -- Cuadro blanco interior (indicador de marcado)
    local mark = container:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", container, "TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -3, 3)
    mark:SetTexture(1, 1, 1, 0.95)
    mark:Hide()  -- oculto = desmarcado

    -- Etiqueta "Opciones" a la izquierda
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("RIGHT", container, "LEFT", -4, 0)
    lbl:SetText(L["OPTIONS_CHECK"] or "Opciones")
    lbl:SetTextColor(1, 1, 1, 1)
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 9)
    container.switchLabel = lbl

    -- Botón invisible para click
    local btn = CreateFrame("Button", nil, container)
    btn:SetAllPoints()
    container.btn = btn
    container.markTex = mark
    container.checked = true  -- por defecto activo
    mark:Show()

    container.GetChecked = function(self) return self.checked end
    container.SetChecked = function(self, val)
        self.checked = val and true or false
        if self.checked then mark:Show() else mark:Hide() end
    end
    container.Click = function(self)
        self.checked = not self.checked
        if self.checked then mark:Show() else mark:Hide() end
        if self.OnClickScript then self.OnClickScript(self) end
    end
    container.SetScript = function(self, event, func)
        if event == "OnClick" then
            self.OnClickScript = func
            self.btn:SetScript("OnClick", function() self:Click() end)
        else
            getmetatable(self).__index.SetScript(self, event, func)
        end
    end

    return container
end
-- ===== CREATE SWITCH =====
-- isCeleste = true → celeste (Auto-LFG), false → morado
function ProChat.Core:CreateSwitch(name, parent, point, x, y, text, defaultOn, isCeleste)
    local SW, SH = 25, 10  -- más pequeño

    local container = CreateFrame("Frame", name, parent)
    container:SetSize(SW, SH)
    container:SetPoint(point, x, y)

    local colOnR, colOnG, colOnB = isCeleste and 0 or 0.44, isCeleste and 0.8 or 0.13, isCeleste and 0.7 or 0.56
    local colOffR, colOffG, colOffB = 0.22, 0.22, 0.22

    local track = container:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetTexture(colOffR, colOffG, colOffB, 1)

    local thumb = container:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(SH - 2, SH - 2)
    thumb:SetTexture(1, 1, 1, 0.95)
    thumb:SetPoint("LEFT", container, "LEFT", 1, 0)

    container.track = track
    container.thumb = thumb
    container.checked = defaultOn or false

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", container, "RIGHT", 4, 0)
    lbl:SetText(text)
    lbl:SetTextColor(1, 1, 1, 1)
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 8)
    container.switchLabel = lbl

    local btn = CreateFrame("Button", nil, container)
    btn:SetAllPoints()
    container.btn = btn

    local function applyState(c)
        if c.checked then
            c.track:SetTexture(colOnR, colOnG, colOnB, 1)
            c.thumb:ClearAllPoints()
            c.thumb:SetPoint("RIGHT", c, "RIGHT", -1, 0)
        else
            c.track:SetTexture(colOffR, colOffG, colOffB, 1)
            c.thumb:ClearAllPoints()
            c.thumb:SetPoint("LEFT", c, "LEFT", 1, 0)
        end
    end

    container.GetChecked = function(self) return self.checked end
    container.SetChecked = function(self, val)
        self.checked = val and true or false
        applyState(self)
    end
    container.Click = function(self)
        self.checked = not self.checked
        applyState(self)
        if self.OnClickScript then self.OnClickScript(self) end
    end
    container.SetScript = function(self, event, func)
        if event == "OnClick" then
            self.OnClickScript = func
            self.btn:SetScript("OnClick", function() self:Click() end)
        else
            getmetatable(self).__index.SetScript(self, event, func)
        end
    end

    applyState(container)
    return container
end

-- ===== CREATE BROOM BUTTON =====
function ProChat.Core:CreateBroomButton(parent)
    local btn = CreateFrame("Button", "PC_BroomBtn", parent)
    btn:SetSize(20, 20)
    btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
    btn:SetFrameLevel(parent:GetFrameLevel() + 3)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\AddOns\\!ProChat_IA\\Media\\pcia_icons_g1")
    icon:SetVertexColor(0.85, 0.85, 0.85, 1)
    icon:SetTexCoord(0, 0.5, 0, 0.5)

    btn:SetScript("OnEnter", function(self)
        icon:SetVertexColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["CLEAN_BTN"] or "Limpiar", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        icon:SetVertexColor(0.85, 0.85, 0.85, 1)
        GameTooltip:Hide()
    end)

    return btn
end

-- ===== CREATE CHANNEL DROPDOWN (FULL CUSTOM - no UIDropDownMenuTemplate) =====
function ProChat.Core:CreateChannelDropdown(parent)
    local menuOpen = false
    local menuFrame = nil
    local W = 100

    local function getCount()
        local count = 0
        for _, v in pairs(Data.selectedChannels) do if v then count = count + 1 end end
        return count
    end

    -- Botón principal
    local btn = CreateFrame("Button", "PC_ChanDrop", parent)
    btn:SetSize(70, 20)
    btn:SetPoint("TOPLEFT", ProChat.UI.checkGrays, "BOTTOMLEFT", 7, -10)
    btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Buttons\\WHITE8X8",tile=true,tileSize=16,edgeSize=1,insets={left=0,right=0,top=0,bottom=0}})
    btn:SetBackdropColor(0.06, 0.0, 0.1, 0.97)
    btn:SetBackdropBorderColor(0.55, 0.1, 0.75, 0.9)
    btn:SetFrameLevel(parent:GetFrameLevel() + 3)
    btn:SetScript("OnEnter", function() btn:SetBackdropColor(0.1, 0.02, 0.18, 0.97) end)
    btn:SetScript("OnLeave", function() btn:SetBackdropColor(0.06, 0.0, 0.1, 0.97) end)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    btnText:SetText(getCount() .. " " .. (L["CHANNELS_TEXT"] or "Canales"))
    btnText:SetTextColor(0.75, 0.4, 1, 1)

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    arrow:SetFont("Fonts\\FRIZQT__.TTF", 8)
    arrow:SetText("v")
    arrow:SetTextColor(0.75, 0.4, 1, 1)

    local function refreshText()
        btnText:SetText(getCount() .. " " .. (L["CHANNELS_TEXT"] or "Canales"))
    end

    local function closeMenu()
        if menuFrame then menuFrame:Hide() menuFrame = nil end
        menuOpen = false
    end

    local chanActiveColors = {
        ["DECIR"]     = "FFFFFF",
        ["GRITAR"]    = "FF4040",
        ["HERMANDAD"] = "40FF40",
        ["DEFAULT"]   = "FFC0C0",
    }

    local function getChanColor(key)
        return chanActiveColors[key] or chanActiveColors["DEFAULT"]
    end

    local function openMenu()
        local extra = {"Decir", "Gritar", "Hermandad"}
        local channels = { GetChannelList() }
        local items = {}
        for _, name in ipairs(extra) do
            table.insert(items, {text = name, key = name:upper()})
        end
        for i = 1, #channels, 2 do
            table.insert(items, {text = channels[i+1], key = channels[i+1]:upper()})
        end

        -- Calcular W dinámico según el texto más largo (padding: 8 check + 6 texto + 6 derecha = 20)
        local measurer = UIParent:CreateFontString(nil, "ARTWORK")
        measurer:SetFont("Fonts\\FRIZQT__.TTF", 9)
        local maxTextW = 0
        for _, item in ipairs(items) do
            measurer:SetText(item.text)
            local tw = measurer:GetStringWidth()
            if tw > maxTextW then maxTextW = tw end
        end
        measurer:SetText("")
        W = math.ceil(maxTextW) + 26  -- 8 (check) + 6 (gap) + 6 (derecha) + 6 (extra borde)
        btn:SetWidth(W)

        menuFrame = CreateFrame("Frame", nil, UIParent)
        menuFrame:SetFrameStrata("TOOLTIP")
        menuFrame:SetFrameLevel(300)
        menuFrame:SetWidth(W)
        menuFrame:SetHeight(#items * 18 + 4)
        menuFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
        menuFrame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Buttons\\WHITE8X8",tile=true,tileSize=16,edgeSize=1,insets={left=0,right=0,top=0,bottom=0}})
        menuFrame:SetBackdropColor(0.06, 0.0, 0.1, 0.98)
        menuFrame:SetBackdropBorderColor(0.55, 0.1, 0.75, 0.9)
        menuFrame:Show()
        menuOpen = true

        for i, item in ipairs(items) do
            local key = item.key
            local activeColor = getChanColor(key)
            local row = CreateFrame("Button", nil, menuFrame)
            row:SetFrameLevel(menuFrame:GetFrameLevel() + 2)
            row:SetSize(W - 2, 18)
            row:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, -(i-1)*18 - 2)

            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            rowBg:SetTexture(0, 0, 0, 0)

            local check = row:CreateFontString(nil, "OVERLAY")
            check:SetPoint("LEFT", row, "LEFT", 4, 0)
            check:SetFont("Fonts\\FRIZQT__.TTF", 8)

            local rowText = row:CreateFontString(nil, "OVERLAY")
            rowText:SetPoint("LEFT", row, "LEFT", 16, 0)
            rowText:SetFont("Fonts\\FRIZQT__.TTF", 9)

            local function updateRow()
                local active = Data.selectedChannels[key]
                if active then
                    check:SetText("")
                    rowText:SetText("|cff"..activeColor..item.text.."|r")
                else
                    check:SetText("")
                    rowText:SetText("|cffAAAAAA"..item.text.."|r")
                end
            end
            updateRow()

            row:SetScript("OnEnter", function()
                rowBg:SetTexture(0.18, 0.04, 0.28, 0.85)
            end)
            row:SetScript("OnLeave", function()
                rowBg:SetTexture(0, 0, 0, 0)
            end)
            row:SetScript("OnClick", function()
                Data.selectedChannels[key] = not Data.selectedChannels[key]
                ProChatDB.selectedChannels = Data.selectedChannels
                refreshText()
                updateRow()
                Frames.chatWin.text:Clear()
                DeferRefresh()
            end)
        end

        menuFrame:SetScript("OnHide", function() menuOpen = false menuFrame = nil end)

        -- Sistema global
        ProChat.Core:RegisterOpenMenu(closeMenu)
        GetMenuClickCatcher():Show()
        AddLeaveTimer(menuFrame, closeMenu, btn)
    end

    btn:SetScript("OnClick", function()
        if menuOpen then closeMenu() else
            ProChat.Core:CloseAllMenus()
            openMenu()
        end
    end)

    -- Compatibilidad: UIDropDownMenu_SetText en código heredado → actualizar btnText
    btn._refreshText = refreshText
    UI.chanDrop = btn
    UI.chanDropText = btnText

    return btn
end

-- ===== CREATE FILTER DROPDOWN (Custom Frame) =====
function ProChat.Core:CreateFilterDropdown(parent)
    local Data = ProChat.Data
    local L = ProChat.L
    local CYAN = {0, 0.08, 0.08, 0.97}
    local CYAN_BORDER = {0, 1, 0.8, 0.8}
    local COLOR_INACTIVE = "666666"
    local openMenu1 = nil
    local openMenu2 = nil

    -- ===== HELPERS =====
    local function applyBackdrop(f)
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = {left=0, right=0, top=0, bottom=0}
        })
        f:SetBackdropColor(unpack(CYAN))
        f:SetBackdropBorderColor(unpack(CYAN_BORDER))
    end

    -- ===== BUTTON CERRAR TODOS LOS MENUS =====
    local function closeAll()
        if openMenu2 and openMenu2.Hide then 
            openMenu2:Hide()
        end
        openMenu2 = nil
        if openMenu1 and openMenu1.Hide then 
            openMenu1:Hide()
        end
        openMenu1 = nil
    end

    -- ===== FRAME PRINCIPAL (botón del DD) =====
    local btn = CreateFrame("Button", "PC_FilterDropBtn", parent)
    btn:SetSize(70, 18)
    btn:SetPoint("TOPLEFT", ProChat.UI.autoLFGSwitch, "BOTTOMLEFT", 3, -10)
    applyBackdrop(btn)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btnText:SetText(L["ALL_TEXT"] or "TODAS")

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0, 1, 0.8, 1)

    -- Función para actualizar el texto del botón
    local function refreshBtnText()
        if Data.selectedDungeons["TODAS"] then
            btnText:SetText("|cff"..(Data.filterColors["TODAS"] or "B0B0B0")..(L["ALL_TEXT"] or "TODAS").."|r")
        else
            local count = 0
            for _, k in ipairs(Data.keywords) do
                if Data.selectedDungeons[k] then count = count + 1 end
            end
            btnText:SetText("|cff00FFCC"..count.." "..(L["DUNGEONS_TEXT"] or "Raids").."|r")
        end
    end

    -- Función guardar estado
    local function saveState()
        ProChatDB.selectedDungeons = Data.selectedDungeons
        ProChatDB.selectedDifficulties = Data.selectedDifficulties
    end

    -- Función aplicar cambios
    local function applyChanges()
        saveState()
        Frames.chatWin.text:Clear()
        DeferRefresh()
        DeferRaidList()
        refreshBtnText()
        -- FIX 8: Re-apuntar si Auto-LFG está activo
        if ProChat.Data.autoLFGActive then
            ProChat.Core:AutoLFGUpdate()
        end
    end

    -- ===== MENU NIVEL 1 (mazmorras) =====
    local function openMainMenu()
        if openMenu1 then
            closeAll()
            return
        end

        local dungeonOrder = Data.keywords
        local visibleKeys = {}
        for _, k in ipairs(dungeonOrder) do
            if Data:IsDungeonVisible(k) then
                table.insert(visibleKeys, k)
            end
        end

        -- W dinámico: medir el texto más largo entre "TODAS" y las mazmorras visibles
        -- padding: 8 (izq texto) + 16 (flecha ">") + 6 (borde) = 30
        local _meas = UIParent:CreateFontString(nil, "ARTWORK")
        _meas:SetFont("Fonts\\FRIZQT__.TTF", 9)
        local _maxW = 0
        local _allKeys = {"TODAS"}
        for _, k in ipairs(visibleKeys) do table.insert(_allKeys, k) end
        for _, k in ipairs(_allKeys) do
            _meas:SetText(k)
            local tw = _meas:GetStringWidth()
            if tw > _maxW then _maxW = tw end
        end
        _meas:SetText("")
        local menu1W = math.ceil(_maxW) + 30

        local menu1 = CreateFrame("Frame", nil, UIParent)
        menu1:SetFrameStrata("TOOLTIP")
        menu1:SetFrameLevel(300)
        applyBackdrop(menu1)
        menu1:SetWidth(menu1W)
        menu1:SetHeight((#visibleKeys + 1) * 20 + 4)
        menu1:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
        menu1:Show()
        openMenu1 = menu1

        -- Botón TODAS
        local todasRow = CreateFrame("Button", nil, menu1)
        todasRow:SetFrameLevel(menu1:GetFrameLevel() + 2)
        todasRow:SetSize(menu1W - 2, 20)
        todasRow:SetPoint("TOPLEFT", menu1, "TOPLEFT", 1, -2)

        local todasActive = Data.selectedDungeons["TODAS"]
        local todasBg = todasRow:CreateTexture(nil, "BACKGROUND")
        todasBg:SetAllPoints()
        todasBg:SetTexture(0, 0, 0, 0)
        local todasText = todasRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        todasText:SetPoint("LEFT", todasRow, "LEFT", 8, 0)
        todasText:SetText("|cff"..(todasActive and (Data.filterColors["TODAS"] or "B0B0B0") or COLOR_INACTIVE)..(L["ALL_TEXT"] or "TODAS").."|r")

        todasRow:SetScript("OnEnter", function() todasBg:SetTexture(0, 0.15, 0.15, 0.8) end)
        todasRow:SetScript("OnLeave", function() todasBg:SetTexture(0, 0, 0, 0) end)
        todasRow:SetScript("OnClick", function()
    Data.selectedDungeons["TODAS"] = true
    for _, k in ipairs(dungeonOrder) do
        Data.selectedDungeons[k] = false
        if Data.dungeonDifficulties[k] then
            Data.selectedDifficulties[k] = {}
            for _, d in ipairs(Data.dungeonDifficulties[k]) do
                Data.selectedDifficulties[k][d] = true
            end
        end
    end
    applyChanges()
    closeAll()
end)

        -- ===== MENU NIVEL 2 (dificultades) =====
    local function openSubMenu(anchorBtn, key)
        if openMenu2 then openMenu2:Hide() end

        local diffs = Data.dungeonDifficulties[key]
        if not diffs then return end

        -- W dinámico para menu2
        local _meas2 = UIParent:CreateFontString(nil, "ARTWORK")
        _meas2:SetFont("Fonts\\FRIZQT__.TTF", 9)
        local _maxW2 = 0
        for _, d in ipairs(diffs) do
            _meas2:SetText(d)
            local tw = _meas2:GetStringWidth()
            if tw > _maxW2 then _maxW2 = tw end
        end
        _meas2:SetText("")
        local menu2W = math.ceil(_maxW2) + 22  -- 8 izq + 8 der + 6 borde

        local menu2 = CreateFrame("Frame", nil, UIParent)
        menu2:SetFrameStrata("TOOLTIP")
        menu2:SetFrameLevel(350)
        applyBackdrop(menu2)
        menu2:SetWidth(menu2W)
        menu2:SetHeight(#diffs * 20 + 4)
        menu2:SetPoint("TOPLEFT", anchorBtn, "TOPRIGHT", 1, 0)
        menu2:Show()
        openMenu2 = menu2

        -- AddLeaveTimer para menu2 (cierra solo menu2, no todo)
        AddLeaveTimer(menu2, function() if openMenu2 then openMenu2:Hide() openMenu2 = nil end end, nil)

        for i, diff in ipairs(diffs) do
            local row = CreateFrame("Button", nil, menu2)
            row:SetFrameLevel(menu2:GetFrameLevel() + 2)
            row:SetSize(menu2W - 2, 20)
            row:SetPoint("TOPLEFT", menu2, "TOPLEFT", 1, -(i-1)*20 - 2)

            -- FIX: Usar dungeonActive y diffActive para color correcto
            local dungeonActive = Data.selectedDungeons["TODAS"] or Data.selectedDungeons[key]
            local diffActive = Data.selectedDifficulties[key] and Data.selectedDifficulties[key][diff]
            local color = (dungeonActive and diffActive) and (Data.filterColors[key] or "ffffff") or COLOR_INACTIVE

            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            rowBg:SetTexture(0, 0, 0, 0)

            local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowText:SetPoint("LEFT", row, "LEFT", 8, 0)
            rowText:SetText("|cff"..color..diff.."|r")

            row:SetScript("OnEnter", function() rowBg:SetTexture(0, 0.15, 0.15, 0.8)
                -- Tooltip GS mínimo por dificultad
                local minData = Data.minGS and Data.minGS[key]
                local gsMin = minData and minData[diff]
                if gsMin then
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(key .. " " .. diff, 1, 1, 1)
                    local r, g, b = (ProChat.Utils and ProChat.Utils.GetGSColor) and ProChat.Utils:GetGSColor(gsMin) or 1,1,1
                    GameTooltip:AddLine("GS mínimo recomendado: " .. gsMin, r, g, b)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() rowBg:SetTexture(0, 0, 0, 0) GameTooltip:Hide() end)

            row:SetScript("OnClick", function()
                if not Data.selectedDifficulties[key] then
                    Data.selectedDifficulties[key] = {}
                end

                Data.selectedDungeons["TODAS"] = false

                -- Contar cuántas activas
                local checkedCount = 0
                for _, d in ipairs(diffs) do
                    if Data.selectedDifficulties[key][d] then
                        checkedCount = checkedCount + 1
                    end
                end
                
                if checkedCount == #diffs then
                    -- Primera selección: dejar solo esta
                    for _, d in ipairs(diffs) do
                        Data.selectedDifficulties[key][d] = false
                    end
                    Data.selectedDifficulties[key][diff] = true
                else
                    -- Toggle normal, nunca dejar todas en false
                    local newVal = not Data.selectedDifficulties[key][diff]
                    local wouldBeZero = true
                    for _, d in ipairs(diffs) do
                        local v = (d == diff) and newVal or Data.selectedDifficulties[key][d]
                        if v then wouldBeZero = false break end
                    end
                    if not wouldBeZero then
                        Data.selectedDifficulties[key][diff] = newVal
                    end
                end
                
                -- Actualizar estado de la mazmorra
                local anyActive = false
                for _, d in ipairs(diffs) do
                    if Data.selectedDifficulties[key][d] then anyActive = true break end
                end
                Data.selectedDungeons[key] = anyActive
                
                -- Si nada está seleccionado, volver a TODAS
                local anySelected = false
                for _, k in ipairs(Data.keywords) do
                    if Data.selectedDungeons[k] then anySelected = true break end
                end
                if not anySelected then
                Data.selectedDungeons["TODAS"] = true
                for _, k in ipairs(Data.keywords) do
                    Data.selectedDungeons[k] = false
                    if Data.dungeonDifficulties[k] then
                        Data.selectedDifficulties[k] = {}
                        for _, d in ipairs(Data.dungeonDifficulties[k]) do
                            Data.selectedDifficulties[k][d] = true
                        end
                    end
                end
            end

            applyChanges()
            local savedAnchor = anchorBtn
            local savedKey = key
            closeAll()
            openMainMenu()
            openSubMenu(savedAnchor, savedKey)
            end)
        end
    end

        -- Botones de mazmorras
        for i, key in ipairs(visibleKeys) do
            local hasDiffs = Data.dungeonDifficulties[key] ~= nil
            local isActive = Data.selectedDungeons["TODAS"] or Data.selectedDungeons[key]
            local color = isActive and (Data.filterColors[key] or "ffffff") or COLOR_INACTIVE

            local row = CreateFrame("Button", nil, menu1)
            row:SetFrameLevel(menu1:GetFrameLevel() + 2)
            row:SetSize(menu1W - 2, 20)
            row:SetPoint("TOPLEFT", menu1, "TOPLEFT", 1, -(i)*20 - 2)

            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            rowBg:SetTexture(0, 0, 0, 0)

            local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowText:SetPoint("LEFT", row, "LEFT", 8, 0)
            rowText:SetText("|cff"..color..key.."|r")

            if hasDiffs then
                local arrowTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                arrowTxt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                arrowTxt:SetText("|cff"..color..">|r")
            end

            row:SetScript("OnEnter", function()
                rowBg:SetTexture(0, 0.15, 0.15, 0.8)
                if hasDiffs then openSubMenu(row, key) end
                -- Tooltip GS mínimo (solo mazmorras sin dificultad o como resumen)
                if not hasDiffs then
                    local minData = Data.minGS and Data.minGS[key]
                    if minData then
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(key, 1, 1, 1)
                        if minData.all then
                            local r, g, b = (ProChat.Utils and ProChat.Utils.GetGSColor) and ProChat.Utils:GetGSColor(minData.all) or 1,1,1
                            GameTooltip:AddLine("GS mínimo recomendado: " .. minData.all, r, g, b)
                        elseif minData.all == nil and key == "VIAJEROS" then
                            GameTooltip:AddLine("GS mínimo: Variado", 1, 1, 0.6)
                        end
                        GameTooltip:Show()
                    end
                end
            end)
            row:SetScript("OnLeave", function() rowBg:SetTexture(0, 0, 0, 0) GameTooltip:Hide() end)

                        row:SetScript("OnClick", function()
                Data.selectedDungeons["TODAS"] = false
                if hasDiffs then
                    if not Data.selectedDifficulties[key] then
                        Data.selectedDifficulties[key] = {}
                        for _, d in ipairs(Data.dungeonDifficulties[key]) do
                            Data.selectedDifficulties[key][d] = true
                        end
                    end
                    if Data.selectedDungeons[key] then
                        -- Desactivar: quitar todas las dificultades
                        for _, d in ipairs(Data.dungeonDifficulties[key]) do
                            Data.selectedDifficulties[key][d] = false
                        end
                        Data.selectedDungeons[key] = false
                    else
                        -- Activar: marcar todas las dificultades
                        for _, d in ipairs(Data.dungeonDifficulties[key]) do
                            Data.selectedDifficulties[key][d] = true
                        end
                        Data.selectedDungeons[key] = true
                    end
                else
                    Data.selectedDungeons[key] = not Data.selectedDungeons[key]
                end
                
                -- Verificar que no quede todo vacío
                local anySelected = false
                for _, k in ipairs(Data.keywords) do
                    if Data.selectedDungeons[k] then anySelected = true break end
                end
                if not anySelected then
                    Data.selectedDungeons["TODAS"] = true
                    for _, k in ipairs(Data.keywords) do
                        Data.selectedDungeons[k] = false
                        if Data.dungeonDifficulties[k] then
                            Data.selectedDifficulties[k] = {}
                            for _, d in ipairs(Data.dungeonDifficulties[k]) do
                                Data.selectedDifficulties[k][d] = true
                            end
                        end
                    end
                end
                
                applyChanges()
                closeAll()
                openMainMenu()
            end)
        end

        -- Cerrar al click fuera
        menu1:SetScript("OnHide", function() openMenu1 = nil end)

        -- Sistema global: registrar cierre y AddLeaveTimer para menu1
        ProChat.Core:RegisterOpenMenu(closeAll)
        GetMenuClickCatcher():Show()
        AddLeaveTimer(menu1, closeAll, btn)
    end

    btn:SetScript("OnClick", function()
        if openMenu1 then
            closeAll()
            ProChat.Core:CloseAllMenus()
        else
            ProChat.Core:CloseAllMenus()
            openMainMenu()
        end
    end)

    UI.filterDropBtnText = btnText
    UI.filterDropRefresh = refreshBtnText

    refreshBtnText()
    return btn
end
-- ===== CREATE TIME DROPDOWN (FULL CUSTOM - no UIDropDownMenuTemplate) =====
function ProChat.Core:CreateTimeDropdown(parent)
    local times = {{s="30s", v=30}, {s="1min", v=60}, {s="2min", v=120}, {s="3min", v=180}, {s="5min", v=300}}

    -- Calcular W dinámico midiendo el texto más largo (textos son fijos, se mide una vez)
    local _measurer = UIParent:CreateFontString(nil, "ARTWORK")
    _measurer:SetFont("Fonts\\FRIZQT__.TTF", 9)
    local _maxW = 0
    for _, item in ipairs(times) do
        _measurer:SetText(item.s)
        local tw = _measurer:GetStringWidth()
        if tw > _maxW then _maxW = tw end
    end
    _measurer:SetText("")
    local W = math.ceil(_maxW) + 22  -- 8 (izq) + 6 (der) + 8 (extra borde)
    local menuOpen = false
    local menuFrame = nil

    -- Botón principal
    local btn = CreateFrame("Button", "PC_TimeDrop", parent)
    btn:SetSize(W, 18)
    btn:SetPoint("TOPLEFT", ProChat.UI.checkMM, "BOTTOMLEFT", 12, -10)
    btn:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Buttons\\WHITE8X8",tile=true,tileSize=16,edgeSize=1,insets={left=0,right=0,top=0,bottom=0}})
    btn:SetBackdropColor(0.06, 0.0, 0.1, 0.97)
    btn:SetBackdropBorderColor(0.55, 0.1, 0.75, 0.9)
    btn:SetFrameLevel(parent:GetFrameLevel() + 3)
    btn:SetScript("OnEnter", function() btn:SetBackdropColor(0.1, 0.02, 0.18, 0.97) end)
    btn:SetScript("OnLeave", function() btn:SetBackdropColor(0.06, 0.0, 0.1, 0.97) end)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    btnText:SetText("1min")
    btnText:SetTextColor(0.75, 0.4, 1, 1)

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    arrow:SetFont("Fonts\\FRIZQT__.TTF", 8)
    arrow:SetText("v")
    arrow:SetTextColor(0.75, 0.4, 1, 1)

    local function closeMenu()
        if menuFrame then menuFrame:Hide() menuFrame = nil end
        menuOpen = false
    end

    local function openMenu()
        menuFrame = CreateFrame("Frame", nil, UIParent)
        menuFrame:SetFrameStrata("TOOLTIP")
        menuFrame:SetFrameLevel(300)
        menuFrame:SetWidth(W)
        menuFrame:SetHeight(#times * 18 + 4)
        menuFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
        menuFrame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Buttons\\WHITE8X8",tile=true,tileSize=16,edgeSize=1,insets={left=0,right=0,top=0,bottom=0}})
        menuFrame:SetBackdropColor(0.06, 0.0, 0.1, 0.98)
        menuFrame:SetBackdropBorderColor(0.55, 0.1, 0.75, 0.9)
        menuFrame:Show()
        menuOpen = true

        for i, item in ipairs(times) do
            local sText, sValue = item.s, item.v
            local row = CreateFrame("Button", nil, menuFrame)
            row:SetFrameLevel(menuFrame:GetFrameLevel() + 2)
            row:SetSize(W - 2, 18)
            row:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, -(i-1)*18 - 2)

            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            rowBg:SetTexture(0, 0, 0, 0)

            local rowText = row:CreateFontString(nil, "OVERLAY")
            rowText:SetPoint("LEFT", row, "LEFT", 8, 0)
            rowText:SetFont("Fonts\\FRIZQT__.TTF", 9)
            -- TimeDrop: activo = dorado, inactivo = gris claro
            local isActive = (Data.filterTime == sValue)
            rowText:SetText(isActive and "|cffFFD100"..sText.."|r" or "|cffAAAAAA"..sText.."|r")

            row:SetScript("OnEnter", function()
                rowBg:SetTexture(0.18, 0.04, 0.28, 0.85)
            end)
            row:SetScript("OnLeave", function()
                rowBg:SetTexture(0, 0, 0, 0)
            end)
            row:SetScript("OnClick", function()
                Data.filterTime = sValue
                btnText:SetText(sText)
                local mins = sValue / 60
                local tag = "[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: "
                local etiqueta = L["TIME_CHANGED"] or "Filter time changed to: "
                ProChatPrint(tag .. etiqueta .. "|cffffff00" .. mins .. " min|r")
                if ProChatDB then ProChatDB.filterTime = sValue end
                closeMenu()
            end)
        end

        menuFrame:SetScript("OnHide", function() menuOpen = false menuFrame = nil end)

        -- Sistema global
        ProChat.Core:RegisterOpenMenu(closeMenu)
        GetMenuClickCatcher():Show()
        AddLeaveTimer(menuFrame, closeMenu, btn)
    end

    btn:SetScript("OnClick", function()
        if menuOpen then closeMenu() else
            ProChat.Core:CloseAllMenus()
            openMenu()
        end
    end)

    -- Compatibilidad con UIDropDownMenu_SetText en código heredado
    btn._btnText = btnText
    UI.timeDrop = btn
    UI.timeDropText = btnText

    return btn
end

-- ===== CREATE LANGUAGE DROPDOWN (FULL CUSTOM - no UIDropDownMenuTemplate) =====
function ProChat.Core:CreateLanguageDropdown(parent)
    local langs = {
        {text = "Esp", value = "es"},
        {text = "Eng", value = "en"},
    }
    local currentLang = (ProChatDB and ProChatDB.lang == "en") and "Eng" or "Esp"
    local menuOpen = false
    local menuFrame = nil

    -- Botón principal
    local btn = CreateFrame("Button", "PC_LangDrop", parent)
    btn:SetSize(58, 16)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -2)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = {left=0,right=0,top=0,bottom=0}
    })
    btn:SetBackdropColor(0, 0, 0, 0.8)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    btn:SetFrameLevel(parent:GetFrameLevel() + 3)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btnText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    btnText:SetText(currentLang)
    btnText:SetTextColor(1, 1, 1, 1)

    local arrowL = btn:CreateFontString(nil, "OVERLAY")
    arrowL:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    arrowL:SetFont("Fonts\\FRIZQT__.TTF", 8)
    arrowL:SetText("v")
    arrowL:SetTextColor(0.85, 0.85, 0.85, 1)

    btn:SetScript("OnEnter", function() btn:SetBackdropColor(0.12, 0.12, 0.12, 0.9) end)
    btn:SetScript("OnLeave", function() btn:SetBackdropColor(0, 0, 0, 0.8) end)

    local function closeMenu()
        if menuFrame then menuFrame:Hide() menuFrame = nil end
        menuOpen = false
    end

    local function openMenu()
        menuFrame = CreateFrame("Frame", nil, UIParent)
        menuFrame:SetFrameStrata("TOOLTIP")
        menuFrame:SetFrameLevel(300)
        menuFrame:SetWidth(58)
        menuFrame:SetHeight(#langs * 18 + 4)
        menuFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
        menuFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
            insets = {left=0,right=0,top=0,bottom=0}
        })
        menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
        menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        menuFrame:Show()
        menuOpen = true

        for i, lang in ipairs(langs) do
            local row = CreateFrame("Button", nil, menuFrame)
            row:SetFrameLevel(menuFrame:GetFrameLevel() + 2)
            row:SetSize(56, 18)
            row:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, -(i-1)*18 - 2)
            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            rowBg:SetTexture(0, 0, 0, 0)
            local rowText = row:CreateFontString(nil, "OVERLAY")
            rowText:SetPoint("LEFT", row, "LEFT", 8, 0)
            rowText:SetFont("Fonts\\FRIZQT__.TTF", 9)
            local isSelected = (ProChatDB and ProChatDB.lang == lang.value)
            -- LangDrop: activo = blanco, inactivo = gris claro
            rowText:SetText(isSelected and "|cffFFFFFF"..lang.text.."|r" or "|cffAAAAAA"..lang.text.."|r")
            row:SetScript("OnEnter", function()
                rowBg:SetTexture(0.18, 0.18, 0.18, 0.85)
            end)
            row:SetScript("OnLeave", function()
                rowBg:SetTexture(0, 0, 0, 0)
            end)
            row:SetScript("OnClick", function()
                ProChatDB.lang = lang.value
                if ProChat.Locales and ProChat.Locales.SetLanguage then
                    ProChat.Locales:SetLanguage(lang.value)
                end
                btnText:SetText(lang.text)
                ProChat.Core:RefreshUIIconsAndLabels()
                closeMenu()
                print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " .. (ProChat.L["LANG_CHANGED"] or "Language Changed"))
            end)
        end

        menuFrame:SetScript("OnHide", function() menuOpen = false menuFrame = nil end)

        -- Sistema global
        ProChat.Core:RegisterOpenMenu(closeMenu)
        GetMenuClickCatcher():Show()
        AddLeaveTimer(menuFrame, closeMenu, btn)
    end

    btn:SetScript("OnClick", function()
        if menuOpen then closeMenu() else
            ProChat.Core:CloseAllMenus()
            openMenu()
        end
    end)

    -- Referencia para RefreshUIIconsAndLabels
    btn.SetCurrentText = function(text) btnText:SetText(text) end
    -- Compatibilidad con UIDropDownMenu_SetText llamadas en código heredado
    UI.langDrop = btn
    UI.langDropText = btnText

    return btn
end

-- ===== CREATE SEARCH BOX =====
function ProChat.Core:CreateSearchBox(parent)
    local searchBox = CreateFrame("EditBox", "PC_SearchBox", parent, "InputBoxTemplate")
    searchBox:SetSize(80, 18)
    -- A la derecha del botón limpiar (escoba está en BOTTOMLEFT +8,+8, size 22)
    searchBox:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 34, 10)
    searchBox:SetAutoFocus(false)
    
    searchBox.timer       = 0
    searchBox.hasFocus    = false
    searchBox.searchDelay = 0      -- acumulador para debounce del search
    searchBox.searchPending = false -- hay texto nuevo sin procesar
    
    searchBox:SetScript("OnUpdate", function(self, elapsed)
        if self.hasFocus then
            self.timer = self.timer + elapsed
            if self.timer >= 3 then self:ClearFocus() end
        end
        -- Debounce: esperar 0.3s de inactividad antes de disparar refresh
        if self.searchPending then
            self.searchDelay = self.searchDelay + elapsed
            if self.searchDelay >= 0.3 then
                self.searchPending = false
                self.searchDelay = 0
                DeferRefresh()
                DeferRaidList()
            end
        end
    end)
    searchBox:SetScript("OnEditFocusGained", function(self) self.timer = 0; self.hasFocus = true end)
    searchBox:SetScript("OnEditFocusLost",   function(self) self.hasFocus = false; self.timer = 0 end)
    searchBox:SetScript("OnEnterPressed",    function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed",   function(self) self:ClearFocus() end)
    searchBox:SetScript("OnTextChanged", function(self, isUserInput)
        Data.searchTerm = self:GetText()
        if isUserInput then
            -- Tecla por tecla: reiniciar debounce, NO refrescar aún
            self.timer = 0
            self.searchDelay = 0
            self.searchPending = true
        else
            -- Cambio programático (SetText) → diferir inmediatamente
            DeferRefresh()
        end
    end)
    
    return searchBox
end

-- ===== CREATE CHECKBOX =====
function ProChat.Core:CreateCheckbox(name, parent, point, x, y, text)
    local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    check:SetPoint(point, x, y)
    _G[check:GetName().."Text"]:SetText(text)
    check:SetChecked(false)
    
    return check
end

-- ===== CREATE BUTTON =====
function ProChat.Core:CreateButton(parent, width, height, point, x, y, text)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetPoint(point, x, y)
    btn:SetText(text)
    
    return btn
end

-- ===== CREATE FONT SLIDER =====
function ProChat.Core:CreateFontSlider(parent)
    local fontSlider = CreateFrame("Slider", "PC_FontSlider", parent, "OptionsSliderTemplate")
    fontSlider:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 160, 5)
    fontSlider:SetWidth(68)
    fontSlider:SetHeight(14)
    fontSlider:SetMinMaxValues(8, 20)
    fontSlider:SetValueStep(1)
    fontSlider:SetValue(ProChatDB and ProChatDB.fontSize or 12)
    _G[fontSlider:GetName() .. "Text"]:SetText(L["SLIDER_TEXT"])
    _G[fontSlider:GetName() .. "Low"]:SetText("") 
    _G[fontSlider:GetName() .. "High"]:SetText("")
    
    fontSlider:SetScript("OnValueChanged", function(self, value)
        local size = math.floor(value)
        if Frames.chatWin.text then
            local font, _, flags = Frames.chatWin.text:GetFont()
            Frames.chatWin.text:SetFont(font, size, flags)
        end
        if Frames.chatWin.raidText then
            local rFont, _, rFlags = Frames.chatWin.raidText:GetFont()
            Frames.chatWin.raidText:SetFont(rFont, size, rFlags)
        end
        if ProChatDB then 
            ProChatDB.fontSize = size 
        end
    end)
    
    EnableSliderMouseWheel(fontSlider)
    return fontSlider
end

-- ===== CREATE OPACITY SLIDER =====
function ProChat.Core:CreateOpacitySlider(parent)
    local opacitySlider = CreateFrame("Slider", "PC_OpacitySlider", parent, "OptionsSliderTemplate")
    -- Pegado al lado derecho del langDrop (bg de 58px), con muy poca separación
    opacitySlider:SetPoint("TOPLEFT", parent, "TOPLEFT", 62, -1)
    opacitySlider:SetWidth(55)
    opacitySlider:SetHeight(14)
    opacitySlider:SetMinMaxValues(35, 90)
    opacitySlider:SetValueStep(1)
    opacitySlider:SetValue(ProChatDB and ProChatDB.opacity or 75)
    
    _G[opacitySlider:GetName() .. "Text"]:SetText("")
    _G[opacitySlider:GetName() .. "Low"]:SetText("")
    _G[opacitySlider:GetName() .. "High"]:SetText("")
    
    opacitySlider:SetScript("OnValueChanged", function(self, value)
        local alpha = value / 100
        if Frames.chatWin then
            Frames.chatWin:SetBackdropColor(0.05, 0.05, 0.05, alpha)
        end
        if ProChatDB then
            ProChatDB.opacity = value
        end
    end)
    
    EnableSliderMouseWheel(opacitySlider)
    parent.opacitySlider = opacitySlider
    return opacitySlider
end

-- ===== CODIFICACIÓN DE GS (nuevo sistema ofuscado) =====
local GS_ENCODE = {
    ["0"] = "HH", ["1"] = "A0", ["2"] = "ZW", ["3"] = "KQ",
    ["4"] = "6J", ["5"] = "PF", ["6"] = "E0", ["7"] = "IG",
    ["8"] = "C8", ["9"] = "4T",
}

local function EncodeGS(gs)
    local s = tostring(gs or 0)
    local result = ""
    for i = 1, #s do
        result = result .. (GS_ENCODE[s:sub(i,i)] or "HH")
    end
    return result
end

-- IDs de dificultad para SR e ICC en el comentario del BB
local DIFF_CODES = {
    -- Códigos de dungeon
    ["SR"]  = "KS",
    ["ICC"] = "6H",
    -- Códigos de dificultad
    ["SR_10N"]  = "D4",
    ["SR_10H"]  = "3V",
    ["SR_25N"]  = "621",
    ["SR_25H"]  = "YF",
    ["ICC_10N"] = "9Q8",
    ["ICC_10H"] = "XC1",
    ["ICC_25N"] = "33A",
    ["ICC_25H"] = "1W",
}

-- ===== AUTO-LFG UPDATE (re-apuntarse cuando cambia función o mazmorras) =====
function ProChat.Core:AutoLFGUpdate()
    if not ProChat.Data.autoLFGActive then return end
    -- Salir primero, luego re-entrar
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

function ProChat.Core:LeaveQueue()
    LeaveLFG()
    ProChat.Data.isQueued = false
    ProChat.Data.autoLFGActive = false
    if UI.autoLFGSwitch then UI.autoLFGSwitch:SetChecked(false) end
    if UI.autoLFGEye then UI.autoLFGEye:UpdateState(false) end
    -- Restaurar ícono normal del minimapa
    if ProChat.Frames.minimap and ProChat.Frames.minimap.UpdateQueueState then
        ProChat.Frames.minimap:UpdateQueueState(false)
    end
    -- FIX 6: Restaurar MiniMapLFGFrame de Blizzard (no el minimap de ProChat)
    if MiniMapLFGFrame then MiniMapLFGFrame:Show() end
    -- FIX 2: Ocultar icono del ojo en barra minimizada (y parar animación)
    local chatWin = Frames.chatWin
    if chatWin and chatWin._minEyeBtn then
        if chatWin._minEyeBtn.anim then chatWin._minEyeBtn.anim:Stop() end
        chatWin._minEyeBtn:Hide()
    end
    if chatWin and chatWin._minEyeIcon and chatWin._minEyeIcon ~= chatWin._minEyeBtn then
        chatWin._minEyeIcon:Hide()
    end
    print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " .. (L["LEAVE_QUEUE_MSG"] or "Te has quitado de la cola."))
end

function ProChat.Core:QueueForDungeons()
    local hasRole = false
    for _ in pairs(ProChat.Data.selectedRoles) do hasRole = true break end
    if not hasRole then
        print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " .. (L["NO_ROLE_SELECTED"] or "Debes seleccionar al menos un rol."))
        if UI.autoLFGSwitch then UI.autoLFGSwitch:SetChecked(false) end
        ProChat.Data.autoLFGActive = false
        -- FIX 4: No actualizar ojo ni mostrar roles
        return
    end

    -- Helper: diff del filtro → ID en dungeonIDs
    local function getIDForDiff(dData, diff)
        if dData[diff] then return dData[diff] end
        if diff == "10N" or diff == "10H" then return dData["10"] end
        if diff == "25N" or diff == "25H" then return dData["25"] end
        return nil
    end

    local dungeonsToQueue = {}
    local addedIDs = {}

    -- Construir fragmento de comentario con códigos de dificultad (SR e ICC)
    local srCodes = ""
    local iccCodes = ""

    -- FIX 7: Códigos de mazmorras especiales (FOSO, SEMANAL, VIAJEROS) vía ONY 10
    local specialCodes = {}  -- lista de códigos a incluir en comentario
    local needsONY10 = false  -- si necesitamos añadir ONY 10 para las especiales

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

    -- FIX 7: Tabla de códigos especiales
    local SPECIAL_CODES = {
        ["FOSO"]     = "I61Q",
        ["SEMANAL"]  = "CP",
        ["VIAJEROS"] = "JJ2",
    }
    -- Código de confirmación ONY 10 (para diferenciar de quien realmente busca ONY)
    local ONY10_CODE = "2TZ"
    -- ID de ONY 10 para inscribir en el buscador
    local ONY10_ID = 46  -- ProChat.Data.dungeonIDs["ONY"]["10"]

    for _, key in ipairs(keysToCheck) do
        -- FIX 7: Manejar mazmorras especiales
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
                                table.insert(dungeonsToQueue, {id = id, key = key, diff = diff})
                            end
                            -- Acumular códigos para SR e ICC
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

    -- FIX 7: Si hay mazmorras especiales, añadir ONY 10 si no está ya
    if needsONY10 and not addedIDs[ONY10_ID] then
        addedIDs[ONY10_ID] = true
        table.insert(dungeonsToQueue, {id = ONY10_ID, key = "ONY", diff = "10"})
        -- Añadir código de ONY 10 para que LFM sepa que también está en ONY real
        table.insert(specialCodes, 1, ONY10_CODE)
    end

    if #dungeonsToQueue == 0 and #specialCodes == 0 then
        print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " .. (L["NO_DUNGEONS_SELECTED"] or "No hay mazmorras seleccionadas."))
        if UI.autoLFGSwitch then UI.autoLFGSwitch:SetChecked(false) end
        ProChat.Data.autoLFGActive = false
        -- FIX 4: No actualizar ojo ni mostrar roles
        return
    end

    -- Construir comentario con nuevo formato
    local gs = ProChat.Core:GetGearScore()
    local playerName = UnitName("player")
    local gsEncoded = EncodeGS(gs)
    local signature = ProChat.Utils:GenerateSignature(gs, playerName)

    -- Fragmento de dungeon/dificultad (SR, ICC)
    local dungeonFragment = ""
    if srCodes ~= "" then
        dungeonFragment = DIFF_CODES["SR"] .. srCodes
    end
    if iccCodes ~= "" then
        if dungeonFragment ~= "" then dungeonFragment = dungeonFragment .. " / " end
        dungeonFragment = dungeonFragment .. DIFF_CODES["ICC"] .. iccCodes
    end
    -- FIX 7: Añadir códigos especiales al fragmento
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
    for _, dq in ipairs(dungeonsToQueue) do
        SetLFGDungeon(dq.id)
    end
    SetLFGComment(comment)

    -- ===== SILENCIAR SEÑALES DE BLIZZARD =====
    -- Activar flag para que el filtro de chat descarte el mensaje de sistema
    -- y para que el hook de PlaySound bloquee solo el sonido de cola (ID 8462)
    ProChat.IsInternalAction = true

    JoinLFG()

    -- Desactivar flag tras 0.6s (suficiente para que pasen todos los eventos)
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

    -- Actualizar ojo y minimapa (solo en éxito)
    if UI.autoLFGEye then
        UI.autoLFGEye:UpdateState(true)
    end
    if ProChat.Frames.minimap and ProChat.Frames.minimap.UpdateQueueState then
        ProChat.Frames.minimap:UpdateQueueState(true)
    end

    -- FIX 6: Ocultar MiniMapLFGFrame (icono de Blizzard del buscador de mazmorras)
    if MiniMapLFGFrame then MiniMapLFGFrame:Hide() end

    -- Mostrar botones de roles y título SOLO cuando hay éxito
    local chatWin = Frames.chatWin
    local optVisible = UI.checkOptions and UI.checkOptions:GetChecked()
    if chatWin.roleButtons then
        for _, btn in pairs(chatWin.roleButtons) do
            if optVisible then btn:Show() else btn:Hide() end
        end
    end
    if chatWin.roleTitleLabel then
        if optVisible then chatWin.roleTitleLabel:Show() else chatWin.roleTitleLabel:Hide() end
    end

    -- Actualizar icono en barra minimizada si está minimizado
    if chatWin.isMinimized and chatWin._minEyeBtn then
        chatWin._minEyeBtn:Show()
        if chatWin._minEyeBtn.anim then chatWin._minEyeBtn.anim:Play() end
    end
end

-- ===== SETUP CHECKBOX SCRIPTS =====
function ProChat.Core:SetupCheckboxScripts()
    -- Minimap switch
    UI.checkMM:SetChecked(ProChatDB and ProChatDB.showMinimap ~= false)
    UI.checkMM:SetScript("OnClick", function(self) 
        if self:GetChecked() then 
            Frames.minimap:Show() 
        else 
            Frames.minimap:Hide() 
        end 
        if ProChatDB then ProChatDB.showMinimap = self:GetChecked() end
    end)
    
    -- Hide grays switch
    UI.checkGrays:SetChecked(ProChatDB and ProChatDB.hideGrays or false)
    UI.checkGrays:SetScript("OnClick", function(self) 
        local isChecked = self:GetChecked()
        Data.hideGrays = isChecked
        if ProChatDB then ProChatDB.hideGrays = isChecked end
        DeferRefresh()
    end)
    
    -- Show raid switch
    UI.checkRaid:SetScript("OnClick", function(self) 
        local isChecked = self:GetChecked() and true or false
        ProChatDB.showRaidWin = isChecked
        ProChat.Core:ApplyRaidVisibility(isChecked)
    end)

    -- Options switch
    UI.checkOptions:SetScript("OnClick", function(self)
        local isVisible = self:GetChecked()
        ProChatDB.showOptions = isVisible and true or false

        -- Elementos del grupo Opciones (fix 6: checkOptions no está en la lista)
        for _, elementName in ipairs(ProChat.Core.OptionsElements) do
            local element = UI[elementName]
            if element then
                if isVisible then element:Show() else element:Hide() end
            end
        end

        local switchKeys = {"checkGrays", "autoLFGSwitch", "checkMM", "checkRaid"}
        for _, key in ipairs(switchKeys) do
            local sw = UI[key]
            if sw and sw.switchLabel then
                if isVisible then sw.switchLabel:Show() else sw.switchLabel:Hide() end
            end
        end
        if UI.checkRaidTitle then
            if isVisible then UI.checkRaidTitle:Show() else UI.checkRaidTitle:Hide() end
        end

        -- Botones de roles y su título (solo si Auto-LFG activo)
        local chatWin = Frames.chatWin
        local autoLFGActive = ProChat.Data.autoLFGActive
        if chatWin.roleButtons then
            for _, btn in pairs(chatWin.roleButtons) do
                if isVisible and autoLFGActive then btn:Show() else btn:Hide() end
            end
        end
        if chatWin.roleTitleLabel then
            if isVisible and autoLFGActive then chatWin.roleTitleLabel:Show() else chatWin.roleTitleLabel:Hide() end
        end

        if isVisible then
            Frames.chatWin.text:SetPoint("TOPLEFT", 15, -75)
        else
            Frames.chatWin.text:SetPoint("TOPLEFT", 15, -30)
        end

        if Frames.chatWin.UpdateLayout then
            Frames.chatWin.UpdateLayout()
        end
    end)
    
    -- Broom (clear) button
    UI.globalClear:SetScript("OnClick", function()
        Frames.chatWin.text:Clear() 
        if Frames.chatWin.raidText then Frames.chatWin.raidText:Clear() end
        Utils:ResetAllData()
        DeferRaidList() 
    end)

    -- Auto-LFG switch
    UI.autoLFGSwitch:SetChecked(false)
    UI.autoLFGSwitch:SetScript("OnClick", function(self)
        local isActive = self:GetChecked()
        ProChat.Data.autoLFGActive = isActive

        -- FIX 4: Solo actualizar ojo y roles SI el switch se activa
        -- La validación real la hace QueueForDungeons; si falla, revierte el estado
        if not isActive then
            -- Desactivar: siempre proceder
            if UI.autoLFGEye then UI.autoLFGEye:UpdateState(false) end
            -- FIX 6: Restaurar MiniMapLFGFrame al desactivar
            if MiniMapLFGFrame then MiniMapLFGFrame:Show() end

            local chatWin = Frames.chatWin
            if chatWin.roleButtons then
                for _, btn in pairs(chatWin.roleButtons) do btn:Hide() end
            end
            if chatWin.roleTitleLabel then chatWin.roleTitleLabel:Hide() end

            ProChat.Core:LeaveQueue()
        else
            -- Activar: QueueForDungeons decidirá si es válido
            -- No mostramos roles NI actualizamos el ojo aquí todavía
            -- QueueForDungeons lo hará solo si tiene éxito
            ProChat.Core:QueueForDungeons()
        end
    end)
end

-- ===== APPLY SAVED SETTINGS =====
function ProChat.Core:ApplySavedSettings()
    ProChatDB.mmAngle = ProChatDB.mmAngle or 45
    ProChatDB.showWindows = (ProChatDB.showWindows == nil) and true or ProChatDB.showWindows
    
    Data.hideGrays = ProChatDB.hideGrays or false
    Data.filterTime = ProChatDB.filterTime or 60

    if ProChatDB.selectedDungeons then
        Data.selectedDungeons = ProChatDB.selectedDungeons
    end
    if ProChatDB.selectedDifficulties then
        Data.selectedDifficulties = ProChatDB.selectedDifficulties
    end
    
    ProChat.Core:RefreshFilterDropBtnText()
    Utils:UpdateMinimapPos()
    
    if ProChatDB.uiScale then
        Frames.chatWin:SetScale(ProChatDB.uiScale)
    else
        ProChatDB.uiScale = 1.0
    end
    
    if ProChatDB.opacity then
        local alpha = ProChatDB.opacity / 100
        Frames.chatWin:SetBackdropColor(0.05, 0.05, 0.05, alpha)
    else
        ProChatDB.opacity = 75
    end

    if ProChatDB.selectedChannels then
    Data.selectedChannels = ProChatDB.selectedChannels
        if UI.chanDrop and UI.chanDrop._refreshText then
            UI.chanDrop._refreshText()
        end
    end

        -- Restaurar texto del timeDrop
    if UI.timeDrop and UI.timeDrop._btnText and ProChatDB.filterTime then
        Data.filterTime = ProChatDB.filterTime
        local timeText = ""
        if ProChatDB.filterTime == 30 then timeText = "30s"
        elseif ProChatDB.filterTime == 60 then timeText = "1min"
        elseif ProChatDB.filterTime == 120 then timeText = "2min"
        elseif ProChatDB.filterTime == 180 then timeText = "3min"
        elseif ProChatDB.filterTime == 300 then timeText = "5min"
        end
        if timeText ~= "" then
            UI.timeDrop._btnText:SetText(timeText)
        end
    end
    
    if UI.opacitySlider then UI.opacitySlider:Show() end
    
    if ProChatDB.showWindows then
        Frames.chatWin:Show()
        if ProChatDB.isMinimized then
            Frames.chatWin:SetSize(150, 22)
            Frames.chatWin.minBtn:ClearAllPoints()
            Frames.chatWin.minBtn:SetPoint("TOPRIGHT", Frames.chatWin, "TOPRIGHT", -2, -4)  -- extremo derecho (cambio 9)
            Frames.chatWin.minBtn.label:SetText("<>")
            Frames.chatWin.closeBtn:Hide()
            if Frames.chatWin.resizeHandle then Frames.chatWin.resizeHandle:Hide() end
            Frames.chatWin:HideContent()
            Frames.chatWin.isMinimized = true
            if ProChatDB.windowPosMin then
                Frames.chatWin:ClearAllPoints()
                Frames.chatWin:SetPoint(unpack(ProChatDB.windowPosMin))
            end
            -- Forzar título en barra minimizada
            local tBtn3 = Frames.chatWin.titleText and Frames.chatWin.titleText:GetParent()
            if tBtn3 and tBtn3 ~= Frames.chatWin then
                tBtn3:Show()
                tBtn3:ClearAllPoints()
                tBtn3:SetPoint("CENTER", Frames.chatWin, "CENTER", -10, 0)
                tBtn3:SetWidth(100)
            end
            Frames.chatWin.titleText:SetText("|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r")
            Frames.chatWin.titleText:Show()
        else
            Frames.chatWin.isMinimized = false
            if ProChatDB.windowX then
                Frames.chatWin:ClearAllPoints()
                Frames.chatWin:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ProChatDB.windowX, ProChatDB.windowY)
            end
            if ProChatDB.windowSizeMax then
                Frames.chatWin:SetSize(unpack(ProChatDB.windowSizeMax))
            end
            
            -- Restaurar estado de Raids Activas
            if UI.checkRaid then
                local raidState = ProChatDB.showRaidWin
                if raidState == nil then raidState = true end
                UI.checkRaid:SetChecked(raidState)
                ProChat.Core:ApplyRaidVisibility(raidState)
            end

            if UI.checkOptions then
                if ProChatDB.showOptions == nil then
                    ProChatDB.showOptions = true
                end
                UI.checkOptions:SetChecked(ProChatDB.showOptions)
                
                -- Forzar posición según estado del checkbox
                if ProChatDB.showOptions then
                    Frames.chatWin.text:SetPoint("TOPLEFT", 15, -75)
                else
                    Frames.chatWin.text:SetPoint("TOPLEFT", 15, -30)
                end
                if Frames.chatWin.UpdateLayout then 
                    Frames.chatWin.UpdateLayout() 
                end
            end
            ProChat.Core:SelectTab(ProChatDB.currentTab or "LFG")
        end
    else
        Frames.chatWin:Hide()
    end
end

-- ===== SETUP EVENT LISTENER =====
function ProChat.Core:SetupEventListener()
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("CHAT_MSG_CHANNEL")
    listener:RegisterEvent("CHAT_MSG_SAY")
    listener:RegisterEvent("CHAT_MSG_YELL")
    listener:RegisterEvent("CHAT_MSG_GUILD")
    listener:RegisterEvent("PLAYER_ENTERING_WORLD")
    listener:RegisterEvent("PLAYER_REGEN_DISABLED")
    
    listener:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            ProChat.Core:OnPlayerEnteringWorld()
        elseif event == "PLAYER_REGEN_DISABLED" then
            ProChat.Core:OnCombat()
        elseif event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_GUILD" then
            ProChat.Core:OnChatMessage(event, ...)
        end
    end)
end

function ProChat.Core:OnPlayerEnteringWorld()
    local msgInicio = L["START_MSG"] or "Cargado. Versión"
    local statusText = L["STATUS_TXT"] or "Estado: |cff00ff00Addon Actualizado|r."
    print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " .. msgInicio .. " |cffffffff"..ProChat.CURRENT_VERSION.."|r. " .. statusText)
end

function ProChat.Core:OnCombat()
    local chatWin = Frames.chatWin
    if chatWin:IsVisible() and not chatWin.isMinimized then
        -- Minimizar en vez de ocultar para no interrumpir la sesión
        if chatWin.minBtn then
            chatWin.minBtn:GetScript("OnClick")()
        end
    end
end

function ProChat.Core:OnChatMessage(event, ...)
    local msg, sender, _, _, _, _, _, _, chanName, _, _, guid = ...
    
    if sender then sender = strsplit("-", sender) end
    
    if event == "CHAT_MSG_SAY" then chanName = "Decir"
    elseif event == "CHAT_MSG_YELL" then chanName = "Gritar"
    elseif event == "CHAT_MSG_GUILD" then chanName = "Hermandad"
    end
    
    if not Frames.chatWin:IsVisible() or not chanName then return end
    
    local isSelected = false
    local chanUpper = chanName:upper()
    
    for selectedName, active in pairs(Data.selectedChannels) do
        if active and string.find(chanUpper, selectedName:upper()) then
            isSelected = true
            break
        end
    end
    if not isSelected then return end
    
    local now = GetTime()
    local currentFilterLimit = Data.filterTime or 60
    local puedeMostrar = false
    if not Data.userMessages[sender] or (now - Data.userMessages[sender].time >= currentFilterLimit) then
        puedeMostrar = true
    end
    
    if puedeMostrar then
        local matched = Utils:MatchDungeonKeyword(msg)
        local matchedDiff = nil
        
        -- Determinar dificultad UNA SOLA VEZ (FIX #2)
        if matched then
            matchedDiff = Utils:MatchDifficultyKeyword(msg, matched)
        end
        
        local cat = matched or "TODAS"
        local c = Data.filterColors[cat] or "ffffff"
        local msgColor = Utils:LightenHexColor(c, 0.45)
        
        local cleanName = chanName:gsub("%d+%.%s*", ""):upper()
        local tagData = Data.channelTags[cleanName] or {t=string.sub(cleanName,1,1), c="ffffff"}
        local dungeonTag = matched and (" |cff"..c.."["..matched.."]|r") or ""
        local timeStamp = Utils:GetFormattedTime()
        
        local formatted = timeStamp
            .." |cff"..tagData.c.."["..tagData.t.."]|r"
            .." |cff"..c.."[|r|Hplayer:"..sender.."|h|cff"..Utils:GetClassColor(guid, sender)..sender.."|r|h|cff"..c.."]|r"
            ..dungeonTag..": "..Utils:ColorMessageText(msg, msgColor)

        local entry = {
            formatted = formatted,
            raw = msg,
            dungeon = matched,
            difficulty = matchedDiff,
        }

        table.insert(Data.history["TODAS"], entry)
        -- Cap del historial: máximo 200 entradas por categoría
        -- Mantener solo las últimas 200 (eliminar la más antigua si se supera)
        local MAX_HISTORY = 200
        if #Data.history["TODAS"] > MAX_HISTORY then
            table.remove(Data.history["TODAS"], 1)
        end
        if matched then 
            table.insert(Data.history[matched], entry)
            if #Data.history[matched] > MAX_HISTORY then
                table.remove(Data.history[matched], 1)
            end
            Data.raidGroups[matched][sender] = true
        end  
        local mostrarPorDungeon = Data.selectedDungeons["TODAS"]
        if not mostrarPorDungeon and matched then
            if Data.selectedDungeons[matched] then
                if Data.dungeonDifficulties[matched] then
                    -- Usar matchedDiff que ya calculamos arriba (FIX #2)
                    if matchedDiff and Data.selectedDifficulties[matched] and Data.selectedDifficulties[matched][matchedDiff] then
                        mostrarPorDungeon = true
                    end
                else
                    -- Dungeons without difficulties (SEMANAL, VIAJEROS, FOSO)
                    mostrarPorDungeon = true
                end
            end
        end  
        if mostrarPorDungeon then
            local mostrarPorTermino = false
            if Data.searchTerm == "" then
                mostrarPorTermino = true
            else
                for word in Data.searchTerm:gmatch("%S+") do
                    if string.find(formatted:upper(), word:upper(), 1, true) then
                        mostrarPorTermino = true
                        break
                    end
                end
            end
            
            if mostrarPorTermino then
                if not Data.hideGrays or matched then 
                    Frames.chatWin.text:AddMessage(formatted)
                end
            end
        end
        
        Data.userMessages[sender] = {
            time = now,
            msg = msg,
            dungeon = matched,
            difficulty = matchedDiff,
        }
        if matched then
            DeferRaidList()
        end
    end
end

-- ===== SLASH COMMANDS =====
SLASH_PROCHAT1 = "/pc"
SLASH_PROCHAT2 = "/prochat"

SlashCmdList["PROCHAT"] = function(msg)
    if msg == "reset" then
        ProChat.Core:ResetAddon()
    else 
        local chatWin = Frames.chatWin
        if chatWin:IsVisible() then 
            chatWin:Hide()
            Utils:SaveWindowState(false)
        else 
            chatWin:Show()
            Utils:SaveWindowState(true)
        end 
    end
end

function ProChat.Core:ResetAddon()
    if ProChatDB then
        ProChatDB.mmAngle = 45
        ProChatDB.showWindows = true
        ProChatDB.showRaidWin = true
        ProChatDB.uiScale = 1.0
        ProChatDB.fontSize = 12
        ProChatDB.filterTime = 60
        ProChatDB.hideGrays = false
        ProChatDB.showMinimap = true
        ProChatDB.showOptions = true
        ProChatDB.opacity = 75
        ProChatDB.selectedDungeons = nil
        ProChatDB.selectedDifficulties = nil
        ProChatDB.selectedChannels = nil
        ProChatDB.selectedRoles = nil  -- FIX BUG 4: resetear roles guardados
    end
    
    Frames.chatWin:ClearAllPoints()
    Frames.chatWin:SetPoint("CENTER")
    Frames.chatWin:SetSize(500, 250)
    Frames.chatWin:SetScale(1.0)
    if UI.fontSlider then UI.fontSlider:SetValue(12) end
    if UI.opacitySlider then
        UI.opacitySlider:SetValue(75)
        Frames.chatWin:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
    end
    
    Data.filterTime = 60
    if UI.timeDrop and UI.timeDrop._btnText then UI.timeDrop._btnText:SetText("1min") end
    
    Data.searchTerm = ""
    if UI.searchBox then UI.searchBox:SetText("") end
    
    Utils:ResetAllData()

     -- FIX: Reinicializar dungeons y dificultades después del reset
    Data.selectedDungeons = { ["TODAS"] = true }
    for _, k in ipairs(Data.keywords) do
        Data.selectedDungeons[k] = false
        Data.selectedDifficulties[k] = {}
        if Data.dungeonDifficulties[k] then
            for _, diff in ipairs(Data.dungeonDifficulties[k]) do
                Data.selectedDifficulties[k][diff] = true
            end
        end
    end
    if not ProChat.Data:IsDungeonVisible("VIAJEROS") then
        Data.selectedDungeons["VIAJEROS"] = false
    end

    Data.selectedChannels = {}
    if UI.chanDrop and UI.chanDrop._refreshText then
        UI.chanDrop._refreshText()
    end
    
    if UI.checkRaid and not UI.checkRaid:GetChecked() then UI.checkRaid:Click() end
    if UI.checkGrays and UI.checkGrays:GetChecked() then UI.checkGrays:Click() end
    if UI.checkOptions and not UI.checkOptions:GetChecked() then UI.checkOptions:Click() end
    if UI.checkMM and not UI.checkMM:GetChecked() then UI.checkMM:Click() end
    if UI.autoLFGSwitch and UI.autoLFGSwitch:GetChecked() then UI.autoLFGSwitch:Click() end
    
    if Frames.chatWin.text then Frames.chatWin.text:Clear() end
    if Frames.chatWin.raidText then Frames.chatWin.raidText:Clear() end

    -- FIX BUG 4: Resetear roles a DPS por defecto
    ProChat.Data.selectedRoles = { ["DPS"] = true }
    if Frames.chatWin.roleButtons then
        for role, btn in pairs(Frames.chatWin.roleButtons) do
            btn.selected = (role == "DPS")
            if btn.icon then
                if btn.selected then btn.icon:SetVertexColor(1,1,1)
                else btn.icon:SetVertexColor(0.35,0.35,0.35) end
            end
        end
    end
    
    Utils:UpdateMinimapPos()
    DeferRaidList()
    DeferRefresh()
    
    if Frames.chatWin.isMinimized then
        Frames.chatWin.isMinimized = false
        ProChatDB.isMinimized = false
        Frames.chatWin.minBtn.label:SetText("_")
        Frames.chatWin.minBtn:ClearAllPoints()
        Frames.chatWin.minBtn:SetPoint("RIGHT", Frames.chatWin.closeBtn, "LEFT", -2, 0)
        Frames.chatWin.closeBtn:Show()
        -- Restaurar contenido visual
        Frames.chatWin:ShowContent()
        if Frames.chatWin.opacitySlider then Frames.chatWin.opacitySlider:Show() end
        if Frames.chatWin.resizeHandle then Frames.chatWin.resizeHandle:Show() end
        if ProChat.UI.tabLFG  then ProChat.UI.tabLFG:Show()  end
        if ProChat.UI.tabLFM  then ProChat.UI.tabLFM:Show()  end
        if ProChat.UI.tabRAID then ProChat.UI.tabRAID:Show() end
        if ProChat.UI.tabREG  then ProChat.UI.tabREG:Show()  end
        ProChat.Core:SelectTab(Frames.chatWin.oldTab or ProChat.Data.currentTab or "LFG")
    end

    if Frames.welcomeWin then Frames.welcomeWin:Show() end
    Frames.chatWin:Show()
    
    local resetMsg = L["RESET_MSG"]
    
    print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " .. resetMsg)
end