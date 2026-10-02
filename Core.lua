local ADDON_NAME, ns = ...
local L = ns.L

-- Init, AceDB, Events, Ticker, Slash-Befehle

local UPDATE_INTERVAL = 0.25     -- SPEC Abschnitt 8
local STATUS_INTERVAL = 1.0      -- Debug-Statuseintrag im Kampf
local POST_COMBAT_STATUS = 5     -- Sekunden nach Kampfende weiter Status loggen

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "?"

local WHITE = { r = 1, g = 1, b = 1 }
local LSM = LibStub("LibSharedMedia-3.0", true)

ns.defaults = {
  profile = {
    mode = "dps",            -- "dps" | "hps"
    dataSource = "auto",     -- "auto" | "current" | "overall"
    showRank = true,
    showName = false,
    showUnit = true,
    nameClassColor = false,
    colors = {
      rank = WHITE,
      name = WHITE,
      value = WHITE,
      unit = WHITE,
    },
    -- Farben nach Platzierung (1.1.0). Standard aus: bestehende Profile sehen keine
    -- Änderung, fehlende Werte kommen über die AceDB-Defaults.
    rankColors = {
      enabled = false,
      first  = { r = 0.1, g = 0.9, b = 0.1 },    -- Platz 1: grün
      second = { r = 1.0, g = 0.82, b = 0.0 },   -- Platz 2: gelb
      rest   = { r = 0.9, g = 0.1, b = 0.1 },    -- ab Platz 3: rot
    },
    font = {
      name = (LSM and LSM:GetDefault("font")) or "Friz Quadrata TT",   -- LibSharedMedia-Schlüssel
      size = 14,
      outline = "OUTLINE",   -- "" | "OUTLINE" | "THICKOUTLINE"
      shadow = true,
    },
    background = {
      show = false,
      color = { r = 0, g = 0, b = 0, a = 0.5 },
    },
    border = {
      show = false,
      color = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
    },
    scale = 1,
    alpha = 1,
    position = { point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },   -- bis 0.3.x; Startwert für Layouts
    layouts = {},            -- Position pro Bearbeitungsmodus-Layout (EditMode.lua)
    locked = false,          -- im Bearbeitungsmodus nicht verschiebbar
    visibility = "always",   -- "always" | "instance" | "group" | "combat"
    hideInVehicle = false,
    trend = {
      style = "arrow",       -- "arrow" | "boxes" | "bars" | "off"
      boxLayout = "side",    -- Kästchen: "side" (nebeneinander) | "stack" (übereinander)
      window = 3,            -- Sekunden, 0,5 bis 30
      tolerance = 0.01,      -- Anteil (1 %), 0,001 bis 0,2; nur Pfeil und Kästchen
      size = 0,              -- 0 = an die Schriftgröße gekoppelt
      colors = {
        up = { r = 0.1, g = 0.9, b = 0.1 },
        down = { r = 0.9, g = 0.1, b = 0.1 },
      },
    },
  },
  global = {
    debug = false,
  },
}

-- Skalierung auf 0,01 runden (Slider liefern Werte wie 1.7000000476837)
function ns.RoundScale(value)
  return math.floor(value * 100 + 0.5) / 100
end

local function Print(msg)
  print("|cff33ff99OwnDPS|r: " .. msg)
end
ns.Print = Print

---------------------------------------------------------------------------
-- Aktualisierung
---------------------------------------------------------------------------

local lastStatus = 0
local postCombatUntil = 0

