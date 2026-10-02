local ADDON_NAME, ns = ...
local L = ns.L

-- Anzeige: eine Textzeile "[Platz] [Name] [Wert] [Einheit]".
-- Der Wert kann geheim sein. Er geht nur als Argument an SetFormattedText,
-- der Formatstring selbst besteht ausschließlich aus nicht geheimen Teilen.

local Display = {}
ns.Display = Display

local issecret = issecretvalue or function() return false end
local LSM = LibStub("LibSharedMedia-3.0", true)

-- 123.4k / 12.3M / 1.2B, im Spiel getestet (SPEC Abschnitt 2), auch mit Secret Values
local ABBREV_OPTS = {
  breakpointData = {
    { breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e3, abbreviation = "k", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
    -- Unter 1000 ganze Zahl. Ohne diese Regel kam der Rohwert, z. B. "240.07407407407" (Test 0.1.0-alpha.1)
    { breakpoint = 1, abbreviation = "", significandDivisor = 1, fractionDivisor = 1, abbreviationIsGlobal = false },
  },
}

-- Nur für den Selbsttest im Debugmodus: dieselben Regeln, die letzte mit breakpoint = 0,
-- um zu sehen, ob damit auch Werte unter 1 als "0" erscheinen.
local ABBREV_OPTS_BP0 = { breakpointData = {} }
for i, rule in ipairs(ABBREV_OPTS.breakpointData) do
  local copy = {}
  for k, v in pairs(rule) do copy[k] = v end
  ABBREV_OPTS_BP0.breakpointData[i] = copy
end
ABBREV_OPTS_BP0.breakpointData[#ABBREV_OPTS_BP0.breakpointData].breakpoint = 0

local FORMAT_SAMPLES = { 0, 0.4, 0.999, 1, 7.5, 240.07407407407, 999.9, 1234.5, 12345.6, 1234567 }

-- Formatiert feste, nicht geheime Beispielwerte und liefert die Ergebnisse fürs Debug-Log.
function Display:FormatSelfTest()
  local out = {}
  for _, v in ipairs(FORMAT_SAMPLES) do
    local ok, r = pcall(AbbreviateNumbers, v, ABBREV_OPTS)
    out["bp1 " .. v] = ok and r or ("error: " .. tostring(r))
    local ok0, r0 = pcall(AbbreviateNumbers, v, ABBREV_OPTS_BP0)
    out["bp0 " .. v] = ok0 and r0 or ("error: " .. tostring(r0))
  end
  return out
end

-- Beispielwert im Bearbeitungsmodus (SPEC: "1. 123.4k DPS")
local SAMPLE_VALUE = "123.4k"
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\media\\"
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local frame, content, text
local bgTex, borderTop, borderBottom, borderLeft, borderRight
local bgRightAnchor      -- Region, an deren rechtem Rand Hintergrund und Rahmen enden
local trendHolder
local trendStyles = {}   -- arrow / boxes / bars -> { root, up, down, clips = {...} }

-- Ergebnis des letzten Zeichnens, für das Debug-Log
Display.last = {}

local function colorCode(c)
  return string.format("|cff%02x%02x%02x",
    math.floor((c.r or 1) * 255 + 0.5),
    math.floor((c.g or 1) * 255 + 0.5),
    math.floor((c.b or 1) * 255 + 0.5))
end

-- Baut den Formatstring aus nicht geheimen Teilen.
-- Rückgabe: fmt, withRank (true, wenn das erste Argument der Platz ist)
-- Farbe nach Platzierung (Option rankColors): Platz 1, Platz 2, ab Platz 3.
-- Der Platz ist im Kampf lesbar (SPEC Abschnitt 10) und stammt aus dem Schleifenindex
-- in Data.lua. Trotzdem defensiv: ist er geheim, gelten die normalen Farben.
-- Rückgabe: Farbtabelle oder nil (= normale Farben)
local function rankColor(p, rank, rankSecret)
  local rc = p.rankColors
  if not (rc and rc.enabled) then return nil end
  if rankSecret then
    ns.Debug:Error("rankColors", "rank is secret, using normal colors")
    return nil
  end
  if type(rank) ~= "number" then return nil end
  if rank == 1 then return rc.first end
  if rank == 2 then return rc.second end
  return rc.rest
end

local function buildFormat(p, rank)
  local parts = {}
  local rankSecret = issecret(rank)
  -- nie einen möglicherweise geheimen Wert vergleichen
  local withRank = p.showRank and (rankSecret or rank ~= nil)
  -- Platzzahl und Wert in der Platzfarbe; Name und Einheit behalten ihre Farben
  local placeColor = rankColor(p, rank, rankSecret)
  if withRank then
    parts[#parts + 1] = colorCode(placeColor or p.colors.rank) .. "%d.|r"
  end
  if p.showName then
    local name = UnitName("player") or ""
    local color = p.colors.name
    if p.nameClassColor then
      local _, class = UnitClass("player")
      local ok, classColor = pcall(C_ClassColor.GetClassColor, class)
      if ok and classColor then color = classColor end
    end
    parts[#parts + 1] = colorCode(color) .. name:gsub("%%", "%%%%") .. "|r"
  end
  parts[#parts + 1] = colorCode(placeColor or p.colors.value) .. "%s|r"
  if p.showUnit then
    local unit = (p.mode == "hps") and L["UNIT_HPS"] or L["UNIT_DPS"]
    parts[#parts + 1] = colorCode(p.colors.unit) .. unit:gsub("%%", "%%%%") .. "|r"
  end
  return table.concat(parts, " "), withRank
end

function Display:GetFrame()
  return frame
end

-- Position des aktiven Bearbeitungsmodus-Layouts (EditMode.lua), sonst Profil-Position
function Display:ApplyPosition()
  if not frame then return end
  local pos = ns.EditMode:GetPosition()
  frame:ClearAllPoints()
  frame:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

local function fontPath(name)
  if LSM and name then
    local ok, path = pcall(LSM.Fetch, LSM, "font", name)
    if ok and path then return path end
  end
  return STANDARD_TEXT_FONT
end

-- Schriftart über LibSharedMedia. SetFont liefert laut API-Doku "success";
-- bei Fehlschlag Standardschrift, damit der Text nie unsichtbar wird.
local function applyFont(f)
  local flags = (f.outline ~= "" and f.outline) or nil
  local ok, success = pcall(text.SetFont, text, fontPath(f.name), f.size, flags)
  if not (ok and success) then
    ns.Debug:Error("SetFont", ok and ("failed: " .. tostring(f.name)) or success)
    text:SetFont(STANDARD_TEXT_FONT, f.size, flags)
  end
end

-- Hintergrund und Rahmen: einfache Texturen am Hauptframe, nur über Anker
-- positioniert. Kein BackdropTemplate, denn dessen SetupTextureCoordinates rechnet
-- mit GetWidth(), und die Breite des Texts ist im Kampf geheim.
local BOX_PAD = 4

local function anchorBackground(rightRegion)
  if bgRightAnchor == rightRegion then return end
  bgRightAnchor = rightRegion
  bgTex:ClearAllPoints()
  bgTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  bgTex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bgTex:SetPoint("RIGHT", rightRegion, "RIGHT", BOX_PAD, 0)
end

local function applyBackground(p)
  local bg, bc = p.background.color, p.border.color
  bgTex:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
  bgTex:SetShown(p.background.show)
  for _, line in ipairs({ borderTop, borderBottom, borderLeft, borderRight }) do
    line:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
    line:SetShown(p.border.show)
  end
end

function Display:ApplySettings()
  if not frame then return end   -- vor PLAYER_LOGIN gibt es noch keinen Frame
  local p = ns.db.profile
  local f = p.font
  applyFont(f)
  if f.shadow then
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
  else
    text:SetShadowOffset(0, 0)
  end
  frame:SetHeight(math.max(f.size, self:GetTrendSize()) + 8)
  frame:SetScale(p.scale)
  frame:SetAlpha(p.alpha)
  applyBackground(p)
  self:ApplyPosition()
  self:ApplyTrendSettings()
end

function Display:Create()
  if frame then return end

  -- Feste Größe, verankert an UIParent: LibEditMode rechnet beim Verschieben mit
  -- GetLeft/GetRight dieses Frames, deshalb darf er nicht an der (im Kampf geheimen)
  -- Textbreite hängen.
  frame = CreateFrame("Frame", "OwnDPSFrame", UIParent)
  frame:SetSize(160, 22)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(false)

  -- Alles Sichtbare liegt in "content". Ohne Wert wird nur content ausgeblendet;
  -- der Hauptframe gehört weiter dem State Driver (Sichtbarkeitsregeln). Beide
  -- Frames sind nicht geschützt, Show/Hide von content ist daher auch im Kampf erlaubt.
  content = CreateFrame("Frame", nil, frame)
  content:SetAllPoints(frame)
  content:Hide()

  text = content:CreateFontString(nil, "OVERLAY")
  text:SetPoint("LEFT", frame, "LEFT", 4, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)

  bgTex = content:CreateTexture(nil, "BACKGROUND", nil, 1)
  local function line(a1, a2, horizontal)
    local t = content:CreateTexture(nil, "BORDER")
    t:SetPoint(a1, bgTex, a1, 0, 0)
    t:SetPoint(a2, bgTex, a2, 0, 0)
    if horizontal then t:SetHeight(1) else t:SetWidth(1) end
    return t
  end
  borderTop = line("TOPLEFT", "TOPRIGHT", true)
  borderBottom = line("BOTTOMLEFT", "BOTTOMRIGHT", true)
  borderLeft = line("TOPLEFT", "BOTTOMLEFT", false)
  borderRight = line("TOPRIGHT", "BOTTOMRIGHT", false)
  anchorBackground(text)

  self:CreateTrend()
  self:ApplySettings()
  self:UpdateVisibility()
end

---------------------------------------------------------------------------
-- Sichtbarkeit (SPEC Abschnitt 5) über den State Driver "visibility".
-- Haustierkampf immer aus (getestet), Fahrzeug optional. Für Instanzen gibt es
-- keine Macro-Bedingung (warcraft.wiki.gg, Macro conditionals), daher wird
-- IsInInstance() bei Zonenwechseln ausgewertet und der Treiber neu gesetzt.
-- RegisterStateDriver setzt Attribute am geschützten SecureStateDriverManager und
-- wird deshalb nie im Kampf aufgerufen, sondern bis Kampfende zurückgestellt.
---------------------------------------------------------------------------

local function inInstance()
  local ok, isIn = pcall(IsInInstance)
  return ok and isIn and true or false
end

function Display:BuildVisibilityMacro()
  if self.editMode then return "show" end   -- im Bearbeitungsmodus immer sichtbar
  local p = ns.db.profile
  local parts = { "[petbattle] hide" }
  if p.hideInVehicle then parts[#parts + 1] = "[vehicleui] hide" end
  local mode = p.visibility
  if mode == "combat" then
    parts[#parts + 1] = "[combat] show"
    parts[#parts + 1] = "hide"
  elseif mode == "group" then
    parts[#parts + 1] = "[group] show"
    parts[#parts + 1] = "hide"
  elseif mode == "instance" then
    parts[#parts + 1] = inInstance() and "show" or "hide"
  else
    parts[#parts + 1] = "show"
  end
  return table.concat(parts, "; ")
end

-- Rückgabe true, wenn der Treiber aktuell ist; false, wenn bis Kampfende verschoben
function Display:UpdateVisibility()
  if not frame then return false end
  local macro = self:BuildVisibilityMacro()
  if macro == self.visibilityMacro then
    self.visibilityPending = false
    return true
  end
  if InCombatLockdown() then
    self.visibilityPending = true
    return false
  end
  local ok, err = pcall(RegisterStateDriver, frame, "visibility", macro)
  if ok then
    self.visibilityMacro = macro
    self.visibilityPending = false
    ns.Debug:Add("visibility", { macro = macro })
  else
    ns.Debug:Error("RegisterStateDriver", err)
  end
  return ok
end

function Display:SetEditMode(on)
  self.editMode = on and true or false
  self:UpdateVisibility()
  if ns.SafeUpdate then ns.SafeUpdate() end   -- Beispiel sofort zeigen bzw. entfernen
end

-- Ohne Wert (oder bei einem Fehler) wird alles ausgeblendet: Text, Trend,
-- Hintergrund und Rahmen. Es gibt kein Platzhalterzeichen mehr.
local function hideContent(last)
  content:Hide()
  last.shown = "hidden"
end

-- Bearbeitungsmodus: Beispieltext "1. 123.4k DPS" (bzw. HPS, mit Name, falls aktiv)
local function renderSample(last)
  local p = ns.db.profile
  local fmt, withRank = buildFormat(p, 1)
  if withRank then
    text:SetFormattedText(fmt, 1, SAMPLE_VALUE)
  else
    text:SetFormattedText(fmt, SAMPLE_VALUE)
  end
  content:Show()
  last.shown = "sample"
end

-- s: Ergebnis von Data:Read()
function Display:Render(s)
  if not frame then return end
  local last = self.last
  last.abbrevOk = nil
  last.formatted = nil
  last.setTextOk = nil

  if self.editMode then
    renderSample(last)
    return
  end

  if not s.hasValue then
    hideContent(last)
    return
  end

  local okA, formatted = pcall(AbbreviateNumbers, s.value, ABBREV_OPTS)
  last.abbrevOk = okA
  if not okA then
    ns.Debug:Error("AbbreviateNumbers", formatted)
    hideContent(last)
    return
  end
  last.formatted = formatted   -- evtl. geheim, das Log schreibt dann "<SECRET>"

  local p = ns.db.profile
  local fmt, withRank = buildFormat(p, s.rank)
  local okF, err
  if withRank then
    okF, err = pcall(text.SetFormattedText, text, fmt, s.rank, formatted)
  else
    okF, err = pcall(text.SetFormattedText, text, fmt, formatted)
  end
  last.setTextOk = okF
  if okF then
    content:Show()
    last.shown = "value"
  else
    ns.Debug:Error("SetFormattedText", err)
    hideContent(last)
  end
end

---------------------------------------------------------------------------
-- Trend-Indikator (SPEC Abschnitt 4)
-- Hoch:   SetMinMaxValues(0, alt),      SetValue(aktuell) -> voll, wenn gestiegen
-- Runter: SetMinMaxValues(0, aktuell),  SetValue(alt)     -> voll, wenn gesunken
-- Den Vergleich macht WoW beim Zeichnen, Lua sieht die Werte nie.
---------------------------------------------------------------------------

function Display:GetTrendSize()
  local t = ns.db.profile.trend
  if t.size and t.size > 0 then return t.size end
  return ns.db.profile.font.size
end

local function setupBar(bar)
  bar:SetOrientation("VERTICAL")
  bar:SetStatusBarTexture(BAR_TEXTURE)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
end

-- Abschneide-Trick: ein sehr langer vertikaler Balken (Höhe = Größe / Toleranz) in
-- einem kleinen Fenster mit SetClipsChildren. Sichtbar ist nur das oberste Stück,
-- es ist nur gefüllt, wenn Wert >= (1 - Toleranz) * Maximum. Technik aus
-- docs/reference/OwnDPS_Test.lua (makeClipIndicator).
local function makeClip(parent, maskFile, withBackground)
  local clip = CreateFrame("Frame", nil, parent)
  clip:SetClipsChildren(true)
  if withBackground then
    local bg = clip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.2, 0.2, 0.4)
  end
  local bar = CreateFrame("StatusBar", nil, clip)
  bar:SetPoint("TOP", clip, "TOP", 0, 0)
  setupBar(bar)
  if maskFile then
    local ok, err = pcall(function()
      local mask = bar:CreateMaskTexture()
      mask:SetTexture(MEDIA .. maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(clip)
      bar:GetStatusBarTexture():AddMaskTexture(mask)
    end)
    if not ok then ns.Debug:Error("mask " .. maskFile, err) end
  end
  return clip, bar
end

-- Normaler vertikaler Balken für den Stil "Balken"
local function makeBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  setupBar(bar)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
  return bar
end

function Display:CreateTrend()
  trendHolder = CreateFrame("Frame", nil, content)
  trendHolder:SetPoint("LEFT", text, "RIGHT", 4, 0)
  trendHolder:Hide()

  -- Pfeil: beide Pfeile an derselben Stelle
  local arrow = { root = CreateFrame("Frame", nil, trendHolder) }
  arrow.root:SetAllPoints()
  arrow.upClip, arrow.up = makeClip(arrow.root, "arrow_up", false)
  arrow.downClip, arrow.down = makeClip(arrow.root, "arrow_down", false)
  arrow.upClip:SetPoint("CENTER", arrow.root, "CENTER", 0, 0)
  arrow.downClip:SetPoint("CENTER", arrow.root, "CENTER", 0, 0)
  trendStyles.arrow = arrow

  -- Kästchen: hoch und runter, bei "stabil" beide an. Position setzt ApplyTrendSettings
  -- je nach Anordnung (nebeneinander oder übereinander).
  local boxes = { root = CreateFrame("Frame", nil, trendHolder) }
  boxes.root:SetAllPoints()
  boxes.upClip, boxes.up = makeClip(boxes.root, nil, true)
  boxes.downClip, boxes.down = makeClip(boxes.root, nil, true)
  trendStyles.boxes = boxes

  -- Balken: zwei normale Balken, der volle zeigt die Richtung, der andere die Stärke
  local bars = { root = CreateFrame("Frame", nil, trendHolder) }
  bars.root:SetAllPoints()
  bars.up = makeBar(bars.root)
  bars.down = makeBar(bars.root)
  bars.up:SetPoint("LEFT", bars.root, "LEFT", 0, 0)
  bars.down:SetPoint("RIGHT", bars.root, "RIGHT", 0, 0)
  trendStyles.bars = bars
end

function Display:ApplyTrendSettings()
  if not trendHolder then return end
  local t = ns.db.profile.trend
  local size = self:GetTrendSize()
  local tolerance = t.tolerance

  local arrow = trendStyles.arrow
  arrow.upClip:SetSize(size, size)
  arrow.downClip:SetSize(size, size)
  arrow.up:SetSize(size, size / tolerance)
  arrow.down:SetSize(size, size / tolerance)

  -- Kästchen in voller Indikatorgröße
  local boxes = trendStyles.boxes
  boxes.upClip:SetSize(size, size)
  boxes.downClip:SetSize(size, size)
  boxes.up:SetSize(size, size / tolerance)
  boxes.down:SetSize(size, size / tolerance)
  boxes.upClip:ClearAllPoints()
  boxes.downClip:ClearAllPoints()
  local boxesWidth
  if t.boxLayout == "stack" then
    -- deckungsgleich wie beim Pfeil; bei "stabil" ist nur die obere Farbe sichtbar
    boxes.upClip:SetPoint("CENTER", boxes.root, "CENTER", 0, 0)
    boxes.downClip:SetPoint("CENTER", boxes.root, "CENTER", 0, 0)
    boxesWidth = size
  else
    -- nebeneinander: links hoch, rechts runter, 2 px Abstand
    boxes.upClip:SetPoint("LEFT", boxes.root, "LEFT", 0, 0)
    boxes.downClip:SetPoint("LEFT", boxes.upClip, "RIGHT", 2, 0)
    boxesWidth = size * 2 + 2
  end

  local barWidth = math.max(3, math.floor(size * 0.35 + 0.5))
  local bars = trendStyles.bars
  bars.up:SetSize(barWidth, size)
  bars.down:SetSize(barWidth, size)

  local widths = { arrow = size, boxes = boxesWidth, bars = barWidth * 2 + 2 }
  trendHolder:SetSize(widths[t.style] or 1, size)

  local up, down = t.colors.up, t.colors.down
  for style, st in pairs(trendStyles) do
    st.up:SetStatusBarColor(up.r, up.g, up.b, 1)
    st.down:SetStatusBarColor(down.r, down.g, down.b, 1)
    st.root:SetShown(style == t.style)
  end
end

local function clearTrend(st)
  st.up:SetMinMaxValues(0, 1)
  st.up:SetValue(0)
  st.down:SetMinMaxValues(0, 1)
  st.down:SetValue(0)
end

-- s: Ergebnis von Data:Read(); prev: Wert von vor dem Zeitfenster (evtl. geheim)
-- Muster im Bearbeitungsmodus: Zustand "hoch" (Balken: runter halb gefüllt als Stärke)
local function sampleTrend(st, style)
  st.up:SetMinMaxValues(0, 1)
  st.up:SetValue(1)
  st.down:SetMinMaxValues(0, 1)
  st.down:SetValue(style == "bars" and 0.5 or 0)
end

function Display:RenderTrend(s, prev, hasPrev)
  if not trendHolder then return end
  local last = self.last
  local style = ns.db.profile.trend.style
  local st = trendStyles[style]   -- nil beim Stil "Aus"

  if self.editMode then
    local visible = st ~= nil
    trendHolder:SetShown(visible)
    anchorBackground(visible and trendHolder or text)
    last.trendShown = visible
    if visible then sampleTrend(st, style) end
    return
  end

  local visible = st ~= nil and s.inCombat
  trendHolder:SetShown(visible)
  anchorBackground(visible and trendHolder or text)
  last.trendShown = visible
  last.trendHasPrev = hasPrev
  last.trendSetOk = nil
  if not visible then return end

  if not (hasPrev and s.hasValue) then
    clearTrend(st)   -- Zeitfenster noch ohne Daten: Indikator leer
    return
  end

  local ok1, e1 = pcall(st.up.SetMinMaxValues, st.up, 0, prev)
  local ok2, e2 = pcall(st.up.SetValue, st.up, s.value)
  local ok3, e3 = pcall(st.down.SetMinMaxValues, st.down, 0, s.value)
  local ok4, e4 = pcall(st.down.SetValue, st.down, prev)
  last.trendSetOk = ok1 and ok2 and ok3 and ok4
  if not last.trendSetOk then
    ns.Debug:Error("trend", e1 or e2 or e3 or e4)
    clearTrend(st)
  end
end

-- Für den Debugmodus. Getestet (0.1.0-alpha.1): GetStringWidth ist im Kampf geheim,
-- Hintergrund und Rahmen deshalb per SetPoint am FontString verankern.
function Display:DebugInfo(out)
  if not text then return end
  local ok, w = pcall(text.GetStringWidth, text)
  out.textWidthOk = ok
  if ok then
    out.textWidthSecret = issecret(w)
    out.textWidth = w
  end
  out.frameShown = frame:IsShown()
  out.contentShown = content:IsShown()
  -- Der Indikator hängt rechts am Text. Ist seine Position dann lesbar?
  if trendHolder and trendHolder:IsShown() then
    local okL, left = pcall(trendHolder.GetLeft, trendHolder)
    out.trendLeftOk = okL
    if okL then out.trendLeftSecret = issecret(left) end
  end
end
