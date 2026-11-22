#pragma semicolon 1
#pragma newdecls required

/*----------------------------------------------------------------------+
| INCLUDES                                                              |
+----------------------------------------------------------------------*/
#include <sourcemod>
#include <sdktools>
#include <gungame_const>
#include <gungame>
#include <gungame_config>

/*----------------------------------------------------------------------+
| PLUGIN INFO                                                           |
+----------------------------------------------------------------------*/
public Plugin myinfo = {
    name        = "GunGame:SM Winner Effects",
    author      = GUNGAME_AUTHOR,
    description = "Show winner effects on gungame win",
    version     = GUNGAME_VERSION,
    url         = GUNGAME_URL
};

/*----------------------------------------------------------------------+
| INIT VARS                                                             |
+----------------------------------------------------------------------*/
#define SPRITE_CSS      "sprites/orangeglow1.vmt"

State g_ConfigState         = CONFIG_STATE_NONE;
int g_Cfg_WinnerEffect      = 0;
int g_GlowSprite            = -1;
int g_winner                = 0;

/*----------------------------------------------------------------------+
| LOAD CONFIG                                                           |
+----------------------------------------------------------------------*/
public void GG_ConfigNewSection(const char[] NewSection)
{
    if ( strcmp(NewSection, "Config", false) == 0 ) {
        g_ConfigState = CONFIG_STATE_CONFIG;
    }
}

public void GG_ConfigKeyValue(const char[] key, const char[] value)
{
    if ( g_ConfigState == CONFIG_STATE_CONFIG ) {
        if ( strcmp("WinnerEffect", key, false) == 0 ) {
            g_Cfg_WinnerEffect = StringToInt(value);
        }
    }
}

public void GG_ConfigParseEnd()
{
    g_ConfigState = CONFIG_STATE_NONE;
}

/*----------------------------------------------------------------------+
| PUBLIC EVENTS                                                         |
+----------------------------------------------------------------------*/
public void OnMapStart()
{
    g_winner = 0;
    g_GlowSprite = PrecacheModel(SPRITE_CSS);
}

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if ( !g_Cfg_WinnerEffect || !g_winner ) {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if ( !client ) {
        return;
    }

    WinnerEffectsStartOne(g_winner, client);
}

/*----------------------------------------------------------------------+
| GUNGAME EVENTS                                                        |
+----------------------------------------------------------------------*/
public void GG_OnStartup(bool Command)
{
    g_winner = 0;
}

public void GG_OnWinner(int client, const char[] Weapon, int victim)
{
    if ( !g_Cfg_WinnerEffect ) {
        return;
    }

    g_winner = client;
    WinnerEffectsStart(client);
}

/*----------------------------------------------------------------------+
| WINNER EFFECTS                                                        |
+----------------------------------------------------------------------*/
void WinnerEffectsStart(int winner)
{
    if ( g_Cfg_WinnerEffect == 1 ) {
        WinnerEffect(winner);
    }
}

void WinnerEffectsStartOne(int winner, int client)
{
    if ( g_Cfg_WinnerEffect == 1 ) {
        WinnerEffectOne(winner, client);
    }
}

void WinnerEffect(int winner)
{
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame(i) && IsPlayerAlive(i) ) {
            WinnerEffectOne(winner, i);
        }
    }
}

void WinnerEffectOne(int winner, int client)
{
    SetPlayerWinnerEffectAll(client);
    if ( winner == client ) {
        SetPlayerWinnerEffectWinner(client);
    }
}

void SetPlayerWinnerEffectAll(int client)
{
    // fly
    SetEntityGravity(client, 0.001);

    SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);

    float pos[3], vel[3];
    GetClientEyePosition(client, pos);

    vel[0] = GetRandomFloat(-10.0, 10.0);
    vel[1] = GetRandomFloat(-10.0, 10.0);
    vel[2] = GetRandomFloat(70.0, 120.0);

    TeleportEntity(client, pos, NULL_VECTOR, vel);
}

void SetPlayerWinnerEffectWinner(int client)
{
    CreateTimer(0.1, Timer_SetPlayerWinnerEffectWinner, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SetPlayerWinnerEffectWinner(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if ( !client || !IsClientInGame(client) || !IsPlayerAlive(client) ) {
        return Plugin_Stop;
    }
    SetPlayerWinnerEffectWinnerReal(client);
    return Plugin_Continue;
}

void SetPlayerWinnerEffectWinnerReal(int client)
{
    // shine
    float vec[3];
    GetClientAbsOrigin(client, vec);
    vec[2] += 40.0;

    TE_SetupGlowSprite(vec, g_GlowSprite, 0.5, 4.0, 70);
    TE_SendToAll();
}
