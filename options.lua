-----------------------------------------------------------------------------------------------
-- KiwiPlates: Configuration options
-----------------------------------------------------------------------------------------------

local addon = KiwiPlates

--================================================

local selectedSkin
local selectedSkinIndex
local skinCommand
local newSkinName

--================================================

addon.OptionsTable = { name = "KiwiPlates Options", type = "group", childGroups = "tab", args = {
	General = { type = "group", order = 10, name = 'General', childGroups = nil, args = {} },
	Skins = { type = "group", order = 20, name = 'Skins', childGroups = "tab", args = {
		Settings = { type = "group", order = 20, name = 'Skin Settings', childGroups = "tree", hidden = function() return not selectedSkin end, args = {} },
		Display  = { type = "group", order = 30, name = 'Display Conditions', childGroups = "tab",  hidden = function() return not selectedSkin end, args = {} },
	} },
	Extras = addon.isClassic and { type = "group", order = 30, name = 'Extras', childGroups = "tab", args = {} } or nil,
	Profiles = { type = "group", order = 100, name = 'Profiles', childGroups = nil, args = {} },
} }

--================================================

local ColorDefault  = addon.ColorDefault
local ColorWidgets  = addon.ColorWidgets
local ColorStatuses = addon.ColorStatuses

--================================================

local fontFlagsValues = {
	[""]        = "Soft",
	["OUTLINE"] = "Soft Thin",
	["THICKOUTLINE"] = "Soft Thick",
	["MONOCHROME"] = "Sharp",
	["MONOCHROME, OUTLINE"] = "Sharp Thin",
	["MONOCHROME, THICKOUTLINE"] = "Sharp Thick",
}

local fontHorizontalAlignValues = {
	LEFT   = "LEFT",
	CENTER = "CENTER",
	RIGHT  = "RIGHT",
}

local healthMasks = {
	[1] = nil, -- percent (special case, no mask stored for percent)
	[2] = "$h",
	[3] = "$m",
	[4] = "$h/$m",
	[5] = "$h $p%",
	[6] = "$m $p%",
	[7] = "$h/$m $p%",
	["$p%"] = 1,
	["$h"] = 2,
	["$m"] = 3,
	["$h/$m"] = 4,
	["$h $p%"] = 5,
	["$m $p%"] = 6,
	["$h/$m $p%"] = 7,
}

--================================================

local function FormatTitle(name, enabled)
	return string.format( "|cffffd200%s%s|r", name, enabled and ': Enabled' or '' )
end

local function SetCVarCombat(key, value)
	if InCombatLockdown() then
		print("You are in combat, settings cannot be updated.")
	else
		if type(value) == 'boolean' then
			SetCVar(key, value and "1" or "0")
		else
			SetCVar(key, value)
		end
		return true
	end
end

local Update
do
	local count, skin = 0
	local function RealUpdate()
		if count > 0 then
			addon:Update(selectedSkin)
			C_Timer.After(0.2, RealUpdate)
		end
		count = 0
	end
	function Update(updateSkin)
		skin  = (updateSkin==nil) and selectedSkin or updateSkin
		count = count + 1
		if count == 1 then
			C_Timer.After(0.2, RealUpdate)
		end
	end
end

local function Opt_GetOption( tree, order )
	local opt = addon.OptionsTable
	for _,key in ipairs( {strsplit('/', tree)} ) do
		if not opt.args[key] then
			opt.args[key] = { type = "group", order = order, name = key, args = {} }
		end
		opt = opt.args[key]
	end
	return opt, opt.args
end

local Opt_SetupOption
do
	local index = 1
	Opt_SetupOption = function( tree, name, options, order, poptions )
		local opt, args = Opt_GetOption(tree, index+100)
		for i=#options,1,-1 do
			local p = options[i]
			p[1]( options, unpack(p,2) )
			table.remove(options,i)
		end
		if (not name) or args[name] then
			args = name and args[name].args or args
			for k,v in pairs(options) do args[k] = v end
		else
			local group = { type = 'group', name = name, order = order or index, inline = not opt.childGroups, args = options }
			if poptions then
				for k,o in pairs(poptions) do
					if k~='disabled' then
						group[k]= o
					else
						for _,t in pairs(options) do
							if t.order~=0 and t.disabled==nil then
								t.disabled = o
							end
						end
					end
				end
			end
			args[name] = group
		end
		index = index + 1
		return options
	end
end

local Opt_GetSkinsValues
do
	local list = {}
	function Opt_GetSkinsValues()
		wipe(list)
		for index,skin in next, addon.db.skins do
			list[index] = skin.__skinName or 'Default'
		end
		return list
	end
end

local function Opt_SwapSkins(i,j)
	local skins = addon.db.skins
	skins[i], skins[j] = skins[j], skins[i]
	local rules = addon.db.rules
	rules[i], rules[j] = rules[j], rules[i]
	if (addon.db.defaultSkin or 1)==i then
		addon.db.defaultSkin = j
	elseif (addon.db.defaultSkin or 1)==j then
		addon.db.defaultSkin = i
	end
	Update()
end

