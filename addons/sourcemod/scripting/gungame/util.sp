void UTIL_FindMapObjective()
{
    if ( FindEntityByClassname(-1, "func_bomb_target") > MaxClients
        || FindEntityByClassname(-1, "info_bomb_target") > MaxClients )
    {
        MapStatus |= OBJECTIVE_BOMB;
    }

    if ( FindEntityByClassname(-1, "hostage_entity") > MaxClients )
    {
        MapStatus |= OBJECTIVE_HOSTAGE;
    }
}

void UTIL_ConvertWeaponToIndex()
{
    for ( int i = 0, b; i < WeaponOrderCount; i++ )
    {
        /**
         * Found empty weapon name
         * Probably no more weapons since this one is empty.
         */
        if ( !WeaponOrderName[i][0] )
        {
            break;
        }

        UTIL_StringToLower(WeaponOrderName[i]);

        if ( !(b = UTIL_GetWeaponIndex(WeaponOrderName[i])) )
        {
            LogMessage("[GunGame] *** FATAL ERROR *** Weapon Order has an invalid entry :: name %s :: level %d", WeaponOrderName[i], i + 1);
        }

        WeaponOrderId[i] = b;
    }
}

void UTIL_PrintToUpperLeft(int r, int g, int b, const char[] source, any ...)
{
    char Buffer[64];
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) && !IsFakeClient(i) )
        {
            SetGlobalTransTarget(i);
            VFormat(Buffer, sizeof(Buffer), source, 5);

            KeyValues Msg = new KeyValues("msg");
            Msg.SetString("title", Buffer);
            Msg.SetColor("color", r, g, b, 255);
            Msg.SetNum("level", 0);
            Msg.SetNum("time", 20);

            CreateDialog(i, Msg, DialogType_Msg);

            delete Msg;
        }
    }
}

/* Weapon Index Lookup via Trie array */
int UTIL_GetWeaponIndex(const char[] Weapon)
{
    if ( !WeaponOpen )
    {
        // weaponinfo file not loaded
        LogError("[GunGame] WeaponInfo file not loaded.");

        return 0;
    }

    int len = 0;
    if ( (strlen(Weapon) > 7) && (StrContains(Weapon, "weapon_") == 0) )
    {
        // truncate weapon name
        len = 7;
    }

    int index;
    if ( TrieWeapon.GetValue(Weapon[len], index) )
    {
        return index;
    }

    if ( (strlen(Weapon[len]) > 6) && (StrContains(Weapon[len], "knife_") == 0) )
    {
        // the weapon is knife
        return g_WeaponIdKnife;
    }

    LogError("[GunGame] Weapon index for \"%s\" not found.", Weapon);

    return 0;
}

/**
 * Changes mp_friendlyfire.
 * Never used to turn friendly fire off in FFA mode.
 */
void UTIL_ChangeFriendlyFire(bool Status)
{
    if ( FFA && !Status )
    {
        return;
    }

    int flags = mp_friendlyfire.Flags;

    mp_friendlyfire.Flags = flags & ~(FCVAR_SPONLY|FCVAR_NOTIFY);
    mp_friendlyfire.IntValue = Status ? 1 : 0;
    mp_friendlyfire.Flags = flags;

    if ( Status ) {
        CPrintToChatAll("%t", "Friendly Fire has been enabled");
    } else {
        CPrintToChatAll("%t", "Friendly Fire has been disabled");
    }

    UTIL_PlaySound(0, AutoFF);
}

void UTIL_SetClientGodMode(int client, int mode = 0)
{
    SetEntProp(client, Prop_Data, "m_takedamage", mode ? DAMAGE_NO : DAMAGE_YES, 1);
}

void UTIL_CallLeaderForward(int level)
{
    Call_StartForward(FwdLeader);
    Call_PushCell(CurrentLeader);
    Call_PushCell(level);
    Call_PushCell(WeaponOrderCount);
    Call_Finish();
}

/**
 * Recalculate CurrentLeader.
 *
 * @param client
 * @param oldLevel
 * @param newLevel
 */
void UTIL_RecalculateLeader(int client, int oldLevel, int newLevel)
{
    if ( newLevel == oldLevel )
    {
        return;
    }
    if ( newLevel < oldLevel )
    {
        if ( !CurrentLeader )
        {
            return;
        }
        if ( client == CurrentLeader )
        {
            // was the leader
            CurrentLeader = FindLeader();
            if ( CurrentLeader != client )
            {
                UTIL_CallLeaderForward(newLevel);
                UTIL_PlaySoundForLeaderLevel();
            }
            return;
        }
        // was not a leader
        return;
    }
    // newLevel > oldLevel
    if ( !CurrentLeader )
    {
        CurrentLeader = client;
        UTIL_CallLeaderForward(newLevel);
        UTIL_PlaySoundForLeaderLevel();
        return;
    }
    if ( CurrentLeader == client )
    {
        // still leading
        UTIL_PlaySoundForLeaderLevel();
        return;
    }
    // CurrentLeader != client
    if ( newLevel < PlayerLevel[CurrentLeader] )
    {
        // not leading
        return;
    }
    if ( newLevel > PlayerLevel[CurrentLeader] )
    {
        CurrentLeader = client;
        UTIL_CallLeaderForward(newLevel);
        // start leading
        UTIL_PlaySoundForLeaderLevel();
        return;
    }
    // new level == leader level
    // tied to the lead
    UTIL_PlaySoundForLeaderLevel();
}

void UTIL_PlaySoundForLeaderLevel()
{
    if ( !CurrentLeader )
    {
        return;
    }
    int WeapLevelId = g_WeaponLevelIndex[WeaponOrderId[PlayerLevel[CurrentLeader]]];
    if ( WeapLevelId == g_WeaponLevelIdHegrenade )
    {
        UTIL_PlaySound(0, Nade);
        return;
    }
    if ( WeapLevelId == g_WeaponLevelIdKnife )
    {
        UTIL_PlaySound(0, Knife);
        return;
    }
}

