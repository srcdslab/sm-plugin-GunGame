#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#include <multicolors>
#include <gungame_const>
#include <gungame>
#include <gungame_config>
#include <langutils>

#undef REQUIRE_PLUGIN
#include <gungame_stats>

#include "gungame/globals.sp"

#if defined GUNGAME_DEBUG
#include "gungame/debug.sp"
#endif

#include "gungame/util.sp"
#include "gungame/natives.sp"
#include "gungame/config.sp"
#include "gungame/keyvalue.sp"
#include "gungame/event.sp"
#include "gungame/menu.sp"
#include "gungame/commands.sp"

public Plugin myinfo = {
    name = "GunGame:SM",
    author = GUNGAME_AUTHOR,
    description = "GunGame:SM for SourceMod",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (!GG_IsCstrike()) {
        strcopy(error, err_max, "GunGame:SM only supports Counter-Strike: Source.");
        return APLRes_Failure;
    }

    RegPluginLibrary("gungame");
    OnCreateNatives();
    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
    if ( StrEqual(name, "gungame_st") )
    {
        StatsEnabled = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if ( StrEqual(name, "gungame_st") )
    {
        StatsEnabled = false;
    }
}

public void OnAllPluginsLoaded()
{
    StatsEnabled = LibraryExists("gungame_st");
}

public void OnPluginStart()
{
    StatsEnabled = LibraryExists("gungame_st");

    LoadTranslations("gungame.phrases");
    PlayerLevelsBeforeDisconnect = new StringMap();
    PlayerHandicapTimes = new StringMap();

    // ConVar
    mp_friendlyfire = FindConVar("mp_friendlyfire");
    mp_restartgame = FindConVar("mp_restartgame");

    ConVar version = CreateConVar("sm_gungamesm_version", GUNGAME_VERSION, "GunGame Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    /* Just to make sure they it updates the convar version if they just had the plugin reload on map change */
    version.SetString(GUNGAME_VERSION);

    gungame_enabled = CreateConVar("gungame_enabled", "1", "Display if GunGame is enabled or disabled", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    /* Dynamic Forwards */
    FwdDeath = new GlobalForward("GG_OnClientDeath", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    FwdLevelChange = new GlobalForward("GG_OnClientLevelChange", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    FwdLevelChanged = new GlobalForward("GG_OnClientLevelChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell);
    FwdKnifeSteal = new GlobalForward("GG_OnKnifeSteal", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    FwdPoint = new GlobalForward("GG_OnClientPointChange", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
    FwdLeader = new GlobalForward("GG_OnLeaderChange", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    FwdWinner = new GlobalForward("GG_OnWinner", ET_Ignore, Param_Cell, Param_String, Param_Cell);
    FwdSoundWinner = new GlobalForward("GG_OnSoundWinner", ET_Hook, Param_Cell);
    FwdTripleLevel = new GlobalForward("GG_OnTripleLevel", ET_Ignore, Param_Cell);
    FwdWarmupEnd = new GlobalForward("GG_OnWarmupEnd", ET_Ignore);
    FwdWarmupStart = new GlobalForward("GG_OnWarmupStart", ET_Ignore);
    FwdMatchStart = new GlobalForward("GG_OnMatchStart", ET_Ignore);

    FwdVoteStart = new GlobalForward("GG_OnStartMapVote", ET_Ignore);
    FwdDisableRtv = new GlobalForward("GG_OnDisableRtv", ET_Ignore);

    FwdStart = new GlobalForward("GG_OnStartup", ET_Ignore, Param_Cell);
    FwdShutdown = new GlobalForward("GG_OnShutdown", ET_Ignore, Param_Cell);

    OnKeyValueStart();
    OnCreateCommand();

    #if defined GUNGAME_DEBUG
    OnCreateDebug();
    #endif

    g_Cvar_Turbo = CreateConVar("sm_gg_turbo", "0", "Turbo mode (overridden by TurboMode of gungame.config.txt when the config is read)", _, true, 0.0, true, 1.0);
    g_Cvar_MultiLevelAmount = CreateConVar("sm_gg_multilevelamount", "3", "Multi level amount (overridden by MultiLevelAmount of gungame.config.txt when the config is read)", _, true, 0.0);

    g_Cvar_Turbo.AddChangeHook(Event_CvarChanged);
    g_Cvar_MultiLevelAmount.AddChangeHook(Event_CvarChanged);

    /* Late load: hook the players already in game. */
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) )
        {
            UTIL_HookClientWeapons(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
    g_SkipSpawn[client] = IsFakeClient(client);
    g_BlockSwitch[client] = false;
    g_MatchKills[client] = 0;
    g_AllowPickup[client] = false;

    UTIL_HookClientWeapons(client);
}

void UTIL_HookClientWeapons(int client)
{
    SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(client, SDKHook_Spawn, OnPlayerSpawnPre);
    SDKHook(client, SDKHook_SpawnPost, OnPlayerSpawnPost);
}

/* Restore the level once the client is in game and authorized (OnClientAuthorized can run before
 * OnClientPutInServer, the leader would then be a client that is not in game), and only during a
 * running match. */
public void OnClientPostAdminCheck(int client)
{
    if ( RestoreLevelOnReconnect && IsActive && !WarmupEnabled && !GameWinner && !IsFakeClient(client) )
    {
        char steamid[64];
        int level = 0;
        if ( GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid))
            && PlayerLevelsBeforeDisconnect.GetValue(steamid, level) )
        {
            if ( PlayerLevel[client] < level )
            {
                int oldLevel = PlayerLevel[client];
                PlayerLevel[client] = level;
                UTIL_RecalculateLeader(client, oldLevel, level);
                UTIL_FireLevelChanged(client, oldLevel, level, GGLevelReason_Reconnect);
            }
        }
    }

    UTIL_UpdatePlayerScoreLevel(client);
}

public void OnPluginEnd()
{
    gungame_enabled.IntValue = 0;
    /* Unloaded mid-map: give the buy zones back, players would keep their spawn pistols for ever. */
    if ( IsActive )
    {
        UTIL_EnableBuyZones();
    }
}

public void OnMapEnd()
{
    /* Kill timer on map change if was in warmup round. */
    delete WarmupTimer;

    /* Clear out data */
    WarmupInitialized = false;
    WarmupCounter = 0;
    MapStatus = 0;
    IsVotingCalled = false;
    g_isCalledEnableFriendlyFire = false;
    g_isCalledDisableRtv = false;
    GameWinner = 0;
    g_GameWinnerLeft = false;
    CurrentLeader = 0;
    g_MatchStarted = false;
    UTIL_ResetMatchKills();

    delete PlayerLevelsBeforeDisconnect;
    PlayerLevelsBeforeDisconnect = new StringMap();
    delete PlayerHandicapTimes;
    PlayerHandicapTimes = new StringMap();

    for ( Sounds i = Welcome; i < MaxSounds; i++ )
    {
        EventSounds[i][0] = '\0';
    }

    UnhookObjectiveEvents();
}

public void OnClientDisconnect(int client)
{
    /* The leaving player still holds his level here: FindLeader must skip him. */
    UTIL_LeaderLeft(client);

    if ( client == GameWinner )
    {
        g_GameWinnerLeft = true;
    }

    if ( AutoFriendlyFire && !FFA && (PlayerState[client] & GRENADE_LEVEL) )
    {
        PlayerState[client] &= ~GRENADE_LEVEL;

        if ( --PlayerOnGrenade < 1 )
        {
            UTIL_ChangeFriendlyFire(!g_cfgFriendlyFireOnOff);
        }
    }

    if ( IsClientConnected(client) && !IsFakeClient(client) )
    {
        char steamid[64];
        if ( GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)) )
        {
            PlayerLevelsBeforeDisconnect.SetValue(steamid, PlayerLevel[client]);
        }
    }

    PlayerLevel[client] = 0;
    CurrentKillsPerWeap[client] = 0;
    CurrentLevelPerRound[client] = 0;
    CurrentLevelPerRoundTriple[client] = 0;
    PlayerState[client] = 0;
    g_MatchKills[client] = 0;

    if ( IsClientInGame(client) && IsPlayerAlive(client) )
    {
        UTIL_StopTripleEffects(client);
    }
}

void HookObjectiveEvents()
{
    if ( (MapStatus & OBJECTIVE_BOMB) && !g_BombEventsHooked )
    {
        g_BombEventsHooked = true;
        HookEvent("bomb_planted", _BombState);
        HookEvent("bomb_exploded", _BombState);
        HookEvent("bomb_defused", _BombState);
        HookEvent("bomb_pickup", _BombPickup);
    }

    if ( (MapStatus & OBJECTIVE_HOSTAGE) && !g_HostageEventsHooked )
    {
        g_HostageEventsHooked = true;
        HookEvent("hostage_killed", _HostageKilled);
    }
}

void UnhookObjectiveEvents()
{
    if ( g_BombEventsHooked )
    {
        g_BombEventsHooked = false;
        UnhookEvent("bomb_planted", _BombState);
        UnhookEvent("bomb_exploded", _BombState);
        UnhookEvent("bomb_defused", _BombState);
        UnhookEvent("bomb_pickup", _BombPickup);
    }

    if ( g_HostageEventsHooked )
    {
        g_HostageEventsHooked = false;
        UnhookEvent("hostage_killed", _HostageKilled);
    }
}

public void GG_OnStartup(bool Command)
{
    if ( !IsActive )
    {
        IsActive = true;

        OnEventStart();
    }

    UTIL_DisableBuyZones();

    if ( !WarmupInitialized && WarmupEnabled )
    {
        StartWarmupRound();
    }

    UTIL_FindMapObjective();
    HookObjectiveEvents();

    char path[PLATFORM_MAX_PATH];
    for ( Sounds i = Welcome; i < MaxSounds; i++ )
    {
        if ( EventSounds[i][0] )
        {
            Format(path, sizeof(path), "sound/%s", EventSounds[i]);
            AddFileToDownloadsTable(path);
            PrecacheSound(EventSounds[i]);
        }
    }

    Tcount = 0;
    CTcount = 0;
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) )
        {
            switch ( GetClientTeam(i) )
            {
                case TEAM_T:
                {
                    Tcount++;
                }
                case TEAM_CT:
                {
                    CTcount++;
                }
            }
        }
    }

    if ( g_Cfg_HandicapUpdate > 0.0 )
    {
        StartHandicapUpdate();
    }
    else
    {
        StopHandicapUpdate();
    }

    /* No warmup: the match starts right away. */
    if ( !WarmupEnabled )
    {
        TryStartMatch();
    }
}

public void GG_OnShutdown(bool Command)
{
    if ( !IsActive )
    {
        return;
    }

    UTIL_EnableBuyZones();

    IsActive = false;
    InternalIsActive = false;
    WarmupInitialized = false;
    WarmupCounter = 0;
    IsVotingCalled = false;
    g_isCalledEnableFriendlyFire = false;
    g_isCalledDisableRtv = false;
    GameWinner = 0;
    g_GameWinnerLeft = false;
    CurrentLeader = 0;
    g_MatchStarted = false;
    UTIL_ResetMatchKills();

    delete PlayerLevelsBeforeDisconnect;
    PlayerLevelsBeforeDisconnect = new StringMap();
    delete PlayerHandicapTimes;
    PlayerHandicapTimes = new StringMap();

    OnEventShutdown();
    StopHandicapUpdate();

    if ( Command )
    {
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) )
            {
                OnClientDisconnect(i);
            }
        }

        delete WarmupTimer;
    }

    UnhookObjectiveEvents();
}

