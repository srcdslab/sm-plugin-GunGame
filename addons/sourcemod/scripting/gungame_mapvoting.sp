#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <gungame_const>
#include <gungame>
#include <gungame_config>

public Plugin myinfo = {
    name = "GunGame:SM Map Vote Starter",
    author = GUNGAME_AUTHOR,
    description = "Start the map voting for next map",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

/* ServerCommand appends: InsertServerCommand ran these cfgs before commands queued earlier
 * in the same frame (the map config), which then overrode them. */
public void GG_OnStartMapVote()
{
    char ConfigGameDirName[PLATFORM_MAX_PATH];
    GG_ConfigGetDir(ConfigGameDirName, sizeof(ConfigGameDirName));
    ServerCommand("exec %s/gungame.mapvote.cfg", ConfigGameDirName);
}

public void GG_OnDisableRtv()
{
    char ConfigGameDirName[PLATFORM_MAX_PATH];
    GG_ConfigGetDir(ConfigGameDirName, sizeof(ConfigGameDirName));
    ServerCommand("exec %s/gungame.disable_rtv.cfg", ConfigGameDirName);
}
