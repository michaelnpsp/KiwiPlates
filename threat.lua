----------------------------------------------------------------
-- KiwiPlates: threat
----------------------------------------------------------------
local addon = KiwiPlates

local next = next
local pairs = pairs
local unpack = unpack
local UnitName = UnitName
local UnitIsUnit = UnitIsUnit
local UnitIsFriend = UnitIsFriend
local UnitAffectingCombat = UnitAffectingCombat
local UnitThreatSituation = UnitThreatSituation
local UnitGroupRolesAssigned = UnitGroupRolesAssigned or addon.GetCustomDungeonRole
local GetSpecialization = GetSpecialization or function() end
local GetSpecializationRole = GetSpecializationRole or function() return addon.db.threat.playerRole end
local NamePlatesByUnit  = addon.NamePlatesByUnit
local UpdateWidgetColor = addon.UpdateWidgetColor

local Widgets
local inCombat
local ignoreCombat
local threatColors
local unitTarget  = setmetatable({}, {__index = function(t,k) local v=k.."target" t[k]=v return v end})

-- not tanked / offtanked / insecure tanking / secure tanking
addon.defaults.threat = {
	widgets     = {},
	colorsTank  = { [0] = { 1, 0, 0 }, [1] = { 0,  0,1 }, [2] = { 1, 1,0 }, [3] = { 0,1,0 }, },
	colorsOther = {	[0] = { .85,1,0 }, [1] = { .35,1,0 }, [2] = { 1,.4,0 }, [3] = { 1,0,0 }, },
}

--- classic & retail stuff

local function UpdatePlateThreatColor(UnitFrame, unit)
	if inCombat and UnitFrame.__type ~= 'Player' and not UnitIsFriend('player',unit) and (ignoreCombat or UnitAffectingCombat(unit)) then
		local threat = UnitThreatSituation( 'player', unit ) or 0  -- 2&3 = tanked
		if threat<2 then
			threat = 0 -- not tanked
			local target = unitTarget[unit]
			if UnitExists(target) then
				if UnitIsUnit(target,'player') then
					threat = 3
				elseif UnitGroupRolesAssigned(target)=='TANK' then
					threat = 1 -- offtanked
				end
			end
		end
		if threat ~= UnitFrame.__threat then
			UnitFrame.__threat = threat
			local color = threatColors[threat]
			local r,g,b,a = unpack(color)
			for i=#Widgets,1,-1 do
				local widget = UnitFrame[Widgets[i]]
				if widget then
					widget.colorOverride = color
					widget:SetWidgetColor(r,g,b,a)
				end
			end
		end
	end
end

local function ResetPlateThreatColor(UnitFrame, unit)
	UnitFrame.__threat = nil
	for i=#Widgets,1,-1 do
		local name = Widgets[i]
		local widget = UnitFrame[name]
		if widget then
			widget.colorOverride = nil
		end
	end
end

local function CombatStart()
	local spec = GetSpecializationRole(GetSpecialization() or 1)
	if addon.db.threat.alwaysEnabled or spec == 'TANK' then
		inCombat = true
		threatColors = spec=='TANK' and addon.db.threat.colorsTank or addon.db.threat.colorsOther
		for unit,UnitFrame in pairs(NamePlatesByUnit) do
			UpdatePlateThreatColor( UnitFrame, unit )
		end
		addon:RegisterEvent('UNIT_THREAT_LIST_UPDATE')
		addon.ThreatColorUpdatePlate = UpdatePlateThreatColor
	end
end

local function CombatEnd()
	if inCombat then
		inCombat = false
		for _, UnitFrame in pairs(NamePlatesByUnit) do
			UnitFrame.__threat = nil
			for i=#Widgets,1,-1 do
				local name = Widgets[i]
				local widget = UnitFrame[name]
				if widget then
					widget.colorOverride = nil
					UpdateWidgetColor( UnitFrame, name )
				end
			end
		end
		addon:UnregisterEvent('UNIT_THREAT_LIST_UPDATE')
		addon.ThreatColorUpdatePlate = nil
	end
end

function addon:UNIT_THREAT_LIST_UPDATE(unit)
	local UnitFrame = NamePlatesByUnit[unit]
	if UnitFrame then
		UpdatePlateThreatColor( UnitFrame, unit )
	end
end

-- Initialization

addon:RegisterMessage('UPDATE', function()
	Widgets = addon.db.threat.widgets
	if next(Widgets) then
		ignoreCombat = addon.db.threat.ignoreCombat
		addon:RegisterMessage('COMBAT_START', CombatStart)
		addon:RegisterMessage('COMBAT_END', CombatEnd)
		addon:RegisterMessage("NAME_PLATE_UNIT_ADDED", UpdatePlateThreatColor)
		addon:RegisterMessage("NAME_PLATE_UNIT_REMOVED", ResetPlateThreatColor)
	else
		addon:UnregisterMessage('COMBAT_START', CombatStart)
		addon:UnregisterMessage('COMBAT_END', CombatEnd)
		addon:UnregisterMessage("NAME_PLATE_UNIT_ADDED", UpdatePlateThreatColor)
		addon:UnregisterMessage("NAME_PLATE_UNIT_REMOVED", ResetPlateThreatColor)
		inCombat = false
	end
end )

