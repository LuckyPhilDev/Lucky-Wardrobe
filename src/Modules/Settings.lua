-- Lucky's Better Wardrobe: native settings panel (LuckyRichSettings).
-- Replaces the old Ace3 options UI. Reads/writes the AceDB profile directly.
local addonName = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addon:BuildSettingsPanel()
    if self.settingsPanel then return end

    local Profile = self.Profile
    local panel = LuckySettings:NewRichPanel("Lucky's Better Wardrobe")
    self.settingsPanel = panel

    SLASH_LUCKYBW1 = "/bw"
    SLASH_LUCKYBW2 = "/betterwardrobe"
    SlashCmdList["LUCKYBW"] = function() panel:Open() end

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(L["General Options"])

        g:Toggle({
            label   = L["Ignore Class Restriction Filter"],
            desc    = "Show sets and appearances your class normally cannot use.",
            checked = Profile.IgnoreClassRestrictions,
            onToggle = function(v)
                Profile.IgnoreClassRestrictions = v
                addon.Init:InitDB()
            end,
        })

    end

    panel:Finalize()
end
