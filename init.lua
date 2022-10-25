-----------------------------------------------------------------------------------------------
--
-- KiwiPlates addon @2012-2018 MiCHaeL
--
-----------------------------------------------------------------------------------------------

local addon = CreateFrame('Frame')
addon.addonName = ...
local versionCli = select(4,GetBuildInfo())
addon.isClassic = versionCli<40000 -- vanilla or tbc or wrath
addon.isVanilla = versionCli<20000
addon.isTBC     = versionCli>=20000 and versionCli<30000
addon.isWrath   = versionCli>=30000 and versionCli<40000
addon.isWoW90   = versionCli>=90000
local versionToc = GetAddOnMetadata(addon.addonName,'Version')
addon.versionToc = versionToc=='@project-version@' and 'Dev' or 'v'..versionToc

----------------------------------------------------------------
-- Messages management
----------------------------------------------------------------

do
	local type = type
	local tremove = table.remove
	local messages = {}

	function addon:SendMessage(msg, ...)
		local registry = messages[msg]
		if registry then
			for i=#registry,1,-1 do
				registry[i](...)
			end
		end
	end

	function addon:RegisterMessage(msg, callback)
		local registry = messages[msg]
		if not registry then
			registry = {}
			messages[msg] = registry
		end
		registry[#registry+1] = type(callback)=="function" and callback or self[callback]
	end

	function addon:UnregisterMessage(msg, callback)
		local registry = messages[msg]
		if registry then
			if type(callback)~="function" then
				callback = self[callback]
			end
			for i=#registry,1,-1 do
				if registry[i] == callback then
					tremove(registry, i)
					return
				end
			end
		else
			messages[msg] = nil
		end
	end
end

----------------------------------------------------------------
-- Run Addon
----------------------------------------------------------------

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")

addon:SetScript("OnEvent", function(frame, event, name)
	if event == "ADDON_LOADED" and name == addon.addonName then
		addon.__loaded = true
	end
	if addon.__loaded and IsLoggedIn() then
		addon:UnregisterAllEvents()
		addon:SetScript("OnEvent", function(f, e, ...) local c=f[e]; if c then c(f,...) end end)
		addon:SendMessage('INITIALIZE')
		addon:UnregisterMessage('INITIALIZE')
		addon:SendMessage('ENABLE')
		addon:UnregisterMessage('ENABLE')
	end
end)

----------------------------------------------------------------
-- Publish
----------------------------------------------------------------

_G[addon.addonName] = addon
