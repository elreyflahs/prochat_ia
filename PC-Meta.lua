-- PC-Meta.lua - ProChat IA v1.0 - 3.3.5
-- Ciclo de vida, eventos, configuración inicial, slash commands, reset.
-- Migrado desde PC-Core.lua
-- Por Elreyflahs

ProChat = ProChat or {}
ProChat.Core = ProChat.Core or {}

-- Aliases locales
local Data   = ProChat.Data
local Utils  = ProChat.Utils
local L      = ProChat.L
local UI     = ProChat.UI
local Frames = ProChat.Frames

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

        local chatWin        = Frames.chatWin
        local autoLFGActive  = ProChat.Data.autoLFGActive
        if chatWin.roleButtons then
            for _, btn in pairs(chatWin.roleButtons) do
                if isVisible and autoLFGActive then btn:Show() else btn:Hide() end
            end
        end
        if chatWin.roleTitleLabel then
            if isVisible and autoLFGActive then chatWin.roleTitleLabel:Show()
            else chatWin.roleTitleLabel:Hide() end
        end

        if isVisible then
            Frames.chatWin.text:SetPoint("TOPLEFT", 15, -75)
        else
            Frames.chatWin.text:SetPoint("TOPLEFT", 15, -30)
        end
        if Frames.chatWin.UpdateLayout then Frames.chatWin.UpdateLayout() end
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
        if not isActive then
            if UI.autoLFGEye then UI.autoLFGEye:UpdateState(false) end
            if MiniMapLFGFrame then MiniMapLFGFrame:Show() end
            local chatWin = Frames.chatWin
            if chatWin.roleButtons then
                for _, btn in pairs(chatWin.roleButtons) do btn:Hide() end
            end
            if chatWin.roleTitleLabel then chatWin.roleTitleLabel:Hide() end
            ProChat.Core:LeaveQueue()
        else
            ProChat.Core:QueueForDungeons()
        end
    end)
end

-- ===== APPLY SAVED SETTINGS =====
function ProChat.Core:ApplySavedSettings()
    ProChatDB.mmAngle     = ProChatDB.mmAngle     or 45
    ProChatDB.showWindows = (ProChatDB.showWindows == nil) and true or ProChatDB.showWindows

    Data.hideGrays  = ProChatDB.hideGrays  or false
    Data.filterTime = ProChatDB.filterTime or 60

    if ProChatDB.selectedDungeons    then Data.selectedDungeons    = ProChatDB.selectedDungeons    end
    if ProChatDB.selectedDifficulties then Data.selectedDifficulties = ProChatDB.selectedDifficulties end

    ProChat.Core:RefreshFilterDropBtnText()
    Utils:UpdateMinimapPos()

    if ProChatDB.uiScale then
        Frames.chatWin:SetScale(ProChatDB.uiScale)
    else
        ProChatDB.uiScale = 1.0
    end

    if ProChatDB.opacity then
        Frames.chatWin:SetBackdropColor(0.05, 0.05, 0.05, ProChatDB.opacity / 100)
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
        local timeLabels = { [30]="30s", [60]="1min", [120]="2min", [180]="3min", [300]="5min" }
        local lbl = timeLabels[ProChatDB.filterTime]
        if lbl then UI.timeDrop._btnText:SetText(lbl) end
    end

    if UI.opacitySlider then UI.opacitySlider:Show() end

    if ProChatDB.showWindows then
        Frames.chatWin:Show()
        if ProChatDB.isMinimized then
            Frames.chatWin:SetSize(150, 22)
            Frames.chatWin.minBtn:ClearAllPoints()
            Frames.chatWin.minBtn:SetPoint("TOPRIGHT", Frames.chatWin, "TOPRIGHT", -2, -4)
            Frames.chatWin.minBtn.label:SetText("<>")
            Frames.chatWin.closeBtn:Hide()
            if Frames.chatWin.resizeHandle then Frames.chatWin.resizeHandle:Hide() end
            Frames.chatWin:HideContent()
            Frames.chatWin.isMinimized = true
            if ProChatDB.windowPosMin then
                Frames.chatWin:ClearAllPoints()
                Frames.chatWin:SetPoint(unpack(ProChatDB.windowPosMin))
            end
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
                Frames.chatWin:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                    ProChatDB.windowX, ProChatDB.windowY)
            end
            if ProChatDB.windowSizeMax then
                Frames.chatWin:SetSize(unpack(ProChatDB.windowSizeMax))
            end

            if UI.checkRaid then
                local raidState = ProChatDB.showRaidWin
                if raidState == nil then raidState = true end
                UI.checkRaid:SetChecked(raidState)
                ProChat.Core:ApplyRaidVisibility(raidState)
            end

            if UI.checkOptions then
                if ProChatDB.showOptions == nil then ProChatDB.showOptions = true end
                UI.checkOptions:SetChecked(ProChatDB.showOptions)
                if ProChatDB.showOptions then
                    Frames.chatWin.text:SetPoint("TOPLEFT", 15, -75)
                else
                    Frames.chatWin.text:SetPoint("TOPLEFT", 15, -30)
                end
                if Frames.chatWin.UpdateLayout then Frames.chatWin.UpdateLayout() end
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
        elseif event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_SAY"
            or event == "CHAT_MSG_YELL"    or event == "CHAT_MSG_GUILD" then
            ProChat.Core:OnChatMessage(event, ...)
        end
    end)
