void OnEventStart()
{
    // Events
    HookEvent("round_start", _RoundState);
    HookEvent("round_end", _RoundState);
    HookEvent("player_death", _PlayerDeath);
    HookEvent("player_spawn", _PlayerSpawn);
    HookEvent("player_team", _PlayerTeam);
    HookEvent("item_pickup", _ItemPickup);
    HookEvent("hegrenade_detonate", _HeExplode);

    if ( g_Cfg_BlockWeaponSwitchIfKnife || g_Cfg_BlockWeaponSwitchOnNade ) {
        for ( int client = 1; client <= MaxClients; client++ ) {
            g_BlockSwitch[client] = false;
        }
    }

    if ( g_Cfg_SelfKillProtection ) {
        AddCommandListener(Event_KillCommand, "kill");
        AddCommandListener(Event_KillCommand, "explode");
    }
}

void OnEventShutdown()
{
    // Events
    UnhookEvent("round_start", _RoundState);
    UnhookEvent("round_end", _RoundState);
    UnhookEvent("player_death", _PlayerDeath);
    UnhookEvent("player_spawn", _PlayerSpawn);
    UnhookEvent("player_team", _PlayerTeam);
    UnhookEvent("item_pickup", _ItemPickup);
    UnhookEvent("hegrenade_detonate", _HeExplode);

    /* Removing a listener that was not added is harmless. */
    RemoveCommandListener(Event_KillCommand, "kill");
    RemoveCommandListener(Event_KillCommand, "explode");
}

public void _ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
    if ( !IsActive || !KnifeElite )
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if ( client && (PlayerState[client] & KNIFE_ELITE) )
    {
        UTIL_ForceDropAllWeapon(client, false);
    }
}

public void _BombPickup(Event event, const char[] name, bool dontBroadcast)
{
    if ( IsActive && (MapStatus & OBJECTIVE_REMOVE_BOMB) )
    {
        int client = GetClientOfUserId(event.GetInt("userid"));
        if ( client )
        {
            UTIL_ForceDropC4(client);
        }
    }
}

public void _PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int oldTeam         = event.GetInt("oldteam");
    int newTeam         = event.GetInt("team");
    bool disconnect     = event.GetBool("disconnect");

    switch ( oldTeam )
    {
        case TEAM_T:
        {
            Tcount--;
        }
        case TEAM_CT:
        {
            CTcount--;
        }
    }

    /* Player disconnected and didn't join a new team */
    if ( !disconnect )
    {
        switch ( newTeam )
        {
            case TEAM_T:
            {
                Tcount++;
            }
            case TEAM_CT:
            {
                CTcount++;
            }
        }
    }

    if ( UnlimitedNadesMinPlayers )
    {
        UnlimitedNades = ( Tcount <= UnlimitedNadesMinPlayers || CTcount <= UnlimitedNadesMinPlayers );
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if ( client && !disconnect && (oldTeam >= TEAM_T) && IsClientInGame(client) && IsPlayerAlive(client) )
    {
        UTIL_StopTripleEffects(client);
    }
    if ( !client || disconnect || (oldTeam < TEAM_T) || (newTeam < TEAM_T) || !IsPlayerAlive(client) || (oldTeam == newTeam) )
    {
        return;
    }
    g_teamChange[client] = true;
}

public void _RoundState(Event event, const char[] name, bool dontBroadcast)
{
    if ( !IsActive )
    {
        return;
    }

    /**
     * round_start
     * round_end
     * 0123456
     */
    if ( name[6] == 's' )
    {
        if ( GameWinner )
        {
            /* Lock all player since the winner was declare already if new round happened. */
            if ( g_Cfg_WinnerFreezePlayers )
            {
                UTIL_FreezeAllPlayers();
            }
        }

        /* Round has Started. */
        RoundStarted = true;

        /* Only remove the hostages on after it been initialized */
        if ( (MapStatus & OBJECTIVE_HOSTAGE) && (MapStatus & OBJECTIVE_REMOVE_HOSTAGE) )
        {
            /*Delay for 0.1 because data need to be filled for hostage entity index */
            CreateTimer(0.1, RemoveHostages, _, TIMER_FLAG_NO_MAPCHANGE);
        }

        UTIL_PlaySoundForLeaderLevel();

        // Disable warmup
        if ( WarmupEnabled && DisableWarmupOnRoundEnd )
        {
            WarmupEnabled = false;
            DisableWarmupOnRoundEnd = false;
        }

        TryStartMatch();

        UTIL_RemoveEntityByClassName("game_player_equip");
    } else {
        /* Round has ended. */
        RoundStarted = false;

        if ( WarmupEnabled && WarmupRandomWeaponMode == 2 )
        {
            WarmupRandomWeaponLevel = -1;
        }
    }
}

