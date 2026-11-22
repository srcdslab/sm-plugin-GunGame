void OnCreateNatives()
{
    CreateNative("GG_GetClientLevel", __GetClientLevel);
    CreateNative("GG_GetMaxLevel", __GetMaxLevel);
    CreateNative("GG_SetMaxLevel", __SetMaxLevel);
    CreateNative("GG_AddAPoint", __AddAPoint);
    CreateNative("GG_RemoveAPoint", __RemoveAPoint);
    CreateNative("GG_GetClientPointLevel", __GetClientPointLevel);
    CreateNative("GG_GetClientMaxPointLevel", __GetClientMaxPointLevel);
    CreateNative("GG_AddALevel", __AddALevel);
    CreateNative("GG_RemoveLevelMulti", __RemoveLevelMulti);
    CreateNative("GG_RemoveALevel", __RemoveALevel);
    CreateNative("GG_GiveHandicapLevel", __GiveHandicapLevel);
    CreateNative("GG_IsClientCurrentWeapon", __IsClientCurrentWeapon);
    CreateNative("GG_SetWeaponLevel", __SetWeaponLevel);
    CreateNative("GG_SetWeaponLevelByName", __SetWeaponLevelByName);
    CreateNative("GG_GetWeaponIndex", __GetWeaponIndex);
    CreateNative("GG_GetLevelWeaponName", __GetLevelWeaponName);
    CreateNative("GG_IsWarmupInProgress", __IsWarmupInProgress);
    CreateNative("GG_GetWeaponIdKnife", __GetWeaponIdKnife);
    CreateNative("GG_IsWeaponKnife", __IsWeaponKnife);
    CreateNative("GG_GetWeaponIdHegrenade", __GetWeaponIdHegrenade);
    CreateNative("GG_GetClientKills", __GetClientKills);
    CreateNative("GG_GetRanking", __GetRanking);
    CreateNative("GG_GetWinner", __GetWinner);
    CreateNative("GG_GetLeader", __GetLeader);
    CreateNative("GG_IsMatchStarted", __IsMatchStarted);
    CreateNative("GG_IsFFA", __IsFFA);
}

/**
 * Validates the client index of a native.
 *
 * @return      True if valid, false after throwing a native error.
 */
bool CheckNativeClient(int client, bool inGame = true)
{
    if ( client < 1 || client > MaxClients )
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
        return false;
    }
    if ( inGame && !IsClientInGame(client) )
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
        return false;
    }
    return true;
}

public int __GetWeaponIdKnife(Handle plugin, int numParams)
{
    return g_WeaponIdKnife;
}

public int __IsWeaponKnife(Handle plugin, int numParams)
{
    int weaponId = GetNativeCell(1);
    if ( weaponId <= 0 || weaponId >= MAX_WEAPONS_COUNT || weaponId > g_WeaponsMaxId )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Weapon index out of range [%d]", weaponId);
    }

    return (g_WeaponLevelIndex[weaponId] == g_WeaponLevelIdKnife);
}

public int __GetWeaponIdHegrenade(Handle plugin, int numParams)
{
    return g_WeaponIdHegrenade;
}

public int __IsWarmupInProgress(Handle plugin, int numParams)
{
    return WarmupEnabled;
}

public int __SetMaxLevel(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    if ( level < 1 || level > GUNGAME_MAX_LEVEL )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Level out of range [%d]", level);
    }

    /* Error checking */

    if ( !WeaponOrderName[level - 1][0] )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Level %d does not have a weapon set", level);
    }

    WeaponOrderCount = level;

    /* Clear any weapon index or name after the max level */
    for ( int i = level; i < GUNGAME_MAX_LEVEL; i++ )
    {
        WeaponOrderName[i][0] = '\0';
        WeaponOrderId[i] = 0;
    }

    return 1;
}

/**
 * Retrieve the weapon index for the weapon name.
 *
 * @param weapon        Name of weapon. short or long name.
 */
public int __GetWeaponIndex(Handle plugin, int numParams)
{
    char weapon[MAX_WEAPON_NAME_SIZE];
    GetNativeString(1, weapon, sizeof(weapon));

    return UTIL_GetWeaponIndex(weapon);
}

