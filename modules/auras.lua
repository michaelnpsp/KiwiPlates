----------------------------------------------------------------
-- KiwiPlates: auras
----------------------------------------------------------------

local addon = KiwiPlates

local C_GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit

local apiHasDurations = not addon.isVanilla
local apiHasBuffs     = not addon.isClassic
local CreateFrame = CreateFrame
local UnitReaction = UnitReaction
local format = string.format
local isVanilla = addon.isVanilla

addon.defaults.auras = { enabled = "custom", buffsCentered = true }

local hideBlizzard
local buffsCentered
local buffsGlobalList
local buffsGlobalSpecial
local buffsDisplayStealable

local ExtraUnits = {}
local targetUnitFrame = CreateFrame('Frame')

local function HideBlizzBuffFrame(self)
	if hideBlizzard then
		self:Hide()
	end
end

local function OnEnter(self)
	local parent = self:GetParent()
	NamePlateTooltip:SetOwner(self, "ANCHOR_LEFT");
	NamePlateTooltip:SetUnitAura(parent.unit, self:GetID(), self.filter or parent.filter)
	self.UpdateTooltip = OnEnter
end

local function OnLeave()
	NamePlateTooltip:Hide()
end

local function CreateBuffFrame(UnitFrame)
	if apiHasBuffs then
		UnitFrame.__BlizzBuffFrameHidden = true
		UnitFrame.BuffFrame:HookScript('OnShow',HideBlizzBuffFrame )
	end
	local buffFrame = CreateFrame( 'Frame', nil, UnitFrame )
	buffFrame.buffList = {}
	UnitFrame.__buffFrame = buffFrame
	buffFrame:Show()
	return buffFrame
end

local function DisableBlizAuras(UnitFrame)
	if apiHasBuffs and not UnitFrame.__BlizzBuffFrameHidden then
		UnitFrame.__BlizzBuffFrameHidden = true
		UnitFrame.BuffFrame:HookScript( 'OnShow',HideBlizzBuffFrame )
	end
end

local function LayoutAuras(UnitFrame, db)
	local buffFrame = UnitFrame.__buffFrame or CreateBuffFrame(UnitFrame)
	local buffList  = buffFrame.buffList
	local buffMax   = #buffList
	local w, h, s = db.buffsWidth or 26, db.buffsHeight or 20, db.buffsSpacing or 2
	if buffMax>0 then
		local x = w+s
		for buffIndex = buffMax, 1, -1 do
			local buff = buffList[buffIndex]
			buff:SetSize( w, h )
			buff:SetPoint( 'BOTTOMLEFT', buffFrame, 'BOTTOMLEFT', (buffIndex-1) * x, 0 )
			buff.Icon:SetSize( w-2, h-2 )
			buff.Icon:SetTexCoord( 0.1, 0.9, 0.1, 0.9 )
			buff.Cooldown:SetSize(w-2,h-2)
		end
	end
	buffFrame:ClearAllPoints()
	if buffsCentered then
		buffFrame:SetSize( (buffList.__buffMax or 1)*(w+s)-s, h )
		buffFrame:SetPoint("BOTTOM", UnitFrame.healthBar, "TOP", 0, db.buffsOffsetY or 14)
	else
		buffFrame:SetSize( 1, h )
		buffFrame:SetPoint("BOTTOMLEFT", UnitFrame.healthBar, "TOPLEFT", db.buffsOffsetX or 0, db.buffsOffsetY or 14)
	end
	buffFrame:Show()
end

