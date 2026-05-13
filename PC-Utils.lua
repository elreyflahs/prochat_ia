-- ProChat IA v1.0 - 3.3.5 - Utils Module
-- Por Elreyflahs

ProChat.Utils = {}

local Data = ProChat.Data
local _G = _G

-- ===== MINIMAP POSITIONING =====
function ProChat.Utils:UpdateMinimapPos()
    local angle = ProChatDB.mmAngle or 45
    if ProChat.Frames.minimap then 
        ProChat.Frames.minimap:SetPoint("TOPLEFT", _G.Minimap, "TOPLEFT", 52 - (80 * _G.cos(angle)), (80 * _G.sin(angle)) - 52) 
    end
end

-- ===== SAVE WINDOW STATE =====
function ProChat.Utils:SaveWindowState(state)
    if ProChatDB then 
        ProChatDB.showWindows = state 
    end
end

-- ===== GET FORMATTED TIME =====
function ProChat.Utils:GetFormattedTime()
    return "|cff888888[".._G.date("%H:%M:%S").."]|r"
end

-- ===== COLOR UTILITIES =====
function ProChat.Utils:HexToRGB(hexColor)
    hexColor = hexColor:gsub("^#", "")
    if #hexColor ~= 6 then return 255, 255, 255 end
    return tonumber(hexColor:sub(1,2), 16), tonumber(hexColor:sub(3,4), 16), tonumber(hexColor:sub(5,6), 16)
end

function ProChat.Utils:RGBToHex(r, g, b)
    local function clamp(val)
        if val < 0 then return 0 end
        if val > 255 then return 255 end
        return val
    end
    return string.format("%02X%02X%02X", clamp(r), clamp(g), clamp(b))
end

function ProChat.Utils:LightenHexColor(hexColor, amount)
    amount = amount or 0.45
    local r, g, b = self:HexToRGB(hexColor)
    r = math.floor(r + (255 - r) * amount + 0.5)
    g = math.floor(g + (255 - g) * amount + 0.5)
    b = math.floor(b + (255 - b) * amount + 0.5)
    return self:RGBToHex(r, g, b)
end

-- ===== COLOR MESSAGE TEXT =====
function ProChat.Utils:ColorMessageText(msg, color)
    if not msg or msg == "" then return "" end
    local result = ""
    local i = 1
    while i <= #msg do
        local linkStart = msg:find("|c", i) or msg:find("|H", i)
        if linkStart then
            -- Add text before link
            if linkStart > i then
                result = result .. "|cff" .. color .. msg:sub(i, linkStart - 1) .. "|r"
            end
            -- Find the end of the link (matching |c and |r)
            local linkEnd = self:FindLinkEnd(msg, linkStart)
            result = result .. msg:sub(linkStart, linkEnd)
            i = linkEnd + 1
        else
            -- No more links, color the rest
            result = result .. "|cff" .. color .. msg:sub(i) .. "|r"
            break
        end
    end
    return result
end

function ProChat.Utils:FindLinkEnd(msg, start)
    local depth = 0
    for j = start, #msg do
        if msg:sub(j, j + 1) == "|c" then
            depth = depth + 1
        elseif msg:sub(j, j + 1) == "|r" then
            depth = depth - 1
            if depth == 0 then
                return j + 1
            end
        end
    end
    return #msg
end

-- ===== REFRESH CHAT WINDOW =====
function ProChat.Utils:RefreshChatWindow()
    local chatWin = ProChat.Frames.chatWin
    if not chatWin or not chatWin.text then return end
    if chatWin.isMinimized then return end
    chatWin.text:Clear()
    local displayedMessages = {}
    
    for dung, active in pairs(Data.selectedDungeons) do
        if active then
            local data = Data.history[dung]
            if data then
                for _, entry in ipairs(data) do
                    if entry and not displayedMessages[entry.formatted] then
                        local matchAny = false
                        if Data.searchTerm == "" then
                            matchAny = true
                        else
                            for word in Data.searchTerm:gmatch("%S+") do 
                                if string.find(entry.formatted:upper(), word:upper(), 1, true) then
                                    matchAny = true
                                    break
                                end
                            end
                        end
                        
                        if matchAny then
                            local canShow = true
                            if dung ~= "TODAS" and Data.dungeonDifficulties[dung] then
                                if not entry.difficulty or not Data.selectedDifficulties[dung] or not Data.selectedDifficulties[dung][entry.difficulty] then
                                    canShow = false
                                end
                            end

                            if canShow then
                                if not Data.hideGrays or not string.find(entry.formatted, "ffB0B0B0") then 
                                    chatWin.text:AddMessage(entry.formatted)
                                    displayedMessages[entry.formatted] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ===== UPDATE RAID LIST =====