/**
 * Gives the handicap level to a client.
 *
 * @return      True if the level was raised.
 */
bool GiveHandicapLevel(int client)
{
    if ( !HandicapMode ) {
        return false;
    }

    if ( g_Cfg_HandicapSkipBots && IsFakeClient(client) ) {
        return false;
    }

    if ( !IsFakeClient(client)
         && !TopRankHandicap
         && StatsEnabled
         && ( !GG_IsPlayerWinsLoaded(client) /* HINT: gungame_stats */
            || GG_IsPlayerInTopRank(client) ) /* HINT: gungame_stats */
    )
    {
        return false;
    }

    int level = UTIL_GetHandicapLevel(client);
    if ( PlayerLevel[client] < level )
    {
        int oldLevel = PlayerLevel[client];
        PlayerLevel[client] = level;
        CurrentKillsPerWeap[client] = 0;
        UTIL_UpdatePlayerScoreLevel(client);
        UTIL_FireLevelChanged(client, oldLevel, level, GGLevelReason_Handicap);
        return true;
    }

    return false;
}

public int __GiveHandicapLevel(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client, false) )
    {
        return 0;
    }

    return GiveHandicapLevel(client) ? 1 : 0;
}

public int __RemoveLevelMulti(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int loose = GetNativeCell(2);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    CurrentLevelPerRound[client] -= loose;
    if ( CurrentLevelPerRound[client] < 0 )
    {
        CurrentLevelPerRound[client] = 0;
    }
    CurrentLevelPerRoundTriple[client] = 0;

    int oldLevel = PlayerLevel[client];
    int level = UTIL_ChangeLevel(client, -loose, false, 0, GGLevelReason_Native);
    if ( level == oldLevel )
    {
        return 0;
    }

    if ( TurboMode )
    {
        UTIL_GiveNextWeapon(client, level);
    }

    return oldLevel - level;
}

public int __RemoveALevel(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    if ( --CurrentLevelPerRound[client] < 0 )
    {
        CurrentLevelPerRound[client] = 0;
    }
    CurrentLevelPerRoundTriple[client] = 0;

    int oldLevel = PlayerLevel[client];
    int level = UTIL_ChangeLevel(client, -1, false, 0, GGLevelReason_Native);
    if ( level == oldLevel )
    {
        return 0;
    }

    if ( TurboMode )
    {
        UTIL_GiveNextWeapon(client, level);
    }

    return 1;
}

public int __AddALevel(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    if ( MaxLevelPerRound && CurrentLevelPerRound[client] >= MaxLevelPerRound )
    {
        return 0;
    }

    CurrentLevelPerRound[client]++;

    int oldLevel = PlayerLevel[client];
    int level = UTIL_ChangeLevel(client, 1, false, 0, GGLevelReason_Native);
    if ( level == oldLevel )
    {
        return 0;
    }

    if ( TurboMode )
    {
        UTIL_GiveNextWeapon(client, level);
    }

    CheckForTripleLevel(client);

    return level;
}

public int __IsClientCurrentWeapon(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    char Weapon[MAX_WEAPON_NAME_SIZE];
    GetNativeString(2, Weapon, sizeof(Weapon));

    return strcmp(Weapon, g_WeaponName[WeaponOrderId[PlayerLevel[client]]], false) == 0;
}

public int __GetClientLevel(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    return PlayerLevel[client] + 1;
}

public int __GetMaxLevel(Handle plugin, int numParams)
{
    return WeaponOrderCount;
}

public int __AddAPoint(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    if ( MaxLevelPerRound && CurrentLevelPerRound[client] >= MaxLevelPerRound )
    {
        return 0;
    }

    int oldLevel = PlayerLevel[client];
    int point = ++CurrentKillsPerWeap[client];
    if ( point < UTIL_GetCustomKillPerLevel(oldLevel) )
    {
        return point;
    }

    /* They leveled up.*/
    int level = UTIL_ChangeLevel(client, 1, false, 0, GGLevelReason_Native);
    if ( level == oldLevel )
    {
        return 0;
    }
    CurrentLevelPerRound[client]++;

    if ( TurboMode )
    {
        UTIL_GiveNextWeapon(client, level);
    }

    CheckForTripleLevel(client);

    return 0;
}

