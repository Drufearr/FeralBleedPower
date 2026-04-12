_, fbp = ...
FeralBleedPowerDB = FeralBleedPowerDB or {}

local frameChooserFrame
local frameChooserBackground
local frameChooserBackgroundText
local frameChooserBox
local oldFocus


function fbp.getFrameName(frame)
	if InCombatLockdown() then
		print("in combat, do it later")
		return
	end
	if frame:GetName() then return {"name", frame:GetName()} end

	local cdmViewers = {[BuffIconCooldownViewer]=1, [EssentialCooldownViewer]=1, [UtilityCooldownViewer]=1}
	if cdmViewers[frame:GetParent()] and frame.cooldownInfo and frame.cooldownInfo.spellID then
		return {"spellID", frame.cooldownInfo.spellID, frame:GetParent():GetName()}
	end

	if frame:GetSpellID() then
		return {"ayije", frame:GetSpellID(), frame:GetParent():GetName()}
	end

	return {"name", UIParent}
end

function fbp.findAnchor(anchorInfo)
	if InCombatLockdown() then
		print("in combat, do it later")
		return
	end
	if type(anchorInfo) == "table" then
		local anchorType, anchorKey, anchorParent = unpack(anchorInfo)
		-- regular frame w a name
		if anchorType == "name" then return _G[anchorKey] end
		if anchorType == "ayije" then 
			for _, child in ipairs({_G[anchorParent]:GetChildren()}) do
				if child.GetSpellID and child:GetSpellID() == anchorKey then
					return child
				end
			end
		end
		-- cdm frames dont have names
		if anchorType == "spellID" then
			local cdmViewers = {
				["BuffIconCooldownViewer"] = BuffIconCooldownViewer, 
				["EssentialCooldownViewer"] = EssentialCooldownViewer, 
				["UtilityCooldownViewer"] = UtilityCooldownViewer
			}
			-- look for the specific cdm viewer first
			if cdmViewers[anchorParent] then 
				for _, child in ipairs({cdmViewers[anchorParent]:GetChildren()}) do
					if child.cooldownInfo and child.cooldownInfo.spellID and anchorKey == child.cooldownInfo.spellID then
						return child
					end
				end
			end
			-- fallback to looking through all of them if that fails
			for _, viewer in ipairs(cdmViewers) do
				for _, child in ipairs({viewer:GetChildren()}) do
					if child.cooldownInfo and child.cooldownInfo.spellID and anchorKey == child.cooldownInfo.spellID then
						return child
					end
				end
			end
		end
	end
	return nil
end

function fbp.startFrameChooser(frame)
	if InCombatLockdown() then
		print("in combat, do it later")
		return
	end
 	if not frame then return end
	if not frameChooserBackground then
		frameChooserBackground = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		frameChooserBackground:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
		frameChooserBackground:SetBackdropColor(0, 0, 0, 0.2)
		frameChooserBackground:SetAllPoints()
		frameChooserBackground:SetFrameStrata("FULLSCREEN_DIALOG")
		frameChooserBackground:SetFrameLevel(1000)
		frameChooserBackground:EnableMouse(false)
		frameChooserBackgroundText = frameChooserBackground:CreateFontString(nil, "OVERLAY", "GameTooltipText")
		frameChooserBackgroundText:ClearAllPoints()
		frameChooserBackgroundText:SetPoint("TOP")
		frameChooserBackgroundText:SetFont("Fonts\\FRIZQT__.TTF", 40, "OUTLINE")
		frameChooserBackgroundText:SetText("Right click to exit frame selector")
	end
	frameChooserBackground:Show()
	frameChooserBackgroundText:Show()
  	if not frameChooserFrame then
		frameChooserFrame = CreateFrame("Frame")
		frameChooserBox = CreateFrame("Frame", nil, frameChooserFrame, "BackdropTemplate")
		frameChooserBox:SetFrameStrata("TOOLTIP")
		frameChooserBox:SetFrameLevel(1001)
		frameChooserBox:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12,
			insets = {left = 0, right = 0, top = 0, bottom = 0}
		})
		frameChooserBox:SetBackdropBorderColor(0.1, 1, 0)
		frameChooserBox:Hide()
	end
	frameChooserFrame:SetScript("OnUpdate", function()
		if IsMouseButtonDown("RightButton") then
		  fbp.stopFrameChooser()
		elseif IsMouseButtonDown("LeftButton") and oldFocus then
			fbp.stopFrameChooser()
			local anchorInfo = fbp.getFrameName(oldFocus)
			FeralBleedPowerDB[frame:GetName()] = anchorInfo
			fbp.reanchor(frame, fbp.findAnchor(anchorInfo))
		else
			local focus = GetMouseFoci()[1]
			if focus ~= oldFocus then
				if focus then
					frameChooserBox:ClearAllPoints()
					frameChooserBox:SetPoint("bottomleft", focus, "bottomleft", -4, -4)
					frameChooserBox:SetPoint("topright", focus, "topright", 4, 4)
					frameChooserBox:Show()
				else
					frameChooserBox:Hide()
				end
				oldFocus = focus
			end
			if not focus then
				frameChooserBox:Hide()
			end
		end
	end)
end

function fbp.stopFrameChooser()
	if frameChooserFrame then
		frameChooserFrame:SetScript("OnUpdate", nil)
		frameChooserBox:Hide()
	end
	if frameChooserBackground then
		frameChooserBackground:Hide()
		frameChooserBackgroundText:Hide()
	end
end


function fbp.reanchor(frame, anchor)
	if not anchor or frame == anchor then return end
	frame:ClearAllPoints()
	frame:GetParent():SetFrameLevel(anchor:GetFrameLevel() + 100)
	frame:SetPoint(
		FeralBleedPowerDB["relative_point"] or "CENTER", 
		anchor, 
		FeralBleedPowerDB["anchor_point"] or "CENTER", 
		FeralBleedPowerDB["x_off"] or 0, 
		FeralBleedPowerDB["y_off"] or 0
	)
	frame:Show()
end

function fbp.anchorFrames()
	local isFeral = UnitClassBase("player") == "DRUID" and GetSpecialization() == 2
	for _, f in pairs(fbp.text_frames) do
		if isFeral then
			local anchor = fbp.findAnchor(FeralBleedPowerDB[f])
			fbp.reanchor(_G[f], anchor)
		else
			_G[f]:Hide()
		end
	end
end

function fbp.resize()
	for _, f in pairs(fbp.text_frames) do
		if _G[f] then
			local font = FeralBleedPowerDB["font_fam"] and "Interface\\FONTS\\"..FeralBleedPowerDB["font_fam"]..".TTF" or "FONTS\\FRIZQT__.TTF"
			_G[f]:SetFont(font, FeralBleedPowerDB["font_size"] or 20, "OUTLINE")
		end
	end
end