--===============================================================
-- Configuration Options
--===============================================================

local options = {
	separator = {
		type = "header",
		order = .1,
		name = "Threat",
	},
	separator1 = {
		type = "header",
		order = 9,
		name = "Colors for Tanks",
	},
	colorTank0 = {
		type = "color",
		order = 10,
		hasAlpha = false,
		name = "Not Tanking",
		get = function()
			return unpack( addon.db.threat.colorsTank[0] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsTank[0] = { r, g, b }
		end,
	},
	colorTank1 = {
		type = "color",
		order = 11,
		hasAlpha = false,
		name = "Offtanked",
		desc = "Tanked by another tank",
		get = function()
			return unpack( addon.db.threat.colorsTank[1] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsTank[1] = { r, g, b }
		end,
	},
	colorTank2 = {
		type = "color",
		order = 12,
		hasAlpha = false,
		name = "Insecure Tanking",
		get = function()
			return unpack( addon.db.threat.colorsTank[2] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsTank[2] = { r, g, b }
		end,
	},
	colorTank3 = {
		type = "color",
		order = 13,
		hasAlpha = false,
		name = "Secure Tanking",
		get = function()
			return unpack( addon.db.threat.colorsTank[3] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsTank[3] = { r, g, b }
		end,
	},
	separator2 = {
		type = "header",
		order = 19,
		name = "Colors for DPS&Healers",
		hidden = function() return not addon.db.threat.alwaysEnabled end,
	},
	colorOther0 = {
		type = "color",
		order = 20,
		hasAlpha = false,
		name = "Not Tanked",
		desc = "Mob attacking another healer or dps.",
		get = function()
			return unpack( addon.db.threat.colorsOther[0] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsOther[0] = { r, g, b }
		end,
		hidden = function() return not addon.db.threat.alwaysEnabled end,
	},
	colorOther1 = {
		type = "color",
		order = 21,
		hasAlpha = false,
		name = "Tanked",
		desc = "Tanked by some tank",
		get = function()
			return unpack( addon.db.threat.colorsOther[1] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsOther[1] = { r, g, b }
		end,
		hidden = function() return not addon.db.threat.alwaysEnabled end,
	},
	colorOther2 = {
		type = "color",
		order = 22,
		hasAlpha = false,
		name = "Attacking me",
		desc = "Attacking me (low aggro)",
		get = function()
			return unpack( addon.db.threat.colorsOther[2] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsOther[2] = { r, g, b }
		end,
		hidden = function() return not addon.db.threat.alwaysEnabled end,
	},
	colorOther3 = {
		type = "color",
		order = 23,
		hasAlpha = false,
		name = "Attacking me",
		desc = "Attacking me (high aggro)",
		get = function()
			return unpack( addon.db.threat.colorsOther[3] )
		end,
		set = function( _, r,g,b )
			addon.db.threat.colorsOther[3] = { r, g, b }
		end,
		hidden = function() return not addon.db.threat.alwaysEnabled end,
	},
	separator3 = {
		type = "header",
		order = 30,
		name = "Special",
	},
	alwaysEnabled = {
		type = "toggle",
		order = 31,
		width = "full",
		name = "Apply threat colors only to Tanks",
		get = function() return not addon.db.threat.alwaysEnabled end,
		set = function ( _, value)
			addon.db.threat.alwaysEnabled = (not value) or nil
		end,
	},
	ignoreCombat = {
		type = "toggle",
		order = 32,
		width = "full",
		name = "Apply threat colors to out of combat units",
		get = function() return addon.db.threat.ignoreCombat end,
		set = function ( _, value)
			addon.db.threat.ignoreCombat = value or nil
			addon:Update()
		end,
	},
}

if addon.isClassic then
	options.playerRole = {
		type = 'select',
		order = 34,
		width = 'normal',
		name = 'Select your Role:',
		get = function() return addon.db.threat.playerRole or 'DAMAGER' end,
		set = function(info, v) addon.db.threat.playerRole = v end,
		values = { TANK = 'Tank', DAMAGER = 'DPS', HEALER = 'Healer'},
	}
end

local order = 1
for key,name in pairs(addon.ColorWidgets) do
	options[key] = {
		type = "toggle",
		order = order,
		name  = name,
		desc  = string.format("Toggle to apply threat colors to the '%s' widget.", name),
		get = function()
			return addon.TableContains( addon.db.threat.widgets, key )
		end,
		set = function ( _, value)
			if value then
				table.insert( addon.db.threat.widgets, key )
			else
				addon.TableRemoveByValue( addon.db.threat.widgets, key )
			end
			addon:Update()
		end,
		hidden = function() return end,
	}
	order = order + 1
end

addon:SetupOptions( 'Skins/Settings', 'Colors: Threat', options, 99 )
