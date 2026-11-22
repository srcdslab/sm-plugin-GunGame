/* PlayerState[client] */
#define KNIFE_ELITE         (1<<0)
#define FIRST_JOIN          (1<<1)
#define GRENADE_LEVEL       (1<<2)

enum Sounds
{
    Welcome,
    Knife,
    Nade,
    Steal,
    Up,
    Down,
    Triple,
    AutoFF,
    MultiKill,
    Winner,
    WarmupTimerSound,
    MaxSounds
}

char g_WeaponName[MAX_WEAPONS_COUNT][MAX_WEAPON_NAME_LEN];
Slots g_WeaponSlot[MAX_WEAPONS_COUNT];
int g_WeaponAmmo[MAX_WEAPONS_COUNT];
bool g_WeaponDropKnife[MAX_WEAPONS_COUNT];
int g_WeaponLevelIndex[MAX_WEAPONS_COUNT];

char EventSounds[MaxSounds][PLATFORM_MAX_PATH];

/* Default values for weapon order.*/
int WeaponOrderId[GUNGAME_MAX_LEVEL];
char WeaponOrderName[GUNGAME_MAX_LEVEL][MAX_WEAPON_NAME_LEN];
int WeaponOrderCount;
int RandomWeaponOrderMap[GUNGAME_MAX_LEVEL];
bool RandomWeaponOrder;

// ConVar Pointer
ConVar mp_friendlyfire;
ConVar mp_restartgame;
ConVar gungame_enabled;
ConVar g_Cvar_Turbo;
ConVar g_Cvar_MultiLevelAmount;

/* Status forwards */
GlobalForward FwdLevelChange;
GlobalForward FwdLevelChanged;
GlobalForward FwdKnifeSteal;
GlobalForward FwdWarmupEnd;
GlobalForward FwdWarmupStart;
GlobalForward FwdWinner;
GlobalForward FwdSoundWinner;
GlobalForward FwdTripleLevel;
GlobalForward FwdLeader;
GlobalForward FwdVoteStart;
GlobalForward FwdDisableRtv;
GlobalForward FwdDeath;
GlobalForward FwdPoint;
GlobalForward FwdStart;
GlobalForward FwdShutdown;
GlobalForward FwdMatchStart;

Handle WarmupTimer;

bool IsActive = false;
bool g_BombEventsHooked;
bool g_HostageEventsHooked;
StringMap PlayerLevelsBeforeDisconnect;
Handle g_Timer_HandicapUpdate;
StringMap PlayerHandicapTimes;
bool g_SkipSpawn[MAXPLAYERS+1] = {false, ...};

int g_WeaponsMaxId              = 0;

int g_WeaponIdKnife             = 0;
int g_WeaponIdHegrenade         = 0;
int g_WeaponIdSmokegrenade      = 0;
int g_WeaponIdFlashbang         = 0;

int g_WeaponLevelIdKnife        = 0;
int g_WeaponLevelIdHegrenade    = 0;

int g_WeaponAmmoTypeHegrenade       = 0;
int g_WeaponAmmoTypeFlashbang       = 0;
int g_WeaponAmmoTypeSmokegrenade    = 0;
bool g_BlockFastSwitchOnChange[MAXPLAYERS+1]    = {false, ...};

/**
 * Config Setting
 */

State ConfigState;
bool ConfigReset;

