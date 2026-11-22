#Requires -Version 5.1
<#
.SYNOPSIS
  Restores Driver/Safety Rank percentages in Le Mans Ultimate UI.

.DESCRIPTION
  Patches RankSquare + RankCard inside Bin\UI.zip so the game shows:
  - current progress % on every rank badge (profile, menus, post-race)
  - post-race +/- % change from drChange / srChange

  Uses only values the game already receives locally. No RaceControl calls.
#>
[CmdletBinding()]
param(
  [string]$GameRoot = "",
  [switch]$WhatIf,
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$PluginRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $PluginRoot "backup"
$Marker = "/*LMU-RANK-PERCENT*/"

function Find-LmuRoot {
  param([string]$Hint)
  if ($Hint -and (Test-Path (Join-Path $Hint "Bin\UI.zip"))) {
    return (Resolve-Path $Hint).Path
  }

  $candidates = @(
    "E:\SteamLibrary\steamapps\common\Le Mans Ultimate",
    "C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate",
    "D:\SteamLibrary\steamapps\common\Le Mans Ultimate",
    "F:\SteamLibrary\steamapps\common\Le Mans Ultimate"
  )
  foreach ($c in $candidates) {
    if (Test-Path (Join-Path $c "Bin\UI.zip")) { return $c }
  }

  $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
  if ($steamPath) {
    $vdf = Join-Path $steamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
      $libs = @($steamPath)
      $libs += (Get-Content $vdf -Raw | Select-String -Pattern '"path"\s+"([^"]+)"' -AllMatches).Matches |
        ForEach-Object { $_.Groups[1].Value -replace "\\\\", "\" }
      foreach ($lib in ($libs | Select-Object -Unique)) {
        $p = Join-Path $lib "steamapps\common\Le Mans Ultimate"
        if (Test-Path (Join-Path $p "Bin\UI.zip")) { return $p }
      }
    }
  }
  throw "Could not find Le Mans Ultimate (Bin\UI.zip). Pass -GameRoot 'X:\path\to\Le Mans Ultimate'."
}

$NewRankSquare = @'
function RankSquare({
  title: title2,
  rank: rank2,
  size = "normal",
  classNames,
  change: change2,
  allowSnapshotDelta
}) {/*LMU-RANK-PERCENT*/
  function getProgressBarWidth() {
    return size === "small" ? "4.5rem" : "8rem";
  }
  function snapshotKey() {
    return "lmu-rp:" + String(title2 || "rank") + ":" + String(rank2.rank) + ":" + String(rank2.tier);
  }
  function readPrev() {
    try {
      const raw = localStorage.getItem(snapshotKey());
      return raw ? JSON.parse(raw) : null;
    } catch (e2) {
      return null;
    }
  }
  function writePrev() {
    try {
      localStorage.setItem(snapshotKey(), JSON.stringify({
        progress: Number(rank2.progress) || 0,
        rank: rank2.rank,
        tier: rank2.tier
      }));
    } catch (e2) {
    }
  }
  function resolveChange() {
    if (change2 != null && Number.isFinite(Number(change2)) && Number(change2) !== 0) {
      return Number(change2);
    }
    if (!allowSnapshotDelta) {
      return void 0;
    }
    const prev = readPrev();
    if (prev && prev.rank === rank2.rank && Number(prev.tier) === Number(rank2.tier)) {
      const delta = (Number(rank2.progress) || 0) - (Number(prev.progress) || 0);
      if (Math.abs(delta) >= 0.05) {
        return delta;
      }
    }
    return change2 != null && Number.isFinite(Number(change2)) ? Number(change2) : void 0;
  }
  function formatChange(value2) {
    if (value2 == null || !Number.isFinite(value2) || value2 === 0) {
      return null;
    }
    const rounded = Math.round(value2 * 10) / 10;
    const sign = rounded > 0 ? "+" : "";
    return sign + rounded.toFixed(1) + "%";
  }
  const resolvedChange = resolveChange();
  const changeLabel = formatChange(resolvedChange);
  const percentLabel = Math.round(Number(rank2.progress) || 0) + "%";
  writePrev();
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(
    "div",
    {
      className: getClassName(classes$21.rankSquare, {
        [classes$21.sizeSmall]: size === "small",
        [classes$21.sizeNormal]: size === "normal"
      }),
      style: {
        "--rank-color": `var(--clr-badge-${rank2.rank.toLowerCase()})`,
        "--progress-fill": `${rank2.progress}%`
      },
      children: [
        title2 && /* @__PURE__ */ jsxRuntimeExports.jsx("h4", { className: classes$21.title, children: title2 }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: getClassName(classes$21.square, classNames == null ? void 0 : classNames.square), children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$21.top, style: { justifyContent: "flex-start" }, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("h4", { className: classes$21.tier, children: rank2.tier }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(
              SegmentedProgressBar,
              {
                className: classes$21.progress,
                progress: {
                  value: rank2.progress / 10,
                  isRounded: true
                },
                width: getProgressBarWidth(),
                height: "0.45rem"
              }
            ),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("span", {
              style: {
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                columnGap: "0.3rem",
                fontSize: size === "small" ? "0.68rem" : "0.85rem",
                fontWeight: 700,
                lineHeight: 1,
                marginTop: size === "small" ? "-0.35rem" : "-0.65rem",
                marginBottom: size === "small" ? "0.45rem" : "0.55rem",
                letterSpacing: "0.02em"
              },
              children: [
                percentLabel,
                changeLabel && /* @__PURE__ */ jsxRuntimeExports.jsx("span", {
                  style: {
                    color: resolvedChange > 0 ? "#1eff6b" : "#ff1e44",
                    fontWeight: 700
                  },
                  children: changeLabel
                })
              ]
            })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("h4", { className: getClassName("heading-4", classes$21.rank), children: rank2.rank })
        ] })
      ]
    }
  );
}
'@

