-- ProChat IA v1.0 - 3.3.5 - Frames Module
-- Por Elreyflahs

ProChat.FrameFactory = {}

local Data = ProChat.Data
local Utils = ProChat.Utils
local L = ProChat.L
local UI = ProChat.UI

-- ===== CREATE MAIN WINDOW =====
function ProChat.FrameFactory:CreateMainWindow(name, title)
    local f = CreateFrame("Frame", name, UIParent)

    f.HideContent = function(self)
        local children = {self:GetChildren()}
        for _, child in ipairs(children) do
            if child ~= self.minBtn and child ~= self.titleText:GetParent() then 
                child:Hide() 
            end
        end
        local regions = {self:GetRegions()}
        for _, region in ipairs(regions) do
            if region:IsObjectType("FontString") and region ~= self.titleText then
                region:Hide()
            end
        end
        -- Forzar título visible siempre
        if self.titleText then self.titleText:Show() end
    end

    f.ShowContent = function(self)
        local children = {self:GetChildren()}
        for _, child in ipairs(children) do
            if child ~= self.minBtn then child:Show() end
        end
    end

    local width = (name == "PC_ChatWin") and 500 or 250 
    
    f:SetSize(width, 250)
    if ProChatDB and ProChatDB.windowX then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ProChatDB.windowX, ProChatDB.windowY)
    else
        f:SetPoint("CENTER")
    end
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)

    if name == "PC_ChatWin" then 
        f:SetMinResize(500, 200) 
    else 
        f:SetMinResize(250, 250) 
    end

    ProChat.Utils:ApplyStandardBackdrop(f)

    -- Header texture (reducido a 18px)
    if not f.headerTex then
        f.headerTex = f:CreateTexture(nil, "OVERLAY")
        f.headerTex:SetHeight(18)
        f.headerTex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.headerTex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        f.headerTex:SetTexture(0.10, 0.10, 0.10, 1)
    end

    -- ===== HELPER: Crear botón cuadrado custom =====
    local function MakeSquareBtn(parent, size, bgR, bgG, bgB, label, fontSize)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(size, size)
        btn:SetFrameLevel(parent:GetFrameLevel() + 10)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(bgR, bgG, bgB, 0.85)
        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetAllPoints()
        fs:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 8)
        fs:SetText(label)
        fs:SetTextColor(0.05, 0.05, 0.05, 1)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        -- FIX 3: Guardar color actual en el botón para que el hover siempre use
        -- el color correcto aunque se haya cambiado (verde → naranja al minimizar)
        btn._cr, btn._cg, btn._cb = bgR, bgG, bgB
        btn:SetScript("OnEnter", function(self)
            bg:SetTexture(math.min(self._cr * 1.4, 1), math.min(self._cg * 1.4, 1), math.min(self._cb * 1.4, 1), 1)
        end)
        btn:SetScript("OnLeave", function(self)
            bg:SetTexture(self._cr, self._cg, self._cb, 0.85)
        end)
        btn.bgTex = bg
        btn.label = fs
        return btn
    end

    -- Botón Cerrar (rojo con X)
    local close = MakeSquareBtn(f, 13, 0.85, 0.25, 0.25, "X", 8)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -3)
    close:SetScript("OnClick", function()
        ProChat.Core:CloseAllMenus()
        f:Hide()
        if name == "PC_ChatWin" then Utils:SaveWindowState(false) end
        ProChatDB.isVisible = f:IsShown()
    end)
    f.closeBtn = close

    -- Botón Minimizar (verde con _)  |  se convierte en naranja-amarillo (<>) al minimizar
    local minBtn = MakeSquareBtn(f, 13, 0.25, 0.72, 0.32, "_", 9)
    minBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)

    -- FIX #3: Title button con FontString ÚNICO
    local tBtn = CreateFrame("Button", nil, f)
    tBtn:SetSize(width - 650, 22)
    tBtn:SetPoint("TOP", 0, -0)

    -- ÚNICO FontString para el título (FIX #3)
    local t = tBtn:CreateFontString(name.."Title", "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("CENTER", 0, 0)
    t:SetText(title)
    
    -- Guardar referencia directa al FontString visible (FIX #3)
    f.titleText = t

    tBtn:RegisterForDrag("LeftButton")

    tBtn:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            f:StartMoving()
            self.downTime = GetTime()
        end
    end)

    -- Doble-click en el header: minimizar/maximizar (igual que el botón minBtn)
    tBtn:SetScript("OnDoubleClick", function(self, button)
        if button == "LeftButton" then
            self.wasDragging = false  -- cancelar el click normal
            minBtn:GetScript("OnClick")()
        end
    end)

    if name == "PC_ChatWin" then 
        tBtn:SetScript("OnClick", function(self) 
            if not self.wasDragging then
                local credWin = ProChat.Frames.credWin
                if credWin:IsVisible() then 
                    credWin:Hide() 
                else 
                    credWin:Show() 
                end 
            end
            self.wasDragging = false
        end) 
    end

    f.isMinimized = false
    f.minBtn = minBtn

    minBtn:SetScript("OnClick", function()
        ProChat.Core:CloseAllMenus()
        if not f.isMinimized then
            -- GUARDAR ESTADO ACTUAL
            if not f.oldHeight or not f.oldWidth then
                f.oldHeight = f:GetHeight()
                f.oldWidth = f:GetWidth()
            end
            local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint()
            ProChatDB.windowPosMax = {point, relativeTo, relativePoint, xOfs, yOfs}
            f.oldTitle = f.titleText:GetText()
            f.raidWinWasVisible = f.raidWin and f.raidWin:IsShown()
            f.oldTab = ProChat.Data.currentTab
            local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint()
            f.oldPos = {point, relativeTo, relativePoint, xOfs, yOfs}
        
            f:ClearAllPoints()
            if f.oldPosMin then
                f:SetPoint(unpack(f.oldPosMin))
            else
                f:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
            end
        
            -- MINIMIZAR
            local mPoint, mRelTo, mRelPoint, mX, mY = f:GetPoint()
            ProChatDB.windowPosMin = {mPoint, mRelTo, mRelPoint, mX, mY}
            ProChatDB.windowSizeMax = {f:GetWidth(), f:GetHeight()}
            f:SetSize(150, 18)
            f.titleText:SetText("|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r")
            minBtn:ClearAllPoints()
            minBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -3)
            -- FIX 3: Color naranja claro para botón maximizar
            minBtn.label:SetText("<>")
            if minBtn.bgTex then minBtn.bgTex:SetTexture(1.0, 0.55, 0.1, 0.85) end
            minBtn._cr, minBtn._cg, minBtn._cb = 1.0, 0.55, 0.1
            f.closeBtn:Hide()
            if f.resizer then f.resizer:Hide() end

            f:HideContent()
            -- Forzar título visible y posición correcta en barra minimizada
            local tBtn2 = f.titleText and f.titleText:GetParent()
            if tBtn2 and tBtn2 ~= f then
                tBtn2:Show()
                tBtn2:ClearAllPoints()
                tBtn2:SetPoint("CENTER", f, "CENTER", -10, 0)
                tBtn2:SetWidth(100)
            end
            f.titleText:SetText("|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r")
            f.titleText:Show()

            f.isMinimized = true
            ProChatDB.isMinimized = true

            -- Mostrar/crear ojo completo en barra minimizada (con animación y tooltip)
            if ProChat.Data and ProChat.Data.autoLFGActive then
                if not f._minEyeBtn then
                    -- Crear botón-ojo para la barra minimizada
                    local minEye = CreateFrame("Button", "PC_MinEyeBtn", f)
                    minEye:SetSize(14, 14)
                    minEye:SetPoint("LEFT", f, "LEFT", 4, 0)
                    minEye:SetFrameLevel(f:GetFrameLevel() + 8)

                    local minEyeIcon = minEye:CreateTexture(nil, "ARTWORK")
                    minEyeIcon:SetAllPoints()
                    minEyeIcon:SetTexture("Interface\\AddOns\\!ProChat_IA\\Media\\pcia_icons_g1")
                    minEyeIcon:SetTexCoord(0.5, 1, 0, 0.5)
                    minEyeIcon:SetVertexColor(0, 1, 0.8, 1)
                    minEye.icon = minEyeIcon

                    -- Animación de rotación (igual que el ojo completo)
                    local minAnim = minEyeIcon:CreateAnimationGroup()
                    minAnim:SetLooping("REPEAT")
                    local minRot = minAnim:CreateAnimation("Rotation")
                    minRot:SetDegrees(360)
                    minRot:SetDuration(4)
                    minRot:SetOrigin("CENTER", 0, 0)
                    minEye.anim = minAnim

                    -- Tooltip idéntico al ojo de la ventana maximizada
                    minEye:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        if ProChat.Data.autoLFGActive then
                            GameTooltip:AddLine("|cff00FFCCAuto-LFG|r: |cff00ff00Activo|r", 1, 1, 1)
                            local count = 0
                            for _, k in ipairs(ProChat.Data.keywords) do
                                if ProChat.Data.selectedDungeons[k] then count = count + 1 end
                            end
                            if ProChat.Data.selectedDungeons["TODAS"] then count = #ProChat.Data.keywords end
                            GameTooltip:AddLine("Mazmorras: |cffffffff"..count.."|r", 1, 1, 0.7)
                            GameTooltip:AddLine("Tiempo de espera: |cffffffff<1min|r", 0.7, 1, 0.7)
                        else
                            GameTooltip:AddLine("|cff888888Auto-LFG|r: |cffff4444Desactivado|r", 1, 1, 1)
                        end
                        GameTooltip:Show()
                    end)
                    minEye:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    -- Click en el ojo minimizado: salir de la cola (misma lógica que el switch)
                    minEye:SetScript("OnClick", function()
                        ProChat.Core:LeaveQueue()
                    end)

                    f._minEyeBtn = minEye
                end
                f._minEyeBtn:Show()
                if f._minEyeBtn.anim then f._minEyeBtn.anim:Play() end
                -- Compatibilidad con código que usa _minEyeIcon
                f._minEyeIcon = f._minEyeBtn
            end
        else
            -- MAXIMIZAR
            local mPoint, mRelTo, mRelPoint, mX, mY = f:GetPoint()
            f.oldPosMin = {mPoint, mRelTo, mRelPoint, mX, mY}
        
            f:ClearAllPoints()
            if ProChatDB.windowPosMax then
                f:SetPoint(unpack(ProChatDB.windowPosMax))
            else
                f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        
            if ProChatDB.windowSizeMax then
                f:SetSize(unpack(ProChatDB.windowSizeMax))
            else
                f:SetSize(f.oldWidth or 500, f.oldHeight or 250)
            end
            f.titleText:SetText(f.oldTitle or title)
        
            minBtn:ClearAllPoints()
            minBtn:SetPoint("RIGHT", f.closeBtn, "LEFT", -2, 0)
            minBtn.label:SetText("_")
            -- FIX 3: Restaurar color verde al maximizar
            minBtn.bgTex = minBtn.bgTex or select(1, minBtn:GetRegions())
            if minBtn.bgTex then minBtn.bgTex:SetTexture(0.25, 0.72, 0.32, 0.85) end
            minBtn._cr, minBtn._cg, minBtn._cb = 0.25, 0.72, 0.32
            f.closeBtn:Show()

            f.isMinimized = false
            ProChatDB.isMinimized = false

            -- FIX 2: Ocultar icono AutoLFGEye de la barra minimizada (si existía)
            if f._minEyeBtn then
                if f._minEyeBtn.anim then f._minEyeBtn.anim:Stop() end
                f._minEyeBtn:Hide()
            end
            if f._minEyeIcon and f._minEyeIcon ~= f._minEyeBtn then f._minEyeIcon:Hide() end

            -- Mostrar contenido
            if name == "PC_ChatWin" then
                if f.opacitySlider then f.opacitySlider:Show() end
                if f.resizeHandle then f.resizeHandle:Show() end
            
                -- FIX 1: Mostrar TODAS las tabs al maximizar
                if ProChat.UI.tabLFG  then ProChat.UI.tabLFG:Show()  end
                if ProChat.UI.tabLFM  then ProChat.UI.tabLFM:Show()  end
                if ProChat.UI.tabRAID then ProChat.UI.tabRAID:Show() end
                if ProChat.UI.tabREG  then ProChat.UI.tabREG:Show()  end
                
                -- FIX 1: Restaurar AutoLFGEye completo (icono + texto)
                if ProChat.UI.autoLFGEye then ProChat.UI.autoLFGEye:Show() end
                if ProChat.UI.autoLFGEye and ProChat.UI.autoLFGEye.statusText then
                    ProChat.UI.autoLFGEye.statusText:Show()
                end
                
                -- SelectTab decide qué mostrar/ocultar según el tab guardado
                ProChat.Core:SelectTab(f.oldTab or ProChat.Data.currentTab or "LFG")
                
                -- FIX BUG 3: Restaurar el label "Opciones:" que HideContent/HideAllTabContent
                -- puede haber ocultado (es un FontString creado en el parent, no en el container).
                if ProChat.UI.checkOptions and ProChat.UI.checkOptions.switchLabel then
                    ProChat.UI.checkOptions.switchLabel:Show()
                end
                
                -- Ajustar resizer según el tab actual y el checkbox
                if f.resizer then
                    if ProChat.Data.currentTab == "LFM" then
                        f.resizer:Show()
                    elseif ProChat.UI.checkRaid and ProChat.UI.checkRaid:GetChecked() then
                        f.resizer:Show()
                    else
                        f.resizer:Hide()
                    end
                end
                local chatWin = ProChat.Frames.chatWin
                local tBtn = chatWin.titleText:GetParent()
                tBtn:Show()
                tBtn:SetWidth(100)
                tBtn:ClearAllPoints()
                tBtn:SetPoint("TOP", f, "TOP", 0, 0)
                chatWin.titleText:SetText("|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r |cffFF6666v"..ProChat.CURRENT_VERSION.."|r")
                chatWin.titleText:Show()
                chatWin.tBtn = tBtn

            else
                local children = {f:GetChildren()}
                for _, child in ipairs(children) do child:Show() end
            end
        end
    end)

    tBtn:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        f:StopMovingOrSizing()
        local duration = GetTime() - (self.downTime or 0)
        if duration > 0.2 then
            self.wasDragging = true
            -- Guardar posición maximizada
            if not f.isMinimized then
                local point, relativeTo, relativePoint, xOfs, yOfs = f:GetPoint()
                ProChatDB.windowPosMax = {point, relativeTo, relativePoint, xOfs, yOfs}
            end
        else
            self.wasDragging = false
        end
    end
