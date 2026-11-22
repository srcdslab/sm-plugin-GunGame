#if defined _gungame_cfg_natives_included_
  #endinput
#endif
#define _gungame_cfg_natives_included_

/**
 * GunGame:SM config reader API (library "gungame_cfg", plugin gungame_config.smx).
 *
 * The reader parses, in this order: gungame.config.txt, gungame.equip.txt,
 * maps/<prefix>.config.txt, maps/<prefix>.equip.txt, maps/<map>.config.txt
 * and maps/<map>.equip.txt from cfg/<sm_gg_cfgdirname>/css/.
 */

/**
 * Called when the config reader enters a new section.
 *
 * @param name          Name of the section.
 */
forward void GG_ConfigNewSection(const char[] name);

/**
 * Called for every key/value pair of the config files.
 *
 * @param key           Key of the setting.
 * @param value         Value of the setting.
 */
forward void GG_ConfigKeyValue(const char[] key, const char[] value);

/**
 * Called when a file is fully parsed.
 */
forward void GG_ConfigParseEnd();

/**
 * Called when all the config file are fully parsed.
 */
forward void GG_ConfigEnd();

/**
 * Get cfg dir name (relative to cfg/, ie "gungame/css").
 *
 * @param dirName       Dir name.
 * @param dirNameSize   Dir name string size.
 * @return              1.
 */
native int GG_ConfigGetDir(char[] dirName, int dirNameSize);

/* Do not edit the code below. */
public SharedPlugin __pl_gungame_cfg =
{
    name = "gungame_cfg",
    file = "gungame_config.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_gungame_cfg_SetNTVOptional()
{
    MarkNativeAsOptional("GG_ConfigGetDir");
}
#endif
