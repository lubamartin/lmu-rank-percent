#Requires -Version 5.1
<#
.SYNOPSIS
  Restores Driver/Safety Rank percentages in Le Mans Ultimate UI.

.DESCRIPTION
  Patches RankSquare + RankCard + StandingsPanel inside Bin\UI.zip so the game shows:
  - current progress % on every rank badge (profile, menus, post-race)
  - post-race +/- % change from drChange / srChange
  - Standings DR badge + approximate Elo % change (toggleable, default on)

  Rank badges use local game values. Standings DR uses RaceOS player lookup
  (same API the UI already uses for online profiles) plus a doX-style Elo estimate.
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

$NewStandingsPanelHeader = @'
function StandingsPanelHeader({
  mode,
  onClickMode,
  onToggleSection,
  section,
  sessionInfo: sessionInfo2
}) {/*LMU-RANK-PERCENT*/
  const { t: t2 } = useTranslation();
  const sectionButtons = [
    {
      key: "rank",
      label: "DR/SR",
      isActive: section.rank !== false,
      shouldInsert: true
    },
    {
      key: "timing",
      label: t2("Timing"),
      isActive: section.timing,
      shouldInsert: true
    },
    {
      key: "ve",
      label: t2("VE"),
      isActive: section.ve,
      shouldInsert: sessionInfo2.isRaceSession()
    }
  ];
  const modeButtons2 = [
    {
      key: "drivers",
      label: t2("Drivers")
    },
    {
      key: "teams",
      label: t2("Teams")
    }
  ];
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(
    "div",
    {
      className: getClassName(classes$5z.standingsPanelHeader, {
        [classes$5z.expanded]: !!(section.timing || section.ve)
      }),
      children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$5z.left, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: getClassName(classes$5z.pos, classes$5z.header), children: t2("Pos") }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(
            "div",
            {
              className: getClassName(classes$5z.toggleButtons, classes$5z.modeButtons),
              children: modeButtons2.map((mb2, i2) => /* @__PURE__ */ jsxRuntimeExports.jsx(
                Button,
                {
                  type: "text",
                  onClick: () => onClickMode(mb2.key),
                  className: getClassName(classes$5z.toggleButton, {
                    [classes$5z.active]: mb2.key === mode
                  }),
                  children: mb2.label
                },
                i2
              ))
            }
          ),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Spacer, {}),
          /* @__PURE__ */ jsxRuntimeExports.jsx(
            "div",
            {
              className: getClassName(
                classes$5z.toggleButtons,
                classes$5z.sectionButtons
              ),
              children: sectionButtons.map(
                (section2, i2) => section2.shouldInsert ? /* @__PURE__ */ jsxRuntimeExports.jsx(
                  Button,
                  {
                    type: "text",
                    onClick: () => onToggleSection(section2.key),
                    className: getClassName(classes$5z.toggleButton, {
                      [classes$5z.active]: section2.isActive
                    }),
                    children: section2.label
                  },
                  i2
                ) : null
              )
            }
          )
        ] }),
        section.timing && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$5z.timingHeaders, children: [
          sessionInfo2.isRaceSession() && /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: getClassName(classes$5z.header, columnClasses.time), children: t2("Int") }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: getClassName(classes$5z.header, columnClasses.time), children: "S1" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: getClassName(classes$5z.header, columnClasses.time), children: "S2" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: getClassName(classes$5z.header, columnClasses.time), children: "S3" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: getClassName(classes$5z.header, columnClasses.time), children: t2("Lap") }),
          sessionInfo2.isRaceSession() && /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(
              "span",
              {
                className: getClassName(classes$5z.header, columnClasses.gain),
                children: t2("Gain")
              }
            ),
            /* @__PURE__ */ jsxRuntimeExports.jsx(
              "span",
              {
                className: getClassName(classes$5z.header, columnClasses.time),
                children: t2("Last 5 Avg")
              }
            )
          ] })
        ] }),
        section.ve && sessionInfo2.isRaceSession() && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: columnClasses.veWrapper, children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: classes$5z.header, children: t2("Last") }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: classes$5z.header, children: t2("5 Lap") }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: classes$5z.header, children: t2("Avg") })
        ] })
      ]
    }
  );
}
'@

