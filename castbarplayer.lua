--=================================================================
-- Player CastBar Skining
--=================================================================

local addon = KiwiPlates
if not addon.isClassic then return end

addon.defaults.playerCastBar = {}

local castBar = CastingBarFrame -- blizzard player casting bar

local function UpdateCastBar()
	local db = addon.db.playerCastBar
	local w = db.barWidth or 300
	local h = db.barHeight or 20
	castBar:ClearAllPoints()
	castBar:SetPoint("BOTTOM", UIParent, "BOTTOM", db.offsetX or 0 , db.offsetY or 55)
	castBar:SetSize( w, h )
	castBar:SetStatusBarTexture( addon.TexCache[db.barTexture] )
	castBar.Text:ClearAllPoints()
	castBar.Text:SetAllPoints()
	castBar.Text:SetFont( addon.FontCache[db.barFontFile or 'Roboto Condensed Bold'], db.barFontSize or 12, db.barFontFlags or 'OUTLINE' )
	castBar.Icon:ClearAllPoints()
	castBar.Icon:SetPoint("RIGHT", castBar, "LEFT", db.iconOffsetX or -1, db.iconOffsetY or 0)
	castBar.Icon:SetSize( db.iconSize or h, db.iconSize or h )
	castBar.Icon:SetShown(db.iconEnabled)
	local border = castBar.Border
	if db.borderTexture then
		addon.SetBorderTexture( castBar, border, db.borderTexture or "Bliz White", db.borderColor or addon.ColorWhite )
		border:SetDrawLayer('ARTWORK',7)
	else
		local size = db.borderSize or 1
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", castBar, "TOPLEFT", -size, size)
		border:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMRIGHT", size, -size)
		border:SetColorTexture( unpack(db.borderColor or addon.ColorBlack) )
		border:SetDrawLayer('BACKGROUND',0)
	end
	castBar.Flash:SetColorTexture(0,0,0,0)
	for i = castBar:GetNumRegions(),1,-1 do
		local tex = select(i, castBar:GetRegions())
		if tex and tex:IsObjectType('Texture') and tex:GetDrawLayer()=='BACKGROUND' and tex~=castBar.Border then
			tex:SetDrawLayer('BACKGROUND',1)
			tex:SetColorTexture(.1,.1,.1,1)
			break
		end
	end
end

-- Init

CastingBarFrame.ignoreFramePositionManager = true
addon:RegisterMessage('ENABLE', function()
	if addon.db.playerCastBar.enabled == true then
		UpdateCastBar()
	elseif addon.db.playerCastBar.enabled == false then
		CastingBarFrame.RegisterEvent = function() end
		CastingBarFrame:UnregisterAllEvents()
		CastingBarFrame:Hide()
	end
end )

-- Options

local function Update()
	if addon.db.playerCastBar.enabled == true then
		UpdateCastBar()
		castBar.casting = true
		castBar.maxValue = 500
		castBar.value = castBar.maxValue / 3
		castBar:SetMinMaxValues(0, castBar.maxValue)
		castBar.Text:SetText('Spell Name Example')
		castBar.Icon:SetTexture( 'Interface\\ICONS\\Ability_Creature_Cursed_05' )
		castBar.Flash:Hide()
		castBar:Show()
		CastingBarFrame_ApplyAlpha(castBar, 1)
	end
end