function ProChat.Utils:UpdateRaidList()
    local chatWin = ProChat.Frames.chatWin
    local rf = chatWin and chatWin.raidText
    if not rf then return end
    if chatWin.isMinimized then return end
    rf:Clear()
    rf:SetInsertMode("TOP")
    
    for i = #Data.keywords, 1, -1 do
        local k = Data.keywords[i]
        if Data.raidGroups[k] then
            local playersToShow = {}
                        for p in pairs(Data.raidGroups[k]) do
                local userData = Data.userMessages[p]
                if not userData then break end  -- seguridad
                
                local playerMsg = userData.msg or ""
                local playerDung = userData.dungeon
                local playerDiff = userData.difficulty
                
                -- === FILTRO DE SEARCH TERM ===
                local matchAny = false
                if Data.searchTerm == "" then
                    matchAny = true
                else
                    for word in Data.searchTerm:gmatch("%S+") do
                        if string.find(playerMsg:upper(), word:upper(), 1, true) then
                            matchAny = true
                            break
                        end
                    end
                end
                
                -- === FILTRO DE DUNGEON / DIFICULTAD ===
                local canShow = true
                if not Data.selectedDungeons["TODAS"] then
                    if not playerDung or not Data.selectedDungeons[playerDung] then
                        canShow = false
                    elseif Data.dungeonDifficulties[playerDung] then
                        if not playerDiff 
                            or not Data.selectedDifficulties[playerDung] 
                            or not Data.selectedDifficulties[playerDung][playerDiff] then
                            canShow = false
                        end
                    end
                end
                
                if matchAny and canShow then
                    table.insert(playersToShow, p)
                end
            end
            
            if #playersToShow > 0 then
                if not Data.collapsed[k] then
                    for _, p in ipairs(playersToShow) do
                        local cColor = Data.PC_ClassCache[p] or "ffffff"
                        rf:AddMessage("      |Hplayer:"..p.."|h|cff"..cColor.."["..p.."]|h|r")
                    end
                end
                
                local symColor = Data.collapsed[k] and "00ff00" or "ff3333"
                local symText = Data.collapsed[k] and "[ + ]" or "[  -  ]"
                local titleName = (Data.fullNames[k] or k):upper()
                local titleColor = Data.filterColors[k] or "ffffff"
                
                rf:AddMessage("|Hraidclick:"..k.."|h|cff"..symColor..symText.."|r |cff"..titleColor..titleName.."|r|h (|cffffffff"..#playersToShow.."|r)")
            end
        end
    end
end


-- ===== GET CLASS COLOR =====
function ProChat.Utils:GetClassColor(guid, sender)
    if guid then
        local _, classUpper = _G.GetPlayerInfoByGUID(guid)
        if classUpper and Data.classColors[classUpper] then
            local nameColor = Data.classColors[classUpper]
            Data.PC_ClassCache[sender] = nameColor
            return nameColor
        end
    end
    return Data.filterColors["TODAS"]
end

-- ===== MATCH DUNGEON KEYWORD =====
-- (con aliases para nombres alternativos de Onyxia)
function ProChat.Utils:MatchDifficultyKeyword(msg, dungeon)
    if not dungeon or not Data.dungeonDifficulties[dungeon] then return nil end
    local msgU = msg:upper()
    for _, diff in ipairs(Data.dungeonDifficulties[dungeon]) do
        if Data.difficultyKeywords[diff] then
            for _, variant in ipairs(Data.difficultyKeywords[diff]) do
                -- Buscar como palabra separada O pegado a la keyword
                if string.find(" "..msgU.." ", "[^%a]"..variant:upper().."[^%a]") then
                    return diff
                end
                -- Buscar pegado a la dungeon: ej "icc25n"
                if string.find(msgU, dungeon:upper()..variant:upper()) then
                    return diff
                end
            end
        end
    end
    return nil
end

-- ===== PROCHAT SIGNATURE =====
local PROCHAT_SECRET = "ProChat2024ElReyFlahs"

function ProChat.Utils:GenerateSignature(gs, playerName)
    local raw = (gs or 0) .. (playerName or "") .. PROCHAT_SECRET
    local hash = 0
    for i = 1, #raw do
        hash = (hash * 31 + string.byte(raw, i)) % 65536
    end
    return string.format("%04X", hash)
end

-- ===== APPLY STANDARD BACKDROP (Fix #6) =====
function ProChat.Utils:ApplyStandardBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
end

-- ===== GEARSCORE ENGINE (extraído de GearScoreLite, solo lo que ProChat necesita) =====
-- Tabla de tipos de slot con sus modificadores
local PC_GS_ItemTypes = {
    ["INVTYPE_RELIC"]          = { SlotMOD = 0.3164, Enchantable = false },
    ["INVTYPE_TRINKET"]        = { SlotMOD = 0.5625, Enchantable = false },
    ["INVTYPE_2HWEAPON"]       = { SlotMOD = 2.000,  Enchantable = true  },
    ["INVTYPE_WEAPONMAINHAND"] = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_WEAPONOFFHAND"]  = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_RANGED"]         = { SlotMOD = 0.3164, Enchantable = true  },
    ["INVTYPE_THROWN"]         = { SlotMOD = 0.3164, Enchantable = false },
    ["INVTYPE_RANGEDRIGHT"]    = { SlotMOD = 0.3164, Enchantable = false },
    ["INVTYPE_SHIELD"]         = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_WEAPON"]         = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_HOLDABLE"]       = { SlotMOD = 1.0000, Enchantable = false },
    ["INVTYPE_HEAD"]           = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_NECK"]           = { SlotMOD = 0.5625, Enchantable = false },
    ["INVTYPE_SHOULDER"]       = { SlotMOD = 0.7500, Enchantable = true  },
    ["INVTYPE_CHEST"]          = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_ROBE"]           = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_WAIST"]          = { SlotMOD = 0.7500, Enchantable = false },
    ["INVTYPE_LEGS"]           = { SlotMOD = 1.0000, Enchantable = true  },
    ["INVTYPE_FEET"]           = { SlotMOD = 0.75,   Enchantable = true  },
    ["INVTYPE_WRIST"]          = { SlotMOD = 0.5625, Enchantable = true  },
    ["INVTYPE_HAND"]           = { SlotMOD = 0.7500, Enchantable = true  },
    ["INVTYPE_FINGER"]         = { SlotMOD = 0.5625, Enchantable = false },
    ["INVTYPE_CLOAK"]          = { SlotMOD = 0.5625, Enchantable = true  },
    ["INVTYPE_BODY"]           = { SlotMOD = 0,      Enchantable = false },
}