$NewStandingsPanelTable = @'
function StandingsPanelTable({
  classLiveStandings,
  mode,
  section,
  sessionInfo: sessionInfo2
}) {/*LMU-RANK-PERCENT*/
  var _a2;
  const displayedEntries = classLiveStandings.entries;
  const { isTeamEvent, multiplayerTeams } = useTeamEvent();
  const { data: customCars } = useQuery(
    allAvailableVehiclesOptions("LiveryEditor")
  );
  const onlineProfiles = useOnlineProfiles();
  const showRank = section.rank !== false;
  const scrollFocusedSlotIntoView = reactExports.useCallback((node2) => {
    node2.querySelector(`.${classes$5x.row}[data-has-focus="true"]`);
  }, []);
  const { hasScrollbar: hasScrollbar2, callbackRef, nodeRef } = useHasScrollbar();
  const focusedSlotId = (_a2 = classLiveStandings.data.find(
    (entry2) => entry2.slotHasFocus
  )) == null ? void 0 : _a2.slotID;
  reactExports.useEffect(() => {
    if (focusedSlotId != void 0 && nodeRef.current) {
      scrollFocusedSlotIntoView(nodeRef.current);
    }
  }, [focusedSlotId, nodeRef, scrollFocusedSlotIntoView]);
  function lmuRpNormProgress(progress) {
    if (typeof progress !== "number" || !Number.isFinite(progress) || progress < 0) {
      return 0;
    }
    let value2 = progress;
    if (value2 > 0 && value2 <= 1) {
      value2 *= 100;
    }
    return Math.max(0, Math.min(100, value2));
  }
  function lmuRpVisualScore(rankName, tier2, progress) {
    const rankIndex = { Bronze: 0, Silver: 1, Gold: 2, Platinum: 3 }[rankName];
    if (rankIndex === void 0) {
      return void 0;
    }
    let level = typeof tier2 === "number" && Number.isFinite(tier2) ? Math.trunc(tier2) : 0;
    if (rankIndex === 0) {
      level = Math.max(0, Math.min(3, level));
    } else {
      level = Math.max(1, Math.min(3, level));
    }
    const pct2 = lmuRpNormProgress(progress);
    const score = rankIndex === 0 ? level + pct2 / 100 : 4 + (rankIndex - 1) * 3 + (level - 1) + pct2 / 100;
    const visual = score * 100;
    return visual > 0 && Number.isFinite(visual) ? visual : void 0;
  }
  function lmuRpFindProfile(driverName2) {
    if (!onlineProfiles || !driverName2) {
      return void 0;
    }
    const exact = onlineProfiles.find((p2) => p2.username === driverName2);
    if (exact) {
      return exact;
    }
    const lower = String(driverName2).trim().toLowerCase();
    return onlineProfiles.find((p2) => {
      var _a3, _b;
      return String(((_a3 = p2.username) != null ? _a3 : "")).trim().toLowerCase() === lower || String(((_b = p2.name) != null ? _b : "")).trim().toLowerCase() === lower;
    });
  }
  function lmuRpCalcGains(entries) {
    const INTERNAL_SCALE = 3;
    const QUALY_WEIGHT = 0.17647058823529413;
    const K = 30;
    const D = 420;
    const LOG = 10;
    const usable = [];
    for (const entry2 of entries) {
      const profile = lmuRpFindProfile(entry2.driverName);
      const dr = profile == null ? void 0 : profile.driverRank;
      const visual = lmuRpVisualScore(dr == null ? void 0 : dr.rank, dr == null ? void 0 : dr.tier, dr == null ? void 0 : dr.progress);
      const racePosition = classLiveStandings.findPositionInClass(entry2);
      if (!(racePosition > 0) || visual === void 0) {
        continue;
      }
      const qualiPosition = classLiveStandings.findQualiPositionInClass(entry2);
      usable.push({
        slotID: entry2.slotID,
        racePosition,
        qualiPosition: qualiPosition > 0 ? qualiPosition : 0,
        visualScore: visual
      });
    }
    const gains = /* @__PURE__ */ new Map();
    if (usable.length < 2) {
      return gains;
    }
    const scale = K / (2 * (usable.length - 1));
    const internals = usable.map((e2) => e2.visualScore * INTERNAL_SCALE);
    for (let i2 = 0; i2 < usable.length; i2++) {
      let raceDelta = 0;
      let qualiDelta = 0;
      for (let j2 = 0; j2 < usable.length; j2++) {
        if (i2 === j2) {
          continue;
        }
        const expected = 1 / (1 + Math.pow(LOG, (internals[j2] - internals[i2]) / D));
        const mine = usable[i2];
        const other = usable[j2];
        const head = mine.racePosition < other.racePosition ? 1 : mine.racePosition > other.racePosition ? 0 : 0.5;
        raceDelta += head - expected;
        if (mine.qualiPosition > 0 && other.qualiPosition > 0) {
          const qHead = mine.qualiPosition < other.qualiPosition ? 1 : mine.qualiPosition > other.qualiPosition ? 0 : 0.5;
          qualiDelta += qHead - expected;
        }
      }
      let gain = scale * (raceDelta + QUALY_WEIGHT * qualiDelta);
      if (!Number.isFinite(gain)) {
        gain = 0;
      }
      gains.set(usable[i2].slotID, Math.round(gain * 10) / 10);
    }
    return gains;
  }
  const rankGains = showRank ? lmuRpCalcGains(displayedEntries) : /* @__PURE__ */ new Map();
  function displayTyreColumn(entry2) {
    return /* @__PURE__ */ jsxRuntimeExports.jsx(
      TyreCompoundIndicator,
      {
        tyres: [
          {
            compound: entry2.tyreCompound("fl"),
            status: "new"
          },
          {
            compound: entry2.tyreCompound("fr"),
            status: "new"
          },
          {
            compound: entry2.tyreCompound("rl"),
            status: "new"
          },
          {
            compound: entry2.tyreCompound("rr"),
            status: "new"
          }
        ]
      }
    );
  }
  const rankColStyle = {
    width: "11.8rem",
    minWidth: "11.8rem",
    maxWidth: "11.8rem",
    flexShrink: 0,
    display: "flex",
    alignItems: "center",
    gap: "0.35rem",
    fontSize: "0.72rem",
    lineHeight: 1,
    height: "1.4rem",
    whiteSpace: "nowrap",
    marginRight: "0.25rem",
    fontVariantNumeric: "tabular-nums"
  };
  const badgeBoxStyle = {
    width: "2rem",
    height: "1.05rem",
    minWidth: "2rem",
    flexShrink: 0,
    display: "flex",
    alignItems: "center",
    justifyContent: "center"
  };
  const badgeImgStyle = {
    width: "2rem",
    height: "1.05rem",
    objectFit: "fill",
    display: "block"
  };
  const drSlotStyle = {
    display: "flex",
    alignItems: "center",
    gap: "0.18rem",
    width: "7.2rem",
    minWidth: "7.2rem",
    flexShrink: 0
  };
  const srSlotStyle = {
    display: "flex",
    alignItems: "center",
    gap: "0.18rem",
    width: "4.2rem",
    minWidth: "4.2rem",
    flexShrink: 0
  };
  const pctCellStyle = {
    width: "2rem",
    minWidth: "2rem",
    textAlign: "right",
    flexShrink: 0
  };
  const gainCellStyle = {
    width: "2.6rem",
    minWidth: "2.6rem",
    textAlign: "right",
    flexShrink: 0
  };
  function formatRankGain(gain) {
    if (gain == null || !Number.isFinite(gain)) {
      return "";
    }
    const rounded = Math.round(gain * 10) / 10;
    const body = Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
    return (rounded > 0 ? "+" : "") + body + "%";
  }
  function rankBadgeUrl(kind, rankObj) {
    if (!(rankObj == null ? void 0 : rankObj.rank) || rankObj.tier === void 0 || rankObj.tier === null) {
      return null;
    }
    const folder = kind === "dr" ? "dr-lmu" : "sr-lmu";
    return "https://rf2-ui-images-prod.s3.eu-west-1.amazonaws.com/ranks/" + folder + "/" + rankObj.rank + rankObj.tier + "-small.svg";
  }
  function renderEqualBadge(kind, rankObj) {
    const url = rankBadgeUrl(kind, rankObj);
    return /* @__PURE__ */ jsxRuntimeExports.jsx("div", { style: badgeBoxStyle, children: url ? /* @__PURE__ */ jsxRuntimeExports.jsx("img", { src: url, alt: "", style: badgeImgStyle }) : null });
  }
  function renderRankColumn(entry2) {
    var _a3, _b;
    if (!showRank) {
      return null;
    }
    const profile = lmuRpFindProfile(entry2.driverName);
    const dr = profile == null ? void 0 : profile.driverRank;
    const sr = profile == null ? void 0 : profile.safetyRank;
    const hasAny = !!(dr == null ? void 0 : dr.rank) || !!(sr == null ? void 0 : sr.rank);
    const drPct = (dr == null ? void 0 : dr.rank) ? Math.round(lmuRpNormProgress(dr.progress)) + "%" : "";
    const srPct = (sr == null ? void 0 : sr.rank) ? Math.round(lmuRpNormProgress(sr.progress)) + "%" : "";
    const gain = rankGains.get(entry2.slotID);
    const gainText = formatRankGain(gain);
    const gainColor = gainText ? gain > 0 ? "#3DDC97" : gain < 0 ? "#FF6B6B" : "#C8C8C8" : "transparent";
    const tip = [
      (dr == null ? void 0 : dr.rank) ? "DR " + dr.rank + (((_a3 = dr.tier) != null ? _a3 : "") !== "" ? dr.tier : "") + " " + drPct + (gainText ? " " + gainText : "") : null,
      (sr == null ? void 0 : sr.rank) ? "SR " + sr.rank + (((_b = sr.tier) != null ? _b : "") !== "" ? sr.tier : "") + " " + srPct : null
    ].filter(Boolean).join(" · ");
    return /* @__PURE__ */ jsxRuntimeExports.jsxs(
      "div",
      {
        style: __spreadProps(__spreadValues({}, rankColStyle), { opacity: hasAny ? 1 : 0.45 }),
        title: tip,
        children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { style: drSlotStyle, children: [
            renderEqualBadge("dr", dr),
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { style: pctCellStyle, children: drPct }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { style: __spreadProps(__spreadValues({}, gainCellStyle), { color: gainColor }), children: gainText || "\xA0" })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { style: srSlotStyle, children: [
            renderEqualBadge("sr", sr),
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { style: pctCellStyle, children: srPct })
          ] })
        ]
      }
    );
  }
  function renderRow(entry2, isFirstRow) {
    return /* @__PURE__ */ jsxRuntimeExports.jsxs(
      StandingsPanelTableRow,
      {
        entry: entry2,
        className: getClassName({
          [classes$5x.firstRow]: isFirstRow
        }),
        children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$5x.leftBackgroundWrapper, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$5x.left, children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: classes$5y.posColumn, children: classLiveStandings.displayPositionInClass(entry2) }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: classes$5y.logoColumn, children: /* @__PURE__ */ jsxRuntimeExports.jsx(
                "img",
                {
                  src: getLogoUrl(
                    entry2,
                    customCars,
                    classLiveStandings,
                    isTeamEvent,
                    multiplayerTeams
                  ),
                  alt: ""
                }
              ) }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: classes$5y.numberColumn, children: entry2.vehicleNumber }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: classes$5y.nameColumn, style: showRank ? { minWidth: 0, maxWidth: "5.8rem" } : void 0, children: /* @__PURE__ */ jsxRuntimeExports.jsx(TextScroll, { text: displayNameColumn(entry2, mode) }) }),
              renderRankColumn(entry2),
              /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: classes$5y.timeColumn, style: { flexShrink: 0 }, children: displayTimeColumn(
                entry2,
                sessionInfo2.isRaceSession(),
                classLiveStandings.entries[0]
              ) })
            ] }),
            section.timing && /* @__PURE__ */ jsxRuntimeExports.jsx(
              StandingsPanelTableTiming,
              {
                entry: entry2,
                classLiveStandings,
                isRaceSession: sessionInfo2.isRaceSession()
              }
            ),
            section.ve && /* @__PURE__ */ jsxRuntimeExports.jsx(StandingsPanelVe, { driverName: entry2.driverName })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$5x.rightBackgroundWrapper, children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: classes$5y.tyreColumn, children: displayTyreColumn(entry2) }),
            entry2.isVirtualEnergyVehicle() && /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$5y.virtualEnergyColumn, children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx(VirtualEnergyBar, { energy: entry2.virtualEnergy }),
              /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { children: [
                entry2.virtualEnergy.toFixed(),
                "%"
              ] })
            ] }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(
              "div",
              {
                className: getClassName(classes$5y.statusColumn, {
                  [classes$5y.penalty]: entry2.hasPenalty()
                }),
                children: entry2.displayStatus()
              }
            )
          ] })
        ]
      }
    );
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsxs(
    "div",
    {
      className: getClassName(classes$5x.standingsPanelTable, {
        [classes$5x.hasScrollbar]: hasScrollbar2
      }),
      children: [
        displayedEntries[0] && renderRow(displayedEntries[0], true),
        displayedEntries.length > 1 && /* @__PURE__ */ jsxRuntimeExports.jsx(ScrollArea, { ref: callbackRef, className: classes$5x.scrollWrapper, children: displayedEntries.slice(1).map((entry2) => /* @__PURE__ */ jsxRuntimeExports.jsx(reactExports.Fragment, { children: renderRow(entry2, false) }, entry2.slotID)) })
      ]
    }
  );
}
'@

