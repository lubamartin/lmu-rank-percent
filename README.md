# LMU Rank Percent

Restores **Driver Rank** and **Safety Rank** percentages in Le Mans Ultimate after the V1.1 UI change that replaced them with a segmented bar only.

## What you get

| Where | Shows |
| --- | --- |
| Profile / menus (any `RankSquare`) | Current progress, e.g. `42%` |
| Post-race badges | Progress + race delta on one line, e.g. `20%  -3.3%` |
| Post-race impact rows | Numeric % only if RaceControl sends it (rows are qualitative, not additive) |

Uses values the game already has locally (`progress`, `drChange`, `srChange`). No RaceControl calls, no scraping.

When a post-race screen includes both a real `%` delta and an arrow adjustment, the mod stores that rate per DR/SR tier in browser `localStorage`. Later races that only expose arrows use the learned rate (fallback: community defaults). More races → tighter estimates.

## Install (~2–5 min)

1. **Quit LMU completely.**
2. Unzip this mod somewhere convenient.
3. In PowerShell:

```powershell
cd "path\to\LMU_Rank_Percent_v1.1.0"
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

Optional if Steam autodetection fails:

```powershell
.\install.ps1 -GameRoot "E:\SteamLibrary\steamapps\common\Le Mans Ultimate"
```

4. Launch LMU → Profile → check DR/SR badges for a `%` under the bar.

## Uninstall

```powershell
.\uninstall.ps1
```

Or Steam → Le Mans Ultimate → Properties → Installed Files → Verify integrity (restores `UI.zip`).

## Notes

- Patches `Bin\UI.zip` → `start/assets/app-*.js` (`RankSquare` + `RankCard`).
- First install stores a clean JS backup next to the scripts under `backup\`.
- A game update that replaces `UI.zip` removes the patch — run `install.ps1` again.
- If Studio 397 renames/refactors those components, the installer will error; the regex anchors need a refresh for that game build.