/**
 * Fires GG_OnClientLevelChanged (1-based levels).
 */
void UTIL_FireLevelChanged(int client, int oldLevel, int newLevel, GGLevelReason reason)
{
    if ( oldLevel == newLevel )
    {
        return;
    }

    Call_StartForward(FwdLevelChanged);
    Call_PushCell(client);
    Call_PushCell(oldLevel + 1);
    Call_PushCell(newLevel + 1);
    Call_PushString(WeaponOrderName[newLevel]);
    Call_PushCell(reason);
    Call_Finish();
}

/**
 * Fires GG_OnKnifeSteal (1-based levels).
 */
void UTIL_FireKnifeSteal(int killer, int victim, bool victimLost)
{
    Call_StartForward(FwdKnifeSteal);
    Call_PushCell(killer);
    Call_PushCell(victim);
    Call_PushCell(PlayerLevel[killer] + 1);
    Call_PushCell(PlayerLevel[victim] + 1);
    Call_PushCell(victimLost);
    Call_Finish();
}

int UTIL_ChangeLevel(int client, int difference, bool KnifeSteal = false, int victim = 0, GGLevelReason reason = GGLevelReason_Native)
{
    if ( !difference || !IsActive || WarmupEnabled || GameWinner )
    {
        return PlayerLevel[client];
    }

    int oldLevel = PlayerLevel[client], Level = oldLevel + difference;

    if ( Level < 0 ) {
        Level = 0;
    } else if ( Level > WeaponOrderCount ) {
        Level = WeaponOrderCount;
    }

    Action ret = Plugin_Continue;

    Call_StartForward(FwdLevelChange);
    Call_PushCell(client);
    Call_PushCell(Level);
    Call_PushCell(difference);
    Call_PushCell(KnifeSteal);
    Call_PushCell(Level == (WeaponOrderCount - 1));
    Call_PushCell(g_WeaponLevelIndex[WeaponOrderId[Level]] == g_WeaponLevelIdKnife);
    Call_Finish(ret);

    if ( ret != Plugin_Continue )
    {
        return PlayerLevel[client] = oldLevel;
    }

    if ( !BotCanWin && IsFakeClient(client) && (Level >= WeaponOrderCount) )
    {
        /* Bot can't win so just keep them at the last level */
        return oldLevel;
    }

    // Client got new level
    PlayerLevel[client] = Level;
    if ( KnifeSteal && g_Cfg_KnifeProRecalcPoints && (oldLevel != Level) ) {
        CurrentKillsPerWeap[client] = CurrentKillsPerWeap[client] * UTIL_GetCustomKillPerLevel(Level) / UTIL_GetCustomKillPerLevel(oldLevel);
    } else {
        CurrentKillsPerWeap[client] = 0;
    }

    if ( difference < 0 )
    {
        UTIL_PlaySound(client, Down);
    }
    else
    {
        if ( KnifeSteal )
        {
            UTIL_PlaySound(client, Steal);
        }
        else
        {
            UTIL_PlaySound(client, Up);
        }
    }

    if ( !IsVotingCalled && Level >= WeaponOrderCount - VoteLevelLessWeaponCount )
    {
        IsVotingCalled = true;
        Call_StartForward(FwdVoteStart);
        Call_Finish();
    }

    if ( g_cfgDisableRtvLevel && !g_isCalledDisableRtv && Level >= g_cfgDisableRtvLevel )
    {
        g_isCalledDisableRtv = true;
        Call_StartForward(FwdDisableRtv);
        Call_Finish();
    }

    /* FFA: friendly fire must stay on, never toggle it. */
    if ( !FFA && g_cfgEnableFriendlyFireLevel && !g_isCalledEnableFriendlyFire && Level >= g_cfgEnableFriendlyFireLevel )
    {
        g_isCalledEnableFriendlyFire = true;
        UTIL_ChangeFriendlyFire(g_cfgFriendlyFireOnOff);
    }

    /* WeaponOrder count is the last weapon. */
    if ( Level >= WeaponOrderCount )
    {
        /* Winner Winner Winner. They won the prize of gaben plus a hat. */
        char Name[MAX_NAME_SIZE];
        GetClientName(client, Name, sizeof(Name));

        int team = GetClientTeam(client);
        int r = (team == TEAM_T ? 255 : 0);
        int g =  team == TEAM_CT ? 128 : (team == TEAM_T ? 0 : 255);
        int b = (team == TEAM_CT ? 255 : 0);
        UTIL_PrintToUpperLeft(r, g, b, "%t", "Has won", Name);

        /* Keep the last level during the winner forward so GG_GetRanking() is consistent. */
        PlayerLevel[client] = oldLevel;
        GameWinner = client;

        Call_StartForward(FwdWinner);
        Call_PushCell(client);
        Call_PushString(WeaponOrderName[Level - 1]);
        Call_PushCell(victim);
        Call_Finish();

        if ( g_Cfg_WinnerFreezePlayers )
        {
            UTIL_FreezeAllPlayers();
        }
        UTIL_EndMultiplayerGameDelayed();

        Action result = Plugin_Continue;
        Call_StartForward(FwdSoundWinner);
        Call_PushCell(client);
        Call_Finish(result);

        if ( result == Plugin_Continue )
        {
            UTIL_PlaySound(0, Winner);
        }

        if ( AlltalkOnWin )
        {
            ConVar sv_alltalk = FindConVar("sv_alltalk");
            if ( sv_alltalk != null )
            {
                sv_alltalk.IntValue = 1;
            }
        }
        return oldLevel;
    }
    UTIL_RecalculateLeader(client, oldLevel, Level);
    UTIL_UpdatePlayerScoreLevel(client);
    UTIL_FireLevelChanged(client, oldLevel, Level, reason);

    return Level;
}

void UTIL_FreezeAllPlayers()
{
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) )
        {
            UTIL_FreezePlayer(i);
        }
    }
}

void UTIL_FreezePlayer(int client)
{
    SetEntityMoveType(client, MOVETYPE_NONE);
}

