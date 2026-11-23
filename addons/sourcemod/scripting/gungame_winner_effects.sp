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
    description = "Show winner effects on gungame win, fireworks at match end and on level up",
    version     = GUNGAME_VERSION,
    url         = GUNGAME_URL
};

/*----------------------------------------------------------------------+
| INIT VARS                                                             |
+----------------------------------------------------------------------*/
#define SPRITE_CSS      "sprites/orangeglow1.vmt"

/* Fireworks: temp entities only, CS:S has no firework particle system.
 * Every material and sound below ships with the game. */
#define FW_BEAM         "materials/sprites/laserbeam.vmt"
#define FW_HALO         "materials/sprites/halo01.vmt"
#define FW_GLOW         "materials/sprites/glow01.vmt"
#define FW_SOUND_1      "weapons/flashbang/flashbang_explode1.wav"
#define FW_SOUND_2      "weapons/flashbang/flashbang_explode2.wav"

#define FW_MODE_OFF         0
#define FW_MODE_MATCH_END   1
#define FW_MODE_WINNER      2
#define FW_MODE_LEVEL_UP    3

/* The match end show launches its rockets over FW_SHOW_WINDOW seconds: with the rise time and
 * the burst life the last burst is gone after ~6.5 s, inside the 7 s intermission (mp_chattime). */
#define FW_SHOW_WINDOW      5.0
/* Minimum time between two bursts. A big burst is 17 temp entities; the engine sends at most
 * sv_multiplayer_maxtempentities (32) per snapshot and drops the rest, so two bursts may share
 * a snapshot only for clients under 25 updates per second. */
#define FW_MIN_SPACING      0.04
/* FW_SHOW_WINDOW / FW_MIN_SPACING: more rockets would not fit in the window. */
#define FW_MAX_SHOW_ROCKETS 125
#define FW_TRAIL_STEPS      5
#define FW_BIG_RISE         0.6
#define FW_SMALL_RISE       0.4
#define FW_BIG_BEAMS        14
#define FW_SMALL_BEAMS      8

/* Confetti: big spark showers (TE_SetupSparks) over the players at match end, like the
 * TopDefenders crown on Zombie Revival (magnitude 1000, trail 200). Sparks are drawn by the
 * client, one temp entity each; the winner gets CONFETTI_WINNER_SHOWERS of them. */
#define CONFETTI_HEIGHT          80.0
#define CONFETTI_WINNER_SHOWERS  5
#define CONFETTI_WINNER_INTERVAL 0.9
#define CONFETTI_WINNER_MAGNITUDE 1000
#define CONFETTI_PLAYER_MAGNITUDE 400
#define CONFETTI_TRAIL           200
#define FW_BIG_RADIUS       140.0
#define FW_SMALL_RADIUS     60.0
/* Bursts stay this far under a ceiling found by the trace (indoor maps). */
#define FW_CEILING_MARGIN   40.0
/* One bang at most every FW_SOUND_INTERVAL seconds, a show of 100 bursts must not deafen. */
#define FW_SOUND_INTERVAL   0.15
/* A level up gives one rocket per level gained, up to this many (knife steal, multi level). */
#define FW_MAX_LEVEL_UP_ROCKETS 3

enum struct Rocket
{
    int userid;
    bool big;
    bool launched;
    int trailSteps;
    float launchTime;
    float burstTime;
    float radius;
    float ground[3];
    float burst[3];
}

/* Bright colors only: dark ones do not show against the sky. */
int g_FwColors[][4] = {
    {255,  40,  40, 255},
    {255, 150,   0, 255},
    {255, 240,  60, 255},
    { 60, 255,  60, 255},
    { 40, 220, 255, 255},
    { 80, 100, 255, 255},
    {200,  70, 255, 255},
    {255,  70, 200, 255},
    {255, 255, 255, 255}
};
int g_FwTrailColor[4] = {255, 190, 110, 255};

ConVar g_cvFireworksMode;
ConVar g_cvFireworksBursts;
ConVar g_cvConfetti;
ArrayList g_Rockets;
/* Queued confetti showers: {userid, game time, magnitude} */
ArrayList g_Confetti;
int g_BeamSprite            = -1;
int g_HaloSprite            = -1;
int g_FwGlowSprite          = -1;
bool g_bShowDone            = false;
float g_fNextBurstSlot      = 0.0;
float g_fNextSoundTime      = 0.0;

