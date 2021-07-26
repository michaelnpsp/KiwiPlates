
local addon = KiwiPlates

local cfgTipProfessionLine

local FontCache = addon.FontCache

local FormatNameText
do
	local tip = CreateFrame('GameTooltip','KiwiPlatesNameTooltip',UIParent,'GameTooltipTemplate')
	local pattern = strmatch(TOOLTIP_UNIT_LEVEL,'^(.-) ') -- invalid pattern
	local gsub    = string.gsub
	local strtrim = strtrim
	local strfind = strfind
	local UnitPVPName = UnitPVPName
	local GetGuildInfo = GetGuildInfo
	local UnitIsPlayer = UnitIsPlayer
	local UnitIsOtherPlayersPet = UnitIsOtherPlayersPet
	local NameTags = {}
	local function GetNPCProfession(unit)
        tip:SetOwner(UIParent,ANCHOR_NONE)
        tip:SetUnit(unit)
        local text = cfgTipProfessionLine:GetText()
	    tip:Hide()
		return text and not strfind(text,pattern) and text or ''
    end
	function FormatNameText(UnitFrame, mask)
		local unit = UnitFrame.unit
		NameTags['$n'] = UnitFrame.__name
		NameTags['$c'] = UnitClass(unit) or ''
		if UnitIsPlayer(unit) then
			NameTags['$p'] = ''
			NameTags['$t'] = UnitPVPName(unit)
			NameTags['$g'] = GetGuildInfo(unit) or ''
		else
			NameTags['$g'] = ''
			NameTags['$t'] = UnitFrame.__name
			NameTags['$p'] = UnitIsOtherPlayersPet(unit) and '' or GetNPCProfession(unit)
		end
		return strtrim(gsub(mask,"%$%l",NameTags))
	end
end

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

function Widget.Enable()
	cfgTipProfessionLine = GetCVarBool('colorblindmode') and KiwiPlatesNameTooltipTextLeft3 or KiwiPlatesNameTooltipTextLeft2
end

addon:RegisterWidget( 'kNameText', Widget )