/**
 * Force drop C4.
 *
 * @param client        Player index.
 */
void UTIL_ForceDropC4(int client)
{
    int ent = GetPlayerWeaponSlot(client, view_as<int>(Slot_C4));
    if ( ent > 0 )
    {
        CS_DropWeapon(client, ent, false, true);
        UTIL_Remove(ent);
    }
}

/**
 * Removes a weapon from a player and from the world.
 */
void UTIL_RemovePlayerWeapon(int client, int weapon)
{
    RemovePlayerItem(client, weapon);
    AcceptEntityInput(weapon, "Kill");
}

/**
 * @param client        Player index
 * @param dropKnife     Allow knife drop
 */
void UTIL_ForceDropAllWeapon(int client, bool dropKnife)
{
    for ( Slots i = Slot_Primary; i < Slot_None; i++ )
    {
        if ( i == Slot_Grenade )
        {
            UTIL_DropAllGrenades(client);
            continue;
        }
        else if ( i == Slot_Knife )
        {
            if ( !dropKnife )
            {
                continue;
            }
        }
        else if ( i == Slot_C4 )
        {
            UTIL_ForceDropC4(client);
            continue;
        }

        int ent = GetPlayerWeaponSlot(client, view_as<int>(i));
        if ( ent > 0 )
        {
            UTIL_RemovePlayerWeapon(client, ent);
        }
    }
}

/**
 * Drop/remove all grenades.
 *
 * @param client        Player index
 */
void UTIL_DropAllGrenades(int client)
{
    for ( int i = 0; i < 5; i++ )
    {
        int ent = GetPlayerWeaponSlot(client, view_as<int>(Slot_Grenade));
        if ( ent < 1 )
        {
            break;
        }

        UTIL_RemovePlayerWeapon(client, ent);
    }
}

void UTIL_CheckForFriendlyFire(int client, int WeapId)
{
    /* FFA: friendly fire must stay on, never toggle it. */
    if ( !AutoFriendlyFire || FFA )
    {
        return;
    }
    int pState = PlayerState[client];
    if ( (pState & GRENADE_LEVEL) && (g_WeaponLevelIndex[WeapId] != g_WeaponLevelIdHegrenade) )
    {
        PlayerState[client] &= ~GRENADE_LEVEL;

        if ( --PlayerOnGrenade < 1 )
        {
            UTIL_ChangeFriendlyFire(!g_cfgFriendlyFireOnOff);
        }
        return;
    }
    if ( !(pState & GRENADE_LEVEL) && (g_WeaponLevelIndex[WeapId] == g_WeaponLevelIdHegrenade) )
    {
        PlayerOnGrenade++;
        PlayerState[client] |= GRENADE_LEVEL;

        if ( !mp_friendlyfire.BoolValue )
        {
            UTIL_ChangeFriendlyFire(g_cfgFriendlyFireOnOff);
        }
        return;
    }
}

