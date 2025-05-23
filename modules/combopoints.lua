local addon = KiwiPlates

-- only for druid or rogue
local _,playerClass = UnitClass('player')
if playerClass~='DRUID' and playerClass~='ROGUE' and playerClass~='MONK' then return end

-- local variables
local UnitExists = UnitExists
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local C_GetNamePlateForUnit  = C_NamePlate.GetNamePlateForUnit
local POWER_TYPE = playerClass~='MONK' and Enum.PowerType.ComboPoints or Enum.PowerType.Chi
local POWER_TSTR = playerClass~='MONK' and 'COMBO_POINTS' or 'CHI'
local VY = { [4] = 16/256, [5] = 16/256*5, [6] = 16/256*10 }
local isClassic = addon.isClassic

-- database defaults
addon.defaults.combo = {}

-- create combo points frame
local frame = CreateFrame('Frame')
local texture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
texture:SetTexture('Interface\\Addons\\KiwiPlates\\media\\combopoints')
texture:SetAllPoints()
texture:SetTexCoord(0,0,0,0)

--
local frameParent
local flagAttachToScreen
local flagCastBarAdjusted

-- return UnitFrame of target Plate
local function GetTargetUnitFrame()
	local plateFrame = C_GetNamePlateForUnit('target')
	return plateFrame and plateFrame.UnitFrame
end

-- update combo points
local Update
do
	if isClassic then
		local Y = VY[5]
		local GetComboPoints = GetComboPoints
		Update = function()
			local v = GetComboPoints('player', 'target') or 0
			if v>0 then
				local y =  Y + v * .0625
				texture:SetTexCoord( 0, 1, y-.0625, y )
				return
			end
			texture:SetTexCoord(0,0,0,0)
		end
	else
		Update = function()
			local v = UnitPower('player', POWER_TYPE) or 0
			if v>0 then
				local m = UnitPowerMax('player', POWER_TYPE)
				local y = VY[m]
				if y then
					y = y + v * .0625
					texture:SetTexCoord( 0, 1, y-.0625, y )
					return
				end
			end
			texture:SetTexCoord(0,0,0,0)
		end
	end
end

-- power update events
frame:SetScript('OnEvent', function(self, _, _, powerType)
	if powerType==POWER_TSTR and frame:IsVisible() then
		Update()
	end
end)

-- hook, combo frame adjust due to castbar
local function AdjustComboFrame(castBar, event)
	if frameParent and castBar.__comboParent == frameParent then
		local visible = castBar.casting or castBar.channeling
		if flagCastBarAdjusted ~= visible then
			local db = addon.db.combo
			local adjY = (db.castBarAdjust and visible and castBar:GetHeight()*db.castBarAdjust) or 0
			frame:ClearAllPoints()
			frame:SetPoint('CENTER', db.offsetX or 0,  (db.offsetY or -15) + adjY)
			flagCastBarAdjusted = visible
		end
	end
end

-- attach combo points frame to target nameplate
local function Attach2Plate(UnitFrame)
	UnitFrame = UnitFrame or GetTargetUnitFrame()
	if UnitFrame then
		local castBar = UnitFrame.kkCastBar
		local db = addon.db.combo
		local iconSize = db.iconSize or 20
		local adjY = (db.castBarAdjust and castBar and castBar:IsVisible()) and castBar:GetHeight()*db.castBarAdjust or 0
		flagCastBarAdjusted = (adjY~=0) or nil
		frameParent = UnitFrame.healthBar or UnitFrame
		frame:SetParent( frameParent )
		frame:SetScale(1)
		frame:SetFrameLevel( UnitFrame.RaidTargetFrame:GetFrameLevel() + 1 )
		frame:SetPoint('CENTER', db.offsetX or 0,  (db.offsetY or -15) + adjY)
		frame:SetSize( iconSize*4, iconSize)
		if isClassic then texture:SetTexCoord(0,0,0,0) end
		frame.UnitFrame = UnitFrame
		frame:Show()
		Update()
		return true
	end