public int __RemoveAPoint(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    int oldLevel = PlayerLevel[client];
    int point = --CurrentKillsPerWeap[client];
    if ( point >= 0 )
    {
        return point;
    }

    // remove a level
    if ( --CurrentLevelPerRound[client] < 0 )
    {
        CurrentLevelPerRound[client] = 0;
    }
    CurrentLevelPerRoundTriple[client] = 0;

    int level = UTIL_ChangeLevel(client, -1, false, 0, GGLevelReason_Native);
    if ( oldLevel == level )
    {
        return CurrentKillsPerWeap[client] = 0;
    }

    if ( TurboMode )
    {
        UTIL_GiveNextWeapon(client, level);
    }

    return CurrentKillsPerWeap[client] = UTIL_GetCustomKillPerLevel(level) - 1;
}

public int __GetClientPointLevel(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    return CurrentKillsPerWeap[client];
}

public int __GetClientMaxPointLevel(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    return UTIL_GetCustomKillPerLevel(PlayerLevel[client]);
}

public int __SetWeaponLevel(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    if ( level < 1 || level > GUNGAME_MAX_LEVEL )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Level out of range [%d]", level);
    }

    int weap = GetNativeCell(2);

    if ( weap <= 0 || weap >= MAX_WEAPONS_COUNT || weap > g_WeaponsMaxId )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Weapon index out of range [%d]", weap);
    }

    /* WeaponOrderName holds short names (without "weapon_"). */
    strcopy(WeaponOrderName[level - 1], sizeof(WeaponOrderName[]), g_WeaponName[weap][7]);
    WeaponOrderId[level - 1] = weap;

    return 1;
}

public int __SetWeaponLevelByName(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    if ( level < 1 || level > GUNGAME_MAX_LEVEL )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Level out of range [%d]", level);
    }

    char weapon[MAX_WEAPON_NAME_SIZE];
    GetNativeString(2, weapon, sizeof(weapon));

    int weap = UTIL_GetWeaponIndex(weapon);

    if ( weap <= 0 || weap >= MAX_WEAPONS_COUNT || weap > g_WeaponsMaxId )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Weapon name is invalid [%s]", weapon);
    }

    /* WeaponOrderName holds short names (without "weapon_"). */
    strcopy(WeaponOrderName[level - 1], sizeof(WeaponOrderName[]), g_WeaponName[weap][7]);
    WeaponOrderId[level - 1] = weap;

    return 1;
}

public int __GetLevelWeaponName(Handle plugin, int numParams)
{
    int level       = GetNativeCell(1);
    int size        = GetNativeCell(3);
    if ( level < 1 || level > GUNGAME_MAX_LEVEL )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Level out of range [%d]", level);
    }
    if ( !WeaponOrderName[level-1][0] )
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Level %d does not have a weapon set", level);
    }
    SetNativeString(2, WeaponOrderName[level-1], size, false);
    return 1;
}

public int __GetClientKills(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if ( !CheckNativeClient(client, false) )
    {
        return 0;
    }

    return g_MatchKills[client];
}

public int __GetRanking(Handle plugin, int numParams)
{
    int maxClients = GetNativeCell(2);
    if ( maxClients <= 0 )
    {
        return 0;
    }

    int ranking[MAXPLAYERS + 1];
    int count = UTIL_BuildRanking(ranking, maxClients < sizeof(ranking) ? maxClients : sizeof(ranking));
    SetNativeArray(1, ranking, count);
    return count;
}

public int __GetWinner(Handle plugin, int numParams)
{
    return GameWinner;
}

public int __GetLeader(Handle plugin, int numParams)
{
    return CurrentLeader;
}

public int __IsMatchStarted(Handle plugin, int numParams)
{
    return g_MatchStarted;
}

public int __IsFFA(Handle plugin, int numParams)
{
    return FFA != 0;
}
