/**
 * Every query is asynchronous (threaded). The connection is opened once with
 * Database.Connect and kept for the whole plugin life (across map changes).
 *
 * Database: the "gungame" entry of databases.cfg when it exists,
 * otherwise "storage-local" (SQLite, addons/sourcemod/data/sqlite/sourcemod-local.sq3).
 */

void SqlConnect()
{
    if ( g_DbConnection != null || g_DbConnecting )
    {
        return;
    }

    g_DbConnecting = true;
    Database.Connect(T_OnDatabaseConnect, SQL_CheckConfig("gungame") ? "gungame" : "storage-local");
}

public void T_OnDatabaseConnect(Database db, const char[] error, any data)
{
    if ( db == null )
    {
        g_DbConnecting = false;
        SetFailState("Unable to connect to database (%s)", error);
        return;
    }

    char ident[16];
    db.Driver.GetIdentifier(ident, sizeof(ident));
    if ( strcmp(ident, "sqlite") == 0 ) {
        g_DbType = DbTypeSqlite;
    } else if ( strcmp(ident, "mysql") == 0 ) {
        g_DbType = DbTypeMysql;
    } else if ( strcmp(ident, "pgsql") == 0 ) {
        g_DbType = DbTypePgsql;
    } else {
        delete db;
        g_DbConnecting = false;
        SetFailState("Unknown db type (%s)", ident);
        return;
    }

    g_DbPending = db;

    if ( g_DbType == DbTypeMysql )
    {
        g_DbPending.SetCharset("utf8");
    }

    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] %s", g_sql_checkTableExists[g_DbType]);
    #endif
    g_DbPending.Query(T_CheckTableExists, g_sql_checkTableExists[g_DbType]);
}

public void T_CheckTableExists(Database db, DBResultSet result, const char[] error, any data)
{
    if ( result == null )
    {
        LogError("Failed to check table exists (error: %s)", error);
        delete g_DbPending;
        g_DbConnecting = false;
        return;
    }

    if ( result.RowCount > 0 )
    {
        OnDatabaseReady();
        return;
    }

    Transaction txn = CreatePlayerTableTransaction(false);
    g_DbPending.Execute(txn, T_CreateTableSuccess, T_CreateTableFailure);
}

/**
 * Builds the transaction that (re)creates the players table.
 */
Transaction CreatePlayerTableTransaction(bool dropFirst)
{
    Transaction txn = new Transaction();
    if ( dropFirst )
    {
        txn.AddQuery(g_sql_dropPlayerTable);
    }
    txn.AddQuery(g_sql_createPlayerTable[g_DbType]);
    if ( g_sql_createPlayerTableIndex1[g_DbType][0] )
    {
        txn.AddQuery(g_sql_createPlayerTableIndex1[g_DbType]);
    }
    if ( g_sql_createPlayerTableIndex2[g_DbType][0] )
    {
        txn.AddQuery(g_sql_createPlayerTableIndex2[g_DbType]);
    }
    return txn;
}

public void T_CreateTableSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    OnDatabaseReady();
}

public void T_CreateTableFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("Could not create players table (query %d, error: %s)", failIndex, error);
    delete g_DbPending;
    g_DbConnecting = false;
}

/**
 * The connection is ready and the table exists.
 */
void OnDatabaseReady()
{
    if ( g_DbPending != null )
    {
        g_DbConnection = g_DbPending;
        g_DbPending = null;
    }
    g_DbConnecting = false;

    LoadRank();

    /* Players already on the server (late load or connection slower than them). */
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientConnected(i) && IsClientAuthorized(i) && !g_PlayerWinsLoaded[i] )
        {
            RetrieveKeyValues(i);
        }
    }
}

/**
 * Retrieves the Steam2 id stored in the database.
 */
bool GetClientDbAuth(int client, char[] auth, int maxlen)
{
    return GetClientAuthId(client, AuthId_Steam2, auth, maxlen);
}

/**
 * @return      true if the save was sent (GG_OnLoadRank follows), false otherwise.
 */
