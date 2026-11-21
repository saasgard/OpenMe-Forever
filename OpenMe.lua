-- OpenMe Forever
-- Pops up a window listing every item in your bags that can be opened.
-- Opening an item needs a real click (secure action button), so each item is a button.
-- Two skins: "classic" (the game's own portrait frame) and "modern" (flat dark,
-- same look as DMme's Dark theme). Options live in Options.lua.

local ADDON_NAME, ns = ...

local COLS        = 5
local BUTTON_SIZE = 32
local SPACING     = 4
local INSET_PAD   = 6
local BOTTOM_BAR  = 26   -- room for the "Open Next" button strip
local LIST_WIDTH  = 230  -- widest a list row gets (icon + name); rows shrink to the longest name
local HEADER_H    = 30   -- modern skin: height of the header band
local PORTRAIT    = "Interface\\AddOns\\OpenMe Forever\\Media\\Icon"
local GEAR        = "Interface\\AddOns\\OpenMe Forever\\Media\\gear"

-- Sizes for the normal window and for compact mode.
-- Compact is bare bones: no title bar, buttons or frame art, just small flat
-- icons in a thin box whose padding doubles as the drag handle. It sizes to
-- its contents: one item is one icon, growing a column at a time up to `cols`.
-- minListWidth: the normal window never gets narrower than its grid, so the
-- title bar and Open Next still fit.
local COMPACT = { size = 24, spacing = 2, pad = 5, cols = 6, listWidth = 180, minListWidth = 24 }
local NORMAL  = { size = BUTTON_SIZE, spacing = SPACING, pad = INSET_PAD, cols = COLS, listWidth = LIST_WIDTH,
	minListWidth = COLS * BUTTON_SIZE + (COLS - 1) * SPACING }

-- Room above the item area: the portrait/title bar (classic) or the header (modern).
local TOP_OFFSET = { classic = 60, modern = HEADER_H + 6 }

-- Backpack + equipped bags (includes the reagent bag slot if the client has one).
local NUM_BAGS = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local OPENABLE_TEXT = ITEM_OPENABLE or "<Right Click to Open>"
local LOCKED_TEXT   = LOCKED or "Locked"

local db
local items = {}          -- one entry per kind of item: { {bag=, slot=, id=, icon=, count=, quality=, link=, quest=}, ... }
local itemTotal = 0       -- items in the list, counting every stack (3 clams in 2 slots = 3)
local ignored = {}        -- itemID (or link) -> true; right-clicked away until logout/reload
local ignoredCount = 0    -- items hidden by `ignored` in the last scan, counting stacks
local buttons = {}
local openableCache = {}  -- itemID -> true/false ("<Right Click to Open>" never changes per item)
local pendingRefresh = false
local pendingSilent = false  -- next refresh should rebuild the list without popping up
local quietUntil = 0         -- GetTime() before which refreshes never pop the window up
local lastCount = 0
local Refresh                -- defined below; item buttons call it after an ignore

local function Print(msg)
	print("|cffffd200OpenMe:|r " .. msg)
end

---------------------------------------------------------------------------
-- Modern skin style (DMme's Dark palette)
---------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
local TOOLTIP_BD = {
	bgFile = WHITE,
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local C = {
	bg          = { 0.055, 0.055, 0.07, 0.94 },
	header      = { 0.11, 0.11, 0.14, 1 },
	header2     = { 0.075, 0.075, 0.095, 1 },
	border      = { 0.20, 0.20, 0.25, 1 },
	frameBorder = { 0.20, 0.20, 0.25, 1 },
	inset       = { 0.035, 0.035, 0.045, 0.9 },
	insetBorder = { 0.13, 0.13, 0.16, 1 },
	inputBg     = { 0.09, 0.09, 0.11, 1 },
	button      = { 0.14, 0.14, 0.17, 1 },
	buttonHi    = { 0.22, 0.22, 0.27, 1 },
	btnText     = { 0.85, 0.85, 0.9 },
	muted       = { 0.55, 0.55, 0.62 },
	sep         = { 0.2, 0.2, 0.25, 1 },
}

-- Settings: only what the player changes is saved; anything missing (nil)
-- means the current default. That way a new default never overrides a choice.
local function IsModern()      -- default: classic skin
	return db ~= nil and db.skin == "modern"
end

local function IsCompact()     -- default: off
	return db ~= nil and db.compact == true
end

local function IsList()        -- default: list
	return db == nil or db.layout ~= "grid"
end

local function IsAuto()        -- default: on
	return db == nil or db.auto ~= false
end

-- Accent colour: the class colour of the character you're playing.
local function Accent()
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 0.82, 0
end

local function SetGradientV(tex, top, bottom)
	tex:SetTexture(WHITE)
	if CreateColor and tex.SetGradient and pcall(tex.SetGradient, tex, "VERTICAL",
			CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
			CreateColor(top[1], top[2], top[3], top[4] or 1)) then
		return
	end
	if tex.SetGradientAlpha then
		tex:SetGradientAlpha("VERTICAL", bottom[1], bottom[2], bottom[3], bottom[4] or 1,
			top[1], top[2], top[3], top[4] or 1)
	else
		tex:SetVertexColor(top[1], top[2], top[3], top[4] or 1)
	end
end

-- Flat button (not secure). opts: width, height, font, bare, hoverColor.
local function FlatButton(parent, text, opts)
	opts = opts or {}
	local b = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
	b:SetBackdrop(FLAT)
	b.label = b:CreateFontString(nil, "OVERLAY", opts.font or "GameFontHighlightSmall")
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	b:SetSize(opts.width or (b.label:GetStringWidth() + 18), opts.height or 20)
	function b:Normal()
		if opts.bare then
			self:SetBackdropColor(0, 0, 0, 0)
			self:SetBackdropBorderColor(0, 0, 0, 0)
		else
			self:SetBackdropColor(unpack(C.button))
			self:SetBackdropBorderColor(unpack(C.border))
		end
		if self:IsEnabled() then
			self.label:SetTextColor(unpack(C.btnText))
		else
			self.label:SetTextColor(0.45, 0.45, 0.5)
		end
	end
	b:SetScript("OnEnter", function(self)
		if not self:IsEnabled() then return end
		local r, g, bl
		if opts.hoverColor then r, g, bl = unpack(opts.hoverColor) else r, g, bl = Accent() end
		self:SetBackdropColor(unpack(C.buttonHi))
		self:SetBackdropBorderColor(r, g, bl, 1)
		self.label:SetTextColor(1, 1, 1)
	end)
	b:SetScript("OnLeave", b.Normal)
	b:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 1, -1) end)
	b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
	b:SetScript("OnEnable", b.Normal)
	b:SetScript("OnDisable", b.Normal)
	b:Normal()
	return b
end

-- Functions run when the skin changes (the options window registers here).
local skinHooks = {}
local function RunSkinHooks()
	local modern = IsModern()
	for _, fn in ipairs(skinHooks) do fn(modern) end
end

---------------------------------------------------------------------------
-- Item detection
---------------------------------------------------------------------------
-- Returns openable, locked, complete (false if the tooltip wasn't ready yet).
local function ScanTooltip(bag, slot)
	if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false, false, false end
	local data = C_TooltipInfo.GetBagItem(bag, slot)
	if not (data and data.lines and #data.lines > 0) then return false, false, false end
	local openable, locked = false, false
	for _, line in ipairs(data.lines) do
		local text = line.leftText
		if text == OPENABLE_TEXT then openable = true end
		if text == LOCKED_TEXT then locked = true end
	end
	return openable, locked, true
end

-- Decides whether a (non-quest) bag item belongs in the list.
-- Tooltips are only read for items that might be openable, and the
-- "can it be opened at all" answer is cached per item ID.
local function IsOpenable(bag, slot, info)
	local id = info.itemID
	if not info.hasLoot and id and openableCache[id] == false then
		return false
	end
	local tipOpenable, locked, complete = ScanTooltip(bag, slot)
	if complete and id then
		openableCache[id] = (info.hasLoot or tipOpenable) and true or false
	end
	return (info.hasLoot or tipOpenable) and not locked
end

-- Returns true if the item starts a quest you haven't accepted (or finished) yet.
local function StartsNewQuest(bag, slot)
	if not C_Container.GetContainerItemQuestInfo then return false end
	local q = C_Container.GetContainerItemQuestInfo(bag, slot)
	if not (q and q.questID) or q.isActive then return false end
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
		and C_QuestLog.IsQuestFlaggedCompleted(q.questID) then
		return false
	end
	return true
end

local function IgnoreKey(id, link)
	return id or link
end

-- Builds the list. The same item in several bag slots becomes one entry
-- (the first slot found) with the counts added up, like a stack in your bags.
local function ScanBags()
	wipe(items)
	itemTotal = 0
	ignoredCount = 0
	local quests = {}
	local byKey = {}
	for bag = 0, NUM_BAGS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local key = info and IgnoreKey(info.itemID, info.hyperlink)
			local count = info and info.stackCount or 1
			if key and ignored[key] then
				ignoredCount = ignoredCount + count
			elseif info then
				local isQuest = StartsNewQuest(bag, slot)
				if isQuest or IsOpenable(bag, slot, info) then
					itemTotal = itemTotal + count
					local existing = key and byKey[key]
					if existing then
						existing.count = existing.count + count
					else
						local entry = {
							bag = bag, slot = slot,
							id = info.itemID,
							icon = info.iconFileID,
							count = count,
							quality = info.quality,
							link = info.hyperlink,
							quest = isQuest or nil,
						}
						if key then byKey[key] = entry end
						if isQuest then
							quests[#quests + 1] = entry
						else
							items[#items + 1] = entry
						end
					end
				end
			end
		end
	end
	-- Quest starters go first so "Open Next" offers them before containers.
	for i = #quests, 1, -1 do
		table.insert(items, 1, quests[i])
	end
end

---------------------------------------------------------------------------
-- Main window (uses the game's own portrait frame template)
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "OpenMeForeverFrame", UIParent, "ButtonFrameTemplate")
frame:Hide()
frame:SetFrameStrata("HIGH")
frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
-- The window holds secure buttons, so it can't be moved during combat.
frame:SetScript("OnDragStart", function(self)
	if not InCombatLockdown() then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	if InCombatLockdown() then return end
	-- Pin the top-left corner, so the window grows right and down as items come in.
	local x, y = self:GetLeft(), self:GetTop()
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	if db then db.pos = { "TOPLEFT", "BOTTOMLEFT", x, y } end
end)

if frame.SetTitle then
	frame:SetTitle("OpenMe")
elseif frame.TitleText then
	frame.TitleText:SetText("OpenMe")
end

if frame.SetPortraitTextureRaw then
	frame:SetPortraitTextureRaw(PORTRAIT)
elseif frame.SetPortraitToAsset then
	frame:SetPortraitToAsset(PORTRAIT)
end

frame:SetScript("OnShow", function() PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN or 862) end)
frame:SetScript("OnHide", function() PlaySound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE or 863) end)

-- The window holds secure buttons, so it can't be hidden during combat.
local function CloseWindow()
	if InCombatLockdown() then
		Print("Can't close during combat.")
	else
		frame:Hide()
	end
end
if frame.CloseButton then
	frame.CloseButton:SetScript("OnClick", CloseWindow)
end

local inset = frame.Inset
inset:EnableMouse(false)   -- let drags on empty space reach the window (compact mode's only handle)

-- Remember every piece of the game's frame art (and whether it was shown),
-- so the modern skin can hide it and the classic skin can bring it back.
local templateParts = {}
local function CollectTemplateParts(owner, skip)
	for _, r in ipairs({ owner:GetRegions() }) do
		templateParts[#templateParts + 1] = { obj = r, shown = r:IsShown() }
	end
	for _, c in ipairs({ owner:GetChildren() }) do
		if c ~= skip then
			templateParts[#templateParts + 1] = { obj = c, shown = c:IsShown() }
		end
	end
end
CollectTemplateParts(frame, inset)
CollectTemplateParts(inset)

local emptyText = inset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("CENTER")
emptyText:SetText("Nothing to open")

local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
countText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 8)
countText:SetJustifyH("LEFT")
countText:SetWordWrap(false)

-- "Open Next" opens the first item in the list with a single click.
local openNextTemplates = "SecureActionButtonTemplate, UIPanelButtonTemplate"
if BACKDROP_TEMPLATE then openNextTemplates = openNextTemplates .. ", " .. BACKDROP_TEMPLATE end
local openNext = CreateFrame("Button", "OpenMeForeverOpenNext", frame, openNextTemplates)
openNext:SetSize(84, 22)
openNext:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)
openNext:SetText("Open Next")
openNext:RegisterForClicks("AnyUp", "AnyDown")
openNext:SetAttribute("type", "item")
-- Cut the count text short rather than letting it run under the button.
countText:SetPoint("RIGHT", openNext, "LEFT", -4, 0)

-- The red button art, faded out in the modern skin. (Alpha, not Hide: the
-- button's own state scripts may show these textures again.)
local openNextArt = {}
for _, r in ipairs({ openNext:GetRegions() }) do
	if r ~= openNext:GetFontString() then
		openNextArt[#openNextArt + 1] = r
	end
end
local openNextFonts = {
	normal = openNext:GetNormalFontObject(),
	highlight = openNext:GetHighlightFontObject(),
	disabled = openNext:GetDisabledFontObject(),
}

local function OpenNext_Style(self, hover)
	if not IsModern() then return end
	if hover and self:IsEnabled() then
		local r, g, b = Accent()
		self:SetBackdropColor(unpack(C.buttonHi))
		self:SetBackdropBorderColor(r, g, b, 1)
	else
		self:SetBackdropColor(unpack(C.button))
		self:SetBackdropBorderColor(unpack(C.border))
	end
end
openNext:HookScript("OnEnter", function(self) OpenNext_Style(self, true) end)
openNext:HookScript("OnLeave", function(self) OpenNext_Style(self, false) end)

-- Gear button: opens the options window.
local gear = CreateFrame("Button", nil, frame)
gear:SetSize(16, 16)
gear.tex = gear:CreateTexture(nil, "ARTWORK")
gear.tex:SetAllPoints()
gear.tex:SetTexture(GEAR)
local function Gear_Color(hover)
	if hover then
		gear.tex:SetVertexColor(Accent())
	elseif IsModern() then
		gear.tex:SetVertexColor(0.6, 0.6, 0.68)
	else
		gear.tex:SetVertexColor(1, 0.82, 0)
	end
end
gear:SetScript("OnEnter", function(self)
	Gear_Color(true)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText("Options")
	GameTooltip:Show()
end)
gear:SetScript("OnLeave", function()
	Gear_Color(false)
	GameTooltip:Hide()
end)
gear:SetScript("OnClick", function()
	if ns.ToggleOptions then ns.ToggleOptions() end
end)

---------------------------------------------------------------------------
-- Modern chrome: drawn on its own layer below everything else
---------------------------------------------------------------------------
local modern = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
modern:SetAllPoints()
modern:SetFrameLevel(frame:GetFrameLevel())
modern:SetBackdrop(FLAT)
modern:SetBackdropColor(unpack(C.bg))
modern:SetBackdropBorderColor(unpack(C.frameBorder))
modern:Hide()

local shadow = modern:CreateTexture(nil, "BACKGROUND", nil, -8)
shadow:SetTexture(WHITE)
shadow:SetVertexColor(0, 0, 0, 0.35)
shadow:SetPoint("TOPLEFT", -3, 3)
shadow:SetPoint("BOTTOMRIGHT", 4, -4)

local header = modern:CreateTexture(nil, "BORDER")
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(HEADER_H - 1)
SetGradientV(header, C.header, C.header2)

local accentLine = modern:CreateTexture(nil, "ARTWORK")
accentLine:SetTexture(WHITE)
accentLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
accentLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
accentLine:SetHeight(1)

local modernIcon = modern:CreateTexture(nil, "ARTWORK")
modernIcon:SetSize(18, 18)
modernIcon:SetPoint("LEFT", modern, "TOPLEFT", 8, -(HEADER_H / 2))
modernIcon:SetTexture(PORTRAIT)

local modernTitle = modern:CreateFontString(nil, "OVERLAY", "GameFontNormal")
modernTitle:SetPoint("LEFT", modernIcon, "RIGHT", 6, 0)
modernTitle:SetText("OpenMe")

local modernClose = FlatButton(modern, "x", { bare = true, width = 20, height = 20,
	font = "GameFontHighlight", hoverColor = { 0.9, 0.25, 0.25 } })
modernClose:SetPoint("TOPRIGHT", -5, -5)
modernClose:SetScript("OnClick", CloseWindow)

-- Item area: a darker panel behind the inset.
local insetBorder = modern:CreateTexture(nil, "BACKGROUND", nil, 1)
insetBorder:SetTexture(WHITE)
insetBorder:SetVertexColor(unpack(C.insetBorder))
insetBorder:SetPoint("TOPLEFT", inset, "TOPLEFT")
insetBorder:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT")
local insetBg = modern:CreateTexture(nil, "BACKGROUND", nil, 2)
insetBg:SetTexture(WHITE)
insetBg:SetVertexColor(unpack(C.inset))
insetBg:SetPoint("TOPLEFT", inset, "TOPLEFT", 1, -1)
insetBg:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -1, 1)

-- Compact chrome: one thin box (flat in the modern skin, tooltip-style in the classic one).
local bare = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
bare:SetAllPoints()
bare:SetFrameLevel(frame:GetFrameLevel())
bare:Hide()

---------------------------------------------------------------------------
-- Item buttons
---------------------------------------------------------------------------
local function ButtonIcon(b)
	return b.icon or b.Icon or _G[b:GetName() .. "IconTexture"]
end

local function Button_OnEnter(self)
	if not self.bag then return end
	if self.rowHi and self.nameText:IsShown() then self.rowHi:Show() end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetBagItem(self.bag, self.slot)
	GameTooltip:AddLine(self.isQuest and "Left-click to view quest" or "Left-click to open", 0.1, 1, 0.1)
	GameTooltip:AddLine("Right-click to ignore until logout", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function Button_OnLeave(self)
	if self.rowHi then self.rowHi:Hide() end
	GameTooltip:Hide()
end

-- Right-click hides every stack of that item until logout or /reload.
local function Button_PostClick(self, button, down)
	if button ~= "RightButton" or down or not self.ignoreKey then return end
	ignored[self.ignoreKey] = true
	GameTooltip:Hide()
	if InCombatLockdown() then
		-- The list can't be rebuilt in combat; grey the item out until it can.
		SetItemButtonDesaturated(self, true)
		pendingRefresh = true
	else
		pendingSilent = true   -- don't let the shorter list count as "new loot"
		Refresh()
	end
	if ns.UpdateOptions then ns.UpdateOptions() end
end

local function GetButton(i)
	local b = buttons[i]
	if b then return b end
	b = CreateFrame("ItemButton", "OpenMeForeverItem" .. i, inset, "SecureActionButtonTemplate")
	b:SetSize(BUTTON_SIZE, BUTTON_SIZE)
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetAttribute("type", "item")
	b:SetAttribute("type2", "ignore")   -- no secure handler: right-click does nothing securely
	b:SetScript("PostClick", Button_PostClick)
	b:SetScript("OnEnter", Button_OnEnter)
	b:SetScript("OnLeave", Button_OnLeave)
	-- Yellow "!" overlay, same as the bags use for quest-starting items.
	b.questBang = b:CreateTexture(nil, "OVERLAY", nil, 2)
	b.questBang:SetTexture(TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\UI-Icon-QuestBang")
	b.questBang:SetAllPoints()
	b.questBang:Hide()
	-- Modern skin: a 1px border behind the icon, coloured by item quality.
	b.flatBorder = b:CreateTexture(nil, "BACKGROUND", nil, -1)
	b.flatBorder:SetTexture(WHITE)
	b.flatBorder:SetAllPoints()
	b.flatBorder:Hide()
	-- List layout: item name, and a faint bar across the row on mouse-over.
	b.nameText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.nameText:SetPoint("LEFT", b, "RIGHT", 8, 0)
	b.nameText:SetJustifyH("LEFT")
	b.nameText:SetWordWrap(false)
	b.nameText:Hide()
	b.rowHi = b:CreateTexture(nil, "BACKGROUND", nil, -2)
	b.rowHi:SetTexture(WHITE)
	b.rowHi:SetVertexColor(1, 1, 1, 0.06)
	b.rowHi:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
	b.rowHi:Hide()
	buttons[i] = b
	return b
end

-- Skin one item button. `quality` is only used by the modern border.
local function SkinButton(b, modernSkin, quality)
	local icon = ButtonIcon(b)
	local normal = b:GetNormalTexture()
	if modernSkin then
		if normal then normal:SetAlpha(0) end
		if b.IconBorder then b.IconBorder:Hide() end
		if icon then
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", 1, -1)
			icon:SetPoint("BOTTOMRIGHT", -1, 1)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		local color = quality and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		if color then
			b.flatBorder:SetVertexColor(color.r, color.g, color.b, 1)
		else
			b.flatBorder:SetVertexColor(unpack(C.border))
		end
		b.flatBorder:Show()
	else
		if normal then normal:SetAlpha(1) end
		if icon then
			icon:ClearAllPoints()
			icon:SetAllPoints(b)
			icon:SetTexCoord(0, 1, 0, 1)
		end
		b.flatBorder:Hide()
	end
end

---------------------------------------------------------------------------
-- Skin switch (out of combat only: it re-anchors frames holding secure buttons)
---------------------------------------------------------------------------
local appliedSkin   -- skin/compact combination last applied; skip the work if unchanged

local function ApplySkin()
	local m = IsModern()
	local compact = IsCompact()
	local key = (m and "modern" or "classic") .. (compact and "-compact" or "")
	if key == appliedSkin then return end
	appliedSkin = key
	for _, part in ipairs(templateParts) do
		part.obj:SetShown(not m and not compact and part.shown)
	end
	modern:SetShown(m and not compact)
	if m then accentLine:SetVertexColor(Accent()) end

	bare:SetShown(compact)
	if compact then
		if m then
			bare:SetBackdrop(FLAT)
			bare:SetBackdropColor(unpack(C.bg))
			bare:SetBackdropBorderColor(unpack(C.frameBorder))
		else
			bare:SetBackdrop(TOOLTIP_BD)
			bare:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
			bare:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
		end
	end
	openNext:SetShown(not compact)
	countText:SetShown(not compact)
	emptyText:SetFontObject(compact and GameFontDisableSmall or GameFontDisable)

	inset:ClearAllPoints()
	if compact then
		inset:SetAllPoints(frame)
	elseif m then
		inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -TOP_OFFSET.modern)
		inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, BOTTOM_BAR)
	else
		inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -TOP_OFFSET.classic)
		inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, BOTTOM_BAR)
	end

	-- Open Next: flat button, or the game's red one.
	for _, r in ipairs(openNextArt) do
		r:SetAlpha(m and 0 or 1)
	end
	if openNext.SetBackdrop then
		if m then
			openNext:SetBackdrop(FLAT)
			OpenNext_Style(openNext, false)
		elseif openNext.ClearBackdrop then
			openNext:ClearBackdrop()
		else
			openNext:SetBackdrop(nil)
		end
	end
	local function SetFont(setter, modernFont, classicFont)
		local f = m and modernFont or classicFont
		if f then openNext[setter](openNext, f) end
	end
	SetFont("SetNormalFontObject", GameFontHighlightSmall, openNextFonts.normal)
	SetFont("SetHighlightFontObject", GameFontHighlightSmall, openNextFonts.highlight)
	SetFont("SetDisabledFontObject", GameFontDisableSmall, openNextFonts.disabled)

	gear:ClearAllPoints()
	if m then
		gear:SetPoint("RIGHT", modernClose, "LEFT", -4, 0)
	elseif frame.CloseButton then
		gear:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)
	else
		gear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -4)
	end
	Gear_Color(false)
	-- The game frame's border/title pieces sit at high frame levels; keep the gear above them all.
	local top = frame:GetFrameLevel()
	for _, c in ipairs({ frame:GetChildren() }) do
		if c ~= gear then top = math.max(top, c:GetFrameLevel()) end
	end
	gear:SetFrameLevel(top + 2)
	gear:SetShown(not compact)

	countText:SetFontObject(m and GameFontHighlightSmall or GameFontNormalSmall)
	if m then
		countText:SetTextColor(unpack(C.muted))
	else
		countText:SetTextColor(1, 0.82, 0)
	end
end

---------------------------------------------------------------------------
-- Layout / refresh (only out of combat: secure attributes are locked in combat)
---------------------------------------------------------------------------
local function ItemName(link)
	return link and link:match("%[(.-)%]") or ""
end

-- Hidden font string for measuring names at their full, unclipped width.
local measure = frame:CreateFontString(nil, "OVERLAY")
measure:Hide()

-- List row width: just wide enough for the longest name, within the mode's limits.
local function ListWidth(M, font)
	measure:SetFontObject(font)
	local widest = 0
	for _, item in ipairs(items) do
		measure:SetText(ItemName(item.link))
		widest = math.max(widest, measure:GetStringWidth())
	end
	local w = math.ceil(M.size + 8 + widest + 6)
	return math.max(M.minListWidth, math.min(M.listWidth, w))
end

local function Layout()
	ApplySkin()
	local m = IsModern()
	local compact = IsCompact()
	local M = compact and COMPACT or NORMAL
	local n = #items
	local list = IsList()
	local cols = list and 1 or M.cols
	local rows = math.max(1, math.ceil(n / cols))
	local nameFont = compact and GameFontNormalSmall or GameFontNormal
	local listW = list and ListWidth(M, nameFont) or M.listWidth
	-- Compact grid: only as many columns as there are items.
	local shownCols = (compact and not list) and math.max(1, math.min(n, M.cols)) or M.cols
	local gridW = list and listW or (shownCols * M.size + (shownCols - 1) * M.spacing)
	local gridH = rows * M.size + (rows - 1) * M.spacing
	if compact then
		if n == 0 then
			-- Just wide enough for "Nothing to open".
			gridW = math.max(gridW, math.ceil(emptyText:GetStringWidth()) + 6)
		end
		frame:SetSize(gridW + M.pad * 2, gridH + M.pad * 2)
	else
		local topOffset = m and TOP_OFFSET.modern or TOP_OFFSET.classic
		frame:SetSize(gridW + M.pad * 2 + 10, gridH + M.pad * 2 + topOffset + BOTTOM_BAR)
	end

	for i, item in ipairs(items) do
		local b = GetButton(i)
		local row = math.floor((i - 1) / cols)
		local col = (i - 1) % cols
		b:SetSize(M.size, M.size)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", inset, "TOPLEFT",
			M.pad + col * (M.size + M.spacing),
			-(M.pad + row * (M.size + M.spacing)))
		b.nameText:SetWidth(listW - M.size - 8)
		b.nameText:SetFontObject(nameFont)
		b.rowHi:SetSize(listW + 4, M.size + 4)
		if list then
			-- Let the whole row be clickable, not just the icon.
			b:SetHitRectInsets(0, -(listW - M.size), 0, 0)
			b.nameText:SetText(ItemName(item.link))
			local color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
			if color then
				b.nameText:SetTextColor(color.r, color.g, color.b)
			else
				b.nameText:SetTextColor(1, 1, 1)
			end
			b.nameText:Show()
		else
			b:SetHitRectInsets(0, 0, 0, 0)
			b.nameText:Hide()
		end
		b.rowHi:Hide()
		b.bag, b.slot, b.ignoreKey = item.bag, item.slot, IgnoreKey(item.id, item.link)
		SetItemButtonDesaturated(b, false)
		b:SetAttribute("item", item.bag .. " " .. item.slot)
		SetItemButtonTexture(b, item.icon)
		SetItemButtonCount(b, item.count)
		SetItemButtonQuality(b, item.quality, item.link)
		-- Compact always uses the flat icons: the game's slot art doesn't fit 24px.
		SkinButton(b, m or compact, item.quality)
		b.isQuest = item.quest
		b.questBang:SetShown(item.quest == true)
		b:Show()
	end
	for i = n + 1, #buttons do
		buttons[i].bag, buttons[i].slot, buttons[i].ignoreKey = nil, nil, nil
		buttons[i]:SetAttribute("item", nil)
		buttons[i]:Hide()
	end

	local ignoredSuffix = ignoredCount > 0 and ("  |cff808080(" .. ignoredCount .. " ignored)|r") or ""
	if n > 0 then
		openNext:SetAttribute("item", items[1].bag .. " " .. items[1].slot)
		openNext:Enable()
		emptyText:Hide()
		countText:SetText((itemTotal == 1 and "1 item" or (itemTotal .. " items")) .. ignoredSuffix)
	else
		openNext:SetAttribute("item", nil)
		openNext:Disable()
		emptyText:Show()
		countText:SetText(ignoredSuffix ~= "" and strtrim(ignoredSuffix) or "")
	end
	OpenNext_Style(openNext, false)