end)

    -- Resize button
    local rb = CreateFrame("Button", name.."_Resize", f)
    rb:SetSize(16, 16)
    rb:SetPoint("BOTTOMRIGHT", -7, 7)
    rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rb:SetScript("OnMouseDown", function() f:StartSizing() end)
    rb:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
    f.resizeHandle = rb

    local sf = CreateFrame("ScrollingMessageFrame", name.."_Text", f)
    sf:SetPoint("TOPLEFT", 15, -75)  -- fix 2: espacio para opciones (fila switches y dropdowns)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 32)
    sf:SetFontObject(GameFontHighlightSmall)
    sf:SetMaxLines(256)
    sf:SetFading(false)
    sf:SetJustifyH("LEFT")
    sf:EnableMouseWheel(true)
    sf:SetHyperlinksEnabled(true)
    sf:SetSpacing(3)

    sf:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then 
            if IsShiftKeyDown() then 
                self:ScrollToTop() 
            else 
                self:ScrollUp() 
            end
            if ProChat.Frames.scrollBottom then 
                ProChat.Frames.scrollBottom:Show() 
            end
        else 
            if IsShiftKeyDown() then 
                self:ScrollToBottom() 
            else 
                self:ScrollDown() 
            end 
            if self:AtBottom() and ProChat.Frames.scrollBottom then 
                ProChat.Frames.scrollBottom:Hide() 
            end
        end
    end)

    -- === SISTEMA DE PESTAÑAS ===
    if name == "PC_ChatWin" then
        -- Colores de tabs: activo = color vivo, inactivo = opaco
        local tabColors = {
            LFG  = {0.7, 0.2, 0.9},  -- morado (intercambiado)
            LFM  = {0, 1, 0.8},      -- celeste (intercambiado)
            RAID = {1, 0.49, 0},      -- naranja (banda)
            REG  = {1, 1, 1},         -- blanco
        }
        local tabOrder = {"LFG", "LFM", "RAID", "REG"}

        local function CreateTab(parent, tabName, index)
            local btn = CreateFrame("Button", nil, parent)
            btn:SetSize(52, 18)
            btn:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 4 + (index-1)*54, -1)
            btn:SetFrameLevel(parent:GetFrameLevel() + 2)

            -- Fondo siempre oscuro
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(0.05, 0.05, 0.05, 0.85)

            -- Bordes: solo top + laterales cuando activo (usando 3 texturas de 1px)
            local borderTop = btn:CreateTexture(nil, "OVERLAY")
            borderTop:SetHeight(1)
            borderTop:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            borderTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
            borderTop:Hide()

            local borderL = btn:CreateTexture(nil, "OVERLAY")
            borderL:SetWidth(1)
            borderL:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            borderL:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
            borderL:Hide()

            local borderR = btn:CreateTexture(nil, "OVERLAY")
            borderR:SetWidth(1)
            borderR:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
            borderR:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
            borderR:Hide()

            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            txt:SetAllPoints()
            txt:SetJustifyH("CENTER")
            txt:SetJustifyV("MIDDLE")
            txt:SetFont("Fonts\\FRIZQT__.TTF", 9)

            local c = tabColors[tabName] or {1,1,1}
            txt:SetText(tabName)
            -- Inactivo: texto blanco
            txt:SetTextColor(1, 1, 1, 0.7)

            btn.tabName = tabName
            btn.txt = txt
            btn.tabColor = c
            btn.bg = bg

            btn.SetActive = function(self, active)
                if active then
                    -- Texto del color de la pestaña
                    self.txt:SetTextColor(self.tabColor[1], self.tabColor[2], self.tabColor[3], 1)
                    bg:SetTexture(0.08, 0.08, 0.08, 0.95)
                    -- Mostrar bordes del color de la pestaña
                    borderTop:SetTexture(self.tabColor[1], self.tabColor[2], self.tabColor[3], 0.9)
                    borderL:SetTexture(self.tabColor[1], self.tabColor[2], self.tabColor[3], 0.9)
                    borderR:SetTexture(self.tabColor[1], self.tabColor[2], self.tabColor[3], 0.9)
                    borderTop:Show() borderL:Show() borderR:Show()
                else
                    -- Texto blanco semi-opaco
                    self.txt:SetTextColor(1, 1, 1, 0.7)
                    bg:SetTexture(0.05, 0.05, 0.05, 0.85)
                    borderTop:Hide() borderL:Hide() borderR:Hide()
                end
            end

            btn:SetScript("OnClick", function()
                ProChat.Core:SelectTab(tabName)
            end)

            return btn
        end

        UI.tabLFG  = CreateTab(f, "LFG",  1)
        UI.tabLFM  = CreateTab(f, "LFM",  2)
        UI.tabRAID = CreateTab(f, "RAID", 3)
        UI.tabREG  = CreateTab(f, "REG",  4)

        self:CreateRaidPanel(f)
        
    -- ===== ROLE BUTTONS (Auto-LFG) =====
        local roleButtons = {}
        local playerClass = ProChat.Data:GetPlayerClass()
        local roles = ProChat.Data.classRoles[playerClass] or {}
        
        local roleCoords = {
            ["TANK"]   = {0.3, 0, 0.32, 0.62},
            ["HEALER"] = {0.28, 0.58, 0, 0.29},
            ["DPS"]    = {0.3, 0.6, 0.32, 0.62},
        }

        local roleTooltips = {
            ["TANK"] = "TANK",
            ["HEALER"] = "HEALER",
            ["DPS"] = "DPS",
        }

        -- FIX BUG 4: Inicializar selectedRoles desde DB o con valor por defecto (DPS).
        -- Siempre debe haber al menos un rol seleccionado; DPS es el default.
        do
            local savedRoles = ProChatDB and ProChatDB.selectedRoles
            -- Limpiar tabla actual
            ProChat.Data.selectedRoles = {}
            if savedRoles then
                -- Restaurar solo los roles que la clase actual soporta
                local hasAny = false
                for _, role in ipairs(roles) do
                    if savedRoles[role] then
                        ProChat.Data.selectedRoles[role] = true
                        hasAny = true
                    end
                end
                -- Si ninguno coincide con la clase, caer al default
                if not hasAny then
                    ProChat.Data.selectedRoles["DPS"] = true
                end
            else
                -- Sin datos guardados: si clase tiene un solo rol, ese; si no, DPS
                if #roles == 1 then
                    ProChat.Data.selectedRoles[roles[1]] = true
                elseif #roles > 1 then
                    ProChat.Data.selectedRoles["DPS"] = true
                end
            end
        end
        
        local function CreateRoleButton(role, index)
            local btn = CreateFrame("Button", nil, f)
            btn:SetSize(20, 20)
            btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)  -- temporal, se reancla en CreateUI
            btn._roleIndex = index
            
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
            local coords = roleCoords[role] or {0, 1, 0, 1}
            icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            
            btn.role = role
            btn.icon = icon
            -- FIX BUG 4: estado inicial desde selectedRoles ya inicializado arriba
            btn.selected = ProChat.Data.selectedRoles[role] and true or false

            local function updateVisual(b)
                if b.selected then
                    b.icon:SetVertexColor(1, 1, 1)
                else
                    b.icon:SetVertexColor(0.35, 0.35, 0.35)
                end
            end
            
            btn:SetScript("OnClick", function(self)
                -- FIX BUG 4: No bloquear toggle si hay un solo rol disponible para la clase,
                -- ya que siempre debe quedar seleccionado.
                local newVal = not self.selected
                -- Verificar que al desmarcar no quede todo vacío
                if not newVal then
                    local countAfter = 0
                    for _, r in ipairs(roles) do
                        if ProChat.Data.selectedRoles[r] and r ~= self.role then
                            countAfter = countAfter + 1
                        end
                    end
                    if countAfter == 0 then return end  -- impedir dejar sin roles
                end
                self.selected = newVal
                if self.selected then
                    ProChat.Data.selectedRoles[self.role] = true
                else
                    ProChat.Data.selectedRoles[self.role] = nil
                end
                -- FIX BUG 4: Guardar en DB para persistir entre sesiones
                if ProChatDB then
                    ProChatDB.selectedRoles = {}
                    for k, v in pairs(ProChat.Data.selectedRoles) do
                        ProChatDB.selectedRoles[k] = v
                    end
                end
                updateVisual(self)
                if ProChat.Data.autoLFGActive then
                    ProChat.Core:AutoLFGUpdate()
                end
            end)

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(roleTooltips[self.role] or self.role, 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            updateVisual(btn)
            
            return btn
        end
        
        for i, role in ipairs(roles) do
            roleButtons[role] = CreateRoleButton(role, i)
        end
        
        -- Título "Selec. Rol" encima de los botones de roles, anclado al primer botón
        local roleTitleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        roleTitleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)  -- temporal, se reancla en CreateUI
        roleTitleLabel:SetFont("Fonts\\FRIZQT__.TTF", 8)
        roleTitleLabel:SetText("Selec. Rol")
        roleTitleLabel:SetTextColor(0, 1, 0.8, 1)
        roleTitleLabel:Hide()
        f.roleTitleLabel = roleTitleLabel
        
        -- Ocultar todos los botones de rol por defecto
        for _, btn in pairs(roleButtons) do btn:Hide() end
        f.roleButtons = roleButtons
    end

    -- Hyperlink handler
    local function handleHyperlinks(self, link, text, button)
        local type, value = strsplit(":", link)
        if type == "player" then
            if button == "RightButton" then
                if ProChat.Data.currentTab == "LFG" and ProChat.ContextMenu then
                    ProChat.ContextMenu:SetLFGTarget(value)
                end
                FriendsFrame_ShowDropdown(value, 1)
            elseif IsShiftKeyDown() then 
                local eb = ChatEdit_GetActiveWindow()
                if eb then eb:Insert(text) else SendWho(value) end
            else 
                ChatFrame_OpenChat("/w "..value.." ", DEFAULT_CHAT_FRAME) 
            end
        elseif type == "raidclick" then 
            Data.collapsed[value] = not Data.collapsed[value]
            Utils:UpdateRaidList()
        else 
            ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
            ItemRefTooltip:SetHyperlink(link)
            ItemRefTooltip:Show() 
        end
    end

    sf:SetScript("OnHyperlinkClick", handleHyperlinks)
    if f.raidText then
        f.raidText:SetScript("OnHyperlinkClick", handleHyperlinks)
    end

    -- Window drag
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not IsModifierKeyDown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        if not self.isMinimized then
            local x, y = self:GetLeft(), self:GetTop()
            ProChatDB.windowX = x
            ProChatDB.windowY = y - UIParent:GetHeight()
            ProChatDB.windowSizeMax = {self:GetWidth(), self:GetHeight()}
        else
            -- FIX BUG 6: Guardar posición de la barra minimizada al arrastrarla
            local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
            ProChatDB.windowPosMin = {point, relativeTo, relativePoint, xOfs, yOfs}
            self.oldPosMin = {point, relativeTo, relativePoint, xOfs, yOfs}
        end
    end)

    -- ===== LFM WINDOW (Tabla de jugadores) =====
    local lfmWin = CreateFrame("Frame", "PC_LFMWin", f)
    lfmWin:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -55)
    lfmWin:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 32)
    lfmWin:Hide()
    
    local lfmText = lfmWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lfmText:SetPoint("TOPLEFT", lfmWin, "TOPLEFT", 0, 0)
    lfmText:SetPoint("BOTTOMRIGHT", lfmWin, "BOTTOMRIGHT", 0, 0)
    lfmText:SetJustifyH("LEFT")
    lfmWin.text = lfmText
    
    f.lfmWin = lfmWin

    f.text = sf
    
    -- Restaurar estado minimizado al cargar
    if ProChatDB and ProChatDB.isMinimized then
        f.isMinimized = true
        f.minBtn.label:SetText("<>")
        f.closeBtn:Hide()
        f:SetSize(150, 22)
        f.titleText:SetText("|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r")
        if f.raidText then f.raidText:Hide() end
    
        local children = {f:GetChildren()}
        for _, child in ipairs(children) do
            if child ~= f.minBtn then child:Hide() end
        end
        local regions = {f:GetRegions()}
        for _, region in ipairs(regions) do
            if region:IsObjectType("FontString") and region ~= f.titleText then
                region:Hide()
            end
        end
    end
        -- Mostrar la ventana si no estaba minimizada
    if not ProChatDB or not ProChatDB.isMinimized then
        if ProChatDB and ProChatDB.showWindows ~= false then
            f:Show()
        end
    end
    f.wasMinimized = ProChatDB and ProChatDB.isMinimized
    return f