do -- UNIT_AURA event
	local NamePlatesByUnit = addon.NamePlatesByUnit
	local UnitAura = apiHasDurations and UnitAura or LibStub("LibClassicDurations").UnitAuraDirect
	local UnitIsUnit = UnitIsUnit
	local UnitReaction = UnitReaction
	local CooldownFrame_Set = CooldownFrame_Set
	local db, buffFrame, buffList, buffIndex
	local name, texture, count, duration, expiration, isBuf, isSteal, _
	local buffsWidth, buffsHeight, buffsSpacing
	local buffCountTotal = 0
	local BuffTemplate = apiHasBuffs and "NameplateBuffButtonTemplate" or "KiwiPlateBuffButtonTemplate"

	local function CreateAura(type, index, filter)
		local buff = buffList[buffIndex]
		if not buff then
			buff = CreateFrame("Frame", 'KiwiPlatesNamePlateBuff'..buffCountTotal, buffFrame, BuffTemplate)
			buff:SetScript("OnEnter", OnEnter)
			buff:SetScript("OnLeave", OnLeave)
			buff:SetScript('OnUpdate', nil)
			buff.layoutIndex = buffIndex
			buff:SetSize( buffsWidth, buffsHeight )
			buff:SetPoint( 'BOTTOMLEFT', buffFrame, 'BOTTOMLEFT', (buffIndex-1) * (buffsWidth+buffsSpacing), 0 )
			buff.Icon:SetSize( buffsWidth-2, buffsHeight-2 )
			buff.Icon:SetTexCoord( 0.1, 0.9, 0.1, 0.9 )
			buff.Cooldown:SetSize( buffsWidth-2,buffsHeight-2 )
			buff:SetMouseClickEnabled(false)
			buff.Border:SetVertexColor(1,1,1,1)
			buffList[buffIndex] = buff
			buffCountTotal = buffCountTotal + 1
		end
		buff:SetID(index)
		buff.name = name
		buff.filter = filter
		buff.Icon:SetTexture(texture)
		if type==0 then -- debuff
			buff.Border:SetColorTexture(0,0,0)
		elseif type==1 then -- buff stealable
			buff.Border:SetColorTexture(0,1,0)
		elseif type==2 then -- buff special list
			buff.Border:SetColorTexture(.2,1,1)
		end
		if count > 1 then
			buff.CountFrame.Count:SetText(count)
			buff.CountFrame.Count:Show()
		else
			buff.CountFrame.Count:Hide()
		end
		CooldownFrame_Set(buff.Cooldown, expiration-duration, duration, duration>0, true)
		buff:Show()
		buffIndex = buffIndex + 1
	end

	function addon.UNIT_AURA(_,unit)
		local UnitFrame = NamePlatesByUnit[unit] or ExtraUnits[unit]
		if not UnitFrame then return end
		db = UnitFrame.__skin

		buffIndex    = 1
		buffFrame    = UnitFrame.__buffFrame or CreateBuffFrame(UnitFrame)
		buffList     = buffFrame.buffList
		buffsWidth   = db.buffsWidth or 26
		buffsHeight	 = db.buffsHeight or 20
		buffsSpacing = db.buffsSpacing or 2

		local filter
		if UnitIsUnit("player", unit) then
			filter = "HELPFUL|INCLUDE_NAME_PLATE_ONLY"
		else
			local reaction = UnitReaction("player", unit) or 5
			if reaction<5 then
				local buffsSpecial = db.buffsSpecial or buffsGlobalSpecial
				if buffsDisplayStealable or buffsSpecial then
					for i = 1, 8 do
						name, texture, count, _, duration, expiration, _, isSteal = UnitAura(unit, i, "HELPFUL")
						if not name then break end
						if buffsDisplayStealable and (isSteal or isVanilla) then
							CreateAura(1, i, "HELPFUL")
						elseif buffsSpecial and buffsSpecial[name] then
							CreateAura(2, i, "HELPFUL")
						end
					end
				end
				filter = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY"
			else
				filter = "NONE"
			end
		end
		buffFrame.unit   = unit
		buffFrame.filter = filter
		if filter ~= "NONE" then
			local buffsNames  = db.buffsNames or buffsGlobalList
			local isBlackList = not db.buffsIsWhiteList
			for i = 1, 32 do
				name, texture, count, _, duration, expiration = UnitAura(unit, i, filter)
				if not name then break end
				if isBlackList == not buffsNames[name] then	CreateAura(0, i) end
			end
		end
		-- Hide unused buffs and remember visible buffs count
		for i = buffList.__buffMax or 0, buffIndex, -1 do
			buffList[i]:Hide()
		end
		buffIndex = buffIndex - 1
		buffList.__buffMax = buffIndex

		if buffsCentered then
			buffFrame:SetWidth( buffIndex*(buffsWidth+buffsSpacing)-buffsSpacing )
		end

		if apiHasBuffs then
			local BuffFrame = UnitFrame.BuffFrame
			if BuffFrame then BuffFrame:Hide() end
		end
	end
end

-- target unit frame management

local function UpdateTargetVisibility(plateFrame)
	targetUnitFrame:SetShown( not plateFrame )
end

