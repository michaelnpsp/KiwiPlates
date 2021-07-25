
local addon = KiwiPlates

local HiddenFrame = addon.HiddenFrame

local Widget = {
	Name = 'Raid Target Icon',
	Enabled = true,
}

function Widget.Create(UnitFrame)
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
	local RaidTargetFrame = UnitFrame.RaidTargetFrame
	if enabled then
		RaidTargetFrame.RaidTargetIcon:SetParent(RaidTargetFrame)
		RaidTargetFrame:SetPoint("RIGHT", frameAnchor, "LEFT", db.raidTargetOffsetX or 154, db.raidTargetOffsetY or 0);
		RaidTargetFrame:SetSize( db.raidTargetSize or 20, db.raidTargetSize or 20 )
		RaidTargetFrame:Show()
	else
		RaidTargetFrame.RaidTargetIcon:SetParent(HiddenFrame) -- we cannot simply Hide() this frame because our widgets are parented to it
	end
end

addon:RegisterWidget( 'RaidTargetFrame', Widget, true )

