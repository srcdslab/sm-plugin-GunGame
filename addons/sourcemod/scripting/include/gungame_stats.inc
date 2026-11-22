#if defined _gungame_st_natives_included_
  #endinput
#endif
#define _gungame_st_natives_included_

/**
 * GunGame:SM stats API (library "gungame_st", plugin gungame_stats.smx).
 */

/**
 * Show the top to the client.
 *
 * @param client        Player index.
 */
native void GG_DisplayTop(int client); /* HINT: gungame_stats */

/**
 * Show the client's rank in chat.
 *
 * @param client        Player index.
 */
native void GG_ShowRank(int client); /* HINT: gungame_stats */

/**
 * Return current player's place in stat.
 *
 * @param client        Player index
 * @return              Place (starting from 1), 0 if the player has no win
 *                      or if the place is not loaded yet (it is loaded with the wins
 *                      and refreshed before GG_OnLoadRank).
 */
native int GG_GetPlayerPlaceInStat(int client); /* HINT: gungame_stats */

/**
 * Count number of winners in stat.
 *
 * @return              Number of players in the stats table.
 */
native int GG_CountPlayersInStat(); /* HINT: gungame_stats */

/**
 * Retrieves player current total wins.
 *
 * @param client        Player index
 * @return              Total player wins
 */
native int GG_GetClientWins(int client); /* HINT: gungame_stats */

/**
 * Check if player in top rank.
 *
 * @param client        Player index.
 * @return              True if player is in top rank, false if he is not.
 */
native bool GG_IsPlayerInTopRank(int client); /* HINT: gungame_stats */

/**
 * Check if player wins is loaded.
 *
 * @param client        Player index.
 * @return              True if player wins is loaded, false if it is not.
 */
native bool GG_IsPlayerWinsLoaded(int client); /* HINT: gungame_stats */

/**
 * Called when the rank (winners count, top rank, places of the players in game)
 * has been (re)loaded, at plugin start and after every saved win.
 */
forward void GG_OnLoadRank();

/**
 * Called when player wins is loaded.
 *
 * @param client        Player index.
 */
forward void GG_OnLoadPlayerWins(int client);


/* Do not edit the code below. */
public SharedPlugin __pl_gungame_st =
{
    name = "gungame_st",
    file = "gungame_stats.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_gungame_st_SetNTVOptional()
{
    MarkNativeAsOptional("GG_DisplayTop");
    MarkNativeAsOptional("GG_ShowRank");
    MarkNativeAsOptional("GG_GetPlayerPlaceInStat");
    MarkNativeAsOptional("GG_CountPlayersInStat");
    MarkNativeAsOptional("GG_GetClientWins");
    MarkNativeAsOptional("GG_IsPlayerInTopRank");
    MarkNativeAsOptional("GG_IsPlayerWinsLoaded");
}
#endif