$NewRankCard = @'
function RankCard({
  currentDriver,
  results: results2,
  nkId,
  type: type2,
  size = "normal",
  className,
  reasons
}) {/*LMU-RANK-PERCENT*/
  const { t: t2 } = useTranslation();
  const heading5 = type2 === "dr" ? t2("Driver Rank") : t2("Safety Rank");
  function getRank() {
    if (results2.teamEvent) {
      const team = results2.teams.find(
        (t22) => t22.teamMembers.some((m2) => m2.driverId === nkId)
      );
      if (type2 === "dr") {
        return team.teamRank;
      } else {
        return team.safetyRank;
      }
    } else {
      if (type2 === "dr") {
        return currentDriver == null ? void 0 : currentDriver.driverRank;
      } else {
        return currentDriver == null ? void 0 : currentDriver.safetyRank;
      }
    }
  }
  function defaultPctPerArrow(rankName) {
    switch (String(rankName || "").toLowerCase()) {
      case "bronze":
        return 15;
      case "silver":
        return 8;
      case "gold":
        return 14 / 3;
      case "platinum":
        return 7 / 3;
      default:
        return 8;
    }
  }
  function learnStoreKey() {
    return "lmu-rp-learn-v1";
  }
  function readLearnStore() {
    try {
      const raw = localStorage.getItem(learnStoreKey());
      return raw ? JSON.parse(raw) : {};
    } catch (e2) {
      return {};
    }
  }
  function writeLearnStore(store) {
    try {
      localStorage.setItem(learnStoreKey(), JSON.stringify(store));
    } catch (e2) {
    }
  }
  function tierKey(rankName) {
    return String(rankName || "").toLowerCase() || "unknown";
  }
  function learnedPctPerArrow(rankName) {
    const store = readLearnStore();
    const bucket = store[type2] && store[type2][tierKey(rankName)];
    if (bucket && bucket.n >= 1 && Number.isFinite(Number(bucket.rate)) && Number(bucket.rate) > 0) {
      return Number(bucket.rate);
    }
    return defaultPctPerArrow(rankName);
  }
  function learnFromRace(rankObj, adjustment, change) {
    const adj = Number(adjustment);
    const ch = Number(change);
    const name = rankObj && rankObj.rank;
    if (!name || !Number.isFinite(adj) || adj === 0 || !Number.isFinite(ch) || ch === 0) {
      return;
    }
    if (Math.sign(adj) !== Math.sign(ch)) {
      return;
    }
    const observed = Math.abs(ch / adj);
    if (observed < 0.5 || observed > 50) {
      return;
    }
    const store = readLearnStore();
    if (!store[type2]) {
      store[type2] = {};
    }
    const key = tierKey(name);
    const prev = store[type2][key] || { n: 0, rate: defaultPctPerArrow(name) };
    const n = Number(prev.n) || 0;
    const prevRate = Number(prev.rate);
    const base = Number.isFinite(prevRate) && prevRate > 0 ? prevRate : defaultPctPerArrow(name);
    const nextN = n + 1;
    const nextRate = (base * n + observed) / nextN;
    store[type2][key] = { n: nextN, rate: Math.round(nextRate * 1000) / 1000 };
    writeLearnStore(store);
  }
  function estimateFromAdjustment(rankObj, adjustment) {
    if (!adjustment || !Number.isFinite(Number(adjustment)) || Number(adjustment) === 0) {
      return void 0;
    }
    const pct2 = Number(adjustment) * learnedPctPerArrow(rankObj && rankObj.rank);
    return Math.round(pct2 * 10) / 10;
  }
  function getChange() {
    let value2;
    let adjustment;
    if (results2.teamEvent) {
      const team = results2.teams.find(
        (t22) => t22.teamMembers.some((m2) => m2.driverId === nkId)
      );
      if (!team) {
        value2 = void 0;
        adjustment = void 0;
      } else if (type2 === "dr") {
        value2 = team.drChange != null ? team.drChange : team.teamRankChange;
        adjustment = team.teamRankAdjustment != null ? team.teamRankAdjustment : team.driverRankAdjustment;
      } else {
        value2 = team.srChange;
        adjustment = team.safetyRankAdjustment;
      }
    } else if (type2 === "dr") {
      value2 = currentDriver == null ? void 0 : currentDriver.drChange;
      adjustment = currentDriver == null ? void 0 : currentDriver.driverRankAdjustment;
    } else {
      value2 = currentDriver == null ? void 0 : currentDriver.srChange;
      adjustment = currentDriver == null ? void 0 : currentDriver.safetyRankAdjustment;
    }
    const rankObj = getRank();
    if (value2 != null && Number.isFinite(Number(value2)) && Number(value2) !== 0) {
      learnFromRace(rankObj, adjustment, Number(value2));
      return Number(value2);
    }
    return estimateFromAdjustment(rankObj, adjustment);
  }
  const rank2 = getRank();
  const change2 = getChange();
  return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: getClassName(classes$1D.rankCard, className), children: rank2 && /* @__PURE__ */ jsxRuntimeExports.jsx(RankSquare, { rank: rank2, title: heading5, size, change: change2, allowSnapshotDelta: true }) });
}
'@

