
local addon = KiwiPlates

local format = format
local FontCache = addon.FontCache

local HealthTags = { ['$p'] = '', ['$h'] = '', ['$m'] = '' } -- percent, health, maxhealth

local Widget = {
	Name = 'Health Text',
	Color = addon.ColorWhite,
	ColorStatus = 'color',
	Enabled = true,
}

function Widget.Create(UnitFrame)
	local text = UnitFrame.RaidTargetFrame:CreateFontString(nil, "BORDER")
	text.SetWidgetColor = text.SetTextColor
	text:SetShadowOffset(1,-1)
	text:SetShadowColor(0,0,0, 1)
	UnitFrame.kkHealthText = text
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
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
end

function Widget.Update(UnitFrame)
	local unit = UnitFrame.unit
	local h = UnitHealth(unit)
	local m = UnitHealthMax(unit)
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
	return p
end

addon:RegisterWidget( 'kHealthText', Widget )