/**
 * Fires GG_OnMatchStart once per match.
 */
void TryStartMatch()
{
    if ( g_MatchStarted || !IsActive || WarmupEnabled )
    {
        return;
    }

    g_MatchStarted = true;
    UTIL_ResetMatchKills();

    Call_StartForward(FwdMatchStart);
    Call_Finish();
}

/**
 * Print messages to chat about leaders.
 *
 * @param client
 * @param oldLevel
 * @param newLevel
 * @param name
 */
void PrintLeaderToChat(int client, int oldLevel, int newLevel, const char[] name)
{
    if ( !CurrentLeader || newLevel <= oldLevel )
    {
        return;
    }
    // newLevel > oldLevel
    if ( CurrentLeader == client )
    {
        // say leading on level X
        if ( g_Cfg_ShowLeaderWeapon ) {
            CPrintToChatAllEx(client, "%t", "Is leading on level weapon", name, newLevel + 1, WeaponOrderName[newLevel]);
        } else {
            CPrintToChatAllEx(client, "%t", "Is leading on level", name, newLevel + 1);
        }
        return;
    }
    // CurrentLeader != client
    if ( newLevel < PlayerLevel[CurrentLeader] )
    {
        // say how much to the lead
        char subtext[64];
        FormatLanguageNumberTextEx(client, subtext, sizeof(subtext), PlayerLevel[CurrentLeader]-newLevel, "levels");
        CPrintToChat(client, "%t", "You are levels behind leader", subtext);
        return;
    }
    // new level == leader level
    // say tied to the lead on level X
    CPrintToChatAllEx(client, "%t", "Is tied with the leader on level", name, newLevel + 1);
}