end

-- attach combo points frame to UIParent
local function Attach2Screen()
	local db = addon.db.combo
	local iconSize = db.screenIconSize or 20
	frameParent = UIParent
	frame:SetParent( frameParent )
	frame:SetScale( addon.pixelScale / frameParent:GetEffectiveScale() )
	frame:SetPoint('CENTER', db.screenOffsetX or 0,  db.screenOffsetY or 0 )
	frame:SetSize( iconSize*4, iconSize )
	if isClassic then texture:SetTexCoord(0,0,0,0) end
	frame.UnitFrame = nil
	frame:Show()
	Update()
end

-- detach&hide combo points frame
local function Detach()
	frame:Hide()
	frame:SetParent(nil)
	frame:ClearAllPoints()
	frame.UnitFrame = nil
	frameParent = nil
end

-- event, when target nameplate changes
local function NamePlateTargetChanged(plateFrame)
	if plateFrame then
		Attach2Plate(plateFrame.UnitFrame)
	elseif flagAttachToScreen and UnitExists('target') then -- attach to screen only if there is no target nameplate
		Attach2Screen()
	elseif frame:IsShown() then -- never attach to screen, hide instead
		Detach()
	end
end

-- event, only when combo frame position must be adjusted due to castbar
local function NamePlateCreated(UnitFrame)
	local castBar = UnitFrame.kkCastBar
	if castBar and not castBar.__comboParent then
		castBar.__comboParent = UnitFrame.healthBar or UnitFrame
	end
end

-- initial positioning
local function InitFrame()
	flagAttachToScreen = (addon.db.combo.attachToScreen==false)  -- nil:attach to target plate/false:attach to target plate or screen/true:attach to screen
	if addon.db.combo.attachToScreen==true then
		Attach2Screen()
	else
		NamePlateTargetChanged( GetTargetUnitFrame() )
	end
end

-- update config
addon:RegisterMessage('UPDATE', function()
	KiwiPlatesCastingBarFrame_AdjustComboFrame = nil
	if addon.db.combo.enabled then
		InitFrame()
		frame:RegisterUnitEvent('UNIT_MAXPOWER','player')
        frame:RegisterUnitEvent('UNIT_POWER_FREQUENT','player')
		frame:RegisterUnitEvent('UNIT_DISPLAYPOWER','player')
		addon:RegisterMessage('UPDATE_SCALE', InitFrame)
		addon:RegisterMessage('PLAYER_TARGET_CHANGED', Update)
		if addon.db.combo.attachToScreen~=true then
			addon:RegisterMessage('NAME_PLATE_TARGET_CHANGED', NamePlateTargetChanged)
		end
		if addon.db.combo.castBarAdjust then
			addon:RegisterMessage('NAME_PLATE_CREATED', NamePlateCreated)
			if not addon.isVanilla and CastingBarFrame_OnEvent then
				hooksecurefunc( 'CastingBarFrame_OnEvent', AdjustComboFrame)
			else
				KiwiPlatesCastingBarFrame_AdjustComboFrame = AdjustComboFrame
			end
		end
	else
		frame:UnregisterEvent('UNIT_MAXPOWER')
        frame:UnregisterEvent('UNIT_POWER_FREQUENT')
        frame:UnregisterEvent('UNIT_DISPLAYPOWER')
		addon:UnregisterMessage('UPDATE_SCALE', InitFrame)
		addon:UnregisterMessage('PLAYER_TARGET_CHANGED', Update)
		addon:UnregisterMessage('NAME_PLATE_TARGET_CHANGED', NamePlateTargetChanged)
		addon:UnregisterMessage('NAME_PLATE_CREATED', NamePlateCreated)
	end
end )