void UTIL_GiveNextWeapon(int client, int level, bool levelupWithKnife = false, float delay = 0.1, bool spawn = false)
{
    DataPack data = new DataPack();
    data.WriteCell(GetClientUserId(client));
    data.WriteCell(level);
    data.WriteCell(levelupWithKnife);
    data.WriteCell(spawn);

    CreateTimer(delay, UTIL_Timer_GiveNextWeapon, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
}

public Action UTIL_Timer_GiveNextWeapon(Handle timer, DataPack data)
{
    data.Reset();
    int client = GetClientOfUserId(data.ReadCell());
    int level = data.ReadCell();
    bool levelupWithKnife = view_as<bool>(data.ReadCell());
    bool spawn = view_as<bool>(data.ReadCell());

    if ( !client || !IsClientInGame(client) || !IsPlayerAlive(client) )
    {
        return Plugin_Stop;
    }

    UTIL_GiveNextWeaponReal(client, level, levelupWithKnife, spawn);
    return Plugin_Stop;
}

void UTIL_GiveNextWeaponReal(int client, int level, bool levelupWithKnife, bool spawn)
{
    int WeapId = WeaponOrderId[level], WeapLevelId = g_WeaponLevelIndex[WeapId];
    Slots slot = g_WeaponSlot[WeapId];
    bool dropKnife = g_WeaponDropKnife[WeapId];
    bool blockSwitch = g_Cfg_BlockWeaponSwitchIfKnife && levelupWithKnife && !dropKnife;
    int newWeapon = 0;

    #if defined GUNGAME_DEBUG
        LogError("[DEBUG-GUNGAME] UTIL GIVE_WEAPON weaponName=%s weaponId=%d slotId=%d clientId=%d levelId=%d", g_WeaponName[WeapId], WeapId, slot, client, level);
    #endif

    if ( blockSwitch )
    {
        g_BlockSwitch[client] = true;
    }

    UTIL_CheckForFriendlyFire(client, WeapId);

    UTIL_ForceDropAllWeapon(client, dropKnife);

    // A check to make sure player always has a knife
    // because some maps do not give the knife.
    if ( !dropKnife && spawn && (GetPlayerWeaponSlot(client, view_as<int>(Slot_Knife)) == -1) )
    {
        GivePlayerItemWrapper(client, g_WeaponName[g_WeaponIdKnife]);
    }

    if ( PlayerState[client] & KNIFE_ELITE )
    {
        if ( blockSwitch )
        {
            g_BlockSwitch[client] = false;
        }
        else
        {
            FakeClientCommand(client, "use %s", g_WeaponName[g_WeaponIdKnife]);
        }
        return;
    }

    if ( slot == Slot_Grenade && WeapLevelId == g_WeaponLevelIdHegrenade )
    {
        // BONUS WEAPONS FOR HEGRENADE
        if ( NumberOfNades )
        {
            g_NumberOfNades[client] = NumberOfNades - 1;
        }
        if ( NadeBonusWeaponId )
        {
            int ent = GivePlayerItemWrapper(client, g_WeaponName[NadeBonusWeaponId]);
            // Remove bonus weapon ammo! So player can not reload weapon!
            if ( (ent > 0) && RemoveBonusWeaponAmmo )
            {
                DataPack Info = new DataPack();
                Info.WriteCell(GetClientUserId(client));
                Info.WriteCell(EntIndexToEntRef(ent));

                CreateTimer(0.1, UTIL_DelayAmmoRemove, Info, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
            }
        }
        if ( NadeSmoke )
        {
            GivePlayerItemWrapper(client, g_WeaponName[g_WeaponIdSmokegrenade], !g_BlockSwitch[client]);
        }
        if ( NadeFlash )
        {
            GivePlayerItemWrapper(client, g_WeaponName[g_WeaponIdFlashbang], !g_BlockSwitch[client]);
        }
    }

    if ( slot == Slot_Knife )
    {
        if ( WeapLevelId == g_WeaponLevelIdKnife )
        {
            // BONUS WEAPONS FOR KNIFE
            if ( g_Cfg_KnifeSmoke )
            {
                GivePlayerItemWrapper(client, g_WeaponName[g_WeaponIdSmokegrenade], !g_BlockSwitch[client]);
            }
            if ( g_Cfg_KnifeFlash )
            {
                GivePlayerItemWrapper(client, g_WeaponName[g_WeaponIdFlashbang], !g_BlockSwitch[client]);
            }
            if ( dropKnife )
            {
                newWeapon = GivePlayerItemWrapper(client, g_WeaponName[WeapId]);
            }
        }
        else
        {
            newWeapon = GivePlayerItemWrapper(client, g_WeaponName[WeapId]);
        }
    }
    else
    {
        // LEVEL WEAPON PRIMARY/SECONDARY/GRENADE
        newWeapon = GivePlayerItemWrapper(client, g_WeaponName[WeapId]);
    }

    if ( blockSwitch )
    {
        g_BlockSwitch[client] = false;
    }
    else
    {
        UTIL_UseWeapon(client, WeapId);
        UTIL_FastSwitchWithCheck(client, newWeapon, true, WeapId);
    }
}

/**
 * This function was created because of the dynamic pricing that was updated in the
 * recent Source update. They are giving full ammo no matter if mp_dynamicpricing was 0 or 1.
 * So I had to delay reseting the hegrenade with glock to 50 bullets by 0.2
 */
public Action UTIL_DelayAmmoRemove(Handle timer, DataPack data)
{
    data.Reset();
    int client = GetClientOfUserId(data.ReadCell());
    int weapon = EntRefToEntIndex(data.ReadCell());

    if ( client && IsClientInGame(client) && weapon > 0 )
    {
        UTIL_RemoveAmmo(client, weapon);
    }
    return Plugin_Stop;
}

void UTIL_PlaySoundDelayed(float delay, int client, Sounds type, int entity = SOUND_FROM_PLAYER, bool stop = false)
{
    DataPack data = new DataPack();
    data.WriteCell(GetClientUserId(client));
    data.WriteCell(type);
    data.WriteCell(entity);
    data.WriteCell(stop);

    CreateTimer(delay, UTIL_Timer_PlaySound, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
}

public Action UTIL_Timer_PlaySound(Handle timer, DataPack data)
{
    data.Reset();
    int client = GetClientOfUserId(data.ReadCell());
    Sounds type = view_as<Sounds>(data.ReadCell());
    int entity = data.ReadCell();
    bool stop = view_as<bool>(data.ReadCell());

    if ( !client || !IsClientInGame(client) || !IsPlayerAlive(client) )
    {
        return Plugin_Stop;
    }

    UTIL_PlaySound(client, type, entity, stop);
    return Plugin_Stop;
}

/**
 * Play gungame sound.
 *
 * @param client        Emit sound to. 0=play to all, int=play to that client id.
 * @param type          Type of the sounds (enum Sounds).
 * @param entity        Emit sound from. Entity, that emits sound.
 * @param stop          Stop that sound.
 */
void UTIL_PlaySound(int client, Sounds type, int entity = SOUND_FROM_PLAYER, bool stop = false)
{
    if ( !EventSounds[type][0] )
    {
        return;
    }
    if ( client && (!IsClientInGame(client) || IsFakeClient(client)) )
    {
        return;
    }

    int flags = SND_NOFLAGS;
    if ( stop )
    {
        flags |= SND_STOPLOOPING;
    }

    if ( g_Cfg_MultiplySoundVolume < 1 )
    {
        g_Cfg_MultiplySoundVolume = 1;
    }
    if ( g_Cfg_MultiplySoundVolume > 5 )
    {
        g_Cfg_MultiplySoundVolume = 5;
    }

    for ( int i = 0; i < g_Cfg_MultiplySoundVolume; i++ )
    {
        if ( !client )
        {
            EmitSoundToAll(EventSounds[type], entity, _, SNDLEVEL_RAIDSIREN, flags);
        }
        else
        {
            EmitSoundToClient(client, EventSounds[type], entity, _, SNDLEVEL_RAIDSIREN, flags);
        }
    }
}

void UTIL_DisableBuyZones()
{
    int index = -1;
    while ( (index = FindEntityByClassname(index, "func_buyzone")) != -1 )
    {
        AcceptEntityInput(index, "Disable");
    }
}

void UTIL_EnableBuyZones()
{
    int index = -1;
    while ( (index = FindEntityByClassname(index, "func_buyzone")) != -1 )
    {
        AcceptEntityInput(index, "Enable");
    }
}

void UTIL_ReloadActiveWeapon(int client, int WeaponId)
{
    Slots slot = g_WeaponSlot[WeaponId];
    if ( (slot == Slot_Primary) || (slot == Slot_Secondary) )
    {
        int ent = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if ( (ent > 0) && g_WeaponAmmo[WeaponId] )
        {
            SetEntProp(ent, Prop_Send, "m_iClip1", g_WeaponAmmo[WeaponId]);
        }
    }
}

int GivePlayerItemWrapper(int client, const char[] item, bool blockSwitch = false)
{
    #if defined GUNGAME_DEBUG
        LogError("[DEBUG-GUNGAME] FUNC GivePlayerItemWrapper, client=%i item=%s", client, item);
    #endif

    g_BlockFastSwitchOnChange[client] = true;
    if ( blockSwitch )
    {
        g_BlockSwitch[client] = true;
    }

    /* GivePlayerItem makes the player touch the new weapon: let OnWeaponCanUse accept it. */
    g_AllowPickup[client] = true;
    int ent = GivePlayerItem(client, item);
    g_AllowPickup[client] = false;

    if ( blockSwitch )
    {
        g_BlockSwitch[client] = false;
    }
    g_BlockFastSwitchOnChange[client] = false;

    return ent;
}

void UTIL_StartTripleEffects(int client)
{
    if ( g_tripleEffects[client] )
    {
        return;
    }
    g_tripleEffects[client] = 1;
    if ( TripleLevelBonusGodMode )
    {
        UTIL_SetClientGodMode(client, 1);
    }
    if ( g_Cfg_TripleLevelBonusGravity != 0.0 )
    {
        SetEntityGravity(client, g_Cfg_TripleLevelBonusGravity);
    }
    if ( g_Cfg_TripleLevelBonusSpeed != 0.0 )
    {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_Cfg_TripleLevelBonusSpeed);
    }
    UTIL_PlaySound(0, Triple, client);
    if ( g_Cfg_TripleLevelEffect )
    {
        UTIL_StartEffectClient(client);
    }
}

void UTIL_StopBonusGravity(int client)
{
    if ( !g_tripleEffects[client] )
    {
        return;
    }
    if ( g_Cfg_TripleLevelBonusGravity != 0.0 )
    {
        SetEntityGravity(client, 1.0);
    }
}

void UTIL_StopTripleEffects(int client)
{
    if ( !g_tripleEffects[client] )
    {
        return;
    }
    g_tripleEffects[client] = 0;
    if ( !IsClientInGame(client) )
    {
        return;
    }
    if ( TripleLevelBonusGodMode )
    {
        UTIL_SetClientGodMode(client, 0);
    }
    if ( g_Cfg_TripleLevelBonusGravity != 0.0 )
    {
        SetEntityGravity(client, 1.0);
    }
    if ( g_Cfg_TripleLevelBonusSpeed != 0.0 )
    {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }
    UTIL_PlaySound(0, Triple, client, true);
    if ( g_Cfg_TripleLevelEffect )
    {
        UTIL_StopEffectClient(client);
    }
}

/**
 * Return current leader client.
 *
 * @param DisallowBot
 * @return              The leader, 0 if no leaders found.
 */
int FindLeader(bool DisallowBot = false)
{
    int leaderId      = 0;
    int leaderLevel   = 0;
    int currentLevel  = 0;

    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( DisallowBot && IsClientInGame(i) && IsFakeClient(i) )
        {
            continue;
        }

        currentLevel = PlayerLevel[i];

        if ( currentLevel > leaderLevel )
        {
            leaderLevel = currentLevel;
            leaderId = i;
        }
    }

    return leaderId;
}

void CheckForTripleLevel(int client)
{
    CurrentLevelPerRoundTriple[client]++;
    if ( TripleLevelBonus && CurrentLevelPerRoundTriple[client] == g_Cfg_MultiLevelAmount )
    {
        char Name[MAX_NAME_SIZE];
        GetClientName(client, Name, sizeof(Name));

        char subtext[64];
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) )
            {
                SetGlobalTransTarget(i);
                FormatLanguageNumberTextEx(i, subtext, sizeof(subtext), g_Cfg_MultiLevelAmount, "leveled times");
                CPrintToChatEx(i, client, "%t", "Player has leveled many times", Name, subtext);
            }
        }

        UTIL_StartTripleEffects(client);
        CreateTimer(10.0, RemoveBonus, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

        Call_StartForward(FwdTripleLevel);
        Call_PushCell(client);
        Call_Finish();
    }
}

