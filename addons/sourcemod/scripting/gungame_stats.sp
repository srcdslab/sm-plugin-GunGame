#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <gungame_const>
#include <gungame>
#include <gungame_stats>
#include <gungame_config>
#include <langutils>

#include "gungame_stats/globals.sp"
#include "gungame_stats/sql.sp"
#include "gungame_stats/menu.sp"

public Plugin myinfo =
{
    name = "GunGame:SM Stats",
    author = GUNGAME_AUTHOR,
    description = "Stats for GunGame:SM",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

bool g_LateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_LateLoad = late;
    RegPluginLibrary("gungame_st");
    OnCreateNatives();
    return APLRes_Success;
}

public void OnPluginStart()
{
    FwdLoadRank = new GlobalForward("GG_OnLoadRank", ET_Ignore);
    FwdLoadPlayerWins = new GlobalForward("GG_OnLoadPlayerWins", ET_Ignore, Param_Cell);

    LoadTranslations("gungame_stats.phrases");

    RegConsoleCmd("top10", _CmdTop);
    RegConsoleCmd("top", _CmdTop);
    RegConsoleCmd("rank", _CmdRank);
    RegAdminCmd("gg_rebuild", _CmdRebuild, GUNGAME_ADMINFLAG, "Rebuilds the top rank from the player data information");
    RegAdminCmd("gg_import", _CmdImport, GUNGAME_ADMINFLAG, "Imports the winners file from es gungame.");
    RegAdminCmd("gg_reset", _CmdReset, GUNGAME_ADMINFLAG, "Reset all gungame stats.");
    RegAdminCmd("gg_importdb", _CmdImportDb, GUNGAME_ADMINFLAG, "Imports the winners from gungame players data file into database.");

    SqlConnect();
}

/* Reloaded mid-map: GG_OnStartup was fired before we were loaded. Config values come back at the
 * next map change. */
public void OnAllPluginsLoaded()
{
    ConVar enabled = FindConVar("gungame_enabled");
    if ( g_LateLoad && enabled != null && enabled.BoolValue )
    {
        GG_OnStartup(false);
    }
}

public void OnClientAuthorized(int client, const char[] auth)
{
    RetrieveKeyValues(client);
}

public void OnMapStart()
{
    SaveProcess = false;
}

public void OnMapEnd()
{
    EndProcess();
}

public void OnPluginEnd()
{
    EndProcess();
}

public void GG_OnStartup(bool Command)
{
    if ( !IsActive )
    {
        IsActive = true;
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientConnected(i) && IsClientAuthorized(i) )
            {
                RetrieveKeyValues(i);
            }
        }
    }
}

public void GG_OnShutdown(bool Command)
{
    if ( IsActive )
    {
        IsActive = false;

        EndProcess();

        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) )
            {
                OnClientDisconnect(i);
            }
        }
    }
}

public void OnClientDisconnect(int client)
{
    g_PlayerWinsLoaded[client] = false;
    PlayerWinsData[client] = 0;
    PlayerPlaceData[client] = 0;
}

public Action _CmdTop(int client, int args)
{
    if ( IsActive && client )
    {
        ShowTopMenu(client);
    }
    return Plugin_Handled;
}

public Action _CmdRank(int client, int args)
{
    if ( IsActive && client )
    {
        ShowRank(client);
    }
    return Plugin_Handled;
}

void EndProcess()
{
    if ( SaveProcess )
    {
        return;
    }

    SaveProcess = true;
    SavePlayerDataInfo();
}

public void GG_OnWinner(int client, const char[] Weapon, int victim)
{
    if ( IsClientInGame(client) && !IsFakeClient(client) )
    {
        if ( g_Cfg_DontAddWinsOnBot && victim && IsClientInGame(victim) && IsFakeClient(victim) )
        {
            /* The win is not saved, but GG_OnLoadRank listeners (display winner) still wait for it. */
            LoadRankOrFire();
            return;
        }

        ++PlayerWinsData[client];
        if ( !SavePlayerData(client) )
        {
            LoadRankOrFire();
        }
    }
}

/**
 * Config
 */

public void GG_ConfigNewSection(const char[] NewSection)
{
    if ( strcmp(NewSection, "Config", false) == 0 )
    {
        ConfigState = CONFIG_STATE_CONFIG;
    }
}

public void GG_ConfigKeyValue(const char[] Key, const char[] Value)
{
    if ( ConfigState == CONFIG_STATE_CONFIG )
    {
        if ( strcmp(Key, "Prune", false) == 0 ) {
            Prune = StringToInt(Value);
        } else if ( strcmp(Key, "HandicapTopRank", false) == 0 ) {
            g_cfgHandicapTopRank = StringToInt(Value);
        } else if ( strcmp(Key, "DontAddWinsOnBot", false) == 0 ) {
            g_Cfg_DontAddWinsOnBot = StringToInt(Value) != 0;
        }
    }
}

public void GG_ConfigParseEnd()
{
    ConfigState = CONFIG_STATE_NONE;
}

/**
 * Natives
 */

void OnCreateNatives()
{
    CreateNative("GG_DisplayTop", __DisplayTop);
    CreateNative("GG_GetClientWins", __GetPlayerWins);
    CreateNative("GG_CountPlayersInStat", __CountPlayersInStat);
    CreateNative("GG_GetPlayerPlaceInStat", __GetPlayerPlaceInStat);
    CreateNative("GG_IsPlayerInTopRank", __IsPlayerInTopRank);
    CreateNative("GG_IsPlayerWinsLoaded", __IsPlayerWinsLoaded);
    CreateNative("GG_ShowRank", __ShowRank);
}

bool CheckNativeClient(int client)
{
    if ( client < 1 || client > MaxClients )
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index [%d]", client);
        return false;
    }
    if ( !IsClientInGame(client) )
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Client is not currently ingame [%d]", client);
        return false;
    }
    return true;
}

public int __DisplayTop(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    ShowTopMenu(client);
    return 1;
}

public int __ShowRank(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    ShowRank(client);
    return 1;
}

public int __GetPlayerPlaceInStat(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    return GetPlayerPlaceInStat(client);
}

public int __CountPlayersInStat(Handle plugin, int numParams)
{
    return TotalWinners;
}

public int __GetPlayerWins(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    return PlayerWinsData[client];
}

public int __IsPlayerInTopRank(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    return IsPlayerInTopRank(client);
}

public int __IsPlayerWinsLoaded(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if ( !CheckNativeClient(client) )
    {
        return 0;
    }

    return g_PlayerWinsLoaded[client];
}
