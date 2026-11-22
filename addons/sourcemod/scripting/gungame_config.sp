#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <gungame_const>
#include <gungame_config>

/**
 * Do map specific config
 * make sure to do partial name config
 *
 * ie .. de.equip.txt
 * ie .. de.config.txt
 * ie .. de_dust.equip.txt
 * ie .. de_dust.config.txt
 *
 * it will be in cfg/gungame/css/maps/
 *
 * gungame.config.txt and gungame.equip.txt are read first.
 * prefix map name configs are read next.
 * then map specific config files are read.
 */

public Plugin myinfo =
{
    name = "GunGame:SM Config Reader",
    author = GUNGAME_AUTHOR,
    description = "GunGame:SM Config Reader",
    version = GUNGAME_VERSION,
    url = GUNGAME_URL
};

SMCParser ConfigParser;
int ConfigCount;
int ParseConfigCount;

GlobalForward FwdConfigNewSection;
GlobalForward FwdConfigKeyValue;
GlobalForward FwdConfigParseEnd;
GlobalForward FwdConfigEnd;

ConVar g_Cvar_CfgDirName;

char ConfigGameDirName[PLATFORM_MAX_PATH];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (!GG_IsCstrike()) {
        strcopy(error, err_max, "GunGame:SM only supports Counter-Strike: Source.");
        return APLRes_Failure;
    }

    RegPluginLibrary("gungame_cfg");
    CreateNative("GG_ConfigGetDir", Native_GG_ConfigGetDir);
    return APLRes_Success;
}

public int Native_GG_ConfigGetDir(Handle plugin, int numParams)
{
    SetNativeString(1, ConfigGameDirName, GetNativeCell(2));
    return 1;
}

public void OnPluginStart()
{
    FwdConfigNewSection = new GlobalForward("GG_ConfigNewSection", ET_Ignore, Param_String);
    FwdConfigKeyValue = new GlobalForward("GG_ConfigKeyValue", ET_Ignore, Param_String, Param_String);
    FwdConfigParseEnd = new GlobalForward("GG_ConfigParseEnd", ET_Ignore);
    FwdConfigEnd = new GlobalForward("GG_ConfigEnd", ET_Ignore);
    g_Cvar_CfgDirName = CreateConVar("sm_gg_cfgdirname", "gungame", "Config directory for gungame (from cfg path)");

    ConfigParser = new SMCParser();
    ConfigParser.OnEnterSection = ReadConfig_NewSection;
    ConfigParser.OnKeyValue = ReadConfig_KeyValue;
    ConfigParser.OnLeaveSection = ReadConfig_EndSection;
    ConfigParser.OnEnd = ReadConfig_ParseEnd;
}

public void OnConfigsExecuted()
{
    ReadConfig();
}