public Action RemoveBonus(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if ( client )
    {
        CurrentLevelPerRoundTriple[client] = 0;
        UTIL_StopTripleEffects(client);
    }
    return Plugin_Stop;
}

/**
 * Stocks
 */

void UTIL_StringToLower(char[] Source)
{
    int len = strlen(Source);

    for ( int i = 0; i < len; i++ )
    {
        Source[i] = CharToLower(Source[i]);
    }
}

void UTIL_GiveWarmUpWeaponDelayed(float delay, int client)
{
    CreateTimer(delay, UTIL_Timer_GiveWarmUpWeapon, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action UTIL_Timer_GiveWarmUpWeapon(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if ( !client || !IsClientInGame(client) || !IsPlayerAlive(client) )
    {
        return Plugin_Stop;
    }

    UTIL_GiveWarmUpWeapon(client);
    return Plugin_Stop;
}

void UTIL_GiveWarmUpWeapon(int client)
{
    UTIL_ForceDropAllWeapon(client, false);

    if ( WarmupRandomWeaponMode )
    {
        if ( WarmupRandomWeaponMode == 1 || WarmupRandomWeaponMode == 2 )
        {
            if ( WarmupRandomWeaponLevel == -1 )
            {
                WarmupRandomWeaponLevel = UTIL_GetRandomInt(0, WeaponOrderCount-1);
            }
            UTIL_GiveNextWeapon(client, WarmupRandomWeaponLevel);
        }
        else if ( WarmupRandomWeaponMode == 3 )
        {
            UTIL_GiveNextWeapon(client, UTIL_GetRandomInt(0, WeaponOrderCount-1));
        }
        return;
    }

    bool nades = WarmupNades;
    bool wpn = g_Cfg_WarmupWeapon && !(g_WeaponLevelIndex[g_Cfg_WarmupWeapon] == g_WeaponLevelIdKnife);

    if ( nades )
    {
        GivePlayerItemWrapper(client, g_WeaponName[g_WeaponIdHegrenade]);
        if ( !wpn )
        {
            FakeClientCommand(client, "use %s", g_WeaponName[g_WeaponIdHegrenade]);
        }
    }
    if ( wpn )
    {
        GivePlayerItemWrapper(client, g_WeaponName[g_Cfg_WarmupWeapon]);
        FakeClientCommand(client, "use %s", g_WeaponName[g_Cfg_WarmupWeapon]);
    }

    if ( !nades && !wpn )
    {
        FakeClientCommand(client, "use %s", g_WeaponName[g_WeaponIdKnife]);
    }
}

int UTIL_GetRandomInt(int start, int end)
{
    return GetRandomInt(start, end);
}

void UTIL_GiveExtraNade(int client, bool knifeKill)
{
    /* Give them another grenade if they killed another person with another weapon or hegrenade with the option enabled*/
    #if defined GUNGAME_DEBUG
        LogError("[DEBUG-GUNGAME] FUNC UTIL_GiveExtraNade, g_Cfg_ExtraNade=%i knifeKill=%i", g_Cfg_ExtraNade, knifeKill);
    #endif
    if ( g_Cfg_ExtraNade && ( knifeKill || g_Cfg_ExtraNade == 1 ) )
    {
        /* Do not give them another nade if they already have one */
        if ( !UTIL_HasClientHegrenade(client) )
        {
            bool blockWeapSwitch = ( g_Cfg_BlockWeaponSwitchIfKnife && knifeKill ) || g_Cfg_BlockWeaponSwitchOnNade;
            int newWeapon = GivePlayerItemWrapper(
                client,
                g_WeaponName[g_WeaponIdHegrenade],
                blockWeapSwitch
            );
            if ( !blockWeapSwitch )
            {
                UTIL_UseWeapon(client, g_WeaponIdHegrenade);
                UTIL_FastSwitchWithCheck(client, newWeapon, true, g_WeaponIdHegrenade);
            }
        }
    }
}

void UTIL_SetClientScoreAndDeaths(int client, int score, int deaths = -1)
{
    SetEntProp(client, Prop_Data, "m_iFrags", score);
    if ( deaths >= 0 )
    {
        SetEntProp(client, Prop_Data, "m_iDeaths", deaths);
    }
}

void UTIL_UpdatePlayerScoreLevel(int client)
{
    if ( WarmupEnabled && !DisableWarmupOnRoundEnd )
    {
        return;
    }
    if ( g_Cfg_LevelsInScoreboard && client && IsClientInGame(client) )
    {
        UTIL_SetClientScoreAndDeaths(client, PlayerLevel[client] + 1, g_Cfg_ScoreboardClearDeaths ? 0 : -1);
    }
}

void UTIL_UpdatePlayerScoreDelayed(int client)
{
    if ( g_Cfg_LevelsInScoreboard && client && IsClientInGame(client) )
    {
        CreateTimer(0.1, UTIL_Timer_UpdatePlayerScore, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action UTIL_Timer_UpdatePlayerScore(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if ( client )
    {
        UTIL_UpdatePlayerScoreLevel(client);
    }
    return Plugin_Stop;
}

void UTIL_ShowHintTextMulti(int client, const char[] textHint, int times, float time)
{
    if ( IsFakeClient(client) )
    {
        return;
    }

    /* First display right away, then every "time" seconds. */
    PrintHintText(client, "%s", textHint);
    if ( times <= 1 )
    {
        return;
    }

    DataPack data = new DataPack();
    data.WriteCell(times - 1);
    data.WriteCell(GetClientUserId(client));
    data.WriteString(textHint);

    CreateTimer(time, UTIL_Timer_ShowHintText, data, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
}

public Action UTIL_Timer_ShowHintText(Handle timer, DataPack data)
{
    char textHint[512];

    data.Reset();
    int times = data.ReadCell();
    int client = GetClientOfUserId(data.ReadCell());
    data.ReadString(textHint, sizeof(textHint));

    if ( !client || !IsClientInGame(client) )
    {
        return Plugin_Stop;
    }

    PrintHintText(client, "%s", textHint);
    if ( --times <= 0 )
    {
        return Plugin_Stop;
    }

    data.Reset();
    data.WriteCell(times);
    return Plugin_Continue;
}

void UTIL_ArrayIntRand(int[] array, int size)
{
    if ( size < 2 )
    {
        return;
    }
    int tmpIndex, tmpValue;
    for ( int i = 0; i < size-1; i++ )
    {
        tmpIndex = UTIL_GetRandomInt(i, size-1);
        if ( tmpIndex == i )
        {
            continue;
        }
        tmpValue = array[tmpIndex];

        array[tmpIndex] = array[i];
        array[i] = tmpValue;
    }
}

int UTIL_GetCustomKillPerLevel(int level)
{
    int killsPerLevel = CustomKillPerLevel[level];
    return killsPerLevel ? killsPerLevel : MinKillsPerLevel;
}

int UTIL_GetHandicapLevel(int skipClient = 0, int aboveLevel = -1)
{
    int level = -1;
    if ( HandicapMode == 1 ) {
        level = UTIL_GetAverageLevel(g_Cfg_HandicapSkipBots, aboveLevel, skipClient);
    } else if ( HandicapMode == 2 ) {
        level = UTIL_GetMinimumLevel(g_Cfg_HandicapSkipBots, aboveLevel, skipClient);
    }
    if ( level == -1 ) {
        return 0;
    }
    level -= g_Cfg_HandicapLevelSubstract;
    if ( g_Cfg_MaxHandicapLevel && g_Cfg_MaxHandicapLevel < level ) {
        level = g_Cfg_MaxHandicapLevel;
    }
    if ( level < 1 ) {
        return 0;
    }
    return level;
}

int UTIL_GetMinimumLevel(bool skipBots = false, int aboveLevel = -1, int skipClient = 0)
{
    int minimum = -1;
    int level = 0;
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) && ( g_Cfg_HandicapUseSpectators || GetClientTeam(i) > TEAM_SPECTATOR ) )
        {
            if ( ( skipBots && IsFakeClient(i) )
                || ( GetClientTeam(i) < TEAM_T )
                || ( skipClient == i ) )
            {
                continue;
            }
            level = PlayerLevel[i];
            if ( aboveLevel >= level ) {
                continue;
            }
            if ( (minimum == -1) || (level < minimum) )
            {
                minimum = level;
            }
        }
    }
    return minimum;
}

int UTIL_GetAverageLevel(bool skipBots = false, int aboveLevel = -1, int skipClient = 0)
{
    int count, level, tmpLevel;
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) && ( g_Cfg_HandicapUseSpectators || GetClientTeam(i) > TEAM_SPECTATOR ) )
        {
            if ( ( skipBots && IsFakeClient(i) )
                || ( GetClientTeam(i) < TEAM_T )
                || ( skipClient == i ) )
            {
                continue;
            }
            tmpLevel = PlayerLevel[i];
            if ( aboveLevel >= tmpLevel ) {
                continue;
            }
            level += tmpLevel;
            count++;
        }
    }
    if ( !count ) {
        return -1;
    }
    level /= count;
    return level;
}

