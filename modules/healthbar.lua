
local addon = KiwiPlates

local TexCache = addon.TexCache

local Widget = {
	Name = 'Health Bar',
	Color = addon.ColorWhite,
	ColorStatus = 'reaction',
	Enabled = true,
}

local function ForceHide(self)
	self:Hide()
end

function Widget.Create(UnitFrame)
	local healthBar = UnitFrame.healthBar
	local layer, level = healthBar.barTexture:GetDrawLayer()
	local kHealthBar = healthBar:CreateTexture(nil, layer, nil, level+1)
	kHealthBar:SetPoint("TOPLEFT", healthBar.barTexture, "TOPLEFT")
	kHealthBar:SetPoint("BOTTOMRIGHT", healthBar.barTexture, "BOTTOMRIGHT")
	kHealthBar.SetWidgetColor = kHealthBar.SetVertexColor
	UnitFrame.kkHealthBar = kHealthBar
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
	local kHealthBar = UnitFrame.kkHealthBar
	local healthBar = UnitFrame.healthBar
	if enabled then
		UnitFrame.kHealthBar = kHealthBar
		if db.kHealthBar_color_status~='blizzard' then
			healthBar.barTexture:SetColorTexture(0,0,0,0)
			kHealthBar:SetTexture( TexCache[db.healthBarTexture] )
			kHealthBar:Show()
		else
			healthBar.barTexture:SetTexture( TexCache[db.healthBarTexture] )
			kHealthBar:Hide()
		end
		healthBar:SetScript('OnShow', nil)
	elseif kHealthBar then
		UnitFrame.kHealthBar = nil
		healthBar:Hide()
		kHealthBar:Hide()
		healthBar:SetScript('OnShow', ForceHide)
	end
end

addon:RegisterWidget( 'kHealthBar', Widget )