$NewStandingsPanel = @'
function StandingsPanel({
  classLiveStandings,
  mainState,
  sessionInfo: sessionInfo2,
  sessionGameState
}) {/*LMU-RANK-PERCENT*/
  var _a2;
  const { standingsPanelConfig: config, setStandingsPanelConfig: setConfig } = useWatchTabsContext();
  const isLoadedReplay = ((_a2 = mainState.state) == null ? void 0 : _a2.settingMode) === "SETTING_REPLAY_PLAYBACK";
  const showRank = config.section.rank !== false;
  function onToggleSection(sectionKey) {
    const current = config.section[sectionKey];
    const next = sectionKey === "rank" ? current === false : !current;
    if (sectionKey === "rank") {
      try {
        localStorage.setItem("lmu-rp:standings-rank", next ? "1" : "0");
      } catch (e2) {
      }
    }
    setConfig(__spreadProps(__spreadValues({}, config), {
      section: __spreadProps(__spreadValues({}, config.section), {
        [sectionKey]: next
      })
    }));
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("article", { className: classes$5y.standingsPanel, style: showRank ? { "--left-width": "29.5rem" } : void 0, children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: classes$5y.sessionInfo, children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: classes$5y.sessionName, children: sessionInfo2 == null ? void 0 : sessionInfo2.displaySessionName() }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: classes$5y.sessionTime, children: classLiveStandings && sessionGameState ? classLiveStandings.displaySessionRemaining(
        mainState,
        sessionGameState.gamePhase
      ) : "-" })
    ] }),
    classLiveStandings && sessionInfo2 && /* @__PURE__ */ jsxRuntimeExports.jsxs(jsxRuntimeExports.Fragment, { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        StandingsPanelHeader,
        {
          mode: config.mode,
          onClickMode: (mode) => setConfig(__spreadProps(__spreadValues({}, config), {
            mode
          })),
          onToggleSection,
          section: config.section,
          sessionInfo: sessionInfo2
        }
      ),
      /* @__PURE__ */ jsxRuntimeExports.jsx(
        StandingsPanelTable,
        {
          classLiveStandings,
          mode: config.mode,
          section: config.section,
          sessionInfo: sessionInfo2,
          isLoadedReplay
        }
      )
    ] })
  ] });
}
'@