public Action RemoveHostages(Handle timer)
{
    int ent = -1;
    while ( (ent = FindEntityByClassname(ent, "hostage_entity")) != -1 )
    {
        AcceptEntityInput(ent, "Kill");
    }
    return Plugin_Stop;
}

public void _PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    // Player has died.
    if ( !IsActive )
    {
        return;
    }

    int Victim = GetClientOfUserId(event.GetInt("userid"));
    if ( !Victim )
    {
        return;
    }
    UTIL_StopTripleEffects(Victim);

    int Killer = GetClientOfUserId(event.GetInt("attacker"));
    UTIL_UpdatePlayerScoreDelayed(Victim);
    UTIL_UpdatePlayerScoreDelayed(Killer);

    /* They change team at round end don't punish them. */
    if ( !RoundStarted && !AllowLevelUpAfterRoundEnd )
    {
        return;
    }

    char Weapon[MAX_WEAPON_NAME_SIZE], vName[MAX_NAME_SIZE], kName[MAX_NAME_SIZE];

    event.GetString("weapon", Weapon, sizeof(Weapon));
    GetClientName(Victim, vName, sizeof(vName));
    if ( Killer )
    {
        GetClientName(Killer, kName, sizeof(kName));
    }

    #if defined GUNGAME_DEBUG
        LogError("[DEBUG-GUNGAME] EVENT PLAYER_DEATH weapon=%s victim=%s killer=%s", Weapon, vName, kName);
    #endif

    /* Kill self with world spawn */
    if ( !Killer )
    {
        if ( RoundStarted && WorldspawnSuicide )
        {
            ClientSuicide(Victim, vName, WorldspawnSuicide);
        }
        return;
    }

    /* They killed themself by kill command or by hegrenade etc */
    if ( Victim == Killer )
    {
        /* (Weapon is event weapon name, can be 'world' or 'hegrenade' etc) */
        if ( CommitSuicide && ( RoundStarted || /* weapon is not 'world' (ie not kill command) */ Weapon[0] != 'w') && (!g_teamChange[Victim]) )
        {
            ClientSuicide(Victim, vName, CommitSuicide);
        }
        return;
    }

    // Victim > 0 && Killer > 0

    int WeaponIndex = UTIL_GetWeaponIndex(Weapon), WeaponLevelIndex = g_WeaponLevelIndex[WeaponIndex];
    Action ret = Plugin_Continue;

    if ( WarmupEnabled )
    {
        if ( ReloadWeapon )
        {
            UTIL_ReloadActiveWeapon(Killer, WeaponIndex);
        }
        return;
    }

    /* In FFA mode a kill on a "teammate" is a normal kill: no team kill, no team kill penalty. */
    bool TeamKill = (!FFA) && (GetClientTeam(Victim) == GetClientTeam(Killer));
    Call_StartForward(FwdDeath);
    Call_PushCell(Killer);
    Call_PushCell(Victim);
    Call_PushCell(WeaponIndex);
    Call_PushCell(TeamKill && mp_friendlyfire.BoolValue);
    Call_Finish(ret);

    if ( ret != Plugin_Continue || TeamKill )
    {
        if ( ret == Plugin_Changed )
        {
            UTIL_ReloadActiveWeapon(Killer, WeaponIndex);
        }
        return;
    }

    /* The kill counts for gungame. */
    g_MatchKills[Killer]++;

    int level = PlayerLevel[Killer], WeaponLevel = WeaponOrderId[level], PlayerLevelIndex = g_WeaponLevelIndex[WeaponLevel];

    /* Give them another grenade if they killed another person with another weapon */
    if ( (PlayerLevelIndex == g_WeaponLevelIdHegrenade)
        && (WeaponLevelIndex != g_WeaponLevelIdHegrenade)
        && !( (WeaponLevelIndex == g_WeaponLevelIdKnife) && KnifeProHE ) // TODO: Remove this statement and make check if killer not leveled up, than give extra nade.
    ) {
        #if defined GUNGAME_DEBUG
            LogError("[DEBUG-GUNGAME] ... call UTIL_GiveExtraNade, killer=%i knife=%i", Killer, (WeaponLevelIndex == g_WeaponLevelIdKnife));
        #endif
        UTIL_GiveExtraNade(Killer, (WeaponLevelIndex == g_WeaponLevelIdKnife));
    }

    if ( MaxLevelPerRound && CurrentLevelPerRound[Killer] >= MaxLevelPerRound )
    {
        return;
    }

    /**
     * Steal level from other player.
     */
    if ( KnifePro && (WeaponLevelIndex == g_WeaponLevelIdKnife) )
    {
        if ( KnifeSteal(Killer, Victim, level, PlayerLevelIndex, WeaponLevelIndex, kName, vName) )
        {
            return;
        }
    }

    bool LevelUpWithPhysics = false;

    /* They didn't kill with the weapon required */
    if ( WeaponLevelIndex != PlayerLevelIndex )
    {
        if ( WeaponLevelIndex == g_WeaponLevelIdHegrenade )
        {
            // Killed with grenade made by map author
            if (
                g_Cfg_CanLevelUpWithMapNades
                && (
                    g_Cfg_CanLevelUpWithNadeOnKnife
                    || !(PlayerLevelIndex == g_WeaponLevelIdKnife)
                )
            ) {
                LevelUpWithPhysics = true;
            } else {
                return;
            }
        } else {
            // Maybe killed with physics made by map author
            if (
                g_Cfg_CanLevelUpWithPhysics
                && ( StrEqual(Weapon, "prop_physics") || StrEqual(Weapon, "prop_physics_multiplayer") )
                && (
                    ( ( PlayerLevelIndex != g_WeaponLevelIdHegrenade) && !(PlayerLevelIndex == g_WeaponLevelIdKnife) )
                    || ( g_Cfg_CanLevelUpWithPhysicsG && (PlayerLevelIndex == g_WeaponLevelIdHegrenade) )
                    || ( g_Cfg_CanLevelUpWithPhysicsK && (PlayerLevelIndex == g_WeaponLevelIdKnife) )
                )
            ) {
                LevelUpWithPhysics = true;
            } else {
                return;
            }
        }
    }

    int killsPerLevel = UTIL_GetCustomKillPerLevel(level);
    if ( ( killsPerLevel > 1 ) && !LevelUpWithPhysics )
    {
        int kills = ++CurrentKillsPerWeap[Killer];
        Action Handled = Plugin_Continue;

        if ( kills <= killsPerLevel )
        {
            Call_StartForward(FwdPoint);
            Call_PushCell(Killer);
            Call_PushCell(kills);
            Call_PushCell(1);
            Call_Finish(Handled);

            if ( Handled != Plugin_Continue )
            {
                CurrentKillsPerWeap[Killer]--;
                return;
            }

            if ( kills < killsPerLevel )
            {
                if ( MultiKillChat )
                {
                    char subtext[64];
                    FormatLanguageNumberTextEx(Killer, subtext, sizeof(subtext), killsPerLevel - kills, "points");
                    if ( !g_Cfg_ShowSpawnMsgInHintBox )
                    {
                        CPrintToChat(Killer, "%t", "You need kills to advance to the next level", subtext, kills, killsPerLevel);
                    }
                    else
                    {
                        SetGlobalTransTarget(Killer);
                        char textHint[256];
                        Format(textHint, sizeof(textHint), "%t", "You need kills to advance to the next level", subtext, kills, killsPerLevel);
                        CRemoveTags(textHint, sizeof(textHint));

                        UTIL_ShowHintTextMulti(Killer, textHint, 3, 1.0);
                    }
                }

                UTIL_PlaySound(Killer, MultiKill);
                if ( ReloadWeapon )
                {
                    UTIL_ReloadActiveWeapon(Killer, WeaponLevel);
                }
                return;
            }
        }
    }

    // reload weapon
    if ( !TurboMode && ReloadWeapon )
    {
        UTIL_ReloadActiveWeapon(Killer, WeaponLevel);
    }

    if ( KnifeElite )
    {
        PlayerState[Killer] |= KNIFE_ELITE;
    }

    int oldLevelKiller = level;
    level = UTIL_ChangeLevel(Killer, 1, false, Victim, GGLevelReason_Kill);
    if ( oldLevelKiller == level )
    {
        return;
    }

    CurrentLevelPerRound[Killer]++;

    PrintLeaderToChat(Killer, oldLevelKiller, level, kName);

    if ( TurboMode || KnifeElite )
    {
        UTIL_GiveNextWeapon(Killer, level, (WeaponLevelIndex == g_WeaponLevelIdKnife));
    }

    CheckForTripleLevel(Killer);
}

