# Changelog

All notable changes of this fork are listed here. The history of the original
GunGame:SM (1.2.16 and before) is in [doc/CHANGELOG.txt](doc/CHANGELOG.txt).

## 2.0.7

### Fixed

- When the leader disconnected, the leader was recalculated while the leaving player still held his
  level, so nobody led any more and the next player gaining any level was announced as the leader.
  The lead now goes to the best remaining player, also when the leader moves to spectator (#9).
- `GG_OnLeaderChange` got the old leader's new level instead of the new leader's level (#9).
- Handicap level raises recalculate the leader (#9).
- Spectators and unassigned players can no longer be the leader (#9).

## 2.0.6

### Fixed

- `GG_OnClientLevelChange` fired for level changes that did not happen: a level 1 player losing
  a level (knife stolen, suicide, team kill) and a bot on the last level while bots cannot win.
  gungame_logging logged fake `gg_leveldown` / `gg_levelup` / `gg_knife_level` events for HLstatsX,
  the player's points were reset and the level-down sound played. The forward now gets the real
  difference after clamping (losing 3 levels from level 2 logs 1 event) (#8).
- No out-of-bounds read of the weapon order on the winning kill with a 64-level weapon order (#8).

## 2.0.5

### Fixed

- gungame_afk: AFK players were never detected with a deathmatch plugin, which teleports players to
  a random spawn point after `player_spawn` (the saved spawn position never matched). A player is
  now AFK when he gave no input at all (movement, attack, jump, duck, use, mouse) between his spawn
  and his death; deaths less than 5 s after the spawn never count (#7).

## 2.0.4

### Fixed

- gungame_bot: the "no level up on bots with the knife / grenade while another human plays" rule
  counted teammates. In team mode two humans in the same team could never pass the knife or
  grenade level on bots. Only humans the killer can score on count now (the other team, or
  everyone in FFA) (#6).

## 2.0.3

### Fixed

- `UnlimitedNadesMinPlayers` turned `UnlimitedNades` off at every team change when both teams had
  more players than the limit, even with `"UnlimitedNades" "1"`: no new grenade after a throw on the
  grenade level. As documented in `gungame.config.txt`, it now only turns unlimited nades on.

## 2.0.2

### Added

- `BlockWeaponPickup` config key (default `0`): players can only pick up the weapons GunGame
  gives them and the knife. Weapons dropped by other players or placed by the map (fy/aim maps)
  stay on the ground. The game's default spawn items still go through (GunGame strips them).

## 2.0.1

### Fixed

- Chat messages no longer end with a color tag (`{green}` after the last value). On CS:S a
  color code with no text after it is printed as raw hex, for example
  `Coco is tied with the leader on level 53EFF3E` (`gungame.phrases.txt`, `gungame_tk.phrases.txt`).

### Documentation

- README: with a deathmatch respawn plugin, `TurboMode` must be `1`, otherwise the next weapon
  is only given at the next spawn.

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

- gungame_logging: a level down logged one `gg_leveldown` event too many (2 for 1 level),
  so stats plugins (HLstatsX) counted every level lost twice.
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
