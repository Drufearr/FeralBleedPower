_, fbp = ...

FeralBleedPowerDB = FeralBleedPowerDB or {} 
local f = CreateFrame("Frame")
f.DotStrength = {}
local active_dots = {}
local moonfireKnown = false
local tf_strength = 1
local tf_active = false
local tf_duration = 10
local stealthed = false
local use_tf_fallback = true
local glorped = false
local dot_ids = {1822, 155625, 1079}
local dot_names = {
	[1822] = "Rake", 
	[155625] = "Li", 
	[1079] =  "Rip"
}
local tracked_dots = {
	[1822] = 1822,     -- rake
	[155625] = 155625, -- li
	[1079] = 1079,     -- rip
	[285381] = 1079    -- pw
}
fbp.text_frames = {
	["rake"] = "FeralBleedPower_Rake_Text",
	["li"] = "FeralBleedPower_Li_Text",
	["rip"] = "FeralBleedPower_Rip_Text",
}




local function getTarget()
	local target = UnitGUID("target")

	if issecretvalue(target) then 
		target = C_NamePlate.GetNamePlateForUnit("target")
	end

	if issecretvalue(target) then 
		target = "glorp"
		if not glorped then 
			glorped = true
			print("glorped gg (this means bleed power cannot be stored per target, so if you're in a multi target scenario expect things to be a lil wrong)") 
		end
	end
	return target
end

local function tf()
	-- fallback needed if TF is not tracked in CDM or CDM frame is not available
	-- check if rip has empowered icon or not to determine if TF is active
	-- can't use rake cause of stealth, can't use li in case not specced in
	local a, b = C_Spell.GetSpellTexture(1079)
	if use_tf_fallback then
		return a == 7195161
	end
	return tf_active
end

local function initStrength()
	for i, spellID in ipairs(dot_ids) do
		local frame = CreateFrame("Frame", "FeralBleedPower_"..dot_names[spellID], UIParent)
		if f.DotStrength[spellID] then 
			frame = f.DotStrength[spellID]
		else
			frame = CreateFrame("Frame", "FeralBleedPower_"..dot_names[spellID], UIParent)
		end
		local cfg = FeralBleedPowerDB[dot_names[spellID]] or {}
		frame:ClearAllPoints()
    
		if not frame.t then
			frame.t = frame:CreateFontString("FeralBleedPower_"..dot_names[spellID].."_Text", "OVERLAY", "GameTooltipText")
		end
		frame.t:ClearAllPoints()
		frame.t:SetPoint("CENTER")
		frame.t:EnableMouse(true)
		local font = FeralBleedPowerDB["font_fam"] and "Interface\\FONTS\\"..FeralBleedPowerDB["font_fam"]..".TTF" or "FONTS\\FRIZQT__.TTF"
		frame.t:SetFont(font, FeralBleedPowerDB["font_size"] or 20, "OUTLINE")
		frame.t:SetText("---")
		
		f.DotStrength[spellID] = frame
	end
end

local function clearBleed(spellID)
	local target = getTarget()
	if target and active_dots[target] then active_dots[target][spellID] = nil end

	if (not f.DotStrength[spellID]) or (not f.DotStrength[spellID].t) then return end
	f.DotStrength[spellID].t:SetText("---")
	f.DotStrength[spellID].t:SetTextColor(1, 1, 1)
end

local function updateBleed()
	local target = getTarget()
	if not target or not active_dots[target] then return end

	for i, spellID in ipairs(dot_ids) do
		if f.DotStrength[spellID] then
			local current_strength = 1
			if active_dots[target][spellID] then 
				current_strength = active_dots[target][spellID] 
			else 
				current_strength = -1 
			end

			if current_strength > 0 then
				local new_strength = 1
				if tf() then new_strength = new_strength * tf_strength end
				if spellID == 1822 and stealthed then new_strength = new_strength * 1.6 end
				if not active_dots[target] then active_dots[target] = {} end

				local strength = ceil((new_strength / current_strength) * 100)
				f.DotStrength[spellID].t:SetText(strength)
				if strength > 100 then
					f.DotStrength[spellID].t:SetTextColor(0, 1, 0) -- green
				elseif strength < 100 then
					f.DotStrength[spellID].t:SetTextColor(1, 0.65, 0.65) -- pinkish red
				else
					f.DotStrength[spellID].t:SetTextColor(1, 1, 1) -- hwite
				end
			else
				clearBleed(spellID)
			end
		end
	end
end

local function applyBleed(spellID)
	local target = getTarget()
	if not target then return end

	local new_strength = 1
	if tf() then new_strength = new_strength * tf_strength end
	if spellID == 1822 and stealthed then new_strength = new_strength * 1.6 end

	if not active_dots[target] then active_dots[target] = {} end
	if active_dots[target][spellID] then current_strength = active_dots[target][spellID] end
	active_dots[target][spellID] = new_strength

	updateBleed()
end





local function auraHandler(frame)
	if not frame then return end
	local spellID = frame.cooldownInfo and frame.cooldownInfo.spellID
	if not spellID then return end
	local auraActive = frame.auraInstanceID and type(frame.auraInstanceID) == "number"
	if spellID == 5217 then
		tf_active = auraActive
		updateBleed()
	elseif tracked_dots[spellID] and not auraActive then
		clearBleed(tracked_dots[spellID])
	end
end

local pendingUpdates = {}
local throttled = {}
-- needed so we dont update 50 times any time any aura changes
local function throttledHandler(frame)
	local cdID = frame.cooldownID
	if not cdID then return end
	pendingUpdates[cdID] = frame
	if throttled[cdID] then return end

	throttled[cdID] = true
	C_Timer.After(0.01, function()
		local f = pendingUpdates[cdID]
		if f then
			auraHandler(f)
			pendingUpdates[cdID] = nil
		end
		throttled[cdID] = nil
	end)
