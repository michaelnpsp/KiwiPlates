--=================================================================
-- Target CastBar Implementation
--=================================================================

local addon = KiwiPlates
if not addon.isClassic then return end

addon.defaults.targetCastBar = {}

local CastingBarFrame_SetUnit = KiwiPlatesCastingBarFrame_SetUnit

local targetCastBar

local function UpdatePlayerTarget()
	CastingBarFrame_SetUnit(targetCastBar, 'target')
end

local function UpdateTargetCastBar()
	local db = addon.db.targetCastBar
	if db.enabled then
		targetCastBar = targetCastBar or CreateFrame("StatusBar", nil, UIParent, "KiwiPlatesCastingBarFrameTemplate")
		targetCastBar:Hide()
		targetCastBar:ClearAllPoints()
		targetCastBar:SetPoint("CENTER", UIParent, "CENTER", (db.offsetX or 0)+(db.barHeight or 20)/2, db.offsetY or 250)
		targetCastBar:SetSize( db.barWidth or 300, db.barHeight or 20)
		targetCastBar.Text:SetFont( addon.FontCache[db.barFontFile or 'Roboto Condensed Bold'], db.barFontSize or 12, db.barFontFlags or 'OUTLINE' )
		targetCastBar:SetStatusBarTexture( addon.TexCache[db.barTexture] )
		local icon = targetCastBar.Icon
		local size = db.iconSize or targetCastBar:GetHeight()
		icon:ClearAllPoints()
		icon:SetPoint('BOTTOMRIGHT', targetCastBar, 'BOTTOMLEFT', db.iconOffsetX or -1, db.iconOffsetY or 0 )
		icon:SetSize( size, size)
		icon:SetShown(db.iconEnabled)
		targetCastBar:SetScript('OnEvent', UpdatePlayerTarget)
		targetCastBar:RegisterEvent("PLAYER_TARGET_CHANGED")
		local border = targetCastBar.Border
		if db.borderTexture then
			border:SetDrawLayer('ARTWORK',7)
			addon.SetBorderTexture( targetCastBar, border, db.borderTexture or "Bliz White", db.borderColor or addon.ColorWhite )
		else
			local size = db.borderSize or 1
			border:ClearAllPoints()
			border:SetPoint("TOPLEFT",     targetCastBar, "TOPLEFT",    -size, size)
			border:SetPoint("BOTTOMRIGHT", targetCastBar, "BOTTOMRIGHT", size,-size)
			border:SetDrawLayer('BACKGROUND',-8)
			border:SetTexCoord( 0,1,0,1 )
			border:SetColorTexture( unpack(db.borderColor or addon.ColorBlack) )
		end
		UpdatePlayerTarget()
		addon.targetCastBar = targetCastBar
	elseif targetCastBar then
		targetCastBar:SetScript('OnEvent', nil)
		targetCastBar:UnregisterEvent("PLAYER_TARGET_CHANGED")
		CastingBarFrame_SetUnit(targetCastBar, nil)
		targetCastBar:Hide()
	end
end

-- Initialization

addon:RegisterMessage('UPDATE', UpdateTargetCastBar )

-- Options

local function Update()
	UpdateTargetCastBar()
	if addon.db.targetCastBar.enabled then
		targetCastBar.maxValue = 500
		targetCastBar.value = targetCastBar.maxValue / 3
		targetCastBar:SetMinMaxValues(0, targetCastBar.maxValue)
		targetCastBar.Text:SetText('Spell Name Example')
		targetCastBar.Icon:SetTexture( 'Interface\\ICONS\\Ability_Creature_Cursed_05' )
		targetCastBar:Show()
	end
end

-- addon.OptionsTable.args.Extras = { type = "group", order = 25, name = 'Extras', childGroups = "tab", args = {} }

