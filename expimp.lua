----------------------------------------------------------------
-- KiwiPlates: Profile Import&Export
----------------------------------------------------------------

local addon = KiwiPlates

-- Base64 encode&decode, code from https://github.com/Adirelle/LibBase64-1.0 by Adirelle, released under GNU Public License version 3.0.
local base64encode, base64decode
do
	local t = {}
	local strbyte, strchar = strbyte, strchar
	local band, lshift, rshift = bit.band, bit.lshift, bit.rshift
	local decode, encode = {}, {
		[0]='A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
			'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
			'0','1','2','3','4','5','6','7','8','9','+','/'
	}
	for value = 0, 63 do decode[ strbyte(encode[value]) ] = value end
	function base64encode(str)
		local j = 1
		for i = 1, strlen(str), 3 do
			local a, b, c = strbyte(str, i, i+2)
			t[j]   = encode[rshift(a, 2)]
			t[j+1] = encode[band(lshift(a, 4) + rshift(b or 0, 4), 0x3F)]
			t[j+2] = b and encode[band(lshift(b, 2) + rshift(c or 0, 6), 0x3F)] or "="
			t[j+3] = c and encode[band(c, 0x3F)] or "="
			j = j + 4
		end
		return table.concat(t, "", 1, j-1)
	end
	function base64decode(str)
		local j = 1
		for i = 1, strlen(str), 4 do
			local ba, bb, bc, bd = strbyte(str, i, i+3)
			local a, b, c, d = decode[ba], decode[bb], decode[bc], decode[bd]
			t[j] = strchar(lshift(a, 2) + rshift(b, 4))
			t[j+1] = c and strchar(band(lshift(b, 4) + rshift(c, 2), 0xFF)) or ""
			t[j+2] = d and strchar(band(lshift(c, 6) + d, 0xFF)) or ""
			j = j + 3
		end
		return table.concat(t, "", 1, j-1)
	end
end

-- Export&Import functions
local function Export(data)
	data.__addonName = 'KiwiPlates'
	data.__profileName = addon:GetCurrentProfile()
	data.__classicBorders = addon.__db.global.classicBorders
	local str = base64encode( LibStub("AceSerializer-3.0"):Serialize(data) )
	data.__addonName, data.__profileName, data.__classicBorders = nil, nil, nil
	return str
end

local function Import(str, name, silent)
	local sucess, data = LibStub("AceSerializer-3.0"):Deserialize( base64decode( gsub(str,'%s','') ) )
	if sucess and type(data)=='table' and data.__addonName == 'KiwiPlates' and data.__profileName then
		local borders = data.__classicBorders
		name = name or addon:GetUniqueProfileName(data.__profileName)
		data.__addonName, data.__profileName, data.__classicBorders = nil, nil, nil
		addon:CreateNewProfile(name, data)
		if not silent then
			print("KiwiPlates, New Profile imported:", name)
		end
		collectgarbage()
		if not borders ~= not addon.__db.global.classicBorders then
			addon.__db.global.classicBorders = borders or nil
			addon:ConfirmDialog("The UI must be reloaded to activate this profile. Are your sure?", ReloadUI )
		end
	else
		print("KiwiPlates: Error Importing Profile, Wrong Data")
	end
end

local function ShowFrame(title,footer,name,data)
	local AceGUI = LibStub("AceGUI-3.0")
	local frame = AceGUI:Create("Frame")
	frame:SetTitle(title)
	frame:SetStatusText(footer)
	frame:SetLayout("Flow")
	frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	frame:SetWidth(525)
	frame:SetHeight(375)
	local editbox = AceGUI:Create("MultiLineEditBox")
	editbox.editBox:SetFontObject(GameFontHighlightSmall)
	editbox:SetFullWidth(true)
	editbox:SetFullHeight(true)
	frame:AddChild(editbox)
	if data then -- Export
		editbox:SetLabel( string.format('%s (%d chars)', name, strlen(data)) )
		editbox:DisableButton(true)
		editbox:SetText(data)
		editbox.editBox:SetFocus()
		editbox.editBox:HighlightText()
		editbox:SetCallback("OnLeave", function(widget)	widget.editBox:HighlightText(); widget:SetFocus() end)
		editbox:SetCallback("OnEnter", function(widget)	widget.editBox:HighlightText(); widget:SetFocus() end)
	else -- Import
		editbox:SetLabel(title)
		editbox:DisableButton(false)
		editbox.button:SetScript("OnClick", function() frame:Hide(); Import(editbox:GetText()) end)
	end
end

local function ExportProfile()
	ShowFrame("KiwiPlates Profile Export", "Press CTRL-C to copy the profile string to your clipboard", addon:GetCurrentProfile(), Export(addon.db) )
end

local function ImportProfile()
	ShowFrame("KiwiPlates Profile Import", "Press CTRL-V to paste a profile string")
end

-- Options table
addon:SetupOptions( 'Profiles', 'Import&Export', {
	import = {
		type = 'execute',
		order = 1,
		name = 'Import Profile',
		desc = 'Import a profile from text format',
		func = function()
			ImportProfile()
		end,
	},
	export = {
		type = 'execute',
		order = 2,
		name = 'Export Profile',
		desc = 'Export the current profile to text format.',
		func = function()
			ExportProfile()
		end,
	},
} )

-- publish some functions

addon.ImportProfile = function(self, ...) Import(...) end
addon.ExportProfile = function(self, ...) Export(...) end