end

local function hookFrame(frame)
	if not frame or frame._bleedPowerHook then return end
	frame._bleedPowerHook = true
	if frame.SetAuraInstanceInfo and frame.ClearAuraInstanceInfo then
		hooksecurefunc(frame, "SetAuraInstanceInfo", function(self) throttledHandler(self) end)
		hooksecurefunc(frame, "ClearAuraInstanceInfo", function(self) throttledHandler(self) end)
	else
		print("ERROR: Set/ClearAuraInstanceInfo not found in: ", frame)
	end
end

local function initHooks()
	local tf_id = {[5217] = true} -- needed as a dict otherwise it doesn't work idk
	local viewers = {_G.BuffIconCooldownViewer, _G.EssentialCooldownViewer, _G.UtilityCooldownViewer}
	for _, viewer in ipairs(viewers) do
		for _, child in ipairs({ viewer:GetChildren() }) do
			local cdID = child.cooldownID
			if cdID then
				local spellID = child.cooldownInfo and child.cooldownInfo.spellID or C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
				if tracked_dots[spellID] then
					hookFrame(child)
				elseif tf_id[spellID] then
					use_tf_fallback = false
					hookFrame(child)
				end
			end
		end
	end
end





local function updateTalents()
	local base_tf_strength = 1.15
	tf_strength = base_tf_strength
	local base_tf_duration = 10
	tf_duration = base_tf_duration

	local nodeIDs = {
		82110, --ci
		82107, --tt/rf
		82122 --pred
	}
	local strength_modifiers = {
		[103173] = 0.06, -- ci
		[103168] = 0.10 -- tt
	}
	local duration_modifiers = {
		[103169] = 5, --rf
		[103186] = 5, --pred
	}
	local active = C_ClassTalents.GetActiveConfigID()
	for _, nodeID in ipairs(nodeIDs) do
		local nodeInfo = C_Traits.GetNodeInfo(active, nodeID)
		for _, entryID in pairs(nodeInfo.entryIDsWithCommittedRanks) do
			if strength_modifiers[entryID] then
				tf_strength = tf_strength + nodeInfo.ranksPurchased * strength_modifiers[entryID]
			end
			if duration_modifiers[entryID] then
				tf_duration = tf_duration + nodeInfo.ranksPurchased * duration_modifiers[entryID]
			end
		end
	end 

	moonfireKnown = IsPlayerSpell(155580)
	if f.DotStrength[155625] then
		if moonfireKnown then
			f.DotStrength[155625]:Show()
		else
			f.DotStrength[155625]:Hide()
		end
	end

	initHooks()
	fbp.anchorFrames()
end
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_STEALTH")
f:SetScript("OnEvent", function(self, event, ...)
  	if (event == "PLAYER_ENTERING_WORLD") then
		initHooks()
		C_Timer.After(1, function() initStrength() end) -- delay to account for cdm frames loading
		C_Timer.After(1.1, function() updateTalents() end) -- delay for fbp frames + talent api
	elseif (event == "PLAYER_TARGET_CHANGED") then
		updateBleed()
	elseif (event == "UNIT_SPELLCAST_SUCCEEDED") then
		unitTarget, _, spellID = ...
		if unitTarget ~= "player" then return end
		if spellID == 384255 or spellID == 200749 then -- change talents/change spec
			C_Timer.After(0.5, function() updateTalents() end) -- small delay cause talent api is slow :)
		elseif spellID == 5217 then
			updateBleed()
			C_Timer.After(tf_duration, function() updateBleed() end)
		elseif tracked_dots[spellID] then
			applyBleed(tracked_dots[spellID])
		end
	elseif (event == "UPDATE_STEALTH") then
		if IsStealthed() then
			stealthed = true
		else 
			C_Timer.After(0.01, function() -- grace period because rake cast/application happens _after_ stealth drops
				stealthed = false 
				updateBleed() 
			end)
		end
		updateBleed()
	else
		print("unknown event:", event)
	end
end)



SLASH_FERALBLEEDPOWER1 = "/fbp"
SlashCmdList["FERALBLEEDPOWER"] = function(msg)
	local args = {}
	for arg in msg:gmatch("%S+") do
		table.insert(args, arg)
	end
	local cmd = args[1] or ""
	
	if fbp.text_frames[cmd] then
		fbp.startFrameChooser(_G[fbp.text_frames[cmd]])
	elseif cmd == "font" then
		FeralBleedPowerDB["font_size"] = args[2]
		fbp.resize()
	elseif cmd == "typeface" then
		FeralBleedPowerDB["font_fam"] = args[2]
		fbp.resize()
	elseif cmd == "anchor" then
		FeralBleedPowerDB["relative_point"] = args[2] or "CENTER"
		FeralBleedPowerDB["anchor_point"] = args[3] or "CENTER"
		FeralBleedPowerDB["x_off"] = args[4] or 0
		FeralBleedPowerDB["y_off"] = args[5] or 0
		fbp.anchorFrames()
	else 
		print("FBP: position commands: |c00FFF200/fbp rake|r, |c0000FFF2/fbp li|r, |c00FF9900/fbp rip|r")
		print("FBP: other commands: /fbp font <number>, /fbp anchor <relative_point?> <anchor_point?> <x_offset?> <y_offset?>")
		print("FBP: for custom typeface: /fbp typeface <name>; requires adding the font to 'interface/FONTS/' folder. e.g. /fbp typeface Expressway")
	end
end