end

function Refresh()
	if InCombatLockdown() then
		pendingRefresh = true
		return
	end
	pendingRefresh = false
	-- Item data trickles in for a few seconds after loading; don't treat that as "new loot".
	local silent = pendingSilent or GetTime() < quietUntil
	pendingSilent = false
	ScanBags()
	Layout()

	if IsAuto() and not silent then
		if itemTotal > lastCount then
			frame:Show()          -- something new to open: pop up
		elseif itemTotal == 0 then
			frame:Hide()          -- all done: tuck away
		end
	end
	lastCount = itemTotal
	if ns.UpdateOptions then ns.UpdateOptions() end
end

-- Rebuild the window after a setting changed, without popping it up.
-- In combat the rebuild waits until combat ends.
local function RequestRefresh()
	RunSkinHooks()
	if InCombatLockdown() then
		pendingRefresh = true
		Print("The window will update when combat ends.")
	else
		pendingSilent = true
		Refresh()
	end
end

---------------------------------------------------------------------------
-- Settings shared with Options.lua
---------------------------------------------------------------------------
local function SetAuto(on)
	db.auto = on and true or false
end

local function SetLayout(layout)
	db.layout = layout == "list" and "list" or "grid"
	RequestRefresh()
end

local function SetCompact(on)
	db.compact = on and true or false
	RequestRefresh()
