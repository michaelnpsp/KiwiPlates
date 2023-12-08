----------------------------------------------------------------
-- KiwiPlates: Manage SavedVariables Database
----------------------------------------------------------------

local addon = KiwiPlates

local rootDB = { global = {}, profiles = {}, profileChars = {} }

local GetNumSpecializations = not addon.isClassic and GetNumSpecializations or function() return 1 end
local GetSpecialization     = not addon.isClassic and GetSpecialization     or function() return 1 end
local GetSpecializationInfo = not addon.isClassic and GetSpecializationInfo or function() return 1, "Default" end

----------------------------------------------------------------
-- Internal functions
----------------------------------------------------------------

local values, undeletable = {}, {}

local function GetProfiles()
	wipe(values)
	for key in pairs(addon.__db.profiles) do
		values[key] = key
	end
	return values
end

local function GetSpecName(i)
	if i<=GetNumSpecializations() then
		local name = select(2,GetSpecializationInfo(i))
		if i==GetSpecialization() then
			name = name .. ' (active)'
		end
		return name
	else
		return ''
	end
end

local function GetSpecProfile(specIndex)
	return addon.__profileChar[specIndex] or 'default'
end

local function SetSpecProfile(specIndex, key)
	addon.__profileChar[specIndex] = key
	if GetSpecialization() or specIndex == 1 then
		addon:PLAYER_TALENT_UPDATE()
	end
end

----------------------------------------------------------------
-- Initialize Database
----------------------------------------------------------------

addon:RegisterMessage('INITIALIZE', function()
	local key = addon.addonName ..'Db'
	local db = _G[key]
	if not db then
		db = rootDB
		_G[key] = db
	end
	local charKey = UnitName("player") .. " - " .. GetRealmName()
	if not db.profiles['default']  then
		db.profiles['default'] = addon.CopyTable(addon.defaults)
	end
	local profileChar = db.profileChars[charKey]
	if not profileChar then
		profileChar = {}
		for i=1,GetNumSpecializations() or 1 do
			profileChar[i] = 'default'
		end
		db.profileChars[charKey] = profileChar
		if not db.profiles[charKey] then
			db.profiles[charKey] = addon.CopyTable(addon.defaults)
		end
	elseif profileChar[0] then -- fix posible wrong data due to a bug in previous versions
		profileChar[0] = nil
	end
	addon.__profileChar = profileChar
	addon.__db = db
	addon:PLAYER_TALENT_UPDATE()
	if not addon.isClassic then
		addon:RegisterEvent("PLAYER_TALENT_UPDATE")
	end
end )

----------------------------------------------------------------
-- Talent change management
----------------------------------------------------------------

function addon:PLAYER_TALENT_UPDATE()
	local profileKey = self.__profileChar[ GetSpecialization() or 1 ] or 'default'
	if profileKey ~= self.__profileKey then
		local old_db = self.db
		local new_db = self.__db.profiles[profileKey] or self.__db.profiles.default
		local version = new_db.version
		self.__profileKey = profileKey
		self.db = self.CopyTable(self.defaults, new_db )
		new_db.version = version
		if old_db then
			self:OnProfileChanged()
		end
	end
end

----------------------------------------------------------------
-- Public methods
----------------------------------------------------------------

function addon:GetUniqueProfileName(name)
	for key in pairs(self.__db.profiles) do
		if name==key then
			return self:GetUniqueProfileName(name .. '2')
		end
	end
	return name
end

function addon:GetCurrentProfile()
	return self.__profileKey
end

function addon:SetCurrentProfile(name)
	SetSpecProfile( GetSpecialization() or 1, name)
end

function addon:CreateNewProfile(name, data)
	name = strtrim(name)
	if not self.__db.profiles[name] then
		self.__db.profiles[name] = data or self.CopyTable(addon.defaults)
		self:SetCurrentProfile(name)
	end
end

----------------------------------------------------------------
-- Options table
----------------------------------------------------------------