void StartWarmupRound()
{
    WarmupInitialized = true;
    PrintToServer("[GunGame] Warmup round has started.");
    char subtext[64];
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) )
        {
            SetGlobalTransTarget(i);
            FormatLanguageNumberTextEx(i, subtext, sizeof(subtext), Warmup_TimeLength - WarmupCounter, "seconds left");
            PrintHintText(i, "%t", "Warmup round seconds left", subtext);
        }
    }

    /* Start Warmup round */
    delete WarmupTimer;
    WarmupTimer = CreateTimer(1.0, EndOfWarmup, _, TIMER_REPEAT);

    Call_StartForward(FwdWarmupStart);
    Call_Finish();
}

/* End of Warmup */
public Action EndOfWarmup(Handle timer)
{
    if ( ++WarmupCounter <= Warmup_TimeLength )
    {
        if ( Warmup_TimeLength - WarmupCounter < 5)
        {
            UTIL_PlaySound(0, WarmupTimerSound);
        }
        char subtext[64];
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) )
            {
                SetGlobalTransTarget(i);
                FormatLanguageNumberTextEx(i, subtext, sizeof(subtext), Warmup_TimeLength - WarmupCounter, "seconds left");
                PrintHintText(i, "%t", "Warmup round seconds left", subtext);
            }
        }
        return Plugin_Continue;
    }

    WarmupTimer = null;
    // Delayed warmup ending: warmup is disabled on the next round start
    DisableWarmupOnRoundEnd = true;

    /* Restart Game */
    mp_restartgame.IntValue = 1;

    CPrintToChatAll("%t", "Warmup round has ended");

    for ( int i = 1; i <= MaxClients; i++ )
    {
        PlayerLevel[i] = 0;
        UTIL_UpdatePlayerScoreLevel(i);
    }

    Call_StartForward(FwdWarmupEnd);
    Call_Finish();

    return Plugin_Stop;
}

