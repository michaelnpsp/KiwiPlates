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

local isClassic = addon.isClassic
local isVanilla = addon.isVanilla
local UNKNOWNOBJECT = UNKNOWNOBJECT
local IsInRaid = IsInRaid
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitHealth = UnitHealth
local UnitIsPlayer = UnitIsPlayer
local UnitIsFriend = UnitIsFriend
local UnitReaction = UnitReaction
local IsInInstance = IsInInstance
local UnitHealthMax = UnitHealthMax
local UnitCanAttack = UnitCanAttack
local UnitIsTapDenied = UnitIsTapDenied
local UnitClassification = UnitClassification
local UnitAffectingCombat = UnitAffectingCombat
local GetNumSubgroupMembers = GetNumSubgroupMembers
local C_GetNamePlateForUnit  = C_NamePlate.GetNamePlateForUnit
local C_SetNamePlateSelfSize = C_NamePlate.SetNamePlateSelfSize
local DifficultyColor = addon.DIFFICULTY_LEVEL_COLOR
local UnitGroupRolesAssigned = UnitGroupRolesAssigned or addon.GetCustomDungeonRole
local CastingBarFrame_SetUnit = isVanilla and KiwiPlatesCastingBarFrame_SetUnit or addon.CastingBarFrame_SetUnit

local pixelScale
local targetFrame
local targetExists
local mouseFrame

local GetPlateSkin
local ConditionFields = {}
local activeWidgets = {}
local activeStatuses = {}

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

local ColorWidgets  = {}

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
-- Database Defaults
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
addon.HiddenFrame = HiddenFrame

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
-- Statuses color painting management
----------------------------------------------------------------

-- default color sources/statuses used to paint widgets
-- example: { kHealthBorder = 'color', kLevelText = 'reaction' }
local ColorStatusDefaults = {}

-- default static colors used to paint widgets
-- example { kHealthBorder = ColorBlack }
local ColorDefaults = {}

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
-- Widgets management
----------------------------------------------------------------

-- Registered widgets:
-- widgetKey => widget table, see widgets folder for widgets tables definitions
local WidgetRegistered = {}

-- Registered Widgets Keys, index part: keys when widget active, hash part: key when widget active => key of created widget
-- example: { kLevelText, kLevelText = 'kkLevelText' }
local WidgetNames = {}

-- cached widget.Update() functions
local WidgetMethods = {}