State g_ConfigState         = CONFIG_STATE_NONE;
int g_Cfg_WinnerEffect      = 0;
int g_GlowSprite            = -1;
int g_winner                = 0; /* userid */

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

    g_BeamSprite = PrecacheModel(FW_BEAM);
    g_HaloSprite = PrecacheModel(FW_HALO);
    g_FwGlowSprite = PrecacheModel(FW_GLOW);
    PrecacheSound(FW_SOUND_1);
    PrecacheSound(FW_SOUND_2);

    /* The game time restarts at 0 on every map. */
    FireworksReset();
}

public void OnMapEnd()
{
    FireworksReset();
}

public void OnPluginStart()
{
    g_cvFireworksMode = CreateConVar("gg_fireworks_mode", "1", "Fireworks: 0 = off, 1 = at match end (GunGame win or time limit), 2 = GunGame winner only, 3 = on every level up and at match end", _, true, 0.0, true, 3.0);
    g_cvFireworksBursts = CreateConVar("gg_fireworks_bursts", "3", "Rockets over each player in the match end show (the winner gets twice as many); lowered automatically on a full server", _, true, 1.0, true, 10.0);
    g_cvConfetti = CreateConVar("gg_confetti", "1", "Confetti (big spark showers) with the match end fireworks: several over the winner, one over every other alive player", _, true, 0.0, true, 1.0);
    AutoExecConfig(true);

    g_Rockets = new ArrayList(sizeof(Rocket));
    g_Confetti = new ArrayList(3);

    HookEvent("player_spawn", Event_PlayerSpawn);
    /* Fired by CS:S when the match ends (time limit or game_end), also after a GunGame win:
     * the show runs once per match end (g_bShowDone). */
    HookEventEx("cs_win_panel_match", Event_WinPanelMatch, EventHookMode_PostNoCopy);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if ( !g_Cfg_WinnerEffect || !g_winner ) {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    /* A userid: a new player in the winner's slot must not get his effects. */
    int winner = GetClientOfUserId(g_winner);
    if ( !client || !winner ) {
        return;
    }

    WinnerEffectsStartOne(winner, client);
}

/*----------------------------------------------------------------------+
| GUNGAME EVENTS                                                        |
+----------------------------------------------------------------------*/
public void GG_OnStartup(bool Command)
{
    g_winner = 0;
    FireworksReset();
}

public void GG_OnMatchStart()
{
    /* gg_restart starts a new match on the same map: it gets its own show. */
    FireworksReset();
}

public void GG_OnWinner(int client, const char[] Weapon, int victim)
{
    int mode = g_cvFireworksMode.IntValue;
    if ( mode != FW_MODE_OFF ) {
        FireworksShow(client);
    }

    if ( !g_Cfg_WinnerEffect ) {
        return;
    }

    g_winner = GetClientUserId(client);
    WinnerEffectsStart(client);
}

public void GG_OnClientLevelChanged(int client, int oldLevel, int newLevel, const char[] weapon, GGLevelReason reason)
{
    /* The post forward, not GG_OnClientLevelChange: another plugin can still block the change
     * in the pre-hook. Not called for the winning kill, the match end show covers it. */
    if ( g_cvFireworksMode.IntValue != FW_MODE_LEVEL_UP || newLevel <= oldLevel || g_bShowDone ) {
        return;
    }

    /* Levels earned in play only: handicap and reconnect restores happen when a player joins
     * or spawns, admin and native changes are not an achievement. */
    if ( reason != GGLevelReason_Kill && reason != GGLevelReason_KnifeSteal && reason != GGLevelReason_Objective ) {
        return;
    }

    int rockets = newLevel - oldLevel;
    if ( rockets > FW_MAX_LEVEL_UP_ROCKETS ) {
        rockets = FW_MAX_LEVEL_UP_ROCKETS;
    }
    for ( int i = 0; i < rockets; i++ ) {
        FireworksQueue(client, false, FW_MIN_SPACING);
    }
}

public void Event_WinPanelMatch(Event event, const char[] name, bool dontBroadcast)
{
    int mode = g_cvFireworksMode.IntValue;
    if ( mode == FW_MODE_MATCH_END || mode == FW_MODE_LEVEL_UP ) {
        FireworksShow(0);
    }
}

public void OnGameFrame()
{
    if ( g_Confetti != null && g_Confetti.Length ) {
        ConfettiProcess(GetGameTime());
    }

    if ( g_Rockets == null || !g_Rockets.Length ) {
        return;
    }

    if ( g_cvFireworksMode.IntValue == FW_MODE_OFF ) {
        delete g_Rockets;
        g_Rockets = new ArrayList(sizeof(Rocket));
        return;
    }

    FireworksProcess(GetGameTime());
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

/*----------------------------------------------------------------------+
| FIREWORKS                                                             |
+----------------------------------------------------------------------*/
void FireworksReset()
{
    g_bShowDone = false;
    g_fNextBurstSlot = 0.0;
    g_fNextSoundTime = 0.0;
    if ( g_Rockets != null ) {
        delete g_Rockets;
        g_Rockets = new ArrayList(sizeof(Rocket));
    }
    if ( g_Confetti != null ) {
        delete g_Confetti;
        g_Confetti = new ArrayList(3);
    }
}

/**
 * Big show over the winner (if any, twice as many rockets) and every alive player.
 * Once per match end: a GunGame win is followed by cs_win_panel_match.
 */
void FireworksShow(int winner)
{
    if ( g_bShowDone ) {
        return;
    }
    g_bShowDone = true;

    int targets[MAXPLAYERS + 1];
    int count = 0;
    bool winnerAlive = false;
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( !IsClientInGame(i) || !IsPlayerAlive(i) ) {
            continue;
        }
        targets[count++] = i;
        if ( i == winner ) {
            winnerAlive = true;
        }
    }
    if ( !count ) {
        return;
    }

    /* Lower the rockets per player until the show fits in the window with FW_MIN_SPACING. */
    int perPlayer = g_cvFireworksBursts.IntValue;
    int total = (count + (winnerAlive ? 1 : 0)) * perPlayer;
    while ( total > FW_MAX_SHOW_ROCKETS && perPlayer > 1 ) {
        perPlayer--;
        total = (count + (winnerAlive ? 1 : 0)) * perPlayer;
    }

    if ( g_cvConfetti.BoolValue ) {
        ConfettiQueueShow(targets, count, winnerAlive ? winner : 0);
    }

    float spacing = FW_SHOW_WINDOW / float(total);
    if ( spacing < FW_MIN_SPACING ) {
        spacing = FW_MIN_SPACING;
    }

    /* Waves: every player gets one rocket per wave, in a random order. */
    for ( int wave = 0; wave < perPlayer; wave++ ) {
        for ( int i = count - 1; i > 0; i-- ) {
            int j = GetRandomInt(0, i);
            int tmp = targets[i];
            targets[i] = targets[j];
            targets[j] = tmp;
        }
        for ( int i = 0; i < count; i++ ) {
            FireworksQueue(targets[i], true, spacing);
            if ( targets[i] == winner ) {
                FireworksQueue(targets[i], true, spacing);
            }
        }
    }
}

/**
 * Queues one rocket over a player. The burst times of all rockets are kept at least
 * `spacing` apart (shared slot), which caps the temp entities sent per snapshot.
 */
void FireworksQueue(int client, bool big, float spacing)
{
    float rise = big ? FW_BIG_RISE : FW_SMALL_RISE;
    float burstTime = GetGameTime() + rise;
    if ( burstTime < g_fNextBurstSlot ) {
        burstTime = g_fNextBurstSlot;
    }
    g_fNextBurstSlot = burstTime + spacing;

    Rocket rocket;
    rocket.userid = GetClientUserId(client);
    rocket.big = big;
    rocket.launched = false;
    rocket.trailSteps = 0;
    rocket.launchTime = burstTime - rise;
    rocket.burstTime = burstTime;
    g_Rockets.PushArray(rocket);
}

void FireworksProcess(float now)
{
    Rocket rocket;
    int i = 0;
    while ( i < g_Rockets.Length ) {
        g_Rockets.GetArray(i, rocket);
        if ( now < rocket.launchTime ) {
            i++;
            continue;
        }

        if ( !rocket.launched ) {
            /* The burst point is taken at launch: the player moved since the rocket was queued. */
            if ( !FireworksLaunch(rocket) ) {
                g_Rockets.Erase(i);
                continue;
            }
            rocket.launched = true;
        }

        if ( now >= rocket.burstTime ) {
            FireworksBurst(rocket, now);
            g_Rockets.Erase(i);
            continue;
        }

        /* Draw the trail in FW_TRAIL_STEPS segments over the rise time, so it climbs. */
        float stepTime = (rocket.burstTime - rocket.launchTime) / float(FW_TRAIL_STEPS);
        int step = RoundToFloor((now - rocket.launchTime) / stepTime);
        if ( step >= FW_TRAIL_STEPS ) {
            step = FW_TRAIL_STEPS - 1;
        }
        while ( rocket.trailSteps <= step ) {
            FireworksTrail(rocket, rocket.trailSteps);
            rocket.trailSteps++;
        }

        g_Rockets.SetArray(i, rocket);
        i++;
    }
}

bool FireworksLaunch(Rocket rocket)
{
    int client = GetClientOfUserId(rocket.userid);
    if ( !client || !IsClientInGame(client) || !IsPlayerAlive(client) ) {
        return false;
    }

    float eye[3], top[3];
    GetClientAbsOrigin(client, rocket.ground);
    rocket.ground[2] += 8.0;
    GetClientEyePosition(client, eye);

    float height, maxRadius;
    top = eye;
    if ( rocket.big ) {
        /* A little sideways too, so several rockets over one player do not overlap. */
        height = GetRandomFloat(260.0, 340.0);
        top[0] += GetRandomFloat(-60.0, 60.0);
        top[1] += GetRandomFloat(-60.0, 60.0);
        maxRadius = FW_BIG_RADIUS;
    } else {
        height = GetRandomFloat(130.0, 160.0);
        maxRadius = FW_SMALL_RADIUS;
    }
    top[2] += height;

    /* Stop under a ceiling (or a wall for the sideways offset); players do not block it. */
    TR_TraceRayFilter(eye, top, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Filter_NoPlayers);
    float end[3];
    TR_GetEndPosition(end);

    float ray[3];
    SubtractVectors(end, eye, ray);
    float dist = GetVectorLength(ray);
    float full = GetVectorDistance(eye, top);
    if ( dist < 1.0 ) {
        /* Head against a ceiling: no room for a rocket. */
        return false;
    }

    /* Burst FW_CEILING_MARGIN before the hit, but at least half way up. */
    float frac = (dist - FW_CEILING_MARGIN) / dist;
    if ( frac < 0.5 ) {
        frac = 0.5;
    }
    ScaleVector(ray, frac);
    AddVectors(eye, ray, rocket.burst);

    /* Smaller bursts in low rooms. */
    float scale = dist / full;
    if ( scale < 0.35 ) {
        scale = 0.35;
    }
    rocket.radius = maxRadius * scale;
    return true;
}

public bool Filter_NoPlayers(int entity, int contentsMask)
{
    return entity < 1 || entity > MaxClients;
}

void FireworksTrail(Rocket rocket, int step)
{
    float from[3], to[3], path[3];
    SubtractVectors(rocket.burst, rocket.ground, path);

    from = path;
    ScaleVector(from, float(step) / float(FW_TRAIL_STEPS));
    AddVectors(rocket.ground, from, from);

    to = path;
    ScaleVector(to, float(step + 1) / float(FW_TRAIL_STEPS));
    AddVectors(rocket.ground, to, to);

    /* Thin at the bottom, wider at the head; lives long enough for the trail to build up. */
    TE_SetupBeamPoints(from, to, g_BeamSprite, g_HaloSprite, 0, 0, 0.35, 1.0, 2.5, 0, 0.5, g_FwTrailColor, 0);
    TE_SendToAll();
    TE_SetupGlowSprite(to, g_FwGlowSprite, 0.12, 0.25, 180);
    TE_SendToAll();
}

void FireworksBurst(Rocket rocket, float now)
{
    int beams = rocket.big ? FW_BIG_BEAMS : FW_SMALL_BEAMS;
    float life = rocket.big ? 0.8 : 0.55;
    float width = rocket.big ? 3.0 : 2.0;

    /* One or two colors per burst. */
    int color1 = GetRandomInt(0, sizeof(g_FwColors) - 1);
    int color2 = GetRandomInt(0, 1) ? GetRandomInt(0, sizeof(g_FwColors) - 1) : color1;

    /* Directions spread evenly on a sphere (golden angle spiral), randomly rotated. */
    float yaw = GetRandomFloat(0.0, 6.2832);
    float dir[3], start[3], end[3];
    for ( int i = 0; i < beams; i++ ) {
        float z = 1.0 - 2.0 * (float(i) + 0.5) / float(beams);
        float r = SquareRoot(1.0 - z * z);
        float phi = float(i) * 2.39996 + yaw;
        dir[0] = r * Cosine(phi);
        dir[1] = r * Sine(phi);
        dir[2] = z;

        start = dir;
        ScaleVector(start, rocket.radius * 0.2);
        AddVectors(rocket.burst, start, start);

        end = dir;
        ScaleVector(end, rocket.radius * GetRandomFloat(0.8, 1.0));
        AddVectors(rocket.burst, end, end);

        /* Wide at the center, thin at the tips. */
        TE_SetupBeamPoints(start, end, g_BeamSprite, g_HaloSprite, 0, 0, life, width, 0.5, 0, 0.0, g_FwColors[(i % 2) ? color2 : color1], 0);
        TE_SendToAll();
    }

    TE_SetupGlowSprite(rocket.burst, g_FwGlowSprite, rocket.big ? 0.3 : 0.2, rocket.big ? 2.5 : 1.2, 255);
    TE_SendToAll();

    float up[3] = {0.0, 0.0, 1.0};
    TE_SetupSparks(rocket.burst, up, rocket.big ? 8 : 4, rocket.big ? 3 : 2);
    TE_SendToAll();

    if ( rocket.big ) {
        TE_SetupBeamRingPoint(rocket.burst, 8.0, rocket.radius * 1.6, g_BeamSprite, g_HaloSprite, 0, 15, 0.45, 5.0, 0.0, g_FwColors[color1], 10, 0);
        TE_SendToAll();
    }

    if ( now >= g_fNextSoundTime ) {
        g_fNextSoundTime = now + FW_SOUND_INTERVAL;
        /* The flashbang bang, higher pitched for the small level up bursts. */
        EmitSoundToAll(GetRandomInt(0, 1) ? FW_SOUND_1 : FW_SOUND_2, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS,
            rocket.big ? 0.8 : 0.5, rocket.big ? GetRandomInt(85, 115) : GetRandomInt(115, 135), -1, rocket.burst);
    }
}

/*----------------------------------------------------------------------+
| CONFETTI                                                              |
+----------------------------------------------------------------------*/
/**
 * Showers over the winner every CONFETTI_WINNER_INTERVAL seconds, one smaller shower over every
 * other alive player at a random time of the show window.
 */
void ConfettiQueueShow(const int[] targets, int count, int winner)
{
    float now = GetGameTime();
    for ( int i = 0; i < count; i++ ) {
        if ( targets[i] == winner ) {
            for ( int n = 0; n < CONFETTI_WINNER_SHOWERS; n++ ) {
                ConfettiQueue(winner, now + 0.2 + float(n) * CONFETTI_WINNER_INTERVAL, CONFETTI_WINNER_MAGNITUDE);
            }
        } else {
            ConfettiQueue(targets[i], now + GetRandomFloat(0.3, FW_SHOW_WINDOW), CONFETTI_PLAYER_MAGNITUDE);
        }
    }
}

void ConfettiQueue(int client, float time, int magnitude)
{
    int index = g_Confetti.Push(GetClientUserId(client));
    g_Confetti.Set(index, time, 1);
    g_Confetti.Set(index, magnitude, 2);
}

void ConfettiProcess(float now)
{
    int i = 0;
    while ( i < g_Confetti.Length ) {
        if ( now < view_as<float>(g_Confetti.Get(i, 1)) ) {
            i++;
            continue;
        }

        int client = GetClientOfUserId(g_Confetti.Get(i, 0));
        int magnitude = g_Confetti.Get(i, 2);
        g_Confetti.Erase(i);
        if ( !client || !IsClientInGame(client) || !IsPlayerAlive(client) ) {
            continue;
        }

        float pos[3];
        GetClientAbsOrigin(client, pos);
        pos[2] += CONFETTI_HEIGHT;
        float up[3] = {0.0, 0.0, 1.0};
        TE_SetupSparks(pos, up, magnitude, CONFETTI_TRAIL);
        TE_SendToAll();
    }
}
