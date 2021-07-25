
local addon = KiwiPlates

local bor = bit.bor
local band = bit.band
local rshift = bit.rshift
local UnitGUID = UnitGUID
local GetNumSubgroupMembers = GetNumSubgroupMembers

local NamePlates = addon.NamePlates
local NamePlatesByGUID = addon.NamePlatesByGUID
local UnitGroupRolesAssigned = addon.UnitGroupRolesAssigned

local timer
local masks = {}
local bits  = { TANK = 8, HEALER = 16 }
local units = { 'party1', 'party2', 'party3','party4', party1 = 'party1target', party2 = 'party2target', party3 = 'party3target', party4 = 'party4target' }

local Widget = {
	Name = 'Attackers',
	Enabled = false,
}

function Widget.Create(UnitFrame)
	local RaidTargetFrame = UnitFrame.RaidTargetFrame
	local kAttackers = RaidTargetFrame:CreateTexture()
	kAttackers:SetTexture("Interface\\Addons\\KiwiPlates\\media\\roles")
	kAttackers:SetTexCoord( 0,0,0,0 )
	UnitFrame.kkAttackers= kAttackers
end

function Widget.Layout(UnitFrame, frameAnchor, db, enabled)
	local kAttackers = UnitFrame.kkAttackers
	if enabled then
		local size = db.attackersIconSize or 14
		kAttackers:ClearAllPoints()
		kAttackers:SetSize( band(UnitFrame.__attackers or 0, 7) * size , size )
		kAttackers:SetPoint( db.attackersAnchorPoint or 'CENTER', frameAnchor, 'CENTER', db.attackersOffsetX or 0, db.attackersOffsetY or 0)
		kAttackers:Show()
		UnitFrame.kAttackers = kAttackers
	elseif kAttackers then
		UnitFrame.kAttackers = nil
		kAttackers:Hide()
	end
end

function Widget.Update(UnitFrame)
	local kAttackers = UnitFrame.kAttackers
	local mask = addon.cfgTestSkin and 28 or UnitFrame.__attackers
	local w = band(mask,7)
	local h = rshift(mask,3) * (20/128)
	kAttackers:SetTexCoord( 0, w*(20/128), h, h+(20/128) )
	kAttackers:SetWidth( w * (UnitFrame.__skin.attackersIconSize or 14) )
end

function Widget.UpdateAllPlates()
	wipe(masks)
	for i=GetNumSubgroupMembers(),1,-1 do
		local unit = units[i]
		local guid = UnitGUID( units[unit] ) -- target guid
		if guid and NamePlatesByGUID[guid] then
			local role = UnitGroupRolesAssigned(unit)
			local mask = masks[guid] or 0
			local bit  = bits[role]
			masks[guid] = bit and (bor(mask,bit)+1) or (mask+1)
		end
	end
	local Update = Widget.Update
	for plateFrame, UnitFrame in pairs(NamePlates) do
		local kAttackers = UnitFrame.kAttackers
		if kAttackers then
			local mask = masks[UnitFrame.__guid] or 0
			if mask~=UnitFrame.__attackers then
				UnitFrame.__attackers = mask
				Update(UnitFrame)
			end
		end
	end
end

function Widget.ResetAllPlates()
	for plateFrame, UnitFrame in pairs(NamePlates) do
		UnitFrame.__attackers = 0
	end
end

function Widget.UpdateTracking()
	local disabled =  not (addon.InCombat and addon.InGroup)
	if disabled ~= not timer:IsPlaying() then
		timer:SetPlaying(not disabled)
		if disabled then Widget.ResetAllPlates() end
	end
end

function Widget.Enable()
	timer = timer or addon.CreateTimer( .2, Widget.UpdateAllPlates )
	addon:RegisterMessage( 'GROUP_TYPE_CHANGED', Widget.UpdateTracking )
	addon:RegisterMessage( 'COMBAT_START', Widget.UpdateTracking )
	addon:RegisterMessage( 'COMBAT_END', Widget.UpdateTracking )
end

function Widget.Disable()
	timer:SetPlaying(false)
	addon:UnregisterMessage( 'GROUP_TYPE_CHANGED', Widget.UpdateTracking )
	addon:UnregisterMessage( 'COMBAT_START', Widget.UpdateTracking )
	addon:UnregisterMessage( 'COMBAT_END', Widget.UpdateTracking )
end

addon:RegisterWidget( 'kAttackers', Widget )