-- Table that caches settings for each skin to update widgets
-- colors & values, example:
-- WidgetUpdate[skin] = {
--   -- functions to update widgets texts and statusbars
--   [1] = WidgetMethods.kHealthBar, [2] = WidgetMethods.kLevelText, ...
--   -- user defined colors & active widgets
--	 ['kHealthBar'] = customColor1, ['kNameText']  = customColor2, ['ClassificationFrame'] = true, ...
--   -- statuses
--	 methods  = {	['kHealthBar'] = UpdateColorReaction, ['kLevelText'] = UpdateColorCustom, ['kNameText'] = UpdateColorCustom },
--	 reaction = { 'kHealthBar' },
--	 color    = { 'kNameText', 'kLevelText' }, -- color = customColor = statusName
-- }
local WidgetUpdate = {}

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
	local UpdateColorHealth = ColorMethods.health
	local UpdateColorReaction = ColorMethods.reaction
	HealthFrame = CreateFrame("Frame")
	HealthFrame:SetScript("OnEvent", function(_, _, unit)
		local UnitFrame = NamePlatesByUnit[unit]
		if UnitFrame then
			local update, percent = UnitFrame.__update
			if UnitFrame.kHealthText then
				percent = WidgetMethods.kHealthText(UnitFrame)
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
-- Skin a nameplate
----------------------------------------------------------------

-- cached widget.Layout() functions, indexes by widget key
local SkinMethods = {}

local function SkinPlate(plateFrame, UnitFrame, UnitAdded)
	-- calculate skin
	local db = addon.db.skins[ GetPlateSkin(UnitFrame, addon.InCombat, addon.InstanceType) ]
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
			healthBar:SetPoint('BOTTOMLEFT', anchorFrame, isVanilla and 'BOTTOMLEFT'  or 'TOPLEFT',  0,  gap or 0 )
			healthBar:SetPoint('BOTTOMRIGHT',anchorFrame, isVanilla and 'BOTTOMRIGHT' or 'TOPRIGHT', 0,  gap or 0 )
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
		local unit = UnitFrame.unit
		UnitFrame.__combat = UnitAffectingCombat(unit) or ( UnitIsPlayer(target[unit]) and UnitIsFriend(target[unit],'player') )
	end
end

local UpdateCombatTracking
do
	local timer = addon.CreateTimer(.25, function()
		for plateFrame, UnitFrame in pairs(NamePlates) do
			local unit = UnitFrame.unit
			local combat = UnitAffectingCombat(unit) or ( UnitIsPlayer(target[unit]) and UnitIsFriend(target[unit],'player') )
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
-- Mouseover management
----------------------------------------------------------------

do
	local timer
	timer = addon.CreateTimer(.2, function()
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
		self:SendMessage("NAME_PLATE_TARGET_CHANGED", targetFrame)
	end
	if targetExists ~= UnitExists('target') then
		targetExists = not targetExists
		if cfgAdjustAlpha then
			UpdatePlatesOpacity()
		end
	end
	self:SendMessage('PLAYER_TARGET_CHANGED', plateFrame, 'target')
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

local CreateMethods = {}

local CreateNamePlate
do
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
		self:NAME_PLATE_CREATED(plateFrame)
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
		UnitFrame.__combat = UnitAffectingCombat(unit) or ( UnitIsPlayer(target[unit]) and UnitIsFriend(target[unit],'player') )
		UnitFrame.__tapped = UnitIsTapDenied(unit)
		UnitFrame.__attackable = UnitCanAttack('player',unit)
		UnitFrame.__attackers = 0
		if UnitFrame.__level==-1 or UnitFrame.__classification=='worldboss' then
			UnitFrame.__classification = 'boss'
		end
		UnitFrame.__name = UnitName( unit )
		local newTarget = UnitIsUnit( unit, 'target' ) or nil
		UnitFrame.__target = newTarget
		if newTarget then
			if targetFrame and targetFrame.UnitFrame then -- unmark&reskin old target frame
				targetFrame.UnitFrame.__target = nil
				SkinPlate(targetFrame, targetFrame.UnitFrame)
			end
			targetFrame = plateFrame
		end
		SkinPlate( plateFrame, UnitFrame, true )
		UnitFrame.healthBar.UnitFrame = UnitFrame -- see FixHealthBarSize()
		self:SendMessage("NAME_PLATE_UNIT_ADDED", UnitFrame, unit)
		if newTarget then
			self:SendMessage("NAME_PLATE_TARGET_CHANGED", targetFrame)
		end
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
		local targetCleared
		UnitFrame.healthBar.UnitFrame = nil -- see FixHealthBarSize()
		UnitFrame.__threat = nil
		UnitFrame.__target = nil
		UnitFrame.__mouseover = nil
		if plateFrame == targetFrame then
			targetFrame = nil
			targetCleared = true
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
		if targetCleared then
			self:SendMessage("NAME_PLATE_TARGET_CHANGED")
		end
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
		UnitFrame.__level = UnitLevel( unit )
		UnitFrame.__classification = UnitClassification(unit) or 'unknow'
		if not ConditionFields['@classification'] or not SkinPlate( C_GetNamePlateForUnit(unit), UnitFrame ) then
			addon:SendMessage('UNIT_CLASSIFICATION_CHANGED', UnitFrame, unit)
		end
	end
end

----------------------------------------------------------------
-- kAttackers
----------------------------------------------------------------

function addon:GROUP_ROSTER_UPDATE()
	local group = not IsInRaid() and GetNumSubgroupMembers()>0
	if group ~= addon.InGroup then
		addon.InGroup = group
		addon:SendMessage('GROUP_TYPE_CHANGED')
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
				value = addon.InCombat == (value==2)
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
				value = addon.InCombat == (value==2)
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
	addon.InCombat = true
	UpdateVisibility()
	self:SendMessage('COMBAT_START')
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
	addon.InCombat = false
	self:SendMessage('COMBAT_END')
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
	if type ~= addon.InstanceType then
		addon.InstanceType = type
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
	addon.PLAYER_ENTERING_WORLD = addon.ZONE_CHANGED_NEW_AREA
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
		local cfgTestSkin = addon.cfgTestSkin
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
		addon.cfgClassicBorders = cfgClassicBorders
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
		for name, widget in pairs(WidgetRegistered) do
			local enabled = not widget.enabled
			if enabled ~= not activeWidgets[name] then
				widget.enabled = enabled or nil
				local func = widget[enabled and 'Enable' or 'Disable']
				if func then func() end
			end
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
	if not update or addon.cfgTestSkin then
		addon.cfgTestSkin = (update or not addon.cfgTestSkin) and skinIndex or nil
		self:Update()
	end
end

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

addon:RegisterMessage('INITIALIZE', function()
	addon.InstanceType = select(2, IsInInstance())
	addon.InGroup = not IsInRaid() and GetNumSubgroupMembers()>0
	addon.InCombat = InCombatLockdown()
	UpdateVisibility()
end )

----------------------------------------------------------------
-- Run
----------------------------------------------------------------

addon:RegisterMessage('ENABLE', function()
	addon:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	addon:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	addon:RegisterEvent("PLAYER_TARGET_CHANGED")
	addon:RegisterEvent("PLAYER_REGEN_DISABLED")
	addon:RegisterEvent("PLAYER_REGEN_ENABLED")
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	addon:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon:RegisterEvent("UNIT_NAME_UPDATE")
	addon:RegisterEvent("GROUP_ROSTER_UPDATE")
	addon:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
	addon:Update()
end )

----------------------------------------------------------------
-- Widgets Register
----------------------------------------------------------------

function addon:RegisterWidget( widgetName, widget, reused )
	WidgetRegistered[widgetName] = widget
	WidgetNames[#WidgetNames+1]  = widgetName
	WidgetNames[widgetName]    	 = reused and widgetName or 'k'..widgetName
	CreateMethods[widgetName]  	 = widget.Create
	SkinMethods[widgetName]    	 = widget.Layout
	WidgetMethods[widgetName]  	 = widget.Update
	ColorWidgets[widgetName]   	 = (widget.Color or widget.ColorStatus) and widget.Name or nil
	ColorDefaults[widgetName]  	 = widget.Color
	ColorStatusDefaults[widgetName] = widget.ColorStatus
	addon.defaults.skins[1][widgetName..'_enabled'] = widget.Enabled
end

----------------------------------------------------------------
-- Publish some stuff
----------------------------------------------------------------

-- methods
addon.SetBorderTexture         = SetBorderTexture
addon.UpdateWidgetColor        = UpdateWidgetColor
-- variables
addon.NamePlates               = NamePlates
addon.NamePlatesByUnit         = NamePlatesByUnit
addon.NamePlatesByGUID         = NamePlatesByGUID
addon.ClassTexturesCoord       = ClassTexturesCoord
addon.CoordEmpty               = CoordEmpty
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
addon.Classifications          = Classifications
addon.UnitGroupRolesAssigned   = UnitGroupRolesAssigned
addon.TargetCache              = target
