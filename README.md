# GunGame:SM (srcdslab fork)

GunGame for Counter-Strike: Source, modernized for SourceMod 1.12/1.13 (x86 and x64).

On spawn you get one weapon. Kill enemies with the current weapon to get the next one;
the first player who kills with every weapon of the list wins the map.

## About this fork

This repository is a fork of
[altexdim/sourcemod-plugin-gungame](https://github.com/altexdim/sourcemod-plugin-gungame)
(GunGame:SM 1.2.16 by **teame06**, **Liam** and the **Otstrel.ru Team**; Display Winner by
**bl4nk**). The original history is kept in this repository, the original documentation is
in [doc/](doc/) and the original changelog in [doc/CHANGELOG.txt](doc/CHANGELOG.txt).

Changes of the fork (details in [CHANGELOG.md](CHANGELOG.md)):

- new SourcePawn syntax (`newdecls`, methodmaps), no deprecated API, x64-safe entity access;
- Counter-Strike: Source only (the CS:GO code and configs are removed);
- asynchronous SQL in gungame_stats (SQLite and MySQL);
- a FFA mode that never punishes "team kills";
- an extended API for companion plugins (level changes, knife steals, match start, ranking).

The gameplay and the config format (`gungame.config.txt`, `gungame.equip.txt`,
map/prefix configs) are unchanged.

## Requirements

- SourceMod 1.12 or newer (the CI builds with 1.12 and 1.13.0.7427)
- Counter-Strike: Source
- To build: [MultiColors](https://github.com/srcdslab/sm-plugin-MultiColors) include

## Installation

Download the archive of the [latest release](https://github.com/srcdslab/sm-plugin-GunGame/releases/tag/latest)
for your SourceMod version and extract it in `cstrike/`:

- `addons/sourcemod/plugins/*.smx`, `addons/sourcemod/translations/*.phrases.txt`
- `cfg/gungame/css/` (configs, `weaponinfo.txt` is mandatory)
- `sound/gungame/` (sounds, also added to the downloads table)
- `addons/sourcemod/scripting/include/gungame*.inc` (only needed to build companion plugins)

## Modules

| Plugin | Required | Description |
| --- | --- | --- |
| `gungame.smx` | yes | Core: levels, weapons, warmup, handicap, turbo, knife pro/elite, multi-kill, winner. Library `gungame`. |
| `gungame_config.smx` | yes | Reads `cfg/<sm_gg_cfgdirname>/css/gungame.config.txt`, `gungame.equip.txt` and `maps/<prefix or map>.config.txt / .equip.txt`. Library `gungame_cfg`. |
| `gungame_stats.smx` | no | Wins database, `!top`, `!rank`, top rank handicap. Library `gungame_st`. |
| `gungame_afk.smx` | no | No level up on AFK players, kick or move them to spectators (`Afk*` keys). |
| `gungame_bot.smx` | no | No level up with the knife or a grenade on bots (`AllowLevelUpBy*` keys). |
| `gungame_tk.smx` | no | Removes `TkLooseLevel` levels after a team kill (never in FFA mode). |
| `gungame_logging.smx` | no | Logs `gg_win`, `gg_levelup`, `gg_knife_steal`... for HLstatsX. |
| `gungame_display_winner.smx` | no | Winner MOTD (`DisplayWinnerMotd`, `DisplayWinnerUrl`) and rank on win; needs gungame_stats. |
| `gungame_winner_effects.smx` | no | Winner effects (`WinnerEffect`), fireworks (`gg_fireworks_*` cvars) and confetti (`gg_confetti`). |
| `gungame_mapvoting.smx` | no | Executes `gungame.mapvote.cfg` near the end and `gungame.disable_rtv.cfg` at `DisableRtvLevel`. |
| `gungame_warmup_configs.smx` | no | Executes `gungame.warmupstart.cfg` / `gungame.warmupend.cfg`. |

## Cvars

| Cvar | Default | Description |
| --- | --- | --- |
| `sm_gungamesm_version` | `2.0.22` | Version (read only). |
| `gungame_enabled` | `1` | Shows if GunGame is enabled (set by the plugin, use `gg_enable`/`gg_disable`). |
| `sm_gg_cfgdirname` | `gungame` | Config directory in `cfg/`; the files are read from `cfg/<value>/css/` on the next map. |
| `sm_gg_turbo` | `0` | Turbo mode; overridden by `TurboMode` when the config is read. |
| `sm_gg_multilevelamount` | `3` | Multi level amount; overridden by `MultiLevelAmount` when the config is read. |
| `sm_gg_bot_win_kills` | `0` | Bots can win after this many winning kills on the last level (a blocked one keeps them there). `0` = `BotsCanWinGame` decides. Useful on a bots-only server so maps end with a winner. |

Everything else is configured in `cfg/gungame/css/gungame.config.txt` (every key is documented there).

Companion plugin cvars (written to `cfg/sourcemod/<plugin>.cfg` on the first load):

| Cvar | Default | Description |
| --- | --- | --- |
| `gg_fireworks_mode` | `1` | gungame_winner_effects fireworks: `0` off, `1` at match end (GunGame win or time limit), `2` on a GunGame win only, `3` at match end and over a player at each level earned in play (kill, knife steal, objective; not handicap, reconnect or admin levels). |
| `gg_fireworks_bursts` | `3` | Rockets over each alive player in the match end show (`1`-`10`), twice as many over the winner; lowered on a full server so the show fits in ~6 s. |
| `gg_confetti` | `1` | gungame_winner_effects confetti with the match end fireworks: big spark showers over the alive players, five over the winner. |

The match end show runs once per match end, over ~6 s from the win or the start of the
intermission (keep `mp_chattime` at 7 or more to see all of it). Fireworks are temp entities
(beams, glow sprite, sparks, ring) with stock CS:S materials and the flashbang bang, nothing to
download.

## Commands

| Command | Access | Description |
| --- | --- | --- |
| `level`, `weapons`, `score`, `leader`, `rules`, `commands` (`!level`...) | everyone | Level panel, weapon order, players levels, leaders, rules, command list. |
| `top`, `top10`, `rank` | everyone | Top winners and own place (gungame_stats). |
| `gg_version`, `gg_status` | everyone | Version information, game state. |
| `gg_restart` | RCON | Restarts the game from level 1. |
| `gg_enable`, `gg_disable` | RCON | Turns GunGame on/off and restarts the game. |
| `gg_rebuild` | RCON | Reloads the top rank (gungame_stats). |
| `gg_reset` | RCON | Deletes every win (gungame_stats). |
| `gg_import`, `gg_importdb` | RCON | Imports `data/gungame/es_gg_winners_db.txt` / `data/gungame/playerdata.txt` (gungame_stats). |

## Stats database

gungame_stats uses the `gungame` entry of `addons/sourcemod/configs/databases.cfg` when it
exists, otherwise `storage-local` (SQLite, `addons/sourcemod/data/sqlite/sourcemod-local.sq3`).
The `gungame_playerdata` table is created on first start. Every query is asynchronous.

## FFA (free-for-all deathmatch)

Set `"FFA" "1"` in `gungame.config.txt` and `mp_friendlyfire 1` on the server. In FFA mode:

- a kill on a "teammate" is a normal kill and levels the killer up;
- `GG_OnClientDeath` never reports a team kill, so gungame_tk never removes levels;
- `AutoFriendlyFire` and `EnableFriendlyFireLevel` never touch `mp_friendlyfire`;
- gungame_logging does not log `gg_team_win` / `gg_team_lose`.

The respawn and the spawn points are left to the deathmatch plugin. Set `"TurboMode" "1"`
with a deathmatch plugin: without it the weapon of the new level is only given at the next
spawn (round-based GunGame), so a player who levels up keeps the old weapon until they die. Also set `"UnlimitedNades" "1"`
(a new grenade after each throw on the grenade level), `"StripDeadPlayersWeapon" "1"` (dead
players drop nothing) and `"BlockWeaponPickup" "1"` (only the weapons given by GunGame and the
knife can be picked up, map weapons stay on the ground). The game's own team
kill punishments (`mp_autokick`, `mp_tkpunish`, `mp_spawnprotectiontime`) are server cvars,
not handled by GunGame.

## Reloading

Reload GunGame with a map change. `sm plugins reload gungame/gungame` mid-map leaves GunGame off
until the next map (the config is only read when the map configs are executed); companions
(gungame_stats, gungame_afk) reloaded alone start again but keep their default config values until
the next map.

## API for companion plugins

Include `gungame.inc` (core), `gungame_stats.inc` (stats) and `gungame_config.inc` (config
reader). Use `#undef REQUIRE_PLUGIN` before the include for an optional dependency and check
`LibraryExists("gungame")`.

Levels are **1-based** in the natives and in the new forwards (level 1 is the first weapon,
`GG_GetMaxLevel()` the last one). Weapon names are the short names of `gungame.equip.txt`
(`glock`, `knife`, `hegrenade`...).

Main entry points:

```sourcepawn
// After every level change (up or down), not for the winning kill.
forward void GG_OnClientLevelChanged(int client, int oldLevel, int newLevel, const char[] weapon, GGLevelReason reason);
// After a knife steal (KnifePro).
forward void GG_OnKnifeSteal(int killer, int victim, int killerLevel, int victimLevel, bool victimLost);
// Winner; GG_GetRanking() gives the final ranking from here.
forward void GG_OnWinner(int client, const char[] Weapon, int victim);
// End of warmup (or start of gungame without warmup), once per match.
forward void GG_OnMatchStart();

native int  GG_GetClientLevel(int client);                                  // 1-based
native int  GG_GetMaxLevel();
native int  GG_GetLevelWeaponName(int level, char[] weapon, int maxlength);
native int  GG_GetClientKills(int client);                                  // valid kills of the match
native int  GG_GetRanking(int[] clients, int maxClients);                   // level, then kills, then points
native int  GG_GetWinner();
native int  GG_GetLeader();
native bool GG_IsMatchStarted();
native bool GG_IsFFA();
```

`GGLevelReason` tells why a level changed: `Kill`, `KnifeSteal`, `KnifeStolen`, `Suicide`,
`Objective`, `Native`, `Handicap`, `Reconnect`, `Admin`. The legacy forwards and natives of
GunGame:SM 1.2 (`GG_OnClientLevelChange`, `GG_OnClientDeath`, `GG_OnLeaderChange`,
`GG_AddALevel`...) are kept unchanged. See the include files for the full documentation.

## Build

```sh
cd addons/sourcemod/scripting
for sp in *.sp; do spcomp -E -i include -i <multicolors>/include -o ../plugins/${sp%.sp}.smx $sp; done
```

## Credits

- GunGame:SM: teame06 ([hat-city.net](http://www.hat-city.net)), Liam, Otstrel.ru Team ([otstrel.ru](http://otstrel.ru)) and the contributors of the original repository
- Display Winner: bl4nk
- Idea and concept of GunGame: cagemonkey