bool SavePlayerData(int client)
{
    if ( g_DbConnection == null )
    {
        return false;
    }

    char auth[64], name[MAX_NAME_SIZE];
    if ( !GetClientDbAuth(client, auth, sizeof(auth)) )
    {
        return false;
    }
    GetClientName(client, name, sizeof(name));
    StripFourByteUtf8(name);

    char query[1024];
    Transaction txn = new Transaction();

    g_DbConnection.Format(query, sizeof(query), g_sql_addPlayerWins, 1, name, auth);
    txn.AddQuery(query);
    g_DbConnection.Format(query, sizeof(query), g_sql_insertPlayerIfMissing[g_DbType], 1, name, auth, auth);
    txn.AddQuery(query);
    /* Read the real total back (the wins may not have been loaded yet). */
    g_DbConnection.Format(query, sizeof(query), g_sql_getPlayerWinsByAuth, auth);
    txn.AddQuery(query);

    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] save win client=%i auth=%s", client, auth);
    #endif
    g_DbConnection.Execute(txn, T_SavePlayerDataSuccess, T_SavePlayerDataFailure, GetClientUserId(client));
    return true;
}

public void T_SavePlayerDataSuccess(Database db, int userid, int numQueries, DBResultSet[] results, any[] queryData)
{
    int client = GetClientOfUserId(userid);
    if ( client && results[numQueries - 1].FetchRow() )
    {
        PlayerWinsData[client] = results[numQueries - 1].FetchInt(0);
        g_PlayerWinsLoaded[client] = true;
    }

    // Reload top rank data after winner has beed updated in the database
    LoadRank();
}

public void T_SavePlayerDataFailure(Database db, int userid, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("Failed to save player data (error: %s)", error);
    LoadRankOrFire();
}

/**
 * Reloads the rank, or tells GG_OnLoadRank listeners right away when there is no database.
 */
void LoadRankOrFire()
{
    if ( g_DbConnection == null )
    {
        FireLoadRank();
        return;
    }
    LoadRank();
}

int GetPlayerPlaceInStat(int client)
{
    return PlayerPlaceData[client];
}

void RetrieveKeyValues(int client)
{
    if ( IsFakeClient(client) )
    {
        g_PlayerWinsLoaded[client] = true;
        PlayerWinsData[client] = 0;

        #if defined SQL_DEBUG
            LogError("[DEBUG-SQL] FORWARD PLAYER WINS LOADED client=%i is BOT", client);
        #endif

        Call_StartForward(FwdLoadPlayerWins);
        Call_PushCell(client);
        Call_Finish();
        return;
    }

    if ( g_DbConnection == null )
    {
        /* OnDatabaseReady() loads them. */
        return;
    }

    char auth[64];
    if ( !GetClientDbAuth(client, auth, sizeof(auth)) )
    {
        return;
    }

    char query[1024];
    g_DbConnection.Format(query, sizeof(query), g_sql_getPlayerByAuth, auth);
    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] %s", query);
    #endif
    g_DbConnection.Query(T_RetrieveKeyValues, query, GetClientUserId(client));
}

public void T_RetrieveKeyValues(Database db, DBResultSet result, const char[] error, int userid)
{
    /* Make sure the client didn't disconnect while the thread was running */
    int client = GetClientOfUserId(userid);
    if ( !client )
    {
        return;
    }
    if ( result == null )
    {
        LogError("Failed to retrieve player by auth (error: %s)", error);
        return;
    }
    g_PlayerWinsLoaded[client] = true;
    if ( result.FetchRow() )
    {
        int id = result.FetchInt(0);
        PlayerWinsData[client] = result.FetchInt(1);

        // update player timestamp
        char query[256];
        g_DbConnection.Format(query, sizeof(query), g_sql_updatePlayerTsById, id);
        #if defined SQL_DEBUG
            LogError("[DEBUG-SQL] %s", query);
        #endif
        g_DbConnection.Query(T_FastQueryResult, query);

        RefreshPlayerPlace(client);
    }
    else
    {
        PlayerWinsData[client] = 0;
        PlayerPlaceData[client] = 0;
    }
    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] FORWARD PLAYER WINS LOADED client=%i, wins=%i", client, PlayerWinsData[client]);
    #endif
    Call_StartForward(FwdLoadPlayerWins);
    Call_PushCell(client);
    Call_Finish();
}

public void T_FastQueryResult(Database db, DBResultSet result, const char[] error, any data)
{
    if ( result == null )
    {
        LogError("Fast query failed (error: %s)", error);
    }
}

