-- ProChat IA v1.0 - 3.3.5 - Data Module
-- Por Elreyflahs

ProChat = ProChat or {}
ProChat.Data = {}

-- ===== VERSION =====
ProChat.CURRENT_VERSION = "1.0"

ProChat.Data.currentTab = "LFG"

-- ===== DUNGEON IDs FOR LFR (Apuntar) =====
ProChat.Data.dungeonIDs = {
    ["ICC"]    = { ["10"] = 279,  ["25"] = 280,  name = "Ciudadela de la Corona de Hielo" },
    ["EOE"]    = { ["10"] = 223,  ["25"] = 237,  name = "El Ojo de la Eternidad" },
    ["SO"]     = { ["10"] = 224,  ["25"] = 238,  name = "El Sagrario Obsidiana" },
    ["SR"]     = { ["10"] = 293,  ["25"] = 294,  name = "El Sagrario Rubí" },
    ["ONY"]    = { ["10"] = 46,   ["25"] = 257,  name = "Guarida de Onyxia" },
    ["ARCHA"]  = { ["10"] = 239,  ["25"] = 240,  name = "La Cámara de Archavon" },
    ["NAXX"]   = { ["10"] = 159,  ["25"] = 227,  name = "Naxxramas" },
    ["TOC"]    = { ["10N"] = 246, ["25N"] = 248, ["10H"] = 247, ["25H"] = 250, name = "Prueba del Cruzado" },
    ["ULDUAR"] = { ["10"] = 243,  ["25"] = 244,  name = "Ulduar" },
}

-- ===== CLASS ROLES =====
ProChat.Data.classRoles = {
    ["WARRIOR"]     = { "TANK", "DPS" },
    ["PALADIN"]     = { "TANK", "HEALER", "DPS" },
    ["HUNTER"]      = { "DPS" },
    ["ROGUE"]       = { "DPS" },
    ["PRIEST"]      = { "HEALER", "DPS" },
    ["DEATHKNIGHT"] = { "TANK", "DPS" },
    ["SHAMAN"]      = { "DPS", "HEALER" },
    ["MAGE"]        = { "DPS" },
    ["WARLOCK"]     = { "DPS" },
    ["DRUID"]       = { "TANK", "HEALER", "DPS" },
}

-- ===== ROLE ICONS =====
ProChat.Data.roleIcons = {
    ["TANK"]   = "Interface\\Icons\\INV_Shield_06",
    ["HEALER"] = "Interface\\Icons\\Spell_Holy_Heal",
    ["DPS"]    = "Interface\\Icons\\INV_Sword_04",
}

-- ===== SELECTED ROLES (para apuntar) =====
ProChat.Data.selectedRoles = {}

-- ===== KEYWORDS & DUNGEON NAMES =====
-- Orden: de mayor a menor dificultad (mismo orden en FilterDropBtn y lfmDrop)
ProChat.Data.keywords = {"SR", "ICC", "TOC", "ARCHA", "ULDUAR", "ONY", "EOE", "SO", "NAXX", "SEMANAL", "FOSO", "VIAJEROS"}

-- ===== GS MÍNIMO RECOMENDADO POR MAZMORRA Y DIFICULTAD =====
ProChat.Data.minGS = {
    ["SR"]    = { ["10N"]=6000, ["10H"]=6100, ["25N"]=6100, ["25H"]=6200 },
    ["ICC"]   = { ["10N"]=5200, ["10H"]=5800, ["25N"]=5400, ["25H"]=6000 },
    ["TOC"]   = { ["10N"]=5000, ["10H"]=5600, ["25N"]=5200, ["25H"]=5800 },
    ["ARCHA"] = { ["10"]=5000,  ["25"]=5200  },
    ["ULDUAR"]= { ["10"]=4800,  ["25"]=5000  },
    ["ONY"]   = { ["10"]=4500,  ["25"]=4800  },
    ["EOE"]   = { ["10"]=4000,  ["25"]=4500  },
    ["SO"]    = { ["10"]=4000,  ["25"]=3700  },
    ["NAXX"]  = { ["10"]=3500,  ["25"]=3800  },
    ["SEMANAL"]= { all=3000 },
    ["FOSO"]  = { all=2000  },
    ["VIAJEROS"]={ all=nil  },  -- variado
}

ProChat.Data.fullNames = {
    ["ICC"] = "ICC", 
    ["SR"] = "SR", 
    ["ARCHA"] = "ARCHA",
    ["TOC"] = "TOC", 
    ["FOSO"] = "FOSO", 
    ["NAXX"] = "NAXX",
    ["ULDUAR"] = "ULDUAR", 
    ["SEMANAL"] = "SEM", 
    ["VIAJEROS"] = "VT", 
    ["SO"] = "SO",
    ["ONY"] = "ONY",
    ["EOE"] = "EOE",
}

ProChat.Data.dungeonDifficulties = {
    ["SR"] = {"10N", "10H", "25N", "25H"},
    ["ICC"] = {"10N", "10H", "25N", "25H"},
    ["TOC"] = {"10N", "10H", "25N", "25H"},
    ["ARCHA"] = {"10", "25"},
    ["ULDUAR"] = {"10", "25"},
    ["NAXX"] = {"10", "25"},
    ["SO"] = {"10", "25"},
    ["ONY"] = {"10", "25"},
    ["EOE"] = {"10", "25"},
}

