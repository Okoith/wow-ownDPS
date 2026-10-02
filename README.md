# OwnDPS

<p align="center"><img src="docs/owndps_logo.png" alt="OwnDPS logo" width="256"></p>

World of Warcraft addon (Retail 12.1, Midnight) that shows your own DPS or HPS, your rank and a trend indicator in a single line:

```
1. 495.1k DPS ▲
```

**Download:** [CurseForge](https://www.curseforge.com/wow/addons/owndps) · [GitHub Releases](../../releases)

<!-- Screenshot: Anzeige im Kampf mit Trend-Pfeil -->
<!-- Screenshot: Einstellungsmenü -->
<!-- Screenshot: Bearbeitungsmodus mit OwnDPS-Dialog -->

## Features

- **One line:** rank, optional character name, value (`123.4k`, `12.3M`) and unit (DPS or HPS)
- **DPS or HPS:** rank, value and trend always refer to the selected mode
- **Data source:** automatic (current fight in combat, overall otherwise), always current fight, or always overall
- **Trend indicator** (combat only): arrow, boxes (side by side or stacked), bars, or off; adjustable time window and tolerance
- **Appearance:** font (LibSharedMedia), size, outline, shadow, colors per element, name in class color, optional colors by rank, background, border, scale, opacity
- **Edit Mode:** move the display in WoW's Edit Mode, position saved per layout, option to lock it; a sample line with trend indicator is shown there
- **No empty frame:** while there is no value (for example before your first hit), the display is hidden completely
- **Visibility:** always, only in instances, only in a group, or only in combat; optionally hidden in vehicles; always hidden during pet battles
- **Profiles:** settings per character, copy them from another character
- **Languages:** English and German

## Data source: Blizzard's damage meter API

OwnDPS reads all numbers from Blizzard's `C_DamageMeter` API. It does not use the combat log.

- It also works when Blizzard's own damage meter window is switched off (tested with the CVar `damageMeterEnabled = 0`).
- In combat, WoW hands out these values only as protected ("secret") values. OwnDPS never calculates with them. The trend is compared by the game itself while drawing the indicator.
- Blizzard resets the overall session when you enter a dungeon. OwnDPS does not reset anything itself.

## Installation

Install OwnDPS from [CurseForge](https://www.curseforge.com/wow/addons/owndps) (for example with the CurseForge app), or download the zip from the [Releases](../../releases) page and extract it to `World of Warcraft\_retail_\Interface\AddOns\`.

## Usage

- **Settings:** type `/owndps` or open *Settings > AddOns > OwnDPS*. Changes apply immediately. The settings cannot be opened during combat.
- **Position:** open WoW's Edit Mode (*Esc > Edit Mode*) and drag the OwnDPS frame. Clicking it opens a dialog with a scale slider and a *More settings* button. The position is saved per Edit Mode layout. With *Lock* enabled the frame cannot be moved, not even in Edit Mode.
- **Edit Mode preview:** in Edit Mode the display always shows a sample line such as `1. 123.4k DPS` (or HPS, with your name if enabled) and the trend indicator in the selected style, so you can adjust position and size even without combat data.
- **Hidden without data:** outside Edit Mode the display (text, trend, background and border) is hidden while no value is available. The visibility rules (instance, group, combat, vehicle, pet battle) apply in addition.

### Settings

- **General:** mode, data source, rank/name/unit, name in class color, lock, reset position, visibility, hide in vehicles, debug mode
- **Appearance:** font, font size, outline, shadow, colors, colors by rank, background, border, scale, opacity
  - **Colors by rank** (off by default): rank and value are shown in their own color for rank 1 (green), rank 2 (yellow) and rank 3 and below (red); name and unit keep their colors. Solo you are always rank 1. Works in DPS and HPS mode and also when the rank number is hidden.
- **Trend:** style, box arrangement, time window, tolerance, indicator size, colors
- **Profiles:** switch, copy from another character, reset

## Commands

| Command | Effect |
|---|---|
| `/owndps` | Open the settings |
| `/owndps help` | List the commands |
| `/owndps mode dps\|hps` | Show damage or healing |
| `/owndps source auto\|current\|overall` | Data source |
| `/owndps toggle rank\|name\|unit` | Show or hide an element |
| `/owndps trend arrow\|boxes\|bars\|off` | Trend style (shown in combat only) |
| `/owndps boxlayout side\|stack` | Arrangement of the trend boxes |
| `/owndps window N` | Trend time window in seconds (0.5 to 30) |
| `/owndps tolerance N` | Trend tolerance in percent (0.1 to 20, arrow and boxes) |
| `/owndps trendsize N` | Indicator size in pixels (0 = font size) |
| `/owndps reset` | Reset the position in the active Edit Mode layout |
| `/owndps debug on\|off\|clear\|status` | Debug log (`OwnDPSDebugLog` in SavedVariables, off by default) |
| `/owndps status` | Current settings |

## Development

Libraries are fetched by the [BigWigs packager](https://github.com/BigWigsMods/packager) from `.pkgmeta` and are not part of the repository: LibStub, CallbackHandler-1.0, AceDB-3.0, AceDBOptions-3.0, AceGUI-3.0, AceConfig-3.0, LibSharedMedia-3.0, AceGUI-3.0-SharedMediaWidgets, LibEditMode.

### Releases

Pushing a tag `v*` (for example `v1.0.0`, test builds `v0.x.y-alpha.N` or `v0.x.y-beta.N`) starts `.github/workflows/release.yml`. It builds a zip with all libraries, publishes it as a GitHub release and uploads it to [CurseForge](https://www.curseforge.com/wow/addons/owndps). The version shown in the game comes from the tag (`## Version: @project-version@` in `OwnDPS.toc`).

**CurseForge upload:** the project ID is set in `OwnDPS.toc` (`## X-Curse-Project-ID: 1709067`), and the workflow passes the Actions secret **`CF_API_TOKEN`** to the packager. The packager only uploads when both are present; without the secret (for example in a fork) only the GitHub release is created. To renew the token:

1. Create an API token at <https://authors.curseforge.com/#/settings/api-tokens>.
2. In the GitHub repository, store it as the Actions secret **`CF_API_TOKEN`** (*Settings > Secrets and variables > Actions*).

## License

MIT, see [LICENSE](LICENSE).