end

-- ===== PLAYER ENTERING WORLD =====
function ProChat.Core:OnPlayerEnteringWorld()
    local msgInicio  = L["START_MSG"]  or "Cargado. Versión"
    local statusText = L["STATUS_TXT"] or "Estado: |cff00ff00Addon Actualizado|r."
    print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: "
        .. msgInicio .. " |cffffffff" .. ProChat.CURRENT_VERSION .. "|r. " .. statusText)
end

-- ===== COMBAT =====
function ProChat.Core:OnCombat()
    local chatWin = Frames.chatWin
    if chatWin:IsVisible() and not chatWin.isMinimized then
        if chatWin.minBtn then
            chatWin.minBtn:GetScript("OnClick")()
        end
    end
end

-- ===== CHAT MESSAGE =====
function ProChat.Core:OnChatMessage(event, ...)
    local msg, sender, _, _, _, _, _, _, chanName, _, _, guid = ...

    if sender then sender = strsplit("-", sender) end

    if     event == "CHAT_MSG_SAY"   then chanName = "Decir"
    elseif event == "CHAT_MSG_YELL"  then chanName = "Gritar"
    elseif event == "CHAT_MSG_GUILD" then chanName = "Hermandad"
    end

    if not Frames.chatWin:IsVisible() or not chanName then return end

    local isSelected = false
    local chanUpper  = chanName:upper()
    for selectedName, active in pairs(Data.selectedChannels) do
        if active and string.find(chanUpper, selectedName:upper()) then
            isSelected = true; break
        end
    end
    if not isSelected then return end

    local now                = GetTime()
    local currentFilterLimit = Data.filterTime or 60
    local puedeMostrar       = false
    if not Data.userMessages[sender]
        or (now - Data.userMessages[sender].time >= currentFilterLimit) then
        puedeMostrar = true
    end

    if puedeMostrar then
        local matched     = Utils:MatchDungeonKeyword(msg)
        local matchedDiff = nil
        if matched then
            matchedDiff = Utils:MatchDifficultyKeyword(msg, matched)
        end

        local cat      = matched or "TODAS"
        local c        = Data.filterColors[cat] or "ffffff"
        local msgColor = Utils:LightenHexColor(c, 0.45)

        local cleanName  = chanName:gsub("%d+%.%s*", ""):upper()
        local tagData    = Data.channelTags[cleanName] or {t=string.sub(cleanName,1,1), c="ffffff"}
        local dungeonTag = matched and (" |cff"..c.."["..matched.."]|r") or ""
        local timeStamp  = Utils:GetFormattedTime()

        local formatted = timeStamp
            .." |cff"..tagData.c.."["..tagData.t.."]|r"
            .." |cff"..c.."[|r|Hplayer:"..sender.."|h|cff"
            ..Utils:GetClassColor(guid, sender)..sender.."|r|h|cff"..c.."]|r"
            ..dungeonTag..": "..Utils:ColorMessageText(msg, msgColor)

        local entry = {
            formatted  = formatted,
            raw        = msg,
            dungeon    = matched,
            difficulty = matchedDiff,
        }

        local MAX_HISTORY = 200
        table.insert(Data.history["TODAS"], entry)
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
                    if matchedDiff and Data.selectedDifficulties[matched]
                        and Data.selectedDifficulties[matched][matchedDiff] then
                        mostrarPorDungeon = true
                    end
                else
                    mostrarPorDungeon = true
                end
            end
        end

        if mostrarPorDungeon then
            local mostrarPorTermino = (Data.searchTerm == "")
            if not mostrarPorTermino then
                for word in Data.searchTerm:gmatch("%S+") do
                    if string.find(formatted:upper(), word:upper(), 1, true) then
                        mostrarPorTermino = true; break
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
            time       = now,
            msg        = msg,
            dungeon    = matched,
            difficulty = matchedDiff,
        }
        if matched then DeferRaidList() end
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