local function UpdateTargetUnitFrame()
	-- extra auras target unit frame
	local enabled = addon.db.auras.enabled=='custom' and addon.db.auras.targetEnabled
	if enabled then
		ExtraUnits.target = targetUnitFrame
		targetUnitFrame.__skin = addon.db.auras
		targetUnitFrame:SetParent(UIParent)
		targetUnitFrame:SetPoint('CENTER',0,0)
		targetUnitFrame:SetSize(1,1)
		targetUnitFrame.healthBar = targetUnitFrame
		LayoutAuras(targetUnitFrame, targetUnitFrame.__skin)
		addon:RegisterMessage('PLAYER_TARGET_CHANGED', addon.UNIT_AURA)
		if enabled==1 then
			targetUnitFrame:Show()
		else
			addon:RegisterMessage('NAME_PLATE_TARGET_CHANGED', UpdateTargetVisibility )
			UpdateTargetVisibility( C_GetNamePlateForUnit('target') )
		end
		addon.UNIT_AURA(nil,'target')
	else
		ExtraUnits.target = nil
		targetUnitFrame.__skin = nil
		targetUnitFrame:SetParent(nil)
		targetUnitFrame:ClearAllPoints()
		targetUnitFrame:Hide()
		addon:UnregisterMessage('PLAYER_TARGET_CHANGED', addon.UNIT_AURA)
		addon:UnregisterMessage('NAME_PLATE_TARGET_CHANGED', UpdateTargetVisibility )
	end
end


-- Init
addon:RegisterMessage('INITIALIZE', function()
	local enabled = addon.db.auras.enabled
	if enabled=="blizzard" then -- blizzard auras
		NamePlateDriverFrame:RegisterEvent('UNIT_AURA')
		addon:UnregisterMessage('NAME_PLATE_UNIT_ADDED',  addon.UNIT_AURA)
		addon:UnregisterMessage('PLAYER_TARGET_ACQUIRED', addon.UNIT_AURA)
		addon:UnregisterMessage('PLATE_SKINNED', LayoutAuras )
		addon:UnregisterMessage('PLATE_SKINNED', DisableBlizAuras )
		addon:UnregisterEvent('UNIT_AURA')
		hideBlizzard = false
	elseif enabled=="custom" then -- user defined auras
		NamePlateDriverFrame:UnregisterEvent('UNIT_AURA')
		addon:UnregisterMessage('PLATE_SKINNED', DisableBlizAuras )
		addon:RegisterMessage('PLATE_SKINNED', LayoutAuras)
		addon:RegisterMessage('NAME_PLATE_UNIT_ADDED',  addon.UNIT_AURA)
		addon:RegisterMessage('PLAYER_TARGET_ACQUIRED', addon.UNIT_AURA)
		addon:RegisterEvent('UNIT_AURA')
		if addon.isVanilla then LibStub("LibClassicDurations"):Register(addon) end
		hideBlizzard = true
	else  -- no auras
		NamePlateDriverFrame:UnregisterEvent('UNIT_AURA')
		addon:UnregisterEvent('UNIT_AURA')
		addon:UnregisterMessage('NAME_PLATE_UNIT_ADDED',  addon.UNIT_AURA)
		addon:UnregisterMessage('PLAYER_TARGET_ACQUIRED', addon.UNIT_AURA)
		addon:UnregisterMessage('PLATE_SKINNED', LayoutAuras )
		addon:RegisterMessage('PLATE_SKINNED', DisableBlizAuras )
		hideBlizzard = true
	end
end )

-- Update
addon:RegisterMessage('UPDATE', function()
	buffsCentered = addon.db.auras.buffsCentered
	buffsDisplayStealable = addon.db.auras.buffsDisplayStealable
	buffsGlobalList    = addon.db.auras.buffsNames or {}
	buffsGlobalSpecial = addon.db.auras.buffsSpecial
	UpdateTargetUnitFrame()
end )

--=============================================================================
-- configuration options
--=============================================================================

local function aurasDisabled()
	return addon.db.auras.enabled~='custom'
end


local ENABLED = {
		type = 'select',
		order = 0.1,
		width = 'full',
		name = 'Auras Display Behaviour',
		get = function()
			local v = addon.db.auras.enabled
			return (v=='blizzard' and 1) or (v=='custom' and 2) or 3
		end,
		set = function(info, v)
			addon.db.auras.enabled = (v==1 and "blizzard") or (v==2 and "custom") or false
			ReloadUI()
		end,
		values = { addon.FormatTitle('Blizzard Default'), addon.FormatTitle('User Defined'), addon.FormatTitle('Hide Auras') },
		confirm = function() return "An UI Reload is required to change this option. Are you sure ?" end,
}