/**
 * Knife steal (KnifePro).
 *
 * @return      True if the kill has been fully handled,
 *              false to continue with the normal level up.
 */
bool KnifeSteal(int Killer, int Victim, int level, int PlayerLevelIndex, int WeaponLevelIndex, const char[] kName, const char[] vName)
{
    int VictimLevel = PlayerLevel[Victim];

    if ( VictimLevel < KnifeProMinLevel )
    {
        CPrintToChatEx(Killer, Victim, "%t", "Is lower than the minimum knife stealing level", vName, KnifeProMinLevel + 1);
        return false;
    }

    if ( g_Cfg_KnifeProMaxDiff && ( g_Cfg_KnifeProMaxDiff < level - VictimLevel ) )
    {
        CPrintToChatEx(Killer, Victim, "%t", "You can not steal level from %s, your levels difference is more then %d", vName, g_Cfg_KnifeProMaxDiff);
        return false;
    }

    bool victimLost = false;
    if ( !g_Cfg_DisableLevelDown )
    {
        int ChangedLevel = UTIL_ChangeLevel(Victim, -1, true, 0, GGLevelReason_KnifeStolen);
        if ( VictimLevel )
        {
            if ( ChangedLevel == VictimLevel ) {
                return false;
            }
            victimLost = true;
            CPrintToChatAllEx(Killer, "%t", "Has stolen a level from", kName, vName);
        }
    }

    if ( (PlayerLevelIndex == g_WeaponLevelIdKnife) && (UTIL_GetCustomKillPerLevel(level) > 1) )
    {
        if ( victimLost ) {
            UTIL_FireKnifeSteal(Killer, Victim, victimLost);
        }
        return false;
    }

    if ( (!KnifeProHE && PlayerLevelIndex == g_WeaponLevelIdHegrenade) )
    {
        if ( victimLost ) {
            UTIL_FireKnifeSteal(Killer, Victim, victimLost);
        }
        return true;
    }

    int oldLevelKiller = level;
    level = UTIL_ChangeLevel(Killer, 1, true, Victim, GGLevelReason_KnifeSteal);
    if ( oldLevelKiller == level )
    {
        if ( victimLost ) {
            UTIL_FireKnifeSteal(Killer, Victim, victimLost);
        }
        return true;
    }

    PrintLeaderToChat(Killer, oldLevelKiller, level, kName);
    CurrentLevelPerRound[Killer]++;

    if ( TurboMode )
    {
        UTIL_GiveNextWeapon(Killer, level, (WeaponLevelIndex == g_WeaponLevelIdKnife));
    }

    UTIL_FireKnifeSteal(Killer, Victim, victimLost);

    CheckForTripleLevel(Killer);

    return true;
}

