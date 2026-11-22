#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <gungame_const>
#include <gungame>
#include <gungame_stats>
#include <gungame_config>
#include <url>

/* Names are cut to this many bytes in the URL: UTF-8 names triple in size once encoded, and CS:S
 * drops a VGUI menu (MOTD) message over 255 bytes. */
#define URL_NAME_MAX_BYTES  32
#define MOTD_URL_MAX_LEN    240

char g_looserName[MAX_NAME_SIZE];
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


public void GG_OnWinner(int client, const char[] weapon, int victim)
{
    if ( ( !g_Cfg_DisplayWinnerMotd && !g_Cfg_ShowPlayerRankOnWin ) || IsFakeClient(client) )
    {
        return;
    }
    GetClientName(client, g_winnerName, sizeof(g_winnerName));
    /* The player killed by the winning kill (none for a win through a native or an objective). */
    g_looserName[0] = '\0';
    if ( victim > 0 && victim <= MaxClients && IsClientInGame(victim) )
    {
        GetClientName(victim, g_looserName, sizeof(g_looserName));
    }
    g_showWinnerOnRankUpdate = true;
    g_winner = GetClientUserId(client);

    /* gungame_stats fires GG_OnLoadRank after the save; do not wait for ever if it never comes. */
    CreateTimer(5.0, Timer_ShowWinnerFallback, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ShowWinnerFallback(Handle timer)
{
    GG_OnLoadRank();
    return Plugin_Stop;
}

/**
 * Copies at most maxBytes of a UTF-8 string without cutting a character in two.
 */
void Utf8Truncate(const char[] source, char[] dest, int maxBytes)
{
    strcopy(dest, maxBytes + 1, source);
    int len = strlen(dest);
    if ( len < strlen(source) )
    {
        /* Cut before a continuation byte: back off to the start of the character. */
        while ( len > 0 && (source[len] & 0xC0) == 0x80 )
        {
            len--;
        }
        dest[len] = '\0';
    }
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
        if ( !g_Cfg_DisplayWinnerUrl[0] )
        {
            return;
        }
        char url[512];
        char winnerShort[URL_NAME_MAX_BYTES + 1], looserShort[URL_NAME_MAX_BYTES + 1];
        char winnerNameUrlEncoded[URL_NAME_MAX_BYTES*3+1];
        char looserNameUrlEncoded[URL_NAME_MAX_BYTES*3+1];
        Utf8Truncate(g_winnerName, winnerShort, URL_NAME_MAX_BYTES);
        Utf8Truncate(g_looserName, looserShort, URL_NAME_MAX_BYTES);
        url_encode(winnerShort, sizeof(winnerShort), winnerNameUrlEncoded, sizeof(winnerNameUrlEncoded));
        url_encode(looserShort, sizeof(looserShort), looserNameUrlEncoded, sizeof(looserNameUrlEncoded));

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
        if ( strlen(url) > MOTD_URL_MAX_LEN )
        {
            LogError("[GunGame] Winner MOTD URL too long (%d bytes, max %d): shorten DisplayWinnerUrl", strlen(url), MOTD_URL_MAX_LEN);
            return;
        }
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