end

-- ===== CREATE RAID PANEL =====
    function ProChat.FrameFactory:CreateRaidPanel(f)
        local resizer = CreateFrame("Frame", nil, f)
        resizer:SetWidth(6)
        resizer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -105, -125) 
        resizer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -210, 32)
        resizer:SetFrameLevel(f:GetFrameLevel() + 5)
        resizer:EnableMouse(true)

        local line = resizer:CreateTexture(nil, "OVERLAY")
        line:SetWidth(1)
        line:SetPoint("TOP", resizer, "TOP")
        line:SetPoint("BOTTOM", resizer, "BOTTOM")
        line:SetPoint("CENTER", resizer, "CENTER")
        line:SetTexture(0.2, 0.2, 0.2, 0.8)
        resizer.line = line
        f.resizer = resizer

                -- ===== ROLE BUTTONS (Apuntar) =====
        f.UpdateLayout = function()
            local currentOffset = f:GetRight() - resizer:GetRight()
            resizer:ClearAllPoints()
            resizer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -currentOffset, (f.text:GetTop() - f:GetTop()))
            resizer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -currentOffset, 32)

            if f.raidText then
                f.raidText:ClearAllPoints()
                f.raidText:SetPoint("TOPLEFT", resizer, "TOPRIGHT", 5, 0)
                f.raidText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 32)
            end
        end

        resizer:SetScript("OnEnter", function() resizer.line:SetTexture(0.5, 0.5, 0.5, 1) end)
        resizer:SetScript("OnLeave", function() resizer.line:SetTexture(0.2, 0.2, 0.2, 0.8) end)
        resizer:SetScript("OnMouseDown", function(self) self.isMoving = true end)
        resizer:SetScript("OnMouseUp", function(self) self.isMoving = false end)
        resizer:SetScript("OnUpdate", function(self)
            if self.isMoving then
                local x, _ = GetCursorPosition()
                local scale = f:GetEffectiveScale()
                local mouseX = x / scale
                local frameRight = f:GetRight()
                local newOffset = frameRight - mouseX

                if newOffset < 105 then newOffset = 105 end   -- 30% menos que 150
                if newOffset > 196 then newOffset = 196 end   -- 30% menos que 280

                self:SetPoint("TOPRIGHT", f, "TOPRIGHT", -newOffset, (f.text:GetTop() - f:GetTop()))
                self:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -newOffset, 32)

                f.text:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT", -5, 0)
                if f.raidText then
                    f.raidText:ClearAllPoints()
                    f.raidText:SetPoint("TOPLEFT", self, "TOPRIGHT", 5, 0)
                    f.raidText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 32)
                end
            end
        end)

        local rf = CreateFrame("ScrollingMessageFrame", "PC_RaidTextIntegrated", f)
        rf:SetFontObject(GameFontHighlightSmall)
        rf:SetMaxLines(100)
        rf:SetFading(false)
        rf:SetJustifyH("LEFT")
        rf:EnableMouseWheel(true)
        rf:SetHyperlinksEnabled(true)
        f.raidText = rf
        f.raidWin = rf
        UI.raidWin = rf
        rf:SetPoint("TOPLEFT", resizer, "TOPRIGHT", 5, 0)
        rf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 32)

        resizer:Hide()
        rf:Hide()
    end