// Player has spawned
public void _PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if ( !IsActive )
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if ( !client )
    {
        return;
    }

    if ( g_SkipSpawn[client] )
    {
        g_SkipSpawn[client] = false;
        return;
    }

    UTIL_UpdatePlayerScoreLevel(client);
    UTIL_StopBonusGravity(client);

    g_teamChange[client] = false;

    int team = GetClientTeam(client);

    if ( team != TEAM_T && team != TEAM_CT )
    {
        return;
    }

    /* Reset Knife Elite state */
    if ( KnifeElite )
    {
        PlayerState[client] &= ~KNIFE_ELITE;
    }

    /* They are not alive don't proccess */
    if ( !IsPlayerAlive(client) )
    {
        return;
    }

    if ( !(PlayerState[client] & FIRST_JOIN) )
    {
        PlayerState[client] |= FIRST_JOIN;

        if ( !IsFakeClient(client) )
        {
            UTIL_PlaySoundDelayed(1.5, client, Welcome);

            /**
             * Show join message.
             */

            if ( JoinMessage )
            {
                ShowJoinMsgPanel(client);
            }
        }

        if ( !StatsEnabled || GG_IsPlayerWinsLoaded(client) ) /* HINT: gungame_stats */
        {
            UTIL_SetHandicapForClient(client);
        }
    }

    if ( g_Cfg_ArmorKevlar )
    {
        /* Set armor to 100. */
        SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
    }
    if ( g_Cfg_ArmorHelmet )
    {
        /* Set user with helm. */
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
    }

    CurrentLevelPerRound[client] = 0;
    CurrentLevelPerRoundTriple[client] = 0;

    if ( team == TEAM_CT )
    {
        if ( (MapStatus & OBJECTIVE_BOMB) && !(MapStatus & OBJECTIVE_REMOVE_BOMB) )
        {
            // Give them a defuser if objective is not removed
            SetEntProp(client, Prop_Send, "m_bHasDefuser", 1);
        }
    }

    int Level = PlayerLevel[client];
    UTIL_ForceDropAllWeapon(client, false);

    /* For deathmatch when they get respawn after round start freeze after game winner. */
    if ( GameWinner && g_Cfg_WinnerFreezePlayers )
    {
        UTIL_FreezePlayer(client);
    }

    if ( WarmupEnabled && !DisableWarmupOnRoundEnd )
    {
        if ( !WarmupInitialized ) {
            CPrintToChat(client, "%t", "Warmup round has not started yet");
        } else {
            CPrintToChat(client, "%t", "Warmup round is in progress");
        }

        UTIL_GiveWarmUpWeaponDelayed(0.3, client);
        return;
    }

    UTIL_GiveNextWeapon(client, Level, false, 0.3, true);

    // spawn chat messages
    int killsPerLevel = UTIL_GetCustomKillPerLevel(Level);

    if ( !g_Cfg_ShowSpawnMsgInHintBox )
    {
        CPrintToChat(client, "%t", "You are on level", Level + 1, WeaponOrderName[Level]);

        if ( MultiKillChat && ( killsPerLevel > 1 ) )
        {
            int kills = CurrentKillsPerWeap[client];
            char subtext[64];
            FormatLanguageNumberTextEx(client, subtext, sizeof(subtext), killsPerLevel - kills, "points");
            CPrintToChat(client, "%t", "You need kills to advance to the next level", subtext, kills, killsPerLevel);
        }
    }
    else
    {
        SetGlobalTransTarget(client);
        char textHint[512], textHint2[256];
        Format(textHint, sizeof(textHint), "%t", "You are on level", Level + 1, WeaponOrderName[Level]);
        CRemoveTags(textHint, sizeof(textHint));
        if ( g_Cfg_ShowLeaderInHintBox && CurrentLeader )
        {
            int leaderLevel = PlayerLevel[CurrentLeader];
            if ( client == CurrentLeader ) {
                Format(textHint2, sizeof(textHint2), "\n%t", "LevelPanel: You are currently the leader");
            } else if ( Level == leaderLevel ) {
                Format(textHint2, sizeof(textHint2), "\n%t", "LevelPanel: You have tied with the leader");
            } else {
                Format(textHint2, sizeof(textHint2), "\n%t", "Hint: Leader is on level", leaderLevel + 1, WeaponOrderName[leaderLevel]);
            }

            StrCat(textHint, sizeof(textHint), textHint2);
        }
        if ( MultiKillChat && ( killsPerLevel > 1 ) )
        {
            int kills = CurrentKillsPerWeap[client];
            char subtext[64];
            FormatLanguageNumberTextEx(client, subtext, sizeof(subtext), killsPerLevel - kills, "points");
            Format(textHint2, sizeof(textHint2), "\n%t", "You need kills to advance to the next level", subtext, kills, killsPerLevel);
            CRemoveTags(textHint2, sizeof(textHint2));
            StrCat(textHint, sizeof(textHint), textHint2);
        }
        UTIL_ShowHintTextMulti(client, textHint, 3, 1.0);
    }
}