-- configuration
addon:SetupOptions( 'Skins/Settings', 'Combo Points', {
	comboEnabled = {
		type = 'toggle',
		order = 0.1,
		width = 'double',
		name = addon.FormatTitle("Combo Points", true),
		desc = 'Display combo points on target nameplate.',
		get = function() return addon.db.combo.enabled end,
		set = function(info, v)
			addon.db.combo.enabled = v or nil
			addon:Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Anchor Behaviour" },
	comboAttach = {
		type = 'select', width = 'double', order = 10,
		name = 'Anchor Combo Points Frame To',
		desc = '',
		get = function()
			local v = addon.db.combo.attachToScreen
			return (v==nil and 1) or (v==false and 2) or 3
		end,
		set = function(info,value)
			if value==1 then
				value = nil
			else
				value = (value==3)
			end
			addon.db.combo.attachToScreen = value
			addon:Update()
		end,
		values = {'Target NamePlate', 'Target NamePlate or Screen', 'Always to Screen' },
	},
	header2 = { type = "header", order = 15, name = "Target NamePlate Position & Size" },
	comboOffsetX =  {
		type = 'range', order = 31, name = 'X Offset', softMin = -32, softMax = 200, step = 1,
		get = function() return addon.db.combo.offsetX or 0 end,
		set = function(info,value)
			addon.db.combo.offsetX = value~=-0 and value or nil
			addon:Update()
		end,
	},
	comboOffsetY =  {
		type = 'range', order = 32, name = 'Y Offset', softMin = -50, softMax = 50, step = 1,
		get = function() return addon.db.combo.offsetY or -15 end,
		set = function(info,value)
			addon.db.combo.offsetY = value~=-15 and value or nil
			addon:Update()
		end,
	},
	comboSize =  {
		type = 'range', order = 33, name = 'Icon Size', min = 0, softMax = 64, step = 1,
		name = "Icon Size",
		desc = "Combo Points Icons Size",
		get = function() return addon.db.combo.iconSize or 20 end,
		set = function(info,value)
			addon.db.combo.iconSize = value~=20 and value or nil
			addon:Update()
		end,
	},
	comboCastBarAdj = {
		type = 'select', width = 'normal', order = 34,
		name = 'Cast Bar Vertical Adjust',
		desc = 'Select combo points vertical adjust when the castbar is visible',
		get = function()
			local v = addon.db.combo.castBarAdjust
			return (v==1 and 3) or (v==-1 and 2) or 1
		end,
		set = function(info,value)
			value = (value==3 and 1) or (value==2 and -1) or nil
			local reload = (not value ~= not addon.db.combo.castBarAdjust)
			addon.db.combo.castBarAdjust = value
			if reload then ReloadUI() end
		end,
		values = {'None', 'Move Down', 'Move Up' },
		confirm = function() return 'UI may be reloaded to change this option. Are you sure ?' end,
	},
	header3 = { type = "header", order = 35, name = "Screen Position & Size" },
	screenOffsetX =  {
		type = 'range', order = 36, name = 'X Offset', softMin = -32, softMax = 200, step = 1,
		get = function() return addon.db.combo.screenOffsetX or 0 end,
		set = function(info,value)
			addon.db.combo.screenOffsetX = value~=-0 and value or nil
			addon:Update()
		end,
	},
	screenOffsetY =  {
		type = 'range', order = 37, name = 'Y Offset', softMin = -50, softMax = 50, step = 1,
		get = function() return addon.db.combo.screenOffsetY or -15 end,
		set = function(info,value)
			addon.db.combo.screenOffsetY = value~=-15 and value or nil
			addon:Update()
		end,
	},
	screenSize =  {
		type = 'range', order = 38, name = 'Icon Size', min = 0, softMax = 64, step = 1,
		name = "Icon Size",
		desc = "Combo Points Icons Size",
		get = function() return addon.db.combo.screenIconSize or 20 end,
		set = function(info,value)
			addon.db.combo.screenIconSize = value~=20 and value or nil
			addon:Update()
		end,
	},
} )