bool UTIL_SetHandicapForClient(int client)
{
    if ( g_Cfg_HandicapTimesPerMap )
    {
        char auth[64];
        if ( !GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)) )
        {
            /* Not authenticated yet (or a bot): key on the userid. */
            FormatEx(auth, sizeof(auth), "#%d", GetClientUserId(client));
        }

        int times = 0;
        if ( !PlayerHandicapTimes.GetValue(auth, times) ) {
            times = 0;
        }

        if ( times >= g_Cfg_HandicapTimesPerMap ) {
            return false;
        }

        times++;
        PlayerHandicapTimes.SetValue(auth, times);
    }

    return GiveHandicapLevel(client);
}

void UTIL_StartEffectClient(int client)
{
    if ( EntRefToEntIndex(g_Ent_Effect[client]) > 0 )
    {
        return;
    }
    int ent = UTIL_CreateEffect(client);
    g_Ent_Effect[client] = ent > 0 ? EntIndexToEntRef(ent) : -1;
}

void UTIL_StopEffectClient(int client)
{
    int ent = EntRefToEntIndex(g_Ent_Effect[client]);
    g_Ent_Effect[client] = -1;
    if ( ent <= 0 )
    {
        return;
    }
    if ( g_Cfg_MultilevelEffectType != 1 )
    {
        AcceptEntityInput(ent, "TurnOff");
    }
    AcceptEntityInput(ent, "Kill");
}