local function logStatus(s)
  local now = GetTime()
  if not (s.inCombat or now < postCombatUntil) then return end
  if now - lastStatus < STATUS_INTERVAL then return end
  lastStatus = now

  local last = ns.Display.last
  local out = {
    mode = ns.db.profile.mode,
    dataSource = ns.db.profile.dataSource,
    sessionType = s.sessionType,
    meterType = s.meterType,
    apiOk = s.apiOk,
    rank = s.rank,
    count = s.count,
    hasValue = s.hasValue,
    valueSecret = issecretvalue and issecretvalue(s.value) or false,
    value = s.value,                   -- wird bei Secret zu "<SECRET>"
    err = s.err,
    abbrevOk = last.abbrevOk,
    formattedSecret = issecretvalue and issecretvalue(last.formatted) or false,
    formatted = last.formatted,        -- wird bei Secret zu "<SECRET>"
    setTextOk = last.setTextOk,
    shown = last.shown,
    rankColors = ns.db.profile.rankColors.enabled,
    trendStyle = ns.db.profile.trend.style,
    trendWindow = ns.db.profile.trend.window,
    trendTolerance = ns.db.profile.trend.tolerance,
    trendShown = last.trendShown,
    trendHasPrev = last.trendHasPrev,
    trendSetOk = last.trendSetOk,
    historyLen = #ns.Data.history,
    visibilityMacro = ns.Display.visibilityMacro,
    layout = ns.EditMode:GetLayoutName(),
  }
  local DM = C_DamageMeter
  if DM and DM.GetSessionDurationSeconds and s.sessionType ~= nil then
    local ok, dur = pcall(DM.GetSessionDurationSeconds, s.sessionType)
    out.durationOk = ok
    if ok then out.duration = dur end
  end
  ns.Display:DebugInfo(out)
  ns.Debug:Add("status", out)
end

function ns:Update()
  local s = ns.Data:Read()
  ns.Data:PushHistory(s)
  local prev, hasPrev = ns.Data:GetPrevious(ns.db.profile.trend.window)
  ns.Display:Render(s)
  ns.Display:RenderTrend(s, prev, hasPrev)
  if s.err then ns.Debug:Error("Data:Read", s.err) end
  if ns.Debug:IsEnabled() then logStatus(s) end
end

local function safeUpdate()
  local ok, err = pcall(ns.Update, ns)
  if not ok then ns.Debug:Error("Update", err) end
end
ns.SafeUpdate = safeUpdate

-- Einstellungen sofort anwenden, ohne /reload
function ns:Refresh()
  ns.Display:ApplySettings()
  ns.Display:UpdateVisibility()
  safeUpdate()
end

-- Offenes Einstellungsfenster aktualisieren, wenn sich etwas außerhalb davon ändert
function ns:NotifyOptions()
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then registry:NotifyChange(ADDON_NAME) end
end

function ns:OnProfileChanged()
  ns.Data:ClearHistory()
  ns:Refresh()
  ns.EditMode:Refresh()
end
ns.OnProfileCopied = ns.OnProfileChanged
ns.OnProfileReset = ns.OnProfileChanged

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
  if name ~= ADDON_NAME then return end
  events:UnregisterEvent("ADDON_LOADED")

  -- Ohne dritten Parameter legt AceDB ein Profil pro Charakter an ("Name - Realm")
  ns.db = LibStub("AceDB-3.0"):New("OwnDPSDB", ns.defaults)
  ns.db.RegisterCallback(ns, "OnProfileChanged", "OnProfileChanged")
  ns.db.RegisterCallback(ns, "OnProfileCopied", "OnProfileCopied")
  ns.db.RegisterCallback(ns, "OnProfileReset", "OnProfileReset")
  ns.Debug:Init()
  ns.Options:Init()
end

function handlers.PLAYER_LOGIN()
  ns.Display:Create()
  ns.EditMode:Init()
  -- Schriften, die andere Addons später registrieren, nachladen
  if LSM then
    LSM.RegisterCallback(ns, "LibSharedMedia_Registered", function(_, mediatype, key)
      if mediatype == "font" and key == ns.db.profile.font.name then ns:Refresh() end
    end)
  end
  ns.Debug:LogMeta()
  C_Timer.NewTicker(UPDATE_INTERVAL, safeUpdate)
  safeUpdate()
  Print(L["LOADED"]:format(ns.VERSION))
end

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
  ns.Debug:LogInstance({ initial = isInitialLogin, reload = isReloadingUi })
  ns.Display:UpdateVisibility()   -- "Nur in Instanzen" hängt an IsInInstance()
end

function handlers.ZONE_CHANGED_NEW_AREA()
  ns.Display:UpdateVisibility()
end

function handlers.PLAYER_REGEN_DISABLED()
  ns.Data:ClearHistory()
  ns.Debug:Add("combatStart", { groupSize = GetNumGroupMembers() })
  lastStatus = 0
  safeUpdate()
