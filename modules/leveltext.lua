
local addon = KiwiPlates

local FontCache = addon.FontCache
local Classifications = addon.Classifications

local Widget = {
	Name = 'Level Text',
	Color = addon.ColorWhite,
	ColorStatus = 'level',
	Enabled = true,
}

function Widget.Create(UnitFrame)
	local text  = UnitFrame.RaidTargetFrame:CreateFontString(nil, "BORDER")
	text.SetWidgetColor = text.SetTextColor
	text:SetShadowOffset(1,-1)
	text:SetShadowColor(0,0,0, 1)
	UnitFrame.kkLevelText = text
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
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
end

function Widget.Update(UnitFrame)
	local kLevelText =  UnitFrame.kLevelText
	if kLevelText then
		local level = UnitFrame.__level
		local class = UnitFrame.__classification
		local text  = level<0 and '??' or level .. (Classifications[class] or '')
		kLevelText:SetText( text )
	end
end

function Widget.Enable()
	addon:RegisterMessage( 'UNIT_CLASSIFICATION_CHANGED', Widget.Update )
end

function Widget.Disable()
	addon:UnregisteMessage( 'UNIT_CLASSIFICATION_CHANGED', Widget.Update )
end

addon:RegisterWidget( 'kLevelText', Widget )