local Opt_MakeSelectedSkinConditions
do
	local convert = { ['true'] = true, ['false'] = false }
	local keys = { ['@attackable'] = 'Unit Is Attackable', ['@type'] = 'Unit Type', ['@classification'] = 'Unit Classification', ['@reaction'] = 'Unit Reaction', ['@level'] = 'Unit Level', ['@target'] = 'Target', ['@mouseover'] = "Mouseover", ['@combat'] = 'Unit In Combat', names = 'Name List', combat = 'In Combat', instance = 'Instance Type'   }
	local def_values = { ['@attackable'] = true, ['@type'] = 'Player' , ['@reaction'] = 'hostile', ['@level'] = 100, ['@classification'] = 'elite', ['@target'] = true, ['@mouseover'] = true, ['@combat'] = true, names = "", combat = true, instance = 'none' }
	local values = {
		['@type'] = { Player = 'Player', Creature = 'Creature', Pet = 'Pet', GameObject = 'Game object', Vehicle = 'Vehicle', Vignette = 'Vignette',
				 ['~=Player'] = 'not Player', ['~=Creature'] = 'not Creature', ['~=Pet'] = 'not Pet', ['~=GameObject'] = 'not Game Object', ['~=Vehicle'] = 'not Vehicle', ['~=Vignette'] = 'not Vignette',
				 ['~~'] = '|cFFff0000delete|r' },
		['@classification'] = { boss = 'Boss', elite = 'Elite', rare = 'Rare', rareelite = 'Rare Elite', normal = 'Normal', trivial = "Trivial",  minus = "Minus",
				           ['~=boss'] = 'not Boss', ['~=elite'] = 'not Elite', ['~=rare'] = 'not Rare', ['~=rareelite'] = 'not Rare Elite', ['~=normal'] = 'not Normal', ['~=trivial'] = "not Trivial",  ['~=minus'] = "not Minus",
					       ['~~'] = '|cFFff0000delete|r' },
		['@reaction'] =  { hostile = 'Hostile', neutral = 'Neutral', friendly = 'Friendly', ['~=hostile'] = 'not Hostile', ['~=neutral'] = 'not Neutral', ['~=friendly'] = 'not Friendly', ['~~'] = '|cFFff0000delete|r' },
		['@level']     = { ['-1'] = '??', ['120'] = '120', ['121'] = '121', ['122'] = '122', ['~~'] = '|cFFff0000delete|r' },
		['@target']    = { ['true'] = 'true', ['false'] = 'false', ['~~'] = '|cFFff0000delete|r' },
		['@mouseover'] = { ['true'] = 'true', ['false'] = 'false', ['~~'] = '|cFFff0000delete|r' },
		['@combat']    = { ['true'] = 'true', ['false'] = 'false', ['~~'] = '|cFFff0000delete|r' },
		['@attackable']    = { ['true'] = 'true', ['false'] = 'false', ['~~'] = '|cFFff0000delete|r' },
		['combat']     = { ['true'] = 'true', ['false'] = 'false', ['~~'] = '|cFFff0000delete|r' },
		['instance'] = { none = 'World', pvp = 'Battleground', arena = 'Arena',  party = 'Dungeon', raid = 'Raid', scenario = 'Scenario',
						 ['~=none'] = 'not in World', ['~=pvp'] = 'not in Battleground', ['~=arena'] = 'not in Arena',  ['~=party'] = 'not in Dungeon', ['~=raid'] = 'not in Raid', ['~=scenario'] = 'not in Scenario',
						 ['~~'] = '|cFFff0000delete|r' },
	}

	function MakeConditions(skinRules, options)
		local function MakeCondition(key, index)
			local cond = {
				name = keys[key],
				get = function(info)
					local comp  = skinRules[index][2]
					local value = skinRules[index][3]
					return ( comp == '==' ) and tostring(value) or  (comp .. tostring(value))
				end,
				set = function(info, value)
					if value == '~~' or (key == 'names' and strtrim(value)=='') then
						table.remove( skinRules, index )
						MakeConditions( skinRules, options )
					else
						local comp, val = '==', tonumber(value) or convert[value]
						if val==nil then
							local ncomp = strsub(value,1,2)
							if ncomp == '<=' or ncomp == '>=' or ncomp == '~=' then
								val  = tonumber(strsub(value,3)) or strsub(value,3)
								comp = ncomp
							end
						end
						skinRules[index][2] = comp
						if val~=nil then
							skinRules[index][3] = val
						else
							skinRules[index][3] = value
						end
					end
					Update(false)
				end,
				confirm = function(info, value)
					if value == '~~' then
						return 'Are you sure you want to remove this condition ?'
					elseif key=='names' and strtrim(value)=='' then
						return 'Names field is empty. Do you want to remove this condition ?'
					end
				end,
				disabled = function() return skinRules.disabled end,
			}
			if key == 'names' then
				cond.type = 'input'
				cond.multiline = 10
				cond.width = 'full'
				cond.values = nil
				cond.order = 99
				options[key] = cond
			else
				cond.type = 'select'
				cond.order = index
				cond.values = values[key] or {}
				options[key..index] = cond
			end
		end
		wipe(options)
		for i=2,#skinRules do
			MakeCondition( skinRules[i][1], i )
		end
		options.AndOr = {
			type = 'select', width = 'normal', order = 1.5,
			name = 'Required for activation',
			desc = '',
			get = function() return skinRules[1] end,
			set = function(info,key)
				skinRules[1] = key
				Update(false)
			end,
			values = { ['and'] = 'All conditions', ['or'] = 'Any condition' },
			disabled = function() return skinRules.disabled end,
		}
		options.toggle = {
			type = 'select', width = 'normal', order = 1.6,
			name = 'Add a New Condition',
			desc = 'Select a condition variable to add.',
			get = function() end,
			set = function(info,key)
				if key~='names' or not options[key] then
					skinRules[#skinRules+1] = { key, '==', def_values[key] }
					MakeCondition( key, #skinRules )
					Update(false)
				end
			end,
			values = keys,
			disabled = function() return skinRules.disabled end,
		}
		options.default = {
			type = "toggle",
			order = 1.7, width = .6,
			name = "Default",
			desc = "If checked this skin will be applied to the nameplate if no other skin conditions are meet.",
			get = function()
				return selectedSkinIndex==(addon.db.defaultSkin or 1)
			end,
			set = function (_, value)
				addon.db.defaultSkin = selectedSkinIndex
				Update()
			end,
			disabled = function() return skinRules.disabled end,
		}
		options.disabled = {
			type = "toggle",
			order = 1.8, width = .6,
			name = "Disabled",
			desc = "If checked this skin will be disabled.",
			get = function()
				return skinRules.disabled
			end,
			set = function (_, value)
				skinRules.disabled = value or nil
				Update()
			end,
			disabled = function() return selectedSkinIndex==(addon.db.defaultSkin or 1) end,
		}
		options.headercond2 = { type = 'header', order = 1.9, name = 'Conditions' }
		options.warning = {
			type = "description",
			order = 1.91,
			fontSize = "medium",
			name = "|cFFff0000Warning, this skin is disabled because no display conditions exist or Disabled option is checked. Add some display condition, set this skin as default or uncheck the Disabled toggle.|r",
			hidden = function() return not skinRules.disabled and (#skinRules>1 or (addon.db.defaultSkin or 1) == selectedSkinIndex) end,
		}
	end
	Opt_MakeSelectedSkinConditions = function()
		MakeConditions( addon.db.rules[selectedSkinIndex], Opt_GetOption( 'Skins/Display' ).args )
	end
end

local Opt_MakeWidgetsToColorize
do
	local options = {}
	local function get(info)
		return info.handler[1] == (selectedSkin[info.arg..'_color_status'] or addon.ColorStatusDefaults[info.arg])
	end
	local function set(info, value)
		selectedSkin[info.arg..'_color_status'] = value and info.handler[1] or nil
		Update()
	end
	local function disabled(info)
		return get(info) and (info.handler[1]==addon.ColorStatusDefaults[info.arg])
	end
	local function hidden(info)
		return not selectedSkin[info.arg..'_enabled']
	end
	options.header = { type = 'header', order = 0, name = function(info) return info.handler[2] end, hidden = function(info) return #info.handler<2 end }
	local order = 1
	for widgetName,widgetDesc in pairs(addon.ColorWidgets) do
		options[widgetName] = {
			type  = "toggle",
			order = order,
			name  = widgetDesc,
			desc  = string.format("Toggle to apply this color to the '%s' widget.", widgetDesc),
			get   = get, set = set, disabled = disabled, hidden = hidden,
			arg   = widgetName,
		}
		order = order + 1
	end
	--  info.handler = statusName(reaction,level,color,...)  info.arg = widgetName(kHealthBar,kNameText,...)
	function Opt_MakeWidgetsToColorize(opt, statusName, title, order)
		opt[statusName..'_widgets'] = { type = 'group',	order = order or 0, name = "", inline = true, args = options, handler = { statusName, title } }
		return opt
	end
end

local function Opt_MakeThreatColor(opt, order, widgetName)
	opt = opt or {}
	order = order or 50
	opt.ColorThreat = {
		type = "toggle",
		order = order, width = "normal",
		name = "Apply Threat Colors",
		desc = "Apply Threat Colors to this widget while in Combat.",
		get = function()
			return addon.TableContains( addon.db.threat.widgets, widgetName )
		end,
		set = function (_, value)
			if value then
				table.insert( addon.db.threat.widgets, widgetName )
			else
				addon.TableRemoveByValue( addon.db.threat.widgets, widgetName )
			end
			addon:Update()
		end,
	}
	opt.ColorThreatWarning = {
		type = 'description',
		order = order+1,
		name = "|cFFff0000Warning the specified color type is not compatible with threat colors. Threat colors will not be applied to this skin.|r",
		hidden = function()
			return not (addon.TableContains(addon.db.threat.widgets,widgetName) and addon.ColorsNonOverride[ selectedSkin[widgetName..'_color_status'] or addon.ColorStatusDefaults[widgetName] ])
		end
	}
	return options
end

local function Opt_SetSelectedSkin(key)
	selectedSkinIndex = key
	selectedSkin = addon.db.skins[key]
	Opt_MakeSelectedSkinConditions()
	addon:TestMode(key, true)
end

--------------------------------------------------------
-- General Options
--------------------------------------------------------

Opt_SetupOption( 'General', 'Nameplates Visibility', {
	nameplateShowAll = {
		type = "toggle",
		order = 11, width = "double",
		name = "Show all Nameplates",
		desc = "Show nameplates for all nearby units. If disabled only show relevant units when you are in combat.",
		get = function() return GetCVar ("nameplateShowAll") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateShowAll", value) end,
	},
	separator1 = { type = 'description', name = "", order = 50, },
	nameplateShowEnemies = {
		type = "select",
		order = 101,
		name = "Show Enemies",
		desc = "Show nameplates for enemy units.",
		get = function()
			return addon.db.general.nameplateShowEnemies or tonumber(GetCVar("nameplateShowEnemies")) or 0
		end,
		set = function (_, value)
			addon.db.general.nameplateShowEnemies = value
			if value>1 then
				addon:UpdateVisibility()
			else
				SetCVarCombat("nameplateShowEnemies", value==1)
			end
		end,
		values = { [0] = "Never", [1] = "Always", [2]= "Only in combat", [3]= "Only out of combat", [4] = 'Only in instances' , [5] = 'Only outside instances' },
	},
	nameplateShowEnemyMinions = {
		type = "toggle",
		order = 102, width = .55,
		name = "Minions",
		desc = "Show nameplate for enemy pets, totems and guardians.",
		get = function() return GetCVar ("nameplateShowEnemyMinions") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateShowEnemyMinions", value) end,
		disabled = function() return GetCVar ("nameplateShowEnemies") == "0" or addon.db.general.nameplateShowEnemies==0 end,
	},
	nameplateShowEnemyMinus = {
		type = "toggle",
		order = 103, width = .55,
		name = "Minor",
		desc = "Show nameplate for minor enemies.",
		get = function() return GetCVar ("nameplateShowEnemyMinus") == "1" end,
		set = function (_, value) SetCVarCombat ("nameplateShowEnemyMinus", value) end,
		disabled = function() return GetCVar ("nameplateShowEnemies") == "0" or addon.db.general.nameplateShowEnemies==0 end,
	},
	separator2 = { type = 'description', name = "", order = 105, },
	nameplateShowFriends = {
		type = "select",
		order = 201,
		name = "Show Friends",
		desc = "Show nameplates for friendly units.",
		get = function()
			return addon.db.general.nameplateShowFriends or tonumber(GetCVar("nameplateShowFriends")) or 0
		end,
		set = function (_, value)
			addon.db.general.nameplateShowFriends = value
			if value>1 then
				addon:UpdateVisibility()
			else
				SetCVarCombat("nameplateShowFriends", value==1)
			end
		end,
		values = { [0] = "Never", [1] = "Always", [2]= "Only in combat", [3]= "Only out of combat", [4] = 'Only in instances' , [5] = 'Only outside instances' },
	},
	nameShowFriendlyNPCs= {
		type = "toggle",
		order = 201.5,
		name = "NPCs", width = .4,
		desc = "Show nameplates for friendly NPCs.",
		get = function() return GetCVar ("nameplateShowFriendlyNPCs") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateShowFriendlyNPCs", value) end,
		disabled = function() return GetCVar ("nameplateShowFriends") == "0" or addon.db.general.nameplateShowFriends==0 end,
	},
	nameplateShowFriendlyMinions = {
		type = "toggle",
		order = 202, width = .5,
		name = "Minions",
		desc = "Show nameplates for friendly minions.",
		get = function() return GetCVar("nameplateShowFriendlyMinions") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateShowFriendlyMinions", value) end,
		disabled = function() return GetCVar ("nameplateShowFriends") == "0" or addon.db.general.nameplateShowFriends==0 end,
	},
	nameplateShowFriendlyGuardians = {
		type = "toggle",
		order = 203, width = .5,
		name = "Guardians",
		desc = "Show nameplates for friendly guardians.",
		get = function() return GetCVar ("nameplateShowFriendlyGuardians") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateShowFriendlyGuardians", value) end,
		disabled = function() return GetCVar ("nameplateShowFriends") == "0" or addon.db.general.nameplateShowFriends==0 end,
	},
	nameplateShowFriendlyTotems = {
		type = "toggle",
		order = 204, width = .5,
		name = "Totems",
		desc = "Show nameplates for friendly totems.",
		get = function() return GetCVar("nameplateShowFriendlyTotems") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateShowFriendlyTotems", value) end,
		disabled = function() return GetCVar ("nameplateShowFriends") == "0" or addon.db.general.nameplateShowFriends==0 end,
	},
	nameplateShowFriendlyPets = {
		type = "toggle",
		order = 205, width = .35,
		name = "Pets",
		desc = "Show nameplates for friendly pets.",
		get = function() return GetCVar("nameplateShowFriendlyPets") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateShowFriendlyPets", value) end,
		disabled = function() return GetCVar ("nameplateShowFriends") == "0" or addon.db.general.nameplateShowFriends==0 end,
	},
} )

Opt_SetupOption( 'General', 'Names Visibility', {
	nameShowAll = {
		type = "toggle",
		order = 11,
		width = .75,
		name = "All NPCs",
		desc = "Show all NPCs names.",
		get = function() return GetCVarBool("UnitNameNPC") end,
		set = function (_, value) SetCVarCombat("UnitNameNPC", value) end,
	},
	nameShowQuest = {
		type = "toggle",
		order = 12,
		width = .75,
		name = "Quest NPCs",
		desc = "Show quest NPCs.",
		get = function() return GetCVarBool("UnitNameFriendlySpecialNPCName") or GetCVarBool("UnitNameNPC") end,
		set = function (_, value) SetCVarCombat("UnitNameFriendlySpecialNPCName", value) end,
		disabled = function() return GetCVarBool("UnitNameNPC") end,
	},
	nameShowHostile = {
		type = "toggle",
		order = 13,
		width = .75,
		name = "Hostile NPCs",
		desc = "Show Hostile NPCs.",
		get = function() return GetCVarBool("UnitNameHostleNPC") or GetCVarBool("UnitNameNPC") end,
		set = function (_, value) SetCVarCombat("UnitNameHostleNPC", value) end,
		disabled = function() return GetCVarBool("UnitNameNPC") end,
	},
	nameShowInteractive = {
		type = "toggle",
		order = 14,
		width = .75,
		name = "Iteractive NPCs",
		desc = "Show iteractive NPCs.",
		get = function() return GetCVarBool("UnitNameInteractiveNPC") or GetCVarBool("UnitNameNPC") end,
		set = function (_, value) SetCVarCombat("UnitNameInteractiveNPC", value) end,
		disabled = function() return GetCVarBool("UnitNameNPC") end,
	},
} )

Opt_SetupOption( 'General', 'Nameplates Stacking', {
	nameplateMotion = {
		type = "toggle",
		order = 301,
		name = "Stack Nameplates",
		desc = "Nameplates must not overlap each other.",
		get = function() return GetCVar ("nameplateMotion") == "1" end,
		set = function (_, value) SetCVarCombat("nameplateMotion", value) end,
	},
	nameplateMotionSpeed = {
		type = "range", min = 0.001, max = 0.2, step = 0.005,
		order = 302,
		name = "Motion Speed",
		desc = "How fast the nameplate moves when stacking is enabled (default: 0.025)",
		get = function() return tonumber (GetCVar ("nameplateMotionSpeed")) end,
		set = function (_, value) SetCVar ("nameplateMotionSpeed", value) end,
		disabled = function() return GetCVar ("nameplateMotion") == "0" end,
	},
	nameplateOverlapV = {
		type = "range",	min = 0.2,	max = 1.6,	step = 0.1,
		order = 303,
		name = "Vertical Padding",
		desc = "Verticaly distance between each nameplate (default: 1.10)",
		get = function() return tonumber (GetCVar("nameplateOverlapV")) end,
		set = function (_, value) SetCVarCombat("nameplateOverlapV", value)	end,
		disabled = function() return GetCVar ("nameplateMotion") == "0" end,
	},
} )

Opt_SetupOption( 'General', 'Nameplate Visibility (Target)', {
	nameplateMotion = {
		type = "toggle",
		order = 351,
		name = "Clamped to Screen",
		desc = "Target nameplate always visible.",
		get = function() return GetCVar('nameplateOtherTopInset') ~= '-1' or GetCVar('nameplateOtherBottomInset') ~= '-1' end,
		set = function (_, value)
			if value then
				SetCVarCombat('nameplateOtherTopInset', '0.08')
				SetCVarCombat('nameplateOtherBottomInset', '0.1')
				SetCVarCombat('nameplateLargeTopInset','0.08')
			else
				SetCVarCombat('nameplateOtherTopInset', '-1')
				SetCVarCombat('nameplateOtherBottomInset', '-1')
				SetCVarCombat('nameplateLargeTopInset','-1')
			end
		end,
	},
	nameplateOtherTopInset = {
		type = "range", min = 0, max = 0.2, step = 0.01,
		order = 352,
		name = "Top Screen Percent",
		isPercent = true,
		get = function()  return math.max( tonumber(GetCVar("nameplateOtherTopInset")), 0 ); end,
		set = function (_, value)
			SetCVarCombat("nameplateOtherTopInset", value>0 and value or -1)
			SetCVarCombat("nameplateLargeTopInset", value>0 and value or -1)
		end,
		disabled = function() return GetCVar('nameplateOtherTopInset') == '-1' and GetCVar('nameplateOtherBottomInset') == '-1' end,
	},
	nameplateOtherBottomInset = {
		type = "range", min = 0, max = 0.2, step = 0.01,
		order = 353,
		name = "Bottom Screen Percent",
		isPercent = true,
		get = function()  return math.max( tonumber(GetCVar("nameplateOtherBottomInset")), 0 ); end,
		set = function (_, value)
			SetCVarCombat("nameplateOtherBottomInset", value>0 and value or -1)
			SetCVarCombat("nameplateLargeBottomInset", value>0 and value or -1)
		end,
		disabled = function() return GetCVar('nameplateOtherTopInset') == '-1' and GetCVar('nameplateOtherBottomInset') == '-1' end,
	},
} )

Opt_SetupOption( 'General', 'Nameplates Appearance', {
	nameplateClassicBorders = {
		type = "toggle",
		order = 1, width = "double",
		name = "Blizzard Border Textures",
		desc = "Enable Blizzard textures for nameplates & castbars borders. This option is global and will be applied to all profiles and skins.",
		get = function()
			return addon.__db.global.classicBorders
		end,
		set = function (_, value)
			addon.__db.global.classicBorders = value or nil
			ReloadUI()
		end,
		confirm = function() return 'UI must be Reloaded to change this option. Are you sure ?' end,
	},
} )

Opt_SetupOption( 'General', 'Nameplates Miscellaneous', {
	nameplateMaxDistance = {
		type = "range", min = 1, max = 100,	step = 1,
		order = 405,
		name = "Max. Distance",
		desc = "How far you can see nameplates (in yards). |cFFFFFFFFDefault: 60|r",
		get = function() return tonumber(GetCVar("nameplateMaxDistance")) end,
		set = function (_, value) SetCVarCombat("nameplateMaxDistance", value) end,
		hidden = function() return addon.isClassic end,
	},
	nameplateOtherAtBase = {
		type = "select",
		order = 407,
		name = "Anchor",
		desc = "Where the nameplate is anchored to.",
		get = function() return GetCVar("nameplateOtherAtBase") end,
		set = function (_, value) SetCVarCombat("nameplateOtherAtBase", value) end,
		values = {	['0'] = "Top", ['1'] = "Top&Bottom", ['2'] = "Bottom"  },
	},
	ShowNamePlateLoseAggroFlash = {
		type = "toggle",
		order = 408,
		name = "Losing Aggro Flash",
		desc = "Flash when losing Aggro.",
		get = function() return GetCVar ("ShowNamePlateLoseAggroFlash") == "1" end,
		set = function (_, value) SetCVarCombat("ShowNamePlateLoseAggroFlash", value) end,
		hidden = function() return addon.isClassic end,
	},
	ShowClassColorInNameplate = {
		type = "toggle",
		order = 409,
		name = "Enemy Class Colors",
		desc = "Display class colors for enemy players.",
		get = function() return GetCVarBool("ShowClassColorInNameplate") end,
		set = function (_, value) SetCVarCombat("ShowClassColorInNameplate", value) end,
	},
	ShowClassColorInFriendlyNameplate = {
		type = "toggle",
		order = 410,
		name = "Friendly Class Colors",
		desc = "Display class colors for friendly players.",
		get = function() return GetCVarBool("ShowClassColorInFriendlyNameplate") end,
		set = function (_, value) SetCVarCombat("ShowClassColorInFriendlyNameplate", value) end,
	},
} )

if not addon.isClassic then
Opt_SetupOption( 'General', 'My Personal Resources', {
	nameplateShowSelf = {
		type = "toggle",
		order = 901,
		width = 1,
		name = "Health&Power Bars",
		desc = "Shows health and power bars under your character.",
		get = function() return GetCVar("nameplateShowSelf") == "1" end,
		set = function ( _, value) SetCVarCombat("nameplateShowSelf", value)	end,
	},
	nameplateResourceOnTarget = {
		type = "toggle",
		order = 902,
		width = 1,
		name = "Resources on Target",
		desc = "Shows resources such as combo points above your target or power bar.",
		get = function() return GetCVar ("nameplateResourceOnTarget") == "1" end,
		set = function (_, value)
			addon.db.general.resourceBarOffset = nil
			SetCVarCombat("nameplateResourceOnTarget", value)
			ReloadUI()
		end,
		confirm = function() return 'UI must be Reloaded to change this option. Are you sure ?' end,
	},
	nameplateResourceOffset = {
		type = 'range', order = 903,
		name = 'Resources frame Offset Y',
		desc = 'Set zero to use blizzard default offset.',
		softMin = -100, softMax = 100, step = 1,
		get = function() return addon.db.general.resourceBarOffset or 0 end,
		set = function(info,value)
			addon.db.general.resourceBarOffset = value~=0 and value or nil
			Update()
		end,
		disabled = function() return GetCVar("nameplateResourceOnTarget") == '0' end,
	}
} )
end

Opt_SetupOption( 'General', 'Miscellaneous', {
	minimapIcon = {
		type = "toggle",
		order = 10,
		name = "Minimap Icon",
		desc = "Display Minimap Icon",
		get = function()
			return not addon.db.minimapIcon.hide
		end,
		set = function ( _, value)
			if addon.db.minimapIcon.hide then
				addon.db.minimapIcon.hide = nil
				LibStub("LibDBIcon-1.0"):Show("KiwiPlates")
			else
				addon.db.minimapIcon.hide = true
				LibStub("LibDBIcon-1.0"):Hide("KiwiPlates")
			end
		end,
	},
} )

--------------------------------------------------------
-- Skins Management Options
--------------------------------------------------------

Opt_SetupOption( 'Skins', nil, {
	selectedSkin = {
		type = 'select',
		order = 1,
		width = .9,
		name = 'Skin',
		get = function()
			if not selectedSkin then Opt_SetSelectedSkin(1)	end
			return selectedSkinIndex
		end,
		set = function(info, key) Opt_SetSelectedSkin(key) end,
		values = Opt_GetSkinsValues,
	},
	moveUp = {
		type = 'execute',
		order = 2,
		width = .35,
		name = 'Up',
		desc = 'Increase skin display priority moving up the skin in the dropdown list.',
		func = function()
			Opt_SwapSkins(selectedSkinIndex, selectedSkinIndex-1)
			Opt_SetSelectedSkin(selectedSkinIndex-1)
		end,
		hidden = function() return not (selectedSkin and selectedSkinIndex>1) or skinCommand~=nil end,
	},
	moveDown = {
		type = 'execute',
		order = 3,
		width = .35,
		name = 'Dn',
		desc = 'Decrease skin display priority moving down the skin in the dropdown list.',
		func = function()
			Opt_SwapSkins(selectedSkinIndex, selectedSkinIndex+1)
			Opt_SetSelectedSkin(selectedSkinIndex+1)
		end,
		hidden = function() return not (selectedSkin and  selectedSkinIndex<#addon.db.skins) or skinCommand~=nil  end,
	},
	resetSkin = {
		type = 'execute',
		order = 4,
		width = .35,
		name = 'Res',
		desc = 'Resets the skin assigning the default values.',
		func = function()
			local name = selectedSkin.__skinName
			wipe(selectedSkin)
			addon.CopyTable(addon.defaults.skins[1], selectedSkin)
			selectedSkin.__skinName = name
			Update()
		end,
		confirm = function() return 'All changes made to this skin will be lost. Are you sure you want to reset this skin?' end,
		hidden = function() return skinCommand~=nil or (not next(addon.db.skins[1])) end,
	},
	deleteSkin = {
		type = 'execute',
		order = 5,
		width = .35,
		name = 'Del',
		desc = 'Delete the selected Skin.',
		func = function()
			tremove( addon.db.skins, selectedSkinIndex )
			tremove( addon.db.rules, selectedSkinIndex )
			if (addon.db.defaultSkin or 1)>#addon.db.skins then
				addon.db.defaultSkin = nil
			end
			Opt_SetSelectedSkin( 1 )
			Update()
		end,
		confirm = function() return 'Are you sure you want to delete the selected skin?' end,
		hidden = function() return skinCommand~=nil or (not selectedSkin) or #addon.db.skins<=1 end,
	},
	renameSkin = {
		type = 'execute',
		order = 6,
		width = .35,
		name = 'Ren',
		desc = 'Rename the selected Skin.',
		func = function()
			addon:ShowEditDialog('Rename skin:', selectedSkin.__skinName, function(name)
				selectedSkin.__skinName = name
				LibStub("AceConfigRegistry-3.0"):NotifyChange(addon.addonName)
			end)
		end,
		hidden = function() return skinCommand~=nil end,
	},
	createSkin = {
		type = 'execute',
		order = 7,
		width = .4,
		name = 'Clone',
		desc = 'Create a new skin using the selected skin as template.',
		func = function() newSkinName = ''; skinCommand = 'create' end,
		hidden = function() return skinCommand~=nil end,
	},
	testMode = {
		type = 'execute',
		order = 8,
		width = .4,
		name = 'Test',
		desc = 'Toggle test mode. In Test mode all nameplates display the selected Skin and all enabled widgets become visible.',
		func = function() addon:TestMode(selectedSkinIndex) end,
		hidden = function() return skinCommand~=nil end,
	},
	newSkinName = {
		type = 'input',
		name = 'New Skin Name',
		order = 10,
		get = function() return newSkinName end,
		set = function(info,skinName)
			local index = #addon.db.skins+1
			addon.db.skins[index] = addon.CopyTable(selectedSkin)
			addon.db.skins[index].__skinName = skinName
			addon.db.rules[index] = { 'and' }
			Opt_SetSelectedSkin(index)
			skinCommand = nil
			newSkinName = ''
		end,
		hidden = function() return not skinCommand end,
		validate = function(info,value)
			for _,skin in ipairs(addon.db.skins) do
				if value==skin.__skinName then
					return false
				end
			end
			return true
		end,
	},
	newSkinCancel = {
		type = 'execute',
		order = 20,
		width = 'half',
		name = 'Cancel',
		func = function() skinCommand = nil; newSkinName = '' end,
		hidden = function() return not skinCommand end,
	},
} )

--------------------------------------------------------
-- General Options for Selected Skin
--------------------------------------------------------

Opt_SetupOption( 'Skins/Settings', 'NamePlate', {
	header1 = { type = "header", order = 0, name = "Nameplate" },
	plateOffsetY = {
		type = "range",
		order = 1,
		width = "full",
		name = 'Vertical Adjust',
		desc = "NamePlate vertical position",
		min = -100,
		max = 100,
		step = 1,
		get = function () return selectedSkin.plateOffsetY or 6 end,
		set = function (_, v)
			selectedSkin.plateOffsetY = v~=6 and v or nil
			Update(false)
		end,
	},
	header2 = { type = "header", order = 11, name = "" },
	generalAlpha1 = {
		type = "range",
		order = 12,
		width = "full",
		name = 'Target Plate Opacity',
		desc = "This setting is shared by all skins.",
		min = 0,
		max = 1,
		step = .05,
		get = function () return addon.db.general.alpha1 or 1 end,
		set = function (_, v)
			addon.db.general.alpha1 = v
			Update(false)
		end,
	},
	generalAlpha2 = {
		type = "range",
		order = 13,
		width = "full",
		name = 'Non Target Plates Opacity',
		desc = "This setting is shared by all skins.",
		min = 0,
		max = 1,
		step = .05,
		get = function () return addon.db.general.alpha2 or .4 end,
		set = function (_, v)
			addon.db.general.alpha2 = v
			Update(false)
		end,
	},
	generalAlpha3 = {
		type = "range",
		order = 14,
		width = "full",
		name = "Plates Opacity when Target does not exist",
		desc = 'This setting is shared by all skins.',
		min = 0,
		max = 1,
		step = .05,
		get = function() return addon.db.general.alpha3 or 1 end,
		set = function (_, v)
			addon.db.general.alpha3 = v
			Update(false)
		end,
	},
	header3 = { type = "header", order = 15, name = "" },
	highlight = {
		type = "toggle",
		order = 16, width = "double",
		name = "Nameplates Mouseover Highlight",
		desc = "Highlight the nameplate under the mouse pointer, this setting is shared by all skins.",
		get = function() return addon.db.general.highlight end,
		set = function (_, value)
			addon.db.general.highlight = value
			Update(false)
		end,
	},
} )

--------------------------------------------------------
-- Widgets
--------------------------------------------------------

Opt_SetupOption( 'Skins/Settings', 'Health Bar', {
	healthBarEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Health Bar", true),
		get = function() return selectedSkin.kHealthBar_enabled end,
		set = function (_, value)
			selectedSkin.kHealthBar_enabled = value
			selectedSkin.kHealthBorder_enabled = value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Health Bar" },
	barWidth = {
		type = 'range', order = 11, name = 'Health Bar Width', min = 0, softMax = 300, step = 1,
		get = function() return selectedSkin.healthBarWidth	or 136 end,
		set = function(info,value)
			selectedSkin.healthBarWidth = value~=136 and value or nil
			Update()
		end,
	},
	barHeight =  {
		type = 'range', order = 12, name = 'Health Bar Height', min = 1, softMax = 64, step = 1,
		get = function() return selectedSkin.healthBarHeight or 12 end,
		set = function(info,value)
			selectedSkin.healthBarHeight = value~=12 and value or nil
			Update()
		end,
	},
	barTexture = {
		type = "select", dialogControl = "LSM30_Statusbar",
		order = 13,
		name = "Bar Texture",
		desc = "Adjust the bar texture.",
		get = function (info) return selectedSkin.healthBarTexture or "Minimalist" end,
		set = function (info, v)
			selectedSkin.healthBarTexture = v
			Update()
		end,
		values = AceGUIWidgetLSMlists.statusbar,
	},
	header2 = { type = "header", order = 14, name = "Colors" },
	healthBarColorStatus = {
		type = "select",
		order = 15,
		name = "Bar Color",
		get = function()
			return selectedSkin.kHealthBar_color_status or addon.ColorStatusDefaults.kHealthBar
		end,
		set = function (_, v)
			selectedSkin.kHealthBar_color_status =  v
			Update()
		end,
		values = addon.CopyTable(ColorStatuses, { blizzard = "Blizzard" } ),
	},
	healthBarColor = {
		type = "color",
		order = 17,
		hasAlpha = true,
		name = "Health Bar Color",
		get = function()
			return unpack( selectedSkin.kHealthBar_color_default or addon.ColorDefaults.kHealthBar )
		end,
		set = function( _, r,g,b,a )
			selectedSkin.kHealthBar_color_default = { r, g, b, a }
			Update()
		end,
		hidden = function() return (selectedSkin.kHealthBar_color_status or addon.ColorStatusDefaults.kHealthBar)~='color' end,
	},
	[1] = { Opt_MakeThreatColor, 50, 'kHealthBar' }
}, nil, { disabled = function() return not selectedSkin.kHealthBar_enabled end } )

Opt_SetupOption( 'Skins/Settings', 'Health Border', {
	borderEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Health Border", true),
		get = function() return selectedSkin.kHealthBorder_enabled end,
		set = function (_, value)
			selectedSkin.kHealthBorder_enabled = value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Health Border" },
	borderSize = {
		type = "range",
		order = 10,
		name = "Border Size",
		min = 1, softMax = 10, step = 1,
		get = function() return selectedSkin.borderSize or 1 end,
		set = function (_, value)
			selectedSkin.borderSize = value~=1 and value or nil
			Update()
		end,
		hidden = function() return addon.__db.global.classicBorders end,
	},
	borderTexture = {
		type = "select",
		order = 11,
		name = "Border Texture",
		get = function()
			return selectedSkin.borderTexture or addon.BorderTextureDefault
		end,
		set = function (_, v)
			selectedSkin.borderSize = nil
			selectedSkin.borderTexture = (v~=addon.BorderTextureDefault) and v or nil
			Update()
		end,
		values = addon.BorderTextures,
		hidden = function() return not addon.__db.global.classicBorders end,
	},
	header2 = { type = "header", order = 13, name = "Colors" },
	borderColorColorStatus = {
		type = "select",
		order = 14,
		name = "Border Color",
		get = function()
			return selectedSkin.kHealthBorder_color_status or addon.ColorStatusDefaults.kHealthBorder
		end,
		set = function (_, v)
			selectedSkin.kHealthBorder_color_status =  v
			Update()
		end,
		values = ColorStatuses,
	},
	borderColor = {
		type = "color",
		order = 15,
		hasAlpha = true,
		name = "Border Color",
		get = function()
			return unpack( selectedSkin.kHealthBorder_color_default or addon.ColorDefaults.kHealthBorder )
		end,
		set = function( _, r,g,b,a )
			selectedSkin.kHealthBorder_color_default = { r, g, b, a }
			Update()
		end,
		hidden = function() return (selectedSkin.kHealthBorder_color_status or addon.ColorStatusDefaults.kHealthBorder)~='color' end,
	},
	[1] = { Opt_MakeThreatColor, 50, 'kHealthBorder' },
}, nil, {
	disabled = function() return not selectedSkin.kHealthBorder_enabled end,
	hidden   = function() return not selectedSkin.kHealthBar_enabled end,
} )

Opt_SetupOption( 'Skins/Settings', 'Health Text', {
	healthTextEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Health Text", true),
		get = function() return selectedSkin.kHealthText_enabled end,
		set = function (_, value)
			selectedSkin.kHealthText_enabled = value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Health Text" },
	healthTextMask = {
		type = "select",
		order = 7,
		name = "Health Format",
		desc = "Select a predefined health format",
		get = function ()
			return healthMasks[selectedSkin.healthMaskValue or '$p%']
		end,
		set = function (_, v)
			selectedSkin.healthMaskValue = healthMasks[v]
			Update()
		end,
		values = {
			"percent",            -- 1
			"health",             -- 2
			"max",                -- 3
			"health/max",         -- 4
			"health percent",     -- 5
			"max percent",        -- 6
			"health/max percent", -- 7
		},
		hidden = function() return not healthMasks[selectedSkin.healthMaskValue or '$p%'] end,
	},
	healthTextMaskManual = {
		type = 'input',
		order = 7,
		name = "Custom Health Format",
		desc = "Valid tokens:\n$h = current health\n$m = max health\n$p = health percent\nWow escape sequences for colors and textures are allowed, example:\n||cFF00FF00Green Text||r",
		get = function()
			-- AceGUI input needs duplicates | characters so add another | for texture and color codes |c |r |T |t
			return gsub( selectedSkin.healthMaskValue or '$p%', "(%|[crTt])", "|%1" )
		end,
		set = function(_,mask)
			-- AceGUI input duplicates | characters so remove one | from texture and color codes |c |r |T |t
			selectedSkin.healthMaskValue = (mask~='$p%') and gsub( mask, "%|(%|[crTt])", "%1" ) or nil
			Update()
		end,
		hidden = function() return healthMasks[selectedSkin.healthMaskValue or '$p%'] end,
	},
	healthTextMaskManualEnabled = {
		type = "toggle",
		order = 8,
		name = "Custom Format",
		desc = "Type a user defined format.",
		get = function() return not healthMasks[selectedSkin.healthMaskValue or '$p%'] end,
		set = function (_, value)
			selectedSkin.healthMaskValue = value and "" or nil
			Update()
		end,
	},
	header2 = { type = "header", order = 9, name = "Position" },
	healthTextOffsetX =  {
		type = 'range', order = 10, name = 'X Adjust', min = -150, softMax = 150, step = 1,
		get = function() return selectedSkin.healthTextOffsetX or 66 end,
		set = function(info,value)
			selectedSkin.healthTextOffsetX = value~=66 and value or nil
			Update()
		end,
	},
	healthTextOffsetY =  {
		type = 'range', order = 11, name = 'Y Adjust', min = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.healthTextOffsetY or -4 end,
		set = function(info,value)
			selectedSkin.healthTextOffsetY = value~=-4 and value or nil
			Update()
		end,
	},
	header4 = { type = "header", order = 11.5, name = "Font" },
	healthTextAlign = {
		type = "select",
		order = 12,
		name = "Horizontal Align",
		get = function () return selectedSkin.healthTextAnchorPoint or 'RIGHT' end,
		set = function (_, v)
			selectedSkin.healthTextAnchorPoint = v~='RIGHT' and v or nil
			Update()
		end,
		values = fontHorizontalAlignValues,
	},
	healthTextFontFile = {
		type = "select", dialogControl = "LSM30_Font",
		order = 21,
		name = "Font Name",
		values = AceGUIWidgetLSMlists.font,
		get = function () return selectedSkin.healthTextFontFile or 'Accidental Presidency' end,
		set = function (_, v)
			selectedSkin.healthTextFontFile = v
			Update()
		end,
	},
	healthTextFontFlags = {
		type = "select",
		order = 22,
		name = "Font Border",
		values = fontFlagsValues,
		get = function () return selectedSkin.healthTextFontFlags or "OUTLINE" end,
		set = function (_, v)
			selectedSkin.healthTextFontFlags =  v ~= "OUTLINE" and v or nil
			Update()
		end,
	},
	healthTextFontSize = {
		type = "range",
		order = 23,
		name = 'Font Size',
		min = 1,
		softMax = 50,
		step = 1,
		get = function () return selectedSkin.healthTextFontSize or 14 end,
		set = function (_, v)
			selectedSkin.healthTextFontSize = v~=14 and v or nil
			Update()
		end,
	},
	header5 = { type = "header", order = 44, name = "Colors" },
	healthTextColorStatus = {
		type = "select",
		order = 45,
		name = "Text Color",
		get = function()
			return selectedSkin.kHealthText_color_status or addon.ColorStatusDefaults.kHealthText
		end,
		set = function (_, v)
			selectedSkin.kHealthText_color_status =  v
			Update()
		end,
		values = ColorStatuses,
	},
	healthTextColor = {
		type = "color",
		order = 50,
		hasAlpha = true,
		name = "Health Text Color",
		get = function()
			return unpack( selectedSkin.kHealthText_color_default or addon.ColorDefaults.kHealthText )
		end,
		set = function( _, r,g,b,a )
			selectedSkin.kHealthText_color_default = { r, g, b, a }
			Update()
		end,
		hidden = function() return (selectedSkin.kHealthText_color_status or addon.ColorStatusDefaults.kHealthText)~='color' end,
	},
	[1] = { Opt_MakeThreatColor, 50, 'kHealthText' }
}, nil, { disabled = function() return not selectedSkin.kHealthText_enabled end } )


Opt_SetupOption( 'Skins/Settings', 'Name Text', {
	nameEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Name Text", true),
		get = function() return selectedSkin.kNameText_enabled end,
		set = function (_, value)
			selectedSkin.kNameText_enabled = value
			Update()
		end,
	},
	headerFormat = { type = "header", order = 1, name = "Name Text" },
	nameFormat = {
		type = "select",
		order = 2,
		name = "Text to Display",
		desc = "Valid tokens:\n$n = Unit Name\n$t = Unit Name+Title\n$g = Player Guild\n$p = NPC Profession\nWow escape sequences for colors can be used, example:\n||cFF00FF00Green Text||r",
		get = function()
			return  selectedSkin.nameFormat and 2 or 1
		end,
		set = function(_, v)
			selectedSkin.nameFormat = v==2 and "$t|cFFffffff\n$g$p" or nil
			Update()
		end,
		values = { "Unit Name", "Custom Format" },
	},
	nameCustomFormat = {
		type = 'input',
		order = 3,
		name = "",
		width = "full",
		multiline = 3,
		desc = "Valid tokens:\n$n = Unit Name\n$t = Unit Name+Title\n$g = player guild\n$p = NPC Profession\nWow escape sequences for colors can be used, example:\n||cFF00FF00Green Text||r",
		get = function()
			-- AceGUI input needs duplicates | characters so add another | for texture and color codes |c |r |T |t
			return gsub( selectedSkin.nameFormat or '', "(%|[crTt])", "|%1" )
		end,
		set = function(_,mask)
			-- AceGUI input duplicates | characters so remove one | from texture and color codes |c |r |T |t
			selectedSkin.nameFormat = gsub( mask, "%|(%|[crTt])", "%1" )
			Update()
		end,
		hidden = function() return not selectedSkin.nameFormat end,
	},
	headerAppearance7 = { type = "header", order = 10, name = "Appearance" },
	nameFontFile = {
		type = "select", dialogControl = "LSM30_Font",
		order = 21,
		name = "Font Name",
		values = AceGUIWidgetLSMlists.font,
		get = function () return selectedSkin.nameFontFile or 'Roboto Condensed Bold' end,
		set = function (_, v)
			selectedSkin.nameFontFile = v
			Update()
		end,
	},
	nameFontFlags = {
		type = "select",
		order = 22,
		name = "Font Border",
		values = fontFlagsValues,
		get = function () return selectedSkin.nameFontFlags or "OUTLINE" end,
		set = function (_, v)
			selectedSkin.nameFontFlags =  v ~= "OUTLINE" and v or nil
			Update()
		end,
	},
	nameFontSize = {
		type = "range",
		order = 23,
		name = 'Font Size',
		min = 1,
		softMax = 50,
		step = 1,
		get = function () return selectedSkin.nameFontSize or 12 end,
		set = function (_, v)
			selectedSkin.nameFontSize = v~=12 and v or nil
			Update()
		end,
	},
	nameOffsetX =  {
		type = 'range', order = 10, name = 'X Adjust', min = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.nameOffsetX or 0 end,
		set = function(info,value)
			selectedSkin.nameOffsetX = value~=0 and value or nil
			Update()
		end,
	},
	nameOffsetY =  {
		type = 'range', order = 11, name = 'Y Adjust', min = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.nameOffsetY or -1 end,
		set = function(info,value)
			selectedSkin.nameOffsetY = value~=-1 and value or nil
			Update()
		end,
	},
	header2 = { type = "header", order = 44, name = "Colors" },
	nameColorStatus = {
		type = "select",
		order = 45,
		name = "Text Color",
		get = function()
			return selectedSkin.kNameText_color_status or addon.ColorStatusDefaults.kNameText
		end,
		set = function (_, v)
			selectedSkin.kNameText_color_status =  v
			Update()
		end,
		values = ColorStatuses,
	},
	nameColor = {
		type = "color",
		order = 46,
		hasAlpha = true,
		name = "Name Text Color",
		get = function()
			return unpack( selectedSkin.kNameText_color_default or addon.ColorDefaults.kNameText )
		end,
		set = function( _, r,g,b,a )
			selectedSkin.kNameText_color_default = { r, g, b, a }
			Update()
		end,
		hidden = function() return (selectedSkin.kNameText_color_status or addon.ColorStatusDefaults.kNameText)~='color' end,
	},
	[1] = { Opt_MakeThreatColor, 50, 'kNameText' },
}, nil, { disabled = function() return not selectedSkin.kNameText_enabled end } )

Opt_SetupOption( 'Skins/Settings', 'Level Text', {
	levelEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Level Text", true),
		get = function() return selectedSkin.kLevelText_enabled end,
		set = function (_, value)
			selectedSkin.kLevelText_enabled = value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Level Text" },
	levelOffsetX =  {
		type = 'range', order = 10, name = 'X Adjust', min = -150, softMax = 150, step = 1,
		get = function() return selectedSkin.levelOffsetX or -62 end,
		set = function(info,value)
			selectedSkin.levelOffsetX = value~=-62 and value or nil
			Update()
		end,
	},
	levelOffsetY =  {
		type = 'range', order = 11, name = 'Y Adjust', min = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.levelOffsetY or -4 end,
		set = function(info,value)
			selectedSkin.levelOffsetY = value~=-4 and value or nil
			Update()
		end,
	},
	header2 = { type = "header", order = 11.5, name = "Font" },
	levelAlign = {
		type = "select",
		order = 12,
		name = "Horizontal Align",
		get = function () return selectedSkin.levelAnchorPoint or 'LEFT' end,
		set = function (_, v)
			selectedSkin.levelAnchorPoint = v~='LEFT' and v or nil
			Update()
		end,
		values = fontHorizontalAlignValues,
	},
	levelFontFile = {
		type = "select", dialogControl = "LSM30_Font",
		order = 21,
		name = "Font Name",
		values = AceGUIWidgetLSMlists.font,
		get = function () return selectedSkin.levelFontFile or 'Accidental Presidency' end,
		set = function (_, v)
			selectedSkin.levelFontFile = v
			Update()
		end,
	},
	levelFontFlags = {
		type = "select",
		order = 22,
		name = "Font Border",
		values = fontFlagsValues,
		get = function () return selectedSkin.levelFontFlags or "OUTLINE" end,
		set = function (_, v)
			selectedSkin.levelFontFlags =  v ~= "OUTLINE" and v or nil
			Update()
		end,
	},
	levelFontSize = {
		type = "range",
		order = 23,
		name = 'Font Size',
		min = 1,
		softMax = 50,
		step = 1,
		get = function () return selectedSkin.levelFontSize or 14 end,
		set = function (_, v)
			selectedSkin.levelFontSize = v~=14 and v or nil
			Update()
		end,
	},
	header3 = { type = "header", order = 44, name = "Colors" },
	levelColorStatus = {
		type = "select",
		order = 45,
		name = "Text Color",
		get = function()
			return selectedSkin.kLevelText_color_status or addon.ColorStatusDefaults.kLevelText
		end,
		set = function (_, v)
			selectedSkin.kLevelText_color_status =  v
			Update()
		end,
		values = ColorStatuses,
	},
	levelColor = {
		type = "color",
		order = 50,
		hasAlpha = true,
		name = "Level Text Color",
		get = function()
			return unpack( selectedSkin.kLevelText_color_default or addon.ColorDefaults.kLevelText )
		end,
		set = function( _, r,g,b,a )
			selectedSkin.kLevelText_color_default = { r, g, b, a }
			Update()
		end,
		hidden = function() return (selectedSkin.kLevelText_color_status or addon.ColorStatusDefaults.kLevelText)~='color' end,
	},
	[1] = { Opt_MakeThreatColor, 50, 'kLevelText' },
}, nil, { disabled = function() return not selectedSkin.kLevelText_enabled end } )

Opt_SetupOption( 'Skins/Settings', 'Cast Bar', {
	barEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Cast Bar", true),
		get = function()
			return selectedSkin.kCastBar_enabled
		end,
		set = function (_, value)
			selectedSkin.kCastBar_enabled = value
			Update()
		end,
	},
	header = { type = "header", order = 50, name = "Cast Bar Visibility" },
	barHiddenFriendly = {
		type = "toggle",
		order = 51, width = "double",
		name = "Disabled for Friendly Units",
		get = function() return selectedSkin.castBarHiddenFriendly==true or not selectedSkin.kCastBar_enabled end,
		set = function (_, value)
			selectedSkin.castBarHiddenFriendly = value or nil
			Update()
		end,
	},
	barHiddenNotFriendly = {
		type = "toggle",
		order = 52, width = "double",
		name = "Disabled for not Friendly Units",
		get = function() return selectedSkin.castBarHiddenFriendly==false or not selectedSkin.kCastBar_enabled end,
		set = function (_, value)
			if value then
				selectedSkin.castBarHiddenFriendly = false
			else
				selectedSkin.castBarHiddenFriendly = nil
			end
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Cast Bar" },
	barHeight =  {
		type = 'range', order = 10, name = 'Cast Bar Height', min = 1, softMax = 64, step = 1,
		get = function() return selectedSkin.castBarHeight or 8 end,
		set = function(info,value)
			selectedSkin.castBarHeight = value~=8 and value or nil
			Update()
		end,
	},
	barGap =  {
		type = 'range', order = 10, name = 'Cast Bar Separation', min = 0, softMax = 64, step = 1,
		get = function() return selectedSkin.castBarGap or 0 end,
		set = function(info,value)
			selectedSkin.castBarGap = value~=0 and value or nil
			Update()
		end,
	},
	barTexture = {
		type = "select", dialogControl = "LSM30_Statusbar",
		order = 11,
		name = "Bar Texture",
		desc = "Adjust the bar texture.",
		get = function (info) return selectedSkin.castBarTexture or "Minimalist" end,
		set = function (info, v)
			selectedSkin.castBarTexture = v
			Update()
		end,
		values = AceGUIWidgetLSMlists.statusbar,
		hidden = function() return not addon.isClassic end,
	},
	headerBorder = { type = "header", order = 12, name = "Border", hidden = function() return not addon.__db.global.classicBorders end },
	barBorderTexture = {
		type = "select",
		order = 13,
		name = "Border Texture",
		get = function()
			return selectedSkin.castBarBorderTexture or addon.BorderTextureDefault
		end,
		set = function (_, v)
			selectedSkin.castBarBorderTexture = (v~=addon.BorderTextureDefault) and v or nil
			Update()
		end,
		values = addon.BorderTextures,
		hidden = function() return not addon.__db.global.classicBorders end,
	},
	barBorderColor = {
		type = "color",
		order = 15,
		hasAlpha = true,
		name = "Border Color",
		get = function()
			return unpack( selectedSkin.castBarBorderColor or addon.ColorWhite )
		end,
		set = function( _, r,g,b,a )
			selectedSkin.castBarBorderColor = { r, g, b, a }
			Update()
		end,
		hidden = function() return not addon.__db.global.classicBorders end,
	},
	headerIcon = { type = "header", order = 16, name = "Icon" },
	barShowIcon = {
		type = "toggle",
		order = 16.1,
		name = "Show Spell Icon",
		get = function() return selectedSkin.castBarIconEnabled end,
		set = function (_, value)
			selectedSkin.castBarIconEnabled = value or nil
			Update()
		end,
	},
	barIconSize = {
		type = "range",
		order = 16.2,
		width = "normal",
		name = "Icon Size",
		desc = "Set zero to use the cast bar height",
		min = 0, softMax = 65, step = 1,
		get = function()
			return selectedSkin.castBarIconSize or 0
		end,
		set = function (_, value)
			selectedSkin.castBarIconSize = value~=0 and value or nil
			Update()
		end,
	},
	barIconOffsetX = {
		type = "range",
		order = 16.3,
		width = "normal",
		name = "X Offset",
		desc = "Horizontal Offset",
		softMin = -256, softMax = 256, step = 1,
		get = function()
			return selectedSkin.castBarIconOffsetX or -1
		end,
		set = function (_, value)
			selectedSkin.castBarIconOffsetX = value~=-1 and value or nil
			Update()
		end,
	},
	barIconOffsetY = {
		type = "range",
		order = 16.4,
		width = "normal",
		name = "Y Offset",
		desc = "Horizontal Offset",
		softMin = -128, softMax = 128, step = 1,
		get = function()
			return selectedSkin.castBarIconOffsetY or 0
		end,
		set = function (_, value)
			selectedSkin.castBarIconOffsetY = value~=0 and value or nil
			Update()
		end,
	},
	headerText = { type = "header", order = 20, name = "Text" },
	cbFontFile = {
		type = "select", dialogControl = "LSM30_Font",
		order = 21,
		name = "Font Name",
		values = AceGUIWidgetLSMlists.font,
		get = function () return selectedSkin.castBarFontFile or 'Roboto Condensed Bold' end,
		set = function (_, v)
			selectedSkin.castBarFontFile = v
			Update()
		end,
	},
	cbFontFlags = {
		type = "select",
		order = 22,
		name = "Font Border",
		values = fontFlagsValues,
		get = function () return selectedSkin.castBarFontFlags or "OUTLINE" end,
		set = function (_, v)
			selectedSkin.castBarFontFlags =  v ~= "OUTLINE" and v or nil
			Update()
		end,
	},
	cbFontSize = {
		type = "range",
		order = 23,
		name = 'Font Size',
		min = 1,
		softMax =50,
		step = 1,
		get = function () return selectedSkin.castBarFontSize or 8 end,
		set = function (_, v)
			selectedSkin.castBarFontSize = v~=8 and v or nil
			Update()
		end,
	},
}, nil, { disabled = function() return not selectedSkin.kCastBar_enabled end } )

Opt_SetupOption( 'Skins/Settings', 'Raid Icon', {
	raidTargetEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Raid Icon", true),
		get = function() return selectedSkin.RaidTargetFrame_enabled end,
		set = function (_, value)
			selectedSkin.RaidTargetFrame_enabled = value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Raid Icon" },
	raidTargetSize =  {
		type = 'range', order = 33, name = 'Icon Size', min = 0, softMax = 64, step = 1,
		name = "Icon Size",
		desc = "Raid Target Icon Size",
		get = function() return selectedSkin.raidTargetSize or 20 end,
		set = function(info,value)
			selectedSkin.raidTargetSize = value~=20 and value or nil
			Update()
		end,
	},
	raidTargetOffsetX =  {
		type = 'range', order = 31, name = 'X Adjust', softMin = -32, softMax = 200, step = 1,
		get = function() return selectedSkin.raidTargetOffsetX or 154 end,
		set = function(info,value)
			selectedSkin.raidTargetOffsetX = value~=154 and value or nil
			Update()
		end,
	},
	raidTargetOffsetY =  {
		type = 'range', order = 32, name = 'Y Adjust', softMin = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.raidTargetOffsetY or 0 end,
		set = function(info,value)
			selectedSkin.raidTargetOffsetY = value~=0 and value or nil
			Update()
		end,
	},
}, nil, { disabled = function() return not selectedSkin.RaidTargetFrame_enabled end } )

Opt_SetupOption( 'Skins/Settings', 'Classif Icon', {
	classIconEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Classification Icon", true),
		get = function() return selectedSkin.kIcon_enabled end,
		set = function (_, value)
			selectedSkin.kIcon_enabled= value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Position & Size" },
	classIconSize =  {
		type = 'range', order = 43, name = 'Icon Size', min = 0, softMax = 32, step = 1,
		name = "Icon Size",
		desc = "Classification Icon Size. Set Zero to hide the Icon.",
		get = function() return selectedSkin.classIconSize or 14 end,
		set = function(info,value)
			selectedSkin.classIconSize = value~=14 and value or nil
			Update()
		end,
	},
	classIconOffsetX =  {
		type = 'range', order = 41, name = 'X Adjust', softMin = -32, softMax = 200, step = 1,
		get = function() return selectedSkin.classIconOffsetX or 0 end,
		set = function(info,value)
			selectedSkin.classIconOffsetX = value~=0 and value or nil
			Update()
		end,
		disabled = function() return selectedSkin.classIconSize == 0 or not selectedSkin.kIcon_enabled end,
	},
	classIconOffsetY =  {
		type = 'range', order = 42, name = 'Y Adjust', softMin = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.classIconOffsetY or 0 end,
		set = function(info,value)
			selectedSkin.classIconOffsetY = value~=0 and value or nil
			Update()
		end,
		disabled = function() return selectedSkin.classIconSize == 0 or not selectedSkin.kIcon_enabled end,
	},
	header2 = { type = "header", order = 50, name = "Icon to Display" },
	classIconPlayers = {
		type = "toggle",
		order = 51, width = "double",
		name = 'Display class icons for Players',
		get = function()
			return not selectedSkin.classIconDisablePlayers
		end,
		set = function (_, value)
			selectedSkin.classIconDisablePlayers = (not value) or nil
			if selectedSkin.classIconDisablePlayers then
				selectedSkin.classIconDisableNPCs = nil
			end
			Update()
		end,
		disabled = function() return selectedSkin.classIconUserTexture~=nil end,
	},
	classIconNPCs = {
		type = "toggle",
		order = 52, width = "double",
		name = 'Display rare/elite/boss icons for NPCs',
		get = function()
			return not selectedSkin.classIconDisableNPCs
		end,
		set = function (_, value)
			selectedSkin.classIconDisableNPCs = (not value) or nil
			if selectedSkin.classIconDisableNPCs then
				selectedSkin.classIconDisablePlayers = nil
			end
			Update()
		end,
		disabled = function() return selectedSkin.classIconUserTexture~=nil end,
	},
	classIconTexture = {
		type = 'select', width = 'normal', order = 53,
		name = 'Select icons theme',
		get = function()
				return selectedSkin.classIconTexture or 'Interface\\Addons\\KiwiPlates\\media\\classif'
		end,
		set = function(info,value)
			selectedSkin.classIconTexture = (value~='Interface\\Addons\\KiwiPlates\\media\\classif') and value or nil
			Update()
		end,
		values = {
			['Interface\\Addons\\KiwiPlates\\media\\classif']    = 'Default',
			['Interface\\Addons\\KiwiPlates\\media\\classifsb'] = 'Squared Black',
			['Interface\\Addons\\KiwiPlates\\media\\classifsw'] = 'Squared White',
			['Interface\\Addons\\KiwiPlates\\media\\classifcb'] = 'Circled Black',
			['Interface\\Addons\\KiwiPlates\\media\\classifcw'] = 'Circled White',
		},
		disabled = function() return selectedSkin.classIconUserTexture~=nil end,
	},
	classIconUserTexture = {
		type = 'input',
		order = 54,
		name = "Or type a custom Texture path",
		width = "full",
		desc = "Type the file path to a game texture, leave the text field empty to use the default textures.",
		get = function()
			return selectedSkin.classIconUserTexture
		end,
		set = function(_,value)
			value = strtrim(value)
			selectedSkin.classIconUserTexture = value~='' and value or nil
			Update()
		end,
	},
	classIconUserPreview = {
		type = "description",
		order= 55,
		type = "execute",
		name = "(icon preview)",
		width = "full",
		image = function(info)
			return tonumber(selectedSkin.classIconUserTexture) or selectedSkin.classIconUserTexture

		end,
		hidden = function() return not selectedSkin.classIconUserTexture end,
	},
}, nil, { disabled = function() return not selectedSkin.kIcon_enabled end } )

Opt_SetupOption( 'Skins/Settings', 'Target Class', {
	targetClassIconEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Target Class", true),
		get = function() return selectedSkin.kTargetClass_enabled end,
		set = function (_, value)
			selectedSkin.kTargetClass_enabled= value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Position & Size" },
	targetClassIconSize =  {
		type = 'range', order = 43, name = 'Icon Size', min = 0, softMax = 32, step = 1,
		name = "Icon Size",
		desc = "Classification Icon Size. Set Zero to hide the Icon.",
		get = function() return selectedSkin.targetClassIconSize or 14 end,
		set = function(info,value)
			selectedSkin.targetClassIconSize = value~=14 and value or nil
			Update()
		end,
	},
	targetClassIconOffsetX =  {
		type = 'range', order = 41, name = 'X Adjust', softMin = -32, softMax = 200, step = 1,
		get = function() return selectedSkin.targetClassIconOffsetX or 0 end,
		set = function(info,value)
			selectedSkin.targetClassIconOffsetX = value~=0 and value or nil
			Update()
		end,
		disabled = function() return selectedSkin.targetClassIconSize == 0 or not selectedSkin.kTargetClass_enabled end,
	},
	targetClassIconOffsetY =  {
		type = 'range', order = 42, name = 'Y Adjust', softMin = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.targetClassIconOffsetY or 0 end,
		set = function(info,value)
			selectedSkin.targetClassIconOffsetY = value~=0 and value or nil
			Update()
		end,
		disabled = function() return selectedSkin.targetClassIconSize == 0 or not selectedSkin.kTargetClass_enabled end,
	},
	header2 = { type = "header", order = 50, name = "Icon to Display" },
	targetClassIconTexture = {
		type = 'select', width = 'normal', order = 53,
		name = 'Select icons theme',
		get = function()
				return selectedSkin.targetClassIconTexture or 'Interface\\Addons\\KiwiPlates\\media\\classif'
		end,
		set = function(info,value)
			selectedSkin.targetClassIconTexture = (value~='Interface\\Addons\\KiwiPlates\\media\\classif') and value or nil
			Update()
		end,
		values = {
			['Interface\\Addons\\KiwiPlates\\media\\classif']   = 'Default',
			['Interface\\Addons\\KiwiPlates\\media\\classifsb'] = 'Squared Black',
			['Interface\\Addons\\KiwiPlates\\media\\classifsw'] = 'Squared White',
			['Interface\\Addons\\KiwiPlates\\media\\classifcb'] = 'Circled Black',
			['Interface\\Addons\\KiwiPlates\\media\\classifcw'] = 'Circled White',
		},
	},
}, nil, { disabled = function() return not selectedSkin.kTargetClass_enabled end } )

Opt_SetupOption( 'Skins/Settings', 'Attackers', {
	attackersEnabled = {
		type = "toggle",
		order = 0, width = "double",
		name = FormatTitle("Attackers", true),
		desc = "Display role icons of players targeting the unit nameplate. Only works in party, not in raid.",
		get = function() return selectedSkin.kAttackers_enabled end,
		set = function (_, value)
			selectedSkin.kAttackers_enabled = value
			Update()
		end,
	},
	header1 = { type = "header", order = 5, name = "Attackers" },
	attackersOffsetX =  {
		type = 'range', order = 10, name = 'X Adjust', min = -150, softMax = 150, step = 1,
		get = function() return selectedSkin.attackersOffsetX or 0 end,
		set = function(info,value)
			selectedSkin.attackersOffsetX = value~=0 and value or nil
			Update()
		end,
	},
	attackersOffsetY =  {
		type = 'range', order = 11, name = 'Y Adjust', min = -50, softMax = 50, step = 1,
		get = function() return selectedSkin.attackersOffsetY or 0 end,
		set = function(info,value)
			selectedSkin.attackersOffsetY = value~=0 and value or nil
			Update()
		end,
	},
	attackersAlign = {
		type = "select",
		order = 12,
		name = "Horizontal Align",
		get = function () return selectedSkin.attackersAnchorPoint or 'CENTER' end,
		set = function (_, v)
			selectedSkin.attackersAnchorPoint = v~='CENTER' and v or nil
			Update()
		end,
		values = fontHorizontalAlignValues,
	},
	attackersIconSize = {
		type = "range",
		order = 55,
		name = 'Icons Size',
		min = 0,
		softMax = 23,
		step = 1,
		get = function () return selectedSkin.attackersIconSize or 14 end,
		set = function (_, v)
			selectedSkin.attackersIconSize = v~=14 and v or nil
			Update()
		end,
	},
}, nil, { disabled = function() return not selectedSkin.kAttackers_enabled end } )

--------------------------------------------------------
-- Color Statuses
--------------------------------------------------------

-- Colors: Unit Level
local options = Opt_MakeWidgetsToColorize({}, 'level', 'Unit Level')
options.header1 = { type = "header", order = 200, name = "Quest Difficulty Colors by Level" }
addon:RegisterMessage('ENABLE', function()
	local colors = addon.DIFFICULTY_COLOR
	for i=#colors,1,-1 do
		options['diff'..i] = {
			type = "color",
			width = "double",
			order = 300-i,
			name = string.format( '|cFFffffff%s|r', colors[i] ),
			get = function() return unpack( colors[colors[i]] or addon.ColorDefault ) end,
			set = false,
			disabled = true,
		}
	end
end	)
Opt_SetupOption( 'Skins/Settings', 'Colors: Unit Level', options, 101 )

-- Colors: ClassColors
local options = Opt_MakeWidgetsToColorize({}, 'class', 'Class Colors')
options.header1 = { type = "header", order = 10, name = "Colors" }
local order = 11
for class,color in pairs(addon.ClassColors) do
	options[class] = {
		type = "color",
		width = "normal",
		order = class == 'UNKNOWN' and 90 or order,
		hasAlpha = true,
		name = class,
		desc = class,
		get = function()
			return unpack( addon.ClassColors[class] )
		end,
		set = function( _, r,g,b,a )
			addon.ClassColors[class] = { r,g,b,a }
			addon.db.general.classColor[class] = addon.ClassColors[class]
			Update()
		end,
	}
	order = order + 1
end
options.header2 = { type = "header", order = 99, name = "", hidden = function() return not next(addon.db.general.classColor) end }
options.reset = {
	type = 'execute',
	order = 100,
	width = 'half',
	name = 'Reset',
	desc = 'Set default Blizzard class colors',
	func = function()
		wipe(addon.db.general.classColor)
		for class,color in pairs(RAID_CLASS_COLORS) do
			addon.ClassColors[class] = { color.r, color.g, color.b, 1 }
		end
		addon.ClassColors.UNKNOWN = {1,1,1,1}
		Update()
	end,
	hidden = function() return not next(addon.db.general.classColor) end,
	confirm = function() return "Are you Sure?" end,
}
Opt_SetupOption( 'Skins/Settings', 'Colors: ClassColors', options, 102 )

-- Colors: Unit Reaction
local options = {
	header1 = { type = "header", order = 30, name = "Colors" },
	reactionColorHostile = {
		type = "color",
		order = 35,
		width = "half",
		hasAlpha = true,
		name = "Hostile",
		desc = "Color for Hostile Units",
		get = function()
			return unpack( addon.db.general.reactionColor.hostile )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.reactionColor.hostile = { r, g, b, a }
			Update()
		end,
	},
	reactionColorNeutral = {
		type = "color",
		order = 36,
		width = "half",
		hasAlpha = true,
		name = "Neutral",
		desc = "Color for Neutral Units",
		get = function()
			return unpack( addon.db.general.reactionColor.neutral )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.reactionColor.neutral = { r, g, b, a }
			Update()
		end,
	},
	reactionColorFriendly = {
		type = "color",
		order = 37,
		width = "half",
		hasAlpha = true,
		name = "Friendly",
		desc = "Color for Friendly Units",
		get = function()
			return unpack( addon.db.general.reactionColor.friendly )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.reactionColor.friendly = { r, g, b, a }
			Update()
		end,
	},
	reactionColorTapped = {
		type = "color",
		order = 38,
		width = "half",
		hasAlpha = true,
		name = "Tapped",
		desc = "Color for Tapped Units",
		get = function()
			return unpack( addon.db.general.reactionColor.tapped)
		end,
		set = function( _, r,g,b,a )
			addon.db.general.reactionColor.tapped = { r, g, b, a }
			Update()
		end,
	},
	reactionColorPlayerFriendly = {
		type = "color",
		order = 39,
		width = "normal",
		hasAlpha = true,
		name = "Player Friendly",
		desc = "Color for friendly players",
		get = function()
			return unpack( addon.db.general.reactionColor.playerfriendly or ColorDefault )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.reactionColor.playerfriendly = { r, g, b, a }
			Update()
		end,
	},
	reactionColorPlayerHostile = {
		type = "color",
		order = 39,
		width = "normal",
		hasAlpha = true,
		name = "Player Hostile",
		desc = "Color for hostile players",
		get = function()
			return unpack( addon.db.general.reactionColor.playerhostile or ColorDefault )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.reactionColor.playerhostile = { r, g, b, a }
			Update()
		end,
	},
	header2 = { type = "header", order = 40, name = "" },
	reactionClassColorHostile = {
		type = "toggle",
		order = 41, width = "full",
		name = "Use class colors for enemy players",
		get = function() return addon.db.general.classColorHostilePlayers end,
		set = function (_, value)
			addon.db.general.classColorHostilePlayers = value or nil
			Update()
		end,
	},
	reactionClassColorFriendly = {
		type = "toggle",
		order = 42, width = "full",
		name = "Use class colors for friendly players",
		get = function() return addon.db.general.classColorFriendlyPlayers end,
		set = function (_, value)
			addon.db.general.classColorFriendlyPlayers = value or nil
			Update()
		end,
	},
}
Opt_MakeWidgetsToColorize(options, 'reaction', 'Unit Reaction')
Opt_SetupOption( 'Skins/Settings', 'Colors: Unit Reaction', options, 103 )

-- Colors: Health Percent
local options = {
	header1 = { type = "header", order = 10, name = "Colors" },
	healthColorColor1 = {
		type = "color",
		order = 20,
		width = "full",
		hasAlpha = true,
		name = "Health High",
		desc = "Color",
		get = function()
			return unpack( addon.db.general.healthColor.color1 or ColorDefault )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.healthColor.color1 = { r,g,b,a }
			Update()
		end,
	},
	healthColorPercent1 = {
		type = "range",
		order = 30,
		width = "full",
		name = 'Threshold High',
		isPercent = true,
		min = 0, max = 1,
		step = .01,
		get = function()
			return addon.db.general.healthColor.threshold1 or 1
		end,
		set = function(_, v)
			local cfg = addon.db.general.healthColor
			cfg.threshold1 = v
			cfg.threshold2 = (cfg.threshold2 or 1)<v and cfg.threshold2 or v
			Update()
		end,
	},
	healthColorColor2 = {
		type = "color",
		order = 40,
		width = "full",
		hasAlpha = true,
		name = "Health Medium",
		desc = "Color",
		get = function()
			return unpack( addon.db.general.healthColor.color2 or ColorDefault )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.healthColor.color2 = { r,g,b,a }
			Update()
		end,
	},
	healthColorPercent2 = {
		type = "range",
		order = 50,
		width = "full",
		name = 'Threshold Medium',
		isPercent = true,
		min = 0, max = 1,
		step = .01,
		get = function()
			return addon.db.general.healthColor.threshold2 or 1
		end,
		set = function(_, v)
			local cfg = addon.db.general.healthColor
			cfg.threshold1 = (cfg.threshold1 or 1)>v and cfg.threshold1 or v
			cfg.threshold2 = v
			Update()
		end,
	},
	healthColorColor3 = {
		type = "color",
		order = 60,
		width = "full",
		hasAlpha = true,
		name = "Health Low",
		desc = "Color",
		get = function(info)
			return unpack( addon.db.general.healthColor.color3 or ColorDefault )
		end,
		set = function( _, r,g,b,a )
			addon.db.general.healthColor.color3 = { r,g,b,a }
			Update()
		end,
	},
}
Opt_MakeWidgetsToColorize(options, 'health', "Health Percent")
Opt_SetupOption( 'Skins/Settings', 'Colors: Health Percent', options, 104 )

--------------------------------------------------------
-- Profile Change Refresh
--------------------------------------------------------

addon:RegisterMessage('PROFILE_CHANGED', function()
	selectedSkin = nil
	LibStub("AceConfigRegistry-3.0"):NotifyChange(addon.addonName)
end )

--------------------------------------------------------
-- Publish some methods
--------------------------------------------------------

addon.FormatTitle = FormatTitle
addon.fontFlagsValues = fontFlagsValues
addon.fontHorizontalAlignValues = fontHorizontalAlignValues

function addon:GetSkin()
	return selectedSkin, selectedSkinIndex
end

function addon:SetupOptions(...)
	return Opt_SetupOption(...)
end

function addon.ToggleOptions()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(addon.addonName, addon.OptionsTable)
	LibStub("AceConfigDialog-3.0"):SetDefaultSize(addon.addonName, 675, 620)
	addon.ToggleOptions = function()
		local LIB = LibStub("AceConfigDialog-3.0")
		LIB[ LIB.OpenFrames.KiwiPlates and 'Close' or 'Open' ](LIB, addon.addonName)
	end
	addon.ToggleOptions()
end

do
	local roles = { tank = 'TANK', healer = 'HEALER', dps = 'DAMAGER' }

	local function SetDungeonRole(role,unit)
		if role then
			local unitName = ( unit and unit~='target' and unit ) or ( UnitIsFriend('player','target') and UnitName('target') )
			if unitName and strlen(unitName)>=3 then
				addon.db.roles[unitName] = role~='DAMAGER' and role or nil
				print( string.format( 'KiwiPlates: %s role assigned to "%s"', role, unitName ) )
				return true
			end
		end
	end

	local function DisplayHelp()
		print("KiwiPlates commands:")
		print("  /kiwiplates help")
		print("  /kiwiplates options")
		print("  /kiwiplates tank playername||target  ; set tank role")
		print("  /kiwiplates healer playername||target  ; set healer role")
		print("  /kiwiplates dps playername||target  ; set damager role")
		if next(addon.db.roles) then
			local tanks, healers = {}, {}
			for name,role in pairs(addon.db.roles) do
				local t = (role=='TANK' and tanks) or (role=='HEALER' and healers)
				if t then t[#t+1] = '"'..name..'"' end
			end
			print("  Tanks: ", table.concat( tanks,', ') )
			print("  Healers: ", table.concat( healers,', ') )
		end
	end

	function addon.OnChatCommand(args)
		args = strtrim(strlower(type(args)=='string' and args or ''))
		if addon.isClassic and args~='' and args~='options' then
			local arg1,arg2 = strsplit(" ",args,2)
			if not SetDungeonRole( roles[arg1], arg2 ) then
				DisplayHelp()
			end
		else
			addon.ToggleOptions()
		end
	end
end

--------------------------------------------------------
-- Initialization
--------------------------------------------------------

addon:RegisterMessage('INITIALIZE', function()
	local optionsFrame = CreateFrame( "Frame", nil, UIParent )
	optionsFrame.name = addon.addonName
	local button = CreateFrame("BUTTON", nil, optionsFrame, "UIPanelButtonTemplate")
	button:SetText("Configure KiwiPlates")
	button:SetSize(225,32)
	button:SetPoint('TOPLEFT', optionsFrame, 'TOPLEFT', 20, -20)
	button:SetScript("OnClick", function()
		HideUIPanel(InterfaceOptionsFrame)
		HideUIPanel(GameMenuFrame)
		addon.OnChatCommand()
	end)
	InterfaceOptions_AddCategory(optionsFrame)
	addon.optionsFrame = optionsFrame
end	)

SlashCmdList[ addon.addonName:upper() ] = addon.OnChatCommand
_G[ 'SLASH_'..addon.addonName:upper()..'1' ] = '/kiwiplates'

--------------------------------------------------------
