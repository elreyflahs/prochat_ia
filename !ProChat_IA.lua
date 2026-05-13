-- ProChat IA v1.0 - 3.3.5 - Main Entry Point
-- By Elreyflahs

ProChat = ProChat or {}

-- Initialize the addon
local function OnAddonLoad()
    ProChat.Core:Initialize()
end

-- Wait for all modules to load, then initialize
local loader = _G.CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "!ProChat_IA" then
        OnAddonLoad()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)