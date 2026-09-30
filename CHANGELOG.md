# Changelog

## 1.0.2

- Addon icon in the AddOns list

## 1.0.1

- CurseForge project ID added, automatic uploads to CurseForge

## 1.0.0

First stable release.

OwnDPS shows your own DPS or HPS, your rank and a trend indicator in a single line, for example `1. 495.1k DPS ▲`. All numbers come from Blizzard's damage meter API (`C_DamageMeter`). The combat log is not used, and OwnDPS also works when Blizzard's own damage meter window is turned off.

### Features

- **One line:** rank, optional character name (optionally in class color), value (`123.4k`, `12.3M`, `1.2B`, whole numbers below 1,000) and unit. Every element except the value can be hidden.
- **DPS or HPS:** rank, value and trend always refer to the selected mode.
- **Data source:** automatic (current fight in combat, overall otherwise), always current fight, or always overall.
- **Trend indicator** (in combat only): arrow, boxes (side by side or stacked), bars, or off. Adjustable time window (0.5 to 30 seconds), tolerance (0.1 to 20 %), colors and size.
- **Appearance:** font (LibSharedMedia), font size, outline, shadow, colors per element, optional background and border, scale and opacity.
- **Edit Mode:** move the display in WoW's Edit Mode; the position is saved per layout. The Edit Mode dialog has a scale slider and a *More settings* button. An optional lock prevents moving. While editing, a sample line with the trend indicator is shown.
- **Visibility:** always, only in instances, only in a group, or only in combat; optionally hidden in vehicles; always hidden during pet battles. The display is hidden while no value is available.
- **Settings:** *Settings > AddOns > OwnDPS* or `/owndps`. All changes apply immediately.
- **Profiles:** settings are stored per character; copy them from another character or reset them.
- **Slash commands** for the main options, see `/owndps help`.
- **Debug mode** (off by default) that writes a log to the SavedVariables.
- **Languages:** English and German.

### Changes since 0.5.0-beta.1

- The logo is no longer part of the addon package (download size about 180 KB instead of 2.2 MB).
- The version shown in the addon list is now taken from the release tag.

## 0.5.0-beta.1 (2026-09-23)

Release-Kandidat. Alle Meilensteine aus CLAUDE.md sind umgesetzt und im Spiel getestet (bis 0.4.1-alpha.1).

- Ohne Wert wird die Anzeige komplett ausgeblendet (Text, Trend, Hintergrund, Rahmen) statt „-“ zu zeigen. Die Sichtbarkeitsregeln gelten weiterhin zusätzlich.
- Umsetzung über einen inneren, nicht geschützten Container-Frame; der Hauptframe bleibt beim State Driver, im Kampf wird kein `RegisterStateDriver` aufgerufen.
- Bearbeitungsmodus: immer sichtbar mit Beispieltext „1. 123.4k DPS“ bzw. „HPS“ (inkl. Name, falls aktiviert) und dem Trend-Indikator im gewählten Stil als Muster
- SPEC.md Abschnitt 10 um die Testergebnisse aus Meilenstein 3 und 4 ergänzt
- README ergänzt (Vorschau im Bearbeitungsmodus, Ausblenden ohne Daten, Beta-Tags)

## 0.4.1-alpha.1 (2026-09-23)

Korrekturen aus dem Test von 0.4.0-alpha.1.

- Behoben: Der Button „Weitere Einstellungen“ im Bearbeitungsmodus öffnete kein Fenster. Er öffnet das Menü jetzt als eigenständiges Fenster (`AceConfigDialog:Open`). `/owndps` und der Eintrag unter AddOns bleiben unverändert.
- Debug-Log: Eintrag `optionsStandalone` mit Ergebnis, ob das Fenster sichtbar ist und ob der Bearbeitungsmodus (`EditModeManagerFrame`) offen ist
- Behoben: Der Skalierungs-Slider im Bearbeitungsmodus zeigte Werte wie `1.7000000476837`. Anzeige jetzt mit zwei Nachkommastellen, gespeichert wird auf 0,01 gerundet (auch im Menü)

## 0.4.0-alpha.1 (2026-09-23)

Meilenstein 4: Bearbeitungsmodus.

- OwnDPS erscheint im WoW-Bearbeitungsmodus (LibEditMode), die Position wird pro Layout gespeichert
- Dialog im Bearbeitungsmodus: Skalierung als Slider, Button „Weitere Einstellungen“ öffnet das OwnDPS-Menü
- Neue Option „Sperren“: Die Anzeige lässt sich dann auch im Bearbeitungsmodus nicht verschieben (Ziehen, Pfeiltasten und „Position zurücksetzen“ im Dialog)
- `/owndps move` entfernt, `/owndps reset` und der Menüpunkt setzen die Position im aktiven Layout zurück
- Migration: Die bisherige Position wird für jedes Layout ohne eigenen Eintrag übernommen