-- ===== CREATE WELCOME WINDOW =====
    function ProChat.FrameFactory:CreateWelcomeWindow()
        local welcomeWin = CreateFrame("Frame", "PC_WelcomeWin", UIParent)
        welcomeWin:SetSize(400, 260)
        welcomeWin:SetPoint("CENTER")
        welcomeWin:Hide()
        welcomeWin:SetFrameStrata("HIGH")
        ProChat.Utils:ApplyStandardBackdrop(welcomeWin)

        local wT = welcomeWin:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        wT:SetPoint("TOP", 0, -25)
        wT:SetText(L["WELCOME_TITLE"] or "|cFFFFFFF¡Gracias por descargar ProChat IA!|r")

        local wX = welcomeWin:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        wX:SetPoint("TOP", 0, -65)
        wX:SetWidth(340)
        wX:SetJustifyH("CENTER")
        wX:SetText(L["WELCOME_TEXT"] or "Tu asistente de búsqueda de mazmorras ha sido instalado correctamente.\n\nEstado: |cff00ff00Addon Actualizado|r\nVersión: |cffFFD100")

        local wB = CreateFrame("Button", nil, welcomeWin, "UIPanelButtonTemplate")
        wB:SetSize(120, 30)
        wB:SetPoint("BOTTOM", 0, 25)
        wB:SetScript("OnClick", function() welcomeWin:Hide() end)
        wB:SetText(L["WELCOME_BTN"] or "Comenzar")

        ProChat.UI.welcomeTitle = wT
        ProChat.UI.welcomeText = wX
        ProChat.UI.welcomeButton = wB

        return welcomeWin
    end

