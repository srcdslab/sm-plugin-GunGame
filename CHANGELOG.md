# Changelog

All notable changes of this fork are listed here. The history of the original
GunGame:SM (1.2.16 and before) is in [doc/CHANGELOG.txt](doc/CHANGELOG.txt).

## 2.0.18

### Fixed

- `"RandomWeaponOrder" "0"` logged `WeaponOrder: invalid level "RandomWeaponOrder"` at every map
  change (regression of 2.0.12, found on the NiDE server) (#14).

## 2.0.17

### Added

- Every phrase in 13 languages: en, fr, de, es, pt, ru, chi, pl, tr, it, ua, zho, cze (fr, chi, tr,
  it, ua, zho and cze are new; de completed and reviewed; pt rewritten in Brazilian Portuguese,
  which is what SourceMod's `pt` means) (#19).
- `gg_status` tells whether the warmup runs and who leads on which level (it replied
  "Currently not implmented") (#19).

### Fixed

- Polish plural forms (seconds, levels, kills, times, wins) and several wrong Polish sentences;
  German team kill and suicide lines; Spanish "Victoris" (#19).
- The AFK kick reason is translated (#19).
- Color tags are stripped from hint boxes and the winner dialog, which show them literally; the
  winner dialog buffer fits long UTF-8 names (#19).

## 2.0.16

### Fixed

- `gungame.mapconfig.cfg` could be skipped on the first map after a server start (it depended on
  the plugin load order); it now runs when the config is read, before the warmup configs (#18).
- gungame_warmup_configs and gungame_mapvoting append their `exec` (`ServerCommand`): with
  `InsertServerCommand` the warmup start config ran before configs queued earlier, which then
  overrode it (#18).
- Unloading gungame.smx mid-map gives the buy zones back (#18).
- gungame_stats and gungame_afk reloaded mid-map start again instead of staying off until the next
  map; README: reload GunGame itself with a map change (#18).

## 2.0.15

### Fixed

- The winner's rank (`ShowPlayerRankOnWin`) and MOTD were never shown when the win was not saved
  (`DontAddWinsOnBot` and a bot victim, no database, failed save): gungame_stats now always fires
  `GG_OnLoadRank` after a win, and gungame_display_winner shows them after 5 s at the latest (#17).
- Winner MOTD: the loser is the victim of the winning kill (it could be a stale name), names are cut
  to 32 bytes on a character boundary, a URL over 240 bytes is not sent (CS:S drops it) and logged,
  and the default `DisplayWinnerUrl` is empty instead of a third-party http site (#17).
- gungame_winner_effects stored the winner's client index: a player joining in his slot after he
  left got the winner glow (#17).

## 2.0.14

### Fixed

- gungame_stats: rank data (total winners, top rank threshold, places) is reloaded after the
  end-of-map prune deleted players (#16).
- `!top` numbered tied players 3, 4 while `!rank` said both were 3rd: the top panel now shows the
  same shared place (#16).
- The database handle was used before the players table existed on a fresh database; a failed table
  creation left every later query failing (#16).
- Names with emoji (4-byte UTF-8) made the save fail on a MySQL utf8 table and the win was lost:
  those characters are removed from the stored name (#16).

## 2.0.13

### Fixed

- `GG_SetMaxLevel` recomputes the `!weapons` panel pages and moves players above the new maximum to
  the new last level; the panel could read out of bounds with an empty weapon order (#15).
- `GG_SetWeaponLevel` / `GG_SetWeaponLevelByName` refuse levels that would leave a gap and extend
  the order when setting the next level (#15).
- `GG_RemoveLevelMulti` with a negative count added levels (`"TkLooseLevel" "-1"` rewarded team
  kills): it throws an error now (#15).
- `GG_AddALevel` counted refused level changes for `MaxLevelPerRound`; `GG_AddAPoint` returned 0
  ("levelled") when the level change was refused (#15).
- `GG_GiveHandicapLevel` threw on an empty slot; `GG_IsClientCurrentWeapon` accepts short names (#15).
- `level`, `leader`, `rules`, `score`, `weapons`, `commands` from the server console threw
  `Invalid client index [0]` (#15).
- Debug build only: `gungamesm_set_level` / `gungamesm_display` are root admin commands (#15).

## 2.0.12

### Fixed

- Empty config values (`"NadeBonus" ""`, `"WarmupWeapon" ""`, `"GameDesc" ""`, a sound set to `""`)
  were never passed on by gungame_config, so they could not reset what a map config had set on an
  earlier map (#14).
- `WeaponOrder` and `MultipleKillsPerLevel` sections now start from scratch: per-level kill counts,
  reserved random levels and weapon names of an earlier map no longer leak into the next maps.
  The level count is the highest level read, not the last one (#14).
- `RandomWeaponOrder` put kill counts on the wrong weapons (the shuffle did not match its map) (#14).
- `RandomWeaponReserveLevels`: no more out-of-bounds index for 0 or levels above 64, no truncated
  numbers, spaces allowed (#14).
- `WarmupRandomWeaponMode` 2 (every round) and 3 (every spawn) behaved like 1 (#14).
- `DisableRtvLevel`, `EnableFriendlyFireLevel` and `MaxHandicapLevel` set to `1` meant "disabled" (#14).
- Weapon order levels with no weapon or an unknown weapon are removed (logged) instead of leaving a
  level nobody can pass; weapon names are case-insensitive everywhere (#14).
- A missing or broken `weaponinfo.txt` stops the plugin with a clear error; config parse errors go to
  the error log with the line, and a config file that cannot be opened no longer keeps GunGame off
  for the whole map (#14).
- Sound lists can hold 32 sounds (#14).

## 2.0.11

### Fixed

- `gg_restart` after a win left the winner set: nobody could level up any more until the map
  changed. It now resets the whole match state: winner, levels, points, leader, per-round and
  multi-level counters, grenade level state, the vote / disable RTV / friendly fire level triggers
  (friendly fire is set back), the reconnect levels and the handicap counters (#13).
- When the winner left during the end of the game, the next player in his slot was ranked first
  by `GG_GetRanking` and decided the round end team (#13).

## 2.0.10

### Fixed

- `HandicapUpdate` raised spectators, unassigned players and SourceTV, and ignored
  `HandicapTimesPerMap` (#12).
- `HandicapUseSpectators 1` had no effect; SourceTV never counts in the handicap level (#12).
- `RestoreLevelOnReconnect` restored the level in `OnClientAuthorized`, which can run before the
  player is in game (he could become the leader before being in game), also during warmup or after
  a win. The level is now restored at `OnClientPostAdminCheck`, during a running match only (#12).

## 2.0.9

### Fixed

- Weapon give timers gave the level stored when they were created. With instant respawns a spawn
  give (0.3 s) could fire after a level-up give (0.1 s) and put the previous level's weapon back;
  kills with it did not count until the next death. The timer now gives the player's current
  level (warmup keeps its random weapon) (#11).
- The timer of an older multi-level bonus ended a newer bonus early (#11).

## 2.0.8

### Fixed

- A player killed by the grenade of a player who had left the server was treated as a world
  suicide and lost a level (#10).
- Kills by a player who moved to spectator in the meantime are ignored (#10).
- Kills credited to map entities (`env_explosion`, `func_physbox`...) no longer log
  `Weapon index for "..." not found` in the error log (#10).

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
