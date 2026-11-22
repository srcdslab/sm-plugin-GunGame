/**
 * Reads gungame weapon info file (cfg/gungame/css/weaponinfo.txt).
 */
void OnKeyValueStart()
{
    FormatEx(WeaponFile, sizeof(WeaponFile), "cfg/gungame/css/weaponinfo.txt");

    if ( !FileExists(WeaponFile) )
    {
        SetFailState("FATAL ERROR File does not exists [%s]", WeaponFile);
    }

    /* Make sure to use unique section name just incase someone else uses it */
    KeyValues KvWeapon = new KeyValues("gg_WeaponInfo");
    WeaponOpen = KvWeapon.ImportFromFile(WeaponFile);

    delete TrieWeapon;
    TrieWeapon = new StringMap();

    if ( !WeaponOpen || !KvWeapon.GotoFirstSubKey() )
    {
        delete KvWeapon;
        SetFailState("FATAL ERROR Cannot read the weapons of [%s]", WeaponFile);
    }

    char name[MAX_WEAPON_NAME_LEN];
    int index;
    g_WeaponsMaxId          = 0;
    g_WeaponIdKnife         = 0;
    g_WeaponIdHegrenade     = 0;
    g_WeaponIdSmokegrenade  = 0;
    g_WeaponIdFlashbang     = 0;

    g_WeaponAmmoTypeHegrenade       = 0;
    g_WeaponAmmoTypeFlashbang       = 0;
    g_WeaponAmmoTypeSmokegrenade    = 0;

    do
    {
        if ( !KvWeapon.GetSectionName(name, sizeof(name)) )
        {
            break;
        }

        index = KvWeapon.GetNum("index");
        if ( index <= 0 || index >= MAX_WEAPONS_COUNT )
        {
            delete KvWeapon;
            SetFailState("FATAL ERROR: Invalid index %d for %s in %s.", index, name, WeaponFile);
        }
        UTIL_StringToLower(name);

        // init weapons by name array
        TrieWeapon.SetValue(name, index);
        // init weapons count
        g_WeaponsMaxId++;
        // init weapons full names (to use in give commands)
        FormatEx(g_WeaponName[index], sizeof(g_WeaponName[]), "weapon_%s", name);
        // init weapons slots
        g_WeaponSlot[index] = view_as<Slots>(KvWeapon.GetNum("slot", 0));
        // init weapons clip size
        g_WeaponAmmo[index] = KvWeapon.GetNum("clipsize", 0);
        // init weapons that need drop knife
        g_WeaponDropKnife[index] = KvWeapon.GetNum("drop_knife", 0) != 0;
        // level index (different weapons but the same level)
        g_WeaponLevelIndex[index] = KvWeapon.GetNum("level_index", 0);

        if ( !g_WeaponLevelIndex[index] )
        {
            delete KvWeapon;
            SetFailState("FATAL ERROR: Level index should not be zero for %s. You should update you %s and take it from the release zip file.",
                name, WeaponFile);
        }

        if ( KvWeapon.GetNum("is_knife", 0) ) {
            g_WeaponIdKnife                 = index;
            g_WeaponLevelIdKnife            = g_WeaponLevelIndex[index];
        } else if ( KvWeapon.GetNum("is_hegrenade", 0) ) {
            g_WeaponIdHegrenade             = index;
            g_WeaponLevelIdHegrenade        = g_WeaponLevelIndex[index];
            g_WeaponAmmoTypeHegrenade       = KvWeapon.GetNum("ammotype", 0);
        } else if ( KvWeapon.GetNum("is_smokegrenade", 0) ) {
            g_WeaponIdSmokegrenade          = index;
            g_WeaponAmmoTypeSmokegrenade    = KvWeapon.GetNum("ammotype", 0);
        } else if ( KvWeapon.GetNum("is_flashbang", 0) ) {
            g_WeaponIdFlashbang             = index;
            g_WeaponAmmoTypeFlashbang       = KvWeapon.GetNum("ammotype", 0);
        }
    }
    while ( KvWeapon.GotoNextKey() );

    delete KvWeapon;

    if ( !(  g_WeaponsMaxId
            && g_WeaponIdKnife
            && g_WeaponIdHegrenade
            && g_WeaponIdSmokegrenade
            && g_WeaponIdFlashbang
    ) ) {
        SetFailState("FATAL ERROR: Some of the weapons not found MAXID=[%i] KNIFE=[%i] HE=[%i] SMOKE=[%i] FLASH=[%i]. You should update you %s and take it from the release zip file.",
            g_WeaponsMaxId, g_WeaponIdKnife, g_WeaponIdHegrenade, g_WeaponIdSmokegrenade, g_WeaponIdFlashbang, WeaponFile);
    }

    if ( !(  g_WeaponAmmoTypeHegrenade
            && g_WeaponAmmoTypeFlashbang
            && g_WeaponAmmoTypeSmokegrenade
    ) ) {
        SetFailState("FATAL ERROR: Some of the ammo types not found HE=[%i] FLASH=[%i] SMOKE=[%i]. You should update you %s and take it from the release zip file.",
            g_WeaponAmmoTypeHegrenade, g_WeaponAmmoTypeFlashbang, g_WeaponAmmoTypeSmokegrenade, WeaponFile);
    }
}