local NAMEPLATES = {
	buffsOffsetX =  {
		type = 'range', order = 1, name = 'X Adjust', softMin = -64, softMax = 64, step = 1,
		get = function() return addon:GetSkin().buffsOffsetX or 0 end,
		set = function(info,value)
			addon:GetSkin().buffsOffsetX = value~=0 and value or nil
			addon:Update()
		end,
	},
	buffsOffsetY =  {
		type = 'range', order = 2, name = 'Y Adjust', softMin = -64, softMax = 64, step = 1,
		get = function() return addon:GetSkin().buffsOffsetY or 14 end,
		set = function(info,value)
			addon:GetSkin().buffsOffsetY = value
			addon:Update()
		end,
	},
	buffsWidth = {
		type = 'range', order = 3, name = 'Aura Width', min = 0, softMax = 64, step = 1,
		get = function() return addon:GetSkin().buffsWidth or 26 end,
		set = function(info,value)
			addon:GetSkin().buffsWidth = value
			addon:Update()
		end,
	},
	buffsHeight =  {
		type = 'range', order = 4, name = 'Aura Height', min = 1, softMax = 64, step = 1,
		get = function() return addon:GetSkin().buffsHeight or 20 end,
		set = function(info,value)
			addon:GetSkin().buffsHeight = value
			addon:Update()
		end,
	},
	buffsSpacing =  {
		type = 'range', order = 5, name = 'Auras Spacing', min = 0, softMax = 32, step = 1,
		get = function() return addon:GetSkin().buffsSpacing or 2 end,
		set = function(info,value)
			addon:GetSkin().buffsSpacing = value
			addon:Update()
		end,
	},
	buffsCentered = {
		type = "toggle",
		order = 6, width = "normal",
		name = "Centered Auras",
		desc = "Horizontal Center Buffs&Debuffs.",
		get = function() return addon.db.auras.buffsCentered end,
		set = function (_, value)
			addon.db.auras.buffsCentered = value
			addon:Update()
		end,
	},
	buffsDisplayStealable = {
		type = "toggle",
		order = 7, width = "normal",
		name = isVanilla and "Display Enemy Buffs" or "Display Stealable Buffs",
		desc = isVanilla and "Display buffs first highlighted with a green border (only for enemies)." or "Display stealable buffs first highlighted with a green border (only for enemies).",
		get = function() return addon.db.auras.buffsDisplayStealable end,
		set = function (_, value)
			addon.db.auras.buffsDisplayStealable = value or nil
			addon:Update()
		end,
	},
}

--=============================================================================

local TARGET = {
	targetEnabled = {
		type = 'select',
		order = 0.1,
		width = 'double',
		name = 'Display Extra Auras Frame for Target',
		get = function()
			return addon.db.auras.targetEnabled or 3
		end,
		set = function(info, v)
			addon.db.auras.targetEnabled = v~=3 and v or nil
			ReloadUI()
		end,
		values = { addon.FormatTitle('Always Enabled'), addon.FormatTitle('Enabled only when target nameplate is not visible'), addon.FormatTitle('Always Disabled') },
		confirm = function() return "An UI Reload is required to change this option. Are you sure ?" end,
	},
	buffsOffsetX =  {
		type = 'range', order = 1, name = 'X Position', softMin = -512, softMax = 512, step = 1,
		get = function() return addon.db.auras.buffsOffsetX or 0 end,
		set = function(info,value)
			addon.db.auras.buffsOffsetX = value~=0 and value or nil
			addon:Update()
		end,
	},
	buffsOffsetY =  {
		type = 'range', order = 2, name = 'Y Position', softMin = -512, softMax = 512, step = 1,
		get = function() return addon.db.auras.buffsOffsetY or 14 end,
		set = function(info,value)
			addon.db.auras.buffsOffsetY = value
			addon:Update()
		end,
	},
	buffsWidth = {
		type = 'range', order = 3, name = 'Aura Width', min = 0, softMax = 64, step = 1,
		get = function() return addon.db.auras.buffsWidth or 26 end,
		set = function(info,value)
			addon.db.auras.buffsWidth = value
			addon:Update()
		end,
	},
	buffsHeight =  {
		type = 'range', order = 4, name = 'Aura Height', min = 1, softMax = 64, step = 1,
		get = function() return addon.db.auras.buffsHeight or 20 end,
		set = function(info,value)
			addon.db.auras.buffsHeight = value
			addon:Update()
		end,
	},
	buffsSpacing =  {
		type = 'range', order = 5, name = 'Auras Spacing', min = 0, softMax = 32, step = 1,
		get = function() return addon.db.auras.buffsSpacing or 2 end,
		set = function(info,value)
			addon.db.auras.buffsSpacing = value
			addon:Update()
		end,
	},
	buffsCentered = {
		type = "toggle",
		order = 6, width = "normal",
		name = "Centered Auras",
		desc = "Horizontal Center Buffs&Debuffs.",
		get = function() return addon.db.auras.buffsCentered end,
		set = function (_, value)
			addon.db.auras.buffsCentered = value
			addon:Update()
		end,
	},
}

