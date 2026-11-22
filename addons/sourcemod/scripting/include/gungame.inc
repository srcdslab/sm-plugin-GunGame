#if defined _gungame_natives_included_
  #endinput
#endif
#define _gungame_natives_included_

/**
 * GunGame:SM core API (library "gungame", plugin gungame.smx).
 *
 * Level numbering:
 *   - The natives and the GG_OnClientLevelChanged / GG_OnKnifeSteal forwards
 *     use 1-based levels (level 1 = first weapon, GG_GetMaxLevel() = last weapon).
 *   - The legacy GG_OnClientLevelChange and GG_OnLeaderChange forwards keep
 *     their historical 0-based levels.
 *
 * Weapon names are the short names of gungame.equip.txt ("glock", "knife",
 * "hegrenade"...), without the "weapon_" prefix.
 */

/**
 * Why a level changed (GG_OnClientLevelChanged).
 */
enum GGLevelReason
{
    GGLevelReason_Kill = 0,         /**< Killer levelled up by killing with the level weapon (or enough points). */
    GGLevelReason_KnifeSteal,       /**< Killer levelled up by stealing a level with the knife (KnifePro). */
    GGLevelReason_KnifeStolen,      /**< Victim lost a level to a knife steal (KnifePro). */
    GGLevelReason_Suicide,          /**< Suicide / world kill penalty (CommitSuicide, WorldspawnSuicide). */
    GGLevelReason_Objective,        /**< Bomb objective bonus or hostage kill penalty. */
    GGLevelReason_Native,           /**< Another plugin changed the level (GG_AddALevel, GG_AddAPoint, GG_RemoveLevelMulti...). */
    GGLevelReason_Handicap,         /**< Handicap gave levels to a late joiner / low player. */
    GGLevelReason_Reconnect,        /**< Level restored on reconnect (RestoreLevelOnReconnect). */
    GGLevelReason_Admin             /**< Admin/debug command. */
};

/**
 * Forwards
 */

/**
 * Called when gungame is enabled
 *
 * @param Command       True if gungame was enabled by command.
 */
forward void GG_OnStartup(bool Command);

/**
 * Called when gungame is disabled.
 *
 * @param Command       True if gungame was disabled by command.
 */
forward void GG_OnShutdown(bool Command);

/**
 * Called before the player level changes. Legacy pre-hook, levels are 0-based.
 *
 * @param client        Player index.
 * @param level         Player new level (starting from 0).
 * @param difference    The difference in the level change.
 * @param steal         true if it was a knife steal otherwise false
 * @param last          true if player reached last level.
 * @param knife         true if player reached knife level.
 * @return              Plugin_Handled to stop the level change.
 */
forward Action GG_OnClientLevelChange(int client, int level, int difference, bool steal, bool last, bool knife);

/**
 * Called after the player level changed (level up or level down).
 * Not called for the winning kill (see GG_OnWinner) nor for the global
 * resets (warmup end, gg_restart, map change).
 *
 * @param client        Player index.
 * @param oldLevel      Previous level (starting from 1).
 * @param newLevel      New level (starting from 1). newLevel > oldLevel is a level up.
 * @param weapon        Short weapon name of the new level.
 * @param reason        Why the level changed.
 */
forward void GG_OnClientLevelChanged(int client, int oldLevel, int newLevel, const char[] weapon, GGLevelReason reason);

/**
 * Called after a knife steal (KnifePro): the killer took a level from the victim.
 * Called after the matching GG_OnClientLevelChanged forwards.
 *
 * @param killer        Killer index.
 * @param victim        Victim index.
 * @param killerLevel   Killer level after the steal (starting from 1).
 * @param victimLevel   Victim level after the steal (starting from 1).
 * @param victimLost    True if the victim actually lost a level
 *                      (false if he was on level 1 or DisableLevelDown is set).
 */
forward void GG_OnKnifeSteal(int killer, int victim, int killerLevel, int victimLevel, bool victimLost);

/**
 * Called when the player point per level changed.
 *
 * @param client        Player index.
 * @param point         Player current point per level.
 * @param difference    The difference in point change.
 * @return              Plugin_Handled to stop the point change.
 */
forward Action GG_OnClientPointChange(int client, int point, int difference);

/**
 * Called when a client won the game.
 * The final ranking is available with GG_GetRanking() from this forward on.
 *
 * @param client        Player index.
 * @param Weapon        The player weapon they won with.
 * @param victim        Player index of victim (or 0 if there was no victim).
 */
forward void GG_OnWinner(int client, const char[] Weapon, int victim);

/**
 * Called when the match starts: when the warmup round is over (first round
 * after warmup), or when gungame starts on a map without warmup.
 * Called once per map, and again after gg_restart.
 */
forward void GG_OnMatchStart();