/**
 * Refreshes the cached place of a client (GG_GetPlayerPlaceInStat).
 */
void RefreshPlayerPlace(int client)
{
    if ( g_DbConnection == null || !PlayerWinsData[client] )
    {
        PlayerPlaceData[client] = 0;
        return;
    }

    char query[256];
    g_DbConnection.Format(query, sizeof(query), g_sql_getPlayerPlaceByWins, PlayerWinsData[client]);
    g_DbConnection.Query(T_RefreshPlayerPlace, query, GetClientUserId(client));
}

public void T_RefreshPlayerPlace(Database db, DBResultSet result, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if ( !client )
    {
        return;
    }
    if ( result == null )
    {
        LogError("Failed to get player place in stats (error: %s)", error);
        return;
    }
    if ( result.FetchRow() )
    {
        PlayerPlaceData[client] = result.FetchInt(0) + 1;
    }
}

void SavePlayerDataInfo()
{
    if ( !Prune || g_DbConnection == null )
    {
        return;
    }

    char query[256];
    g_DbConnection.Format(query, sizeof(query), g_sql_prunePlayers[g_DbType], Prune);
    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] %s", query);
    #endif
    g_DbConnection.Query(T_SavePlayerDataInfo, query);
}

public void T_SavePlayerDataInfo(Database db, DBResultSet result, const char[] error, any data)
{
    if ( result == null )
    {
        LogError("Could not prune players (error: %s)", error);
        return;
    }
    /* Total winners, places and the top rank threshold change with the deleted rows. */
    if ( result.AffectedRows > 0 )
    {
        LoadRank();
    }
}

/**
 * Imports a winners file (es_gg_winners_db.txt or playerdata.txt) into the database.
 */
void ImportWinnersFile(int client, const char[] file, const char[] rootSection, const char[] winsKey, const char[] nameKey, const char[] label)
{
    if ( g_DbConnection == null )
    {
        ReplyToCommand(client, "[GunGame] The database is not connected.");
        return;
    }

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "data/gungame/%s", file);

    if ( !FileExists(path) )
    {
        ReplyToCommand(client, "[GunGame] %s does not exists to be imported.", file);
        return;
    }

    KeyValues KvGunGame = new KeyValues(rootSection);
    KvGunGame.ImportFromFile(path);

    /* Go to first SubKey */
    if ( !KvGunGame.GotoFirstSubKey() )
    {
        delete KvGunGame;
        ReplyToCommand(client, "[GunGame] You have no player data to import.");
        return;
    }

    char query[1024], Name[64], Auth[64];
    int ImportedWins, count = 0;
    Transaction txn = new Transaction();

    do
    {
        KvGunGame.GetSectionName(Auth, sizeof(Auth));
        ImportedWins = KvGunGame.GetNum(winsKey);

        if ( !ImportedWins || Auth[0] != 'S' )
        {
            continue;
        }

        KvGunGame.GetString(nameKey, Name, sizeof(Name));

        /* Existing player: add the wins and keep his name. New player: insert him. */
        g_DbConnection.Format(query, sizeof(query), g_sql_importPlayerWins, ImportedWins, Auth);
        txn.AddQuery(query);
        g_DbConnection.Format(query, sizeof(query), g_sql_insertPlayerIfMissing[g_DbType], ImportedWins, Name, Auth, Auth);
        txn.AddQuery(query);
        count++;
    }
    while ( KvGunGame.GotoNextKey() );

    delete KvGunGame;

    if ( !count )
    {
        delete txn;
        ReplyToCommand(client, "[GunGame] You have no player data to import.");
        return;
    }

    DataPack pack = new DataPack();
    pack.WriteCell(client ? GetClientUserId(client) : 0);
    pack.WriteCell(count);
    pack.WriteString(label);

    g_DbConnection.Execute(txn, T_ImportSuccess, T_ImportFailure, pack);
    ReplyToCommand(client, "[GunGame] Importing %d players...", count);
}

int ReadReplyTarget(DataPack pack, bool &valid)
{
    pack.Reset();
    int userid = pack.ReadCell();
    int client = userid ? GetClientOfUserId(userid) : 0;
    valid = (userid == 0 || client != 0);
    return client;
}