local PC_GS_Formula = {
    ["A"] = {
        [4] = { A = 91.4500, B = 0.6500 },
        [3] = { A = 81.3750, B = 0.8125 },
        [2] = { A = 73.0000, B = 1.0000 },
    },
    ["B"] = {
        [4] = { A = 26.0000, B = 1.2000 },
        [3] = { A =  0.7500, B = 1.8000 },
        [2] = { A =  8.0000, B = 2.0000 },
        [1] = { A =  0.0000, B = 2.2500 },
    },
}

-- Rangos de color por GS (extraído de GS_Quality de informationLite.lua)
local PC_GS_Quality = {
    [6000] = { R={ A=0.94, B=5000, C=0.00006,  D=1  }, G={ A=0.47, B=5000, C=0.00047, D=-1 }, B={ A=0,    B=0,    C=0,       D=0  } },
    [5000] = { R={ A=0.69, B=4000, C=0.00025,  D=1  }, G={ A=0.28, B=4000, C=0.00019, D=1  }, B={ A=0.97, B=4000, C=0.00096, D=-1 } },
    [4000] = { R={ A=0.0,  B=3000, C=0.00069,  D=1  }, G={ A=0.5,  B=3000, C=0.00022, D=-1 }, B={ A=1,    B=3000, C=0.00003, D=-1 } },
    [3000] = { R={ A=0.12, B=2000, C=0.00012,  D=-1 }, G={ A=1,    B=2000, C=0.00050, D=-1 }, B={ A=0,    B=2000, C=0.001,   D=1  } },
    [2000] = { R={ A=1,    B=1000, C=0.00088,  D=-1 }, G={ A=1,    B=0,    C=0.00000, D=0  }, B={ A=1,    B=1000, C=0.001,   D=-1 } },
    [1000] = { R={ A=0.55, B=0,    C=0.00045,  D=1  }, G={ A=0.55, B=0,    C=0.00045, D=1  }, B={ A=0.55, B=0,    C=0.00045, D=1  } },
}

