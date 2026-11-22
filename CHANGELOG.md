# Changelog

All notable changes of this fork are listed here. The history of the original
GunGame:SM (1.2.16 and before) is in [doc/CHANGELOG.txt](doc/CHANGELOG.txt).

## 2.0.0

Fork of [altexdim/sourcemod-plugin-gungame](https://github.com/altexdim/sourcemod-plugin-gungame)
(GunGame:SM 1.2.16 by teame06, Liam and the Otstrel.ru Team), modernized for SourceMod 1.12/1.13 x64.

### Changed

- Every plugin uses `#pragma newdecls required`, new declarations and methodmaps
  (`ConVar`, `KeyValues`, `StringMap`, `DataPack`, `Panel`, `Menu`, `SMCParser`,
  `GlobalForward`, `Database`, `Transaction`), and `delete` for handles.
- Counter-Strike: Source only. CS:GO code paths (taser, molotov, CS:GO knife slot,
  CS:GO sounds and round end cvars, `cfg/gungame/csgo/`) are removed. The CS:GO-only
  config keys (`MolotovBonus*`, `ExtraMolotovOnKnifeKill`, `ExtraTaserOnKnifeKill`) are ignored.
- SDKHooks is always used: the separate `gungame_sdkhooks.smx` build is gone.
- Entity data is read and written with `GetEntProp`/`SetEntProp` instead of raw offsets
  (`m_ArmorValue`, `m_bHasHelmet`, `m_bHasDefuser`, `m_iAmmo`, `m_flLaggedMovementValue`),
  hostages are removed by class name: no x86-only offset arithmetic left.
- Timers carry user ids and entity references instead of client and entity indexes.
- Steam ids come from `GetClientAuthId(AuthId_Steam2)` (same `STEAM_0:X:Y` format as before,
  existing stats databases keep working).
- Colors come from [MultiColors](https://github.com/srcdslab/sm-plugin-MultiColors)
  instead of the bundled `colors.inc`.
- Translation files are renamed `*.phrases.txt`.
- Config and exec paths use `/` instead of `\`.
- gungame_stats: every query is asynchronous (`Database.Connect`, threaded queries and
  transactions); no more `SQL_Query`/`SQL_FastQuery`/`SQL_LockDatabase` on the game thread.
  A win is saved with an atomic `wins = wins + 1` update followed by an insert when the
  player has no row yet, then read back, so a win is never lost or duplicated.
  `GG_GetPlayerPlaceInStat` returns a cached place, refreshed when the wins are loaded and
  before `GG_OnLoadRank`. New SQLite indexes are named `gg_playerdata_*` (the database file
  is shared with other plugins).

### Added

- API for companion plugins (see `gungame.inc`): `GG_OnClientLevelChanged` (old level, new
  level, weapon, reason), `GG_OnKnifeSteal`, `GG_OnMatchStart`, `GG_GetRanking`,
  `GG_GetClientKills`, `GG_GetWinner`, `GG_GetLeader`, `GG_IsMatchStarted`, `GG_IsFFA`.
  The existing `GG_IsClientCurrentWeapon` native and `GG_OnDisableRtv` forward are now
  declared in the include, and every include marks its natives optional when the
  dependency is optional.
- FFA mode (`"FFA" "1"`) also keeps `mp_friendlyfire` untouched (`AutoFriendlyFire` and
  `EnableFriendlyFireLevel` are ignored), gungame_tk never punishes and gungame_logging
  skips the team win/lose events.
- `SelfKillProtection` also blocks the `explode` command.
- CI: build with SourceMod 1.12 and 1.13.0.7427 (warnings are errors), translation check,
  `latest` release on push to `main`.

### Fixed

- gungame_config: the `GG_ConfigParseEnd` forward was registered as `GG_COnfigParseEnd`
  and never called.
- gungame_stats: SQLite prune compared a text timestamp with a unix time and never
  removed anyone.
- gungame_stats: the top menu page count used a float retag of integers.
- `!rules`: the first two rules were shown on every page.
- `GG_SetWeaponLevel`/`GG_SetWeaponLevelByName` stored `weapon_xxx` instead of the short
  weapon name.
- The knife steal minimum level message showed the 0-based level.
- gungame_bot: the last client slot was ignored when counting humans.
- gungame_afk: bots are never treated as AFK.
- Objective events were never unhooked at map end.
- Duplicate `pt` phrase in `gungame.phrases.txt` (it was the Spanish one).