public void _BombState(Event event, const char[] name, bool dontBroadcast)
{
    if ( !IsActive || !ObjectiveBonus || (!RoundStarted && name[5] != 'e') )
    {
        return;
    }
    int client = GetClientOfUserId(event.GetInt("userid"));

    if ( !client || !IsClientInGame(client) )
    {
        return;
    }
    UTIL_UpdatePlayerScoreDelayed(client);

    if ( !ObjectiveBonusWin && ( PlayerLevel[client] >= WeaponOrderCount - ObjectiveBonus ) )
    {
        return;
    }

    if ( ( g_Cfg_ObjectiveBonusExplode && name[5] == 'p' ) ||
         ( !g_Cfg_ObjectiveBonusExplode && name[5] == 'e' ) )
    {
        return;
    }

    /* Give them a level if give level for objective */
    int oldLevel = PlayerLevel[client];
    int newLevel = UTIL_ChangeLevel(client, ObjectiveBonus, false, 0, GGLevelReason_Objective);
    if ( newLevel == oldLevel )
    {
        return;
    }
    char cname[MAX_NAME_SIZE];
    GetClientName(client, cname, sizeof(cname));
    PrintLeaderToChat(client, oldLevel, newLevel, cname);

    char subtext[64];
    FormatLanguageNumberTextEx(client, subtext, sizeof(subtext), ObjectiveBonus, "levels");
    if ( name[5] == 'p' )
    {
        CPrintToChat(client, "%t", "You gained level by planting the bomb", subtext);
    }
    else if ( name[5] == 'e' )
    {
        CPrintToChat(client, "%t", "You gained level by exploding the bomb", subtext);
    }
    else
    {
        CPrintToChat(client, "%t", "You gained level by defusing the bomb", subtext);
    }
}

