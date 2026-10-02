local ADDON_NAME, ns = ...
local L = ns.L

-- Einstellungsmenü (SPEC Abschnitt 5) mit AceConfig-3.0 / AceConfigDialog-3.0,
-- eingetragen unter Einstellungen > AddOns. Profile über AceDBOptions-3.0.
-- Jede Änderung wird sofort angewendet (ns:Refresh), ohne /reload.

local Options = {}
ns.Options = Options

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local AceGUI = LibStub("AceGUI-3.0", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

---------------------------------------------------------------------------
-- Zugriff auf Profilwerte über info.arg = { "pfad", "zum", "schlüssel" }
---------------------------------------------------------------------------

local function resolve(path)
  local t = ns.db.profile
  for i = 1, #path - 1 do t = t[path[i]] end
  return t, path[#path]
end

local function get(info)
  local t, k = resolve(info.arg)
  return t[k]
end

local function set(info, value)
  local t, k = resolve(info.arg)
  t[k] = value
  ns.Debug:Add("setting", { [table.concat(info.arg, ".")] = value })
  ns:Refresh()
  ns.EditMode:Refresh()   -- Sperre und Skalierung im Bearbeitungsmodus-Dialog nachziehen
end

-- wie set, leert zusätzlich die Trend-Historie (Modus, Datenquelle, Zeitfenster)
local function setClearHistory(info, value)
  ns.Data:ClearHistory()
  set(info, value)
end

local function getColor(info)
  local t, k = resolve(info.arg)
  local c = t[k]
  return c.r, c.g, c.b, c.a
end

local function setColor(info, r, g, b, a)
  local t, k = resolve(info.arg)
  local c = t[k]
  c.r, c.g, c.b = r, g, b
  if c.a ~= nil and a ~= nil then c.a = a end
  ns:Refresh()
end

local function trendStyleIs(...)
  local style = ns.db.profile.trend.style
  for i = 1, select("#", ...) do
    if style == select(i, ...) then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Schriftauswahl: mit AceGUI-3.0-SharedMediaWidgets (Vorschau der Schrift),
-- sonst normales Dropdown mit den LibSharedMedia-Namen.
---------------------------------------------------------------------------

local function hasFontWidget()
  return AceGUI ~= nil and AceGUI:GetWidgetVersion("LSM30_Font") ~= nil
end

local function fontValues()
  if not LSM then return {} end
  if hasFontWidget() then
    return LSM:HashTable("font")   -- Name -> Datei, das Widget zeigt damit die Vorschau
  end
  local list = {}
  for _, name in ipairs(LSM:List("font")) do list[name] = name end
  return list
end

---------------------------------------------------------------------------
-- Optionstabelle
---------------------------------------------------------------------------

local function buildOptions()
  local o = {
    type = "group",
    name = "OwnDPS",
    childGroups = "tab",
    args = {},
  }

  -- Allgemein ---------------------------------------------------------------
  o.args.general = {
    type = "group", order = 1, name = L["TAB_GENERAL"],
    args = {
      mode = {
        type = "select", order = 1, name = L["OPT_MODE"], desc = L["OPT_MODE_DESC"],
        values = { dps = L["UNIT_DPS"], hps = L["UNIT_HPS"] },
        arg = { "mode" }, get = get, set = setClearHistory,
      },
      dataSource = {
        type = "select", order = 2, name = L["OPT_SOURCE"], width = "double",
        values = { auto = L["SOURCE_AUTO"], current = L["SOURCE_CURRENT"], overall = L["SOURCE_OVERALL"] },
        sorting = { "auto", "current", "overall" },
        arg = { "dataSource" }, get = get, set = setClearHistory,
      },
      elementsHeader = { type = "header", order = 10, name = L["OPT_ELEMENTS"] },
      showRank = {
        type = "toggle", order = 11, name = L["ELEMENT_RANK"],
        arg = { "showRank" }, get = get, set = set,
      },
      showName = {
        type = "toggle", order = 12, name = L["ELEMENT_NAME"],
        arg = { "showName" }, get = get, set = set,
      },
      nameClassColor = {
        type = "toggle", order = 13, name = L["OPT_NAME_CLASSCOLOR"],
        disabled = function() return not ns.db.profile.showName end,
        arg = { "nameClassColor" }, get = get, set = set,
      },
      showUnit = {
        type = "toggle", order = 14, name = L["ELEMENT_UNIT"],
        arg = { "showUnit" }, get = get, set = set,
      },
      positionHeader = { type = "header", order = 20, name = L["OPT_POSITION"] },
      positionNote = { type = "description", order = 21, name = L["OPT_POSITION_NOTE"] },
      locked = {
        type = "toggle", order = 22, name = L["OPT_LOCKED"], desc = L["OPT_LOCKED_DESC"],
        arg = { "locked" }, get = get, set = set,
      },
      resetPosition = {
        type = "execute", order = 23, name = L["OPT_RESET_POSITION"], desc = L["OPT_RESET_POSITION_DESC"],
        func = function() ns.EditMode:ResetPosition() end,
      },
      visibilityHeader = { type = "header", order = 30, name = L["OPT_VISIBILITY"] },
      visibility = {
        type = "select", order = 31, name = L["OPT_VISIBILITY"], desc = L["OPT_VISIBILITY_DESC"],
        values = {
          always = L["VISIBILITY_ALWAYS"], instance = L["VISIBILITY_INSTANCE"],
          group = L["VISIBILITY_GROUP"], combat = L["VISIBILITY_COMBAT"],
        },
        sorting = { "always", "instance", "group", "combat" },
        arg = { "visibility" }, get = get, set = set,
      },
      hideInVehicle = {
        type = "toggle", order = 32, name = L["OPT_HIDE_VEHICLE"],
        arg = { "hideInVehicle" }, get = get, set = set,
      },
      debugHeader = { type = "header", order = 90, name = L["OPT_DEBUG"] },
      debug = {
        type = "toggle", order = 91, name = L["OPT_DEBUG"], desc = L["OPT_DEBUG_DESC"], width = "full",
        get = function() return ns.Debug:IsEnabled() end,
        set = function(_, value)
          if not value then ns.Debug:Add("debugOff") end
          ns.Debug:SetEnabled(value)
        end,
      },
    },
  }

  -- Darstellung -------------------------------------------------------------
  o.args.appearance = {
    type = "group", order = 2, name = L["TAB_APPEARANCE"],
    args = {
      fontHeader = { type = "header", order = 1, name = L["OPT_FONT_HEADER"] },
      font = {
        type = "select", order = 2, name = L["OPT_FONT"],
        dialogControl = hasFontWidget() and "LSM30_Font" or nil,
        values = fontValues,
        arg = { "font", "name" }, get = get, set = set,
      },
      fontSize = {
        type = "range", order = 3, name = L["OPT_FONT_SIZE"], min = 6, max = 48, step = 1,
        arg = { "font", "size" }, get = get, set = set,
      },
      outline = {
        type = "select", order = 4, name = L["OPT_OUTLINE"],
        values = { NONE = L["OUTLINE_NONE"], OUTLINE = L["OUTLINE_THIN"], THICKOUTLINE = L["OUTLINE_THICK"] },
        sorting = { "NONE", "OUTLINE", "THICKOUTLINE" },
        get = function()
          local v = ns.db.profile.font.outline
          return (v == "" or v == nil) and "NONE" or v
        end,
        set = function(_, value)
          ns.db.profile.font.outline = (value == "NONE") and "" or value
          ns:Refresh()
        end,
      },
      shadow = {
        type = "toggle", order = 5, name = L["OPT_SHADOW"],
        arg = { "font", "shadow" }, get = get, set = set,
      },
      colorsHeader = { type = "header", order = 10, name = L["OPT_COLORS"] },
      colorRank = {
        type = "color", order = 11, name = L["ELEMENT_RANK"], desc = L["OPT_RANKCOLORS_OVERRIDE"],
        disabled = function() return ns.db.profile.rankColors.enabled end,
        arg = { "colors", "rank" }, get = getColor, set = setColor,
      },
      colorName = {
        type = "color", order = 12, name = L["ELEMENT_NAME"],
        disabled = function() return ns.db.profile.nameClassColor end,
        arg = { "colors", "name" }, get = getColor, set = setColor,
      },
      colorValue = {
        type = "color", order = 13, name = L["OPT_VALUE"], desc = L["OPT_RANKCOLORS_OVERRIDE"],
        disabled = function() return ns.db.profile.rankColors.enabled end,
        arg = { "colors", "value" }, get = getColor, set = setColor,
      },
      colorUnit = {
        type = "color", order = 14, name = L["ELEMENT_UNIT"],
        arg = { "colors", "unit" }, get = getColor, set = setColor,
      },
      -- Farben nach Platzierung (1.1.0): färbt Platzzahl und Wert, Name/Einheit bleiben
      rankColors = {
        type = "group", order = 15, inline = true, name = L["OPT_RANKCOLORS"],
        args = {
          enabled = {
            type = "toggle", order = 1, width = "full",
            name = L["OPT_RANKCOLORS_ENABLE"], desc = L["OPT_RANKCOLORS_ENABLE_DESC"],
            arg = { "rankColors", "enabled" }, get = get, set = set,
          },
          first = {
            type = "color", order = 2, name = L["OPT_RANKCOLOR_FIRST"],
            disabled = function() return not ns.db.profile.rankColors.enabled end,
            arg = { "rankColors", "first" }, get = getColor, set = setColor,
          },
          second = {
            type = "color", order = 3, name = L["OPT_RANKCOLOR_SECOND"],
            disabled = function() return not ns.db.profile.rankColors.enabled end,
            arg = { "rankColors", "second" }, get = getColor, set = setColor,
          },
          rest = {
            type = "color", order = 4, name = L["OPT_RANKCOLOR_REST"],
            disabled = function() return not ns.db.profile.rankColors.enabled end,
            arg = { "rankColors", "rest" }, get = getColor, set = setColor,
          },
        },
      },
      frameHeader = { type = "header", order = 20, name = L["OPT_FRAME"] },
      backgroundShow = {
        type = "toggle", order = 21, name = L["OPT_BACKGROUND"],
        arg = { "background", "show" }, get = get, set = set,
      },
      backgroundColor = {
        type = "color", order = 22, name = L["OPT_BACKGROUND_COLOR"], desc = L["OPT_BACKGROUND_COLOR_DESC"], hasAlpha = true,
        disabled = function() return not ns.db.profile.background.show end,
        arg = { "background", "color" }, get = getColor, set = setColor,
      },
      spacer1 = { type = "description", order = 23, name = "" },
      borderShow = {
        type = "toggle", order = 24, name = L["OPT_BORDER"],
        arg = { "border", "show" }, get = get, set = set,
      },
      borderColor = {
        type = "color", order = 25, name = L["OPT_BORDER_COLOR"], hasAlpha = true,
        disabled = function() return not ns.db.profile.border.show end,
        arg = { "border", "color" }, get = getColor, set = setColor,
      },
      spacer2 = { type = "description", order = 26, name = "" },
      scale = {
        type = "range", order = 27, name = L["OPT_SCALE"], min = 0.5, max = 3, step = 0.05, isPercent = true,
        arg = { "scale" }, get = get,
        set = function(info, value) set(info, ns.RoundScale(value)) end,
      },
      alpha = {
        type = "range", order = 28, name = L["OPT_ALPHA"], min = 0.1, max = 1, step = 0.05, isPercent = true,
        arg = { "alpha" }, get = get, set = set,
      },
    },
  }

  -- Trend -------------------------------------------------------------------
  o.args.trend = {
    type = "group", order = 3, name = L["TAB_TREND"],
    args = {
      style = {
        type = "select", order = 1, name = L["OPT_TREND_STYLE"], desc = L["OPT_TREND_STYLE_DESC"],
        values = { arrow = L["STYLE_ARROW"], boxes = L["STYLE_BOXES"], bars = L["STYLE_BARS"], off = L["STYLE_OFF"] },
        sorting = { "arrow", "boxes", "bars", "off" },
        arg = { "trend", "style" }, get = get, set = set,
      },
      boxLayout = {
        type = "select", order = 2, name = L["OPT_BOXLAYOUT"], desc = L["OPT_BOXLAYOUT_DESC"],
        values = { side = L["BOXLAYOUT_SIDE"], stack = L["BOXLAYOUT_STACK"] },
        sorting = { "side", "stack" },
        disabled = function() return not trendStyleIs("boxes") end,
        arg = { "trend", "boxLayout" }, get = get, set = set,
      },
      window = {
        type = "range", order = 3, name = L["OPT_WINDOW"], desc = L["OPT_WINDOW_DESC"],
        min = 0.5, max = 30, step = 0.5,
        disabled = function() return trendStyleIs("off") end,
        arg = { "trend", "window" }, get = get, set = setClearHistory,
      },
      tolerance = {
        type = "range", order = 4, name = L["OPT_TOLERANCE"], desc = L["OPT_TOLERANCE_DESC"],
        min = 0.001, max = 0.2, step = 0.001, isPercent = true,
        disabled = function() return not trendStyleIs("arrow", "boxes") end,
        arg = { "trend", "tolerance" }, get = get, set = set,
      },
      sizeHeader = { type = "header", order = 10, name = L["OPT_TREND_SIZE"] },
      sizeCoupled = {
        type = "toggle", order = 11, name = L["OPT_TREND_SIZE_COUPLED"],
        get = function() return ns.db.profile.trend.size == 0 end,
        set = function(_, value)
          local p = ns.db.profile
          p.trend.size = value and 0 or p.font.size
          ns:Refresh()
        end,
      },
      size = {
        type = "range", order = 12, name = L["OPT_TREND_SIZE"], min = 6, max = 64, step = 1,
        disabled = function() return ns.db.profile.trend.size == 0 end,
        get = function() return ns.Display:GetTrendSize() end,
        set = function(_, value)
          ns.db.profile.trend.size = value
          ns:Refresh()
        end,
      },
      colorsHeader = { type = "header", order = 20, name = L["OPT_COLORS"] },
      colorUp = {
        type = "color", order = 21, name = L["OPT_COLOR_UP"],
        arg = { "trend", "colors", "up" }, get = getColor, set = setColor,
      },
      colorDown = {
        type = "color", order = 22, name = L["OPT_COLOR_DOWN"],
        arg = { "trend", "colors", "down" }, get = getColor, set = setColor,
      },
      note = { type = "description", order = 30, name = "\n" .. L["OPT_TREND_NOTE"] },
    },
  }

  -- Profile: "Kopieren von", Zurücksetzen usw. (AceDBOptions-3.0) ------------
  if AceDBOptions then
    o.args.profiles = AceDBOptions:GetOptionsTable(ns.db)
    o.args.profiles.order = 100
  end

  return o
end

---------------------------------------------------------------------------
-- Registrieren und Öffnen
---------------------------------------------------------------------------

function Options:Init()
  if not (AceConfig and AceConfigDialog) then
    ns.Debug:Error("Options", "AceConfig-3.0 missing")
    return
  end
  local ok, err = pcall(function()
    AceConfig:RegisterOptionsTable(ADDON_NAME, buildOptions())
    -- Seit Ace3 r1390 (WoW 12.0) muss die zweite Rückgabe an Settings.OpenToCategory
    -- weitergegeben werden (Ace3 changelog.txt).
    local _, categoryID = AceConfigDialog:AddToBlizOptions(ADDON_NAME, "OwnDPS")
    self.categoryID = categoryID
  end)
  if not ok then ns.Debug:Error("Options:Init", err) end
end

-- Rückgabe true, wenn das Menü verfügbar ist (auch wenn es im Kampf gesperrt ist)
function Options:Open()
  if not self.categoryID then return false end
  -- C_SettingsUtil.OpenSettingsPanel ist als HasRestrictions markiert: im Kampf nicht aufrufen
  if InCombatLockdown() then
    ns.Print(L["NOT_IN_COMBAT"])
    return true
  end
  local ok, err = pcall(Settings.OpenToCategory, self.categoryID)
  if not ok then
    ns.Debug:Error("OpenToCategory", err)
    return false
  end
  return true
end

local function editModeShown()
  if not EditModeManagerFrame then return "missing" end
  local ok, shown = pcall(EditModeManagerFrame.IsShown, EditModeManagerFrame)
  return ok and shown or "error"
end

-- Eigenständiges AceConfigDialog-Fenster, für den Button im Bearbeitungsmodus.
-- Settings.OpenToCategory lief dort ohne Fehler, zeigte aber kein Fenster (Test 0.4.0-alpha.1).
-- Das AceGUI-Fenster liegt in der Ebene FULLSCREEN_DIALOG, der Bearbeitungsmodus in DIALOG.
function Options:OpenStandalone()
  if not AceConfigDialog then return false end
  local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, ADDON_NAME)
  local openFrame = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[ADDON_NAME]
  local okShown, frameShown = false, nil
  if openFrame and openFrame.frame then
    okShown, frameShown = pcall(openFrame.frame.IsShown, openFrame.frame)
  end
  ns.Debug:Add("optionsStandalone", {
    ok = ok,
    err = err,
    editModeShown = editModeShown(),
    frameShown = okShown and frameShown or false,
  })
  if not ok then ns.Debug:Error("AceConfigDialog:Open", err) end
  return ok
end