int UTIL_CreateMultilevelEffect1(int client)
{
    int ent = CreateEntityByName("env_spritetrail");
    if ( ent == -1 )
    {
        return -1;
    }
    char target[32];
    Format(target, sizeof(target), "target%i", client);

    DispatchKeyValue(client, "targetname", target);
    DispatchKeyValue(ent, "parentname", target);
    DispatchKeyValue(ent, "lifetime", "1.0");
    DispatchKeyValue(ent, "endwidth", "1.0");
    DispatchKeyValue(ent, "startwidth", "20.0");
    DispatchKeyValue(ent, "spritename", "materials/sprites/crystal_beam1.vmt");
    DispatchKeyValue(ent, "renderamt", "255");
    DispatchKeyValue(ent, "rendercolor", "255 128 0");
    DispatchKeyValue(ent, "rendermode", "5");

    DispatchSpawn(ent);

    float Client_Origin[3];
    GetClientAbsOrigin(client, Client_Origin);
    Client_Origin[2] += 20.0; //Beam clips into the floor without this
    TeleportEntity(ent, Client_Origin, NULL_VECTOR, NULL_VECTOR);

    SetVariantString(target);
    AcceptEntityInput(ent, "SetParent");
    return ent;
}

int UTIL_CreateMultilevelEffect2(int client)
{
    int particle = CreateEntityByName("env_smokestack");
    if ( particle == -1 )
    {
        LogError("Failed to create env_smokestack for client %i!", client);
        return -1;
    }

    char Name[32];
    float fPos[3], fAng[3] = { 0.0, 0.0, 0.0 };
    Format(Name, sizeof(Name), "CSParticle_%i", client);
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
    fPos[2] += 28.0;

    //Set Key Values
    DispatchKeyValueVector(particle, "Origin", fPos);
    DispatchKeyValueVector(particle, "Angles", fAng);
    DispatchKeyValueFloat(particle, "BaseSpread", 15.0);
    DispatchKeyValueFloat(particle, "StartSize", 2.0);
    DispatchKeyValueFloat(particle, "EndSize", 6.0);
    DispatchKeyValueFloat(particle, "Twist", 0.0);

    DispatchKeyValue(particle, "Name", Name);
    DispatchKeyValue(particle, "SmokeMaterial", MULTI_LEVEL_EFFECT2);
    DispatchKeyValue(particle, "RenderColor", "252 232 131");
    DispatchKeyValue(particle, "SpreadSpeed", "10");
    DispatchKeyValue(particle, "RenderAmt", "200");
    DispatchKeyValue(particle, "JetLength", "13");
    DispatchKeyValue(particle, "RenderMode", "0");
    DispatchKeyValue(particle, "Initial", "0");
    DispatchKeyValue(particle, "Speed", "10");
    DispatchKeyValue(particle, "Rate", "173");
    DispatchSpawn(particle);

    //Set Entity Inputs
    SetVariantString("!activator");
    AcceptEntityInput(particle, "SetParent", client, particle, 0);
    AcceptEntityInput(particle, "TurnOn");
    return particle;
}

int UTIL_CreateEffect(int client)
{
    if ( !IsClientInGame(client) )
    {
        return -1;
    }

    if ( g_Cfg_MultilevelEffectType == 1 )
    {
        return UTIL_CreateMultilevelEffect1(client);
    }
    return UTIL_CreateMultilevelEffect2(client);
}

