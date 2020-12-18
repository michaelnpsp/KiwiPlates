----------------------------------------------------------------
-- KiwiPlates: core
----------------------------------------------------------------

local addon = KiwiPlates

local Media  = LibStub("LibSharedMedia-3.0", true)

local next    = next
local pairs   = pairs
local ipairs  = ipairs
local unpack  = unpack
local select  = select
local strsub  = strsub
local gsub    = string.gsub
local format  = string.format
local tinsert = table.insert
local tremove = table.remove
local tconcat = table.concat
local bor = bit.bor
local band = bit.band
local rshift = bit.rshift

local isClassic = addon.isClassic
local isRetail = not isClassic
local UNKNOWNOBJECT = UNKNOWNOBJECT
local IsInRaid = IsInRaid
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitHealth = UnitHealth
local UnitIsFriend = UnitIsFriend
local UnitReaction = UnitReaction
local IsInInstance = IsInInstance
local UnitHealthMax = UnitHealthMax
local UnitCanAttack = UnitCanAttack
local UnitIsTapDenied = UnitIsTapDenied
local UnitClassification = UnitClassification
local UnitAffectingCombat = UnitAffectingCombat
local GetNumSubgroupMembers = GetNumSubgroupMembers
local UnitGroupRolesAssigned = UnitGroupRolesAssigned or function() return "NONE" end
local C_GetNamePlateForUnit  = C_NamePlate.GetNamePlateForUnit
local C_SetNamePlateSelfSize = C_NamePlate.SetNamePlateSelfSize
local DifficultyColor = addon.DIFFICULTY_LEVEL_COLOR
local CastingBarFrame_SetUnit = isClassic and KiwiPlatesCastingBarFrame_SetUnit or addon.CastingBarFrame_SetUnit

local InCombat = false
local InGroup
local InstanceType
local pixelScale
local targetFrame
local targetExists
local mouseFrame
local RealMobHealth -- Classic

local GetPlateSkin
local ConditionFields = {}
local activeWidgets = {}
local activeStatuses = {}

local cfgTestSkin -- Test Mode
local cfgAlpha1
local cfgAlpha2
local cfgAlpha3
local cfgAdjustAlpha
local cfgReactionColor
local cfgHealthColor1
local cfgHealthColor2
local cfgHealthColor3
local cfgHealthThreshold1
local cfgHealthThreshold2
local cfgClassColorReaction = {}
local cfgClassicBorders
local cfgTipProfessionLine
local cfgPlatesAdjustW = isClassic and 0 or 24

local NamePlates = {}
local NamePlatesByUnit = {}
local NamePlatesByGUID = {}
local NamePlatesAll = {}

local target = setmetatable({}, {__index = function(t,k) local v=k.."target" t[k]=v return v end})

local Types = { a = 'Player', e = 'Creature', t = 'Pet', m = 'GameObject', h = 'Vehicle', g = 'Vignette' }

local Reactions = { 'hostile', 'hostile', 'hostile', 'neutral', 'friendly', 'friendly',	'friendly',	'friendly' }

local Classifications = { elite = '+', rare = 'r', rareelite = 'r+', boss = 'b' }

local ClassColors = { UNKNOWN = {1,1,1,1} }
for class,color in pairs(RAID_CLASS_COLORS) do
	ClassColors[class] = { color.r, color.g, color.b, 1 }
end

local ColorTransparent = { 0,0,0,0 }

local ColorBlack = { 0,0,0,1 }

local ColorWhite = { 1,1,1,1 }

local ColorDefault = ColorWhite

local ColorWidgets  = {
	kHealthBar    = "Health Bar",
	kHealthBorder = "Health Border",
	kHealthText   = "Health Text",
	kLevelText    = "Level Text",
	kNameText     = "Name Text",
}

local ColorStatuses = {
	color    = "Custom Color",
	health   = "Health Percent",
	reaction = "Unit Reaction",
	class    = "Class Color",
	level    = "Unit Level",
}

-- Color statuses that cannot be overrided (for example by the threat module)
local ColorsNonOverride = {
	blizzard = true, health = true,
}

-- Health tags: percent, health, maxhealth
local HealthTags = { ['$p'] = '', ['$h'] = '', ['$m'] = '' }

-- Used to call CreateMethods & SkinMethods
local WidgetNames = {
	--Available Widgets
	'kCastBar',
	'kHealthBar',
	'kHealthBorder',
	'kHealthText',
	'kNameText',
	'kLevelText',
	'kAttackers',
	'kIcon',
	'RaidTargetFrame',
	-- Used to check if the widget was already created, field value exists in the UnitFrame if the widget was already created.
	kCastBar      = 'kkCastBar',
	kHealthBar    = 'kkHealthBar',
	kHealthBorder = 'kkHealthBorder',
	kHealthText   = 'kkHealthText',
	kNameText     = 'kkNameText',
	kLevelText    = 'kkLevelText',
	kAttackers    = 'kkAttackers',
	kIcon         = 'kkIcon',
	RaidTargetFrame = 'RaidTargetFrame',
}

local FontCache = setmetatable({}, {__index = function(t,k) local v = Media:Fetch('font',      k or 'Roboto Condensed Bold'); t[k or 'Roboto Condensed Bold'] = v; return v end})
local TexCache  = setmetatable({}, {__index = function(t,k) local v = Media:Fetch('statusbar', k or 'Minimalist');            t[k or 'Minimalist'] = v;            return v end})

-- borders
local BorderTextureDefault = 'Flat'
local BorderTexturesData = {}
local BorderTextures = {} -- Used by option tables as values for 'select' type

local function SetBorderTexture(anchorObj, texObj, texName, color)
	local f = BorderTexturesData[texName] or BorderTexturesData.Flat
	local w, h = anchorObj:GetSize()
	texObj:ClearAllPoints()
	texObj:SetPoint("TOPLEFT",     anchorObj, "TOPLEFT",    f[2]*w, f[4]*h)
	texObj:SetPoint("BOTTOMRIGHT", anchorObj, "BOTTOMRIGHT",f[3]*w, f[5]*h)
	texObj:SetTexture( f[1] )
	if color then texObj:SetVertexColor( unpack(color or ColorDefault) ) end
end

local function RegisterBorderTexture(name, file, x1, x2, y1, y2)
	local m1 =     x1 / (x2-x1)
	local m2 = (1-x2) / (x2-x1)
	local m3 =     y1 / (y2-y1)
	local m4 = (1-y2) / (y2-y1)
	BorderTextures[name] = name
	BorderTexturesData[name] = { file, -m1, m2, m3, -m4 }
	BorderTexturesData[file] = name
end

RegisterBorderTexture( 'Flat',                  'Interface\\Addons\\KiwiPlates\\media\\borderf',     1/127, 126/127,  1/15, 14/15)
RegisterBorderTexture( 'Bliz Gold',             'Interface\\Addons\\KiwiPlates\\media\\borderg',     3/127, 124/127,  3/15, 12/15)
RegisterBorderTexture( 'Bliz White',            'Interface\\Addons\\KiwiPlates\\media\\borderw',     3/127, 124/127,  3/15, 12/15)
RegisterBorderTexture( 'Bliz StatusBar',        'Interface\\Tooltips\\UI-StatusBar-Border',          3/127, 124/127,  3/15, 12/15)
RegisterBorderTexture( 'Bliz CastingBar',       'Interface\\CastingBar\\UI-CastingBar-Border',       33/255,222/255, 27/63, 37/63)
RegisterBorderTexture( 'Bliz CastingBar Small', 'Interface\\CastingBar\\UI-CastingBar-Border-Small', 32/255,223/255, 25/63, 38/63)

-- classification textures
local CoordEmpty = { 0,0,0,0 }

local ClassTexturesCoord = {
	WARRIOR     = {   0, .25,   0, .25 },
	MAGE        = { .25, .50,   0, .25 },
	ROGUE       = { .50, .75,   0, .25 },
	DRUID       = { .75,   1,   0, .25 },
	HUNTER      = {   0, .25, .25, .50 },
	SHAMAN      = { .25, .50, .25, .50 },
	PRIEST      = { .50, .75, .25, .50 },
	WARLOCK     = { .75,   1, .25, .50 },
	PALADIN     = {   0, .25, .50, .75 },
	DEATHKNIGHT = { .25, .50, .50, .75 },
	MONK        = { .50, .75, .50, .75 },
	DEMONHUNTER = { .75,   1, .50, .75 },
    elite       = {   0, .25, .75,   1 },
 	rare        = { .25, .50, .75,   1 },
	rareelite   = { .50, .75, .75,   1 },
	boss        = { .75,   1, .75,   1 },
}

----------------------------------------------------------------
--
----------------------------------------------------------------