--=============================================================================

local DEBUFFS = {
	buffsBlackList = {
		type = 'select',
		order = 100,
		width = 'normal',
		name = 'Debuffs List Type',
		desc = 'WhiteList: Specified auras will be displayed.\nBlackList: Specified auras will be hidden.',
		get = function()
			return addon:GetSkin().buffsIsWhiteList and 2 or 1
		end,
		set = function(info, v)
			addon:GetSkin().buffsIsWhiteList = (v==2) or nil
			addon:Update()
		end,
		values = { 'BlackList', 'WhiteList' },
	},
	buffsPrivateList = {
		type = "toggle",
		order = 101, width = "normal",
		name = "Use Private List",
		desc = "Use a private aura list specific for this skin instead of the global aura list.",
		get = function() return addon:GetSkin().buffsNamesStr~=nil end,
		set = function (_, value)
			local db = addon:GetSkin()
			db.buffsNamesStr   = value and "" or nil
			db.buffsNames      = nil
			db.buffsSpecialStr = value and "" or nil
			db.buffsSpecial    = nil
		end,
		confirm = function(_, value)
			return (not value) and "Current buffs/debuffs lists will be erased and the global lists will be used. Are you Sure ?" or nil
		end
	},
	buffsNames = {
		type = 'input',
		order = 102,
		name = function() return addon:GetSkin().buffsIsWhiteList and 'Debuffs (WhiteList)' or 'Debuffs (BlackList)' end,
		multiline = 15,
		width = 'full',
		get = function(info)
			return addon:GetSkin().buffsNamesStr or addon.db.auras.buffsNamesStr
		end,
		set = function(info, value)
			local db =  addon:GetSkin().buffsNamesStr and addon:GetSkin() or addon.db.auras
			local names = db.buffsNames or {}
			wipe(names)
			local list  = { strsplit("\n", value) }
			for i=1,#list do
				names[ strtrim(list[i]) ] = true
			end
			db.buffsNames    = names
			db.buffsNamesStr = value
			addon:Update()
		end,
	},
}

--=============================================================================

local BUFFS = {
	buffsSpecialNames = {
		type = 'input',
		order = 103,
		name = 'Buffs (WhiteList)',
		desc = 'Buffs on enemy players to be displayed and highlighted, this is always a whitelist.',
		multiline = 18,
		width = 'full',
		get = function(info)
			return addon:GetSkin().buffsSpecialStr or addon.db.auras.buffsSpecialStr
		end,
		set = function(info, value)
			local db =  addon:GetSkin().buffsSpecialStr and addon:GetSkin() or addon.db.auras
			local names = db.buffsSpecial or {}
			wipe(names)
			local list  = { strsplit("\n", value) }
			for i=1,#list do
				names[ strtrim(list[i]) ] = true
			end
			db.buffsSpecial    = #list>0 and names or nil
			db.buffsSpecialStr = #list>0 and value or ""
			addon:Update()
		end,
	},
}

addon:SetupOptions( 'Skins/Settings', 'Auras', {
	Enabled    = ENABLED,
	Nameplates = { type = "group", order = 14, name = 'Nameplates', args = NAMEPLATES, disabled = aurasDisabled },
	Target     = { type = "group", order = 20, name = 'Target',     args = TARGET ,    disabled = aurasDisabled },
	Debuffs    = { type = "group", order = 30, name = 'Debuffs',    args = DEBUFFS,    disabled = aurasDisabled },
	Buffs      = { type = "group", order = 40, name = 'Buffs',      args = BUFFS  ,    disabled = aurasDisabled },
}, nil, {
	childGroups = 'tab',
} )
