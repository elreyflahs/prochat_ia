-- PC-Files.lua - ProChat IA v1.0 - 3.3.5
-- Menú contextual de jugadores manejado por el menú custom de PC-Events.lua
-- El click derecho en filas LFM usa FriendsFrame_ShowDropdown (menú Blizzard estándar).
-- Por Elreyflahs

ProChat = ProChat or {}
ProChat.ContextMenu = ProChat.ContextMenu or {}
ProChat.ContextMenu._pendingTarget = nil

-- SetLFGTarget: llamado desde PC-Frames.lua (click derecho en hipervínculo de jugador tab LFG)
-- Guarda el nombre para que FriendsFrame_ShowDropdown lo use.
function ProChat.ContextMenu:SetLFGTarget(playerName)
    self._pendingTarget = playerName
end

-- =========================================================
-- Construir y enviar el whisper "Pedir Party"
-- Llamado desde el menú custom (PC-Events.lua) si se desea.
-- =========================================================
function ProChat.ContextMenu:SendPartyRequest(targetName)
    local lang = (ProChatDB and ProChatDB.lang) or "es"

    local classLocalized = UnitClass("player") or "?"

    local roleNames = {
        es = { TANK = "Tanque", HEALER = "Healer", DPS = "DPS" },
        en = { TANK = "Tank",   HEALER = "Healer", DPS = "DPS" },
    }
    local roleOrder = { "TANK", "HEALER", "DPS" }
    local roleList  = {}
    if ProChat.Data and ProChat.Data.selectedRoles then
        for _, role in ipairs(roleOrder) do
            if ProChat.Data.selectedRoles[role] then
                local rName = (roleNames[lang] and roleNames[lang][role]) or role
                table.insert(roleList, rName)
            end
        end
    end
    local rolesStr = (#roleList > 0) and table.concat(roleList, "/") or "DPS"

    local gs = 0
    if ProChat.Core and ProChat.Core.GetGearScore then
        gs = ProChat.Core:GetGearScore() or 0
    end
    local gsStr = (gs and gs > 0) and tostring(gs) or "?"

    local msg
    if lang == "es" then
        msg = string.format("Soy %s %s GS: %s [ProChat IA]", classLocalized, rolesStr, gsStr)
    else
        msg = string.format("I'm a %s %s GS: %s [ProChat IA]", classLocalized, rolesStr, gsStr)
    end

    SendChatMessage(msg, "WHISPER", nil, targetName)

    local prefix  = "[|cffB366FFPro|r|cffFFFFFFChat|r |cff00FFCCIA|r]: "
    local confirm = (lang == "es")
        and ("Solicitud enviada a |cffffffff" .. targetName .. "|r: " .. msg)
        or  ("Request sent to |cffffffff"     .. targetName .. "|r: " .. msg)
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. confirm)
end