end

local function SetSkin(skin)
	db.skin = skin == "modern" and "modern" or "classic"
	RequestRefresh()
end

local function Unignore()
	local had = next(ignored) ~= nil
	wipe(ignored)
	RequestRefresh()
	return had
end

local function IgnoredItemCount()
	local n = 0
	for _ in pairs(ignored) do n = n + 1 end
	return n
end

ns.C = C
ns.WHITE = WHITE
ns.FLAT = FLAT
ns.BACKDROP_TEMPLATE = BACKDROP_TEMPLATE
ns.HEADER_H = HEADER_H
ns.PORTRAIT = PORTRAIT
ns.Print = Print
ns.Accent = Accent
ns.SetGradientV = SetGradientV
ns.FlatButton = FlatButton
ns.IsModern = IsModern
ns.IsCompact = IsCompact
ns.IsList = IsList
ns.IsAuto = IsAuto
ns.skinHooks = skinHooks
ns.SetAuto = SetAuto
ns.SetLayout = SetLayout
ns.SetSkin = SetSkin
ns.SetCompact = SetCompact
ns.Unignore = Unignore
ns.IgnoredItemCount = IgnoredItemCount

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")

local function SetEscapeClosable(enabled)
	local name = frame:GetName()
	for i = #UISpecialFrames, 1, -1 do
		if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end
	end
	if enabled then tinsert(UISpecialFrames, name) end