end

function handlers.PLAYER_REGEN_ENABLED()
  ns.Debug:Add("combatEnd")
  postCombatUntil = GetTime() + POST_COMBAT_STATUS
  ns.Display:UpdateVisibility()   -- im Kampf zurückgestellte Änderung nachholen
  safeUpdate()
end

function handlers.DAMAGE_METER_CURRENT_SESSION_UPDATED()
  safeUpdate()
end

function handlers.DAMAGE_METER_RESET()
  ns.Data:ClearHistory()
  ns.Debug:Add("damageMeterReset")
  safeUpdate()
end

events:SetScript("OnEvent", function(_, event, ...)
  local handler = handlers[event]
  if handler then
    local ok, err = pcall(handler, ...)
    if not ok then
      if ns.db then ns.Debug:Error(event, err) end
      if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        geterrorhandler()(err)
      end
    end
  end
end)

for event in pairs(handlers) do
  local ok = pcall(events.RegisterEvent, events, event)
  if not ok then Print("Event unknown: " .. event) end
end

---------------------------------------------------------------------------
-- Slash-Befehle. /owndps ohne Argument öffnet das Einstellungsmenü.
---------------------------------------------------------------------------

local SOURCE_NAMES = { auto = "SOURCE_AUTO", current = "SOURCE_CURRENT", overall = "SOURCE_OVERALL" }
local TOGGLES = { rank = { "showRank", "ELEMENT_RANK" }, name = { "showName", "ELEMENT_NAME" }, unit = { "showUnit", "ELEMENT_UNIT" } }
local STYLE_NAMES = { arrow = "STYLE_ARROW", boxes = "STYLE_BOXES", bars = "STYLE_BARS", off = "STYLE_OFF" }
local BOX_LAYOUT_NAMES = { side = "BOXLAYOUT_SIDE", stack = "BOXLAYOUT_STACK" }
ns.SOURCE_NAMES, ns.STYLE_NAMES, ns.BOX_LAYOUT_NAMES = SOURCE_NAMES, STYLE_NAMES, BOX_LAYOUT_NAMES

-- Zahl aus der Eingabe, akzeptiert auch Komma ("0,5")
local function parseNumber(arg)
  local s = (arg or ""):gsub(",", ".")
  return tonumber(s)
end

local function modeName(mode)
  return mode == "hps" and L["UNIT_HPS"] or L["UNIT_DPS"]
end

local function printHelp()
  Print(L["HELP_HEADER"])
  for _, key in ipairs({ "HELP_OPEN", "HELP_MODE", "HELP_SOURCE", "HELP_TOGGLE", "HELP_TREND", "HELP_BOXLAYOUT",
      "HELP_WINDOW", "HELP_TOLERANCE", "HELP_TRENDSIZE", "HELP_RESET", "HELP_DEBUG", "HELP_STATUS" }) do
    print("  " .. L[key])
  end
end

-- Nach jeder Änderung: Anzeige neu aufbauen und ein offenes Menü aktualisieren
local function changed(setting)
  ns.Debug:Add("setting", setting)
  ns:Refresh()
  ns:NotifyOptions()
end

local commands = {}

function commands.help()
  printHelp()
end

function commands.mode(arg)
  if arg ~= "dps" and arg ~= "hps" then printHelp(); return end
  ns.db.profile.mode = arg
  ns.Data:ClearHistory()
  changed({ mode = arg })
  Print(L["MODE_SET"]:format(modeName(arg)))
end

function commands.source(arg)
  if not SOURCE_NAMES[arg] then printHelp(); return end
  ns.db.profile.dataSource = arg
  ns.Data:ClearHistory()
  changed({ dataSource = arg })
  Print(L["SOURCE_SET"]:format(L[SOURCE_NAMES[arg]]))
end

function commands.toggle(arg)
  local t = TOGGLES[arg]
  if not t then printHelp(); return end
  local p = ns.db.profile
  p[t[1]] = not p[t[1]]
  changed({ [t[1]] = p[t[1]] })
  Print((p[t[1]] and L["ELEMENT_SHOWN"] or L["ELEMENT_HIDDEN"]):format(L[t[2]]))