addon.defaults = {
	version = 4,
	general = {
		highlight     = true,
		classColor    = {},
		healthColor   = { threshold1 = .9, threshold2 = .3, color1 = { .6,1,.8,1 }, color2 = { 1,1,1,1 }, color3 = { 1,.4,.3,1 } },
		reactionColor = { hostile = {.7,.2,.1,1}, neutral = {1,.8,0,1}, friendly = {.2,.6,.1,1}, tapped = {.5,.5,.5,1}, playerfriendly = {.2,.6,.1,1}, playerhostile = {.7,.2,.1,1}	},
	},
	skins = { { __skinName = 'Default', kCastBar_enabled = true, kHealthBar_enabled = true, kHealthBorder_enabled = true, kNameText_enabled = true, kLevelText_enabled = true, kHealthText_enabled = true, RaidTargetFrame_enabled = true } },
	rules = { { 'and' } },
	minimapIcon = {},
	roles = isClassic and {} or nil,
}

----------------------------------------------------------------
-- Used to reparent disabled/unused textures
----------------------------------------------------------------

local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()

----------------------------------------------------------------
-- Highlight texture
----------------------------------------------------------------

local HighlightTex = HiddenFrame:CreateTexture(nil, "OVERLAY")
HighlightTex:SetColorTexture(1,1,1,.2)
HighlightTex:SetVertexColor(1,1,1,1)
HighlightTex:SetBlendMode('ADD')

----------------------------------------------------------------
-- Register media stuff early
----------------------------------------------------------------

