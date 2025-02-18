local Plater = Plater
local addonId, platerInternal = ...
local GameCooltip = GameCooltip2
local DF = DetailsFramework
local GetSpellInfo = GetSpellInfo
local _

local unpack = table.unpack or _G.unpack

--localization
local LOC = DF.Language.GetLanguageTable(addonId)

local LibSharedMedia = LibStub:GetLibrary("LibSharedMedia-3.0")

--get templates
local options_text_template = DF:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE")
local options_dropdown_template = DF:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
local options_switch_template = DF:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE")
local options_slider_template = DF:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE")
local options_button_template = DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE")

local dropdownStatusBarTexture = platerInternal.Defaults.dropdownStatusBarTexture
local dropdownStatusBarColor = platerInternal.Defaults.dropdownStatusBarColor

local colorNoValue = {1, 1, 1, 0.5}
local dropdownIconColor = {1, 1, 1, .6}

local DB_CAST_COLORS
local DB_CAST_AUDIOCUES
local DB_NPCIDS_CACHE
local DB_CAPTURED_SPELLS
local DB_CAPTURED_CASTS

local CONST_INDEX_ENABLED = 1
local CONST_INDEX_COLOR = 2
local CONST_INDEX_NAME = 3

local CONST_CASTINFO_ENABLED = 1
local CONST_CASTINFO_COLOR = 2
local CONST_CASTINFO_SPELLID = 3
local CONST_CASTINFO_SPELLNAME = 4
local CONST_CASTINFO_SPELLICON = 5
local CONST_CASTINFO_SOURCENAME = 6
local CONST_CASTINFO_NPCID = 7
local CONST_CASTINFO_NPCLOCATION = 8
local CONST_CASTINFO_ENCOUNTERNAME = 9
local CONST_CASTINFO_CUSTOMSPELLNAME = 10

local on_refresh_db = function()
	local profile = Plater.db.profile
	DB_CAST_AUDIOCUES = profile.cast_audiocues
	DB_CAST_COLORS = profile.cast_colors
    DB_NPCIDS_CACHE = profile.npc_cache
    DB_CAPTURED_SPELLS = PlaterDB.captured_spells
    DB_CAPTURED_CASTS = PlaterDB.captured_casts

    DB_CAPTURED_CASTS[116] = {npcID = 188027}
end
Plater.RegisterRefreshDBCallback(on_refresh_db)

function platerInternal.Data.GetSpellRenameData(spellId)
    if (spellId) then
        local spellTable = Plater.db.profile.cast_colors[spellId]
        if (spellTable) then
            --index 3 is the spell name renamed by the user
            return spellTable[3]
        end
    else
        return Plater.db.profile.cast_colors
    end
end

function platerInternal.Data.GetSpellColorData(spellId)
    if (spellId) then
        local spellTable = Plater.db.profile.cast_colors[spellId]
        if (spellTable) then
            --index 2 is the color
            return spellTable[2]
        end
    else
        return Plater.db.profile.cast_colors
    end
end

function platerInternal.Data.SetSpellRenameData(spellId, newName)
    if (spellId) then
        local spellTable = Plater.db.profile.cast_colors[spellId]
        if (spellTable) then
            spellTable[1] = true --index one is the enabled flag
            spellTable[3] = newName --index 3 is the spell name renamed by the user
        else
            Plater.db.profile.cast_colors[spellId] = {true, "white", newName}
        end
    end
end

function platerInternal.Data.SetSpellColorData(spellId, color)
    if (spellId) then
        local spellTable = Plater.db.profile.cast_colors[spellId]
        if (spellTable) then
            --index 2 is the color
            spellTable[1] = true
            spellTable[2] = color
        else
            Plater.db.profile.cast_colors[spellId] = {true, color, ""}
        end
    end
end

function Plater.GetSpellCustomColor(spellId) --exposed
    local customColorTable = Plater.db.profile.cast_colors[spellId]
    if (customColorTable) then
        return customColorTable[2] and (customColorTable[2] ~= "white") and customColorTable[2] or nil
    end
end

--priority for user cast color >> can't interrupt color >> script color
function Plater.SetCastBarColorForScript(castBar, canUseScriptColor, scriptColor, envTable) --exposed
    --user set cast bar color into the Cast Colors tab in the options panel
    local colorByUser = Plater.GetSpellCustomColor(envTable._SpellID)
    if (colorByUser) then
        castBar:SetStatusBarColor(Plater:ParseColors(colorByUser))
        return
    end

    --don't change the color of non-interruptible casts
    if (not envTable._CanInterrupt) then
        castBar:SetStatusBarColor(Plater:ParseColors(Plater.db.profile.cast_statusbar_color_nointerrupt))
        return
    end

    --if is interruptible and don't have a custom user color, set the script color
    if (canUseScriptColor and scriptColor) then
        if (type(scriptColor) == "table") then
            castBar:SetStatusBarColor(Plater:ParseColors(scriptColor))
        end
    end
end

