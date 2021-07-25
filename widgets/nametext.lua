
local addon = KiwiPlates

local FontCache = addon.FontCache
local FormatNameText = addon.FormatNameText

local Widget = {
	Name = 'Name Text',
	Color = addon.ColorWhite,
	ColorStatus = 'color',
	Enabled = true,
}

function Widget.Create(UnitFrame)
	local text = UnitFrame.RaidTargetFrame:CreateFontString(nil, "BORDER")
	text.SetWidgetColor = text.SetTextColor
	text:SetShadowOffset(1,-1)
	text:SetShadowColor(0,0,0, 1)
	UnitFrame.kkNameText = text
	UnitFrame.name:SetParent(addon.HiddenFrame)
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
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
end

function Widget.Update(UnitFrame)
	local mask = UnitFrame.__skin.nameFormat
	UnitFrame.kNameText:SetText( mask and FormatNameText(UnitFrame, mask) or UnitFrame.__name )
end

addon:RegisterWidget( 'kNameText', Widget )