Meilenstein 5: Feinschliff.

- Sichtbarkeit: Immer, Nur in Instanzen, Nur in Gruppe, Nur im Kampf; zusätzlich „Im Fahrzeug ausblenden“; im Haustierkampf immer ausgeblendet
- Umsetzung über den State Driver (`[combat]`, `[group]`, `[vehicleui]`, `[petbattle]`); Instanzen über `IsInInstance()` bei Zonenwechseln, weil es dafür keine Macro-Bedingung gibt; Änderungen im Kampf werden bis Kampfende zurückgestellt
- Debugmodus ist standardmäßig aus
- README fertiggestellt (Funktionen, Bedienung, Befehle, Datenquelle `C_DamageMeter`, CurseForge-Einrichtung)
- Release-Workflow reicht `CF_API_TOKEN` an den Packager weiter; ohne Secret und Projekt-ID entsteht weiterhin nur das GitHub-Release

## 0.3.0-alpha.1 (2026-09-23)

Meilenstein 3: Einstellungsmenü.

- Einstellungsmenü unter Einstellungen > AddOns > OwnDPS (AceConfig-3.0), `/owndps` öffnet es, `/owndps help` zeigt die Befehle
- Reiter Allgemein: Modus, Datenquelle, Platz/Name/Einheit, Name in Klassenfarbe, Position zurücksetzen, Debugmodus
- Reiter Darstellung: Schriftart (LibSharedMedia, mit Vorschau über AceGUI-3.0-SharedMediaWidgets), Schriftgröße, Kontur, Schatten, Farben für Platz/Name/Wert/Einheit, Hintergrund (Farbe und Transparenz, standardmäßig aus), Rahmen (an/aus, Farbe), Skalierung, Gesamt-Transparenz
- Reiter Trend: Stil, Kästchen-Anordnung, Zeitfenster, Toleranz, Indikatorgröße, Farben hoch/runter
- Reiter Profile (AceDBOptions-3.0): Profil wechseln, „Kopieren von“ anderen Charakteren, Zurücksetzen
- Alle Änderungen sofort sichtbar, ohne /reload
- Hintergrund und Rahmen hängen per Anker an Text und Trend-Indikator (keine berechneten Breiten, da `GetStringWidth` im Kampf geheim ist)
- Trend-Stil Kästchen: neue Option Anordnung „Nebeneinander“ (Standard, links hoch, rechts runter) oder „Übereinander“ (deckungsgleich; bei „stabil“ ist nur die obere Farbe sichtbar), beide in voller Indikatorgröße
- Neuer Befehl `/owndps boxlayout side|stack`

## 0.2.0-alpha.1 (2026-09-23)

Meilenstein 2: Trend.

- Trend-Indikator mit vier Stilen: Pfeil (Standard), Kästchen, Balken, Aus
- Pfeil und Kästchen nutzen den Abschneide-Trick, Pfeilform über Masken aus `media/`
- Zeitfenster (Standard 3 s, 0,5 bis 30 s) und Toleranz (Standard 1 %, 0,1 bis 20 %)
- Farben hoch (grün) und runter (rot), Größe an die Schriftgröße gekoppelt oder eigener Wert
- Indikator nur im Kampf sichtbar, Historie wird bei Kampfbeginn, Reset und Wechsel von Modus oder Datenquelle geleert
- Neue Befehle: `/owndps trend`, `/owndps window`, `/owndps tolerance`, `/owndps trendsize`
- Debug-Log: Trend-Status pro Sekunde im Kampf
- Behoben: Werte unter 1000 wurden ungerundet angezeigt (z. B. `240.07407407407 HPS`), jetzt ganze Zahl
- Debug-Log: Selbsttest des Zahlenformats beim Einschalten (`formatSelfTest`)

## 0.1.0-alpha.1 (2026-09-23)

Meilenstein 1: Grundgerüst.

- TOC für Retail 12.1.0 (Interface 120100), Locales enUS und deDE
- Einstellungen pro Charakter über AceDB-3.0
- Textzeile `Platz Wert Einheit` (Name optional, standardmäßig aus)
- Datenquelle Automatisch (im Kampf aktueller Kampf, sonst Gesamt), Immer aktueller Kampf, Immer Gesamt
- Modus DPS oder HPS
- Im Haustierkampf ausgeblendet
- Debugmodus mit Log in `OwnDPSDebugLog` (max. 5000 Einträge, Secret Values nur als `<SECRET>`)
- Slash-Befehl `/owndps` (Einstellungsmenü folgt in Meilenstein 3)
- Release-Workflow mit BigWigs Packager (GitHub Release bei Tag `v*`)