$NewReasonBox = @'
function ReasonBox({ reason, animation }) {/*LMU-RANK-PERCENT*/
  const { t: t2 } = useTranslation();
  function getImpactText() {
    switch (reason.impact) {
      case 1:
      case -1:
        return t2("Low");
      case 2:
      case -2:
        return t2("Mid");
      case 3:
      case -3:
        return t2("High");
      default:
        return t2("Zero");
    }
  }
  function formatReasonPct() {
    const direct = reason.change != null ? reason.change : reason.delta != null ? reason.delta : reason.percentage != null ? reason.percentage : reason.percent;
    if (direct != null && Number.isFinite(Number(direct)) && Number(direct) !== 0) {
      const rounded = Math.round(Number(direct) * 10) / 10;
      return (rounded > 0 ? "+" : "") + rounded.toFixed(1) + "%";
    }
    return null;
  }
  const reasonPct = formatReasonPct();
  return /* @__PURE__ */ jsxRuntimeExports.jsx(
    "div",
    {
      className: getClassName(classes$1B.reasonBox, classes$1B.enterAnimation),
      style: animation ? {
        "--reason-box-enter-delay": `${animation.index * 0.6 + animation.initialDelay}s`
      } : void 0,
      onAnimationEnd: (e2) => {
        var _a2;
        const elem = e2.target;
        const scrollContainer = (_a2 = elem.parentElement) == null ? void 0 : _a2.parentElement;
        if (scrollContainer) {
          scrollIntoViewBottom(elem, scrollContainer);
        }
      },
      children: /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: classes$1B.reasonContent, children: /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: classes$1B.reasonText, children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("p", { cohinline: "", children: reason.reason }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs(
          "div",
          {
            className: getClassName(classes$1B.impact, {
              [classes$1B.green]: reason.impact ? reason.impact > 0 : false,
              [classes$1B.red]: reason.impact ? reason.impact < 0 : false
            }),
            children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("span", { children: t2("Impact") }),
              /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: classes$1B.impactValue, children: [
                getImpactText(),
                /* @__PURE__ */ jsxRuntimeExports.jsx(ImpactIcon, { reason, className: classes$1B.impactIcon }),
                reasonPct && /* @__PURE__ */ jsxRuntimeExports.jsx("span", {
                  style: {
                    marginLeft: "0.4rem",
                    fontWeight: 700,
                    color: reason.impact > 0 ? "#1eff6b" : reason.impact < 0 ? "#ff1e44" : "#fff"
                  },
                  children: reasonPct
                })
              ] })
            ]
          }
        )
      ] }) })
    }
  );
}
'@