-- ===== CREATE CREDITS WINDOW =====
    function ProChat.FrameFactory:CreateCreditsWindow()
        local credWin = CreateFrame("Frame", "PC_CreditsWin", UIParent)
        credWin:SetSize(380, 320)
        credWin:SetPoint("CENTER")
        credWin:Hide()
        credWin:SetFrameStrata("TOOLTIP")
        ProChat.Utils:ApplyStandardBackdrop(credWin)

        local cT = credWin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cT:SetPoint("TOP", 0, -15)
        cT:SetText(L["CREDITS_TITLE"] or "|cffffffCréditos|r")

        local cX = credWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cX:SetPoint("TOPLEFT", 20, -45)
        cX:SetWidth(340)
        cX:SetJustifyH("LEFT")
        cX:SetText(L["CREDITS_TEXT"] or "")

        local cC = CreateFrame("Button", nil, credWin, "UIPanelButtonTemplate")
        cC:SetSize(80, 22)
        cC:SetPoint("BOTTOM", 0, 15)
        cC:SetText(L["CREDITS_BTN"] or "Cerrar")
        cC:SetScript("OnClick", function() credWin:Hide() end)

        ProChat.UI.credTitle = cT
        ProChat.UI.credText = cX
        ProChat.UI.credButton = cC

        return credWin
    end

