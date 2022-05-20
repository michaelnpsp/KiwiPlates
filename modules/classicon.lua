
local addon = KiwiPlates

local CoordEmpty = addon.CoordEmpty
local ClassTexturesCoord = addon.ClassTexturesCoord

local Widget = {
	Name = 'Class Icon',
	Enabled = true,
}

function Widget.Create(UnitFrame)
	UnitFrame.kkIcon = UnitFrame.RaidTargetFrame:CreateTexture()
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
	local kIcon = UnitFrame.kkIcon
	if enabled then
		kIcon:ClearAllPoints()
		kIcon:SetSize( db.classIconSize or 14, db.classIconSize or 14 )
		kIcon:SetPoint('RIGHT', frameAnchor, 'LEFT', db.classIconOffsetX or 0, db.classIconOffsetY or 0)
		if db.classIconUserTexture then
			kIcon:SetTexture(db.classIconUserTexture)
			kIcon:SetTexCoord(0,1,0,1)
		else
			kIcon:SetTexture(db.classIconTexture or 'Interface\\Addons\\KiwiPlates\\media\\classif')
			kIcon:SetTexCoord(0,0,0,0)
		end
		UnitFrame.kIcon = kIcon
		kIcon:Show()
	elseif kIcon then
		UnitFrame.kIcon = nil
		kIcon:Hide()
	end
end

function Widget.Update(UnitFrame)
	local kIcon = UnitFrame.kIcon
	if kIcon then
		local skin = UnitFrame.__skin
		if not skin.classIconUserTexture then
			local key
			if addon.cfgTestSkin then
				key = UnitFrame.__type=='Player' and UnitFrame.__class or 'elite'
			else
				if UnitFrame.__type=='Player' then
					if not skin.classIconDisablePlayers then
						key = UnitFrame.__class
					end
				elseif not skin.classIconDisableNPCs then
					key = UnitFrame.__classification
				end
			end
			kIcon:SetTexCoord( unpack(ClassTexturesCoord[key] or CoordEmpty) )
		end
	end
end

function Widget.Enable()
	addon:RegisterMessage( 'UNIT_CLASSIFICATION_CHANGED', Widget.Update )
end

function Widget.Disable()
	addon:UnregisterMessage( 'UNIT_CLASSIFICATION_CHANGED', Widget.Update )
end

addon:RegisterWidget( 'kIcon', Widget )