int MapStatus;
int MaxLevelPerRound = 0;
int MinKillsPerLevel = 1;
bool TurboMode;
int StripDeadPlayersWeapon;
bool AllowLevelUpAfterRoundEnd;
bool RemoveBonusWeaponAmmo;
bool ReloadWeapon;
bool MultiKillChat;
bool JoinMessage;
int VoteLevelLessWeaponCount;
int ObjectiveBonus;
int WorldspawnSuicide = 1;
int NadeBonusWeaponId;
bool NadeSmoke;
bool NadeFlash;
int g_Cfg_ExtraNade;
bool UnlimitedNades;
/* UnlimitedNades as read from the config: UnlimitedNadesMinPlayers can only turn it on, never off. */
bool g_Cfg_UnlimitedNades;
bool WarmupNades;
bool KnifePro;
int KnifeProMinLevel;
bool KnifeElite;
bool AutoFriendlyFire;
bool BotCanWin;
bool WarmupEnabled = true;
bool DisableWarmupOnRoundEnd = false;
bool WarmupInitialized;
int Warmup_TimeLength = 30;
int WarmupCounter;
bool IsVotingCalled = false;
bool g_isCalledEnableFriendlyFire = false;
bool g_isCalledDisableRtv = false;
bool TripleLevelBonus = false;
bool KnifeProHE = false;
bool ObjectiveBonusWin = false;
bool InternalIsActive = true;
int CommitSuicide = 1;
bool AlltalkOnWin = false;
bool RestoreLevelOnReconnect;
bool TripleLevelBonusGodMode;
int HandicapMode;
bool TopRankHandicap;
bool StatsEnabled;
int WarmupRandomWeaponMode = 0;
int WarmupRandomWeaponLevel = 0;
int UnlimitedNadesMinPlayers = 0;
int FFA = 0;
int NumberOfNades = 0;
int g_Cfg_LevelsInScoreboard = 0;
int g_Cfg_HandicapLevelSubstract = 0;
int g_Cfg_ArmorKevlar = 1;
int g_Cfg_ArmorHelmet = 1;
float g_Cfg_TripleLevelBonusGravity = 0.5;
float g_Cfg_TripleLevelBonusSpeed = 1.5;
bool g_Cfg_TripleLevelEffect = false;
int g_Cfg_KnifeSmoke = 0;
int g_Cfg_KnifeFlash = 0;
int g_Cfg_ObjectiveBonusExplode = 0;
int g_Cfg_ShowLeaderWeapon = 0;
int g_Cfg_ShowSpawnMsgInHintBox = 0;
int g_Cfg_ShowLeaderInHintBox = 0;
int g_Cfg_MaxHandicapLevel = 0;
int g_Cfg_ScoreboardClearDeaths = 0;
int g_Cfg_WarmupWeapon = 0;
int g_Cfg_RandomWeaponReservLevels[GUNGAME_MAX_LEVEL];
float g_Cfg_HandicapUpdate;
int g_Cfg_KnifeProRecalcPoints = 0;
bool g_Cfg_HandicapSkipBots = false;
int g_Cfg_KnifeProMaxDiff = 0;
int g_Cfg_MultiLevelAmount = 3;
int g_Cfg_HandicapTimesPerMap = 0;
int g_cfgDisableRtvLevel = 0;
int g_cfgEnableFriendlyFireLevel = 0;
bool g_cfgFriendlyFireOnOff = true;
bool g_Cfg_BlockWeaponSwitchIfKnife = false;
bool g_Cfg_BlockWeaponSwitchOnNade = false;
/* BlockWeaponPickup: players only get the weapons GunGame gives them. */
bool g_Cfg_BlockWeaponPickup = false;
bool g_AllowPickup[MAXPLAYERS+1];
/* Id of the last multi-level bonus of each player (RemoveBonus timers of older bonuses are ignored). */
int g_TripleBonusId[MAXPLAYERS+1];
bool g_Cfg_HandicapUseSpectators = false;
bool g_Cfg_CanLevelUpWithPhysics = false;
bool g_Cfg_CanLevelUpWithPhysicsG = false;
bool g_Cfg_CanLevelUpWithPhysicsK = false;
bool g_Cfg_CanLevelUpWithMapNades = false;
bool g_Cfg_CanLevelUpWithNadeOnKnife = false;
bool g_Cfg_DisableLevelDown = false;
bool g_Cfg_SelfKillProtection = false;
char g_CfgGameDesc[64] = "";
int g_Cfg_MultilevelEffectType = 2;

int g_Cfg_MultiplySoundVolume = 0;
int g_Cfg_BonusWeaponAmmo = 0;

float g_Cfg_EndGameDelay        = 0.0;
int g_Cfg_WinnerFreezePlayers   = 0;
int g_Cfg_FastSwitchOnChangeWeapon  = 0;
int g_Cfg_FastSwitchOnLevelUp       = 0;
bool g_Cfg_FastSwitchSkipWeapons[MAX_WEAPONS_COUNT];

int g_Cfg_EndGameSilent = 0;
int PlayerState[MAXPLAYERS + 1];
int PlayerOnGrenade;

int CTcount;
int Tcount;

/* Checks to make sure clients only gain level by objective during Round Started and not during Round End*/
bool RoundStarted;

/* Changes the default MinKillsPerWeapon setting if value is greater than 0. */
int CustomKillPerLevel[GUNGAME_MAX_LEVEL];

int PlayerLevel[MAXPLAYERS + 1];
int CurrentKillsPerWeap[MAXPLAYERS + 1];
int CurrentLevelPerRound[MAXPLAYERS + 1];
int CurrentLevelPerRoundTriple[MAXPLAYERS + 1];
int CurrentLeader;
int GameWinner;
/* The winner left the server: GameWinner still blocks level changes, but his slot may be reused. */
bool g_GameWinnerLeft;
bool g_teamChange[MAXPLAYERS + 1];
int g_NumberOfNades[MAXPLAYERS + 1];
bool g_BlockSwitch[MAXPLAYERS + 1];

/* Valid kills of the match per client (GG_GetClientKills / GG_GetRanking). */
int g_MatchKills[MAXPLAYERS + 1];
bool g_MatchStarted = false;

/* Weapon index lookup */
char WeaponFile[PLATFORM_MAX_PATH];
bool WeaponOpen;
StringMap TrieWeapon;

/* Menus */
int ClientOnPage[MAXPLAYERS + 1];
int WeaponLevelPages;

int g_tripleEffects[MAXPLAYERS+1] = {0, ...};
int g_Ent_Effect[MAXPLAYERS+1] = {-1, ...};
