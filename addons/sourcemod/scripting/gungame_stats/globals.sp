State ConfigState = CONFIG_STATE_NONE;
int Prune = 30;
int g_cfgHandicapTopRank = 10;
bool g_Cfg_DontAddWinsOnBot = false;

/**
 * Top rank and player data will sync after map change.
 */
bool SaveProcess;

/* Player Data */
int PlayerWinsData[MAXPLAYERS + 1] = {0, ...};
bool IsActive;

int PlayerPlaceData[MAXPLAYERS + 1] = {0, ...};
int TotalWinners = 0;

GlobalForward FwdLoadRank;
GlobalForward FwdLoadPlayerWins;
int g_cfgHandicapTopWins = 0;

bool g_PlayerWinsLoaded[MAXPLAYERS + 1] = {false, ...};

int ClientOnPage[MAXPLAYERS + 1] = {0, ...};

enum DbType
{
    DbTypeSqlite,
    DbTypeMysql,
    DbTypePgsql,
    MaxDbTypes
};

DbType g_DbType;
Database g_DbConnection;
/* Connection being set up: g_DbConnection is only set once the table exists, so no query runs
 * against a missing table on a fresh database. */
Database g_DbPending;
bool g_DbConnecting;

char g_sql_createPlayerTable[MaxDbTypes][]   =
{
    "CREATE TABLE IF NOT EXISTS gungame_playerdata (   id INTEGER PRIMARY KEY AUTOINCREMENT, wins int(12) NOT NULL default 0, authid varchar(255) NOT NULL default '', name varchar(255) NOT NULL default '', timestamp timestamp NOT NULL default CURRENT_TIMESTAMP );",
    "CREATE TABLE IF NOT EXISTS `gungame_playerdata`(`id` int(11) NOT NULL auto_increment,`wins` int(12) NOT NULL default '0',`authid` varchar(255) NOT NULL default '',`name` varchar(255) NOT NULL default '',`timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,PRIMARY KEY  (`id`),KEY `wins` (`wins`),KEY `authid` (`authid`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;",
    "CREATE TABLE gungame_playerdata (id serial, wins int NOT NULL default 0, authid varchar(255) NOT NULL default '', name  varchar(255) NOT NULL default '', timestamp timestamp NOT NULL default CURRENT_TIMESTAMP, PRIMARY KEY (id));"
};
/* SQLite index names are global to the database file (storage-local is shared with other plugins): prefix them. */
char g_sql_createPlayerTableIndex1[MaxDbTypes][]  =
{
    "CREATE INDEX IF NOT EXISTS gg_playerdata_wins ON gungame_playerdata(wins);",
    "",
    "CREATE INDEX gg_playerdata_wins ON gungame_playerdata(wins);"
};
char g_sql_createPlayerTableIndex2[MaxDbTypes][]  =
{
    "CREATE INDEX IF NOT EXISTS gg_playerdata_authid ON gungame_playerdata(authid);",
    "",
    "CREATE INDEX gg_playerdata_authid ON gungame_playerdata(authid);"
};
char g_sql_checkTableExists[MaxDbTypes][]    =
{
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'gungame_playerdata';",
    "SHOW TABLES like 'gungame_playerdata';",
    "SELECT table_name FROM information_schema.tables WHERE table_name = 'gungame_playerdata';"
};
char g_sql_dropPlayerTable[]      = "DROP TABLE IF EXISTS gungame_playerdata;";

/**
 * Wins are saved with an atomic "add N wins" update followed by an insert
 * when the player has no row yet, so a win is never lost or duplicated even
 * if the player wins before his wins were loaded.
 */
char g_sql_addPlayerWins[]        = "UPDATE gungame_playerdata SET wins = wins + %d, name = '%s', timestamp = current_timestamp WHERE authid = '%s';";
char g_sql_importPlayerWins[]     = "UPDATE gungame_playerdata SET wins = wins + %d WHERE authid = '%s';";
char g_sql_insertPlayerIfMissing[MaxDbTypes][] =
{
    "INSERT INTO gungame_playerdata (wins, name, timestamp, authid) SELECT %d, '%s', current_timestamp, '%s' WHERE NOT EXISTS (SELECT 1 FROM gungame_playerdata WHERE authid = '%s');",
    "INSERT INTO gungame_playerdata (wins, name, timestamp, authid) SELECT %d, '%s', current_timestamp, '%s' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM gungame_playerdata WHERE authid = '%s');",
    "INSERT INTO gungame_playerdata (wins, name, timestamp, authid) SELECT %d, '%s', current_timestamp, '%s' WHERE NOT EXISTS (SELECT 1 FROM gungame_playerdata WHERE authid = '%s');"
};
char g_sql_getPlayerWinsByAuth[]  = "SELECT wins FROM gungame_playerdata WHERE authid = '%s';";
char g_sql_getPlayerPlaceByWins[] = "SELECT count(*) FROM gungame_playerdata WHERE wins > %d;";
char g_sql_getPlayersCount[]      = "SELECT count(*) FROM gungame_playerdata;";
char g_sql_getPlayerByAuth[]      = "SELECT id, wins, name FROM gungame_playerdata WHERE authid = '%s';";
char g_sql_updatePlayerTsById[]   = "UPDATE gungame_playerdata SET timestamp = current_timestamp WHERE id = %d;";
/* place = players with more wins + 1, the same rule as GG_GetPlayerPlaceInStat (ties share a place). */
char g_sql_getTopPlayers[]        = "SELECT id, wins, name, authid, (SELECT count(*) FROM gungame_playerdata p2 WHERE p2.wins > p.wins) + 1 FROM gungame_playerdata p ORDER by wins desc, id LIMIT %d OFFSET %d;";

/**
 * SQLite stores current_timestamp as 'YYYY-MM-DD HH:MM:SS' text (UTC): compare it with datetime(),
 * comparing it with a unix time (integer) never matched.
 */
char g_sql_prunePlayers[MaxDbTypes][]    =
{
    "DELETE FROM gungame_playerdata WHERE timestamp < datetime('now', '-%d days');",
    "DELETE FROM gungame_playerdata WHERE timestamp < current_timestamp - interval %d day;",
    "DELETE FROM gungame_playerdata WHERE timestamp < current_timestamp - interval '%d day';"
};