public void T_ImportSuccess(Database db, DataPack pack, int numQueries, DBResultSet[] results, any[] queryData)
{
    bool valid;
    int client = ReadReplyTarget(pack, valid);
    int count = pack.ReadCell();
    char label[32];
    pack.ReadString(label, sizeof(label));
    delete pack;

    /* Reload the players wins in memory */
    for ( int i = 1; i <= MaxClients; i++ )
    {
        if ( IsClientConnected(i) && IsClientAuthorized(i) )
        {
            RetrieveKeyValues(i);
        }
    }
    LoadRank();

    if ( valid )
    {
        ReplyToCommand(client, "[GunGame] Import of %s completed (%d players).", label, count);
    }
}

public void T_ImportFailure(Database db, DataPack pack, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    bool valid;
    int client = ReadReplyTarget(pack, valid);
    delete pack;

    LogError("Could not import players (query %d, error: %s)", failIndex, error);
    if ( valid )
    {
        ReplyToCommand(client, "[GunGame] Import finished with sql error");
    }
}

public Action _CmdImport(int client, int args)
{
    ImportWinnersFile(client, "es_gg_winners_db.txt", "gg_winners", "wins", "name", "es player data");
    return Plugin_Handled;
}

public Action _CmdImportDb(int client, int args)
{
    ImportWinnersFile(client, "playerdata.txt", "gg_PlayerData", "Wins", "Name", "player data");
    return Plugin_Handled;
}

public Action _CmdRebuild(int client, int args)
{
    LoadRank();
    ReplyToCommand(client, "[GunGame] Top rank has been rebuilt");
    return Plugin_Handled;
}

public Action _CmdReset(int client, int args)
{
    if ( g_DbConnection == null )
    {
        ReplyToCommand(client, "[GunGame] The database is not connected.");
        return Plugin_Handled;
    }

    Transaction txn = CreatePlayerTableTransaction(true);
    g_DbConnection.Execute(txn, T_ResetSuccess, T_ResetFailure, client ? GetClientUserId(client) : 0);
    return Plugin_Handled;
}

public void T_ResetSuccess(Database db, int userid, int numQueries, DBResultSet[] results, any[] queryData)
{
    // reset current players data
    for ( int i = 1; i <= MAXPLAYERS; i++ )
    {
        PlayerWinsData[i] = 0;
        PlayerPlaceData[i] = 0;
    }

    // reset top 10 data
    TotalWinners = 0;
    g_cfgHandicapTopWins = 0;

    int client = userid ? GetClientOfUserId(userid) : 0;
    if ( userid == 0 || client )
    {
        ReplyToCommand(client, "[GunGame] Stats has been reseted.");
    }
}

public void T_ResetFailure(Database db, int userid, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("Could not reset players table (query %d, error: %s)", failIndex, error);
    int client = userid ? GetClientOfUserId(userid) : 0;
    if ( userid == 0 || client )
    {
        ReplyToCommand(client, "[GunGame] Error reseting stats.");
    }
}

void LoadRank()
{
    if ( g_DbConnection == null )
    {
        return;
    }

    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] %s", g_sql_getPlayersCount);
    #endif
    g_DbConnection.Query(T_CountWinners, g_sql_getPlayersCount);
}

public void T_CountWinners(Database db, DBResultSet result, const char[] error, any data)
{
    if ( result == null )
    {
        LogError("Failed to count players in stat (error: %s)", error);
        return;
    }
    int count = 0;
    if ( result.FetchRow() )
    {
        count = result.FetchInt(0);
    }
    TotalWinners = count;
    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] Found %i winners in the rank table", TotalWinners);
    #endif

    LoadTopRankData();
}

void LoadTopRankData()
{
    if ( !g_cfgHandicapTopRank )
    {
        g_cfgHandicapTopWins = 0;
        LoadPlayersPlaces();
        return;
    }

    if ( g_cfgHandicapTopRank >= TotalWinners )
    {
        g_cfgHandicapTopWins = 1;
        LoadPlayersPlaces();
        return;
    }

    char query[256];
    g_DbConnection.Format(query, sizeof(query), g_sql_getTopPlayers, 1, g_cfgHandicapTopRank - 1);
    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] %s", query);
    #endif
    g_DbConnection.Query(T_LoadTopRankData, query);
}