-- ===== CREATE MINIMAP BUTTON =====
    function ProChat.FrameFactory:CreateMinimapButton()
        local mm = CreateFrame("Button", "PC_Minimap", Minimap)
        mm:SetSize(33, 33)
        mm:EnableMouse(true)
        mm:SetFrameStrata("MEDIUM")
        mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        local highlight = mm:GetHighlightTexture()
        highlight:SetVertexColor(0.2, 0.8, 1, 0.8)
        highlight:SetBlendMode("ADD") 
        mm:SetScript("OnEnter", function(self)
        local h = self:GetHighlightTexture()
            if h then 
                h:SetVertexColor(1, 1, 1, 1)
            end
        end)

        -- Ícono normal (nota)
        local icon = mm:CreateTexture(nil, "BACKGROUND")
        icon:SetTexture("Interface\\AddOns\\!ProChat_IA\\Media\\pcia_icons_g1")
        icon:SetSize(20, 20)
        icon:SetPoint("CENTER")
        icon:SetTexCoord(0.55, 1, 0.55, 1)
        mm.icon = icon

        -- Ícono de cola activa (ojo de AutoLFG, celeste)
        local eyeIcon = mm:CreateTexture(nil, "BACKGROUND")
        eyeIcon:SetTexture("Interface\\AddOns\\!ProChat_IA\\Media\\pcia_icons_g1")
        eyeIcon:SetTexCoord(0.5, 1, 0, 0.5)
        eyeIcon:SetSize(20, 20)
        eyeIcon:SetPoint("CENTER")
        eyeIcon:SetVertexColor(0, 1, 0.8, 1)
        eyeIcon:Hide()
        mm.eyeIcon = eyeIcon

        local border = mm:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetSize(52, 52)
        border:SetPoint("TOPLEFT")
        border:SetVertexColor(0, 1, 1, 0.8)

        -- Animación de rotación anclada al eyeIcon (textura), no al frame completo.
        -- Así solo gira el ícono; el marco MiniMap-TrackingBorder queda estático.
        local animGroup = eyeIcon:CreateAnimationGroup()
        animGroup:SetLooping("REPEAT")
        local rot = animGroup:CreateAnimation("Rotation")
        rot:SetDegrees(360)
        rot:SetDuration(4)
        rot:SetOrigin("CENTER", 0, 0)  -- eje de rotación = centro exacto del ícono
        mm.anim = animGroup

        -- Función pública para cambiar estado del ícono
        mm.UpdateQueueState = function(self, active)
            if active then
                icon:Hide()
                eyeIcon:Show()
                animGroup:Play()
            else
                eyeIcon:Hide()
                icon:Show()
                animGroup:Stop()
            end
        end

        mm:RegisterForDrag("LeftButton")
        mm:SetScript("OnDragStart", function(self) 
            self:SetScript("OnUpdate", function()
                local xpos, ypos = GetCursorPosition()
                local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
                local scale = Minimap:GetEffectiveScale()
                local x = (xmin + (Minimap:GetWidth()/2)) - (xpos/scale)
                local y = (ypos/scale) - (ymin + (Minimap:GetHeight()/2))
                ProChatDB.mmAngle = math.deg(math.atan2(y, x))
                Utils:UpdateMinimapPos()
            end)
        end)

        mm:SetScript("OnDragStop", function(self) 
            self:SetScript("OnUpdate", nil) 
        end)

        mm:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFFFIA|r")
            if ProChat.Data.autoLFGActive then
                GameTooltip:AddLine("|cff00FFCCAuto-LFG:|r |cff00ff00Activo|r", 1, 1, 0.8)
                local count = 0
                for _, k in ipairs(ProChat.Data.keywords) do
                    if ProChat.Data.selectedDungeons[k] then count = count + 1 end
                end
                if ProChat.Data.selectedDungeons["TODAS"] then count = #ProChat.Data.keywords end
                GameTooltip:AddLine("En cola: |cffffffff"..count.." mazmorra(s)|r", 0.7, 1, 0.7)
            else
                GameTooltip:AddLine(L["MINIMAP_TIP"] or "Click: Mostrar/Ocultar\nArrastrar: Mover icono", 1, 1, 1)
            end
            GameTooltip:Show()
        end)

        mm:SetScript("OnLeave", function() 
            GameTooltip:Hide() 
        end)
        
        -- Siempre funciona para mostrar/ocultar ProChat, incluso en cola
        mm:SetScript("OnClick", function(self)
            local chatWin = ProChat.Frames.chatWin
            if IsControlKeyDown() then 
                ProChat.Frames.credWin:Show()
            elseif IsShiftKeyDown() then
                self:Hide()
                if UI.checkMM then UI.checkMM:SetChecked(false) end
            else
                if chatWin:IsVisible() then 
                    chatWin:Hide()
                    Utils:SaveWindowState(false)
                else
                    chatWin:Show()
                    Utils:SaveWindowState(true)
                end
            end
        end)
        return mm
    end