function Plater.CreateCastColorOptionsFrame(castColorFrame)
    local castFrame = CreateFrame("frame", castColorFrame:GetName() .. "ColorFrame", castColorFrame)
    castFrame:SetPoint("topleft", castColorFrame, "topleft", 5, -140)
    castFrame:SetSize(1060, 495)

    --options
    local scroll_width = 1050
    local scroll_height = 442
    local scroll_lines = 20
    local scroll_line_height = 20
    local backdrop_color = {.2, .2, .2, 0.2}
    local backdrop_color_on_enter = {.8, .8, .8, 0.4}
    local y = -20
    local headerY = y - 20
    local scrollY = headerY - 15

    ----platerInternal.optionsYStart or

    local luaeditor_border_color = {0, 0, 0, 1}
    local edit_script_size = {620, 300}
    local buttons_size = {120, 20}

    DB_CAST_COLORS = Plater.db.profile.cast_colors
    DB_NPCIDS_CACHE = Plater.db.profile.npc_cache --[npcId] = {npc name, npc zone}
    DB_CAPTURED_CASTS = PlaterDB.captured_casts --[spellId] = {[npcID] = 000000}
    DB_CAPTURED_SPELLS = PlaterDB.captured_spells --[spellId] = {[npcID] = 000000}

    --header
    local headerTable = {
        {text = "Enabled", width = 40},
        {text = "Icon", width = 32},
        {text = "Spell Id", width = 50},
        {text = "Spell Name", width = 140},
        {text = "Rename To", width = 110},
        {text = "Npc Name", width = 110},
        {text = "Send To Raid", width = 110},
        {text = "Play Sound", width = 110},
        {text = "Color", width = 110},
        {text = "Add Animation", width = 270},
    }

    local headerOptions = {
        padding = 2,
    }

    castFrame.Header = DF:CreateHeader(castFrame, headerTable, headerOptions)
    castFrame.Header:SetPoint("topleft", castFrame, "topleft", 5, headerY+5)

    --store npcID = checkbox object
    --this is used when selecting the color from the dropdown, it'll automatically enable the color and need to set the checkbox to checked for feedback
    castFrame.CheckBoxCache = {}

    --line scripts
    local line_onenter = function(self)
        if (castColorFrame.lastLineEntered) then
            castColorFrame.lastLineEntered:SetBackdropColor(unpack (castColorFrame.lastLineEntered.backdrop_color or backdrop_color))
        end

        self:SetBackdropColor (unpack (backdrop_color_on_enter or backdrop_color))
        if (self.spellId) then
            GameTooltip:SetOwner (self, "ANCHOR_TOPLEFT")
            GameTooltip:SetSpellByID (self.spellId)
            GameTooltip:AddLine (" ")
            GameTooltip:Show()

            castColorFrame.latestSpellId = self.spellId
            castColorFrame.optionsFrame.previewCastBar.UpdateAppearance()

            castColorFrame.SelectScriptForSpellId(self.spellId)
            castColorFrame.currentSpellId = self.spellId
        end
    end

    local line_onleave = function(self)
        --self:SetBackdropColor(unpack (self.backdrop_color or backdrop_color))
        GameTooltip:Hide()
        castColorFrame.lastLineEntered = self
        --castColorFrame.currentSpellId = nil
    end

    local widget_onenter = function(self)
        local line = self:GetParent()
        line:GetScript ("OnEnter")(line)
    end
    local widget_onleave = function(self)
        local line = self:GetParent()
        line:GetScript ("OnLeave")(line)
    end

    local oneditfocusgained_spellid = function(self, capsule)
        self:HighlightText (0)
    end

    local refresh_line_color = function(self, color)
        color = color or backdrop_color
        local r, g, b = DF:ParseColors(color)
        local a = 0.2
        self:SetBackdropColor (r, g, b, a)
        self.backdrop_color = self.backdrop_color or {}
        self.backdrop_color[1] = r
        self.backdrop_color[2] = g
        self.backdrop_color[3] = b
        self.backdrop_color[4] = a
        self.ColorDropdown:Select (color)
    end

    local onToggleEnabled = function(self, spellId, state)
        if (not DB_CAST_COLORS[spellId]) then
            DB_CAST_COLORS[spellId] = {false, "blue"}
        end
        DB_CAST_COLORS[spellId][CONST_INDEX_ENABLED] = state

        --clean the refresh scroll cache
        castFrame.spellsScroll.CachedTable = nil
        castFrame.spellsScroll.SearchCachedTable = nil

        if (state) then
            self:GetParent():RefreshColor(DB_CAST_COLORS[spellId][CONST_INDEX_COLOR])
            castColorFrame.latestSpellId = spellId
            castColorFrame.optionsFrame.previewCastBar.UpdateAppearance()
        else
            self:GetParent():RefreshColor()
        end

        Plater.RefreshDBLists()
        Plater.UpdateAllNameplateColors()
        Plater.ForceTickOnAllNameplates()

        castFrame.RefreshScroll(0)
    end

    --audio cues
    local line_select_audio_dropdown = function (self, spellId, audioFilePath)
        DB_CAST_AUDIOCUES[spellId] = audioFilePath
    end

    local createAudioCueList = function(fullRefresh)
        if (castFrame.AudioCueListCache and not fullRefresh) then
            --return
        end

        local audioCueList = {
            {
                label = " no audio",
                value = nil,
                color = colorNoValue,
                statusbar = [[Interface\Tooltips\UI-Tooltip-Background]],
                statusbarcolor = {.1, .1, .1, .92},
                icon = [[Interface\AddOns\Plater\media\audio_cue_icon]],
                iconcolor = {1, 1, 1, .4},
                onclick = line_select_audio_dropdown
            }
        }

        local cuesInUse = {}
        for spellId, cueFile in pairs(DB_CAST_AUDIOCUES) do
            cuesInUse[cueFile] = true
        end

        local audioCues = _G.LibStub:GetLibrary("LibSharedMedia-3.0"):HashTable("sound")
        local audioListInOrder = {}
        for cueName, cueFile in pairs(audioCues) do
            audioListInOrder[#audioListInOrder+1] = {cueName, cueFile, cueName:lower(), cuesInUse[cueFile] or false}
        end

        table.sort(audioListInOrder, function(t1, t2) --alphabetical
            if (t1[4] and not t2[4]) then
                return true

            elseif (not t1[4] and t2[4]) then
                return false

            elseif (t1[4] and t2[4]) then
                return t1[3] < t2[3]
            else
                return t1[3] < t2[3]
            end
        end)

        --table.sort(audioListInOrder, function(t1, t2) return t1[3] < t2[3] end) --alphabetical
        --table.sort(audioListInOrder, function(t1, t2) return t1[4] > t2[4] end) --in use

        for i = 1, #audioListInOrder do
            local cueName, cueFile, lowerName, cueInUse = unpack(audioListInOrder[i])
            audioCueList[#audioCueList+1] = {
                label = " " .. cueName,
                value = cueFile,
                audiocue = cueFile,
                color = "white",
                statusbar = dropdownStatusBarTexture,
                statusbarcolor = cueInUse and {.3, .3, .3, .8} or dropdownStatusBarColor,
                iconcolor = dropdownIconColor,
                icon = [[Interface\AddOns\Plater\media\audio_cue_icon]],
                onclick = line_select_audio_dropdown,
            }
        end

        castFrame.AudioCueListCache = audioCueList
    end

    local line_refresh_audio_dropdown = function(self)
        createAudioCueList(true)
        return castFrame.AudioCueListCache
    end

    --cast color
    local line_select_color_dropdown = function (self, spellId, color)
        if (not DB_CAST_COLORS[spellId]) then
            DB_CAST_COLORS[spellId] = {true, "blue", ""}
        end

        DB_CAST_COLORS[spellId][CONST_INDEX_ENABLED] = true
        DB_CAST_COLORS[spellId][CONST_INDEX_COLOR] = color

        --o que é este checkbox cache
        local checkBox = castFrame.CheckBoxCache[spellId]
        if (checkBox) then
            checkBox:SetValue(true)
        end

        --clean the refresh scroll cache
        castFrame.spellsScroll.CachedTable = nil
        castFrame.spellsScroll.SearchCachedTable = nil

        self:GetParent():RefreshColor(color)

        Plater.RefreshDBLists()
        Plater.ForceTickOnAllNameplates()

        --o que é esses dois caches
        castFrame.cachedColorTable = nil
        castFrame.cachedColorTableNameplate = nil

        castFrame.RefreshScroll(0)
        castColorFrame.latestSpellId = spellId
        castColorFrame.optionsFrame.previewCastBar.UpdateAppearance()
    end

    local function hex (num)
        local hexstr = '0123456789abcdef'
        local s = ''
        while num > 0 do
            local mod = math.fmod(num, 16)
            s = string.sub(hexstr, mod+1, mod+1) .. s
            num = math.floor(num / 16)
        end
        if s == '' then s = '00' end
        if (string.len (s) == 1) then
            s = "0"..s
        end
        return s
    end

    local function sort_color (t1, t2)
        return t1[1][CONST_INDEX_COLOR] > t2[1][CONST_INDEX_COLOR]
    end

    local line_refresh_color_dropdown = function(self)
        if (not self.spellId) then
            return {}
        end

        if (not castFrame.cachedColorTable) then
            local colorsAdded = {}
            local colorsAddedT = {}
            local t = {}

            --add colors already in use first
            --get colors that are already in use and pull them to be the first colors in the dropdown
            for spellId, castColorTable in pairs(DB_CAST_COLORS) do
                local color = castColorTable[CONST_INDEX_COLOR]
                if (not colorsAdded[color]) then
                    colorsAdded[color] = true
                    local r, g, b = DF:ParseColors(color)
                    tinsert(colorsAddedT, {{r, g, b}, color, hex (r * 255) .. hex (g * 255) .. hex (b * 255)})
                end
            end
            --table.sort (colorsAddedT, sort_color) --this make the list be listed from the brightness color to the darkness

            for index, colorTable in ipairs (colorsAddedT) do
                local colortable = colorTable[1]
                local colorname = colorTable[2]
                tinsert (t, {label = " " .. colorname, value = colorname, color = colortable, onclick = line_select_color_dropdown,
                statusbar = [[Interface\Tooltips\UI-Tooltip-Background]],
                icon = [[Interface\AddOns\Plater\media\star_empty_64]],
                iconcolor = {1, 1, 1, .6},
                })
            end

            --all colors
            local allColors = {}
            for colorName, colorTable in pairs (DF:GetDefaultColorList()) do
                if (not colorsAdded [colorName]) then
                    tinsert (allColors, {colorTable, colorName, hex (colorTable[1]*255) .. hex (colorTable[2]*255) .. hex (colorTable[3]*255)})
                end
            end

            --table.sort (allColors, sort_color) --this make the list be listed from the brightness color to the darkness

            for index, colorTable in ipairs (allColors) do
                local colortable = colorTable[1]
                local colorname = colorTable[2]
                tinsert (t, {
                    label = colorname,
                    value = colorname,
                    color = colortable,
                    statusbar = dropdownStatusBarTexture,
                    statusbarcolor = dropdownStatusBarColor,
                    onclick = line_select_color_dropdown
                })
            end

            tinsert(t, 1, {
                label = "no color",
                value = "white",
                color = colorNoValue,
                statusbar = dropdownStatusBarTexture,
                statusbarcolor = dropdownStatusBarColor,
                iconcolor = dropdownIconColor,
                onclick = line_select_color_dropdown
            }) --localize-me

            castFrame.cachedColorTable = t
            return t
        else
            return castFrame.cachedColorTable
        end
    end

    --line
    local scroll_createline = function (self, index)

        local line = CreateFrame ("button", "$parentLine" .. index, self, BackdropTemplateMixin and "BackdropTemplate")
        line:SetPoint ("topleft", self, "topleft", 1, -((index-1)*(scroll_line_height+1)) - 1)
        line:SetSize (scroll_width - 3, scroll_line_height)
        line:SetScript ("OnEnter", line_onenter)
        line:SetScript ("OnLeave", line_onleave)

        line.RefreshColor = refresh_line_color

        line:SetBackdrop({bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
        line:SetBackdropColor(unpack (backdrop_color))

        DF:Mixin (line, DF.HeaderFunctions)

        --enabled check box
        local enabledCheckBox = DF:CreateSwitch(line, onToggleEnabled, true, _, _, _, _, "EnabledCheckbox", "$parentEnabledToggle" .. index, _, _, _, nil, DF:GetTemplate ("switch", "OPTIONS_CHECKBOX_BRIGHT_TEMPLATE"))
        enabledCheckBox:SetAsCheckBox()

        --has animation icon
        local hasAnimationIconTexture = DF:CreateImage(line, [[Interface\BUTTONS\UI-SpellbookIcon-NextPage-Up]], scroll_line_height-2, scroll_line_height-2)
        hasAnimationIconTexture:Hide()
        hasAnimationIconTexture:SetScale(1.1)
        hasAnimationIconTexture:SetAlpha(0.82)
        hasAnimationIconTexture:SetPoint("left", enabledCheckBox, "right", 2, 0)
        line.hasAnimationIconTexture = hasAnimationIconTexture

        --spell icon
        local spellIconTexture = DF:CreateImage(line, "", scroll_line_height-2, scroll_line_height-2)
        spellIconTexture:SetTexCoord(.1, .9, .1, .9)
        line.spellIconTexture = spellIconTexture

        --spell Id
        local spellIdEntry = DF:CreateTextEntry(line, function()end, headerTable[3].width, 20, "spellIdEntry", nil, nil, DF:GetTemplate ("dropdown", "PLATER_DROPDOWN_OPTIONS"))
        spellIdEntry:SetHook ("OnEditFocusGained", oneditfocusgained_spellid)
        spellIdEntry:SetJustifyH("left")

        --spell Name
        local spellNameEntry = DF:CreateTextEntry(line, function()end, headerTable[4].width, 20, "spellNameEntry", nil, nil, DF:GetTemplate ("dropdown", "PLATER_DROPDOWN_OPTIONS"))
        spellNameEntry:SetHook("OnEditFocusGained", oneditfocusgained_spellid)
        spellNameEntry:SetJustifyH("left")

        local spellRenameEntry = DF:CreateTextEntry(line, function()end, headerTable[5].width, 20, "spellRenameEntry", nil, nil, DF:GetTemplate ("dropdown", "PLATER_DROPDOWN_OPTIONS"))
        spellRenameEntry:SetHook("OnEditFocusGained", oneditfocusgained_spellid)
        spellRenameEntry:SetJustifyH("left")

        spellRenameEntry:SetHook("OnEditFocusLost", function(widget, capsule, text)
            local castColors = Plater.db.profile.cast_colors
            local spellId = capsule.spellId
            capsule.text = castColors[spellId] and castColors[spellId][CONST_INDEX_NAME] or ""
        end)

        spellRenameEntry:SetHook("OnEnterPressed", function(widget, capsule, text)
            local castColors = Plater.db.profile.cast_colors
            local spellId = capsule.spellId
            local castColor = castColors[spellId]

            if (text == "") then
                if (castColor) then
                    castColor[CONST_INDEX_NAME] = ""
                end
            else
                if (castColor) then
                    castColor[CONST_INDEX_NAME] = text
                else
                    castColors[spellId] = {true, "white", text}
                end
            end

            Plater.UpdateAllPlates()
        end)

        --npc name
        local npcNameLabel = DF:CreateLabel(line, "", 10, "white", nil, "npcNameLabel")

        --npc Id
        --local npcIdLabel = DF:CreateLabel(line, "", 10, "white", nil, "npcIdLabel")

        --send to raid button
        local sendToRaidButton = DF:CreateButton(line, function()end, headerTable[7].width, 20, "Click to Select", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
        line.sendToRaidButton = sendToRaidButton

        --location
        --local npcLocationLabel = DF:CreateLabel(line, "", 10, "white", nil, "npcLocationLabel")
        local selectAudioDropdown = DF:CreateDropDown(line, line_refresh_audio_dropdown, 1, headerTable[8].width - 1, 20, "SelectAudioDropdown", nil, DF:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))

        --encounter
        local encounterNameLabel = DF:CreateLabel(line, "", 10, "white", nil, "encounterNameLabel") --not in use, got replaced by spell name rename

        --color
        local colorDropdown = DF:CreateDropDown(line, line_refresh_color_dropdown, 1, headerTable[8].width - 1, 20, "ColorDropdown", nil, DF:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE"))

        enabledCheckBox:SetHook ("OnEnter", widget_onenter)
        enabledCheckBox:SetHook ("OnLeave", widget_onleave)
        spellIdEntry:SetHook ("OnEnter", widget_onenter)
        spellIdEntry:SetHook ("OnLeave", widget_onleave)
        spellNameEntry:SetHook ("OnEnter", widget_onenter)
        spellNameEntry:SetHook ("OnLeave", widget_onleave)
        spellRenameEntry:SetHook ("OnEnter", widget_onenter)
        spellRenameEntry:SetHook ("OnLeave", widget_onleave)
        colorDropdown:SetHook ("OnEnter", widget_onenter)
        colorDropdown:SetHook ("OnLeave", widget_onleave)
        selectAudioDropdown:SetHook("OnEnter", widget_onenter)
        selectAudioDropdown:SetHook("OnLeave", widget_onleave)

        line:AddFrameToHeaderAlignment (enabledCheckBox)
        line:AddFrameToHeaderAlignment (spellIconTexture)
        line:AddFrameToHeaderAlignment (spellIdEntry)
        line:AddFrameToHeaderAlignment (spellNameEntry)
        line:AddFrameToHeaderAlignment (spellRenameEntry)
        line:AddFrameToHeaderAlignment (npcNameLabel)
        line:AddFrameToHeaderAlignment (sendToRaidButton)
        --line:AddFrameToHeaderAlignment (npcIdLabel)
        line:AddFrameToHeaderAlignment (selectAudioDropdown)
        --line:AddFrameToHeaderAlignment (encounterNameLabel)
        line:AddFrameToHeaderAlignment (colorDropdown)

        line:AlignWithHeader (castFrame.Header, "left")

        return line
    end

        local onChangeOption = function()
            --when a setting if changed
            Plater.RefreshDBUpvalues()
            Plater.UpdateAllPlates()
            --optionsspFrameFrame.previewCastBar.UpdateAppearance()
        end

        --> build scripts preview to add the cast to a script
        local scriptPreviewFrame = CreateFrame("frame", castFrame:GetName() .. "ScriptPreviewPanel", castFrame, "BackdropTemplate")
        local spFrame = scriptPreviewFrame
        spFrame:SetPoint("topright", castFrame, "topright", 23, -56)
        spFrame:SetPoint("bottomright", castFrame, "bottomright", -10, 35)
        spFrame:SetWidth(250)
        spFrame:SetFrameLevel(castFrame:GetFrameLevel()+10)

        DF:ApplyStandardBackdrop(spFrame)
        spFrame:SetBackdropBorderColor(0, 0, 0, 0)
        spFrame:EnableMouse(true)

        local onChangeOption = function()
            --when a setting if changed
            Plater.RefreshDBUpvalues()
            Plater.UpdateAllPlates()
            --optionsspFrameFrame.previewCastBar.UpdateAppearance()
        end

        local settingsOverride = {
            FadeInTime = 0.02,
            FadeOutTime = 0.66,
            SparkHeight = 20,
            LazyUpdateCooldown = 0.1,
            FillOnInterrupt = false,
            HideSparkOnInterrupt = false,
        }

    local CONST_PREVIEW_SPELLID = 116
    local allPreviewFrames = {}
    castColorFrame.allPreviewFrames = allPreviewFrames

    local hasScriptWithPreviewSpellId = function(spellId)
        local previewSpellId = spellId or CONST_PREVIEW_SPELLID
        for i = 1, #platerInternal.Scripts.DefaultCastScripts do
            local scriptName = platerInternal.Scripts.DefaultCastScripts[i]
            local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
            if (scriptObject) then
                local index = DF.table.find(scriptObject.SpellIds, previewSpellId)
                if (index) then
                    return true
                end
            end
        end
    end

    local castBarPreviewTexture = [[Interface\AddOns\Plater\Images\cast_bar_scripts_preview]]
    local eachCastBarButtonHeight = PlaterOptionsPanelContainerCastColorManagementColorFrameScriptPreviewPanel:GetHeight() / #platerInternal.Scripts.DefaultCastScripts
    
    local scriptsToShow = {}
    for i = 1, #platerInternal.Scripts.DefaultCastScripts do
        local scriptName = platerInternal.Scripts.DefaultCastScripts[i]
        
        local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
        if (scriptObject) then
            scriptsToShow[#scriptsToShow + 1] = scriptName
        end
    end

    for i = 1, #scriptsToShow do
        local scriptName = scriptsToShow[i]
        
        local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
        if (scriptObject) then

            local previewFrame = CreateFrame("button", nil, spFrame, BackdropTemplateMixin and "BackdropTemplate")
            previewFrame:SetSize(spFrame:GetWidth()-5, eachCastBarButtonHeight) --270
            previewFrame:SetPoint("topleft", spFrame, "topleft", 5, (-eachCastBarButtonHeight * (i - 1)) -5)
            DF:ApplyStandardBackdrop(previewFrame)
            previewFrame.scriptName = scriptName

            local scriptNameText = previewFrame:CreateFontString(nil, "overlay", "GameFontNormal")
            scriptNameText:SetPoint("topright", previewFrame, "topright", -2, -1)
            scriptNameText:SetJustifyH("right")
            scriptNameText:SetText(scriptName)
            scriptNameText:SetAlpha(0.5)
            DF:SetFontSize(scriptNameText, 9)
            previewFrame.scriptNameText = scriptNameText

            local widthEnd = 282/512
            local textureHeight = 46.54 --increasing reduces the preview texture height

            local scriptPreviewTexture = previewFrame:CreateTexture(nil, "overlay")
            scriptPreviewTexture:SetTexture(castBarPreviewTexture)
            scriptPreviewTexture:SetTexCoord(0, widthEnd, textureHeight * (i-1) / 512, textureHeight * i / 512)
            scriptPreviewTexture:SetPoint("topleft", previewFrame, "topleft", 1, -1)
            scriptPreviewTexture:SetPoint("bottomright", previewFrame, "bottomright", -1, 1)
            scriptPreviewTexture:SetAlpha(1)
            --scriptPreviewTexture:SetBlendMode("ADD")

            local scriptPreviewTexture2 = previewFrame:CreateTexture(nil, "overlay")
            scriptPreviewTexture2:SetTexture(castBarPreviewTexture)
            scriptPreviewTexture2:SetTexCoord(0, widthEnd, textureHeight * (i-1) / 512, textureHeight * i / 512)
            scriptPreviewTexture2:SetPoint("topleft", previewFrame, "topleft", 1, -1)
            scriptPreviewTexture2:SetPoint("bottomright", previewFrame, "bottomright", -1, 1)
            scriptPreviewTexture2:SetAlpha(0.2)
            scriptPreviewTexture2:SetBlendMode("ADD")
            previewFrame.selectedHighlight = scriptPreviewTexture2

            local selectedScript = previewFrame:CreateTexture(nil, "overlay")
            selectedScript:SetPoint("topright", previewFrame, "topleft", 0, -1)
            selectedScript:SetPoint("bottomright", previewFrame, "bottomleft", 0, 1)
            selectedScript:SetColorTexture(.8, .8, .8, 0.92)
            selectedScript:SetWidth(7)
            selectedScript:Hide()
            previewFrame.selectedScript = selectedScript

            platerInternal.Scripts.RemoveSpellFromScriptTriggers(scriptObject, CONST_PREVIEW_SPELLID)

            previewFrame:EnableMouse(false)
            allPreviewFrames[#allPreviewFrames+1] = previewFrame

            previewFrame:SetScript("OnEnter", function(castBar)
                GameCooltip:Reset()
                GameCooltip:AddLine("Script:", previewFrame.scriptName)
                GameCooltip:AddLine("Click to use this animation when the cast start")
                GameCooltip:AddLine("Having enemy npcs near you, make their nameplates to preview this animation")

                local scriptObject = platerInternal.Scripts.GetScriptObjectByName(previewFrame.scriptName)
                if (scriptObject) then
                    GameCooltip:AddLine(" ")
                    GameCooltip:AddLine(scriptObject.Desc, "", 1, "yellow")
                end

                GameCooltip:SetOption("FixedWidth", 320)
                GameCooltip:SetOwner(previewFrame)
                GameCooltip:Show(previewFrame)
                previewFrame:SetBackdropBorderColor(1, .7, .1, 1)
                spFrame.StartCastBarPreview(previewFrame)
            end)

            previewFrame:SetScript("OnLeave", function(castBar)
                GameCooltip:Hide()
                previewFrame:SetBackdropBorderColor(0, 0, 0, 0)
                spFrame.StopCastBarPreview(previewFrame)
                if (spFrame.StopPreviewTimer and not spFrame.StopPreviewTimer:IsCancelled()) then
                    spFrame.StopPreviewTimer:Cancel()
                end
                spFrame.StopPreviewTimer = C_Timer.NewTimer(4, spFrame.ForceStopPreview)
            end)

            previewFrame:SetScript("OnClick", function() --~onclick õnclick
                local spellId = castColorFrame.currentSpellId
                local scriptName = previewFrame.scriptName
                local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
                if (scriptObject) then
                    --already have this trigger?
                    local index = DF.table.find(scriptObject.SpellIds, spellId)
                    if (index) then
                        spFrame.RemoveTriggerFromAllScriptsBySpellID(spellId)

                    else
                        spFrame.RemoveTriggerFromAllScriptsBySpellID(spellId)
                        platerInternal.Scripts.AddSpellToScriptTriggers(scriptObject, spellId)

                    end

                    castColorFrame.SelectScriptForSpellId(spellId)
                    castFrame.RefreshScroll()
                end
            end)
            
        end
    end

    function castColorFrame.SelectScriptForSpellId(spellId)
        local foundScriptWithThisSpellId = false
        for i = 1, #platerInternal.Scripts.DefaultCastScripts do
            local scriptName = platerInternal.Scripts.DefaultCastScripts[i]
            local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
            if (scriptObject) then
                local hasTrigger = platerInternal.Scripts.DoesScriptHasTrigger(scriptObject, spellId)
                if (hasTrigger) then
                    for o = 1, #allPreviewFrames do
                        local previewFrame = allPreviewFrames[o]
                        if (previewFrame.scriptName == scriptName) then
                            previewFrame.selectedScript:Show()
                            previewFrame.scriptNameText:SetAlpha(0.9)
                            previewFrame.selectedHighlight:Show()
                            foundScriptWithThisSpellId = true
                        else
                            previewFrame.selectedScript:Hide()
                            previewFrame.scriptNameText:SetAlpha(0.5)
                            previewFrame.selectedHighlight:Hide()
                        end
                    end
                end
            end
        end

        --no script has been found using this spellId as trigger
        if (not foundScriptWithThisSpellId) then
            for o = 1, #allPreviewFrames do
                local previewFrame = allPreviewFrames[o]
                previewFrame.selectedScript:Hide()
                previewFrame.scriptNameText:SetAlpha(0.5)
                previewFrame.selectedHighlight:Hide()
            end
        end
    end

    function spFrame.ForceStopPreview()
        if (not spFrame.HasPreviewButtonHover()) then
            Plater.StopCastBarTest()
        end
    end

    function spFrame.HasPreviewButtonHover()
        for i = 1, #allPreviewFrames do
            local button = allPreviewFrames[i]
            if (button:IsMouseOver()) then
                return button
            end
        end
    end

    function spFrame.CheckIfNoAnimationsArePlaying()
        if (hasScriptWithPreviewSpellId()) then
            return
        else
            --the spellId is free to be used on another script
            local previewFrame = spFrame.HasPreviewButtonHover()
            if (previewFrame) then
                spFrame.StartCastBarPreview(previewFrame)
                spFrame.checkQueueToPlayNextAnimation:Cancel()
            end
        end
    end

    function spFrame.StartCastBarPreview(previewFrame)
        if (hasScriptWithPreviewSpellId()) then
            if (not spFrame.checkQueueToPlayNextAnimation or spFrame.checkQueueToPlayNextAnimation:IsCancelled()) then
                spFrame.checkQueueToPlayNextAnimation = C_Timer.NewTicker(0.4, spFrame.CheckIfNoAnimationsArePlaying)
                return
            end
        end

        if (Plater.IsTestRunning) then
            return
        end

        --it's still fuckup
        local scriptName = previewFrame.scriptName
        local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
        if (scriptObject) then
            if (scriptPreviewFrame.TimerToRemoveTriggers) then
                if (not scriptPreviewFrame.TimerToRemoveTriggers:IsCancelled()) then
                    scriptPreviewFrame.TimerToRemoveTriggers:Cancel()
                end
            end

            spFrame.RemoveTriggerFromAllScripts()
            platerInternal.Scripts.AddSpellToScriptTriggers(scriptObject, CONST_PREVIEW_SPELLID)

            scriptPreviewFrame.NextAnimationCooldown = GetTime() + 2.05

            Plater.StartCastBarTest(true, 2)
        end

    end

    --on leave castBar area
    function spFrame.StopCastBarPreview(previewFrame)
        Plater.StopCastBarTest()

        local scriptName = previewFrame.scriptName
        local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
        if (not scriptObject) then
            Plater:Msg("[StopCastBarPreview] script not found:", scriptName)
            return
        end

        scriptPreviewFrame.TimerToRemoveTriggers = C_Timer.NewTimer(2.1, function()
            if (not Plater.IsTestRunning) then
                spFrame.RemoveTriggerFromAllScripts()
            end
        end)
    end

    function spFrame.RemoveTriggerFromAllScripts()
        --this should check if there's a any script running on any nameplate
        --technically this function shouldn't exists as all the functions above should clean up the
        --preview spellId from the trigger as it leave the preview button
        --if the user press escape, it will call this and might remove the trigger while the 
        --animation is still ongoing and cause the OnUpdate and OnHide scripts not triiger
        --thica cause issue of not hidding parts of the script animation

        local previewFrame = spFrame.HasPreviewButtonHover()
        if (previewFrame and spFrame.checkQueueToPlayNextAnimation and not spFrame.checkQueueToPlayNextAnimation:IsCancelled()) then
            spFrame.RemoveTriggerFromAllScriptsOnLeave()
            --will check if there's a button being hovered over
            spFrame.CheckIfNoAnimationsArePlaying()
            return
        end

        spFrame.RemoveTriggerFromAllScriptsOnLeave()
    end

    function spFrame.RemoveTriggerFromAllScriptsBySpellID(spellId)
        spellId = spellId or CONST_PREVIEW_SPELLID
        local noRecompile = true
        local scriptData = Plater.db.profile.script_data
        local spellRemoved = false
        for i, scriptObject in pairs(scriptData) do
            platerInternal.Scripts.RemoveSpellFromScriptTriggers(scriptObject, spellId, noRecompile)
            spellRemoved = true
        end

        if (spellRemoved) then
            Plater.WipeAndRecompileAllScripts("script")
        end
    end

    function spFrame.RemoveTriggerFromAllScriptsOnLeave()
        for i = 1, #platerInternal.Scripts.DefaultCastScripts do
            local scriptName = platerInternal.Scripts.DefaultCastScripts[i]
            local scriptObject = platerInternal.Scripts.GetScriptObjectByName(scriptName)
            if (scriptObject) then
                platerInternal.Scripts.RemoveSpellFromScriptTriggers(scriptObject, CONST_PREVIEW_SPELLID)
            end
        end

        if (spFrame.checkQueueToPlayNextAnimation and not spFrame.checkQueueToPlayNextAnimation:IsCancelled()) then
            spFrame.checkQueueToPlayNextAnimation:Cancel()
        end
    end

    spFrame:HookScript("OnShow", function()
        if (not spFrame.LoopPreviewTimer) then
            --spFrame.LoopPreviewTimer = DF.Schedules.NewTicker(2, startCasting)
        end
    end)

    spFrame.OnHide = function()
        if (Plater.IsTestRunning) then
            C_Timer.After(0.05, spFrame.OnHide)
        else
            spFrame.RemoveTriggerFromAllScriptsOnLeave()
        end
    end

    spFrame:HookScript("OnHide", function()
        spFrame.OnHide()
    end)

------------------------------------------------------------------------------------------------------------
        --> build the ~options panel
        local optionsFrame = CreateFrame("frame", castFrame:GetName() .. "OptionsPanel", castFrame, "BackdropTemplate")
        optionsFrame:SetPoint("topright", castFrame, "topright", -5, -56)
        optionsFrame:SetPoint("bottomright", castFrame, "bottomright", 0, 35)
        optionsFrame:SetWidth(270)
        optionsFrame:SetFrameLevel(castFrame:GetFrameLevel()+10)
        optionsFrame:Hide() --hidden by default

        DF:ApplyStandardBackdrop(optionsFrame)
        optionsFrame:SetBackdropBorderColor(0, 0, 0, 0)
        optionsFrame:EnableMouse(true)

        local onChangeOption = function()
            --when a setting if changed
            Plater.RefreshDBUpvalues()
            Plater.UpdateAllPlates()
            optionsFrame.previewCastBar.UpdateAppearance()
        end

        local layerNames = {
            "Background",
            "Artwork",
            "Overlay",
        }

        local buildLayerMenu = function()
            local t = {}
            for i = 1, #layerNames do
                tinsert (t, {
                    label = layerNames[i],
                    value = layerNames[i],
                    onclick = function (_, _, value)
                        Plater.db.profile.cast_color_settings.layer = value
                        onChangeOption()
                    end
                })
            end
            return t
        end

        --anchor table
        local anchorNames = Plater.AnchorNames

        local build_anchor_side_table = function()
            local t = {}
            for i = 1, 13 do
                tinsert (t, {
                    label = anchorNames[i],
                    value = i,
                    onclick = function (_, _, value)
                        Plater.db.profile.cast_color_settings.anchor.side = value
                        onChangeOption()
                    end
                })
            end
            return t
        end

        local optionsTable = {
            {
                type = "toggle",
                get = function() return Plater.db.profile.cast_color_settings.enabled end,
                set = function (self, fixedparam, value)
                    Plater.db.profile.cast_color_settings.enabled = value
                end,
                name = "Enable Original Cast Color",
                desc = "Show a small indicator showing the original color of the cast.",
            },
            {
                type = "range",
                get = function() return Plater.db.profile.cast_color_settings.alpha end,
                set = function (self, fixedparam, value)
                    Plater.db.profile.cast_color_settings.alpha = value
                end,
                min = 0,
                max = 1,
                step = 0.1,
                usedecimals = true,
                name = "Alpha",
            },
            {
                type = "range",
                get = function() return Plater.db.profile.cast_color_settings.width end,
                set = function (self, fixedparam, value)
                    Plater.db.profile.cast_color_settings.width = value
                end,
                min = 1,
                max = 200,
                step = 1,
                name = "Width",
            },
            {
                type = "range",
                get = function() return Plater.db.profile.cast_color_settings.height_offset end,
                set = function (self, fixedparam, value)
                    Plater.db.profile.cast_color_settings.height_offset = value
                end,
                min = -30,
                max = 30,
                step = 1,
                name = "Height Offset",
            },
            {
                type = "select",
                get = function() return Plater.db.profile.cast_color_settings.layer end,
                values = function() return buildLayerMenu() end,
                name = "Layer",
            },
            {
                type = "select",
                get = function() return Plater.db.profile.cast_color_settings.anchor.side end,
                values = function() return build_anchor_side_table() end,
                name = LOC["OPTIONS_ANCHOR"],
            },
            {
                type = "range",
                get = function() return Plater.db.profile.cast_color_settings.anchor.x end,
                set = function (self, fixedparam, value)
                    Plater.db.profile.cast_color_settings.anchor.x = value
                end,
                min = -200,
                max = 200,
                step = 1,
                usedecimals = true,
                name = LOC["OPTIONS_XOFFSET"],
            },
            {
                type = "range",
                get = function() return Plater.db.profile.cast_color_settings.anchor.y end,
                set = function (self, fixedparam, value)
                    Plater.db.profile.cast_color_settings.anchor.y = value
                end,
                min = -200,
                max = 200,
                step = 1,
                usedecimals = true,
                name = LOC["OPTIONS_YOFFSET"],
            },

        }

        local startX, startY, heightSize = 10, -10, optionsFrame:GetHeight()
        _G.C_Timer.After(0.5, function() --~delay
            DF:BuildMenu(optionsFrame, optionsTable, startX, startY, heightSize, true, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template, onChangeOption)
        end)

    -->  ~preview window (not in use as the script choise frame is over this one)
        local previewWindow = CreateFrame("frame", optionsFrame:GetName() .. "previewWindown", optionsFrame, "BackdropTemplate")
        previewWindow:SetSize(250, 40)
        previewWindow:SetPoint("topleft", optionsFrame, "topleft", 10, -240)
        previewWindow:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
        previewWindow:SetBackdropBorderColor(0, 0, 0, .6)
        previewWindow:SetBackdropColor(0.1, 0.1, 0.1, 0.4)

        local previewLabel = Plater:CreateLabel(previewWindow, "Quick Preview")
        previewLabel:SetPoint("bottomleft", previewWindow, "topleft", 0, 14)
        local castLabel = Plater:CreateLabel(previewWindow, "Cast a spell, refresh, than add a color for it")
        castLabel:SetPoint("topleft", previewLabel, "bottomleft", 0, -2)

        previewLabel.textcolor = "gray"
        castLabel.textcolor = "gray"

        local settingsOverride = {
            FadeInTime = 0.02,
            FadeOutTime = 0.66,
            SparkHeight = 20,
            LazyUpdateCooldown = 0.1,
        }

        local previewCastBar = DF:CreateCastBar(previewWindow, previewWindow:GetName() .. "CastBar", settingsOverride)
        optionsFrame.previewCastBar = previewCastBar
        castColorFrame.optionsFrame = optionsFrame

        previewCastBar:SetSize(190, 20)
        previewCastBar:SetPoint("center", previewWindow, "center", 0, 0)
        previewCastBar:SetUnit("player")
        previewCastBar:Show()

        previewCastBar.percentText:SetText("1.5")
        previewCastBar:SetMinMaxValues(0, 1)
        previewCastBar.value = 0.6
        previewCastBar.maxValue = 1
        previewCastBar:OnTick_Casting(0.016)
        previewCastBar.Spark:Show()

        local spellName, _, spellIcon = GetSpellInfo(CONST_PREVIEW_SPELLID)
        previewCastBar.Text:SetText(spellName)
        previewCastBar.Icon:SetTexture(spellIcon)
        previewCastBar.Icon:SetAlpha(1)
        previewCastBar.Icon:Show()
        previewCastBar.Icon:SetSize(previewCastBar:GetHeight()-2, previewCastBar:GetHeight()-2)
        previewCastBar.Icon:SetTexCoord(.1, .9, .1, .9)

        previewCastBar.Spark:SetTexture(Plater.db.profile.cast_statusbar_spark_texture)
        previewCastBar.Spark:SetVertexColor(unpack (Plater.db.profile.cast_statusbar_spark_color))
        previewCastBar.Spark:SetAlpha(Plater.db.profile.cast_statusbar_spark_alpha)
        previewCastBar:SetColor(Plater.db.profile.cast_statusbar_color)
        previewCastBar:SetStatusBarTexture(LibSharedMedia:Fetch("statusbar", Plater.db.profile.cast_statusbar_texture))

        previewCastBar.castColorTexture = previewCastBar:CreateTexture("$parentCastColor", "background", nil, -6)

        local hookEventCast = function(self, event, unit, ...)
            local isEnabled = DB_CAST_COLORS[self.spellID] and DB_CAST_COLORS[self.spellID][CONST_INDEX_ENABLED]
            if (isEnabled) then
                previewCastBar.castColorTexture:SetColorTexture(unpack(Plater.db.profile.cast_statusbar_color))
            end
        end
        hooksecurefunc(previewCastBar, "UNIT_SPELLCAST_START", hookEventCast)
        hooksecurefunc(previewCastBar, "UNIT_SPELLCAST_CHANNEL_START", hookEventCast)

        function previewCastBar.UpdateAppearance()
            local profile = Plater.db.profile

            --original cast color
            local isEnabled = profile.cast_color_settings.enabled
            if (isEnabled) then
                previewCastBar.castColorTexture:SetColorTexture(unpack(Plater.db.profile.cast_statusbar_color))
                previewCastBar.castColorTexture:SetHeight(previewCastBar:GetHeight() + profile.cast_color_settings.height_offset)
                previewCastBar.castColorTexture:SetWidth(profile.cast_color_settings.width)
                previewCastBar.castColorTexture:SetAlpha(profile.cast_color_settings.alpha)
                previewCastBar.castColorTexture:SetDrawLayer(profile.cast_color_settings.layer, -6)
                Plater.SetAnchor(previewCastBar.castColorTexture, profile.cast_color_settings.anchor)
                previewCastBar.castColorTexture:Show()
            else
                previewCastBar.castColorTexture:Hide()
            end

            --cast color
            local latestSpellId = castColorFrame.latestSpellId
            if (latestSpellId) then
                local castColor = DB_CAST_COLORS[latestSpellId]
                if (castColor) then
                    local color = castColor[CONST_INDEX_COLOR]
                    if (color and color ~= "white") then
                        previewCastBar:SetColor(color)
                    else
                        previewCastBar:SetColor(Plater.db.profile.cast_statusbar_color)
                        previewCastBar.castColorTexture:Hide()
                    end
                else
                    previewCastBar:SetColor(Plater.db.profile.cast_statusbar_color)
                    previewCastBar.castColorTexture:Hide()
                end
            else
                previewCastBar:SetColor(Plater.db.profile.cast_statusbar_color)
                previewCastBar.castColorTexture:Hide()
            end
        end

        previewCastBar.UpdateAppearance()

    --end preview

    local sort_enabled_colors = function (t1, t2)
        if (t1[2] < t2[2]) then --color
            return true
        elseif (t1[2] > t2[2]) then --color
            return false
        else
            return t1[4] < t2[4] --alphabetical
        end
    end

    local sortByEnabledColor = function (t1, t2)
        if (t1[1] and not t2[1]) then --color
            return true
        elseif (not t1[1] and t2[1]) then --color
            return false
        else
            return t1[4] < t2[4] --alphabetical
        end
    end

    local sort_enabled_animation = function (t1, t2)
        if (t1[11] and not t2[11]) then
            return true
        elseif (not t1[11] and t2[11]) then
            return false
        else
            return t1[4] < t2[4] --alphabetical
        end
    end

    local sort_has_audio_cue = function(t1, t2)
        if (t1[12] and not t2[12]) then
            return true
        elseif (not t1[12] and t2[12]) then
            return false
        else
            return t1[4] < t2[4] --alphabetical
        end
    end

    local sortOrder4R = function(t1, t2)
        return t1[4] < t2[4]
    end

    --callback from have clicked in the 'Share With Raid' button
    local latestMenuClicked = false
    local onSendToRaidButtonClicked = function(self, button, spellId)
        if (spellId == latestMenuClicked and GameCooltip:IsShown()) then
            GameCooltip:Hide()
            latestMenuClicked = false
            return
        end

        latestMenuClicked = spellId

        GameCooltip:Preset(2)
        GameCooltip:SetOwner(self)
        GameCooltip:SetType("menu")
        GameCooltip:SetFixedParameter(spellId)

        local bAutoAccept = false

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "castcolor", "", "Send Color", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\JumpUpArrow]], 1, 1, 14, 14)

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "castrename", "", "Send Rename", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\JumpUpArrow]], 1, 1, 14, 14)

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "castscript", "", "Send Script", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\JumpUpArrow]], 1, 1, 14, 14)

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "resetcast", "", "Send Reset", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\UI-MicroStream-Red]], 1, 1, 14, 14)

        GameCooltip:AddLine("$div")
        bAutoAccept = true

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "castcolor", "", "Send Color (auto accept)", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\JumpUpArrow]], 1, 1, 14, 14)

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "castrename", "", "Send Rename (auto accept)", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\JumpUpArrow]], 1, 1, 14, 14)

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "castscript", "", "Send Script (auto accept)", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\JumpUpArrow]], 1, 1, 14, 14)

        GameCooltip:AddMenu(1, platerInternal.Comms.SendCastInfoToGroup, bAutoAccept, "resetcast", "", "Send Reset (auto accept)", nil, true)
        GameCooltip:AddIcon([[Interface\BUTTONS\UI-MicroStream-Red]], 1, 1, 14, 14)

        --GameCooltip:AddLine("$div")

        GameCooltip:Show()
    end

    --refresh scroll
    local IsSearchingFor
    local scroll_refresh = function (self, data, offset, totalLines)
        local dataInOrder = {}

        if (IsSearchingFor and IsSearchingFor ~= "") then
            if (self.SearchCachedTable and IsSearchingFor == self.SearchCachedTable.SearchTerm) then
                dataInOrder = self.SearchCachedTable
            else
                local enabledTable = {}

                for i = 1, #data do
                    local thisData = data[i]

                    local isEnabled = thisData[CONST_CASTINFO_ENABLED]
                    local color = thisData[CONST_CASTINFO_COLOR]
                    local spellId = thisData[CONST_CASTINFO_SPELLID]
                    local spellName = thisData[CONST_CASTINFO_SPELLNAME]
                    local spellIcon = thisData[CONST_CASTINFO_SPELLICON]
                    local sourceName = thisData[CONST_CASTINFO_SOURCENAME]
                    local npcId = thisData[CONST_CASTINFO_NPCID]
                    local npcLocation = thisData[CONST_CASTINFO_NPCLOCATION]
                    local encounterName = thisData[CONST_CASTINFO_ENCOUNTERNAME]
                    local customSpellName = thisData[CONST_CASTINFO_CUSTOMSPELLNAME]

                    local isTriggerOfAnyPreviewScript = hasScriptWithPreviewSpellId(spellId)

                    if (spellName:lower():find(IsSearchingFor) or sourceName:lower():find(IsSearchingFor) or npcLocation:lower():find(IsSearchingFor) or encounterName:lower():find(IsSearchingFor)) then
                        if (isEnabled) then
                            enabledTable[#enabledTable+1] = {true, color, spellId, spellName, spellIcon, sourceName, npcId, npcLocation, encounterName, customSpellName, isTriggerOfAnyPreviewScript or false, DB_CAST_AUDIOCUES[spellId] or false}
                        else
                            dataInOrder[#dataInOrder+1] = {false, color, spellId, spellName, spellIcon, sourceName, npcId, npcLocation, encounterName, customSpellName, isTriggerOfAnyPreviewScript or false, DB_CAST_AUDIOCUES[spellId] or false}
                        end
                    end
                end

                table.sort (enabledTable, sort_enabled_colors) --sort by enabled state
                table.sort (enabledTable, sort_enabled_animation) --is has a script trigger

                table.sort (dataInOrder, sortOrder4R) --by spell name
                table.sort (dataInOrder, sort_enabled_animation) --is has a script trigger
                table.sort (dataInOrder, sort_has_audio_cue) --has an audio cue

                --make the dropdown be bigger
                --table.sort (enabledTable, sort_enabled_colors)
                --table.sort (dataInOrder, sortOrder4R) --spell name

                for i = #enabledTable, 1, -1 do
                    tinsert (dataInOrder, 1, enabledTable[i])
                end

                self.SearchCachedTable = dataInOrder
                self.SearchCachedTable.SearchTerm = IsSearchingFor
            end
        else
            if (not self.CachedTable) then
                local enabledTable = {}

                for i = 1, #data do
                    local thisData = data[i]

                    local isEnabled = thisData[CONST_CASTINFO_ENABLED]
                    local color = thisData[CONST_CASTINFO_COLOR]
                    local spellId = thisData[CONST_CASTINFO_SPELLID]
                    local spellName = thisData[CONST_CASTINFO_SPELLNAME]
                    local spellIcon = thisData[CONST_CASTINFO_SPELLICON]
                    local sourceName = thisData[CONST_CASTINFO_SOURCENAME]
                    local npcId = thisData[CONST_CASTINFO_NPCID]
                    local npcLocation = thisData[CONST_CASTINFO_NPCLOCATION]
                    local encounterName = thisData[CONST_CASTINFO_ENCOUNTERNAME]
                    local customSpellName = thisData[CONST_CASTINFO_CUSTOMSPELLNAME]

                    local isTriggerOfAnyPreviewScript = hasScriptWithPreviewSpellId(spellId)

                    if (isEnabled) then
                        enabledTable[#enabledTable+1] = {true, color, spellId, spellName, spellIcon, sourceName, npcId, npcLocation, encounterName, customSpellName, isTriggerOfAnyPreviewScript or false, DB_CAST_AUDIOCUES[spellId]}
                    else
                        dataInOrder[#dataInOrder+1] = {false, color, spellId, spellName, spellIcon, sourceName, npcId, npcLocation, encounterName, customSpellName, isTriggerOfAnyPreviewScript or false, DB_CAST_AUDIOCUES[spellId]}
                    end
                end

                self.CachedTable = dataInOrder

                table.sort (enabledTable, sort_enabled_colors) --sort by enabled state
                table.sort (enabledTable, sort_enabled_animation) --has a script trigger

                table.sort (dataInOrder, sortOrder4R) --by spell name
                table.sort (dataInOrder, sort_enabled_animation) --has a script trigger
                table.sort (dataInOrder, sort_has_audio_cue) --has an audio cue

                for i = #enabledTable, 1, -1 do
                    tinsert (dataInOrder, 1, enabledTable[i])
                end
            end

            dataInOrder = self.CachedTable
        end

        --hide the empty text if there's enough results
        if (#dataInOrder > 6) then
            castFrame.EmptyText:Hide()
        end

        data = dataInOrder

        for i = 1, totalLines do
            local index = i + offset
            local spellInfo = data[index]
            if (spellInfo) then
                local line = self:GetLine(i)

                local isEnabled = spellInfo[CONST_CASTINFO_ENABLED]
                local color = spellInfo[CONST_CASTINFO_COLOR]
                local spellId = spellInfo[CONST_CASTINFO_SPELLID]
                local spellName = spellInfo[CONST_CASTINFO_SPELLNAME]
                local spellIcon = spellInfo[CONST_CASTINFO_SPELLICON]
                local sourceName = spellInfo[CONST_CASTINFO_SOURCENAME]
                local npcId = spellInfo[CONST_CASTINFO_NPCID]
                local npcLocation = spellInfo[CONST_CASTINFO_NPCLOCATION]
                local encounterName = spellInfo[CONST_CASTINFO_ENCOUNTERNAME]
                local customSpellName = spellInfo[CONST_CASTINFO_CUSTOMSPELLNAME]

                line.value = spellInfo
                line.spellId = nil

                if (spellName) then --~refresh
                    local colorOption = color
                    line.spellId = spellId

                    line.ColorDropdown.spellId = spellId
                    line.ColorDropdown:SetFixedParameter(spellId)

                    line.SelectAudioDropdown.spellId = spellId
                    line.SelectAudioDropdown:SetFixedParameter(spellId)
                    local selectedAudioCue = DB_CAST_AUDIOCUES[spellId]
                    if (selectedAudioCue)then
                        --this spell has an audio cue
                        line.SelectAudioDropdown:Select(selectedAudioCue)
                    else
                        line.SelectAudioDropdown:Select(1, true)
                    end

                    line.sendToRaidButton.spellId = spellId
                    line.sendToRaidButton:SetClickFunction(onSendToRaidButtonClicked, spellId)

                    line.spellRenameEntry.spellId = spellId

                    line.spellIconTexture:SetTexture(spellIcon)
                    line.spellIdEntry:SetText(spellId)
                    line.spellNameEntry:SetText(spellName)
                    line.spellRenameEntry:SetText(customSpellName)
                    line.npcNameLabel:SetText(sourceName)
                    --line.npcIdLabel:SetText(npcId)
                    --line.npcLocationLabel:SetText(npcLocation)
                    line.encounterNameLabel:SetText(encounterName)

                    line.hasAnimationIconTexture:SetShown(spellInfo[11])

                    castFrame.CheckBoxCache[spellId] = line.EnabledCheckbox

                    if (colorOption) then
                        --causing lag in the scroll - might be an issue with dropdown:Select
                        --Select: is calling a dispatch making it to rebuild the entire color table, may be caching the color table might save performance
                        line.EnabledCheckbox:SetValue(isEnabled)
                        line.ColorDropdown:Select(color)

                        if (isEnabled) then
                            line:RefreshColor(color)
                        else
                            line:RefreshColor()
                        end
                    else
                        line.EnabledCheckbox:SetValue(false)
                        line.ColorDropdown:Select("white")

                        line:RefreshColor()
                    end

                    line.EnabledCheckbox:SetFixedParameter(spellId)
                else
                    line:Hide()
                end
            end
        end
    end

    --create scroll
    local spells_scroll = DF:CreateScrollBox (castFrame, "$parentColorsScroll", scroll_refresh, {}, scroll_width, scroll_height, scroll_lines, scroll_line_height)
    DF:ReskinSlider (spells_scroll)
    spells_scroll:SetPoint ("topleft", castFrame, "topleft", 5, scrollY)
    castFrame.spellsScroll = spells_scroll

    spells_scroll:SetScript("OnShow", function(self)
        if (self.LastRefresh and self.LastRefresh+0.5 > GetTime()) then
            return
        end
        self.LastRefresh = GetTime()

        local newData = {}
        local addedSpells = {}
        --[=[
        --captured_spells
        [205762] = {
            ["source"] = "Wastewander Tracker",
            ["event"] = "SPELL_CAST_SUCCESS",
            ["npcID"] = 154461,
        },

        --npc_cache
            [135475] = {
                "Kula the Butcher", -- [1] Npc Name
                "Kings' Rest", -- [2] Location
            },
        --]=]

        for spellId, spellTable in pairs(DB_CAPTURED_CASTS) do
            local spellName, _, spellIcon = GetSpellInfo(spellId)
            if (spellName) then
                --build the castInfo table for this spell
                local npcId = spellTable.npcID
                local isEnabled = DB_CAST_COLORS[spellId] and DB_CAST_COLORS[spellId][CONST_INDEX_ENABLED] or false
                local color = DB_CAST_COLORS[spellId] and DB_CAST_COLORS[spellId][CONST_INDEX_COLOR] or "white"
                local customSpellName = DB_CAST_COLORS[spellId] and DB_CAST_COLORS[spellId][CONST_INDEX_NAME] or ""

                local castInfo = {
                    isEnabled,
                    color,
                    spellId,
                    spellName,
                    spellIcon,
                    DB_NPCIDS_CACHE[npcId] and DB_NPCIDS_CACHE[npcId][1] or "", --npc name
                    npcId,
                    DB_NPCIDS_CACHE[npcId] and DB_NPCIDS_CACHE[npcId][2] or "", --npc location
                    spellTable.encounterName or "",
                    customSpellName,
                }

                tinsert(newData, castInfo)
                addedSpells[spellId] = true
            end
        end
        
        -- add SPELLS as well, if not yet added.
        for spellId, spellTable in pairs(DB_CAPTURED_SPELLS) do
            local spellName, _, spellIcon, castTime = GetSpellInfo(spellId)
            if (spellName and not addedSpells[spellId] and (castTime > 0 or spellTable.isChanneled) and spellTable.event == "SPELL_CAST_SUCCESS") then -- and spellTable.event ~= "SPELL_AURA_APPLIED" ?
                --build the castInfo table for this spell
                local npcId = spellTable.npcID
                local isEnabled = DB_CAST_COLORS[spellId] and DB_CAST_COLORS[spellId][CONST_INDEX_ENABLED] or false
                local color = DB_CAST_COLORS[spellId] and DB_CAST_COLORS[spellId][CONST_INDEX_COLOR] or "white"
                local customSpellName = DB_CAST_COLORS[spellId] and DB_CAST_COLORS[spellId][CONST_INDEX_NAME] or ""

                local castInfo = {
                    isEnabled,
                    color,
                    spellId,
                    spellName,
                    spellIcon,
                    DB_NPCIDS_CACHE[npcId] and DB_NPCIDS_CACHE[npcId][1] or "", --npc name
                    npcId,
                    DB_NPCIDS_CACHE[npcId] and DB_NPCIDS_CACHE[npcId][2] or "", --npc location
                    spellTable.encounterName or "",
                    customSpellName,
                }

                tinsert(newData, castInfo)
            end
        end

        self.CachedTable = nil
        self.SearchCachedTable = nil

        self:SetData(newData)
        self:Refresh()
    end)

    --create lines
    for i = 1, scroll_lines do
        spells_scroll:CreateLine (scroll_createline)
    end

    --create search box
        function castFrame.OnSearchBoxTextChanged()
            local text = castFrame.AuraSearchTextEntry:GetText()
            if (text and string.len (text) > 0) then
                IsSearchingFor = text:lower()
            else
                IsSearchingFor = nil
            end
            spells_scroll:Refresh()
        end

        local aura_search_textentry = DF:CreateTextEntry(castFrame, function()end, 150, 20, "AuraSearchTextEntry", _, _, options_dropdown_template)
        aura_search_textentry:SetPoint("bottomright", castFrame, "topright", 0, -20)
        aura_search_textentry:SetHook("OnChar", castFrame.OnSearchBoxTextChanged)
        aura_search_textentry:SetHook("OnTextChanged", castFrame.OnSearchBoxTextChanged)

        local aura_search_label = DF:CreateLabel(aura_search_textentry, "search", DF:GetTemplate ("font", "ORANGE_FONT_TEMPLATE"))
        aura_search_label:SetPoint("left", aura_search_textentry, "left", 4, 0)
        aura_search_label.fontcolor = "gray"
        aura_search_label.color = {.5, .5, .5, .3}
        aura_search_textentry.tooltip = "- Spell Name\n- Npc Name\n- Zone Name\n- Encounter Name"
        aura_search_textentry:SetFrameLevel(castFrame.Header:GetFrameLevel() + 20)

        --clear search button
        local clear_search_button = DF:CreateButton(castFrame, function() aura_search_textentry:SetText(""); aura_search_textentry:ClearFocus() end, 20, 20, "", -1)
        clear_search_button:SetPoint("right", aura_search_textentry, "right", 5, 0)
        clear_search_button:SetAlpha(.7)
        clear_search_button:SetIcon([[Interface\Glues\LOGIN\Glues-CheckBox-Check]])
        clear_search_button.icon:SetDesaturated(true)
        clear_search_button:SetFrameLevel(castFrame.Header:GetFrameLevel() + 21)

        function castFrame.RefreshScroll(refreshSpeed)
            if (refreshSpeed and refreshSpeed == 0) then
                spells_scroll:Hide()
                spells_scroll:Show()
            else
                spells_scroll:Hide()
                C_Timer.After (refreshSpeed or .01, function() spells_scroll:Show() end)
            end
        end

    --help button
        local help_button = DF:CreateButton(castFrame, function()end, 70, 20, "help", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
        help_button:SetPoint("right", aura_search_textentry, "left", -2, 0)
        help_button.tooltip = "|cFFFFFF00Help:|r\n\n- Spell are filled as they are seen.\n\n- Colors set in scripts and hooks override colors set here.\n\n- |TInterface\\AddOns\\Plater\\media\\star_empty_64:16:16|t icon indicates the color is favorite, so you can use it across all spells to keep color consistency."
        help_button:SetFrameLevel(castFrame.Header:GetFrameLevel() + 20)

    --refresh button
        local refresh_button = DF:CreateButton (castFrame, function() castFrame.RefreshScroll() end, 70, 20, "refresh", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
        refresh_button:SetPoint("right", help_button, "left", -2, 0)
        refresh_button:SetFrameLevel(castFrame.Header:GetFrameLevel() + 20)

        local create_import_box = function (parent, mainFrame)
            --create the text editor
            local import_text_editor = DF:NewSpecialLuaEditorEntry(parent, edit_script_size[1], edit_script_size[2], "ImportEditor", "$parentImportEditor", true)
            import_text_editor:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
            import_text_editor:SetBackdropBorderColor(unpack (luaeditor_border_color))
            import_text_editor:SetBackdropColor(.3, .3, .3, 1)
            import_text_editor:Hide()
            import_text_editor:SetFrameLevel(parent:GetFrameLevel()+100)
            DF:ReskinSlider(import_text_editor.scroll)

            --background color
            local bg = import_text_editor:CreateTexture(nil, "background")
            bg:SetColorTexture(0.1, 0.1, 0.1, .9)
            bg:SetAllPoints()

            local block_mouse_frame = CreateFrame("frame", nil, import_text_editor, BackdropTemplateMixin and "BackdropTemplate")
            block_mouse_frame:SetFrameLevel(block_mouse_frame:GetFrameLevel()-5)
            block_mouse_frame:SetAllPoints()
            block_mouse_frame:SetScript("OnMouseDown", function()
                import_text_editor:SetFocus(true)
            end)

            mainFrame.ImportTextEditor = import_text_editor

            --import button
            local okay_import_button = DF:CreateButton(import_text_editor, mainFrame.ImportColors, buttons_size[1], buttons_size[2], "Okay", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
            okay_import_button:SetIcon([[Interface\BUTTONS\UI-Panel-BiggerButton-Up]], 20, 20, "overlay", {0.1, .9, 0.1, .9})
            okay_import_button:SetPoint("topright", import_text_editor, "bottomright", 0, 1)

            --cancel button
            local cancel_import_button = DF:CreateButton(import_text_editor, function() mainFrame.ImportTextEditor:Hide() end, buttons_size[1], buttons_size[2], "Cancel", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
            cancel_import_button:SetIcon([[Interface\BUTTONS\UI-Panel-MinimizeButton-Up]], 20, 20, "overlay", {0.1, .9, 0.1, .9})
            cancel_import_button:SetPoint("right", okay_import_button, "left", -2, 0)

            import_text_editor.OkayButton = okay_import_button
            import_text_editor.CancelButton = cancel_import_button
        end

        -- ~importcolor
        function castFrame.ImportColors()
            --get the colors from the text field and code it to import

            if (castFrame.IsImporting) then
                local text = castFrame.ImportEditor:GetText()
                text = DF:Trim(text)
                local colorData = Plater.DecompressData(text, "print")

                --exported cast colors has this member to identify the exported data
                if (colorData and colorData[Plater.Export_CastColors]) then

                    --the uncompressed table is a numeric table of tables
                    for i, colorTable in pairs(colorData) do
                        --check integrity
                        if (type(colorTable) == "table") then

                            local spellId, color, npcId, sourceName, npcLocation, encounterName, customSpellName, audioCue = unpack(colorTable)

                            --check integrity
                            spellId = tonumber(spellId)
                            color = tostring(color or "white")
                            npcId = tonumber(npcId)
                            sourceName = tostring(sourceName or "")
                            npcLocation = tostring(npcLocation or "")
                            encounterName = tostring(encounterName or "")
                            customSpellName = tostring(customSpellName or "")
                            audioCue = tostring(audioCue) -- may be nil

                            if (spellId and (color or customSpellName)) then
                                --add into the cast_colors data
                                DB_CAST_COLORS[spellId] = DB_CAST_COLORS[spellId] or {}
                                DB_CAST_COLORS[spellId][CONST_INDEX_COLOR] = color
                                DB_CAST_COLORS[spellId][CONST_INDEX_ENABLED] = true
                                DB_CAST_COLORS[spellId][CONST_INDEX_NAME] = customSpellName
                                
                                DB_CAST_AUDIOCUES[spellId] = audioCue

                                --add into the discoreved spell cache
                                if (not DB_CAPTURED_SPELLS[spellId]) then
                                    DB_CAPTURED_SPELLS[spellId] = {
                                        event = "SPELL_CAST_SUCCESS",
                                        source = sourceName,
                                        npcID = npcId,
                                        encounterName = encounterName,
                                    }
                                end

                                --add into the npc cache
                                if (npcId and npcId ~= 0 and sourceName and sourceName ~= "" and npcLocation and npcLocation ~= "") then
                                    if (not DB_NPCIDS_CACHE[npcId]) then
                                        DB_NPCIDS_CACHE[npcId] = {
                                            sourceName,
                                            npcLocation
                                        }
                                    end
                                end
                            end
                        end
                    end

                    castFrame.RefreshScroll()
                    Plater:Msg ("cast colors imported.")
                else
                    Plater.SendScriptTypeErrorMsg(colorData)
                end
            end

            castFrame.ImportEditor:Hide()
        end

    --import and export buttons
        local import_func = function()
            if (not castFrame.ImportEditor) then
                create_import_box(castFrame, castFrame)
            end

            castFrame.IsExporting = nil
            castFrame.IsImporting = true

            castFrame.ImportEditor:Show()
            castFrame.ImportEditor:SetPoint("topleft", castFrame.Header, "topleft")
            castFrame.ImportEditor:SetPoint("bottomright", castFrame, "bottomright", -17, 37)

            castFrame.ImportEditor:SetText("")
            C_Timer.After(.1, function()
                castFrame.ImportEditor.editbox:HighlightText()
                castFrame.ImportEditor.editbox:SetFocus(true)
            end)
        end

        local import_button = DF:CreateButton(castFrame, import_func, 70, 20, "import", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
        import_button:SetPoint("right", refresh_button, "left", -2, 0)
        import_button:SetFrameLevel(castFrame.Header:GetFrameLevel() + 20)

        local export_func = function()
            if (not castFrame.ImportEditor) then
                create_import_box(castFrame, castFrame)
            end

            --build the list of colors to be exported
            --~exportcolor ~export color table to string
            --this is the table which will be compress with libdeflate
            local exportedTable = {
                [Plater.Export_CastColors] = true, --identify this table as a cast color table
            }

            --[=[
			["cast_colors"] = {
				[325727] = {
					true, -- [1]
					"greenyellow", -- [2]
				},
			},
            --]=]
            --check if the user is searching npcs, build the export table only using the cast colors shown in the result
            if (IsSearchingFor and IsSearchingFor ~= "" and spells_scroll.SearchCachedTable) then
                local dbColors = Plater.db.profile.cast_colors

                for i, searchResult in ipairs(spells_scroll.SearchCachedTable) do
                    local spellId = searchResult[CONST_CASTINFO_SPELLID]
                    local sourceName = searchResult[CONST_CASTINFO_SOURCENAME]
                    local npcId = searchResult[CONST_CASTINFO_NPCID]
                    local npcLocation = searchResult[CONST_CASTINFO_NPCLOCATION]
                    local encounterName = searchResult[CONST_CASTINFO_ENCOUNTERNAME]
                    local customSpellName = searchResult[CONST_CASTINFO_CUSTOMSPELLNAME] or ""
                    local audioCue = DB_CAST_AUDIOCUES[spellId]

                    local castColor = dbColors[spellId]

                    if (castColor) then
                        local isEnabled = castColor[CONST_INDEX_ENABLED]
                        local color = castColor[CONST_INDEX_COLOR]
                        if (isEnabled) then
                            tinsert (exportedTable, {spellId, color, npcId, sourceName, npcLocation, encounterName, customSpellName, audioCue})
                        end
                    end
                end
            else
                for spellId, castColor in pairs(Plater.db.profile.cast_colors) do
                    local isEnabled = castColor[CONST_INDEX_ENABLED]
                    local color = castColor[CONST_INDEX_COLOR]
                    local npcId, sourceName, npcLocation, encounterName
                    local customSpellName = castColor[CONST_INDEX_NAME] or ""
                    local audioCue = DB_CAST_AUDIOCUES[spellId]

                    --this db gives source, npcID, event, encounterName
                    local capturedSpell = DB_CAPTURED_SPELLS[spellId] or DB_CAPTURED_CASTS[spellId]
                    if (capturedSpell) then
                        npcId = capturedSpell.npcID or 0

                        --this db give npc name, npc location
                        local npcInfo = DB_NPCIDS_CACHE[npcId]
                        if (npcInfo) then
                            sourceName = npcInfo[1] or ""
                            npcLocation = npcInfo[2] or ""
                        end
                    end

                    npcId = npcId or 0
                    sourceName = sourceName or ""
                    npcLocation = npcLocation or ""
                    encounterName = capturedSpell and capturedSpell.encounterName or ""

                    if (isEnabled) then
                        tinsert (exportedTable, {spellId, color, npcId, sourceName, npcLocation, encounterName, customSpellName, audioCue})
                    end
                end
            end

            --check if there's at least 1 color being exported
            if (#exportedTable < 1) then
                Plater:Msg ("There's nothing to export.")
                return
            end

            castFrame.IsExporting = true
            castFrame.IsImporting = nil

            castFrame.ImportEditor:Show()
            castFrame.ImportEditor:SetPoint("topleft", castFrame.Header, "topleft")
            castFrame.ImportEditor:SetPoint("bottomright", castFrame, "bottomright", -17, 37)

            --compress data and show it in the text editor
            local data = Plater.CompressData(exportedTable, "print")
            castFrame.ImportEditor:SetText(data or "failed to export color table")

            C_Timer.After (.1, function()
                castFrame.ImportEditor.editbox:HighlightText()
                castFrame.ImportEditor.editbox:SetFocus(true)
            end)
        end

        local export_button = DF:CreateButton(castFrame, export_func, 70, 20, "export", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
        export_button:SetPoint("right", import_button, "left", -2, 0)
        export_button:SetFrameLevel(castFrame.Header:GetFrameLevel() + 20)

        castFrame.showingScriptSelection = true
        local toggleScriptSelectionAndOptionsFrame = function()
            if (castFrame.showingScriptSelection) then
                spFrame:Hide()
                optionsFrame:Show()
                castFrame.toggleOptionsButton:SetText("Show Scripts")
            else
                spFrame:Show()
                optionsFrame:Hide()
                castFrame.toggleOptionsButton:SetText("Show Options")
            end

            castFrame.showingScriptSelection = not castFrame.showingScriptSelection
        end

        local toggleOptionsButton = DF:CreateButton(castFrame, toggleScriptSelectionAndOptionsFrame, 70, 20, "Show Options", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
        toggleOptionsButton:SetPoint("right", export_button, "left", -2, 0)
        toggleOptionsButton:SetFrameLevel(castFrame.Header:GetFrameLevel() + 20)
        castFrame.toggleOptionsButton = toggleOptionsButton

    --disable all button
        local disableAllColors = function()
            for spellId, colorTable in pairs(Plater.db.profile.cast_colors) do
                colorTable[CONST_INDEX_ENABLED] = false
            end
            castFrame.RefreshScroll()
        end

        local disableall_button = DF:CreateButton(castFrame, disableAllColors, 140, 20, "Disable All Colors", -1, nil, nil, nil, nil, nil, DF:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE"), DF:GetTemplate ("font", "PLATER_BUTTON"))
        disableall_button:SetPoint("bottomleft", spells_scroll, "bottomleft", 1, 0)
        disableall_button:SetFrameLevel(castFrame.Header:GetFrameLevel() + 20)

    -- buttons backdrop
        local backdropFoot = CreateFrame("frame", nil, spells_scroll, BackdropTemplateMixin and "BackdropTemplate")
        backdropFoot:SetHeight(20)
        backdropFoot:SetPoint("bottomleft", spells_scroll, "bottomleft", 0, 0)
        backdropFoot:SetPoint("bottomright", castFrame, "bottomright", -3, 0)
        backdropFoot:SetBackdrop({edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1, bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
        backdropFoot:SetBackdropColor(.52, .52, .52, .7)
        backdropFoot:SetBackdropBorderColor(0, 0, 0, 1)
        backdropFoot:SetFrameLevel(castFrame.Header:GetFrameLevel() + 19)

    --empty label
        local empty_text = DF:CreateLabel(castFrame, "this list is automatically filled when\nyou see enemies casting spells inside a dungeons and raids\n\nthen you may select colors here.")
        empty_text.fontsize = 24
        empty_text.align = "|"
        empty_text:SetPoint("center", spells_scroll, "center", -130, 0)
        castFrame.EmptyText = empty_text

    --create the description
    castFrame.TitleDescText = Plater:CreateLabel(castFrame, "For raid and dungeon npcs, they are added into the list after you see them for the first time", 10, "silver")
    castFrame.TitleDescText:SetPoint("bottomleft", spells_scroll, "topleft", 0, 26)

    castFrame:SetScript("OnHide", function()
        if (castFrame.ImportEditor) then
            castFrame.ImportEditor:Hide()
            castFrame.ImportEditor.IsExporting = nil
            castFrame.ImportEditor.IsImporting = nil
        end
    end)

end