addon:SetupOptions( 'Extras', 'CastBar(Player)', {
	barEnabled = {
		type = 'select',
		order = 0,
		width = 'normal',
		name = 'Select Bar Type:',
		get = function()
			local v = addon.db.playerCastBar.enabled
			return (v==nil and 1) or (v==true and 2) or 3
		end,
		set = function(info, v)
			if v==1 then
				addon.db.playerCastBar.enabled = nil
			else
				addon.db.playerCastBar.enabled = (v==2)
			end
			ReloadUI()
		end,
		values = { addon.FormatTitle('Blizzard Casting Bar'), addon.FormatTitle('Kiwi Casting Bar'), addon.FormatTitle('Disable Casting Bar') },
		confirm = function() return "An UI Reload is required to change this option. Are you sure ?" end,
	},
	header1 = { type = "header", order = 5, name = "Casting Bar for Player" },
	barOffsetX =  {
		type = 'range', order = 6, width = 1.5, name = 'X Offset', softMin = -500, softMax = 500, step = 1,
		get = function() return addon.db.playerCastBar.offsetX or 0 end,
		set = function(info,value)
			addon.db.playerCastBar.offsetX = value
			Update()
		end,
	},
	barOffsetY =  {
		type = 'range', order = 7, width = 1.5, name = 'Y Offset', softMin = 0, softMax = math.floor(GetScreenHeight()+.5), step = 1,
		get = function() return addon.db.playerCastBar.offsetY or 55 end,
		set = function(info,value)
			addon.db.playerCastBar.offsetY = value
			Update()
		end,
	},
	barWidth = {
		type = 'range', order = 11, width = 1.5, name = 'Bar Width', min = 0, softMax = 500, step = 1,
		get = function() return addon.db.playerCastBar.barWidth	or 200 end,
		set = function(info,value)
			addon.db.playerCastBar.barWidth = value
			Update()
		end,
	},
	barHeight =  {
		type = 'range', order = 12, width = 1.5, name = 'Bar Height', min = 1, softMax = 64, step = 1,
		get = function() return addon.db.playerCastBar.barHeight or 16 end,
		set = function(info,value)
			addon.db.playerCastBar.barHeight = value
			Update()
		end,
	},
	barTexture = {
		type = "select", dialogControl = "LSM30_Statusbar",
		order = 13,
		width = 1.5,
		name = "Bar Texture",
		desc = "Adjust the bar texture.",
		get = function (info) return addon.db.playerCastBar.barTexture or "Minimalist" end,
		set = function (info, v)
			addon.db.playerCastBar.barTexture = v
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
			if castBar and castBar:IsVisible() then
				castBar:Hide()
			else
				Update()
			end
		end,
		hidden = function() return not addon.db.playerCastBar.enabled end,
	},
	headerBorder = { type = "header", order = 13.9, name = "Border" },
	barBorderTexture = {
		type = "select",
		order = 14,
		name = "Border Texture",
		desc = "Warning: Blizzard textures are not compatible with solid colors, so to enable blizzard textures the UI will be reloaded.",
		get = function()
			return addon.db.playerCastBar.borderTexture or 'Flat'
		end,
		set = function (_, v)
			addon.db.playerCastBar.borderTexture = (v~='Flat') and v or nil
			addon.db.playerCastBar.borderSize = nil
			Update()
		end,
		values = addon.BorderTextures,
	},
	barBorderSize = {
		type = "range",
		order = 15,
		name = "Border Size",
		softMin = 0, softMax = 33, step = 1,
		get = function()
			return addon.db.playerCastBar.borderSize or 1
		end,
		set = function (_, value)
			addon.db.playerCastBar.borderSize = value~=1 and value or nil
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
			return unpack ( addon.db.playerCastBar.borderColor or (addon.db.playerCastBar.borderTexture and addon.ColorWhite) or addon.ColorBlack )
		end,
		set = function( _, r,g,b,a )
			addon.db.playerCastBar.borderColor = { r, g, b, a }
			Update()
		end,
	},
	headerIcon = { type = "header", order = 17, name = "Icon" },
	barIconOffsetX = {
		type = "range",
		order = 19.1,
		width = 1.5,
		name = "X Offset",
		desc = "Horizontal Offset",
		softMin = -256, softMax = 256, step = 1,
		get = function()
			return addon.db.playerCastBar.iconOffsetX or -1
		end,
		set = function (_, value)
			addon.db.playerCastBar.iconOffsetX = value~=-1 and value or nil
			Update()
		end,
		disabled = function() return not addon.db.playerCastBar.iconEnabled end,
	},
	barIconOffsetY = {
		type = "range",
		order = 19.2,
		width = 1.5,
		name = "Y Offset",
		desc = "Horizontal Offset",
		softMin = -128, softMax = 128, step = 1,
		get = function()
			return addon.db.playerCastBar.iconOffsetY or 0
		end,
		set = function (_, value)
			addon.db.playerCastBar.iconOffsetY = value~=0 and value or nil
			Update()
		end,
		disabled = function() return not addon.db.playerCastBar.iconEnabled end,
	},
	barIconSize = {
		type = "range",
		order = 19.3,
		width = 1.5,
		name = "Icon Size",
		desc = "Set zero to use the cast bar height",
		min = 0, softMax = 65, step = 1,
		get = function()
			return addon.db.playerCastBar.iconSize or 0
		end,
		set = function (_, value)
			addon.db.playerCastBar.iconSize = value~=0 and value or nil
			Update()
		end,
		disabled = function() return not addon.db.playerCastBar.iconEnabled end,
	},
	barShowIcon = {
		type = "toggle",
		order = 19.6,
		name = "Show Spell Icon",
		get = function() return addon.db.playerCastBar.iconEnabled end,
		set = function (_, value)
			addon.db.playerCastBar.iconEnabled = value or nil
			Update()
		end,
	},
	header2 = { type = "header", order = 20, name = "Spell Text" },
	cbFontFile = {
		type = "select", dialogControl = "LSM30_Font",
		order = 21,
		name = "Font Name",
		values = AceGUIWidgetLSMlists.font,
		get = function () return addon.db.playerCastBar.barFontFile or 'Roboto Condensed Bold' end,
		set = function (_, v)
			addon.db.playerCastBar.barFontFile = v
			Update()
		end,
	},
	cbFontFlags = {
		type = "select",
		order = 22,
		name = "Font Border",
		values = addon.fontFlagsValues,
		get = function () return addon.db.playerCastBar.barFontFlags or "OUTLINE" end,
		set = function (_, v)
			addon.db.playerCastBar.barFontFlags =  v ~= "OUTLINE" and v or nil
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
		get = function () return addon.db.playerCastBar.barFontSize or 8 end,
		set = function (_, v)
			addon.db.playerCastBar.barFontSize = v~=8 and v or nil
			Update()
		end,
	},
}, nil, { disabled = function() return addon.db.playerCastBar.enabled~=true end } )

