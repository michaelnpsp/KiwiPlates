----------------------------------------------------------------
-- KiwiPlates: utility functions
----------------------------------------------------------------

local addon = KiwiPlates

local tremove = table.remove

-- Empty function
addon.Dummy = function() end

 -- deep copy table
do
	local function CopyTable(src, dst)
		if type(dst)~="table" then dst = {} end
		for k,v in pairs(src) do
			if type(v)=="table" then
				dst[k] = CopyTable(v,dst[k])
			elseif dst[k]==nil then
				dst[k] = v
			end
		end
		return dst
	end
	addon.CopyTable = CopyTable
end

-- check if an ipairs table contains a specific value
addon.TableContains = tContains

-- remove an ipairs table item by value
function addon.TableRemoveByValue(t,v)
	for i=#t,1,-1 do
		if t[i]==v then
			table.remove(t,i)
			return
		end
	end
end

-- Repeating Timers Management
do
	local timers = {}
	local function SetDuration(self, duration)
		self.animation:SetDuration(duration)
	end
	-- addon:CreateTimer(func, duration, play)
	-- play=true|nil => timer running; play=false => timer paused
	-- timer methods: timer:Play() timer:Stop() timer:SetDuration()
	function addon:CreateTimer( func, duration, play )
		local timer = tremove(timers)
		if not timer then
			timer = addon:CreateAnimationGroup()
			timer.animation = timer:CreateAnimation()
			timer.SetDuration = SetDuration
			timer:SetLooping("REPEAT")
		end
		timer:SetScript("OnLoop", func)
		if duration then
			timer:SetDuration(duration)
			if play~=false then timer:Play() end
		end
		return timer
	end
	-- addon:CancelTimer(timer)
	function addon:CancelTimer( timer )
		if timer then
			timer:Stop()
			timers[#timers+1] = timer
		end
	end
end

-- precalculate quest difficult colors table, we delay the precalculation
-- because GetQuestDifficultyColor() returns incorrect values before LOGIN
do
	local diff_colors  = {}
	local level_colors = {}
	addon:RegisterMessage('INITIALIZE', function()
		local text, flevel
		local max = UnitLevel('player')+25
		local function register_difficulty(desc, from, to)
			local desc = string.format( to and '%s (%d-%d)' or '%s (%d+)', strmatch(desc,'^QuestDifficulty_(.+)$'), from, to )
			diff_colors[desc] = level_colors[from]
			diff_colors[#diff_colors+1] = desc
			flevel = (to or 0) + 1
		end
		for level=1,max do
			local t = GetQuestDifficultyColor(level)
			if t.font ~= text then
				if text then register_difficulty(text, flevel, level-1) end
				text   = t.font
				flevel = level
				level_colors[level] = { t.r, t.g, t.b, 1 }
				if text=='QuestDifficulty_Impossible' then
					level_colors[-1] = level_colors[level]
					register_difficulty(text, level)
					break
				end
			else
				level_colors[level] = level_colors[level-1]
			end
		end
	end )
	addon.DIFFICULTY_COLOR       = diff_colors
	addon.DIFFICULTY_LEVEL_COLOR = level_colors
end

-- addon:ConfirmDialog(), addon:ShowEditDialog()
do
	StaticPopupDialogs["KIWIPLATES_GENERAL_DIALOG"] = { timeout = 0, whileDead = 1, hideOnEscape = 1, button1 = ACCEPT, button2 = CANCEL }

	local function ShowDialog(message, textDefault, funcAccept, funcCancel, textAccept, textCancel)
		local t = StaticPopupDialogs["KIWIPLATES_GENERAL_DIALOG"]
		t.OnShow = function (self)	if textDefault then self.editBox:SetText(textDefault) end; self:SetFrameStrata("TOOLTIP") end
		t.OnHide = function(self) self:SetFrameStrata("DIALOG")	end
		t.hasEditBox = textDefault and true or nil
		t.text = message
		t.button1 = funcAccept and (textAccept or ACCEPT) or nil
		t.button2 = funcCancel and (textCancel or CANCEL) or nil
		t.OnCancel = funcCancel
		t.OnAccept = funcAccept and function (self)	funcAccept( textDefault and self.editBox:GetText() ) end or nil
		StaticPopup_Show ("KIWIPLATES_GENERAL_DIALOG")
	end

	function addon:MessageDialog(message, funcAccept)
		ShowDialog(message, nil, funcAccept or addon.Dummy)
	end

	function addon:ConfirmDialog(message, funcAccept, funcCancel, textAccept, textCancel)
		ShowDialog(message, nil, funcAccept, funcCancel or addon.Dummy, textAccept, textCancel )
	end

	function addon:ShowEditDialog(message, text, funcAccept, funcCancel)
		ShowDialog(message, text or "", funcAccept, funcCancel or addon.Dummy)
	end
end