public void T_LoadTopRankData(Database db, DBResultSet result, const char[] error, any data)
{
    if ( result == null )
    {
        LogError("Failed to load rank data (error: %s)", error);
        g_cfgHandicapTopWins = 0;
    }
    else if ( result.FetchRow() )
    {
        g_cfgHandicapTopWins = result.FetchInt(1);
    }
    else
    {
        g_cfgHandicapTopWins = 0;
    }

    LoadPlayersPlaces();
}

/**
 * Refreshes the places of all the players in game, then fires GG_OnLoadRank.
 */
void LoadPlayersPlaces()
{
    Transaction txn = new Transaction();
    char query[256];
    int count = 0;

    for ( int i = 1; i <= MaxClients; i++ )
    {
        PlayerPlaceData[i] = 0;
        if ( IsClientInGame(i) && PlayerWinsData[i] )
        {
            g_DbConnection.Format(query, sizeof(query), g_sql_getPlayerPlaceByWins, PlayerWinsData[i]);
            txn.AddQuery(query, GetClientUserId(i));
            count++;
        }
    }

    if ( !count )
    {
        delete txn;
        FireLoadRank();
        return;
    }

    g_DbConnection.Execute(txn, T_LoadPlacesSuccess, T_LoadPlacesFailure);
}

public void T_LoadPlacesSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
    for ( int i = 0; i < numQueries; i++ )
    {
        int client = GetClientOfUserId(queryData[i]);
        if ( client && results[i].FetchRow() )
        {
            PlayerPlaceData[client] = results[i].FetchInt(0) + 1;
        }
    }
    FireLoadRank();
}

public void T_LoadPlacesFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("Failed to load players places (error: %s)", error);
    FireLoadRank();
}

void FireLoadRank()
{
    Call_StartForward(FwdLoadRank);
    Call_Finish();
}

void ShowRank(int client)
{
    int wins = PlayerWinsData[client];
    if ( !wins || PlayerPlaceData[client] || g_DbConnection == null )
    {
        ShowRankInChat(client);
        return;
    }

    char query[256];
    g_DbConnection.Format(query, sizeof(query), g_sql_getPlayerPlaceByWins, wins);
    #if defined SQL_DEBUG
        LogError("[DEBUG-SQL] %s", query);
    #endif
    g_DbConnection.Query(T_ShowRank, query, GetClientUserId(client));
}

public void T_ShowRank(Database db, DBResultSet result, const char[] error, int userid)
{
    /* Make sure the client didn't disconnect while the thread was running */
    int client = GetClientOfUserId(userid);
    if ( !client )
    {
        return;
    }
    if ( result == null )
    {
        LogError("Failed to retrieve player place by wins (error: %s)", error);
        return;
    }
    if ( result.FetchRow() )
    {
        PlayerPlaceData[client] = result.FetchInt(0) + 1;
    }
    ShowRankInChat(client);
}

void ShowRankInChat(int client)
{
    if ( !IsClientInGame(client) )
    {
        return;
    }

    char name[MAX_NAME_SIZE];
    GetClientName(client, name, sizeof(name));
    if ( !PlayerPlaceData[client] )
    {
        CPrintToChatAllEx(client, "%t", "Rank: not ranked", name);
    }
    else
    {
        char subtext[64];
        for ( int i = 1; i <= MaxClients; i++ )
        {
            if ( IsClientInGame(i) && !IsFakeClient(i) )
            {
                SetGlobalTransTarget(i);
                FormatLanguageNumberTextEx(i, subtext, sizeof(subtext), PlayerWinsData[client], "with wins");
                CPrintToChatEx(i, client, "%t", "Rank: rank", name, PlayerPlaceData[client], subtext, TotalWinners);
            }
        }
    }
}

bool IsPlayerInTopRank(int client)
{
    if ( !g_cfgHandicapTopWins )
    {
        return false;
    }
    return PlayerWinsData[client] >= g_cfgHandicapTopWins;
}

/**
 * Removes 4-byte UTF-8 characters (emoji...) from a name: a MySQL utf8 (3 bytes) table rejects them
 * in strict mode, the save transaction then fails and the win is lost.
 */
void StripFourByteUtf8(char[] name)
{
    int r = 0, w = 0;
    while ( name[r] )
    {
        if ( (name[r] & 0xF8) == 0xF0 )
        {
            r += 4;
            continue;
        }
        name[w++] = name[r++];
    }
    name[w] = '\0';
}