-- ===== RESET ADDON =====
function ProChat.Core:ResetAddon()
    if ProChatDB then
        ProChatDB.mmAngle             = 45
        ProChatDB.showWindows         = true
        ProChatDB.showRaidWin         = true
        ProChatDB.uiScale             = 1.0
        ProChatDB.fontSize            = 12
        ProChatDB.filterTime          = 60
        ProChatDB.hideGrays           = false
        ProChatDB.showMinimap         = true
        ProChatDB.showOptions         = true
        ProChatDB.opacity             = 75
        ProChatDB.selectedDungeons    = nil
        ProChatDB.selectedDifficulties = nil
        ProChatDB.selectedChannels    = nil
        ProChatDB.selectedRoles       = nil
    end

    Frames.chatWin:ClearAllPoints()
    Frames.chatWin:SetPoint("CENTER")
    Frames.chatWin:SetSize(500, 250)
    Frames.chatWin:SetScale(1.0)
    if UI.fontSlider    then UI.fontSlider:SetValue(12) end
    if UI.opacitySlider then
        UI.opacitySlider:SetValue(75)
        Frames.chatWin:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
    end

    Data.filterTime = 60
    if UI.timeDrop and UI.timeDrop._btnText then UI.timeDrop._btnText:SetText("1min") end

    Data.searchTerm = ""
    if UI.searchBox then UI.searchBox:SetText("") end

    Utils:ResetAllData()

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
    if UI.chanDrop and UI.chanDrop._refreshText then UI.chanDrop._refreshText() end

    if UI.checkRaid    and not UI.checkRaid:GetChecked()    then UI.checkRaid:Click()    end
    if UI.checkGrays   and UI.checkGrays:GetChecked()       then UI.checkGrays:Click()   end
    if UI.checkOptions and not UI.checkOptions:GetChecked() then UI.checkOptions:Click() end
    if UI.checkMM      and not UI.checkMM:GetChecked()      then UI.checkMM:Click()      end
    if UI.autoLFGSwitch and UI.autoLFGSwitch:GetChecked()   then UI.autoLFGSwitch:Click() end

    if Frames.chatWin.text     then Frames.chatWin.text:Clear()     end
    if Frames.chatWin.raidText then Frames.chatWin.raidText:Clear() end

    ProChat.Data.selectedRoles = { ["DPS"] = true }
    if Frames.chatWin.roleButtons then
        for role, btn in pairs(Frames.chatWin.roleButtons) do
            btn.selected = (role == "DPS")
            if btn.icon then
                if btn.selected then btn.icon:SetVertexColor(1,1,1)
                else                 btn.icon:SetVertexColor(0.35,0.35,0.35) end
            end
        end
    end

    Utils:UpdateMinimapPos()
    DeferRaidList()
    DeferRefresh()

    if Frames.chatWin.isMinimized then
        Frames.chatWin.isMinimized = false
        ProChatDB.isMinimized      = false
        Frames.chatWin.minBtn.label:SetText("_")
        Frames.chatWin.minBtn:ClearAllPoints()
        Frames.chatWin.minBtn:SetPoint("RIGHT", Frames.chatWin.closeBtn, "LEFT", -2, 0)
        Frames.chatWin.closeBtn:Show()
        Frames.chatWin:ShowContent()
        if Frames.chatWin.opacitySlider then Frames.chatWin.opacitySlider:Show() end
        if Frames.chatWin.resizeHandle  then Frames.chatWin.resizeHandle:Hide()  end
        if ProChat.UI.tabLFG  then ProChat.UI.tabLFG:Show()  end
        if ProChat.UI.tabLFM  then ProChat.UI.tabLFM:Show()  end
        if ProChat.UI.tabRAID then ProChat.UI.tabRAID:Show() end
        if ProChat.UI.tabREG  then ProChat.UI.tabREG:Show()  end
        ProChat.Core:SelectTab(Frames.chatWin.oldTab or ProChat.Data.currentTab or "LFG")
    end

    if Frames.welcomeWin then Frames.welcomeWin:Show() end
    Frames.chatWin:Show()

    print("[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: " ..
        (L["RESET_MSG"] or "Reset completo."))
end