addon:SetupOptions( 'Extras', 'CastBar(Target)', {
	barEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = addon.FormatTitle("Casting Bar for Target", true),
		get = function() return addon.db.targetCastBar.enabled end,
		set = function (_, value)
			addon.db.targetCastBar.enabled = value or nil
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Cast Bar" },
	barOffsetX =  {
		type = 'range', order = 6, width = 1.5, name = 'X Offset', softMin = -500, softMax = 500, step = 1,
		get = function() return addon.db.targetCastBar.offsetX or 0 end,
		set = function(info,value)
			addon.db.targetCastBar.offsetX = value
			Update()
		end,
	},
	barOffsetY =  {
		type = 'range', order = 7, width = 1.5, name = 'Y Offset', softMin = -500, softMax = 500, step = 1,
		get = function() return addon.db.targetCastBar.offsetY or 250 end,
		set = function(info,value)
			addon.db.targetCastBar.offsetY = value
			Update()
		end,
	},
	barWidth = {
		type = 'range', order = 11, width = 1.5, name = 'Bar Width', min = 0, softMax = 500, step = 1,
		get = function() return addon.db.targetCastBar.barWidth	or 200 end,
		set = function(info,value)
			addon.db.targetCastBar.barWidth = value
			Update()
		end,
	},
	barHeight =  {
		type = 'range', order = 12, width = 1.5, name = 'Bar Height', min = 1, softMax = 64, step = 1,
		get = function() return addon.db.targetCastBar.barHeight or 16 end,
		set = function(info,value)
			addon.db.targetCastBar.barHeight = value
			Update()
		end,
	},
	barTexture = {
		type = "select", dialogControl = "LSM30_Statusbar",
		order = 13,
		width = 1.5,
		name = "Bar Texture",
		desc = "Adjust the bar texture.",
		get = function (info) return addon.db.targetCastBar.barTexture or "Minimalist" end,
		set = function (info, v)
			addon.db.targetCastBar.barTexture = v
			Update()
		end,
		values = AceGUIWidgetLSMlists.statusbar,
	},
	barTestMode = {
		type = 'execute',
		order = 13.5,
		width = 1.5,
		name = "Toggle Test Mode",
		desc = 'Show/Hide the casting bar for testing purposes.',
		func = function()
			if targetCastBar and targetCastBar:IsVisible() then
				targetCastBar:Hide()
			else
				Update()
			end
		end,
		hidden = function() return not addon.db.targetCastBar.enabled end,
	},
	headerBorder = { type = "header", order = 13.9, name = "Border" },
	barBorderTexture = {
		type = "select",
		order = 14,
		name = "Border Texture",
		desc = "Border Texture",
		get = function()
			return addon.db.targetCastBar.borderTexture or 'Flat'
		end,
		set = function (_, v)
			addon.db.targetCastBar.borderTexture = (v~='Flat') and v or nil
			addon.db.targetCastBar.borderSize = nil
			Update()
		end,
		values = addon.BorderTextures,
	},
	barBorderSize = {
		type = "range",
		order = 15,
		name = "Border Size",
		softMin = 0, softMax = 32, step = 1,
		get = function()
			return addon.db.targetCastBar.borderSize or 1
		end,
		set = function (_, value)
			addon.db.targetCastBar.borderSize = value~=1 and value or nil
			Update()
		end,
		hidden = function() return addon.__db.global.classicBorders end,
	},
	barBorderColor = {
		type = "color",
		order = 16,
		hasAlpha = true,
		name = "Border Color",
		get = function()
			return unpack( addon.db.targetCastBar.borderColor or (addon.db.targetCastBar.borderTexture and addon.ColorWhite) or addon.ColorBlack )
		end,
		set = function( _, r,g,b,a )
			addon.db.targetCastBar.borderColor = { r, g, b, a }
			Update()
		end,
	},
	header15 = { type = "header", order = 17, name = "Icon" },
	barIconOffsetX = {
		type = "range",
		order = 19.1,
		width = 1.5,
		name = "X Offset",
		desc = "Horizontal Offset",
		softMin = -256, softMax = 256, step = 1,
		get = function()
			return addon.db.targetCastBar.iconOffsetX or -1
		end,
		set = function (_, value)
			addon.db.targetCastBar.iconOffsetX = value~=-1 and value or nil
			Update()
		end,
		disabled = function() return not addon.db.targetCastBar.iconEnabled end,
	},
	barIconOffsetY = {
		type = "range",
		order = 19.2,
		width = 1.5,
		name = "Y Offset",
		desc = "Horizontal Offset",
		softMin = -128, softMax = 128, step = 1,
		get = function()
			return addon.db.targetCastBar.iconOffsetY or 0
		end,
		set = function (_, value)
			addon.db.targetCastBar.iconOffsetY = value~=0 and value or nil
			Update()
		end,
		disabled = function() return not addon.db.targetCastBar.iconEnabled end,
	},
	barIconSize = {
		type = "range",
		order = 19.4,
		width = 1.5,
		name = "Icon Size",
		desc = "Set zero to use the cast bar height",
		min = 0, softMax = 65, step = 1,
		get = function()
			return addon.db.targetCastBar.iconSize or 0
		end,
		set = function (_, value)
			addon.db.targetCastBar.iconSize = value~=0 and value or nil
			Update()
		end,
		disabled = function() return not addon.db.targetCastBar.iconEnabled end,
	},
	barShowIcon = {
		type = "toggle",
		order = 19.5,
		name = "Show Spell Icon",
		get = function() return addon.db.targetCastBar.iconEnabled end,
		set = function (_, value)
			addon.db.targetCastBar.iconEnabled = value or nil
			Update()
		end,
	},
	headerText = { type = "header", order = 20, name = "Text" },
	cbFontFile = {
		type = "select", dialogControl = "LSM30_Font",
		order = 21,
		name = "Font Name",
		values = AceGUIWidgetLSMlists.font,
		get = function () return addon.db.targetCastBar.barFontFile or 'Roboto Condensed Bold' end,
		set = function (_, v)
			addon.db.targetCastBar.barFontFile = v
			Update()
		end,
	},
	cbFontFlags = {
		type = "select",
		order = 22,
		name = "Font Border",
		values = addon.fontFlagsValues,
		get = function () return addon.db.targetCastBar.barFontFlags or "OUTLINE" end,
		set = function (_, v)
			addon.db.targetCastBar.barFontFlags =  v ~= "OUTLINE" and v or nil
			Update()
		end,
	},
	cbFontSize = {
		type = "range",
		order = 23,
		name = 'Font Size',
		min = 1,
		softMax =50,
		step = 1,
		get = function () return addon.db.targetCastBar.barFontSize or 8 end,
		set = function (_, v)
			addon.db.targetCastBar.barFontSize = v~=8 and v or nil
			Update()
		end,
	},
}, nil, { disabled = function() return not addon.db.targetCastBar.enabled end } )
