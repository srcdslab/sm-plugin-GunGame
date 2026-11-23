#if defined _gungame_const_included_
  #endinput
#endif
#define _gungame_const_included_

/**
 * Enable debug code.
 * Default is disabled.
 */
// #define GUNGAME_DEBUG

/**
 * Enable debug code for sql in stats plugin.
 * Default is disabled.
 */
// #define SQL_DEBUG

/**
 * Version of the whole GunGame:SM suite (every plugin uses it).
 * This is the only place to bump it.
 */
#define GUNGAME_VERSION     "2.0.22"

#define GUNGAME_AUTHOR      "teame06-hat (http://www.hat-city.net), Liam, Otstrel.ru Team (http://otstrel.ru)"
#define GUNGAME_URL         "https://github.com/srcdslab/sm-plugin-GunGame"

/**
 * Maximum level in gungame.
 */
#define GUNGAME_MAX_LEVEL   64

/**
 * This is the maximum allow time for a menu to be !rules, !weapons, !score, !level is display for.
 */
#define GUNGAME_MENU_TIME   360

/**
 * Admin flag for admin commands
 */
#define GUNGAME_ADMINFLAG   ADMFLAG_RCON

stock const char BLANK[] = "";
stock const char BLANK_SPACE[] = " ";

#define MAX_NAME_SIZE        64
#define MAX_CHAT_SIZE        192
#define MAX_WEAPON_NAME_SIZE 32

//RemoveObjectives / MapStatus
#define OBJECTIVE_REMOVE_BOMB       (1<<0)
#define OBJECTIVE_REMOVE_HOSTAGE    (1<<1)
#define OBJECTIVE_BOMB              (1<<2)
#define OBJECTIVE_HOSTAGE           (1<<3)

#define TEAM_UNASSIGN        0
#define TEAM_SPECTATOR       1
#define TEAM_T               2
#define TEAM_CT              3

// settings for m_takedamage
#define DAMAGE_NO            0
#define DAMAGE_EVENTS_ONLY   1      // Call damage functions, but don't modify health
#define DAMAGE_YES           2
#define DAMAGE_AIM           3

// AfkAction
#define AFK_KICK             1
#define AFK_SPECTATE         2

enum Slots
{
    Slot_Primary,
    Slot_Secondary,
    Slot_Knife,
    Slot_Grenade,
    Slot_C4,
    Slot_None
};

#define MAX_WEAPONS_COUNT 64
#define MAX_WEAPON_NAME_LEN 24

enum State
{
    CONFIG_STATE_NONE,
    CONFIG_STATE_CONFIG,
    CONFIG_STATE_EQUIP,
    CONFIG_STATE_KILLS,
    CONFIG_STATE_SOUNDS,
    CONFIG_STATE_SECONDARY_LIST
}

#define MULTI_LEVEL_EFFECT2      "effects/combinemuzzle2.vmt"
#define MULTI_LEVEL_EFFECT1      "effects/combinemuzzle1.vmt"

/**
 * GunGame:SM only supports Counter-Strike: Source.
 *
 * @return              True if the running game is cstrike.
 */
stock bool GG_IsCstrike()
{
    char gameName[32];
    GetGameFolderName(gameName, sizeof(gameName));
    return StrEqual(gameName, "cstrike", false);
}