-- ===== CREATE SCROLL TO BOTTOM BUTTON =====
function ProChat.FrameFactory:CreateScrollButton(parent)
    local btn = CreateFrame("Button", "PC_ScrollBottom", parent)
    btn:SetSize(28, 28)
    btn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -25, 40) 
    btn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
    btn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Down")
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn:SetFrameStrata("FULLSCREEN")
    btn:Hide()
    
    btn:SetScript("OnClick", function(self)
        if parent.text then parent.text:ScrollToBottom() end
        self:Hide()
    end)
    
    return btn
end

-- ===== CREATE AUTO-LFG STATUS BAR =====
function ProChat.FrameFactory:CreateAutoLFGStatusBar(parent)
    local eyeBtn = CreateFrame("Button", "PC_AutoLFGEye", parent)
    eyeBtn:SetSize(20, 20)
    eyeBtn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -25, 8)
    eyeBtn:SetFrameLevel(parent:GetFrameLevel() + 5)

    local eyeIcon = eyeBtn:CreateTexture(nil, "ARTWORK")
    eyeIcon:SetAllPoints()
    eyeIcon:SetTexture("Interface\\AddOns\\!ProChat_IA\\Media\\pcia_icons_g1")
    eyeIcon:SetTexCoord(0.5, 1, 0, 0.5)
    eyeIcon:SetDesaturated(true)
    eyeIcon:SetVertexColor(0.5, 0.5, 0.5, 1)
    eyeBtn.icon = eyeIcon

    local animGroup = eyeBtn:CreateAnimationGroup()
    animGroup:SetLooping("REPEAT")
    local rot = animGroup:CreateAnimation("Rotation")
    rot:SetDegrees(360)
    rot:SetDuration(4)
    eyeBtn.anim = animGroup

    eyeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if ProChat.Data.autoLFGActive then
            local L2 = ProChat.L
            GameTooltip:AddLine("|cff00FFCCAuto-LFG|r: |cff00ff00Activo|r", 1, 1, 1)
            -- Contar mazmorras en cola
            local count = 0
            for _, k in ipairs(ProChat.Data.keywords) do
                if ProChat.Data.selectedDungeons[k] then count = count + 1 end
            end
            if ProChat.Data.selectedDungeons["TODAS"] then count = #ProChat.Data.keywords end
            GameTooltip:AddLine("Mazmorras: |cffffffff"..count.."|r", 1, 1, 0.7)
            GameTooltip:AddLine("Tiempo de espera: |cffffffff<1min|r", 0.7, 1, 0.7)
        else
            GameTooltip:AddLine("|cff888888Auto-LFG|r: |cffff4444Desactivado|r", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    eyeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Texto de estado al lado del ícono
    local statusText = parent:CreateFontString("PC_AutoLFGStatusText", "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("RIGHT", eyeBtn, "LEFT", -4, 0)
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    statusText:SetText("|cff888888Auto-LFG: Desactivado|r")

    eyeBtn.statusText = statusText

    -- Función para actualizar el estado visual
    eyeBtn.UpdateState = function(self, active)
        if active then
            self.icon:SetDesaturated(false)
            self.icon:SetVertexColor(0, 1, 0.8, 1) -- celeste
            self.anim:Play()
            local gs = ProChat.Core and ProChat.Core:GetGearScore() or 0
            local gsColorHex = ProChat.Utils and ProChat.Utils.GetGSColorHex and ProChat.Utils:GetGSColorHex(gs) or "ffffff"
            local gsText = (gs and gs > 0) and (string.format("%.1fk", gs/1000)) or "?"
            local roleText = ""
            for role in pairs(ProChat.Data.selectedRoles) do
                roleText = roleText .. (roleText == "" and "" or "/") .. role
            end
            statusText:SetText("|cff00FFCCAuto-LFG: Activo|r  GS: |cff"..gsColorHex..gsText.."|r  |cff00FFCCFunción:|r |cffffffff"..roleText.."|r")
        else
            self.icon:SetDesaturated(true)
            self.icon:SetVertexColor(0.5, 0.5, 0.5, 1)
            self.anim:Stop()
            statusText:SetText("|cff888888Auto-LFG: Desactivado|r")
        end
    end

    parent.autoLFGEye = eyeBtn
    ProChat.UI.autoLFGEye = eyeBtn

    return eyeBtn
end