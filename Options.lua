-- OpenMe Forever: options window (gear button on the main window, or /openme options).
-- Follows the chosen skin: flat dark (modern) or the game's dialog look (classic).

local _, ns = ...

local C, WHITE, FLAT = ns.C, ns.WHITE, ns.FLAT
local BACKDROP_TEMPLATE = ns.BACKDROP_TEMPLATE
local HEADER_H = ns.HEADER_H
local Accent, IsModern, FlatButton = ns.Accent, ns.IsModern, ns.FlatButton

local WIDTH = 320
local ROW = 24

-- Classic look: the game's dialog border and tooltip-style edges (as in DMme's Forever theme).
local DIALOG_BD = {
	bgFile = WHITE,
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local CLASSIC = {
	bg      = { 0.07, 0.07, 0.08, 0.97 },
	header  = { 0.16, 0.13, 0.09, 0.85 },
	header2 = { 0.05, 0.04, 0.03, 0.85 },
	sep     = { 0.55, 0.45, 0.2, 0.7 },
	muted   = { 0.62, 0.6, 0.52 },
}

-- Heading colour: class colour in the modern skin, gold in the classic one.
local function HeadingColor()
	if IsModern() then return Accent() end
	return 1, 0.82, 0
end

local o            -- the options frame (built on first open)
local checks = {}  -- check rows, refreshed together

local function OnSkin(fn)
	ns.skinHooks[#ns.skinHooks + 1] = fn
	fn(IsModern())
end

local function Build()
	o = CreateFrame("Frame", "OpenMeForeverOptions", UIParent, BACKDROP_TEMPLATE)
	o:SetWidth(WIDTH)
	o:SetPoint("CENTER")
	o:SetFrameStrata("DIALOG")
	o:SetToplevel(true)
	o:SetClampedToScreen(true)
	o:EnableMouse(true)
	o:SetMovable(true)
	o:RegisterForDrag("LeftButton")
	o:SetScript("OnDragStart", o.StartMoving)
	o:SetScript("OnDragStop", o.StopMovingOrSizing)
	o:Hide()
	tinsert(UISpecialFrames, "OpenMeForeverOptions")

	local shadow = o:CreateTexture(nil, "BACKGROUND", nil, -8)
	shadow:SetTexture(WHITE)
	shadow:SetVertexColor(0, 0, 0, 0.35)
	shadow:SetPoint("TOPLEFT", -3, 3)
	shadow:SetPoint("BOTTOMRIGHT", 4, -4)

	local header = o:CreateTexture(nil, "BORDER")
	local line = o:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE)
	line:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
	line:SetHeight(1)

	local icon = o:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", o, "TOPLEFT", 10, -(HEADER_H / 2))
	icon:SetTexture(ns.PORTRAIT)
	local title = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	title:SetText("OpenMe Options")

	local flatClose = FlatButton(o, "x", { bare = true, width = 20, height = 20,
		font = "GameFontHighlight", hoverColor = { 0.9, 0.25, 0.25 } })
	flatClose:SetPoint("TOPRIGHT", -5, -5)
	flatClose:SetScript("OnClick", function() o:Hide() end)
	local gameClose = CreateFrame("Button", nil, o, "UIPanelCloseButton")
	gameClose:SetPoint("TOPRIGHT", -1, -1)
	gameClose:SetScript("OnClick", function() o:Hide() end)

	OnSkin(function(modern)
		local pad = modern and 1 or 5
		o:SetBackdrop(modern and FLAT or DIALOG_BD)
		o:SetBackdropColor(unpack(modern and C.bg or CLASSIC.bg))
		if modern then
			o:SetBackdropBorderColor(unpack(C.frameBorder))
		else
			o:SetBackdropBorderColor(1, 1, 1, 1)
		end
		shadow:SetShown(modern)  -- game windows have no drop shadow
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", pad, -pad)
		header:SetPoint("TOPRIGHT", -pad, -pad)
		header:SetHeight(HEADER_H - 1 - (pad - 1))
		ns.SetGradientV(header, modern and C.header or CLASSIC.header, modern and C.header2 or CLASSIC.header2)
		local r, g, b = HeadingColor()
		line:SetVertexColor(r, g, b, modern and 0.9 or 0.6)
		flatClose:SetShown(modern)
		gameClose:SetShown(not modern)
	end)

	----------------------------------------------------------------------
	-- Builders (top to bottom; y is the current offset from the top)
	----------------------------------------------------------------------
	local y = -(HEADER_H + 10)

	local function Section(text)
		local fs = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("TOPLEFT", 14, y)
		fs:SetText(text:upper())
		local l = o:CreateTexture(nil, "ARTWORK")
		l:SetTexture(WHITE)
		l:SetPoint("LEFT", fs, "RIGHT", 8, 0)
		l:SetPoint("RIGHT", o, "RIGHT", -14, 0)
		l:SetHeight(1)
		OnSkin(function(modern)
			fs:SetTextColor(HeadingColor())
			l:SetVertexColor(unpack(modern and C.sep or CLASSIC.sep))
		end)
		y = y - 20
	end

	local function Check(label, tip, get, set)
		local b = CreateFrame("Button", nil, o)
		b:SetPoint("TOPLEFT", 16, y)
		b:SetPoint("RIGHT", o, "RIGHT", -16, 0)
		b:SetHeight(20)
		-- flat square (modern)
		local box = CreateFrame("Frame", nil, b, BACKDROP_TEMPLATE)
		box:SetSize(14, 14)
		box:SetPoint("LEFT", 0, 0)
		box:SetBackdrop(FLAT)
		box:SetBackdropColor(unpack(C.inputBg))
		box:SetBackdropBorderColor(unpack(C.border))
		local fill = box:CreateTexture(nil, "ARTWORK")
		fill:SetTexture(WHITE)
		fill:SetPoint("TOPLEFT", 3, -3)
		fill:SetPoint("BOTTOMRIGHT", -3, 3)
		-- the game's own check box (classic)
		local cbUp = b:CreateTexture(nil, "ARTWORK")
		cbUp:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
		cbUp:SetSize(24, 24)
		cbUp:SetPoint("CENTER", box, "CENTER")
		local cbCheck = b:CreateTexture(nil, "OVERLAY")
		cbCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		cbCheck:SetAllPoints(cbUp)
		local cbHi = b:CreateTexture(nil, "HIGHLIGHT")
		cbHi:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
		cbHi:SetBlendMode("ADD")
		cbHi:SetAllPoints(cbUp)
		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
		fs:SetPoint("RIGHT")
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs:SetText(label)

		function b.Refresh()
			local on = get() and true or false
			local modern = IsModern()
			box:SetShown(modern)
			fill:SetShown(on)
			fill:SetVertexColor(Accent())
			cbUp:SetShown(not modern)
			cbHi:SetShown(not modern)
			cbCheck:SetShown(not modern and on)
			fs:SetTextColor(on and 1 or 0.7, on and 1 or 0.7, on and 1 or 0.75)
		end
		b:SetScript("OnClick", function()
			PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
			set(not get())
			for _, c in ipairs(checks) do c.Refresh() end
		end)
		b:SetScript("OnEnter", function(self)
			box:SetBackdropBorderColor(Accent())
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label, 1, 1, 1)
			GameTooltip:AddLine(tip, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function()
			box:SetBackdropBorderColor(unpack(C.border))
			GameTooltip:Hide()
		end)
		checks[#checks + 1] = b
		OnSkin(b.Refresh)
		y = y - ROW
		return b
	end

	-- A button that is flat in the modern skin and the game's red button in the classic one.
	local function DualButton(text, width, onClick)
		local flat = FlatButton(o, text, { width = width, height = 22 })
		flat:SetScript("OnClick", onClick)
		local game = CreateFrame("Button", nil, o, "UIPanelButtonTemplate")
		game:SetSize(width, 22)
		game:SetText(text)
		game:SetScript("OnClick", onClick)
		local pair = {}
		function pair:SetPoint(...)
			flat:SetPoint(...)
			game:SetPoint(...)
		end
		function pair:SetEnabled(on)
			flat:SetEnabled(on)
			game:SetEnabled(on)
		end
		OnSkin(function(modern)
			flat:SetShown(modern)
			game:SetShown(not modern)
		end)
		return pair
	end

	----------------------------------------------------------------------
	-- Contents
	----------------------------------------------------------------------
	Section("Window")
	Check("Open by itself when you loot something",
		"Pops the window up when something you can open lands in your bags, and hides it when the list is empty.",
		function() return ns.IsAuto() end,
		function(on) ns.SetAuto(on) end)
	Check("Show items as a list",
		"Shows each item on its own row with its name. Turn off for a grid of icons.",
		function() return ns.IsList() end,
		function(on) ns.SetLayout(on and "list" or "grid") end)
	Check("Compact",
		"Just the items in a thin box: no title bar, buttons or frame art. Drag the edge to move it, press Escape or type /openme to close it, and type /openme options to get back here.",
		function() return ns.IsCompact() end,
		function(on) ns.SetCompact(on) end)
	Check("Modern skin",
		"A flat, dark look in the same style as DMme's Dark theme. Turn off to use the game's own window style.",
		function() return ns.IsModern() end,
		function(on) ns.SetSkin(on and "modern" or "classic") end)

	y = y - 8
	Section("Ignored items")
	local help = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 16, y)
	help:SetPoint("RIGHT", o, "RIGHT", -16, 0)
	help:SetJustifyH("LEFT")
	help:SetText("Right-click an item in the OpenMe window to hide it until you log out or reload.")
	y = y - 30

	local status = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	status:SetPoint("TOPLEFT", 16, y - 4)
	local showAgain = DualButton("Show them again", 120, function()
		ns.Unignore()
	end)
	showAgain:SetPoint("TOPRIGHT", o, "TOPRIGHT", -16, y)
	y = y - 34

	OnSkin(function(modern)
		help:SetTextColor(unpack(modern and C.muted or CLASSIC.muted))
	end)

	function o.Update()
		local n = ns.IgnoredItemCount()
		if n == 0 then
			status:SetText("Nothing ignored right now.")
		else
			status:SetText(n == 1 and "1 item ignored." or (n .. " items ignored."))
		end
		showAgain:SetEnabled(n > 0)
		for _, c in ipairs(checks) do c.Refresh() end
	end

	o:SetHeight(-y + 4)
	o:SetScript("OnShow", function(self)
		PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 850)
		self.Update()
	end)
	o:SetScript("OnHide", function()
		PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 851)
	end)
end

function ns.ToggleOptions()
	if not o then Build() end
	o:SetShown(not o:IsShown())
end

function ns.UpdateOptions()
	if o and o:IsShown() then o.Update() end
end

---------------------------------------------------------------------------
-- Entry in the game's own AddOns options, pointing at the window above.
---------------------------------------------------------------------------
local hasSettings = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
if hasSettings or InterfaceOptions_AddCategory then
	local panel = CreateFrame("Frame")
	panel.name = "OpenMe Forever"
	local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -16)
	heading:SetText("OpenMe Forever")
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
	text:SetText("OpenMe has its own options window. You can also open it with /openme options.")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(160, 24)
	open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
	open:SetText("Open OpenMe Options")
	open:SetScript("OnClick", function()
		if not InCombatLockdown() then
			local blizzard = SettingsPanel or InterfaceOptionsFrame
			if blizzard and blizzard:IsShown() then HideUIPanel(blizzard) end
		end
		if not o then Build() end
		o:Show()
	end)
	if hasSettings then
		local category = Settings.RegisterCanvasLayoutCategory(panel, "OpenMe Forever")
		Settings.RegisterAddOnCategory(category)
	else
		InterfaceOptions_AddCategory(panel)
	end
end