$NewWatchTabsProvider = @'
function WatchTabsProvider({
  children
}) {/*LMU-RANK-PERCENT*/
  const [userToggledTabs, setUserToggledTabs] = reactExports.useState(null);
  const [tabsBeforeStints, setTabsBeforeStints] = reactExports.useState(null);
  const [standingsPanelConfig, setStandingsPanelConfig] = reactExports.useState(() => {
    let rankOn = true;
    try {
      const stored = localStorage.getItem("lmu-rp:standings-rank");
      if (stored !== null) {
        rankOn = stored !== "0";
      }
    } catch (e2) {
    }
    return {
      mode: "drivers",
      section: {
        timing: false,
        ve: false,
        rank: rankOn
      }
    };
  });
  return /* @__PURE__ */ jsxRuntimeExports.jsx(
    WatchTabsContext.Provider,
    {
      value: {
        userToggledTabs,
        setUserToggledTabs,
        tabsBeforeStints,
        setTabsBeforeStints,
        standingsPanelConfig,
        setStandingsPanelConfig
      },
      children
    }
  );
}
'@

function Patch-AppJs {
  param([string]$Js)
  if ($Js.Contains($Marker) -and -not $Force) {
    Write-Host "Already patched (marker found). Use -Force to re-apply from backup."
    return $null
  }

  $patched = $Js

  $sectionDefault = [regex]::Replace(
    $patched,
    'section: \{\r?\n      timing: false,\r?\n      ve: false\r?\n    \}',
    "section: {`n      timing: false,`n      ve: false,`n      rank: true`n    }",
    1
  )
  if ($sectionDefault -eq $patched) {
    throw "standingsPanelConfig section default not found. Game UI may have changed — update this mod."
  }
  $patched = $sectionDefault

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
    },
    @{
      Pattern = 'function WatchTabsProvider\(\{[\s\S]*?\n\}\n(?=const GameStateContext)'
      Replacement = $NewWatchTabsProvider
      Name = "WatchTabsProvider"
    },
    @{
      Pattern = 'function StandingsPanelHeader\(\{[\s\S]*?\n\}\n(?=const standingsPanel =)'
      Replacement = $NewStandingsPanelHeader
      Name = "StandingsPanelHeader"
    },
    @{
      Pattern = 'function StandingsPanelTable\(\{[\s\S]*?\n\}\n(?=function StandingsPanel\()'
      Replacement = $NewStandingsPanelTable
      Name = "StandingsPanelTable"
    },
    @{
      Pattern = 'function StandingsPanel\(\{[\s\S]*?\n\}\n(?=const eventWatchView)'
      Replacement = $NewStandingsPanel
      Name = "StandingsPanel"
    }
  )

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
Write-Host "4. Standings panel — DR/SR column on by default (header button DR/SR toggles both)"
Write-Host "Uninstall: .\uninstall.ps1"