/**
 * Called when a client triple leveled.
 *
 * @param client        Player index.
 */
forward void GG_OnTripleLevel(int client);

/**
 * Called when warmup has ended.
 */
forward void GG_OnWarmupEnd();

/**
 * Called when warmup has started.
 */
forward void GG_OnWarmupStart();

/**
 * Called when the leader change player.
 *
 * @param client        Player index.
 * @param level         The player current level (starting from 0).
 * @param totalLevels   Total number of levels (max level from config)
 */
forward void GG_OnLeaderChange(int client, int level, int totalLevels);

/**
 * Called when to start the map voting for next map
 */
forward void GG_OnStartMapVote();

/**
 * Called when a player reached the DisableRtvLevel level.
 */
forward void GG_OnDisableRtv();

/**
 * Called when a player died.
 *
 * @param killer        Killer's index.
 * @param victim        Victim's index.
 * @param WeaponId      The weapon index the player was killed with.
 * @param TeamKilled    True if they were killed by a team mate.
 *                      Always false in FFA mode ("FFA" "1" in gungame.config.txt).
 * @return              Plugin_Handled to ignore the kill,
 *                      Plugin_Changed to ignore it and reload the killer weapon.
 */
forward Action GG_OnClientDeath(int killer, int victim, int WeaponId, bool TeamKilled);

/**
 * Called before winner sound starts to play.
 *
 * @param client        Winner's index.
 * @return              Plugin_Handled to prevent winner sound to play.
 */
forward Action GG_OnSoundWinner(int client);

/**
 * Gives the client the average/minimum level of all players in the server.
 *
 * Handicap mode:
 *    1 - Average level
 *    2 - Minimum level
 *
 * @param client        Player index.
 * @return              1 if the level was set, 0 if it was not changed.
 */
native int GG_GiveHandicapLevel(int client);

/**
 * Get the player current level.
 *
 * @param client        Player index
 * @return              The player current level (starting from 1).
 * @error               Invalid client index or client not in game.
 */
native int GG_GetClientLevel(int client);

/**
 * Retrieves the max level.
 *
 * @return              The max level (starting from 1).
 */
native int GG_GetMaxLevel();

/**
 * Add a level to the player current level.
 * This does not tell the client that they have leveled.
 *
 * @param client        Player index.
 * @return              The player new level (0-based) or 0 if not changed.
 */
native int GG_AddALevel(int client);

/**
 * Remove a level from the player current level.
 *
 * This does not tell the client that they have lost a level.
 * This also obeys the max level per round.
 *
 * @param client        Player index.
 * @return              1 if a level was removed, 0 otherwise.
 */
native int GG_RemoveALevel(int client);

/**
 * Remove multi levels from the player current level.
 *
 * This does not tell the client that they have lost a level.
 * This also obeys the max level per round.
 *
 * @param client        Player index.
 * @param level         Levels to loose.
 * @return              Number of levels actually lost.
 */
native int GG_RemoveLevelMulti(int client, int level);

/**
 * Add a point to the player point per level.
 *
 * This does not tell the client if they gain a point
 * nor does it tell the client that they leveled due to reaching the max point.
 *
 * @param client        Player index.
 * @return              The current player point per level or 0 if they leveled.
 */
native int GG_AddAPoint(int client);

/**
 * Removes a point to the player point per level.
 *
 * This does not tell the client if they lost a point
 * nor does it tell the client that they lost a level.
 *
 * @param client        Player index.
 * @return              The current player point per level or GG_GetClientMaxPointLevel() - 1 if they lost a level.
 */
native int GG_RemoveAPoint(int client);

/**
 * Retrieves the client current point per level.
 *
 * @param client        Player index.
 * @return              The current player point per level.
 */
native int GG_GetClientPointLevel(int client);

/**
 * Retrieves the client max point per level.
 *
 * @param client        Player index.
 * @return              The player max point per level.
 */
native int GG_GetClientMaxPointLevel(int client);

/**
 * Checks if the given weapon is the weapon of the client current level.
 *
 * @param client        Player index.
 * @param weapon        Full weapon name (ie weapon_glock).
 * @return              True if it is the client level weapon.
 */
native bool GG_IsClientCurrentWeapon(int client, const char[] weapon);

/**
 * Set the level weapon by weapon index.
 *
 * @param level         The weapon level (starting from 1)
 * @param weapon        The weapon index
 * @return              1 on success.
 */
native int GG_SetWeaponLevel(int level, int weapon);

/**
 * Set the level weapon by weapon name.
 *
 * @param level         The weapon level (starting from 1)
 * @param weapon        The weapon name
 * @return              1 on success.
 */
native int GG_SetWeaponLevelByName(int level, const char[] weapon);

/**
 * Set the maximum level the player can achieve to win the game.
 *
 * @param level         The level (starting from 1)
 * @return              1 on success.
 * @error               If level is greater than the define maximum.
 */