Media:Register('font', 'Yanone Kaffesatz Bold', "Interface\\Addons\\KiwiPlates\\media\\yanone.ttf" )
Media:Register('font', 'FrancoisOne', "Interface\\Addons\\KiwiPlates\\media\\francois.ttf" )
Media:Register('font', 'Roboto Condensed Bold', "Interface\\Addons\\KiwiPlates\\media\\roboto.ttf" )
Media:Register("font", "Accidental Presidency", "Interface\\Addons\\KiwiPlates\\media\\accid___.ttf" )
Media:Register("statusbar", "Minimalist", "Interface\\Addons\\KiwiPlates\\media\\Minimalist")
Media:Register("statusbar", "Gradient", "Interface\\Addons\\KiwiPlates\\media\\gradient")
Media:Register("statusbar", "Blizzard Solid White", "Interface\\Buttons\\white8x8")
Media:Register("statusbar", "Blizzard NamePlate", "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

----------------------------------------------------------------
-- Utils
----------------------------------------------------------------

local CreateTimer
do
	local function SetPlaying(self, enable)
		if enable then
			self:Play()
		else
			self:Stop()
		end
	end
	CreateTimer = function(delay, func)
		local timer = addon:CreateAnimationGroup()
		timer:CreateAnimation():SetDuration(delay)
		timer:SetLooping("REPEAT")
		timer:SetScript("OnLoop", func)
		if not timer.SetPlaying then
			timer.SetPlaying = SetPlaying
		end
		return timer
	end
end

local function AdjustHealth(h)
	if h<1000 then
		return h,''
	elseif h<1000000 then
		return h/1000,'K'
	else
		return h/1000000,'M'
	end
end

local FormatNameText
do
	local tip = CreateFrame('GameTooltip','KiwiPlatesNameTooltip',UIParent,'GameTooltipTemplate')
	local pattern = strmatch(TOOLTIP_UNIT_LEVEL,'^(.-) ') -- invalid pattern
	local strtrim = strtrim
	local strfind = strfind
	local UnitPVPName = UnitPVPName
	local GetGuildInfo = GetGuildInfo
	local UnitIsOtherPlayersPet = UnitIsOtherPlayersPet
	local NameTags = {}
	local function GetNPCProfession(unit)
        tip:SetOwner(UIParent,ANCHOR_NONE)
        tip:SetUnit(unit)
        local text = cfgTipProfessionLine:GetText()
	    tip:Hide()
		return text and not strfind(text,pattern) and text or ''
    end
	function FormatNameText(UnitFrame, mask)
		local unit = UnitFrame.unit
		NameTags['$n'] = UnitFrame.__name
		NameTags['$c'] = UnitClass(unit) or ''
		if UnitIsPlayer(unit) then
			NameTags['$p'] = ''
			NameTags['$t'] = UnitPVPName(unit)
			NameTags['$g'] = GetGuildInfo(unit) or ''
		else
			NameTags['$g'] = ''
			NameTags['$t'] = UnitFrame.__name
			NameTags['$p'] = UnitIsOtherPlayersPet(unit) and '' or GetNPCProfession(unit)
		end
		return strtrim(gsub(mask,"%$%l",NameTags))
	end
end

----------------------------------------------------------------
-- Table that caches settings for each skin to update widgets
-- colors & values, example:
-- WidgetUpdate[skin] = {
--   -- functions to update widgets texts and statusbars
--   [1] = WidgetMethods.kHealthBar, [2] = WidgetMethods.kLevelTetx, ...
--   -- user defined colors & active widgets
--	 ['kHealthBar'] = customColor1, ['kNameText']  = customColor2, ['ClassificationFrame'] = true, ...
--   -- statuses
--	 methods  = {	['kHealthBar'] = UpdateColorReaction, ['kLevelText'] = UpdateColorCustom, ['kNameText'] = UpdateColorCustom },
--	 reaction = { 'kHealthBar' },
--	 color    = { 'kNameText', 'kLevelText' }, -- color = customColor = statusName
-- }
----------------------------------------------------------------

local WidgetUpdate = {}

----------------------------------------------------------------
-- Statuses color painting management
----------------------------------------------------------------

local ColorStatusDefaults = {
	kHealthBar    = 'reaction',
	kHealthBorder = 'color',
	kHealthText   = 'color',
	kNameText     = 'color',
	kLevelText    = 'level',
}

local ColorDefaults = {
	kHealthBorder = ColorBlack,
	kHealthBar    = ColorWhite,
	kHealthText   = ColorWhite,
	kNameText     = ColorWhite,
	kLevelText    = ColorWhite,
	kAttackers    = ColorWhite,
}

-- Calculate and return the status color for the unit
local ColorMethods = {
	blizzard = function(UnitFrame)
		return ColorTransparent
	end,
	reaction = function(UnitFrame)
		if UnitFrame.__type == "Player" then
			if cfgClassColorReaction[UnitFrame.__reaction] then
				return ClassColors[UnitFrame.__class] or ColorWhite
			elseif UnitFrame.__reaction == 'friendly' then
				return cfgReactionColor.playerfriendly or ColorWhite
			else
				return cfgReactionColor.playerhostile or ColorWhite
			end
		else
			return (UnitFrame.__tapped and cfgReactionColor.tapped) or cfgReactionColor[UnitFrame.__reaction] or ColorWhite
		end
	end,
	health = function(UnitFrame,_,per)
		per = per or UnitHealth(UnitFrame.unit)/UnitHealthMax(UnitFrame.unit)
		return (per>=cfgHealthThreshold1 and cfgHealthColor1) or (per>=cfgHealthThreshold2 and cfgHealthColor2) or cfgHealthColor3 or ColorWhite
	end,
	class = function(UnitFrame)
		return ClassColors[UnitFrame.__class] or ClassColors.UNKNOWN
	end,
	level = function(UnitFrame)
		return DifficultyColor[UnitFrame.__level] or DifficultyColor[-1]
	end,
	color = function(UnitFrame, widgetName)
		return UnitFrame.__update[widgetName] or ColorWhite
	end,
}

local function UpdatePlateColors(UnitFrame)
	local update = UnitFrame.__update
	for widgetName,func in pairs(update.methods) do
		local widget = UnitFrame[widgetName]
		widget:SetWidgetColor( unpack(widget.colorOverride or func(UnitFrame, widgetName)) )
	end
end

local function UpdateWidgetColor(UnitFrame, widgetName)
	local widget = UnitFrame[widgetName]
	widget:SetWidgetColor( unpack( widget.colorOverride or UnitFrame.__update.methods[widgetName](UnitFrame, widgetName) ) )
end

local function UpdateWidgetStatusColor(UnitFrame, statusName)
	local widgets = UnitFrame.__update[statusName]
	local count   = #widgets
	if count>0 then
		local func = ColorMethods[statusName]
		for i=count,1,-1 do
			local widgetName = widgets[i]
			local widget = UnitFrame[widgetName]
			widget:SetWidgetColor( unpack( widget.colorOverride or func(UnitFrame, widgetName) ) )
		end
	end
end

----------------------------------------------------------------
-- Widgets values assignment management
----------------------------------------------------------------

local WidgetMethods = {
	kHealthBar = addon.Dummy, -- no update needed because we are using blizzard health bar
	kHealthText = function(UnitFrame)
		local h,m
		local unit = UnitFrame.unit
		if RealMobHealth then
			h,m = RealMobHealth(unit)
		else
			h = UnitHealth(unit)
			m = UnitHealthMax(unit)
		end
		local p = h/m
		local mask = UnitFrame.__skin.healthMaskValue -- mask = something like "$h/$m|$p%"
		if mask then
			HealthTags['$p'] = format("%d",p*100)
			HealthTags['$h'] = (h<1000 and h) or (h<1000000 and format("%.1fK",h/1000)) or format("%.1fM",h/1000000)
			HealthTags['$m'] = (m<1000 and m) or (m<1000000 and format("%.1fK",m/1000)) or format("%.1fM",m/1000000)
			UnitFrame.kHealthText:SetText( gsub(mask,"%$%l",HealthTags) )
		else
			UnitFrame.kHealthText:SetFormattedText( '%.0f%%',p*100 )
		end
	end,
	kNameText = function(UnitFrame)
		local mask = UnitFrame.__skin.nameFormat
		UnitFrame.kNameText:SetText( mask and FormatNameText(UnitFrame, mask) or UnitFrame.__name )
	end,
	kLevelText = function(UnitFrame)
		local level = UnitFrame.__level
		local class = UnitFrame.__classification
		local text  = level<0 and '??' or level .. (Classifications[class] or '')
		UnitFrame.kLevelText:SetText( text )
	end,
	kIcon = function(UnitFrame)
		local skin = UnitFrame.__skin
		if not skin.classIconUserTexture then
			local key
			if cfgTestSkin then
				key = UnitFrame.__type=='Player' and UnitFrame.__class or 'elite'
			else
				if UnitFrame.__type=='Player' then
					if not skin.classIconDisablePlayers then
						key = UnitFrame.__class
					end
				elseif not skin.classIconDisableNPCs then
					key = UnitFrame.__classification
				end
			end
			UnitFrame.kIcon:SetTexCoord( unpack(ClassTexturesCoord[key] or CoordEmpty) )
		end
	end,
	kAttackers = function(UnitFrame)
		local kAttackers = UnitFrame.kAttackers
		local mask = cfgTestSkin and 28 or UnitFrame.__attackers
		local w = band(mask,7)
		local h = rshift(mask,3) * (20/128)
		kAttackers:SetTexCoord( 0, w*(20/128), h, h+(20/128) )
		kAttackers:SetWidth( w * (UnitFrame.__skin.attackersIconSize or 14) )
	end,
}

function UpdatePlateValues(UnitFrame)
	local widgets = UnitFrame.__update
	for i=#widgets,1,-1 do
		widgets[i](UnitFrame)
	end
end

----------------------------------------------------------------
-- Health update for health text widget & health status
----------------------------------------------------------------
local HealthFrame
do
	local UpdateText = WidgetMethods.kHealthText
	local UpdateColorHealth = ColorMethods.health
	local UpdateColorReaction = ColorMethods.reaction
	HealthFrame = CreateFrame("Frame")
	HealthFrame:SetScript("OnEvent", function(_, _, unit)
		local UnitFrame = NamePlatesByUnit[unit]
		if UnitFrame then
			local update, percent = UnitFrame.__update
			if UnitFrame.kHealthText then
				percent = UpdateText(UnitFrame)
			end
			local widgets = update.health
			if #widgets>0 then
				local color = UpdateColorHealth(UnitFrame,nil,percent)
				for i=1,#widgets do
					local widget = UnitFrame[widgets[i]]
					widget:SetWidgetColor( unpack( widget.colorOverride or color ) )
				end
			end
			local widgets = update.reaction
			if #widgets>0 then
				local tapped = UnitIsTapDenied(unit)
				if tapped ~= UnitFrame.__tapped then
					UnitFrame.__tapped = tapped
					local color = UpdateColorReaction(UnitFrame)
					for i=1,#widgets do
						local widget = UnitFrame[widgets[i]]
						widget:SetWidgetColor( unpack( widget.colorOverride or color ) )
					end
				end
			end
		end
	end )
end

----------------------------------------------------------------
-- Disable blizzard stuff
----------------------------------------------------------------

local function DisableBlizzardStuff(UnitFrame)
	local healthBar = UnitFrame.healthBar
	healthBar.barTexture:SetColorTexture(0,0,0,0)
	if isClassic then
		local level = healthBar:GetFrameLevel()+1
		UnitFrame.RaidTargetFrame:SetFrameLevel(level)
		UnitFrame.LevelFrame:Hide()
		if not cfgClassicBorders then healthBar.border:Hide() end
	else
		local textures = healthBar.border.Textures
		for i=#textures,1,-1 do
			textures[i]:SetVertexColor(0,0,0,0)
			textures[i]:SetColorTexture(0,0,0,0)
			textures[i]:Hide()
		end
		local level = UnitFrame.castBar:GetFrameLevel()+1
		UnitFrame.RaidTargetFrame:SetFrameLevel(level)
		UnitFrame.ClassificationFrame:Hide()
	end
end

----------------------------------------------------------------
-- kHealthBar widget creation
----------------------------------------------------------------

local function CreateHealthBar(UnitFrame)
	local healthBar = UnitFrame.healthBar
	local layer, level = healthBar.barTexture:GetDrawLayer()
	local kHealthBar = healthBar:CreateTexture(nil, layer, nil, level+1)
	kHealthBar:SetPoint("TOPLEFT", healthBar.barTexture, "TOPLEFT")
	kHealthBar:SetPoint("BOTTOMRIGHT", healthBar.barTexture, "BOTTOMRIGHT")
	kHealthBar.SetWidgetColor = kHealthBar.SetVertexColor
	UnitFrame.kkHealthBar = kHealthBar
end

----------------------------------------------------------------
-- kHealthBorder widget creation
----------------------------------------------------------------

local function CreateHealthBorderClassic(UnitFrame)
	local healthBar = UnitFrame.healthBar
	local layer = healthBar.barTexture:GetDrawLayer()
	local border = isClassic and healthBar.border:GetRegions() or healthBar.border:CreateTexture()
	border.widgetName = 'kHealthBorder'
	border:SetTexCoord(0, 1, 0, 1)
	border:SetDrawLayer( layer, 7 )
	border:SetParent(healthBar)
	border.SetWidgetColor = border.SetVertexColor
	UnitFrame.kkHealthBorder = border
	return border
end

local CreateHealthBorderRetail
do
	local BORDER_POINTS = {
		{ "TOPRIGHT",    "TOPLEFT",    0, 1, "BOTTOMRIGHT", "BOTTOMLEFT",  0, -1, "SetWidth" },
		{ "TOPLEFT",     "TOPRIGHT",   0, 1, "BOTTOMLEFT",  "BOTTOMRIGHT", 0, -1, "SetWidth" },
		{ "TOPRIGHT",    "BOTTOMLEFT", 0, 0, "TOPLEFT",     "BOTTOMRIGHT", 0, 0 , "SetHeight" },
		{ "BOTTOMRIGHT", "TOPRIGHT",   0, 0, "BOTTOMLEFT",  "TOPLEFT",     0, 0 , "SetHeight" },
	}

	local function SetBorderColor(border,r,g,b,a)
		border[1]:SetVertexColor(r,g,b,a)
		border[2]:SetVertexColor(r,g,b,a)
		border[3]:SetVertexColor(r,g,b,a)
		border[4]:SetVertexColor(r,g,b,a)
	end

	local function SetBorderSize(border,size)
		if border.size ~= size then
			local frame = border[1]:GetParent()
			for i=1,4 do
				local p = BORDER_POINTS[i]
				local t = border[i]
				t:ClearAllPoints()
				t:SetPoint( p[1], frame, p[2], p[3]*size, p[4]*size )
				t:SetPoint( p[5], frame, p[6], p[7]*size, p[8]*size )
				t[ p[9] ](t, size)
			end
			border.size = size
		end
	end

	local function Hide(border)
		SetBorderColor(border,0,0,0,0)
	end

	function CreateHealthBorderRetail(UnitFrame)
		local frame = UnitFrame.healthBar
		local border = { widgetName= 'kHealthBorder', size=1 }
		for i=1,4 do
			local p = BORDER_POINTS[i]
			local t = frame:CreateTexture(nil, "BACKGROUND")
			t:SetPoint( p[1], frame, p[2], p[3], p[4] )
			t:SetPoint( p[5], frame, p[6], p[7], p[8] )
			t[ p[9] ](t,1)
			t:SetColorTexture(1,1,1,1)
			border[i] = t
		end
		border.SetWidgetColor = SetBorderColor
		border.SetWidgetSize  = SetBorderSize
		border.Hide = Hide
		UnitFrame.kkHealthBorder = border
		return border
	end
end

local function CreateHealthBorder(UnitFrame)
	if cfgClassicBorders then
		CreateHealthBorderClassic(UnitFrame)
	else
		CreateHealthBorderRetail(UnitFrame)
	end
end

----------------------------------------------------------------
-- kCastBar widget creation
----------------------------------------------------------------

local function CreateCastBar(UnitFrame)
	local castBar = UnitFrame.castBar
	if castBar then -- retail
		if cfgClassicBorders then
			castBar.Border = castBar:CreateTexture(nil, 'ARTWORK')
		end
	else -- classic
		castBar = CreateFrame("StatusBar", nil, UnitFrame, "KiwiPlatesCastingBarFrameTemplate")
		castBar:SetPoint("TOPLEFT",  UnitFrame, "BOTTOMLEFT",  0, 0)
		castBar:SetPoint("TOPRIGHT", UnitFrame, "BOTTOMRIGHT", 0, 0)
	end
	if cfgClassicBorders then
		castBar.Border:SetDrawLayer('ARTWORK',7)
	end
	UnitFrame.kkCastBar = castBar
end

----------------------------------------------------------------
-- kLevelText widget creation
----------------------------------------------------------------

local function CreateLevelText(UnitFrame)
	local text  = UnitFrame.RaidTargetFrame:CreateFontString(nil, "BORDER")
	text.SetWidgetColor = text.SetTextColor
	text:SetShadowOffset(1,-1)
	text:SetShadowColor(0,0,0, 1)
	UnitFrame.kkLevelText = text
end

----------------------------------------------------------------
-- kNameText widget creation
----------------------------------------------------------------

local function CreateNameText(UnitFrame)
	local text = UnitFrame.RaidTargetFrame:CreateFontString(nil, "BORDER")
	text.SetWidgetColor = text.SetTextColor
	text:SetShadowOffset(1,-1)
	text:SetShadowColor(0,0,0, 1)
	UnitFrame.kkNameText = text
	UnitFrame.name:SetParent(HiddenFrame)
end

----------------------------------------------------------------
-- kHealthText widget creation
----------------------------------------------------------------

local function CreateHealthText(UnitFrame)
	local text = UnitFrame.RaidTargetFrame:CreateFontString(nil, "BORDER")
	text.SetWidgetColor = text.SetTextColor
	text:SetShadowOffset(1,-1)
	text:SetShadowColor(0,0,0, 1)
	UnitFrame.kkHealthText = text
end

----------------------------------------------------------------
-- kIcon widget creation
----------------------------------------------------------------

local function CreateIcon(UnitFrame)
	local icon = UnitFrame.RaidTargetFrame:CreateTexture()
	UnitFrame.kkIcon = icon
end

----------------------------------------------------------------
-- kAttackers widget creation
----------------------------------------------------------------

local function CreateAttackers(UnitFrame)
	local RaidTargetFrame = UnitFrame.RaidTargetFrame
	local kAttackers = RaidTargetFrame:CreateTexture()
	kAttackers:SetTexture("Interface\\Addons\\KiwiPlates\\media\\roles")
	kAttackers:SetTexCoord( 0,0,0,0 )
	UnitFrame.kkAttackers= kAttackers
end

----------------------------------------------------------------
-- Skin a nameplate
----------------------------------------------------------------

local SkinPlate
do
	local SkinMethods = {
		kCastBar = function(UnitFrame, frameAnchor, db, enabled)
			if enabled then
				local castBar = UnitFrame.kkCastBar
				local cbHeight = db.castBarHeight or 10
				castBar.BorderShield:SetSize(cbHeight, cbHeight)
				castBar.Icon:ClearAllPoints()
				castBar.Icon:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMLEFT", db.castBarIconOffsetX or -1, db.castBarIconOffsetY or 0)
				castBar.Icon:SetSize(db.castBarIconSize or cbHeight, db.castBarIconSize or cbHeight)
				castBar.Icon:SetShown(db.castBarIconEnabled)
				castBar:SetStatusBarTexture( TexCache[db.castBarTexture] )
				castBar.Text:SetFont( FontCache[db.castBarFontFile or 'Roboto Condensed Bold'], db.castBarFontSize or 8, db.castBarFontFlags or 'OUTLINE' )
				if cfgClassicBorders then
					SetBorderTexture( castBar, castBar.Border, db.castBarBorderTexture, db.castBarBorderColor or ColorWhite )
				else
					castBar.Icon:SetTexCoord( 0.1, 0.9, 0.1, 0.9 )
				end
				UnitFrame.kCastBar = castBar
			else
				UnitFrame.kCastBar = nil
			end
		end,
		kHealthBar = function(UnitFrame, frameAnchor, db, enabled)
			local kHealthBar = UnitFrame.kkHealthBar
			local healthBar = UnitFrame.healthBar
			if enabled then
				UnitFrame.kHealthBar = kHealthBar
				if db.kHealthBar_color_status~='blizzard' then
					healthBar.barTexture:SetColorTexture(0,0,0,0)
					kHealthBar:SetTexture( TexCache[db.healthBarTexture] )
					kHealthBar:Show()
				else
					healthBar.barTexture:SetTexture( TexCache[db.healthBarTexture] )
					kHealthBar:Hide()

				end
			elseif kHealthBar then
				UnitFrame.kHealthBar = nil
				healthBar:Hide()
				kHealthBar:Hide()
			end
		end,
		kHealthBorder = function(UnitFrame, frameAnchor, db, enabled)
			local kHealthBorder = UnitFrame.kkHealthBorder
			if enabled then
				if cfgClassicBorders then
					SetBorderTexture(UnitFrame.healthBar, kHealthBorder, db.borderTexture )
					kHealthBorder:Show()
					UnitFrame.kHealthBorder = kHealthBorder
				else
					kHealthBorder:SetWidgetSize( db.borderSize or 1 )
					UnitFrame.kHealthBorder = kHealthBorder
				end
			elseif kHealthBorder then
				UnitFrame.kHealthBorder = nil
				kHealthBorder:Hide()
			end
		end,
		kNameText = function(UnitFrame, frameAnchor, db, enabled)
			local kNameText = UnitFrame.kkNameText
			if enabled then
				kNameText:SetPoint("BOTTOM", frameAnchor, "TOP", db.nameOffsetX or 0, db.nameOffsetY or -1);
				kNameText:SetFont( FontCache[db.nameFontFile or 'Roboto Condensed Bold'], db.nameFontSize or 12, db.nameFontFlags or 'OUTLINE' )
				UnitFrame.kNameText = kNameText
				UnitFrame.kNameText:SetWordWrap(db.nameFormat~=nil)
				kNameText:Show()
			elseif kNameText then
				UnitFrame.kNameText = nil
				kNameText:Hide()
			end
		end,
		kLevelText = function(UnitFrame, frameAnchor, db, enabled)
			local kLevelText = UnitFrame.kkLevelText
			if enabled then
				kLevelText:ClearAllPoints()
				kLevelText:SetPoint( db.levelAnchorPoint or "LEFT", frameAnchor, "CENTER", db.levelOffsetX or -62, db.levelOffsetY or -4);
				kLevelText:SetFont( FontCache[db.levelFontFile or 'Accidental Presidency'], db.levelFontSize or 14, db.levelFontFlags or 'OUTLINE' )
				UnitFrame.kLevelText = kLevelText
				kLevelText:Show()
			elseif kLevelText then
				UnitFrame.kLevelText = nil
				kLevelText:Hide()
			end
		end,
		kHealthText = function(UnitFrame, frameAnchor, db, enabled)
			local kHealthText = UnitFrame.kkHealthText
			if enabled then
				kHealthText:ClearAllPoints()
				kHealthText:SetPoint( db.healthTextAnchorPoint or 'RIGHT', frameAnchor, 'CENTER', db.healthTextOffsetX or 66, db.healthTextOffsetY or -4)
				kHealthText:SetFont( FontCache[db.healthTextFontFile or 'Accidental Presidency'], db.healthTextFontSize or 14, db.healthTextFontFlags or 'OUTLINE' )
				UnitFrame.kHealthText = kHealthText
				kHealthText:Show()
			elseif kHealthText then
				UnitFrame.kHealthText = nil
				kHealthText:Hide()
			end
		end,
		kAttackers = function(UnitFrame, frameAnchor, db, enabled)
			local kAttackers = UnitFrame.kkAttackers
			if enabled then
				local size = db.attackersIconSize or 14
				kAttackers:ClearAllPoints()
				kAttackers:SetSize( bit.band(UnitFrame.__attackers or 0, 7) * size , size )
				kAttackers:SetPoint( db.attackersAnchorPoint or 'CENTER', frameAnchor, 'CENTER', db.attackersOffsetX or 0, db.attackersOffsetY or 0)
				kAttackers:Show()
				UnitFrame.kAttackers = kAttackers
			elseif kAttackers then
				UnitFrame.kAttackers = nil
				kAttackers:Hide()
			end
		end,
		kIcon = function(UnitFrame, frameAnchor, db, enabled)
			local kIcon = UnitFrame.kkIcon
			if enabled then
				kIcon:ClearAllPoints()
				kIcon:SetSize( db.classIconSize or 14, db.classIconSize or 14 )
				kIcon:SetPoint('RIGHT', frameAnchor, 'LEFT', db.classIconOffsetX or 0, db.classIconOffsetY or 0)
				if db.classIconUserTexture then
					kIcon:SetTexture(db.classIconUserTexture)
					kIcon:SetTexCoord(0,1,0,1)
				else
					kIcon:SetTexture(db.classIconTexture or 'Interface\\Addons\\KiwiPlates\\media\\classif')
					kIcon:SetTexCoord(0,0,0,0)
				end
				UnitFrame.kIcon = kIcon
				kIcon:Show()
			elseif kIcon then
				UnitFrame.kIcon = nil
				kIcon:Hide()
			end
		end,
		RaidTargetFrame = function(UnitFrame, frameAnchor, db, enabled)
			local RaidTargetFrame = UnitFrame.RaidTargetFrame
			if enabled then
				RaidTargetFrame.RaidTargetIcon:SetParent(RaidTargetFrame)
				RaidTargetFrame:SetPoint("RIGHT", frameAnchor, "LEFT", db.raidTargetOffsetX or 154, db.raidTargetOffsetY or 0);
				RaidTargetFrame:SetSize( db.raidTargetSize or 20, db.raidTargetSize or 20 )
				RaidTargetFrame:Show()
			else
				RaidTargetFrame.RaidTargetIcon:SetParent(HiddenFrame) -- we cannot simply Hide() this frame because our widgets are parented to it
			end
		end,
	}

	function SkinPlate(plateFrame, UnitFrame, UnitAdded)
		-- calculate skin
		local db = addon.db.skins[ GetPlateSkin(UnitFrame, InCombat, InstanceType) ]
		-- opacity & frame level
		local target = UnitFrame.__target
		local mouse =  UnitFrame.__mouseover
		UnitFrame:SetFrameStrata( (target or mouse) and "HIGH" or "MEDIUM" )
		UnitFrame:SetAlpha( (mouse and 1) or (target and cfgAlpha1) or (not targetExists and cfgAlpha3) or cfgAlpha2 )
		local Reskin = (db ~= UnitFrame.__skin)
		if Reskin or UnitAdded then -- blizzard code resets these settings, so we need to reapply them even if our skin has not changed.
			-- UnitFrame
			UnitFrame:ClearAllPoints()
			UnitFrame:SetPoint( 'TOP', plateFrame, 'TOP', 0, 0 )
			UnitFrame:SetPoint( 'BOTTOM', plateFrame, 'BOTTOM', 0, db.plateOffsetY or 6 )
			UnitFrame:SetWidth( (db.healthBarWidth or 136)  + cfgPlatesAdjustW )
			-- healthBar
			local healthBar = UnitFrame.healthBar
			local anchorFrame = UnitFrame.castBar or UnitFrame
			local gap = db.castBarGap or (isClassic and 0) or nil
			if gap ~= UnitFrame.castBarGap then
				-- in classic we execute this code if gap is not defined to reanchor healthBar the "(isClassic and 0)" above forces to execute this code
				-- in retail is not necessary because healthBar is already anchored to castBar with "correct" point values
				healthBar:ClearAllPoints()
				healthBar:SetPoint('BOTTOMLEFT', anchorFrame, 'BOTTOMLEFT',  0,  gap or 0 )
				healthBar:SetPoint('BOTTOMRIGHT',anchorFrame, 'BOTTOMRIGHT', 0,  gap or 0 )
				UnitFrame.castBarGap = gap
			end
			healthBar:SetShown( db.kHealthBar_enabled )
			healthBar:SetHeight( db.healthBarHeight or 12 )
			-- castBar
			local castBar = UnitFrame.kkCastBar
			if castBar then
				castBar:SetHeight( db.castBarHeight or 10 )	-- SetHeight() is called for disabled castBars, wrong but necessary in retail because healthbar is anchored to the castbar
				if not isClassic then
					castBar.Text:SetFont( FontCache[db.castBarFontFile or 'Roboto Condensed Bold'], db.castBarFontSize or 8, db.castBarFontFlags or 'OUTLINE' )
				end
				if db.kCastBar_enabled and not ((UnitFrame.__reaction=='friendly')==db.castBarHiddenFriendly) then
					CastingBarFrame_SetUnit(castBar, UnitFrame.unit, false, true)
				else
					CastingBarFrame_SetUnit(castBar, nil)
				end
			end
		end
		if Reskin then
			local update = WidgetUpdate[db]
			-- save skin & update stuff
			UnitFrame.__skin = db
			UnitFrame.__update = update
			-- skin widgets
			local frameAnchor = UnitFrame.healthBar
			for i=1,#WidgetNames do
				local widgetName = WidgetNames[i]
				SkinMethods[widgetName]( UnitFrame, frameAnchor, db, update[widgetName] )
			end
			-- update widgets values & color
			UpdatePlateValues(UnitFrame)
			UpdatePlateColors(UnitFrame)
			-- notify that a plate has been skinned to other modules
			addon:SendMessage('PLATE_SKINNED',UnitFrame, db)
			return true
		elseif UnitAdded then
			-- update widgets values & color
			UpdatePlateValues(UnitFrame)
			UpdatePlateColors(UnitFrame)
		end
	end

end

----------------------------------------------------------------
-- Fix Unknown entities in plate names
----------------------------------------------------------------

function addon:UNIT_NAME_UPDATE(unit)
	local UnitFrame = NamePlatesByUnit[unit]
	if UnitFrame then
		local name = UnitName(unit)
		UnitFrame.__name = name
		local text = UnitFrame.kNameText
		if text then
			text:SetText(name)
		end
		if ConditionFields.names then
			SkinPlate( C_GetNamePlateForUnit(unit), UnitFrame )
		end
	end
end

----------------------------------------------------------------
-- Reskin visible nameplates
----------------------------------------------------------------

local function ReskinPlates()
	for plateFrame, UnitFrame in pairs(NamePlates) do
		SkinPlate(plateFrame, UnitFrame)
	end
end

----------------------------------------------------------------
-- Highlights nameplate
----------------------------------------------------------------

local function HighlightSet(UnitFrame)
	if UnitFrame then
		if UnitFrame.kHealthBar then
			HighlightTex:ClearAllPoints()
			HighlightTex:SetParent(UnitFrame.healthBar)
			HighlightTex:SetAllPoints()
		end
	else
		HighlightTex:SetParent(HiddenFrame)
	end
end

----------------------------------------------------------------
-- Units Combat Status tracking (not player in combat)
----------------------------------------------------------------

local function UpdatePlatesUnitCombatValues()
	for plateFrame, UnitFrame in pairs(NamePlates) do
		UnitFrame.__combat = UnitAffectingCombat(UnitFrame.unit) or UnitIsFriend(target[UnitFrame.unit],'player')
	end
end

local UpdateCombatTracking
do
	local timer = CreateTimer(.25, function()
		for plateFrame, UnitFrame in pairs(NamePlates) do
			local combat = UnitAffectingCombat(UnitFrame.unit) or UnitIsFriend(target[UnitFrame.unit],'player')
			if combat ~= UnitFrame.__combat then
				UnitFrame.__combat = combat
				SkinPlate(plateFrame, UnitFrame)
			end
		end
	end	)
	function UpdateCombatTracking(enabled)
		timer:SetPlaying(not not enabled)
	end
end

----------------------------------------------------------------
-- Attackers widget update
----------------------------------------------------------------

local UpdateAttackersTracking
do
	local masks = {}
	local bits  = { TANK = 8, HEALER = 16 }
	local units = { 'party1', 'party2', 'party3','party4', party1 = 'party1target', party2 = 'party2target', party3 = 'party3target', party4 = 'party4target' }
	local timer = CreateTimer(.2, function()
		if IsInRaid() then return end
		wipe(masks)
		for i=GetNumSubgroupMembers(),1,-1 do
			local unit = units[i]
			local guid = UnitGUID( units[unit] ) -- target guid
			if guid and NamePlatesByGUID[guid] then
				local role = UnitGroupRolesAssigned(unit)
				local mask = masks[guid] or 0
				local bit  = bits[role]
				masks[guid] = bit and (bor(mask,bit)+1) or (mask+1)
			end
		end
		local Update = WidgetMethods.kAttackers
		for plateFrame, UnitFrame in pairs(NamePlates) do
			local kAttackers = UnitFrame.kAttackers
			if kAttackers then
				local mask = masks[UnitFrame.__guid] or 0
				if mask~=UnitFrame.__attackers then
					UnitFrame.__attackers = mask
					Update(UnitFrame)
				end
			end
		end
	end )
	function UpdateAttackersTracking(enabled)
		if not enabled ~= not timer:IsPlaying() then
			timer:SetPlaying(not not enabled)
			if not enabled then
				for plateFrame, UnitFrame in pairs(NamePlates) do
					UnitFrame.__attackers = 0
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Mouseover management
----------------------------------------------------------------

do
	local timer
	timer = CreateTimer(.2, function()
		if not (mouseFrame and (not mouseFrame.UnitFrame or UnitIsUnit('mouseover', mouseFrame.UnitFrame.unit)) ) then
			timer:Stop()
			addon:UPDATE_MOUSEOVER_UNIT()
		end
	end )
	function addon:UPDATE_MOUSEOVER_UNIT()
		local plateFrame = C_GetNamePlateForUnit('mouseover')
		if plateFrame~=mouseFrame then
			if mouseFrame then
				local UnitFrame = mouseFrame.UnitFrame
				if UnitFrame then
					UnitFrame.__mouseover = nil
					SkinPlate(mouseFrame, UnitFrame)
					mouseFrame = nil
					HighlightSet(nil)
					timer:Stop()
				end
			end
			if plateFrame and NamePlates[plateFrame] then
				local UnitFrame = plateFrame.UnitFrame
				if UnitFrame then
					UnitFrame.__mouseover = true
					mouseFrame = plateFrame
					SkinPlate(mouseFrame, UnitFrame)
					HighlightSet(UnitFrame)
					timer:Play()
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Opacity adjust
----------------------------------------------------------------

local function UpdatePlatesOpacity()
	local alpha = targetExists and cfgAlpha2 or cfgAlpha3
	for plateFrame, UnitFrame in pairs(NamePlates) do
		if plateFrame~=targetFrame and plateFrame~=mouseFrame then
			UnitFrame:SetAlpha( alpha )
		end
	end
end

----------------------------------------------------------------
-- Personal resource bar
----------------------------------------------------------------

local function PersonalBarAdded(plateFrame)
	-- undo some custom changes to avoid displaying a messed personal bar
	local UnitFrame = plateFrame.UnitFrame
	UnitFrame.healthBar.barTexture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
	for i=1,#WidgetNames do
		local widget = UnitFrame[WidgetNames[i]]
		if widget then widget:Hide() end
	end
	UnitFrame.__skin = nil
end

local function PersonalBarRemoved(plateFrame)
	-- redo our custom changes once the personal resource bar is hidden
	local UnitFrame = plateFrame.UnitFrame
	if UnitFrame then
		UnitFrame.healthBar.barTexture:SetColorTexture(0,0,0,0)
	end
end

----------------------------------------------------------------
-- Player target management
----------------------------------------------------------------

function addon:PLAYER_TARGET_CHANGED()
	local plateFrame = C_GetNamePlateForUnit('target')
	if plateFrame ~= targetFrame then
		if targetFrame then
			local UnitFrame = targetFrame.UnitFrame
			if UnitFrame then
				UnitFrame.__target = nil
				SkinPlate(targetFrame, UnitFrame)
				targetFrame = nil
			end
		end
		if plateFrame and NamePlates[plateFrame] then
			local UnitFrame = plateFrame.UnitFrame
			if UnitFrame then
				UnitFrame.__target = true
				SkinPlate(plateFrame, UnitFrame)
				targetFrame = plateFrame
				self:SendMessage('PLAYER_TARGET_ACQUIRED', plateFrame, 'target' )
			end
		end
	end
	if targetExists ~= UnitExists('target') then
		targetExists = not targetExists
		if cfgAdjustAlpha then
			UpdatePlatesOpacity()
		end
	end
	self:SendMessage('PLAYER_TARGET_CHANGED', plateFrame)
end

----------------------------------------------------------------
-- Fix Health Bar height because game changes the user defined value
----------------------------------------------------------------

local fix_health_stop = false
local function FixHealthBarSize(bar, w, h)
	if not fix_health_stop and bar.UnitFrame then
		local db = bar.UnitFrame.__skin
		if db then
			local j = db.healthBarHeight or 12
			local d = j - h
			if d > 0.5 or d < -0.5 then
				fix_health_stop = true
				bar:SetHeight(j)
				fix_health_stop = false
			end
		end
	end
end

---------------------------------------------------------------
-- Nameplate created event
----------------------------------------------------------------

local CreateNamePlate
do
	local CreateMethods = {
		kCastBar      = CreateCastBar,
		kHealthBar    = CreateHealthBar,
		kHealthBorder = CreateHealthBorder,
		kHealthText   = CreateHealthText,
		kLevelText    = CreateLevelText,
		kNameText     = CreateNameText,
		kIcon         = CreateIcon,
		kAttackers    = CreateAttackers,
	}
	function CreateNamePlate(UnitFrame)
		for i=1,#activeWidgets do
			local widgetName = activeWidgets[i]
			if not UnitFrame[WidgetNames[widgetName]] then
				CreateMethods[widgetName](UnitFrame)
			end
		end
		UnitFrame.healthBar:SetScript('OnSizeChanged', FixHealthBarSize) -- see FixHealthBarSize()
		UnitFrame.__skin = nil
	end
	function addon:NAME_PLATE_CREATED(plateFrame)
		local UnitFrame = plateFrame.UnitFrame
		if not UnitFrame.__kInitialized then
			UnitFrame.__kInitialized = true
			DisableBlizzardStuff(UnitFrame)
			CreateNamePlate(UnitFrame)
			NamePlatesAll[#NamePlatesAll+1] = UnitFrame
			self:SendMessage("NAME_PLATE_CREATED", UnitFrame, plateFrame)
		end
	end
end

---------------------------------------------------------------
-- Nameplate added event
----------------------------------------------------------------

function addon:NAME_PLATE_UNIT_ADDED(unit)
	local plateFrame = C_GetNamePlateForUnit(unit)
	if UnitIsUnit(unit,'player') then return PersonalBarAdded(plateFrame) end
	if plateFrame then
		if isRetail then self:NAME_PLATE_CREATED(plateFrame) end
		local guid = UnitGUID(unit)
		local UnitFrame = plateFrame.UnitFrame
		NamePlates[plateFrame] = UnitFrame
		NamePlatesByUnit[unit] = UnitFrame
		NamePlatesByGUID[guid] = UnitFrame
		UnitFrame:SetParent(WorldFrame)
		UnitFrame:SetScale(pixelScale)
		UnitFrame.__guid   = guid
		UnitFrame.__class  = select(2,UnitClass(unit))
		UnitFrame.__type   = Types[ strsub( guid, 3,3 ) ]
		UnitFrame.__reaction = Reactions [ UnitReaction( unit, "player") or 1 ]
		UnitFrame.__level  = UnitLevel( unit )
		UnitFrame.__classification = UnitClassification(unit) or 'unknow'
		UnitFrame.__combat = UnitAffectingCombat(unit) or UnitIsFriend(target[unit],'player')
		UnitFrame.__tapped = UnitIsTapDenied(unit)
		UnitFrame.__attackable = UnitCanAttack('player',unit)
		UnitFrame.__attackers = 0
		if UnitFrame.__level==-1 or UnitFrame.__classification=='worldboss' then
			UnitFrame.__classification = 'boss'
		end
		UnitFrame.__name = UnitName( unit )
		UnitFrame.__target = UnitIsUnit( unit, 'target' ) or nil
		if UnitFrame.__target then
			if targetFrame and targetFrame.UnitFrame then -- unmark&reskin old target frame
				targetFrame.UnitFrame.__target = nil
				SkinPlate(targetFrame, targetFrame.UnitFrame)
			end
			targetFrame = plateFrame
		end
		SkinPlate( plateFrame, UnitFrame, true )
		UnitFrame.healthBar.UnitFrame = UnitFrame -- see FixHealthBarSize()
		self:SendMessage("NAME_PLATE_UNIT_ADDED", UnitFrame, unit)
	end
end

----------------------------------------------------------------
-- Nameplate removed event
----------------------------------------------------------------

function addon:NAME_PLATE_UNIT_REMOVED(unit)
	local plateFrame = C_GetNamePlateForUnit(unit)
	if UnitIsUnit(unit,'player') then return PersonalBarRemoved(plateFrame) end
	local UnitFrame = plateFrame.UnitFrame or NamePlates[plateFrame]
	if UnitFrame then
		UnitFrame.healthBar.UnitFrame = nil -- see FixHealthBarSize()
		UnitFrame.__threat = nil
		UnitFrame.__target = nil
		UnitFrame.__mouseover = nil
		if plateFrame == targetFrame then
			targetFrame = nil
		end
		if plateFrame == mouseFrame then
			mouseFrame = nil
		end
		if isClassic and UnitFrame.kCastBar then
			CastingBarFrame_SetUnit(UnitFrame.kCastBar, nil)
		end
		UnitFrame:SetParent(plateFrame)
		UnitFrame:SetScale(1)
		UnitFrame:ClearAllPoints()
		UnitFrame:SetAllPoints()
		NamePlates[plateFrame] = nil
		NamePlatesByUnit[unit] = nil
		NamePlatesByGUID[UnitFrame.__guid or 0] = nil
		self:SendMessage("NAME_PLATE_UNIT_REMOVED", UnitFrame, unit)
	end
end

----------------------------------------------------------------
-- Events triggering reaction/attackable stuff update
----------------------------------------------------------------

function addon:UNIT_FLAGS(unit)
	local UnitFrame = NamePlatesByUnit[unit]
	if UnitFrame then
		local reaction   = Reactions [ UnitReaction( unit, "player") or 1 ]
		local attackable = UnitCanAttack('player',unit)
		if reaction~=UnitFrame.__reaction or attackable~=UnitFrame.__attackable then
			local reskinned
			UnitFrame.__reaction = reaction
			UnitFrame.__attackable = attackable
			if ConditionFields['@attackable'] or ConditionFields['@reaction'] then
				reskinned = SkinPlate( C_GetNamePlateForUnit(unit), UnitFrame )
			end
			if not reskinned and activeStatuses.reaction then
				UpdateWidgetStatusColor(UnitFrame, 'reaction')
			end
		end
	end
end
addon.UNIT_TARGETABLE_CHANGED = UNIT_FLAGS
addon.UNIT_FACTION = UNIT_FLAGS

----------------------------------------------------------------
-- Events triggering level/classification stuff update
----------------------------------------------------------------

function addon:UNIT_CLASSIFICATION_CHANGED(unit)
	local UnitFrame = NamePlatesByUnit[unit]
	if UnitFrame then
		local reskinned
		UnitFrame.__level = UnitLevel( unit )
		UnitFrame.__classification = UnitClassification(unit) or 'unknow'
		if ConditionFields['@classification'] then
			reskinned = SkinPlate( C_GetNamePlateForUnit(unit), UnitFrame )
		end
		if not reskinned and UnitFrame.kLevelText then
			WidgetMethods.kLevelText(UnitFrame)
		end
	end
end

----------------------------------------------------------------
--kAttackers
----------------------------------------------------------------

function addon:GROUP_ROSTER_UPDATE()
	local group = not IsInRaid() and GetNumSubgroupMembers()>0
	if group ~= InGroup then
		InGroup = group
		UpdateAttackersTracking(InCombat and InGroup)
	end
end

----------------------------------------------------------------
-- Combat switch reskin
----------------------------------------------------------------

local function CombatReskinCheck(delay)
	if delay then
		-- We need to add a delay because some times UnitAffectingCombat() does not return correct values just after combat start.
		C_Timer.After(.05, CombatReskinCheck)
		return
	end
	local reskin = ConditionFields['@combat']
	if reskin then
		UpdatePlatesUnitCombatValues()
	else
		reskin = ConditionFields['combat']
	end
	if reskin then
		ReskinPlates()
	end
end

----------------------------------------------------------------
-- Combat Visibility
----------------------------------------------------------------

local function UpdateVisibility()
	if not InCombatLockdown() then
		local value = addon.db.general.nameplateShowFriends or 0
		if value>=2 then
			if value<=3 then
				value = InCombat == (value==2)
			else
				value = not IsInInstance() == (value==5)
			end
			value = value and "1" or "0"
			if GetCVar("nameplateShowFriends")~=value then
				SetCVar("nameplateShowFriends", value)
			end
		end
		local value = addon.db.general.nameplateShowEnemies or 0
		if value>=2 then
			if value<=3 then
				value = InCombat == (value==2)
			else
				value = not IsInInstance() == (value==5)
			end
			value = value and "1" or "0"
			if GetCVar("nameplateShowEnemies")~=value then
				SetCVar("nameplateShowEnemies", value)
			end
		end
	end
end

----------------------------------------------------------------
-- Combat Start
----------------------------------------------------------------

function addon:PLAYER_REGEN_DISABLED()
	InCombat = true
	UpdateVisibility()
	self:SendMessage('COMBAT_START')
	if activeWidgets.kAttackers then
		UpdateAttackersTracking(InGroup)
	end
	if ConditionFields['@combat'] then
		UpdateCombatTracking(true)
		CombatReskinCheck(true)
	else
		CombatReskinCheck()
	end
end

----------------------------------------------------------------
-- Combat End
----------------------------------------------------------------

function addon:PLAYER_REGEN_ENABLED()
	InCombat = false
	self:SendMessage('COMBAT_END')
	if activeWidgets.kAttackers then
		UpdateAttackersTracking(false)
	end
	if ConditionFields['@combat'] then
		UpdateCombatTracking(false)
	end
	CombatReskinCheck()
	UpdateVisibility()
end

----------------------------------------------------------------
-- Zone Changed, reskin plates if necessary
----------------------------------------------------------------

function addon:ZONE_CHANGED_NEW_AREA(event)
	local _, type = IsInInstance()
	if type ~= InstanceType then
		InstanceType = type
		UpdateVisibility()
		if ConditionFields.instance then
			ReskinPlates()
		end
	end
end

----------------------------------------------------------------
-- Player entering world
----------------------------------------------------------------

if addon.isClassic then
	function addon:PLAYER_ENTERING_WORLD()
		local distance = addon.db.general.nameplateMaxDistanceClassic
		if distance then
			SetCVar("nameplateMaxDistance", distance)
		end
		self:ZONE_CHANGED_NEW_AREA()
	end
else
	addon.ZONE_CHANGED_NEW_AREA = addon.ZONE_CHANGED_NEW_AREA
end

----------------------------------------------------------------
-- Compile a function to calculate nameplate skin
----------------------------------------------------------------

local UpdateSkinCheckFunction
do
	local function NamesToList(names)
		local lines = {}
		local t = { strsplit("\n",names) }
		for i=1,#t do -- Remove comments: any text starting with #@\/-[ characters.
			local s = strtrim( (strsplit( "#@\\\/\-\[", t[i] )) ) -- Don't remove strsplit extra brackets.
			if #s>0 then tinsert( lines, format('["%s"]=true',s) ) end
		end
		return tconcat( lines , ',')
	end
	local function MakeSkinCheckWithClosure(names, source)
		local lines = { "return function()" }
		for i=1,#names do
			tinsert( lines, format("local names%d = {%s}",i, NamesToList(names[i]) ) )
		end
		tinsert( lines,  source )
		tinsert( lines, 'end' )
		return assert(loadstring(tconcat( lines, "\n")))()()
	end
	local function CompileSkinCheckFunction(rules, default, fields)
		if fields then wipe(fields) end
		local count, handler, lines, names, iff = 0, { 'return function(p, combat, instance) ' }, {}, {}, 'if'
		for j=1,#rules do
			local rule = rules[j]
			if #rule>1 and (not rule.disabled) then
				for i=2,#rule do
					local c = rule[i]
					if c[1] == 'names' then
						tinsert( names, c[3] )
						tinsert( lines, format("names%d[p.__name]",#names) )
					else
						local line
						local typ   = type(c[3])
						local field = gsub(c[1], "@", 'p.__')
						if c[3] == 'nil' then
							line = format( '%s == nil', field )
						elseif typ == 'string' then
							line = format( '%s %s "%s"', field, c[2], c[3] )
						elseif typ == 'boolean' then
							line = format( 'not %s %s %s', field, c[2], tostring(not c[3]) )
						else
							line = format( '%s %s %s', field, c[2], tostring(c[3]) )
						end
						tinsert( lines, line )
					end
					if fields then fields[c[1]] = true end
				end
				tinsert( handler, format( '%s %s then return %d', iff, tconcat(lines,format(' %s ',rule[1])), j) )
				iff = "elseif"
				wipe(lines)
				count = count + 1
			end
		end
		tinsert( handler, format(count>0 and 'else return %d end end' or 'return %d end', default or 1) )
		if #names>0 then
			return MakeSkinCheckWithClosure( names, tconcat(handler,"\n") )
		else
			return assert(loadstring(tconcat(handler,"\n")))()
		end
	end
	function UpdateSkinCheckFunction()
		if cfgTestSkin then
			GetPlateSkin = function() return addon.db.skins[cfgTestSkin] and cfgTestSkin or 1 end
		else
			GetPlateSkin = CompileSkinCheckFunction(addon.db.rules, addon.db.defaultSkin, ConditionFields)
		end
	end

end

----------------------------------------------------------------
-- Register/Unregister events
----------------------------------------------------------------

local function UpdateEventRegister( self, enabled, ... )
	local method = enabled and "RegisterEvent" or "UnregisterEvent"
	for i=select('#',...),1,-1 do
		self[method]( self, select(i,...) )
	end
end

----------------------------------------------------------------
-- Upgrade database from old formats if necessary
----------------------------------------------------------------

local UpgradeDatabase
do
	local replace = { PlateBorderFlat = 'borderf', PlateBorderGold = 'borderg', PlateBorderWhite = 'borderw' }
	local function UpgradeBorder(db,field)
		if db and db[field] then db[field] = BorderTexturesData[ gsub(db[field],'%a+$',replace) ] end
	end
	function UpgradeDatabase()
		local version = addon.db.version or 0
		if version<addon.defaults.version then
			for _,skin in ipairs(addon.db.skins) do
				UpgradeBorder( skin, 'borderTexture' )
				UpgradeBorder( skin, 'castBarBorderTexture' )
				skin.kCastBar_enabled = not skin.castBarHidden
				skin.castBarHidden = nil
				skin.kIcon_enabled = skin.ClassificationFrame_enabled
				skin.ClassificationFrame_enabled = nil
				if not isClassic and skin.healthBarWidth then
					skin.healthBarWidth = math.max(1,skin.healthBarWidth-24)
				end
			end
			UpgradeBorder( addon.db.targetCastBar, 'borderTexture' )
			UpgradeBorder( addon.db.playerCastBar, 'borderTexture' )
			addon.db.version = addon.defaults.version
		end
	end
end

----------------------------------------------------------------
-- Update addon when database config or profile changes
----------------------------------------------------------------

do
	local function UpdateGeneral()
		local cfg = addon.db.general
		cfgAlpha1 = cfg.alpha1 or 1
		cfgAlpha2 = cfg.alpha2 or .4
		cfgAlpha3 = cfg.alpha3 or 1
		cfgAdjustAlpha = math.abs(cfgAlpha3 - cfgAlpha2)>0.01
		cfgReactionColor = cfg.reactionColor
		cfgClassColorReaction.hostile  = cfg.classColorHostilePlayers
		cfgClassColorReaction.friendly = cfg.classColorFriendlyPlayers
		cfgHealthColor1 = cfg.healthColor.color1
		cfgHealthColor2 = cfg.healthColor.color2
		cfgHealthColor3 = cfg.healthColor.color3
		cfgHealthThreshold1 = cfg.healthColor.threshold1
		cfgHealthThreshold2 = cfg.healthColor.threshold2
		for class,color in pairs(cfg.classColor) do
			ClassColors[class] = color
		end
		pixelScale = 768/select(2,GetPhysicalScreenSize())/WorldFrame:GetScale()
		if not InCombatLockdown() then
			SetCVar("nameplateGlobalScale", 1)
			SetCVar("nameplateSelectedScale", 1)
			SetCVar("nameplateMinScale", 1)
		end
		cfgClassicBorders = addon.__db.global.classicBorders
		cfgTipProfessionLine = GetCVarBool('colorblindmode') and KiwiPlatesNameTooltipTextLeft3 or KiwiPlatesNameTooltipTextLeft2
	end

	local function UpdateSkins()
		wipe(activeWidgets)
		wipe(activeStatuses)
		wipe(WidgetUpdate)
		for _,skin in ipairs(addon.db.skins) do
			local update = { methods = {}, blizzard = {} }
			for statusName in pairs(ColorStatuses) do
				update[statusName] = {}
			end
			for _,widgetName in ipairs(WidgetNames) do
				if skin[widgetName..'_enabled'] then
					if not activeWidgets[widgetName] then
						activeWidgets[widgetName] = true
						tinsert( activeWidgets, widgetName )
					end
					local statusName = skin[widgetName..'_color_status'] or ColorStatusDefaults[widgetName]
					if statusName then
						update.methods[widgetName] = ColorMethods[statusName]
						tinsert( update[statusName], widgetName )
						update[widgetName] = skin[widgetName..'_color_default'] or ColorDefaults[widgetName]
						activeStatuses[statusName] = true
					else
						update[widgetName] = true -- hackish, we use this to detect enabled widgets inside each skin
					end
					local func = WidgetMethods[widgetName]
					if func then tinsert( update , WidgetMethods[widgetName] ) end
				end
			end
			WidgetUpdate[skin] = update
		end
	end

	function addon:Update()

		UpgradeDatabase()

		UpdateGeneral()

		UpdateSkins()

		UpdateSkinCheckFunction()

		UpdateEventRegister( HealthFrame, activeWidgets.kHealthText or activeStatuses.health or activeStatuses.reaction, "UNIT_MAXHEALTH", isClassic and "UNIT_HEALTH_FREQUENT" or "UNIT_HEALTH"  )
		UpdateEventRegister( self, self.db.general.highlight or ConditionFields['@mouseover'], "UPDATE_MOUSEOVER_UNIT" )
		UpdateEventRegister( self, activeStatuses.reaction or ConditionFields['@attackable'] or ConditionFields['@reaction'], "UNIT_FLAGS", "UNIT_TARGETABLE_CHANGED", "UNIT_FACTION" )
		UpdateEventRegister( self, activeWidgets.kLevelText or ConditionFields['@classification'], 'UNIT_CLASSIFICATION_CHANGED' )
		UpdateEventRegister( self, activeWidgets.kAttackers, "GROUP_ROSTER_UPDATE" )

		UpdateAttackersTracking( activeWidgets.kAttackers and InCombat and InGroup)

		-- updating modules before reskining the plates, be careful in threat/auras modules UPDATE callbacks,
		-- do not call direct/indirect to the function SkinPlate() in these callbacks, do not use plates skin data.
		self:SendMessage('UPDATE')

		-- Create nameplates widgets if necessary and mark all nameplates to be reskinned, even the unused nameplates
		for _,UnitFrame in ipairs(NamePlatesAll) do
			CreateNamePlate(UnitFrame)
		end

		-- Not using the function C_NamePlate.GetNamePlates() to iterate the plates because that function
		-- can return the personal resource bar if visible, and the addon must not skin that bar.
		for plateFrame, UnitFrame in pairs(NamePlates) do
			SkinPlate(plateFrame, UnitFrame, true) -- true = Fake UNIT_ADDED to force a full update
		end

		if isClassic then
			RealMobHealth = self.db.RealMobHealth and _G.RealMobHealth and _G.RealMobHealth.GetUnitHealth
		end

		UpdatePlatesOpacity()

	end
end

----------------------------------------------------------------
-- Friend/Enemy visibility, only called from options
----------------------------------------------------------------

function addon:UpdateVisibility()
	UpdateVisibility()
end

----------------------------------------------------------------
-- Database profile changed
----------------------------------------------------------------

function addon:OnProfileChanged()
	self:Update()
	self:SendMessage('PROFILE_CHANGED')
end

----------------------------------------------------------------
-- Test Mode
----------------------------------------------------------------

function addon:TestMode(skinIndex, update) -- Togle test mode or update skin to test
	if not update or cfgTestSkin then
		cfgTestSkin = (update or not cfgTestSkin) and skinIndex or nil
		self:Update()
	end
end

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

addon:RegisterMessage('INITIALIZE', function()
	InstanceType = select(2, IsInInstance())
	InGroup = not IsInRaid() and GetNumSubgroupMembers()>0
	UpdateVisibility()
end )

----------------------------------------------------------------
-- Run
----------------------------------------------------------------

addon:RegisterMessage('ENABLE', function()
	if isClassic then addon:RegisterEvent("NAME_PLATE_CREATED") end
	addon:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	addon:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	addon:RegisterEvent("PLAYER_TARGET_CHANGED")
	addon:RegisterEvent("PLAYER_REGEN_DISABLED")
	addon:RegisterEvent("PLAYER_REGEN_ENABLED")
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	addon:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon:RegisterEvent("UNIT_NAME_UPDATE")
	addon:Update()
end )

----------------------------------------------------------------
-- Publish some stuff
----------------------------------------------------------------

-- methods
addon.CreateTimer              = CreateTimer
addon.SetBorderTexture         = SetBorderTexture
addon.UpdateWidgetColor        = UpdateWidgetColor
-- variables
addon.NamePlates               = NamePlates
addon.NamePlatesByUnit         = NamePlatesByUnit
addon.NamePlatesByGUID         = NamePlatesByGUID
addon.ClassColors              = ClassColors
addon.ColorsNonOverride        = ColorsNonOverride
addon.ColorWhite               = ColorWhite
addon.ColorBlack               = ColorBlack
addon.ColorDefault             = ColorDefault
addon.ColorDefaults            = ColorDefaults
addon.ColorWidgets             = ColorWidgets
addon.ColorStatuses            = ColorStatuses
addon.ColorStatusDefaults      = ColorStatusDefaults
addon.FontCache                = FontCache
addon.TexCache                 = TexCache
addon.BorderTextures           = BorderTextures
addon.BorderTexturesCoord      = BorderTexturesCoord
addon.BorderTexturesPlateSep   = BorderTexturesPlateSep
addon.BorderTexturesCastBarSep = BorderTexturesCastBarSep
addon.BorderTextureDefault     = BorderTextureDefault