public void _HostageKilled(Event event, const char[] name, bool dontBroadcast)
{
    if ( !IsActive || !RoundStarted )
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if ( !client )
    {
        return;
    }

    char Name[MAX_NAME_SIZE];
    GetClientName(client, Name, sizeof(Name));

    int oldLevel = PlayerLevel[client];
    int newLevel = UTIL_ChangeLevel(client, -1, false, 0, GGLevelReason_Objective);
    if ( oldLevel == newLevel )
    {
        return;
    }
    PrintLeaderToChat(client, oldLevel, newLevel, Name);
    CPrintToChatAllEx(client, "%t", "Has lost a level by killing a hostage", Name);
}

void ClientSuicide(int client, const char[] Name, int loose)
{
    int oldLevel = PlayerLevel[client];
    int newLevel = UTIL_ChangeLevel(client, -loose, false, 0, GGLevelReason_Suicide);
    if ( oldLevel == newLevel )
    {
        return;
    }
    if ( loose > 1 )
    {
        char subtext[64];
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) )
            {
                SetGlobalTransTarget(i);
                FormatLanguageNumberTextEx(i, subtext, sizeof(subtext), oldLevel - newLevel, "levels");
                CPrintToChatEx(i, client, "%t", "Has lost levels by suicided", Name, subtext);
            }
        }
    }
    else
    {
        CPrintToChatAllEx(client, "%t", "Has lost a level by suicided", Name);
    }

    PrintLeaderToChat(client, oldLevel, newLevel, Name);
}