void UTIL_RemoveAmmo(int client, int weapon)
{
    int primaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if ( primaryAmmoType != -1 )
    {
        SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, primaryAmmoType);
    }

    // LEAVE ONE CLIP, REMOVE EXTRA CLIPS
    SetEntProp(weapon, Prop_Send, "m_iClip2", 0);

    if ( g_Cfg_BonusWeaponAmmo > 0 )
    {
        SetEntProp(weapon, Prop_Send, "m_iClip1", g_Cfg_BonusWeaponAmmo);
    }
}

/**
 * Removes from the world.
 *
 * @param entity        entity index
 */
void UTIL_Remove(int entity)
{
    if ( entity > 0 && IsValidEntity(entity) )
    {
        AcceptEntityInput(entity, "Kill");
    }
}

void UTIL_EndMultiplayerGameDelayed()
{
    if ( g_Cfg_EndGameDelay > 0.0 )
    {
        CreateTimer(g_Cfg_EndGameDelay, UTIL_Timer_EndMultiplayerGame, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        UTIL_EndMultiplayerGame();
    }
}

public Action UTIL_Timer_EndMultiplayerGame(Handle timer)
{
    UTIL_EndMultiplayerGame();
    return Plugin_Stop;
}

/**
 * Forces multiplayer game to end so it can go threw intermission and map change.
 */
void UTIL_EndMultiplayerGame()
{
    if ( g_Cfg_EndGameSilent )
    {
        UTIL_EndMultiplayerGameSilent();
    }
    else
    {
        UTIL_EndMultiplayerGameNormal();
    }
}

void UTIL_EndMultiplayerGameSilent()
{
    int ent = CreateEntityByName("game_end");
    if ( ent == -1 )
    {
        return;
    }
    DispatchSpawn(ent);
    AcceptEntityInput(ent, "EndGame");
}

void UTIL_SetConVarIntByName(const char[] name, int value)
{
    ConVar cvar = FindConVar(name);
    if ( cvar != null )
    {
        cvar.IntValue = value;
    }
}

void UTIL_EndMultiplayerGameNormal()
{
    UTIL_SetConVarIntByName("mp_timelimit", 0);
    UTIL_SetConVarIntByName("mp_fraglimit", 0);
    UTIL_SetConVarIntByName("mp_maxrounds", 0);
    UTIL_SetConVarIntByName("mp_winlimit", 0);

    if ( GameWinner && IsClientInGame(GameWinner) && GetClientTeam(GameWinner) == CS_TEAM_T )
    {
        CS_TerminateRound(0.1, CSRoundEnd_TerroristWin);
    }
    else
    {
        CS_TerminateRound(0.1, CSRoundEnd_CTWin);
    }
}

/**
 * Get the count of any grenade type a client has.
 *
 * @param client        The client index.
 * @param type          The ammo type of the grenade.
 */
int UTIL_WeaponAmmoGetGrenadeCount(int client, int type)
{
    return GetEntProp(client, Prop_Send, "m_iAmmo", _, type);
}

bool UTIL_HasClientHegrenade(int client)
{
    return UTIL_WeaponAmmoGetGrenadeCount(client, g_WeaponAmmoTypeHegrenade) > 0;
}

void UTIL_FastSwitch(int client, int weapon, bool setActiveWeapon)
{
    float GameTime = GetGameTime();

    if ( setActiveWeapon )
    {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GameTime);
    }

    SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GameTime);
    int ViewModel = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    if ( ViewModel != -1 )
    {
        SetEntProp(ViewModel, Prop_Send, "m_nSequence", 0);
    }
}

void UTIL_FastSwitchWithCheck(int client, int weapon, bool setActiveWeapon, int weaponId)
{
    if ( g_Cfg_FastSwitchOnLevelUp && (!g_Cfg_FastSwitchSkipWeapons[weaponId]) && weapon > 0 )
    {
        UTIL_FastSwitch(client, weapon, setActiveWeapon);
    }
}

void UTIL_UseWeapon(int client, int WeapId)
{
    g_BlockFastSwitchOnChange[client] = true;
    FakeClientCommand(client, "use %s", g_WeaponName[WeapId]);
    g_BlockFastSwitchOnChange[client] = false;
}

void UTIL_RemoveEntityByClassName(const char[] entityName)
{
    int ent = -1;
    while ( (ent = FindEntityByClassname(ent, entityName)) != -1 )
    {
        AcceptEntityInput(ent, "Kill");
    }
}

void UTIL_ResetMatchKills()
{
    for ( int i = 0; i <= MaxClients; i++ )
    {
        g_MatchKills[i] = 0;
    }
}

/**
 * Sort callback for GG_GetRanking: level desc, kills desc, points desc, client asc.
 */
public int UTIL_SortRanking(int elem1, int elem2, const int[] array, Handle hndl)
{
    if ( GameWinner )
    {
        if ( elem1 == GameWinner ) return -1;
        if ( elem2 == GameWinner ) return 1;
    }
    if ( PlayerLevel[elem1] != PlayerLevel[elem2] )
    {
        return PlayerLevel[elem1] > PlayerLevel[elem2] ? -1 : 1;
    }
    if ( g_MatchKills[elem1] != g_MatchKills[elem2] )
    {
        return g_MatchKills[elem1] > g_MatchKills[elem2] ? -1 : 1;
    }
    if ( CurrentKillsPerWeap[elem1] != CurrentKillsPerWeap[elem2] )
    {
        return CurrentKillsPerWeap[elem1] > CurrentKillsPerWeap[elem2] ? -1 : 1;
    }
    return elem1 < elem2 ? -1 : 1;
}

int UTIL_BuildRanking(int[] clients, int maxClients)
{
    int list[MAXPLAYERS + 1];
    int count = 0;
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientInGame(i) && (GetClientTeam(i) >= TEAM_T || i == GameWinner) )
        {
            list[count++] = i;
        }
    }

    SortCustom1D(list, count, UTIL_SortRanking);

    if ( count > maxClients )
    {
        count = maxClients;
    }
    for ( int i = 0; i < count; i++ )
    {
        clients[i] = list[i];
    }
    return count;
}
