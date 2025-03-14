
local addon = KiwiPlates

local SetBorderTexture = addon.SetBorderTexture

--===================================================================================================

-- classic border style (rounded)
local function CreateHealthBorderClassic(UnitFrame)
	local healthBar = UnitFrame.healthBar
	if addon.isClassic then
		local border = healthBar.border:GetRegions()
		border:Hide()
		border:SetParent(nil)
	end
	local border = healthBar:CreateTexture()
	border.widgetName = 'kHealthBorder'
	border:SetTexCoord(0, 1, 0, 1)
	border:SetDrawLayer( healthBar.barTexture:GetDrawLayer(), 7 )
	border:SetParent(healthBar)
	border.SetWidgetColor = border.SetVertexColor
	UnitFrame.kkHealthBorder = border
end

-- retail border style (squared)
local CreateHealthBorderRetail
do
	local BORDER_POINTS = {
		{ "TOPRIGHT",    "TOPLEFT",    0, 1, "BOTTOMRIGHT", "BOTTOMLEFT",  0, -1, "SetWidth" },
		{ "TOPLEFT",     "TOPRIGHT",   0, 1, "BOTTOMLEFT",  "BOTTOMRIGHT", 0, -1, "SetWidth" },
		{ "TOPRIGHT",    "BOTTOMLEFT", 0, 0, "TOPLEFT",     "BOTTOMRIGHT", 0, 0 , "SetHeight" },
		{ "BOTTOMRIGHT", "TOPRIGHT",   0, 0, "BOTTOMLEFT",  "TOPLEFT",     0, 0 , "SetHeight" },
	}

	local function SetBorderColor(border,r,g,b,a)
		border[1]:SetVertexColor(r,g,b,a)
		border[2]:SetVertexColor(r,g,b,a)
		border[3]:SetVertexColor(r,g,b,a)
		border[4]:SetVertexColor(r,g,b,a)
	end

	local function SetBorderSize(border,size)
		if border.size ~= size then
			local frame = border[1]:GetParent()
			for i=1,4 do
				local p = BORDER_POINTS[i]
				local t = border[i]
				t:ClearAllPoints()
				t:SetPoint( p[1], frame, p[2], p[3]*size, p[4]*size )
				t:SetPoint( p[5], frame, p[6], p[7]*size, p[8]*size )
				t[ p[9] ](t, size)
			end
			border.size = size
		end
	end

	local function Hide(border)
		SetBorderColor(border,0,0,0,0)
	end

	function CreateHealthBorderRetail(UnitFrame)
		local frame = UnitFrame.healthBar
		local border = { widgetName= 'kHealthBorder', size=1 }
		for i=1,4 do
			local p = BORDER_POINTS[i]
			local t = frame:CreateTexture(nil, "BACKGROUND")
			t:SetPoint( p[1], frame, p[2], p[3], p[4] )
			t:SetPoint( p[5], frame, p[6], p[7], p[8] )
			t[ p[9] ](t,1)
			t:SetColorTexture(1,1,1,1)
			border[i] = t
		end
		border.SetWidgetColor = SetBorderColor
		border.SetWidgetSize  = SetBorderSize
		border.Hide = Hide
		UnitFrame.kkHealthBorder = border
	end
end

--===================================================================================================

local Widget = {
	Name = 'Health Border',
	Color = addon.ColorBlack,
	ColorStatus = 'color',
	Enabled = true,
}

function Widget.Create(UnitFrame)
	if addon.cfgClassicBorders then
		CreateHealthBorderClassic(UnitFrame)
	else
		CreateHealthBorderRetail(UnitFrame)
	end
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
	local kHealthBorder = UnitFrame.kkHealthBorder
	if enabled then
		if addon.cfgClassicBorders then
			SetBorderTexture(UnitFrame.healthBar, kHealthBorder, db.borderTexture )
			kHealthBorder:Show()
			UnitFrame.kHealthBorder = kHealthBorder
		else
			kHealthBorder:SetWidgetSize( db.borderSize or 1 )
			UnitFrame.kHealthBorder = kHealthBorder
		end
	elseif kHealthBorder then
		UnitFrame.kHealthBorder = nil
		kHealthBorder:Hide()
	end
end

addon:RegisterWidget( 'kHealthBorder', Widget )

