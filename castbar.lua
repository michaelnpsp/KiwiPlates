-- CastBar management for WoW vanilla
if select(4, GetBuildInfo())>=20000 then return end

local LibCC = LibStub("LibClassicCasterino")
local next =  next
local GetTime = GetTime

local function UpdateCastBar(self, channel, name, _, texture, startTimeMS, endTimeMS)
	if name then
		self.channeling = channel
		self.maxValue = (endTimeMS - startTimeMS)/1000
		self.value = GetTime() - startTimeMS/1000
		self:SetMinMaxValues(0, self.maxValue)
		self.Text:SetText(name)
		self.Icon:SetTexture(texture)
		self:SetAlpha(1)
		self:Show()
	else
		self:Hide()
	end
end

local function RefreshCastBar(self, unit)
	local name, _, texture, startTimeMS, endTimeMS = LibCC:UnitCastingInfo(unit)
	if name then
		UpdateCastBar(self, false, name, _, texture, startTimeMS, endTimeMS)
	else
		name, _, texture, startTimeMS, endTimeMS = LibCC:UnitChannelInfo(unit)
		if name then
			UpdateCastBar(self, true, name, _, texture, startTimeMS, endTimeMS)
		else
			self:Hide()
		end
	end
end

local RegisterCallback, UnregisterCallback
do
	local object_to_unit = {}
	local unit_to_object = {}

	local function CastEvent(_,unit)
		local self = unit_to_object[unit]
		if self then
			UpdateCastBar(self, false, LibCC:UnitCastingInfo(unit))
		end
	end

	local function ChannelEvent(_,unit)
		local self = unit_to_object[unit]
		if self then
			UpdateCastBar(self, true, LibCC:UnitChannelInfo(unit))
		end
	end

	function RegisterCallback(self, unit)
		unit_to_object[unit] = self
		object_to_unit[self] = unit
	end

	function UnregisterCallback(self)
		local unit = object_to_unit[self]
		if unit then
			object_to_unit[self] = nil
			unit_to_object[unit] = nil
		end
	end

	LibCC.RegisterCallback("KiwiPlatesCast","UNIT_SPELLCAST_START", CastEvent)
	LibCC.RegisterCallback("KiwiPlatesCast","UNIT_SPELLCAST_STOP", CastEvent)
	LibCC.RegisterCallback("KiwiPlatesCast","UNIT_SPELLCAST_FAILED", CastEvent)
	LibCC.RegisterCallback("KiwiPlatesCast","UNIT_SPELLCAST_INTERRUPTED", CastEvent)
	LibCC.RegisterCallback("KiwiPlatesCast","UNIT_SPELLCAST_CHANNEL_START", ChannelEvent)
	LibCC.RegisterCallback("KiwiPlatesCast","UNIT_SPELLCAST_CHANNEL_STOP", ChannelEvent)
end

-- Global functions
function KiwiPlatesCastingBarFrame_OnUpdate(self, elapsed)
	local value = self.value + elapsed
	if value<self.maxValue then
		self.value = value
		self:SetValue(self.channeling and self.maxValue-value or value)
	else
		self:Hide()
	end
end

function KiwiPlatesCastingBarFrame_SetUnit(self, unit)
	if unit then
		RegisterCallback(self, unit)
		RefreshCastBar(self, unit)
	else
		UnregisterCallback(self)
		self:Hide()
	end
end