-- Obtener color RGB según GS (retorna r, g, b en rango 0-1)
function ProChat.Utils:GetGSColor(gs)
    if not gs or gs <= 0 then return 0.55, 0.55, 0.55 end
    local score = gs
    if score > 5999 then score = 5999 end
    for i = 0, 6 do
        local lo = i * 1000
        local hi = (i + 1) * 1000
        if score > lo and score <= hi then
            local q = PC_GS_Quality[hi]
            if not q then break end
            local r = q.R.A + ((score - q.R.B) * q.R.C) * q.R.D
            local g = q.G.A + ((score - q.G.B) * q.G.C) * q.G.D
            local b = q.B.A + ((score - q.B.B) * q.B.C) * q.B.D
            return r, g, b
        end
    end
    return 0.55, 0.55, 0.55
end

-- Obtener hex color según GS para uso en strings de WoW
function ProChat.Utils:GetGSColorHex(gs)
    local r, g, b = self:GetGSColor(gs)
    return string.format("%02X%02X%02X", math.floor(r*255+0.5), math.floor(g*255+0.5), math.floor(b*255+0.5))
end

-- Calcular enchant penalty para un item
local function PC_GS_GetEnchantInfo(ItemLink, ItemEquipLoc)
    local typeData = PC_GS_ItemTypes[ItemEquipLoc]
    if not typeData or not typeData.Enchantable then return 1 end
    local found, _, ItemSubString = string.find(ItemLink, "^|c%x+|H(.+)|h%[.*%]")
    if not found then return 1 end
    local parts = {}
    for v in string.gmatch(ItemSubString, "[^:]+") do tinsert(parts, v) end
    if not parts[2] or not parts[3] then return 1 end
    local sub2 = parts[2] .. ":" .. parts[3]
    local sStart = string.find(sub2, ":")
    if not sStart then return 1 end
    local enchantID = string.sub(sub2, sStart + 1)
    if enchantID == "0" then
        local slotMod = typeData.SlotMOD
        local pct = math.floor((-2 * slotMod) * 100) / 100
        return 1 + (pct / 100)
    end
    return 1
end

