local addon = KiwiPlates

if addon.isClassic then return end

local C_GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

local barFrame, barOffsetY

local function PlacePowerBar(frame)
	if barOffsetY then
		local plateFrame = C_GetNamePlateForUnit('target')
		if plateFrame == frame:GetParent() then
			local healthBar = plateFrame.UnitFrame.healthBar
			barFrame:SetParent(healthBar)
			barFrame:ClearAllPoints()
			barFrame:SetPoint('TOP', healthBar,'BOTTOM', 0, barOffsetY)
		end
	end
end

addon:RegisterMessage('ENABLE', function()
	if addon.db.general.resourceBarOffset then
		local _, class = UnitClass('player')
		barFrame =  (class=='MAGE'    and ClassNameplateBarMageFrame) or
					(class=='MONK'    and ClassNameplateBarWindwalkerMonkFrame) or
					(class=='PALADIN' and ClassNameplateBarPaladinFrame) or
					(class=='DRUID'   and ClassNameplateBarRogueDruidFrame) or
					(class=='ROGUE'   and ClassNameplateBarRogueDruidFrame) or
					(class=='WARLOCK' and ClassNameplateBarWarlockFrame)
		if barFrame then
			barFrame:HookScript('OnUpdate', PlacePowerBar )
			addon:RegisterMessage('UPDATE', function()
				barOffsetY = addon.db.general.resourceBarOffset
				if barOffsetY and C_GetNamePlateForUnit('target') then
					barFrame:SetParent( C_GetNamePlateForUnit('target') )
				end
			end)
		end
	end
end )