$NewRankBreakdown = @'
function RankBreakdown({
  currentDriver,
  results: results2,
  drReasons,
  srReasons,
  steamId,
  userId,
  className
}) {/*LMU-RANK-PERCENT*/
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: getClassName(classes$1z.rankBreakdown, className), children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$1z.rankSection, children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        RankCard,
        {
          className: classes$1z.rankCard,
          currentDriver,
          results: results2,
          steamId,
          nkId: userId,
          type: "dr",
          size: "small",
          reasons: drReasons
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        RankReasons,
        {
          reasons: drReasons,
          animation: {
            initialDelay: 0
          }
        }
      )
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$1z.rankSection, children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        RankCard,
        {
          className: classes$1z.rankCard,
          currentDriver,
          results: results2,
          steamId,
          nkId: userId,
          type: "sr",
          size: "small",
          reasons: srReasons
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        RankReasons,
        {
          reasons: srReasons,
          animation: {
            initialDelay: drReasons && drReasons.length > 0 ? drReasons.length * 0.7 : 0
          }
        }
      )
    ] })
  ] });
}
'@

function Patch-AppJs {
  param([string]$Js)
  if ($Js.Contains($Marker) -and -not $Force) {
    Write-Host "Already patched (marker found). Use -Force to re-apply from backup."
    return $null
  }

  $replacements = @(
    @{
      Pattern = 'function RankSquare\(\{[\s\S]*?\n\}\n(?=const eventJokerCardsOne)'
      Replacement = $NewRankSquare
      Name = "RankSquare"
    },
    @{
      Pattern = 'function RankCard\(\{[\s\S]*?\n\}\n(?=const impactIcon\$1)'
      Replacement = $NewRankCard
      Name = "RankCard"
    },
    @{
      Pattern = 'function ReasonBox\(\{[\s\S]*?\n\}\n(?=const rankReasons)'
      Replacement = $NewReasonBox
      Name = "ReasonBox"
    },
    @{
      Pattern = 'function RankBreakdown\(\{[\s\S]*?\n\}\n(?=const podiumDriverWithPointsUpdate)'
      Replacement = $NewRankBreakdown
      Name = "RankBreakdown"
    }
  )

  $patched = $Js
  foreach ($item in $replacements) {
    $match = [regex]::Match($patched, $item.Pattern)
    if (-not $match.Success) {
      throw "$($item.Name) function not found. Game UI may have changed — update this mod."
    }
    $patched = $patched.Remove($match.Index, $match.Length).Insert($match.Index, $item.Replacement)
  }
  return $patched
}

