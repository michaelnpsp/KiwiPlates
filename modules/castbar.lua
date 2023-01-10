
local addon = KiwiPlates

local FontCache = addon.FontCache
local TexCache = addon.TexCache
local SetBorderTexture = addon.SetBorderTexture

local fixSpellText = addon.isTBC or addon.isWrath

local Widget = {
	Name = 'Casting Bar',
	Enabled = true,
}

function Widget.Create(UnitFrame)
	local castBar = UnitFrame.castBar or UnitFrame.CastBar -- retail or TBC castbar
	if not castBar then -- vanilla
		castBar = CreateFrame("StatusBar", nil, UnitFrame, "KiwiPlatesCastingBarFrameTemplate")
	elseif UnitFrame.CastBar then -- tbc or wrath
		UnitFrame.castBar = castBar -- for some reason the castbar name is uppercased in tbc
		castBar.Border:Hide() -- we cannot reuse tbc border because blizzard code is continuosly changing the border width
		castBar:ClearAllPoints()
	end
	if addon.isClassic then -- vanilla or tbc
		castBar:SetPoint("TOPLEFT",  UnitFrame, "BOTTOMLEFT",  0, 0)
		castBar:SetPoint("TOPRIGHT", UnitFrame, "BOTTOMRIGHT", 0, 0)
	end
	if addon.cfgClassicBorders then
		castBar.cBorder = addon.isVanilla and castBar.Border or castBar:CreateTexture(nil, 'ARTWORK')
		castBar.cBorder:SetDrawLayer('ARTWORK',7)
	end
	UnitFrame.kkCastBar = castBar
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
	if enabled then
		local castBar = UnitFrame.kkCastBar
		local cbHeight = db.castBarHeight or 10
		castBar.BorderShield:SetSize(cbHeight, cbHeight)
		castBar.Icon:ClearAllPoints()
		castBar.Icon:SetPoint("BOTTOMRIGHT", castBar, "BOTTOMLEFT", db.castBarIconOffsetX or -1, db.castBarIconOffsetY or 0)
		castBar.Icon:SetSize(db.castBarIconSize or cbHeight, db.castBarIconSize or cbHeight)
		castBar.Icon:SetShown(db.castBarIconEnabled)
		if addon.isClassic then
			castBar:SetStatusBarTexture( TexCache[db.castBarTexture] ) -- in retail texture is overrided on cast start so this is useless
		end
		castBar.Text:SetFont( FontCache[db.castBarFontFile or 'Roboto Condensed Bold'], db.castBarFontSize or 8, db.castBarFontFlags or 'OUTLINE' )
		if addon.cfgClassicBorders then
			SetBorderTexture( castBar, castBar.cBorder, db.castBarBorderTexture, db.castBarBorderColor or ColorWhite )
		else
			castBar.Icon:SetTexCoord( 0.1, 0.9, 0.1, 0.9 )
		end
		if fixSpellText then -- tbc or wrath
			castBar:SetScript('OnShow', nil) -- ugly fix, OnShow blizzard code changes the icon size and messes with the spell text.
			castBar.Text:Show()
		end
		UnitFrame.kCastBar = castBar
	else
		UnitFrame.kCastBar = nil
	end
end

addon:RegisterWidget( 'kCastBar', Widget )