native int GG_SetMaxLevel(int level);

/**
 * Retrieves the weapon index from weapon name.
 *
 * @param weapon        The short weapon name. ie awp, glock.
 * @return              0 if weapon is not found or the weapon index.
 */
native int GG_GetWeaponIndex(const char[] weapon);

/**
 * Get weapon name from level.
 *
 * @param level         The level (starting from 1).
 * @param weapon        Buffer to store the short weapon name (ie "glock").
 * @param maxlength     Max length of weapon String.
 * @return              1 on success.
 * @error               Level out of range or level without weapon.
 */
native int GG_GetLevelWeaponName(int level, char[] weapon, int maxlength);

/**
 * Retrieves if warmup is in progress.
 *
 * @return              Return true if warmup is in progress otherwise false.
 */
native bool GG_IsWarmupInProgress();

/**
 * Return weapon id for knife weapon.
 *
 * @return              Return weapon id for knife weapon.
 */
native int GG_GetWeaponIdKnife();

/**
 * Return true if weapon is knife.
 *
 * @param weaponId      The weapon id to ckeck.
 * @return              True if the weapon is the knife.
 */
native bool GG_IsWeaponKnife(int weaponId);

/**
 * Return weapon id for hegrenade weapon.
 *
 * @return              Return weapon id for hegrenade weapon.
 */
native int GG_GetWeaponIdHegrenade();

/**
 * Retrieves the number of valid kills (kills that counted for gungame:
 * no warmup, no team kill, not blocked by another plugin) of the client
 * since the match started.
 *
 * @param client        Player index.
 * @return              Number of kills.
 * @error               Invalid client index.
 */
native int GG_GetClientKills(int client);

/**
 * Builds the current ranking: in-game players on a team (T/CT), sorted by
 * level (descending), then kills (descending), then points on the current
 * level (descending). Once the game is won, the winner is always first.
 *
 * @param clients       Array to store the client indexes, best first.
 * @param maxClients    Size of the array.
 * @return              Number of clients written.
 */
native int GG_GetRanking(int[] clients, int maxClients);

/**
 * Retrieves the winner of the current map.
 *
 * @return              Winner client index, 0 if the game is not won yet.
 */
native int GG_GetWinner();

/**
 * Retrieves the current leader.
 *
 * @return              Leader client index, 0 if there is no leader.
 */
native int GG_GetLeader();

/**
 * Retrieves if the match has started (see GG_OnMatchStart).
 *
 * @return              True if the match has started.
 */
native bool GG_IsMatchStarted();

/**
 * Retrieves if the free-for-all mode is enabled ("FFA" "1" in gungame.config.txt).
 * In FFA mode every kill counts as an enemy kill: no team kill and no team kill penalty.
 *
 * @return              True if FFA is enabled.
 */
native bool GG_IsFFA();

/* Do not edit the code below. */
public SharedPlugin __pl_gungame =
{
    name = "gungame",
    file = "gungame.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_gungame_SetNTVOptional()
{
    MarkNativeAsOptional("GG_GiveHandicapLevel");
    MarkNativeAsOptional("GG_GetClientLevel");
    MarkNativeAsOptional("GG_GetMaxLevel");
    MarkNativeAsOptional("GG_AddALevel");
    MarkNativeAsOptional("GG_RemoveALevel");
    MarkNativeAsOptional("GG_RemoveLevelMulti");
    MarkNativeAsOptional("GG_AddAPoint");
    MarkNativeAsOptional("GG_RemoveAPoint");
    MarkNativeAsOptional("GG_GetClientPointLevel");
    MarkNativeAsOptional("GG_GetClientMaxPointLevel");
    MarkNativeAsOptional("GG_IsClientCurrentWeapon");
    MarkNativeAsOptional("GG_SetWeaponLevel");
    MarkNativeAsOptional("GG_SetWeaponLevelByName");
    MarkNativeAsOptional("GG_SetMaxLevel");
    MarkNativeAsOptional("GG_GetWeaponIndex");
    MarkNativeAsOptional("GG_GetLevelWeaponName");
    MarkNativeAsOptional("GG_IsWarmupInProgress");
    MarkNativeAsOptional("GG_GetWeaponIdKnife");
    MarkNativeAsOptional("GG_IsWeaponKnife");
    MarkNativeAsOptional("GG_GetWeaponIdHegrenade");
    MarkNativeAsOptional("GG_GetClientKills");
    MarkNativeAsOptional("GG_GetRanking");
    MarkNativeAsOptional("GG_GetWinner");
    MarkNativeAsOptional("GG_GetLeader");
    MarkNativeAsOptional("GG_IsMatchStarted");
    MarkNativeAsOptional("GG_IsFFA");
}
#endif