void ReadConfig()
{
    char ConfigDirName[PLATFORM_MAX_PATH];
    g_Cvar_CfgDirName.GetString(ConfigDirName, sizeof(ConfigDirName));

    FormatEx(ConfigGameDirName, sizeof(ConfigGameDirName), "%s/css", ConfigDirName);

    char ConfigDir[PLATFORM_MAX_PATH];
    FormatEx(ConfigDir, sizeof(ConfigDir), "cfg/%s", ConfigGameDirName);

    char ConfigFile[PLATFORM_MAX_PATH], EquipFile[PLATFORM_MAX_PATH];

    /* Counters are per map: a new parse round starts here. */
    ConfigCount = 0;
    ParseConfigCount = 0;

    FormatEx(ConfigFile, sizeof(ConfigFile), "%s/gungame.config.txt", ConfigDir);

    if (FileExists(ConfigFile))
    {
        ConfigCount++;
        PrintToServer("[GunGame] Loading gungame.config.txt config file");
    } else {
        SetFailState("[GunGame] FATAL *** ERROR *** can not find %s", ConfigFile);
    }

    FormatEx(EquipFile, sizeof(EquipFile), "%s/gungame.equip.txt", ConfigDir);

    if (FileExists(EquipFile))
    {
        ConfigCount++;
        PrintToServer("[GunGame] Loading gungame.equip.txt config file");
    } else {
        SetFailState("[GunGame] FATAL *** ERROR *** can not find %s", EquipFile);
    }

    /* Build map config and map prefix config*/

    /**
     * Thanks sawce for the idea from your prefix map plugin loading for AMX Mod X
     * saved me alot of time doing it this way.
     */

    char Map[PLATFORM_MAX_PATH];
    GetCurrentMap(Map, sizeof(Map));
    /* Workshop-style maps: keep the display name only. */
    GetMapDisplayName(Map, Map, sizeof(Map));

    int i = 0;
    while (Map[i] != '_' && Map[i] != '\0')
    {
        i++;
    }

    char PrefixConfigFile[PLATFORM_MAX_PATH], PrefixEquipFile[PLATFORM_MAX_PATH];
    bool EquipOne, ConfigOne;

    if (Map[i] == '_')
    {
        int b = Map[i];
        Map[i] = '\0';

        FormatEx(PrefixConfigFile, sizeof(PrefixConfigFile), "%s/maps/%s.config.txt", ConfigDir, Map);
        FormatEx(PrefixEquipFile, sizeof(PrefixEquipFile), "%s/maps/%s.equip.txt", ConfigDir, Map);

        if (FileExists(PrefixConfigFile))
        {
            ConfigOne = true;
            PrintToServer("[GunGame] Loading %s.config.txt config file", Map);
            ConfigCount++;
        }

        if (FileExists(PrefixEquipFile))
        {
            EquipOne = true;
            PrintToServer("[GunGame] Loading %s.equip.txt config file", Map);
            ConfigCount++;
        }

        Map[i] = b;
    }

    char MapEquipFile[PLATFORM_MAX_PATH], MapConfigFile[PLATFORM_MAX_PATH];
    bool EquipTwo, ConfigTwo;

    FormatEx(MapConfigFile, sizeof(MapConfigFile), "%s/maps/%s.config.txt", ConfigDir, Map);
    FormatEx(MapEquipFile, sizeof(MapEquipFile), "%s/maps/%s.equip.txt", ConfigDir, Map);

    if (FileExists(MapConfigFile))
    {
        PrintToServer("[GunGame] Loading %s.config.txt file", Map);
        ConfigTwo = true;
        ConfigCount++;
    }

    if (FileExists(MapEquipFile))
    {
        PrintToServer("[GunGame] Loading %s.equip.txt file", Map);
        EquipTwo = true;
        ConfigCount++;
    }

    InternalReadConfig(ConfigFile);
    InternalReadConfig(EquipFile);

    if (ConfigOne)
    {
        InternalReadConfig(PrefixConfigFile);
    }

    if (EquipOne)
    {
        InternalReadConfig(PrefixEquipFile);
    }

    if (ConfigTwo)
    {
        InternalReadConfig(MapConfigFile);
    }

    if (EquipTwo)
    {
        InternalReadConfig(MapEquipFile);
    }
}

static void InternalReadConfig(const char[] path)
{
    SMCError err = ConfigParser.ParseFile(path);

    if (err != SMCError_Okay)
    {
        char buffer[64];
        if (ConfigParser.GetErrorString(err, buffer, sizeof(buffer)))
        {
            PrintToServer("[GunGame] %s: %s", path, buffer);
        } else {
            PrintToServer("[GunGame] %s: Fatal parse error", path);
        }
    }
}

public SMCResult ReadConfig_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if (name[0])
    {
        Call_StartForward(FwdConfigNewSection);
        Call_PushString(name);
        Call_Finish();
    }

    return SMCParse_Continue;
}

public SMCResult ReadConfig_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
    if (key[0] && value[0])
    {
        Call_StartForward(FwdConfigKeyValue);
        Call_PushString(key);
        Call_PushString(value);
        Call_Finish();
    }

    return SMCParse_Continue;
}

public SMCResult ReadConfig_EndSection(SMCParser smc)
{
    return SMCParse_Continue;
}

public void ReadConfig_ParseEnd(SMCParser smc, bool halted, bool failed)
{
    Call_StartForward(FwdConfigParseEnd);
    Call_Finish();

    if (ConfigCount == ++ParseConfigCount)
    {
        Call_StartForward(FwdConfigEnd);
        Call_Finish();
    }
}
