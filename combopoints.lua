local addon = KiwiPlates

-- only for druid or rogue
local _,playerClass = UnitClass('player')
if playerClass~='DRUID' and playerClass~='ROGUE' and playerClass~='MONK' then return end

-- local variables
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
local flagCastBarAdjusted

-- update combo points
local function Update(UnitFrame)
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

-- attach combo points frame to target nameplate
local function Attach(UnitFrame)
	local castBar = UnitFrame.kkCastBar
	local db = addon.db.combo
	local iconSize = db.iconSize or 20
	local adjY = db.castBarAdjust and (castBar and castBar:IsVisible() and castBar:GetHeight()*db.castBarAdjust) or 0
	frameParent = UnitFrame.healthBar or UnitFrame
	frame:SetParent( frameParent )
	frame:SetFrameLevel( UnitFrame.RaidTargetFrame:GetFrameLevel() + 1 )
	frame:SetPoint('CENTER', db.offsetX or 0,  (db.offsetY or -15) + adjY)
	frame:SetSize( iconSize*4, iconSize)
	if isClassic then texture:SetTexCoord(0,0,0,0) end
	frame.UnitFrame = UnitFrame
	frame:Show()
end

--hide combo points frame
local function Detach()
	frame:Hide()
	frame:SetParent(nil)
	frame:ClearAllPoints()
	frame.UnitFrame = nil
	frameParent = nil
end

-- power update events
frame:SetScript('OnEvent', function(self, _, _, powerType)
	if powerType==POWER_TSTR then
		local plateFrame = C_GetNamePlateForUnit('target')
		if plateFrame then
			Update(plateFrame.UnitFrame)
		end
	end
end)

-- target changed message
local function TargetChanged(plateFrame)
	if plateFrame then
		Attach(plateFrame.UnitFrame)
	elseif frame:IsShown() then
		Detach()
	end
end

local function NamePlateAdded(UnitFrame)
	if UnitFrame.__target then
		Attach(UnitFrame)
		Update(UnitFrame)
	elseif UnitFrame==frame.UnitFrame then
		Detach()
	end
end

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

local function NamePlateCreated(UnitFrame)
	local castBar = UnitFrame.kkCastBar
	if castBar and not castBar.__comboParent then
		castBar.__comboParent = UnitFrame.healthBar or UnitFrame
	end
end

-- update config
addon:RegisterMessage('UPDATE', function()
	if addon.db.combo.enabled then
		addon:RegisterMessage('PLAYER_TARGET_CHANGED', TargetChanged)
		addon:RegisterMessage('NAME_PLATE_UNIT_ADDED', NamePlateAdded)
		frame:RegisterUnitEvent('UNIT_MAXPOWER','player')
        frame:RegisterUnitEvent('UNIT_POWER_FREQUENT','player')
		frame:RegisterUnitEvent('UNIT_DISPLAYPOWER','player')
		if addon.db.combo.castBarAdjust then
			addon:RegisterMessage('NAME_PLATE_CREATED', NamePlateCreated)
			if not addon.isVanilla then
				hooksecurefunc( 'CastingBarFrame_OnEvent', AdjustComboFrame)
			end
		end
	else
		addon:UnregisterMessage('PLAYER_TARGET_CHANGED', TargetChanged)
		addon:UnregisterMessage('NAME_PLATE_UNIT_ADDED', NamePlateAdded)
		addon:UnregisterMessage('NAME_PLATE_CREATED', NamePlateCreated)
		frame:UnregisterEvent('UNIT_MAXPOWER')
        frame:UnregisterEvent('UNIT_POWER_FREQUENT')
        frame:UnregisterEvent('UNIT_DISPLAYPOWER')
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
} )