public void _HeExplode(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if ( !client || !IsClientInGame(client) || !IsPlayerAlive(client) )
    {
        return;
    }

    if ( ( WarmupNades && WarmupEnabled )
         || ( g_WeaponLevelIndex[WeaponOrderId[PlayerLevel[client]]] == g_WeaponLevelIdHegrenade
            && ( UnlimitedNades
               || ( NumberOfNades && g_NumberOfNades[client] ) ) ) )
    {
        /* Do not give them another nade if they already have one */
        if ( !UTIL_HasClientHegrenade(client) )
        {
            if ( NumberOfNades )
            {
                g_NumberOfNades[client]--;
            }

            bool blockSwitch = g_Cfg_BlockWeaponSwitchOnNade;
            int newWeapon = GivePlayerItemWrapper(client, g_WeaponName[g_WeaponIdHegrenade], blockSwitch);
            if ( !blockSwitch )
            {
                UTIL_UseWeapon(client, g_WeaponIdHegrenade);
                UTIL_FastSwitchWithCheck(client, newWeapon, true, g_WeaponIdHegrenade);
            }
        }
    }
}

public Action OnWeaponSwitch(int client, int weapon)
{
    if ( !IsActive )
    {
        return Plugin_Continue;
    }

    if ( g_BlockSwitch[client] )
    {
        return Plugin_Handled;
    }

    if ( g_Cfg_FastSwitchOnChangeWeapon && weapon > 0 && !g_BlockFastSwitchOnChange[client] )
    {
        DataPack data = new DataPack();
        data.WriteCell(GetClientUserId(client));
        data.WriteCell(EntIndexToEntRef(weapon));

        CreateTimer(0.1, Timer_FastSwitch, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
    }

    return Plugin_Continue;
}

public Action Timer_FastSwitch(Handle timer, DataPack data)
{
    data.Reset();
    int client = GetClientOfUserId(data.ReadCell());
    int weapon = EntRefToEntIndex(data.ReadCell());

    if ( client && IsClientInGame(client) && IsPlayerAlive(client) && weapon > 0 )
    {
        UTIL_FastSwitch(client, weapon, false);
    }
    return Plugin_Stop;
}

public Action Event_KillCommand(int client, const char[] command, int argc)
{
    if ( !IsActive || !g_Cfg_SelfKillProtection )
    {
        return Plugin_Continue;
    }
    return Plugin_Handled;
}

public Action OnGetGameDescription(char gameDesc[64])
{
    if ( !g_CfgGameDesc[0] )
    {
        return Plugin_Continue;
    }

    strcopy(gameDesc, sizeof(gameDesc), g_CfgGameDesc);
    return Plugin_Changed;
}

public void Event_CvarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    if ( cvar == g_Cvar_Turbo )
    {
        TurboMode = g_Cvar_Turbo.BoolValue;
    }
    else if ( cvar == g_Cvar_MultiLevelAmount )
    {
        g_Cfg_MultiLevelAmount = g_Cvar_MultiLevelAmount.IntValue;
        if ( g_Cfg_MultiLevelAmount < 0 )
        {
            g_Cfg_MultiLevelAmount = 1;
        }
    }
}

public Action CS_OnCSWeaponDrop(int client, int weapon, bool donated)
{
    if ( !IsActive )
    {
        return Plugin_Continue;
    }
    if ( StripDeadPlayersWeapon == 1 )
    {
        // do not allow drop weapon
        return Plugin_Stop;
    }
    else if ( StripDeadPlayersWeapon == 2 )
    {
        DataPack data = new DataPack();
        data.WriteCell(GetClientUserId(client));
        data.WriteCell(EntIndexToEntRef(weapon));

        CreateTimer(0.1, Timer_RemoveDroppedWeapon, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
    }
    // allow drop weapon
    return Plugin_Continue;
}

public Action Timer_RemoveDroppedWeapon(Handle timer, DataPack data)
{
    data.Reset();
    int client = GetClientOfUserId(data.ReadCell());
    int weapon = EntRefToEntIndex(data.ReadCell());

    if ( weapon <= 0 )
    {
        // entity is invalid
        return Plugin_Stop;
    }

    if ( GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") > 0 )
    {
        // weapon is owned by someone
        return Plugin_Stop;
    }

    if ( client && IsClientInGame(client) && IsPlayerAlive(client) )
    {
        // client, that dropped weapon, is alive
        return Plugin_Stop;
    }

    // client, that dropped weapon, is not alive or does not exist: remove weapon
    UTIL_Remove(weapon);

    return Plugin_Stop;
}
