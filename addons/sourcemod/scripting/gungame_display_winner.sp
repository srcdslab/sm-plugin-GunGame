#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <gungame_const>
#include <gungame>
#include <gungame_stats>
#include <gungame_config>
#include <url>

char g_looserName[MAXPLAYERS+1][MAX_NAME_SIZE];
char g_winnerName[MAX_NAME_SIZE];
bool g_showWinnerOnRankUpdate = false;
int g_winner;

State ConfigState;
int g_Cfg_DisplayWinnerMotd = 0;
char g_Cfg_DisplayWinnerUrl[256];
int g_Cfg_ShowPlayerRankOnWin = 1;

public Plugin myinfo =
{
    name = "GunGame:SM Display Winner",
    description = "Shows a MOTD window with the winner's information when the game is won.",
    author = "bl4nk, Otstrel.ru Team",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if ( !g_Cfg_DisplayWinnerMotd )
    {
        return;
    }
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if ( !victim || !attacker )
    {
        return;
    }
    GetClientName(victim, g_looserName[attacker], sizeof(g_looserName[]));
}

public void GG_OnWinner(int client, const char[] weapon, int victim)
{
    if ( ( !g_Cfg_DisplayWinnerMotd && !g_Cfg_ShowPlayerRankOnWin ) || IsFakeClient(client) )
    {
        return;
    }
    GetClientName(client, g_winnerName, sizeof(g_winnerName));
    g_showWinnerOnRankUpdate = true;
    g_winner = GetClientUserId(client);
}

public void GG_OnLoadRank()
{
    if ( ( !g_Cfg_DisplayWinnerMotd && !g_Cfg_ShowPlayerRankOnWin ) || !g_showWinnerOnRankUpdate )
    {
        return;
    }
    g_showWinnerOnRankUpdate = false;

    int winner = GetClientOfUserId(g_winner);
    if ( !winner || !IsClientInGame(winner) )
    {
        return;
    }

    if ( g_Cfg_ShowPlayerRankOnWin )
    {
        GG_ShowRank(winner);                  /* HINT: gungame_stats */
    }
    if ( g_Cfg_DisplayWinnerMotd )
    {
        char url[128+sizeof(g_Cfg_DisplayWinnerUrl)];
        char winnerNameUrlEncoded[sizeof(g_winnerName)*3+1];
        char looserNameUrlEncoded[sizeof(g_looserName[])*3+1];
        url_encode(g_winnerName, sizeof(g_winnerName), winnerNameUrlEncoded, sizeof(winnerNameUrlEncoded));
        url_encode(g_looserName[winner], sizeof(g_looserName[]), looserNameUrlEncoded, sizeof(looserNameUrlEncoded));

        bool urlHasParams = (StrContains(g_Cfg_DisplayWinnerUrl, "?", true) != -1);

        Format(url, sizeof(url), "%s%swinnerName=%s&loserName=%s&wins=%i&place=%i&totalPlaces=%i",
            g_Cfg_DisplayWinnerUrl,
            urlHasParams ? "&" : "?",
            winnerNameUrlEncoded,
            looserNameUrlEncoded,
            GG_GetClientWins(winner),         /* HINT: gungame_stats */
            GG_GetPlayerPlaceInStat(winner),  /* HINT: gungame_stats */
            GG_CountPlayersInStat()           /* HINT: gungame_stats */
        );
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) && !IsFakeClient(i) )
            {
                ShowMOTDPanel(i, "", url, MOTDPANEL_TYPE_URL);
            }
        }
    }
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
        if ( strcmp("DisplayWinnerMotd", key, false) == 0 ) {
            g_Cfg_DisplayWinnerMotd = StringToInt(value);
        } else if ( strcmp("DisplayWinnerUrl", key, false) == 0 ) {
            strcopy(g_Cfg_DisplayWinnerUrl, sizeof(g_Cfg_DisplayWinnerUrl), value);
        } else if ( strcmp("ShowPlayerRankOnWin", key, false) == 0 ) {
            g_Cfg_ShowPlayerRankOnWin = StringToInt(value);
        }
    }
}

public void GG_ConfigParseEnd()
{
    ConfigState = CONFIG_STATE_NONE;
}

public void OnMapEnd()
{
    g_showWinnerOnRankUpdate = false;
}
