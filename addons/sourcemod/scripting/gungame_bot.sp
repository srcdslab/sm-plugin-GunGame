#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <gungame_const>
#include <gungame>
#include <gungame_config>

State ConfigState;
bool g_Cfg_AllowUpByKnifeBot;
bool g_Cfg_AllowUpByExplodeBot;
bool g_Cfg_AllowUpByKnifeBotNoH;
bool g_Cfg_AllowUpByExplodeBotNoH;

public Plugin myinfo =
{
    name = "GunGame:SM Bot Protection",
    author = GUNGAME_AUTHOR,
    description = "Does not allow players to win on bots",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

public void OnPluginStart()
{
    LoadTranslations("gungame_bot.phrases");
}

public Action GG_OnClientDeath(int Killer, int Victim, int WeaponId, bool TeamKilled)
{
    if ( TeamKilled || !IsFakeClient(Victim) || IsFakeClient(Killer) ) {
        return Plugin_Continue;
    }

    if ( GG_IsWeaponKnife(WeaponId) ) {
        if ( g_Cfg_AllowUpByKnifeBot ) {
            return Plugin_Continue;
        }

        if ( g_Cfg_AllowUpByKnifeBotNoH ) {
            if ( IsThereOtherHuman(Killer) ) {
                CPrintToChat(Killer, "%t", "You can not level up on bot with knife if there is other human");
                return Plugin_Handled;
            } else {
                return Plugin_Continue;
            }
        }

        CPrintToChat(Killer, "%t", "You can not level up on bot with knife");
        return Plugin_Handled;
    } else if ( WeaponId == GG_GetWeaponIdHegrenade() ) {
        if ( g_Cfg_AllowUpByExplodeBot ) {
            return Plugin_Continue;
        }

        if ( g_Cfg_AllowUpByExplodeBotNoH ) {
            if ( IsThereOtherHuman(Killer) ) {
                CPrintToChat(Killer, "%t", "You can not level up on bot with hegrenade if there is other human");
                return Plugin_Handled;
            } else {
                return Plugin_Continue;
            }
        }

        CPrintToChat(Killer, "%t", "You can not level up on bot with hegrenade");
        return Plugin_Handled;
    }

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
        if ( strcmp("AllowLevelUpByKnifeBot", key, false) == 0 ) {
            g_Cfg_AllowUpByKnifeBot = StringToInt(value) != 0;
        } else if ( strcmp("AllowLevelUpByExplodeBot", key, false) == 0 ) {
            g_Cfg_AllowUpByExplodeBot = StringToInt(value) != 0;
        } else if ( strcmp("AllowLevelUpByKnifeBotIfNoHuman", key, false) == 0 ) {
            g_Cfg_AllowUpByKnifeBotNoH = StringToInt(value) != 0;
        } else if ( strcmp("AllowLevelUpByExplodeBotIfNoHuman", key, false) == 0 ) {
            g_Cfg_AllowUpByExplodeBotNoH = StringToInt(value) != 0;
        }
    }
}

public void GG_ConfigParseEnd()
{
    ConfigState = CONFIG_STATE_NONE;
}

/**
 * @param killer    The human who killed a bot.
 * @return          True if another human the killer can score on plays: any human on T or CT
 *                  in FFA, a human of the other team otherwise. Teammates do not count, else two
 *                  humans in the same team could never pass the knife or grenade level on bots.
 */
bool IsThereOtherHuman(int killer)
{
    bool ffa = GetFeatureStatus(FeatureType_Native, "GG_IsFFA") == FeatureStatus_Available && GG_IsFFA();
    int killerTeam = GetClientTeam(killer);
    int team;
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( i == killer || !IsClientInGame(i) || IsFakeClient(i) || IsClientSourceTV(i) ) {
            continue;
        }
        team = GetClientTeam(i);
        if ( team != TEAM_T && team != TEAM_CT ) {
            continue;
        }
        if ( ffa || team != killerTeam ) {
            return true;
        }
    }
    return false;
}