ProChat.Data.difficultyKeywords = {
    ["10N"] = {"10N", "10Normal", "10 normal"},
    ["10H"] = {"10H", "10Hero", "10 hero", "10Heroico", "10 heroico"},
    ["25N"] = {"25N", "25Normal", "25 normal"},
    ["25H"] = {"25H", "25Hero", "25 hero", "25Heroico", "25 heroico"},
    ["10"] = {"10"},
    ["25"] = {"25"},
}

-- ===== COLOR TABLES =====
ProChat.Data.filterColors = {
    ["ICC"] = "81DDF0", 
    ["SR"] = "FF8000", 
    ["ARCHA"] = "E6CC80", 
    ["SEMANAL"] = "0070DE",
    ["NAXX"] = "32CD32", 
    ["ULDUAR"] = "D2B48C", 
    ["TOC"] = "FFFF00", 
    ["VIAJEROS"] = "A335EE",
    ["FOSO"] = "FF69B4", 
    ["SO"] = "FF0000", 
    ["TODAS"] = "B0B0B0",
    ["ONY"] = "FFD700",
    ["EOE"] = "00BFFF",
}

ProChat.Data.classColors = {
    ["WARRIOR"] = "C79C6E", 
    ["PALADIN"] = "F58CBA", 
    ["HUNTER"] = "ABD473",
    ["ROGUE"] = "FFF569", 
    ["PRIEST"] = "FFFFFF", 
    ["DEATHKNIGHT"] = "C41F3B",
    ["SHAMAN"] = "0070DE", 
    ["MAGE"] = "69CCF0", 
    ["WARLOCK"] = "9482C9",
    ["DRUID"] = "FF7D0A"
}

ProChat.Data.channelTags = {
    ["DECIR"]     = {t="D", c="ffffff"},
    ["GRITAR"]    = {t="Y", c="ff4040"},
    ["HERMANDAD"] = {t="H", c="40ff40"},
    ["COMERCIO"]  = {t="C", c="ffc0c0"},
    ["GENERAL"]   = {t="G", c="ffc0c0"},
    ["POSADA"]    = {t="P", c="ffc0c0"},
    ["BUSCARGRUPO"] = {t="B", c="ffc0c0"},
}

-- ===== LFM STATE =====
ProChat.Data.lfmCurrentSize = "25" -- "25" o "10"

-- ===== RUNTIME STATE =====
ProChat.Data.userMessages = {}
ProChat.Data.history = { ["TODAS"] = {} }
ProChat.Data.raidGroups = {}
ProChat.Data.collapsed = {}
ProChat.Data.PC_ClassCache = {}

ProChat.Data.selectedChannels = {}
ProChat.Data.selectedDungeons = { ["TODAS"] = true }
ProChat.Data.filterTime = 60
ProChat.Data.hideGrays = false
ProChat.Data.showRaidWin = true
ProChat.Data.searchTerm = ""
ProChat.Data.isQueued = false
ProChat.Data.lfmCurrentRaid = nil
ProChat.Data.autoLFGActive = false

-- ===== INITIALIZE STRUCTURES =====
ProChat.Data.selectedDifficulties = {}
for _, k in ipairs(ProChat.Data.keywords) do 
    ProChat.Data.history[k] = {}
    ProChat.Data.raidGroups[k] = {}
    ProChat.Data.collapsed[k] = true 
    ProChat.Data.selectedDifficulties[k] = {}
    if ProChat.Data.dungeonDifficulties[k] then
        for _, diff in ipairs(ProChat.Data.dungeonDifficulties[k]) do
            ProChat.Data.selectedDifficulties[k][diff] = true
        end
    end
end

-- ===== FRAME REFERENCES =====
ProChat.Frames = {
    chatWin = nil,
    credWin = nil,
    welcomeWin = nil,
}

-- ===== UI ELEMENT REFERENCES =====
ProChat.UI = {
    chanDrop = nil,
    filterDrop = nil,
    timeDrop = nil,
    langDrop = nil,
    searchBox = nil,
    labelChan = nil,
    labelDung = nil,
    labelSpam = nil,
    searchLabel = nil,
    checkMM = nil,
    checkGrays = nil,
    checkRaid = nil,
    checkOptions = nil,
    globalClear = nil,
    lfgBtn = nil,
    fontSlider = nil,
    opacitySlider = nil,
    scrollBottom = nil,
    credTitle = nil,
    credText = nil,
    credButton = nil,
    welcomeTitle = nil,
    welcomeText = nil,
    welcomeButton = nil,
    autoLFGSwitch = nil,
    autoLFGEye = nil,
}

-- Register special frames
tinsert(UISpecialFrames, "PC_CreditsWin")
tinsert(UISpecialFrames, "PC_WelcomeWin")

-- ===== REALM-SPECIFIC DUNGEONS (FIX #15) =====
-- FIX 5: Detectar por realmlist en vez de nombre de realm
ProChat.Data.realmSpecificDungeons = {
    ["VIAJEROS"] = { realmlist = "logon.ultimowow.com" }
}

-- ===== CHECK IF DUNGEON IS VISIBLE (FIX 5 - Realmlist detection) =====
function ProChat.Data:IsDungeonVisible(key)
    if ProChat.Data.realmSpecificDungeons[key] then
        local entry = ProChat.Data.realmSpecificDungeons[key]
        if entry.realmlist then
            -- Obtener el realmlist actual desde la variable de cliente WoW
            local currentRealmList = GetCVar("realmList") or ""
            currentRealmList = currentRealmList:lower():gsub("^%s*(.-)%s*$", "%1")  -- trim
            return currentRealmList == entry.realmlist:lower()
        end
        return false
    end
    return true
end

-- ===== GET PLAYER CLASS (Apuntar) =====
function ProChat.Data:GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end