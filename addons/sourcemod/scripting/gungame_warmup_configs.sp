#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <gungame_const>
#include <gungame>
#include <gungame_config>

public Plugin myinfo = {
    name = "GunGame:SM Warmup Configs Execution",
    author = GUNGAME_AUTHOR,
    description = "Execute warmup configs on warmup start and end",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

/* ServerCommand appends: InsertServerCommand ran these cfgs before commands queued earlier
 * in the same frame (the map config), which then overrode them. */
public void GG_OnWarmupEnd()
{
    char ConfigGameDirName[PLATFORM_MAX_PATH];
    GG_ConfigGetDir(ConfigGameDirName, sizeof(ConfigGameDirName));
    ServerCommand("exec %s/gungame.warmupend.cfg", ConfigGameDirName);
}

public void GG_OnWarmupStart()
{
    char ConfigGameDirName[PLATFORM_MAX_PATH];
    GG_ConfigGetDir(ConfigGameDirName, sizeof(ConfigGameDirName));
    ServerCommand("exec %s/gungame.warmupstart.cfg", ConfigGameDirName);
}
