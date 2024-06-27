----------------------------------------------------------------
-- KiwiPlates: DataBroker launcher
----------------------------------------------------------------

local addon = KiwiPlates

local DataBroker = LibStub("LibDataBroker-1.1", true)
if not DataBroker then return end

-- blizzard compartment
if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
	AddonCompartmentFrame:RegisterAddon({
		text = "KiwiPlates",
		icon = "Interface\\AddOns\\KiwiPlates\\media\\kiwi.tga",
		func = function() addon:OnChatCommand("kiwiplates") end,
		notCheckable = true,
	})
end

-- databroker
local GetAddOnInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
local LDB = DataBroker:NewDataObject("KiwiPlates", {
	type  = "launcher",
	label = GetAddOnInfo("KiwiPlates", "Title"),
	icon  = "Interface\\AddOns\\KiwiPlates\\media\\kiwi",
	OnClick = function(self, button)
		if button=="LeftButton" then
			addon:OnChatCommand("kiwiplates")
		elseif button=="RightButton" then
			addon:MenuShow()
		end
	end,
	OnTooltipShow = function(tooltip)
		tooltip:AddDoubleLine("Kiwi Plates", addon.versionToc, 0.5, 1, 0.45 )
		tooltip:AddLine("|cFFff4040Left Click|r to open configuration\n|cFFff4040Right Click|r to open menu", 0.2, 1, 0.2)
	end,
} )

-- popup menu
do
	local function SetVisibility(self)
		if not InCombatLockdown() then
			SetCVar(self.value, self.checked() and '0' or '1')
		end
	end
	local menuFrame
	local menuTable = {
		{ 	text = '|cFF7FFF72Kiwi Plates|r',  notCheckable= true, isTitle = true },
		{ 	text = 'Show Enemies',     value = 'nameplateShowEnemies', isNotRadio = true, keepShownOnClick = 1, func = SetVisibility, checked = function() return GetCVar('nameplateShowEnemies')~='0' end },
		{ 	text = 'Show Friends',     value = 'nameplateShowFriends', isNotRadio = true, keepShownOnClick = 1, func = SetVisibility, checked = function() return GetCVar('nameplateShowFriends')~='0' end },
		{ 	text = 'Stack Plates', value = 'nameplateMotion',      isNotRadio = true, keepShownOnClick = 1, func = SetVisibility, checked = function() return GetCVar('nameplateMotion')~='0' end },
		{ 	text = '|cFF7FFF72Minimap Icon|r',  notCheckable= true, isTitle = true },
		{ 	text = 'Icon Visible', value = 'minimapIcon', isNotRadio = true, keepShownOnClick = 1,
			func = function()
				if KiwiPlates.db.minimapIcon.hide then
					KiwiPlates.db.minimapIcon.hide = nil; LibStub("LibDBIcon-1.0"):Show("KiwiPlates")
				else
					KiwiPlates.db.minimapIcon.hide = true; LibStub("LibDBIcon-1.0"):Hide("KiwiPlates")
				end
			end,
			checked = function()
				return not KiwiPlates.db.minimapIcon.hide
			end,
		},
	}
	local EasyMenu_Initialize = EasyMenu_Initialize or function(frame, level, menuList)
		for index = 1, #menuList do
			local value = menuList[index]
			if value.text then value.index = index; UIDropDownMenu_AddButton(value, level) end
		end
	end
	local EasyMenu = EasyMenu or function(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
		if displayMode=='MENU' then menuFrame.displayMode = displayMode end
		UIDropDownMenu_Initialize(menuFrame, EasyMenu_Initialize, displayMode, nil, menuList)
		ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay)
	end
	addon.MenuShow = function()
		menuFrame = menuFrame or CreateFrame("Frame", "KiwiPlatesLDBPopupMenu", UIParent, "UIDropDownMenuTemplate")
		EasyMenu(menuTable, menuFrame, "cursor", 0 , 0, "MENU", 1)
	end
end

-- initialization
addon:RegisterMessage('INITIALIZE', function()
	local icon = LibStub("LibDBIcon-1.0")
	if icon then
		icon:Register("KiwiPlates", LDB, addon.db.minimapIcon)
		addon.minimapIcon = icon
	end
end )
