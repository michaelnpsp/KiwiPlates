
local addon = KiwiPlates

local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer

local NamePlates = addon.NamePlates
local TargetCache = addon.TargetCache
local CoordEmpty = addon.CoordEmpty
local ClassTexturesCoord = addon.ClassTexturesCoord

local timer

local Widget = {
	Name = 'Target Class',
	Enabled = false,
}

function Widget.Create(UnitFrame)
	local RaidTargetFrame = UnitFrame.RaidTargetFrame
	local kTargetClass = RaidTargetFrame:CreateTexture()
	kTargetClass:SetTexture('Interface\\Addons\\KiwiPlates\\media\\classif')
	kTargetClass:SetTexCoord( 0,0,0,0 )
	UnitFrame.kkTargetClass = kTargetClass
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
	local kTargetClass = UnitFrame.kkTargetClass
	if enabled then
		kTargetClass.displayedGUID = nil
		kTargetClass:ClearAllPoints()
		kTargetClass:SetSize( db.targetClassIconSize or 14, db.targetClassIconSize or 14 )
		kTargetClass:SetPoint('RIGHT', frameAnchor, 'RIGHT', db.targetClassIconOffsetX or 0, db.targetClassIconOffsetY or 0)
		kTargetClass:SetTexture(db.targetClassIconTexture or 'Interface\\Addons\\KiwiPlates\\media\\classif')
		kTargetClass:SetTexCoord(0,0,0,0)
		kTargetClass:Show()
		UnitFrame.kTargetClass = kTargetClass
	elseif kTargetClass then
		kTargetClass:Hide()
		UnitFrame.kTargetClass = nil
	end
end

function Widget.Update(UnitFrame)
	if addon.cfgTestSkin then
		UnitFrame.kTargetClass:SetTexCoord( unpack(ClassTexturesCoord.PRIEST) )
		UnitFrame.kTargetClass:SetVertexColor(1,1,1,1)
	else
		UnitFrame.kTargetClass:SetTexCoord(0,0,0,0)
	end
end

function Widget.UpdateAllPlates()
	for plateFrame, UnitFrame in pairs(NamePlates) do
		local kTargetClass = UnitFrame.kTargetClass
		if kTargetClass then
			local unit = TargetCache[UnitFrame.unit]
			local guid = UnitGUID(unit)
			if guid ~= kTargetClass.displayedGUID then
				if guid and UnitIsPlayer(unit) and not UnitIsUnit(unit,'player') then
					local _, class = UnitClass(unit)
					kTargetClass:SetTexCoord( unpack(ClassTexturesCoord[class or 0] or CoordEmpty) )
				else
					kTargetClass:SetTexCoord( 0,0,0,0 )
				end
				kTargetClass.displayedGUID = guid
			end
		end
	end
end

function Widget.ResetAllPlates()
	for plateFrame, UnitFrame in pairs(NamePlates) do
		local kTargetClass = UnitFrame.kTargetClass
		if kTargetClass and kTargetClass.displayedGUID then
			kTargetClass.displayedGUID = nil
			kTargetClass:SetTexCoord( 0,0,0,0 )
		end
	end
end

function Widget.UpdateTracking()
	local disabled =  not (addon.InCombat and addon.InGroup)
	if disabled ~= not timer:IsPlaying() then
		timer:SetPlaying(not disabled)
		if disabled then Widget.ResetAllPlates() end
	end
end

function Widget.Enable()
	timer = timer or addon.CreateTimer( .1, Widget.UpdateAllPlates )
	addon:RegisterMessage( 'GROUP_TYPE_CHANGED', Widget.UpdateTracking )
	addon:RegisterMessage( 'COMBAT_START', Widget.UpdateTracking )
	addon:RegisterMessage( 'COMBAT_END', Widget.UpdateTracking )
	UpdateTracking()
end

function Widget.Disable()
	timer:SetPlaying(false)
	addon:UnregisterMessage( 'GROUP_TYPE_CHANGED', Widget.UpdateTracking )
	addon:UnregisterMessage( 'COMBAT_START', Widget.UpdateTracking )
	addon:UnregisterMessage( 'COMBAT_END', Widget.UpdateTracking )
end

addon:RegisterWidget( 'kTargetClass', Widget )