end

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		OpenMeForeverDB = OpenMeForeverDB or {}
		db = OpenMeForeverDB
		if db.pos then
			frame:ClearAllPoints()
			frame:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
		end
		SetEscapeClosable(true)
		RunSkinHooks()
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- Don't pop up on login/zoning for items already sitting in bags; just build the list.
		pendingSilent = true
		quietUntil = GetTime() + 5
		Refresh()
	elseif event == "PLAYER_REGEN_DISABLED" then
		SetEscapeClosable(false)   -- Escape would try to hide a protected frame in combat
	elseif event == "PLAYER_REGEN_ENABLED" then
		SetEscapeClosable(true)
		if pendingRefresh then Refresh() end
	elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
		-- Give the quest log a moment to update before re-checking quest items.
		C_Timer.After(0.3, Refresh)
	else -- BAG_UPDATE_DELAYED
		Refresh()
	end
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_OPENMEFOREVER1 = "/openme"
SlashCmdList.OPENMEFOREVER = function(msg)
	msg = strtrim((msg or ""):lower())
	if msg == "auto" then
		SetAuto(not IsAuto())
		Print("Auto pop-up " .. (IsAuto() and "|cff00ff00on|r" or "|cffff2020off|r") .. ".")
		if ns.UpdateOptions then ns.UpdateOptions() end
		return
	elseif msg == "grid" or msg == "list" or msg == "layout" then
		if msg == "layout" then
			msg = IsList() and "grid" or "list"
		end
		SetLayout(msg)
		Print("Layout set to " .. msg .. ".")
		return
	elseif msg == "skin" or msg == "modern" or msg == "classic" then
		if msg == "skin" then
			msg = IsModern() and "classic" or "modern"
		end
		SetSkin(msg)
		Print("Skin set to " .. msg .. ".")
		return
	elseif msg == "compact" then
		SetCompact(not IsCompact())
		Print("Compact mode " .. (IsCompact() and "|cff00ff00on|r" or "|cffff2020off|r") .. ".")
		return
	elseif msg == "unignore" or msg == "reset" then
		Print(Unignore() and "No longer ignoring any items." or "No items were being ignored.")
		return
	elseif msg == "options" or msg == "config" or msg == "settings" then
		if ns.ToggleOptions then ns.ToggleOptions() end
		return
	elseif msg == "help" then
		Print("/openme - show or hide the window")
		Print("/openme options - open the options window")
		Print("/openme auto - turn the automatic pop-up on or off")
		Print("/openme grid | list - choose how items are shown (/openme layout toggles)")
		Print("/openme compact - turn compact mode (just the items, no frame) on or off")
		Print("/openme modern | classic - choose the window skin (/openme skin toggles)")
		Print("/openme unignore - show items you right-clicked away again")
		return
	end
	if InCombatLockdown() then
		Print("Can't open or close the window during combat.")
		return
	end
	if frame:IsShown() then
		frame:Hide()
	else
		Refresh()
		frame:Show()
	end
end