function Update-ZipEntry {
  param(
    [string]$ZipPath,
    [string]$EntryName,
    [byte[]]$Bytes
  )
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Update)
  try {
    $entry = $zip.GetEntry($EntryName)
    if (-not $entry) { throw "Zip entry missing: $EntryName" }
    $entry.Delete()
    $newEntry = $zip.CreateEntry($EntryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $stream = $newEntry.Open()
    try {
      $stream.Write($Bytes, 0, $Bytes.Length)
    } finally {
      $stream.Dispose()
    }
  } finally {
    $zip.Dispose()
  }
}

Write-Host "LMU Rank Percent mod"
Write-Host "Close Le Mans Ultimate before installing."

$lmu = Find-LmuRoot -Hint $GameRoot
$uiZip = Join-Path $lmu "Bin\UI.zip"
Write-Host "Game: $lmu"

if (Get-Process -Name "Le Mans Ultimate","LeMansUltimate","rFactor2" -ErrorAction SilentlyContinue) {
  throw "LMU appears to be running. Close it, then run install again."
}

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$jsName = $null
$jsText = $null
$zip = [System.IO.Compression.ZipFile]::OpenRead($uiZip)
try {
  $candidates = @($zip.Entries | Where-Object {
    ($_.FullName -replace '\\', '/') -like "start/assets/app-*.js" -and
    ($_.FullName -replace '\\', '/') -notlike "*.map"
  })
  foreach ($entry in $candidates) {
    $sr = New-Object System.IO.StreamReader($entry.Open())
    try {
      $text = $sr.ReadToEnd()
    } finally {
      $sr.Dispose()
    }
    if ($text.Contains("function RankSquare({")) {
      $jsName = $entry.FullName
      $jsText = $text
      break
    }
  }
  if (-not $jsName) { throw "Could not find app JS with RankSquare inside UI.zip." }
  Write-Host "Patching entry: $jsName ($([math]::Round($jsText.Length/1MB,1)) MB)"
} finally {
  $zip.Dispose()
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$backupJs = Join-Path $BackupDir (($jsName -replace '[\\/]', '_') + ".bak")
if (-not (Test-Path $backupJs)) {
  if ($jsText.Contains($Marker)) {
    throw "UI.zip is already patched and no clean backup exists. Restore via Steam Verify, then re-run install."
  }
  [System.IO.File]::WriteAllText($backupJs, $jsText, $utf8NoBom)
  Write-Host "Backup: $backupJs"
} else {
  Write-Host "Backup already exists, keeping original."
}

if ($Force) {
  Write-Host "Force: patching from clean backup."
  $jsText = [System.IO.File]::ReadAllText($backupJs, $utf8NoBom)
}

@{
  gameRoot = $lmu
  uiZip = $uiZip
  jsEntry = $jsName
  installedAt = (Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content -Path (Join-Path $BackupDir "install-meta.json") -Encoding UTF8

$patched = Patch-AppJs -Js $jsText
if ($null -eq $patched) {
  Write-Host "Nothing to do."
  exit 0
}

if ($WhatIf) {
  Write-Host "WhatIf: patch OK ($($patched.Length) chars). Not writing UI.zip."
  exit 0
}

$bytes = $utf8NoBom.GetBytes($patched)
Write-Host "Writing patched JS into UI.zip (may take a few minutes for a ~1 GB archive)..."
Update-ZipEntry -ZipPath $uiZip -EntryName $jsName -Bytes $bytes

Write-Host ""
Write-Host "Installed."
Write-Host "1. Launch LMU"
Write-Host "2. Open Profile — rank badges should show e.g. 42%"
Write-Host "3. After an online race — post-race cards show +/- change (e.g. +3.1%)"
Write-Host "Uninstall: .\uninstall.ps1"