-- Calcular score de un item individual
local function PC_GS_GetItemScore(ItemLink)
    if not ItemLink then return 0, 0 end
    local _, _, ItemRarity, ItemLevel, _, _, _, _, ItemEquipLoc = GetItemInfo(ItemLink)
    if not ItemRarity or not ItemEquipLoc then return 0, 0 end
    local QualityScale = 1
    local Scale = 1.8618
    if     ItemRarity == 5 then QualityScale = 1.3; ItemRarity = 4
    elseif ItemRarity == 1 then QualityScale = 0.005; ItemRarity = 2
    elseif ItemRarity == 0 then QualityScale = 0.005; ItemRarity = 2 end
    if ItemRarity == 7 then ItemRarity = 3; ItemLevel = 187.05 end
    local typeData = PC_GS_ItemTypes[ItemEquipLoc]
    if not typeData then return 0, ItemLevel or 0 end
    local Table = (ItemLevel > 120) and PC_GS_Formula["A"] or PC_GS_Formula["B"]
    if ItemRarity >= 2 and ItemRarity <= 4 then
        local formulaRow = Table[ItemRarity]
        if not formulaRow then return 0, ItemLevel or 0 end
        local gs = math.floor(((ItemLevel - formulaRow.A) / formulaRow.B) * typeData.SlotMOD * Scale * QualityScale)
        if ItemLevel == 187.05 then ItemLevel = 0 end
        if gs < 0 then gs = 0 end
        local enchantMult = PC_GS_GetEnchantInfo(ItemLink, ItemEquipLoc) or 1
        gs = math.floor(gs * enchantMult)
        return gs, ItemLevel or 0
    end
    return 0, ItemLevel or 0
end

-- Calcular GearScore del jugador (función principal que reemplaza la dependencia de GearScoreLite)
function ProChat.Utils:CalculatePlayerGS()
    local target = "player"
    if not UnitIsPlayer(target) then return 0 end
    local _, playerClass = UnitClass(target)
    local GearScore = 0
    local TitanGrip = 1

    -- Detectar Titan Grip (guerrero con 2H en slot off-hand)
    if GetInventoryItemLink(target, 16) and GetInventoryItemLink(target, 17) then
        local _, _, _, _, _, _, _, _, ItemEquipLoc = GetItemInfo(GetInventoryItemLink(target, 16))
        if ItemEquipLoc == "INVTYPE_2HWEAPON" then TitanGrip = 0.5 end
    end

    -- Slot 17 (off-hand) con lógica especial de hunter/titan grip
    local link17 = GetInventoryItemLink(target, 17)
    if link17 then
        local _, _, _, _, _, _, _, _, ItemEquipLoc = GetItemInfo(link17)
        if ItemEquipLoc == "INVTYPE_2HWEAPON" then TitanGrip = 0.5 end
        local score, _ = PC_GS_GetItemScore(link17)
        if playerClass == "HUNTER" then score = score * 0.3164 end
        GearScore = GearScore + score * TitanGrip
    end

    -- Slots 1-18 (excepto 4=shirt y 17=off-hand ya procesado)
    for i = 1, 18 do
        if i ~= 4 and i ~= 17 then
            local link = GetInventoryItemLink(target, i)
            if link then
                local score, _ = PC_GS_GetItemScore(link)
                if i == 16 then
                    if playerClass == "HUNTER" then score = score * 0.3164 end
                    score = score * TitanGrip
                elseif i == 18 and playerClass == "HUNTER" then
                    score = score * 5.3224
                end
                GearScore = GearScore + score
            end
        end
    end

    return math.floor(GearScore)
end

-- ===== RESET ALL DATA =====
function ProChat.Utils:ResetAllData()
    for k in pairs(Data.history) do 
        Data.history[k] = {} 
    end
    for _, k in ipairs(Data.keywords) do 
        Data.raidGroups[k] = {}
        Data.collapsed[k] = true 
    end
    Data.userMessages = {}
    Data.showRaidWin = true
end

-- ===== MATCH DUNGEON KEYWORD (con aliases para nombres alternativos) =====
function ProChat.Utils:MatchDungeonKeyword(msg)
    local msgU = msg:upper()
    
    -- Aliases para nombres alternativos
    local aliases = {
        ["ONIXIA"] = "ONY",
        ["ONYXIA"] = "ONY", 
        ["ONIXYA"] = "ONY",
    }
    for alias, target in pairs(aliases) do
        if string.find(" "..msgU.." ", "[^%a]"..alias.."[^%a]") then
            return target
        end
    end
    
    for _, k in ipairs(Data.keywords) do 
        if string.find(" "..msgU.." ", "[^%a]"..k.."[^%a]") then 
            return k
        end 
    end
    return nil
end