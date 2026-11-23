#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <gungame_const>
#include <gungame>
#include <gungame_config>

bool AfkManagement;
int AfkDeaths;
int AfkAction;
int AfkReload;
bool IsActive;

/* AFK = no input at all between the spawn and the death. The spawn position cannot be used:
 * deathmatch plugins teleport players to a random spawn point after player_spawn. */
#define AFK_MIN_ALIVE_TIME  5.0   /* a death this soon after the spawn never counts as AFK */
#define AFK_INPUT_BUTTONS   (IN_ATTACK|IN_ATTACK2|IN_JUMP|IN_DUCK|IN_FORWARD|IN_BACK|IN_MOVELEFT|IN_MOVERIGHT|IN_USE|IN_RELOAD|IN_SPEED|IN_WALK)

bool PlayerHadInput[MAXPLAYERS + 1];
float PlayerSpawnTime[MAXPLAYERS + 1];
int PlayerAfkCount[MAXPLAYERS + 1];

State ConfigState;

public Plugin myinfo =
{
    name = "GunGame:SM Afk Management",
    author = GUNGAME_AUTHOR,
    description = "GunGame:SM Afk Management System",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

bool g_LateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_LateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("gungame_afk.phrases");
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

public void GG_OnStartup(bool Command)
{
    if ( !IsActive )
    {
        HookEvent("player_spawn", _PlayerSpawn);
        IsActive = true;
    }
}

public void GG_OnShutdown(bool Command)
{
    if ( IsActive )
    {
        UnhookEvent("player_spawn", _PlayerSpawn);
        IsActive = false;
    }
}

public void _PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if ( !IsActive || !AfkManagement )
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if ( !client || IsFakeClient(client) )
    {
        return;
    }

    PlayerHadInput[client] = false;
    PlayerSpawnTime[client] = GetGameTime();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if ( !IsActive || !AfkManagement || PlayerHadInput[client] || IsFakeClient(client) )
    {
        return Plugin_Continue;
    }

    if ( (buttons & AFK_INPUT_BUTTONS) || mouse[0] || mouse[1] )
    {
        PlayerHadInput[client] = true;
    }
    return Plugin_Continue;
}

public Action GG_OnClientDeath(int Killer, int Victim, int WeaponId, bool TeamKilled)
{
    /* Afk management only checks after the player worldspawn/suicide checks */
    if ( !AfkManagement || IsFakeClient(Victim) )
    {
        return Plugin_Continue;
    }

    if ( !PlayerHadInput[Victim] && GetGameTime() - PlayerSpawnTime[Victim] >= AFK_MIN_ALIVE_TIME )
    {
        /* You killed an afk. */
        CPrintToChat(Killer, "%t", "You do not gain a level because you killed an afk");

        if ( AfkAction && (++PlayerAfkCount[Victim] >= AfkDeaths) )
        {
            if ( AfkAction & AFK_KICK )
            {
                KickClient(Victim, "%T", "Kick: Max afk deaths reached", Victim);
            }
            else if ( AfkAction & AFK_SPECTATE )
            {
                ChangeClientTeam(Victim, TEAM_SPECTATOR);
                PlayerAfkCount[Victim] = 0;
            }
        }

        if ( AfkReload )
        {
            return Plugin_Changed;
        }

        return Plugin_Handled;
    }

    PlayerAfkCount[Victim] = 0;
    return Plugin_Continue;
}

public void GG_ConfigNewSection(const char[] name)
{
    if ( strcmp("Config", name, false) == 0 )
    {
        ConfigState = CONFIG_STATE_CONFIG;
    }
}

public void GG_ConfigKeyValue(const char[] key, const char[] value)
{
    if ( ConfigState == CONFIG_STATE_CONFIG )
    {
        if ( strcmp("AfkManagement", key, false) == 0 ) {
            AfkManagement = StringToInt(value) != 0;
        } else if ( strcmp("AfkDeaths", key, false) == 0 ) {
            AfkDeaths = StringToInt(value);
        } else if ( strcmp("AfkAction", key, false) == 0 ) {
            AfkAction = StringToInt(value);
        } else if ( strcmp("AfkReload", key, false) == 0 ) {
            AfkReload = StringToInt(value);
        }
    }
}

public void GG_ConfigParseEnd()
{
    ConfigState = CONFIG_STATE_NONE;
}

public void OnClientConnected(int client)
{
    PlayerAfkCount[client] = 0;
    /* Unknown until the first spawn: never AFK. */
    PlayerHadInput[client] = true;
    PlayerSpawnTime[client] = 0.0;
}
