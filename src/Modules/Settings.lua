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

    ---------------------------------------------------------------------------
    -- Transmog Vendor
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(L["Transmog Vendor Window"])

        g:Toggle({
            label   = L["Show Incomplete Sets"],
            checked = Profile.ShowIncomplete,
            onToggle = function(v) Profile.ShowIncomplete = v end,
        })

        g:Toggle({
            label   = L["Show Items set to Hidden"],
            checked = Profile.ShowHidden,
            onToggle = function(v) Profile.ShowHidden = v end,
        })

        g:Toggle({
            label   = L["Hide Missing Set Pieces at Transmog Vendor"],
            checked = Profile.HideMissing,
            onToggle = function(v) Profile.HideMissing = v end,
        })

        g:Toggle({
            label   = L["Use Hidden Transmog for Missing Set Pieces"],
            checked = Profile.HiddenMog,
            onToggle = function(v) Profile.HiddenMog = v end,
        })

        g:Slider({
            label   = L["Required pieces"],
            key     = "BW_PartialLimit",
            desc    = "How many pieces a set needs before it counts as owned.",
            min     = 1,
            max     = 8,
            value   = Profile.PartialLimit,
            onChanged = function(val) Profile.PartialLimit = val end,
        })

    end

    do
        local g = panel:Group("Dressing Room")

        g:Toggle({
            label   = "Enable dressing room enhancements",
            desc    = "Adds slot buttons, undress, undo, and outfit import and export to the dressing room. This feature is incomplete and unpolished, expect rough edges.",
            checked = Profile.DR_OptionsEnable,
            onToggle = function(v)
                Profile.DR_OptionsEnable = v
                if v then
                    addon:DressingRoom_Enable()
                else
                    addon:DressingRoom_Disable()
                end
            end,
        })
    end

    panel:Finalize()
end
