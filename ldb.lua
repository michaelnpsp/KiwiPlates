----------------------------------------------------------------
-- KiwiPlates: DataBroker launcher
----------------------------------------------------------------

local addon = KiwiPlates

local DataBroker = LibStub("LibDataBroker-1.1", true)
if not DataBroker then return end

-- databroker
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
		tooltip:AddLine("|cFF7FFF72Kiwi Plates|r")
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