-- profile selection per specialization
local options = addon:SetupOptions( 'Profiles', 'Profiles', {} )
for i=1,6 do
	options['spec'..i] = {
		type   = 'select',
		order  = i,
		name   = function() return GetSpecName(i) end,
		get    = function() return GetSpecProfile(i) end,
		set    = function(_, key) SetSpecProfile(i,key) end,
		hidden = function() return i>GetNumSpecializations() end,
		values = GetProfiles,
	}
end


-- profile database maintenance operations
do
	local kwpLoaded
	local profilesRepo
	local profilesValues = { [0] = "Basic" }
	local newProfileIndex

	addon:SetupOptions( 'Profiles', 'Operations', {
		newDesc = {
			type = 'description',
			order = 0.5,
			name = "\nYou can create a new profile based on the selected profile template.",
		},
		newProfileImage = {
			type = "execute",
			width= "full",
			order = 0.8,
			name = "",
			imageWidth= 512,
			imageHeight= 64,
			image = function() return profilesRepo[newProfileIndex].banner end,
			func =  function() end,
			hidden = function()
				if kwpLoaded==nil then
					kwpLoaded = LoadAddOn("KiwiPlatesProfiles") or false
				end
				return (newProfileIndex or 0) == 0
			end,
		},
		newProfileTemplate = {
			type = 'select',
			name = 'Profile Template',
			order = 0.9,
			get = function()
				return newProfileIndex
			end,
			set = function(info,v)
				newProfileIndex = v
			end,
			values = function()
				return profilesValues
			end,
			hidden = function() return profilesRepo == nil end,
		},
		newProfileName = {
			type = 'input',
			name = 'New Profile Name',
			order = 1,
			get = function() end,
			set = function(info,name)
				local profile = profilesRepo and profilesRepo[newProfileIndex or 0]
				if profile then
					local data = profile[1]
					addon:ImportProfile( type(data)=='function' and data(profile.name) or data, name, true)
					newProfileIndex = nil
				else
					addon:CreateNewProfile(name)
				end
			end,
			validate = function(info,name)
				name = strtrim(name)
				return strlen(name)>2 and not addon.__db.profiles[name]
			end,
			hidden = function() return profilesRepo and newProfileIndex==nil end,
		},
		copyDesc = {
			type = 'description',
			order = 1.5,
			name = "\nCopy the settings from one existing profile into the currently active profile.",
		},
		copyProfile = {
			type   = 'select',
			order  = 2,
			name   = 'Copy From',
			desc   = "Copy the settings from one existing profile into the currently active profile.",
			get    = function() end,
			set    = function(_, key)
				local profiles = addon.__db.profiles
				profiles[addon.__profileKey] = addon.CopyTable( profiles[key] )
				addon.__profileKey = nil
				addon:PLAYER_TALENT_UPDATE()
			end,
			confirm = function() return "Selected profile will be copied into the current profile and current profile settings will be lost. Are you sure ?" end,
			values = function()
				wipe(values)
				for key in pairs(addon.__db.profiles) do
					if key ~= addon.__profileKey then
						values[key] = key
					end
				end
				return values
			end,
		},
		deleteDesc = {
			type = 'description',
			order = 2.5,
			name = "\nYou can delete unused profiles from the database to save space.",
		},
		deleteProfile = {
			type   = 'select',
			order  = 3,
			name   = 'Delete Profile',
			desc   = "Unlisted profiles are in use by some toon and cannot be deleted.",
			get    = function() end,
			set    = function(_, key)
				addon.__db.profiles[key] = nil
				addon:Update()
			end,
			values = function()
				wipe(values)
				wipe(undeletable)
				for _,specs in pairs(addon.__db.profileChars) do
					for _,key in pairs(specs) do
						undeletable[key] = true
					end
				end
				for key in pairs(addon.__db.profiles) do
					if not undeletable[key] then values[key] = key end
				end
				return values
			end,
			confirm = function(_,key) return "Are you sure you want to delete the selected profile?" end,
		},
		footer = { type = "description", order = 100, name = " " },
	} )

	function addon:RegisterProfile(data)
		profilesRepo = profilesRepo or {}
		profilesRepo[#profilesRepo+1] = data
		profilesValues[#profilesRepo] = data.name
	end

end