void StartHandicapUpdate()
{
    if ( g_Timer_HandicapUpdate != null )
    {
        return;
    }
    g_Timer_HandicapUpdate = CreateTimer(g_Cfg_HandicapUpdate, Timer_HandicapUpdate, _, TIMER_REPEAT);
}

void StopHandicapUpdate()
{
    delete g_Timer_HandicapUpdate;
}

public Action Timer_HandicapUpdate(Handle timer)
{
    if ( WarmupEnabled || !HandicapMode )
    {
        return Plugin_Continue;
    }

    // get very minimum level
    int minimum = UTIL_GetMinimumLevel(g_Cfg_HandicapSkipBots);
    if ( minimum == -1 ) {
        return Plugin_Continue;
    }
    // get handicap level for players above very minimum level
    int level = UTIL_GetHandicapLevel(0, minimum);
    if ( level <= minimum ) {
        return Plugin_Continue;
    }

    for ( int i = 1; i <= MaxClients; i++ )
    {
        /* Only players in a team (not spectators, unassigned players or SourceTV). */
        if ( IsClientInGame(i) && GetClientTeam(i) >= TEAM_T && (PlayerLevel[i] == minimum) )
        {
            if ( g_Cfg_HandicapSkipBots && IsFakeClient(i) ) {
                continue;
            }
            if ( !IsFakeClient(i)
                 && !TopRankHandicap
                 && StatsEnabled
                 && ( !GG_IsPlayerWinsLoaded(i) /* HINT: gungame_stats */
                    || GG_IsPlayerInTopRank(i) ) /* HINT: gungame_stats */
            )
            {
                continue;
            }
            if ( !UTIL_ConsumeHandicapTime(i) ) {
                continue;
            }
            int oldLevel = PlayerLevel[i];
            PlayerLevel[i] = level;
            CurrentKillsPerWeap[i] = 0;
            CPrintToChat(i, "%t", "Your level has been updated by handicap");
            if ( TurboMode && IsPlayerAlive(i) )
            {
                UTIL_GiveNextWeapon(i, level);
            }
            UTIL_UpdatePlayerScoreLevel(i);
            UTIL_RecalculateLeader(i, oldLevel, level);
            UTIL_FireLevelChanged(i, oldLevel, level, GGLevelReason_Handicap);
        }
    }

    return Plugin_Continue;
}

public void GG_OnLoadPlayerWins(int client)
{
    if ( !(PlayerState[client] & FIRST_JOIN) )
    {
        return;
    }
    if ( UTIL_SetHandicapForClient(client) && IsClientInGame(client) && IsPlayerAlive(client) )
    {
        UTIL_GiveNextWeapon(client, PlayerLevel[client]);
    }
}

public void OnMapStart()
{
    PrecacheModel(MULTI_LEVEL_EFFECT2);
    PrecacheModel(MULTI_LEVEL_EFFECT1);
    PrecacheModel("materials/sprites/crystal_beam1.vmt");
}