end

function commands.trend(arg)
  if not STYLE_NAMES[arg] then printHelp(); return end
  ns.db.profile.trend.style = arg
  changed({ trendStyle = arg })
  Print(L["TREND_STYLE_SET"]:format(L[STYLE_NAMES[arg]]))
end

function commands.boxlayout(arg)
  if not BOX_LAYOUT_NAMES[arg] then printHelp(); return end
  ns.db.profile.trend.boxLayout = arg
  changed({ boxLayout = arg })
  Print(L["BOXLAYOUT_SET"]:format(L[BOX_LAYOUT_NAMES[arg]]))
end

function commands.window(arg)
  local n = parseNumber(arg)
  if not n or n < 0.5 or n > 30 then
    Print(L["RANGE"]:format("0.5", "30"))
    return
  end
  ns.db.profile.trend.window = n
  ns.Data:ClearHistory()
  changed({ trendWindow = n })
  Print(L["WINDOW_SET"]:format(n))
end

-- Eingabe in Prozent, gespeichert als Anteil
function commands.tolerance(arg)
  local n = parseNumber(arg)
  if not n or n < 0.1 or n > 20 then
    Print(L["RANGE"]:format("0.1", "20"))
    return
  end
  ns.db.profile.trend.tolerance = n / 100
  changed({ trendTolerance = n / 100 })
  Print(L["TOLERANCE_SET"]:format(n))
end

-- 0 = an die Schriftgröße gekoppelt
function commands.trendsize(arg)
  local n = parseNumber(arg)
  if not n or (n ~= 0 and (n < 6 or n > 64)) then
    Print(L["RANGE"]:format("6", "64") .. " " .. L["TRENDSIZE_ZERO"])
    return
  end
  n = math.floor(n + 0.5)
  ns.db.profile.trend.size = n
  changed({ trendSize = n })
  if n == 0 then
    Print(L["TRENDSIZE_FONT"])
  else
    Print(L["TRENDSIZE_SET"]:format(n))
  end
end

-- Position im aktiven Bearbeitungsmodus-Layout zurücksetzen
function commands.reset()
  ns.EditMode:ResetPosition()
  ns:NotifyOptions()
  Print(L["POSITION_RESET"])
end

function commands.status()
  local p = ns.db.profile
  Print(L["STATUS"]:format(modeName(p.mode), L[SOURCE_NAMES[p.dataSource] or "SOURCE_AUTO"], ns.db:GetCurrentProfile()))
  local t = p.trend
  Print(L["STATUS_TREND"]:format(L[STYLE_NAMES[t.style] or "STYLE_ARROW"], t.window, t.tolerance * 100,
    t.size > 0 and tostring(t.size) or L["TRENDSIZE_FONT_SHORT"]))
  Print(L["DEBUG_STATUS"]:format(ns.Debug:IsEnabled() and L["ON"] or L["OFF"], ns.Debug:Count()))
end

function commands.debug(arg)
  if arg == "on" then
    ns.Debug:SetEnabled(true)
    ns.Debug:LogInstance({ reason = "debugOn" })
    ns:NotifyOptions()
    Print(L["DEBUG_ON"])
  elseif arg == "off" then
    ns.Debug:Add("debugOff")
    ns.Debug:SetEnabled(false)
    ns:NotifyOptions()
    Print(L["DEBUG_OFF"])
  elseif arg == "clear" then
    ns.Debug:Clear()
    Print(L["DEBUG_CLEARED"])
  else
    Print(L["DEBUG_STATUS"]:format(ns.Debug:IsEnabled() and L["ON"] or L["OFF"], ns.Debug:Count()))
  end
end

SLASH_OWNDPS1 = "/owndps"
SlashCmdList.OWNDPS = function(msg)
  if not ns.db then return end
  local cmd, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "" then
    -- Menü öffnen; ohne Menü (Bibliothek fehlt) die Hilfe zeigen
    if not ns.Options:Open() then printHelp() end
  elseif commands[cmd] then
    commands[cmd](arg)
  else
    Print(L["UNKNOWN_COMMAND"])
  end
end
