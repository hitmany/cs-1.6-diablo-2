/* ================================================================================================ /
*
*	Diablo Mod: 
*	------------------
*
*	Need:		This compiled and items files
*	Works with:	AMXX § Cs 1.6
*
*	Installation:
*	-------------------
*	Copy script into plugins and edit plugins.ini
*	Copy item diablo directory into addons/amxmodx
*	If you amx directory is not called addons/amxmodx/.. just create a new path
*
*	Credits:
*	-----------------
*	Spacedude
*	Some others back when amx mod started :]
*	twistedeuphoria
*
*	diablo_xpbonus = Xp on each kill (without bonus)
*	diablo_durability = Will your item loose durability on damage? And how much each time
*	diablo_saveitems = Save items when map changes
*	diablo_spawnchance = 1/x chance to spawn powerup on each roundstart
*
*	Contact:
*	-----------------
*	email: mortengryning@gmail.com
*
/ ================================================================================================= */

new Basepath[128]	//Path from Cstrike base directory

#include <amxmodx>
#include <amxmisc>
#include <string>

#include <engine>
#include <fakemeta> 
#include <cstrike>

#include <fun>
#include <fakemeta_util>
#include <sqlx>
#include <csx> 
#include <hamsandwich>
#include <colorchat>
#include <xs>
#include <nvault>
#include <cs_player_models_api>


#define RESTORETIME 30.0	 //How long from server start can players still get their item trasferred (s)
#define MAX 32			 //Max number of valid player entities

//#define CHEAT 1		 //Cheat for testing purposes
#define CS_PLAYER_HEIGHT 72.0
#define GLOBAL_COOLDOWN 0.5
#define MAX_PLAYERS 32
#define BASE_SPEED 	245.0
#define GLUTON 95841
#define VOL_NULL    0.0
#define VOL_MID    0.5
#define FLAG_NONE    0
#define PITCH_NONE    0
new Float:agi=BASE_SPEED
new round_status
new DemageTake[33]
new DemageTake1[33]
//new weapon, clip, ammo
#define x 0
#define y 1
#define z 2

#define TASK_MODELCHANGE 100
#define ID_MODELCHANGE (taskid - TASK_MODELCHANGE)
#define TASK_CHARGE 110
#define TASK_HUD 120
#define TASK_GOD 129
#define TASK_GREET 240
#define TASK_HOOK 360

#define TASKID_REVIVE 	1337
#define TASKID_RESPAWN 	1338
#define TASKID_CHECKRE 	1339
#define TASKID_CHECKST 	13310
#define TASKID_ORIGIN 	13311
#define TASKID_SETUSER 	13312
#define TASKID_SQLFETCH 13313
#define TASKID_GLOW 	13314
#define TASK_NAME 48424
#define TASK_FLASH_LIGHT 81184
#define TASK_REMOVE_BAAL 81185
#define TASK_BURN 81186
#define FL_ONGROUND (1<<9)
#define message_begin_f(%1,%2,%3,%4) engfunc(EngFunc_MessageBegin, %1, %2, %3, %4)
#define write_coord_f(%1) engfunc(EngFunc_WriteCoord, %1)

#define pev_zorigin	pev_fuser4
#define seconds(%1) ((1<<12) * (%1))

#define OFFSET_CAN_LONGJUMP    356

#define MAX_FLASH 15		//pojemnosc barejii maga (sekund)

#define MAX_SKILLS		7
#define MAX_RACES		28

//Frozen explode
#define message_begin_fl(%1,%2,%3,%4) engfunc(EngFunc_MessageBegin, %1, %2, %3, %4)
#define write_coord_fl(%1) engfunc(EngFunc_WriteCoord, %1)

//Set user model
// Delay between model changes (increase if getting SVC_BAD kicks)
#define MODELCHANGE_DELAY 0.2

// Delay after roundstart (increase if getting kicks at round start)
#define ROUNDSTART_DELAY 2.0

#define MAXPLAYERS 32
#define MODELNAME_MAXLENGTH 32

new amxbasedir[64]
new configsbasedir[64]

new const DEFAULT_MODELINDEX_T[] = "models/player/terror/terror.mdl"
new const DEFAULT_MODELINDEX_CT[] = "models/player/urban/urban.mdl"

// CS Player PData Offsets (win32)
#define PDATA_SAFE 2
#define OFFSET_CSTEAMS 114
#define OFFSET_MODELINDEX 491 // Orangutanz

#define flag_get(%1,%2)		(%1 & (1 << (%2 & 31)))
#define flag_set(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define flag_unset(%1,%2)	(%1 &= ~(1 << (%2 & 31)));

new g_MaxPlayers
new g_HasCustomModel
new Float:g_ModelChangeTargetTime
new g_CustomPlayerModel[MAXPLAYERS+1][MODELNAME_MAXLENGTH]

//END of set user model block

new SOUND_START[] 	= "items/medshot4.wav"
new SOUND_FINISHED[] 	= "items/smallmedkit2.wav"
new SOUND_FAILED[] 	= "items/medshotno1.wav"
new SOUND_EQUIP[]	= "items/ammopickup2.wav"

new rndfsound

enum
{
	ICON_HIDE = 0,
	ICON_SHOW,
	ICON_FLASH
}

new g_haskit[MAX+1]
new Float:g_revive_delay[MAX+1]
new Float:g_body_origin[MAX+1][3]
new bool:g_wasducking[MAX+1]

new g_msg_bartime
new g_msg_screenfade
new g_msg_statusicon
new g_msg_clcorpse
new g_msgDamage
new g_MsgText

new cvar_revival_time
new cvar_revival_health
new cvar_revival_dis

new attacker
new attacker1
new flashlight[33]
new flashbattery[33]
new flashlight_r
new flashlight_g
new flashlight_b

new planter
new defuser

new map_end = 0

new g_shock

// max clip
stock const maxClip[31] = { -1, 13, -1, 10,  1,  7,  1,  30, 30,  1,  30,  20,  25, 30, 35, 25,  12,  20,
			10,  30, 100,  8, 30,  30, 20,  2,  7, 30, 30, -1,  50 };

// max bpammo
stock const maxAmmo[31] = { -1, 52, -1, 90, -1, 32, -1, 100, 90, -1, 120, 100, 100, 90, 90, 90, 100, 100,
			30, 120, 200, 32, 90, 120, 60, -1, 35, 90, 90, -1, 100 };

new gmsgDeathMsg
new gmsgStatusText
new gmsgBartimer
new gmsgScoreInfo
new gmsgHealth
new g_msgHostageAdd, g_msgHostageDel; // radar
new player, bossPower
new old_mp_autoteambalance, Float:old_mp_roundtime, Float:old_mp_buytime, old_mp_freezetime, old_mp_startmoney

new bool:freeze_ended

// Remembers when the round starts
new Float:gF_starttime

new c4state[33]
new c4bombc[33][3] 
new c4fake[33]
new fired[33]
new fired_viper[33]
new Float:viper_cord[33][3]
new Float:viper_vector[33][3]
new viper_spear[33]
new Float:viper_gas_time[33]
new viper_gases[33]
new bool:ghost_check
new baal_copyed[33]
new ghosttime[33]
new ghoststate[33]
new naswietlony[33]

new spider_traps[33]
new mephisto_fires[33]
new mephisto_touch[33]
new is_trap_active[33]
new owner_radar_trap[33] //Кто владелец ловушки показать ему на радаре
new spider_hook_disabled[33] //Кто владелец ловушки показать ему на радаре
new Float:spider_regen_time[33]

new duriel_slowweap[33]
new duriel_boost[33]
new duriel_boost_delay[33]
new duriel_boost_ent[33]

new izual_ring[33]
new Float:izual_ringing[33]

new const primaryWeapons[][] = {
	"weapon_shield",
	"weapon_scout",
	"weapon_xm1014",
	"weapon_mac10",
	"weapon_aug",
	"weapon_ump45",
	"weapon_sg550",
	"weapon_galil",
	"weapon_famas",
	"weapon_awp",
	"weapon_mp5navy",
	"weapon_m249",
	"weapon_m3",
	"weapon_m4a1",
	"weapon_tmp",
	"weapon_g3sg1",
	"weapon_sg552",
	"weapon_ak47",
	"weapon_p90"
}

new sprite_blood_drop = 0
new sprite_blood_spray = 0
new sprite_gibs = 0
new sprite_white = 0
new sprite_fire = 0
new sprite_boom = 0
new sprite_line = 0
new sprite_lgt = 0
new sprite_laser = 0
new sprite_ignite = 0
new sprite_flame = 0
new sprite_smoke = 0
new sprite_sabrecat = 0
new sprite_bloodraven = 0
new g_smokeSpr

// Player burning sounds
new const grenade_fire_player[][] = { "scientist/sci_fear8.wav", "scientist/sci_pain1.wav", "scientist/scream02.wav" }

new const sprite_grenade_smoke[] = "sprites/black_smoke3.spr"
new coldGibs;
//new sound_fireball = 0
//new sound_explode = 0
new sprite_blast;
new sprite;
new diablolght;
new diablo_lights[33];

new player_xp[33] = 0		//Holds players experience
new player_lvl[33] = 1			//Holds players level
new player_point[33] = 0		//Holds players level points
new player_item_id[33] = 0	//Items id
new player_item_name[33][128]   //The items name
new player_intelligence[33]
new player_strength[33]
new player_agility[33]
new player_dextery[33]
new mana_gracza[33]
new player_TotalLVL[33]
new Float:player_damreduction[33]
new player_class[33]		
new Float:player_huddelay[33]
new player_premium[33] = 0  //Holds players premium
new player_fallen_tr[33] = 0  //fallen shaman
new player_portal[33] = 0 //has portal
new player_portals[33] = 0 //how much portals setted
new player_portal_infotrg_1[33] = 0 //portal1
new player_portal_infotrg_2[33] = 0 //portal2
new player_portal_sprite_1[33] = 0
new player_portal_sprite_2[33] = 0
new player_infidel[33]

//Item attributes
new player_b_vampire[33] = 1	//Vampyric damage
new player_b_damage[33] = 1	//Bonus damage
new player_b_money[33] = 1	//Money bonus
new player_b_gravity[33] = 1	//Gravity bonus : 1 = best
new player_b_inv[33] = 1		//Invisibility bonus
new player_b_grenade[33] = 1	//Grenade bonus = 1/chance to kill
new player_b_reduceH[33] = 1	//Reduces player health each round start
new player_b_theif[33] = 1	//Amount of money to steal
new player_b_respawn[33] = 1	//Chance to respawn upon death
new player_b_explode[33] = 1	//Radius to explode upon death
new player_b_heal[33] = 1	//Ammount of hp to heal each 5 second
new player_b_gamble[33] = 1	//Random skill each round : value = vararity
new player_b_blind[33] = 1	//Chance 1/Value to blind the enemy
new player_b_fireshield[33] = 1	//Protects against explode and grenade bonus 
new player_b_meekstone[33] = 1	//Ability to lay a fake c4 and detonate 
new player_b_teamheal[33] = 1	//How many hp to heal when shooting a teammate 
new player_b_redirect[33] = 1	//How much damage will the player redirect 
new player_b_fireball[33] = 1	//Ability to shot off a fireball value = radius
new player_b_ghost[33] = 1	//Ability to walk through stuff
new player_b_eye[33] = 1		//Ability to place camera
new player_b_blink[33] = 1	//Ability to get a railgun
new player_b_windwalk[33] = 1	//Ability to windwalk away
new player_b_usingwind[33] = 1	//Is player using windwalk
new player_b_froglegs[33] = 1	//Ability to hold down duck for 4 sec to frog-jump
new player_b_silent[33]	= 1	//Is player silent
new player_b_dagon[33] = 1	//Ability to nuke an opponent
new player_b_sniper[33] = 1	//Ability to kill in 1/sniper with scout
new c_awp[33] = 1
new player_b_m3master[33] = 1
new player_b_dglmaster[33] = 1
new player_b_awpmaster[33] = 1
new player_b_akmaster[33] = 1
new player_b_m4master[33] = 1
new player_b_jumpx[33] = 1	//Ability to double jump
new player_b_smokehit[33] = 1	//Ability to hit and kill with smoke :]
new player_b_extrastats[33] = 1	//Ability to gain extra stats
new player_b_firetotem[33] = 1	//Ability to put down a fire totem that explodes after 7 seconds
new player_b_hook[33] = 1	//Ability to grap a player a hook him towards you
new player_b_darksteel[33] = 1	//Ability to damage double from behind the target 	
new player_b_illusionist[33] = 1	//Ability to use the illusionist escape
new player_b_mine[33] = 1	//Ability to lay down mines
new c_mine[33]
new c_shake[33]
new c_shaked[33]
new c_damage[33]
new bool:c_ulecz[33]
new c_jump[33]
new c_respawn[33]
new c_vampire[33]
new c_silent[33]
new player_b_antyarchy[33]
new c_antyarchy[33]
new player_b_antymeek[33]
new c_antymeek[33]
new player_b_antyorb[33]
new c_antyorb[33]
new player_b_antyfs[33]
new c_antyfs[33]
new niewidzialnosc_kucanie[33];
new c_grenade[33]
new c_blind[33]
new zmiana_skinu[33]
new c_darksteel[33]
new c_blink[33] = 0
new lustrzany_pocisk[33] = 1
new c_redirect[33]
new losowe_itemy[33]
new fire_bows[33]
new niewidka[33]
new player_b_radar[33] = 1              // radar
new player_b_autobh[33] = 1
new player_b_godmode[33] = 1    // niesmiertelnosc
new player_b_zamroztotem[33] = 1
new player_b_fleshujtotem[33] = 1
new player_b_kasatotem[33] = 1
new player_b_kasaqtotem[33] = 1
new player_b_wywaltotem[33] = 1
new uzyl_przedmiot[33];
new skinchanged[33]
new player_dc_name[33][99]	//Information about last disconnected players name
new player_dc_item[33]		//Information about last disconnected players item
new player_sword[33] 		//nowyitem
new player_ring[33]		//ring stats bust +5
new Float:poprzednia_rakieta_gracza[33];
new ilosc_rakiet_gracza[33];
new ilosc_blyskawic[33]
new Float:poprzednia_blyskawica[33];
//new ilosc_dynamitow_gracza[33];
new Float:g_wallorigin[33][3]
new Float:falen_fires_time[33];
new fallen_fires[33]
new frozen_colds[33]
new is_frozen[33]
new is_fired[33]
new imp_fires[33]
new is_poisoned[33]
new Float:is_touched[33]
new cel // do pokazywania statusu
new item_info[513] //id itemu  
new item_name[513][128] //nazwa itemu
new player_artifact[33][4]
new player_artifact_time[33][4]
new const modelitem[]="models/winebottle.mdl" //tutaj zmieniacie model itemu
new const gszSound[] = "diablo_lp/eleccast.wav";
//Cvars
new pHook, pThrowSpeed, pSpeed, pWidth, pSound, pColor
new pInterrupt, pAdmin, pHookSky, pOpenDoors, pPlayers
new pUseButtons, pHostage, pWeapons, pInstant, pHookNoise
new pMaxHooks, pRndStartDelay
// Sprite
new sprBeam

// Players hook entity
new Hook[33]

// MaxPlayers
new gMaxPlayers

// some booleans
new bool:gHooked[33]
new bool:canThrowHook[33]
new bool:rndStarted


// Player Spawn
new bool:gRestart[33] = {false, ...}
new bool:gUpdate[33] = {false, ...}

new gHooksUsed[33] // Used with sv_hookmax
new bool:g_bHookAllowed[33] // Used with sv_hookadminonly
new bool:g_bWeaponsDisabled = false; //disable give weapon skills

/////////////////////////////////////////////////////////////////////
new player_ultra_armor[33]
new player_ultra_armor_left[33]
/////////////////////////////////////////////////////////////////////

new Float:player_b_oldsen[33]	//Players old sens

new bool:player_b_dagfired[33]	//Fired dagoon?
new bool:used_item[33] 
new jumps[33]			//Keeps charge with the number of jumps the user has made
new bool:dojump[33]		//Are we jumping?
new item_boosted[33]		//Has this user boosted his item?
new earthstomp[33]
new bool:falling[33]
new gravitytimer[33]
new item_durability[33]	//Durability of hold item
new CTSkins[4][]={"sas","gsg9","urban","gign"}
new TSkins[4][]={"arctic","leet","guerilla","terror"}
new SWORD_VIEW[]         = "models/diablomod/v_knife.mdl" 
new SWORD_PLAYER[]       = "models/diablomod/p_knife.mdl" 
new KNIFE_VIEW[] 	= "models/v_knife.mdl"
new KNIFE_PLAYER[] 	= "models/p_knife.mdl"
new C4_VIEW[] 		= "models/v_c4.mdl"
new C4_PLAYER[] 	= "models/p_c4.mdl"
new HE_VIEW[] = "models/v_hegrenade.mdl"
new HE_PLAYER[] = "models/p_hegrenade.mdl"
new FL_VIEW[] = "models/v_flashbang.mdl"
new FL_PLAYER[] = "models/p_flashbang.mdl"
new SE_VIEW[] = "models/v_smokegrenade.mdl"
new SE_PLAYER[] = "models/p_smokegrenade.mdl"
new SE_MODEL[] = "models/w_smokegrenade.mdl"
new SABRECAT_VIEW[]         = "models/diablomod/v_poisongas.mdl" 
new SABRECAT_PLAYER[]       = "models/diablomod/p_poisongas.mdl"
new SABRECAT_MODEL[]       = "models/diablomod/w_poisongas.mdl"

new cbow_VIEW[]  = "models/diablomod/v_crossbow.mdl" 
new cvow_PLAYER[]= "models/diablomod/p_crossbow.mdl" 
new cbow_bolt[]  = "models/diablomod/Crossbow_bolt.mdl"
new scythe_view[]  = "models/diablomod/v_scythe.mdl"
new infidel_view[]  = "models/diablomod/v_infidel2.mdl"
new infidel_model[]  = "models/player/d2_infidel/d2_infidel.mdl"
new infidel_model_short[]  = "d2_infidel"
new mosquito_model_short[]  = "d2_mosquito3"
new mosquito_model[]  = "models/player/d2_mosquito3/d2_mosquito3.mdl"
new bloodbow_VIEW[]  = "models/diablomod/v_ravenbow.mdl" 
new bloodbow_PLAYER[]= "models/diablomod/p_ravenbow.mdl" 
//new bloodbow_MODEL[]  = "models/diablomod/Crossbow_bolt.mdl"

new LeaderCT = -1
new LeaderT = -1

new JumpsLeft[33]
new JumpsMax[33]

new monk_energy[33]
new monk_maxenergy[33]
new Float:monk_lastshot[33]

new fallens_ct
new fallens_tt

new loaded_xp[33]
new asked_sql[33]
new olny_one_time=0
// Lets us know that the DB is ready
new bool:bDBAvailable = false;
// Player's Unique ID
new g_iDBPlayerUniqueID[33];
new g_iDBPlayerSavedBy[33];
// SQLX
new Handle:g_DBTuple;
new Handle:g_DBConn;
new gcvar_host, gcvar_user, gcvar_pass, gcvar_database;
//new bool:bDBXPRetrieved[33];

#define TOTAL_TABLES		5

new const szTables[TOTAL_TABLES][] = 
{
	"CREATE TABLE IF NOT EXISTS `player` ( `id` int(8) unsigned NOT NULL AUTO_INCREMENT, `name` varchar(33) NOT NULL, `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'ON UPDATE CURRENT_TIMESTAMP', PRIMARY KEY (`id`), UNIQUE KEY `id` (`id`)) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;",
	"CREATE TABLE IF NOT EXISTS `extra` ( `id` int(8) unsigned NOT NULL, `gold` int(11) NOT NULL DEFAULT '0', `total_lvl` int(8) NOT NULL DEFAULT '0', PRIMARY KEY ( `id` )) ENGINE=MyISAM DEFAULT CHARSET=utf8;",
	"CREATE TABLE IF NOT EXISTS `class` ( `id` int(8) unsigned NOT NULL, `class` int(2) unsigned NOT NULL, `xp` int(8) NOT NULL DEFAULT '0', PRIMARY KEY ( `id`,`class` )) ENGINE=MyISAM DEFAULT CHARSET=utf8;",
	"CREATE TABLE IF NOT EXISTS `skill` ( `id` int(8) unsigned NOT NULL, `class` int(2) unsigned NOT NULL, `str` int(2) NOT NULL, `agi_best` int(2) NOT NULL, `agi_dmg` int(2) NOT NULL, `sta` int(2) NOT NULL, `dur` int(2) NOT NULL, `int` int(2) NOT NULL, `dex_dmg` int(2) NOT NULL, `quest_cur` int(2) NOT NULL DEFAULT '0', `quest_count1` int(2) NOT NULL DEFAULT '0', `quest_count2` int(2) NOT NULL DEFAULT '0', PRIMARY KEY (`id`,`class`)) ENGINE=MyISAM DEFAULT CHARSET=utf8;",
	"CREATE TABLE IF NOT EXISTS `item`  ( `id` int(8) unsigned NOT NULL, `item` int(3) unsigned NOT NULL, `item_number` int(1) NOT NULL, `expire_time` int(14) NOT NULL, PRIMARY KEY (`id`,`item`,`item_number`)) ENGINE=MyISAM DEFAULT CHARSET=utf8;"
};

enum { NONE = 0, Mag, Monk, Paladin, Assassin, Necromancer, Barbarian, Ninja, Amazon, BloodRaven, Duriel, Mephisto, Izual, Diablo, Baal, Fallen, Imp, Zakarum, Viper, Mosquito, Frozen, Infidel, GiantSpider, SabreCat, Griswold, TheSmith, Demonolog, VipCztery }
new Race[28][] = 
{
	"Нет",
	"Маг",
	"Монах",
	"Паладин",
	"Ассассин",
	"Некромант",
	"Варвар",
	"Ниндзя",
	"Амазонка",
	"Кровавый ворон",
	"Дуриель",
	"Мефисто",
	"Изуал",
	"Диабло",
	"Баал",
	"Падший",
	"Бес",
	"Закарум",
	"Саламандра",
	"Гигантский комар",
	"Ледяной ужас",
	"Инфидель",
	"Гигантский паук",
	"Адский кот",
	"Griswold",
	"The Smith",
	"Demonolog",
	"VipCztery"
}
/*
Race[0][] = "Нет"
Race[1][] = "Маг"
Race[2][] = "Монах"
Race[3][] = "Паладин"
Race[4][] = "Ассассин"
Race[5][] = "Некромант"
Race[6][] = "Варвар"
Race[7][] = "Ниндзя"
Race[8][] = "Амазонка"
Race[9][] = "Кровавый ворон"
Race[10][] = "Дуриель"
Race[11][] = "Мефисто"
Race[12][] = "Изуал"
Race[13][] = "Диабло"
Race[14][] = "Баал"
Race[15][] = "Падший"
Race[16][] = "Бес"
Race[17][] = "Закарум"
Race[18][] = "Саламандра"
Race[19][] = "Гигантский комар"
Race[20][] = "Ледяной ужас"
Race[21][] = "Инфидель"
Race[22][] = "Гигантский паук"
Race[23][] = "Адский кот"
Race[24][] = "Griswold"
Race[25][] = "The Smith"
Race[26][] = "Demonolog"
Race[27][] = "VipCztery"*/


//race1,race2,race3,"Ассассин","Некромант","Варвар", "Ниндзя", "Амазонка","Кровавый ворон", "Дуриель", "Мефисто", "Изуал", "Диабло", "Баал", "Падший", "Бес", "Закарум", "Саламандра", "Гигантский комар", "Ледяной ужас", "Инфидель", "Гигантский паук", "Адский кот","Griswold","The Smith","Demonolog","VipCztery" }

new race_heal[28] = { 100, //No
110, //Mag
100, //Monk
130, //Paladin
140, //Assassin
110, //Necromancer
120, //Barbarian
140, //Ninja
140, //Amazon
110, //BloodRaven
120, //Duriel
120, //Mephisto
140, //Izual
150, //Diablo
130, //Baal
130, //Fallen
110, //Imp
100, //Zakarum
135, //Viper
100, //Mosquito
100, //Frozen
140, //Infidel
115, //GiantSpider
120, //SabreCat
145, //Griswold
145, //TheSmith
145, //Demonolog
145 /*VipCztery*/}

new LevelXP[101] = { 0, 50, 125, 225, 340, 510, 765, 1150, 1500, 1950, 2550, 3300, 4000, 4800, 5800, 7000, 8500, 9500, 10500, 11750, 13000, //21
14300, 15730, 17300, 19030, 20900, 23000, 24000, 25200, 26400, 27700, 29000, 30500, 32000, 33600, 35300, 37000, 39000, //38
41000, 43000, 45100, 47400, 49800, 52300, 55000, 57800, 60700, 63700, 66900, 70200, //50
73700, 77400, 80000, 82400, 84900, 87500, 90000, 92700, 95500, 98300, 101000, 104000, 107000, 110000, 113000, 116000, 120000, //67
123000, 126700, 130000, 134000, 138000, 142000, 146000, 150000, 154000, 158000, 163000, 168000, 173000, //80
178000, 183000, 188000, 194000, 200000, 216000, 232000, 255000, 282000, 309000, 325000, 367000, 401000, 427000, 464000, 482000, 505000, 537000, 559000, 579000, 600000/*101*/}

new player_class_lvl[33][28]
new player_class_lvl_save[33]
new player_class_xp[33][28]

new database_user_created[33]

new srv_avg[28] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}

//For Hook and powerup sy
new hooked[33]
new Float:player_global_cooldown[33]

//For optimization
new last_update_xp[33]
new Float:last_update_perc[33]
new bool:use_addtofullpack
#define ICON_HIDE 0 
#define ICON_SHOW 1
#define ICON_FLASH 2 
#define ICON_S "suithelmet_full"


new wear_sun[33]
new anty_flesh[33]


//Flags a user can have
enum
{
	Flag_Ignite = 0,
	Flag_Hooking,
	Flag_Rot,
	Flag_Dazed,
	Flag_Illusion,
	Flag_Moneyshield,
	Flag_Teamshield,
	Flag_Teamshield_Target,
	num_of_flags
}


//Flags
new afflicted[33][num_of_flags]

//noze

new max_knife[33]
new player_knife[33]
new Float:tossdelay[33]

//luk

new Float:bowdelay[33]
new bow[33]
new bow_zoom[33]

new Float:player_last_check_time[33]  //Mosquito
new bool:use_fly[33] //Mosquito
new bool:hit_key[33] //Mosquito
new bool:fly_step_shift[33], Float:fly_check_time[33] //Mosquito

const fly_forward_speed = 300					//forward flying speed 
const fly_left_right_speed = (fly_forward_speed / 3) * 2	//to the left and the speed of flight 
const fly_up_down_speed = fly_forward_speed / 2			//to the upper and lower flight speed
const fly_back_speed = fly_forward_speed / 3			//down flight speed
const fly_step_range = 90	

new button[33]
new can_cast[33] //frozen horror

new mosquito_sting[33]

// amazon - slad

#define TARACE_TASK 91203

new trace_bool[33]

#define NADE_VELOCITY	EV_INT_iuser1
#define NADE_ACTIVE	EV_INT_iuser2	
#define NADE_TEAM	EV_INT_iuser3	
#define NADE_PAUSE	EV_INT_iuser4

new cvar_throw_vel = 90 // def: 90
new cvar_activate_dis = 175 // def 190
new cvar_nade_vel = 280 //def 280
new Float: cvar_explode_delay = 0.5 // def 0.50


new g_TrapMode[33]
new g_GrenadeTrap[33] = {0, ... }
new Float:g_PreThinkDelay[33]


new Float:gfBlockSizeMin1[3]= {-32.0,-4.0,-32.0};
new Float:gfBlockSizeMax1[3]= { 32.0, 4.0, 32.0};
new Float:vAngles1[3] = {90.0,90.0,0.0}

new Float:gfBlockSizeMin2[3]= {-4.0,-32.0,-32.0}
new Float:gfBlockSizeMax2[3]= { 4.0, 32.0, 32.0}
new Float:vAngles2[3] = {90.0,0.0,0.0}

new casting[33]
new casting_bow[33]
new Float:cast_end[33]
new on_knife[33]
new golden_bulet[33]
new ultra_armor[33]
new after_bullet[33]
new num_shild[33]
new invisible_cast[33]

new cvar_max_gold

//SabreCat smoke
//new const g_SabreSmokeClassname[] = "colored_smokenade";

/* PLUGIN CORE REDIRECTING TO FUNCTIONS ========================================================== */


// SQL //

new Handle:g_SqlTuple

new g_sqlTable[64] = "dbmod_tables2"
new g_boolsqlOK=0

// SQL //
//questy
new quest_gracza[33];
new ile_juz[33];

//przedzial , ile ,kogo , nagroda expa, vip 1 tak 0 nie
new questy[][]={
	{1,2,Zakarum,500,0},
	{1,3,Imp,1200,1},
	{1,6,Fallen,2000,0},
	{2,6,Diablo,5000,0},
	{2,15,Viper,15000,1},
	{2,20,BloodRaven,20000,1},
	{3,65,Imp,150000,1},
	{3,120,Baal,200000,1}
}

new vault_questy;
new vault_questy2;

//od , do , hp
new prze[][]={
	{1,50,20},
	{51,80,40},
	{81,101,60}
}

new prze_wybrany[33]

new questy_info[][]={
	"Убей 2 Zakarum (Получи 500 опыта)",
	"Убей 3 Imp (Получи 1200 опыта)",
	"Убей 6 Fallen (Получи 2000 опыта)",
	"Убей 6 Diablo (Получи 5000 опыта)",
	"Убей 15 Viper (Получи 15000 опыта)",
	"Убей 20 BloodRaven (Получи 20000 опыта)",
	"Убей 65 Imp (Получи 150000 опыта)",
	"Убей 120 Баал (Получи 200000 опыта)"
}

new questy_zabil[][]={
	"Ninja",
	"Mag",
	"Assassin",
	"Amazon",
	"Barbarian",
	"Paladin",
	"Barbarian",
	"Paladin"
}

new mod_version[16] = "LP 2.0 beta"


public plugin_init()
{
	get_basedir(amxbasedir,63)
	get_configsdir(configsbasedir,63)
	
	new map[32]
	get_mapname(map,31)
	new times[64]
	get_time("%m/%d/%Y - %H:%M:%S" ,times,63)
	//D2_Log( true, "%s ### MAP: %s ### ",times,map)
	WC3_MapDisableCheck("weapons.cfg")
	
	gcvar_host = register_cvar("diablo_sql_host","localhost",FCVAR_PROTECTED)
	gcvar_user = register_cvar("diablo_sql_user","root",FCVAR_PROTECTED)
	gcvar_pass = register_cvar("diablo_sql_pass","",FCVAR_PROTECTED)
	gcvar_database = register_cvar("diablo_sql_database","dbmod",FCVAR_PROTECTED)
	
	//register_cvar("diablo_sql_table","dbmod_table222",FCVAR_PROTECTED)
	register_cvar("diablo_sql_save","0",FCVAR_PROTECTED)	// 0 - nick
								// 1 - ip
								// 2 - steam id	
	register_cvar("diablo_classes", "abcdefghijklmnoprstuwxyz!@#$")
	// a Mag
	// b Paladin
	// c Monk
	// d Assassin
	// e Barbarian
	// f Necromancer
	// g Ninja
	// h Amazon
		
	register_cvar("diablo_avg", "1")	
		
	cvar_revival_time 	= register_cvar("amx_revkit_time", 	"3")
	cvar_revival_health	= register_cvar("amx_revkit_health", 	"25")
	cvar_revival_dis 	= register_cvar("amx_revkit_distance", 	"70.0")
	
	g_msg_bartime	= get_user_msgid("BarTime")
	g_msg_clcorpse	= get_user_msgid("ClCorpse")
	g_msg_screenfade= get_user_msgid("ScreenFade")
	g_msg_statusicon= get_user_msgid("StatusIcon")
	g_msgDamage = get_user_msgid("Damage")
	g_MsgText 		= get_user_msgid("TextMsg")

	register_message(g_msg_clcorpse, "message_clcorpse")
	
	register_event("HLTV", 		"event_hltv", 	"a", "1=0", "2=0")
	
	register_forward(FM_Touch, 		"fwd_touch")
	register_forward(FM_Touch, "fwTouch")
	register_forward(FM_EmitSound, 		"fwd_emitsound")
	register_forward(FM_PlayerPostThink, 	"fwd_playerpostthink")
	register_forward(FM_SetClientKeyValue, "fw_SetClientKeyValue")
	g_MaxPlayers = get_maxplayers()
	//register_forward(FM_CmdStart, "Fwd_CmdStart");
	register_forward(FM_CmdStart, "FwdCmdStart");
	RegisterHam(Ham_TakeDamage, "player", "HamTakeDamage")
	new szWeaponName[32] 
    new NOSHOT_BITSUM = (1<<CSW_KNIFE) | (1<<CSW_HEGRENADE) | (1<<CSW_FLASHBANG) | (1<<CSW_SMOKEGRENADE) 
    for(new iId = CSW_P228; iId <= CSW_P90; iId++) 
    { 
        if( ~NOSHOT_BITSUM & 1<<iId && get_weaponname(iId, szWeaponName, charsmax(szWeaponName) )) 
        { 
            RegisterHam(Ham_Weapon_PrimaryAttack, szWeaponName, "fwd_AttackSpeed", 1) 
			RegisterHam(Ham_Item_Deploy , szWeaponName, "fwd_AttackSpeed", 1)
		} 
	}
	//Diablo napalm
	RegisterHam(Ham_Think, "grenade", "fw_ThinkGrenade",0)
	RegisterHam(Ham_Touch, "player", "fw_TouchPlayer")
	
	register_plugin("DiabloMod","2.0","HiTmAnY") 
	register_cvar("diablomod_version",mod_version,FCVAR_SERVER)
	
	register_cvar("flashlight_custom","1");
	register_cvar("flashlight_drain","1.0");
	register_cvar("flashlight_charge","0.5");
	register_cvar("flashlight_radius","8");
	register_cvar("flashlight_decay","90");
	register_event("Flashlight","event_flashlight","b");
		
	register_event("CurWeapon","CurWeapon","be", "1=1") 
	register_event("ResetHUD", "ResetHUD", "abe")
	register_event("ScreenFade","det_fade","be","1!0","2!0","7!0")
	register_event("DeathMsg","DeathMsg","ade") 
	register_event("Damage", "Damage", "ae", "2!0")
	register_event("SendAudio","freeze_over","b","2=%!MRAD_GO","2=%!MRAD_MOVEOUT","2=%!MRAD_LETSGO","2=%!MRAD_LOCKNLOAD")
	register_event("SendAudio","freeze_begin","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw") 
	register_event("HLTV", "round_bstart", "a", "1=0", "2=0")
	register_logevent("round_estart", 2, "1=Round_Start")
	
	register_event("SendAudio", "award_defuse", "a", "2&%!MRAD_BOMBDEF")  	
	register_event("BarTime", "bomb_defusing", "be", "1=10", "1=5")
	
	register_logevent("award_plant", 3, "2=Planted_The_Bomb");	
	register_event("StatusIcon", "got_bomb", "be", "1=1", "1=2", "2=c4")
		
	register_event("TextMsg", "award_hostageALL", "a", "2&#All_Hostages_R" ); 
	register_event("TextMsg","host_killed","b","2&#Killed_Hostage") 
	register_event("SendAudio","eventGrenade","bc","2=%!MRAD_FIREINHOLE")
	register_event("TextMsg", "freeze_begin", "a", "2=#Game_will_restart_in")
	register_event("SendAudio", "TTWin", "a", "2&%!MRAD_terwin")
	register_event("SendAudio", "CTWin", "a", "2&%!MRAD_ctwin")
	register_clcmd("say drop","dropitem") 
	register_clcmd("say /drop","dropitem")
	register_clcmd("say /d","dropitem")
	register_clcmd("say /ii","iteminfo")
	register_clcmd("say /item","iteminfo")
	register_clcmd("say /iteminfo","iteminfo")
	register_clcmd("say /menuitem","show_menu_item")
	register_clcmd("say /items","show_menu_item")
	//register_clcmd("say /help","helpme") 
	register_clcmd("say changerace","changerace")
	register_clcmd("say /class","changerace")
	register_clcmd("say /speed","speed")
	register_clcmd("say /s","speed")
	//register_clcmd("flash", "cmdBlyskawica");
	register_concmd("rocket","StworzRakiete")
	//register_concmd("fallen","FallenShaman")
	//register_concmd("pluginflash","Flesh")
	register_clcmd("say /portal","cmd_place_portal")
	register_clcmd("say portal","cmd_place_portal")
	register_clcmd("say class","changerace")
	register_clcmd("say /who","cmd_who")	
	register_clcmd("say /skills", "showskills")
	register_clcmd("say skills", "showskills")
	register_clcmd("say /menu","showmenu") 
	register_clcmd("menu","showmenu")
	register_clcmd("say /commands","komendy")
	//register_clcmd("pomoc","helpme") 
	//register_clcmd("say /rune","mana4") 
	//register_clcmd("rune","mana4")
	//register_clcmd("say /r","mana4")
	//register_clcmd("say /savexp","savexpcom")
	register_clcmd("say /reset","reset_skill")
	//register_clcmd("say /exp", "exp")
	//register_clcmd("say exp", "exp")
	//register_clcmd("reset","reset_skill")	 
	//register_clcmd("/reset","reset_skill")
	//register_clcmd("say /gold","mana1")
	//register_clcmd("say /g","mana1")		
	register_clcmd("mod","mod_info")
	//register_concmd("dynamit","PolozDynamit")
	//register_concmd("paladin","check_palek")
	register_concmd("setmine","item_mine")
	register_clcmd("+rope", "make_hook")
	register_clcmd("-rope", "del_hook")
	register_clcmd("amx_boss","cmdMakeBoss",ADMIN_IMMUNITY,"<name or #userid> <power> - make player a boss. Power must be 201 to 999")
	register_clcmd("amx_unboss","cmdUnmakeBoss",ADMIN_IMMUNITY,"- end the boss event")
	register_event("TeamScore","hook_teamscore","a")
	register_menucmd(register_menuid("Team_Select"),(1<<0)|(1<<1)|(1<<4)|(1<<5),"hook_team_select")
	register_menucmd(-2,(1<<0)|(1<<1)|(1<<4)|(1<<5),"hook_team_select")
	player=0
	register_concmd("amx_givehook", "give_hook", ADMIN_IMMUNITY, "<Username> - Give somebody access to the hook")
	register_concmd("amx_takehook", "take_hook", ADMIN_IMMUNITY, "<UserName> - Take away somebody his access to the hook")
	
	//Diablo nades unlimit ammo
	
	// Buy grenades old style
	register_menucmd(register_menuid("BuyItem"), (1<<3), "cmd_HeBuy")
	// Buy grenades new style (VGUI)
	register_menucmd(-34, (1<<3), "cmd_HeBuy")	
	// Buy grenades through console commands
	register_clcmd("hegren", "cmd_HeBuy")
	
	register_menucmd(register_menuid("Навыки"), 1023, "skill_menu")
	register_menucmd(register_menuid("Опции"), 1023, "option_menu")
	register_menucmd(register_menuid("ChooseClass"), 1023, "select_class_menu")
	register_menucmd(register_menuid("ChooseRune"), 1023, "select_rune_menu")
	register_menucmd(register_menuid("Новые Предметы"), 1023, "nowe_itemy")
	register_menucmd(register_menuid("Демоны"), 1023, "PressedKlasy")
	register_menucmd(register_menuid("Heroes"), 1023, "PokazMeni")
	register_menucmd(register_menuid("Животные"), 1023, "PokazZwierz")
	register_menucmd(register_menuid("Премиум"), 1023, "PokazPremium")
	gmsgDeathMsg = get_user_msgid("DeathMsg")
	gmsgStatusText = get_user_msgid("StatusText")
	gmsgBartimer = get_user_msgid("BarTime") 
	gmsgScoreInfo = get_user_msgid("ScoreInfo") 
	register_cvar("diablo_xpdmg","10",0)
	register_cvar("diablo_xpbonus","20",0)
	register_cvar("diablo_xpbonus_type","1",0)
	register_cvar("diablo_xp_multi","2",0)
	register_cvar("diablo_xp_multi2","2",0)
	register_cvar("diablo_durability","5",0) 
	cvar_max_gold 	= register_cvar("diablo_maxgold","250") 
	register_cvar("SaveXP", "1")
	set_msg_block ( gmsgDeathMsg, BLOCK_SET ) 
	set_task(5.0, "Timed_Healing", 0, "", 0, "b")
	set_task(1.0, "radar_scan", 0, _, _, "b"); // radar
	set_task(1.0, "fallen_respawn", 2, _, _, "b") //falen shaman and zakarum priest
	set_task(1.0, "Timed_Ghost_Check", 0, "", 0, "b")
	set_task(0.8, "UpdateHUD",0,"",0,"b")
	register_think("PlayerCamera","Think_PlayerCamera");
	register_think("PowerUp","Think_PowerUp")
	register_think("Effect_Rot","Effect_Rot_Think")
	register_think("Effect_Zamroz_Totem","Effect_Zamroz_Totem_Think")
	register_think("Effect_Fleshuj_Totem","Effect_Fleshuj_Totem_Think")
	register_think("Effect_Wywal_Totem","Effect_Wywal_Totem_Think")
	register_think("Effect_Kasa_Totem","Effect_Kasa_Totem_Think")
	register_think("Effect_Kasaq_Totem","Effect_Kasaq_Totem_Think")
	register_think("HealBot", "HealBotThink");
        CreateHealBot();
	register_think("HealBot2", "HealBotThink2");
        CreateHealBot2();
	register_think("HealBot3", "HealBotThink3");
        CreateHealBot3();
	register_think("HealBot4", "HealBotThink4");
        CreateHealBot4();
	register_logevent("RoundStart", 2, "0=World triggered", "1=Round_Start")
	register_logevent( "on_EndRound"			, 2		, "0=World triggered"	, "1=Round_End"		);
	register_clcmd("fullupdate","fullupdate")
	register_clcmd("amx_dajitem",  "giveitem",     ADMIN_IMMUNITY, "Uzycie <amx_dajitem NICK idITemku")
	register_forward(FM_WriteString, "FW_WriteString")
	register_think("Effect_Ignite_Totem", "Effect_Ignite_Totem_Think")
	register_think("Effect_Ignite", "Effect_Ignite_Think")
	register_think("Effect_Slow","Effect_Slow_Think")
	register_think("Effect_Timedflag","Effect_Timedflag_Think")
	register_think("Effect_MShield","Effect_MShield_Think")
	register_think("Effect_Teamshield","Effect_Teamshield_Think")
	register_think("Effect_Healing_Totem","Effect_Healing_Totem_Think")
	register_think("viperball", "viper_think")
	register_forward(FM_AddToFullPack, "client_AddToFullPack")
	register_forward(FM_UpdateClientData, "UpdateClientData_Post", 1)
	register_event("SendAudio","freeze_over1","b","2=%!MRAD_GO","2=%!MRAD_MOVEOUT","2=%!MRAD_LETSGO","2=%!MRAD_LOCKNLOAD")
	register_event("SendAudio","freeze_begin1","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw")

	register_forward(FM_PlayerPreThink, "Forward_FM_PlayerPreThink")
	register_forward(FM_SetModel, "fw_SetModel") //SabreCat W_ model
	
	register_cvar("diablo_dir", "addons/amxmodx/diablo/")
	
	get_cvar_string("diablo_dir",Basepath,127)
	
	register_event("Health", "Health", "be", "1!255")
	register_cvar("diablo_show_health","1")
	gmsgHealth = get_user_msgid("Health")
	g_msgHostageAdd = get_user_msgid("HostagePos");
	g_msgHostageDel = get_user_msgid("HostageK");
	//noze
	
	register_touch("throwing_knife", "player", "touchKnife")
	register_touch("throwing_knife", "worldspawn",		"touchWorld")
	register_touch("throwing_knife", "func_wall",		"touchWorld")
	register_touch("throwing_knife", "func_door",		"touchWorld")
	register_touch("throwing_knife", "func_door_rotating",	"touchWorld")
	register_touch("throwing_knife", "func_wall_toggle",	"touchWorld")
	register_touch("throwing_knife", "dbmod_shild",		"touchWorld")
	
	register_touch("throwing_knife", "func_breakable",	"touchbreakable")
	register_touch("func_breakable", "throwing_knife",	"touchbreakable")
	
	register_touch("mosquito_sting", "player", "touchmosquito_sting")
	register_touch("mosquito_sting", "worldspawn",		"removeEntity")
	register_touch("mosquito_sting", "func_wall",		"removeEntity")
	register_touch("mosquito_sting", "func_door",		"removeEntity")
	register_touch("mosquito_sting", "func_door_rotating",	"removeEntity")
	register_touch("mosquito_sting", "func_wall_toggle",	"removeEntity")
	register_touch("mosquito_sting", "dbmod_shild",		"removeEntity")
	
	register_touch("mosquito_sting", "func_breakable",	"touchbreakable")
	register_touch("func_breakable", "mosquito_sting",	"touchbreakable")
	
	register_touch("spidertrap", "player", "touchSpiderTrap")
	
	register_cvar("diablo_knife","20")
	register_cvar("diablo_knife_speed","1000")
	
	register_cvar("diablo_mosquito_sting_speed","1000")
	
	register_touch("xbow_arrow", "player", 			"toucharrow")
	register_touch("xbow_arrow", "worldspawn",		"touchWorld2")
	register_touch("xbow_arrow", "func_wall",		"touchWorld2")
	register_touch("xbow_arrow", "func_door",		"touchWorld2")
	register_touch("xbow_arrow", "func_door_rotating",	"touchWorld2")
	register_touch("xbow_arrow", "func_wall_toggle",	"touchWorld2")
	register_touch("xbow_arrow", "dbmod_shild",		"touchWorld2")
	
	register_touch("xbow_arrow", "func_breakable",		"touchbreakable")
	register_touch("func_breakable", "xbow_arrow",		"touchbreakable")
	register_touch("Rocket", "*" , "DotykRakiety");
	//register_touch("info_target", "player", "portal_touch")
	register_touch("iportal", "player", "portal_touch")
	register_touch("frozencold", "player", "frozen_touch")
	//register_touch("frozencold", "worldspawn",		"touchWorld2")
	//register_touch("frozencold", "func_wall",		"touchWorld2")
	//register_touch("frozencold", "func_door",		"touchWorld2")
	//register_touch("frozencold", "func_door_rotating",	"touchWorld2")
	//register_touch("frozencold", "func_wall_toggle",	"touchWorld2")
	register_touch("frozencold", "dbmod_shild",		"touchWorld2")
	register_touch("impfires", "player", "imp_touch")
	//register_touch( g_SabreSmokeClassname, "worldspawn", "FwdTouch_FakeSmoke" );
	//register_think( g_SabreSmokeClassname, "FwdThink_FakeSmoke" );
	register_think( "saber_smoke3", "FwdThink_FakeSmoke2" );
	register_touch( "saber_smoke3", "player", "FwdPlayerTouch_FakeSmoke" );
	
	register_cvar("diablo_arrow","120.0")
	register_cvar("diablo_arrow_multi","2.0")
	register_cvar("diablo_arrow_speed","1500")
	
	register_cvar("diablo_klass_delay","2.5")
	pHook = 	register_cvar("sv_hook", "1")
	pThrowSpeed = 	register_cvar("sv_hookthrowspeed", "2000")
	pSpeed = 	register_cvar("sv_hookspeed", "600")
	pWidth = 	register_cvar("sv_hookwidth", "32")
	pSound = 	register_cvar("sv_hooksound", "1")
	pColor =	register_cvar("sv_hookcolor", "1")
	pPlayers = 	register_cvar("sv_hookplayers", "0")
	pInterrupt = 	register_cvar("sv_hookinterrupt", "0")
	pAdmin = 	register_cvar("sv_hookadminonly",  "0")
	pHookSky = 	register_cvar("sv_hooksky", "0")
	pOpenDoors = 	register_cvar("sv_hookopendoors", "1")
	pUseButtons = 	register_cvar("sv_hookusebuttons", "1")
	pHostage = 	register_cvar("sv_hookhostflollow", "1")
	pWeapons =	register_cvar("sv_hookpickweapons", "1")
	pInstant =	register_cvar("sv_hookinstant", "0")
	pHookNoise = 	register_cvar("sv_hooknoise", "0")
	pMaxHooks = 	register_cvar("sv_hookmax", "0")
	pRndStartDelay = register_cvar("sv_hookrndstartdelay", "0.0")
	
	//Koniec noze
	
	register_think("grenade", "think_Grenade")
	register_think("think_bot", "think_Bot")
	_create_ThinkBot()
	
	register_forward(FM_TraceLine,"fw_traceline");
	vault_questy = nvault_open("Questy");
	vault_questy2 = nvault_open("Questy2");
	
	register_clcmd("quest","menu_questow")
	register_clcmd("say /quest","menu_questow")
	server_cmd("exec %s/diablo/main.cfg", configsbasedir) 
	sql_start()
	//set_task(1.0, "AutoCheck_Afk", 0, "", 0, "b")
	
	return PLUGIN_CONTINUE  
}

bool:WC3_MapDisableCheck( szFileName[] )
{
	// Format the Orc Nade Disable File
	new szFile[128];
	
	formatex( szFile, 127, "%s/diablo/disable/%s", amxbasedir, szFileName );

	if ( !file_exists( szFile ) )
	{
		return g_bWeaponsDisabled = false;
	}

	new iLineNum, szData[64], iTextLen, iLen;
	new szMapName[64], szRestrictName[64];
	get_mapname( szMapName, 63 );

	while ( read_file( szFile, iLineNum, szData, 63, iTextLen ) )
	{
		iLen = copyc( szRestrictName, 63, szData, '*' );

		if ( equali( szMapName, szRestrictName, iLen ) )
		{
      return g_bWeaponsDisabled = true;
		}

		iLineNum++;
	}

	return false;
}

public menu_questow(id){
	if(quest_gracza[id] == -1 || quest_gracza[id] == -2){
		
		new menu = menu_create("Меню Квестов","menu_questow_handle")
		new formats[128]
		for(new i = 0;i<sizeof prze;i++){
			formatex(formats,127,"Квесты от %d до %d уровня",prze[i][0],prze[i][1]);
			menu_additem(menu,formats)
		}
		menu_display(id,menu,0)
	}
	else
	{
		client_print(id,print_chat,"Вы не выполнили предыдущее задание")
	}
}

public menu_questow_handle(id,menu,item){
	if(item == MENU_EXIT){
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	if(player_lvl[id] < prze[item][0])
	{
		client_print(id,print_chat,"Ваш уровень меньше требуемого!");
		menu_questow(id)
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	new formats[128]
	formatex(formats,127,"Квесты от %d до %d уровня",prze[item][0],prze[item][1]);
	new menu2 = menu_create(formats,"menu_questow_handle2")
	for(new i = 0;i<sizeof(questy);i++)
	{
		if(questy[i][0] == item+1){
			menu_additem(menu2,questy_info[i]);
		}
	}
	menu_setprop(menu2, MPROP_EXITNAME, "Выход");
	menu_setprop(menu2, MPROP_BACKNAME, "Назад");
	menu_setprop(menu2, MPROP_NEXTNAME, "Вперед");
	prze_wybrany[id] = item+1;
	menu_display(id,menu2)
	return PLUGIN_CONTINUE;
}

public zapisz_questa(id,quest)
{
	new name[64];
	get_user_name(id,name,63)
	strtolower(name)
	new key[64];
	format(key,63,"questy-%i-%s-%i",player_class[id],name,quest);
	nvault_set(vault_questy,key,"1");
}

public zapisz_aktualny_quest(id)
{
	new name[64];
	get_user_name(id,name,63)
	strtolower(name)
	new key[256];
	format(key,255,"questy-%d-%s",player_class[id],name);
	new data[32]
	formatex(data,charsmax(data),"#%d#%d",quest_gracza[id]+1,ile_juz[id]);
	nvault_set(vault_questy2,key,data);
}

public wczytaj_aktualny_quest(id)
{
	new name[64];
	get_user_name(id,name,63)
	strtolower(name)
	new key[256];
	format(key,255,"questy-%d-%s",player_class[id],name);
	new data[32];
	nvault_get(vault_questy2,key,data,31);
	replace_all(data,31,"#"," ");
	new questt[32],ile[32]
	parse(data,questt,31,ile,31)
	ile_juz[id] = str_to_num(ile)
	return str_to_num(questt)-1
}

public wczytaj_questa(id,quest)
{
	new name[64];
	get_user_name(id,name,63)
	strtolower(name)
	new key[64];
	format(key,63,"questy-%i-%s-%i",player_class[id],name,quest);
	new data[64];
	nvault_get(vault_questy,key,data,63);
	return str_to_num(data);
}

public menu_questow_handle2(id,menu,item)
{
	if(item == MENU_EXIT){
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	new ile2 = 0;
	for(new i = 0;i<sizeof(questy);i++){
		if(questy[i][0] != prze_wybrany[id]){
			continue;
		}
		if(ile2 == item){
			item = i;
			break;
		}
		ile2++;
	}
	if(questy[item][4] && (!player_premium[id])){
		client_print(id,print_chat,"Этот квест только для Премиум! Покупка премиум на lpstrike.ru");
		menu_questow(id)
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	if(wczytaj_questa(id,item)){
		client_print(id,print_chat,"Ты уже выполнил эту задачу!");
		menu_questow(id)
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	quest_gracza[id] = item;
	ile_juz[id] = 0
	zapisz_aktualny_quest(id)
	client_print(id,print_chat,"Вы выбрали задания: %s Удачи !",questy_info[item]);
	quest_gracza[id] = wczytaj_aktualny_quest(id);
	menu_destroy(menu);
	return PLUGIN_CONTINUE;
}

// Verifies that the database connection is ok
bool:MYSQLX_Connection_Available()
{
	if ( !bDBAvailable || !g_DBConn )
	{
		return false;
	}

	return true;
}

// Function will simply log to a file as well as amxx log
public D2_Log( bool:bAmxx, const fmt[], ... )
{
	static szFormattedText[512];
	vformat( szFormattedText, 511, fmt, 3 );

	// Write to amxx log file
	if ( bAmxx )
	{
		log_amx( szFormattedText );
	}

	new szLogFile[128];
	get_configsdir( szLogFile, 127 );
	formatex( szLogFile, 127, "%s/diablo/d2_error.log", szLogFile );

	// Write to the war3ft log file as well
	log_to_file( szLogFile, szFormattedText );
}

public MYSQLX_Close()
{
	if ( g_DBTuple )
	{
		SQL_FreeHandle( g_DBTuple );
	}

	if ( g_DBConn )
	{
		SQL_FreeHandle( g_DBConn );
	}

	bDBAvailable = false;
}

// The id should be a unique number, so we know what function called it (useful for debugging)
public MYSQLX_Error( Handle:query, szQuery[], id )
{
	new szError[256];
	new iErrNum = SQL_QueryError( query, szError, 255 );

	D2_Log( true, "[MYSQLX] Error in querying database, location: %d", id );
	D2_Log( true, "[MYSQLX] Message: %s (%d)", szError, iErrNum );
	D2_Log( true, "[MYSQLX] Query statement: %s ", szQuery );

	// Free the handle
	SQL_FreeHandle( query );

	// MySQL server has gone away (2006)
	if ( iErrNum == 2006 )
	{
		D2_Log( true, "[MYSQLX] Attempting to re-establish connection to MySQL server" );
		// Close the connection
		MYSQLX_Close();

		// Re-open the connection
		sql_start();
	}
}

public MYSQLX_ThreadError( Handle:query, szQuery[], szError[], iErrNum, failstate, id )
{
	D2_Log( true, "[MYSQLX] Threaded query error, location: %d", id );
	D2_Log( true, "[MYSQLX] Message: %s (%d)", szError, iErrNum );
	D2_Log( true, "[MYSQLX] Query statement: %s ", szQuery );

	// Connection failed
	if ( failstate == TQUERY_CONNECT_FAILED )
	{	
		D2_Log( true, "[MYSQLX] Fail state: Connection Failed" );
	}

	// Query failed
	else if ( failstate == TQUERY_QUERY_FAILED )
	{
		D2_Log( true, "[MYSQLX] Fail state: Query Failed" );
	}

	// Free the handle
	SQL_FreeHandle( query );
}

public MYSQLX_UpdateTimestamp( id )
{
	// Make sure our connection is working
	if ( !MYSQLX_Connection_Available() )
	{
		return;
	}

	new szQuery[256];
	format( szQuery, 255, "UPDATE `player` SET time = NOW() WHERE ( `id` = '%d' );", DB_GetUniqueID( id ) );

	SQL_ThreadQuery( g_DBTuple, "_MYSQLX_UpdateTimestamp", szQuery );	
}

public _MYSQLX_UpdateTimestamp( failstate, Handle:query, error[], errnum, data[], size )
{
	// Error during the query
	if ( failstate )
	{
		new szQuery[256];
		SQL_GetQueryString( query, szQuery, 255 );
		
		MYSQLX_ThreadError( query, szQuery, error, errnum, failstate, 4 );
	}

	// Query successful, we can do stuff!
	else
	{
		// Free the handle
		SQL_FreeHandle( query );
	}

	return;
}

// Create all of our tables!
public MYSQLX_CreateTables()
{
	new Handle:query;

	// Create the default tables if we need to
	for ( new i = 0; i < TOTAL_TABLES; i++ )
	{
		query = SQL_PrepareQuery( g_DBConn, szTables[i] );

		if ( !SQL_Execute( query ) )
		{
			MYSQLX_Error( query, szTables[i], 1 );

			return;
		}

		SQL_FreeHandle( query );
	}
}

public sql_start()
{
	
	new host[128], database[64], user[64], pass[64], szError[256], iErrNum;
	
	server_cmd("exec %s/diablo/main.cfg", configsbasedir)
	server_exec()
	
	get_pcvar_string(gcvar_database,database,63)
	get_pcvar_string(gcvar_host,host,127)
	get_pcvar_string(gcvar_user,user,63)
	get_pcvar_string(gcvar_pass,pass,63)
	
	g_SqlTuple = SQL_MakeDbTuple(host,user,pass,database)
	
	// Attempt to connect
	g_DBConn = SQL_Connect( g_SqlTuple, iErrNum, szError, 255 );
	
	if ( !g_DBConn )
	{
		D2_Log( true, "Database Connection Failed: [%d] %s", iErrNum, szError )

		return;
	}

	server_print( "[Diablo] MySQL X database connection successful" );
	
	bDBAvailable = true;
	
	// Create tables!
	MYSQLX_CreateTables();
	
}

public DB_GetUniqueID( id )
{
	// Then we need to determine this player's ID!
	if ( g_iDBPlayerUniqueID[id] <= 0 )
	{
		DB_FetchUniqueID( id );
	}

	return g_iDBPlayerUniqueID[id];
}

public bool:DB_Connection_Available()
{

	MYSQLX_Connection_Available();

	return false;
}

public DB_FetchUniqueID( id )
{
	MYSQLX_FetchUniqueID( id );
	
	// Nothing was found - try again in a bit
	if ( g_iDBPlayerUniqueID[id] == 0 )
	{
		// No connection available!
		if ( !DB_Connection_Available() )
		{
			return;
		}

		set_task( 1.0, "DB_FetchUniqueID", id );
	}

	return;
}

public MYSQLX_FetchUniqueID( id )
{
	// Make sure our connection is working
	if ( !MYSQLX_Connection_Available() )
	{
		return;
	}

	// Remember how we got this ID
	g_iDBPlayerSavedBy[id] = 2;

	new szQuery[512], szName[70];
	get_user_name( id, szName, 69 );
	format( szQuery, 511, "SELECT `id` FROM `player` WHERE `name` = '%s';", szName);
	new Handle:query = SQL_PrepareQuery( g_DBConn, szQuery );

	if ( !SQL_Execute( query ) )
	{
		MYSQLX_Error( query, szQuery, 2 );

		return;
	}

	// If no rows we need to insert!
	if ( SQL_NumResults( query ) == 0 )
	{
		// Free the last handle!
		SQL_FreeHandle( query );

		// Insert this player!
		new szQuery[512];
		format( szQuery, 511, "INSERT INTO `player` ( `id` , `name` , `time` ) VALUES ( NULL , '%s', NOW() );", szName );
		new Handle:query = SQL_PrepareQuery( g_DBConn, szQuery );

		if ( !SQL_Execute( query ) )
		{
			MYSQLX_Error( query, szQuery, 3 );

			return;
		}

		g_iDBPlayerUniqueID[id] = SQL_GetInsertId( query );

		// Since we have the ID - lets insert extra data here...
		//  Basically insert whatever data we don't have yet on this player in the extra table 
		//  (this will only be used for the webpage)
		/*new szName[70], szSteamID[30], szIP[20];
		get_user_name( id, szName, 69 );
		DB_FormatString( szName, 69 );
		get_user_ip( id, szIP, 19, 1 );
		get_user_authid( id, szSteamID, 29 );

		format( szQuery, 511, "INSERT INTO `wc3_player_extra` ( `player_id` , `player_steamid` , `player_ip` , `player_name` ) VALUES ( '%d', '%s', '%s', '%s' );", g_iDBPlayerUniqueID[id], szSteamID, szIP, szName );
		query = SQL_PrepareQuery( g_DBConn, szQuery );

		if ( !SQL_Execute( query ) )
		{
			MYSQLX_Error( query, szQuery, 20 );

			return;
		}*/
	}

	// They have been here before - store their ID
	else
	{
		g_iDBPlayerUniqueID[id] = SQL_ReadResult( query, 0 );
	}

	// Free the last handle!
	SQL_FreeHandle( query );
}

public MYSQLX_GetAllXP( id )
{
	// Make sure our connection is working
	if ( !MYSQLX_Connection_Available() )
	{
		return;
	}
	
	new iUniqueID = DB_GetUniqueID( id );

	// Then we have a problem and cannot retreive the user's XP
	if ( iUniqueID <= 0 )
	{
		client_print( id, print_chat, "Unable to retreive your XP from the database, please attempt to changerace later");

		D2_Log( true, "[ERROR] Unable to retreive user's Unique ID" );

		return;
	}

	new szQuery[256];
	format(szQuery, 255, "SELECT `class`, `xp` FROM `class` WHERE ( `id` = '%d' );", iUniqueID );
	new Handle:query = SQL_PrepareQuery( g_DBConn, szQuery );

	if ( !SQL_Execute( query ) )
	{
		client_print( id, print_chat, "Error, unable to retrieve XP, please contact a server administrator");

		MYSQLX_Error( query, szQuery, 6 );

		return;
	}

	// Get the XP!
	new iXP, iRace;

	// Loop through all of the records to find the XP data
	while ( SQL_MoreResults( query ) )
	{
		iRace	= SQL_ReadResult( query, 0 );
		iXP		= SQL_ReadResult( query, 1 );
		for (new i = 1; i <= sizeof(LevelXP)-1; i++ )
		{
			// User has enough XP to advance to the next level
			if ( iXP >= LevelXP[i])
			{
				player_class_lvl[id][iRace] = i+1;
			}
			else
			{
				break;
			}
		}
		
		// Save the user's XP in an array
		if ( iRace > 0 && iRace < MAX_RACES + 1 )
		{
			player_class_xp[id][iRace] = iXP
		}

		SQL_NextRow( query );
	}

	// Free the handle
	SQL_FreeHandle( query );
	
	//Get total lvl and gold
	format(szQuery, 255, "SELECT `gold`, `total_lvl` FROM `extra` WHERE ( `id` = '%d' );", iUniqueID );
	query = SQL_PrepareQuery( g_DBConn, szQuery );

	if ( !SQL_Execute( query ) )
	{
		MYSQLX_Error( query, szQuery, 2 );

		return;
	}

	// If no rows we need to insert!
	if ( SQL_NumResults( query ) == 0 )
	{
		// Free the last handle!
		SQL_FreeHandle( query );

		// Insert this player!
		new szQuery[512];
		format( szQuery, 511, "INSERT INTO `extra` ( `id`) VALUES ( '%d' );", iUniqueID );
		new Handle:query = SQL_PrepareQuery( g_DBConn, szQuery );

		if ( !SQL_Execute( query ) )
		{
			MYSQLX_Error( query, szQuery, 3 );

			return;
		}
	}
	else
	{
		mana_gracza[id] = SQL_ReadResult( query, 0 );
		player_TotalLVL[id] = SQL_ReadResult( query, 1 );
		if(mana_gracza[id] > get_pcvar_num(cvar_max_gold))
		{
			mana_gracza[id] = get_pcvar_num(cvar_max_gold)
		}
	}

	// Free the last handle!
	SQL_FreeHandle( query );
	
	//Get all items
	format(szQuery, 255, "SELECT `item`, `item_number`, `expire_time` FROM `item` WHERE `id` = '%d';", iUniqueID );
	query = SQL_PrepareQuery( g_DBConn, szQuery );

	if ( !SQL_Execute( query ) )
	{
		client_print( id, print_chat, "Error, unable to retrieve XP, please contact a server administrator");

		MYSQLX_Error( query, szQuery, 6 );

		return;
	}

	// Get the XP!
	new iItem, iTime, iItemID;

	// Loop through all of the records to give item
	while ( SQL_MoreResults( query ) )
	{
		iItem	= SQL_ReadResult( query, 0 );
		iItemID		= SQL_ReadResult( query, 1 );
		iTime		= SQL_ReadResult( query, 2 );
		
		Give_Artefact(id, iItem, iTime, iItemID)

		SQL_NextRow( query );
	}

	// Free the handle
	SQL_FreeHandle( query );

	// Call the function that will display the "select a race" menu
	//D2_ChangeRaceShowMenu( id, g_iDBPlayerXPInfoStore[id] );
	select_class(id)
	loaded_xp[id] = 0;
	
	return;
}

public MYSQLX_Save( id )
{
	// Make sure our connection is working
	if ( !MYSQLX_Connection_Available() )
	{
		return;
	}

	new iUniqueID = DB_GetUniqueID( id );

	// Error checking when saving
	if ( iUniqueID <= 0 )
	{
		new szName[128];
		get_user_name( id, szName, 127 );

		D2_Log( true, "Unable to save XP for user '%s', unique ID: %d", szName, iUniqueID );

		return;
	}
	
	new szQuery[512];
	new Handle:query
	
	// Save the user's XP!
	if ( player_xp[id] > 0 && player_class[id] != 0 )
	{
		format( szQuery, 511, "REPLACE INTO `class` ( `id` , `class` , `xp` ) VALUES ( '%d', '%d', '%d');", iUniqueID, player_class[id], player_xp[id] );
		query = SQL_PrepareQuery( g_DBConn, szQuery );

		if ( !SQL_Execute( query ) )
		{
			client_print( id, print_chat, "Error, unable to save your XP, please contact a server administrator" );

			MYSQLX_Error( query, szQuery, 4 );

			return;
		}
	}

	
	// Then we need to save this!
	if ( player_xp[id] > 0 && player_class[id] != 0 )
	{
		format( szQuery, 511, "REPLACE INTO `skill` (`id`, `class`, `str`, `agi_dmg`, `int`, `dex_dmg`) VALUES ('%d', '%d', '%d', '%d', '%d', '%d');", iUniqueID, player_class[id], player_strength[id], player_agility[id], player_intelligence[id], player_dextery[id] );
		query = SQL_PrepareQuery( g_DBConn, szQuery );
	
		if ( !SQL_Execute( query ) )
		{
			client_print( id, print_chat, "Error, unable to save your skills, please contact a server administrator" );
	
			MYSQLX_Error( query, szQuery, 5 );
	
			return;
		}
	}
	
	if( (player_TotalLVL[id] > 0) || (mana_gracza[id] > 0) )
	{
		format( szQuery, 511, "REPLACE INTO `extra` (`id`, `gold`, `total_lvl`) VALUES ('%d', '%d', '%d');", iUniqueID, mana_gracza[id], player_TotalLVL[id]);
		query = SQL_PrepareQuery( g_DBConn, szQuery );
	
		if ( !SQL_Execute( query ) )
		{
			client_print( id, print_chat, "Error, unable to save your gold, please contact a server administrator" );
	
			MYSQLX_Error( query, szQuery, 5 );
	
			return;
		}
	}
	format( szQuery, 511, "REPLACE INTO `item` (`id`, `item`, `item_number`, `expire_time`) VALUES ('%d', '%d', '1', '%d');", iUniqueID, player_artifact[id][1], player_artifact_time[id][1]);
	query = SQL_PrepareQuery( g_DBConn, szQuery );

	if ( !SQL_Execute( query ) )
	{
		client_print( id, print_chat, "Error, unable to save your gold, please contact a server administrator" );

		MYSQLX_Error( query, szQuery, 5 );

		return;
	}
	format( szQuery, 511, "REPLACE INTO `item` (`id`, `item`, `item_number`, `expire_time`) VALUES ('%d', '%d', '2', '%d');", iUniqueID, player_artifact[id][1], player_artifact_time[id][2]);
	query = SQL_PrepareQuery( g_DBConn, szQuery );

	if ( !SQL_Execute( query ) )
	{
		client_print( id, print_chat, "Error, unable to save your gold, please contact a server administrator" );

		MYSQLX_Error( query, szQuery, 5 );

		return;
	}
	format( szQuery, 511, "REPLACE INTO `item` (`id`, `item`, `item_number`, `expire_time`) VALUES ('%d', '%d', '3', '%d');", iUniqueID, player_artifact[id][1], player_artifact_time[id][3]);
	query = SQL_PrepareQuery( g_DBConn, szQuery );

	if ( !SQL_Execute( query ) )
	{
		client_print( id, print_chat, "Error, unable to save your gold, please contact a server administrator" );

		MYSQLX_Error( query, szQuery, 5 );

		return;
	}
	
	return;
}

public MYSQLX_Save_T( id )
{
	// Make sure our connection is working
	if ( !MYSQLX_Connection_Available() )
	{
		return;
	}

	new iUniqueID = DB_GetUniqueID( id );

	// Error checking when saving
	if ( iUniqueID <= 0 )
	{
		new szName[128];
		get_user_name( id, szName, 127 );

		D2_Log( true, "Unable to save XP for user '%s', unique ID: %d", szName, iUniqueID );

		return;
	}
	
	new szQuery[512];

	// Save the user's XP!
	if ( player_xp[id] > 0 && player_class[id] != 0 )
	{
		if ( player_xp[id] > 0 && player_class[id] != 0)
		{
			format( szQuery, 511, "REPLACE INTO `class` ( `id` , `class` , `xp` ) VALUES ( '%d', '%d', '%d');", iUniqueID, player_class[id], player_xp[id] );
			SQL_ThreadQuery( g_DBTuple, "_MYSQLX_Save_T", szQuery );
		}
	}

	// Only save skill levels if the user does NOT play chameleon
	// Then we need to save this!
	if ( player_xp[id] > 0)
	{
		format( szQuery, 511, "REPLACE INTO `skill` (`id`, `class`, `str`, `agi_dmg`, `int`, `dex_dmg`) VALUES ('%d', '%d', '%d', '%d', '%d', '%d');", iUniqueID, player_class[id], player_strength[id], player_agility[id], player_intelligence[id], player_dextery[id] );
		SQL_ThreadQuery( g_DBTuple, "_MYSQLX_Save_T", szQuery );
	}
	
	if( (player_TotalLVL[id] > 0) || (mana_gracza[id] > 0) )
	{
		format( szQuery, 511, "REPLACE INTO `extra` (`id`, `gold`, `total_lvl`) VALUES ('%d', '%d', '%d');", iUniqueID, mana_gracza[id], player_TotalLVL[id]);
		SQL_ThreadQuery( g_DBTuple, "_MYSQLX_Save_T", szQuery );
	}
	
	return;
}

public _MYSQLX_Save_T( failstate, Handle:query, error[], errnum, data[], size )
{

	// Error during the query
	if ( failstate )
	{
		new szQuery[256];
		SQL_GetQueryString( query, szQuery, 255 );
		
		MYSQLX_ThreadError( query, szQuery, error, errnum, failstate, 1 );
	}
}

public MYSQLX_SetDataForRace( id )
{
	// Make sure our connection is working
	if ( !MYSQLX_Connection_Available() )
	{
		return;
	}

	new iUniqueID = DB_GetUniqueID( id );
	
	new szQuery[256];
	format( szQuery, 255, "SELECT `str`, `agi_dmg`, `int` ,`dex_dmg` FROM `skill` WHERE `id` = '%d' AND `class` = '%d';", iUniqueID, player_class[id] );
	new Handle:query = SQL_PrepareQuery( g_DBConn, szQuery );
	
	if ( !SQL_Execute( query ) )
	{
		MYSQLX_Error( query, szQuery, 2 );

		return;
	}

	if ( SQL_NumResults( query ) == 0 )
	{
	
	}
	else
	{
		player_strength[id] = SQL_ReadResult( query, 0 );
		player_agility[id] = SQL_ReadResult( query, 1 );
		player_intelligence[id] = SQL_ReadResult( query, 2 );
		player_dextery[id] = SQL_ReadResult( query, 3 );
	}
	
	// While we have a result!
	/*while ( SQL_MoreResults( query ) )
	{
		player_strength[id] = SQL_ReadResult( query, 0 );
		player_agility_best[id] = SQL_ReadResult( query, 1 );
		player_agility[id] = SQL_ReadResult( query, 2 );
		player_stamina[id] = SQL_ReadResult( query, 3 );
		player_vitality[id] = SQL_ReadResult( query, 4 );
		player_intelligence[id] = SQL_ReadResult( query, 5 );
		player_dextery[id] = SQL_ReadResult( query, 6 );
		D2_Log( true, "Set data for race", szName, iUniqueID );
		
		player_point[id]=(player_lvl[id]-1)*2-player_intelligence[id]-player_strength[id]-player_dextery[id]-player_agility[id]	
		if(player_point[id]<0) 
		{
			player_point[id]=0
			player_damreduction[id] = (47.3057*(1.0-floatpower( 2.7182, -0.06798*float(player_agility[id])))/100)
		}
	}*/
	
	// Free the handle
	SQL_FreeHandle( query );
	player_lvl[id] = player_class_lvl[id][player_class[id]];
	player_xp[id] = player_class_xp[id][player_class[id]];
	player_point[id]=(player_lvl[id]-1)*2-player_intelligence[id]-player_strength[id]-player_dextery[id]-player_agility[id]	
	if(player_point[id]==0) 
	{
		player_point[id]=0
		player_damreduction[id] = (47.3057*(1.0-floatpower( 2.7182, -0.06798*float(player_agility[id])))/100)
	}
	else
	{
		if(player_point[id]<0)
		{
			player_point[id] = player_lvl[id]*2-2
			player_intelligence[id] = 0
			player_strength[id] = 0 
			player_agility[id] = 0
			player_dextery[id] = 0
		}
		skilltree(id)
	}

	// This user's XP has been set + retrieved! We can save now
	//bDBXPRetrieved[id] = true;


	return;
}

public DB_SaveAll(thread)
{

	new players[32], numofplayers, i;
	get_players( players, numofplayers );
	
	if(numofplayers != 0)
	{
		for ( i = 0; i < numofplayers; i++ )
		{
			if(thread == 1)
			{
				if (player_class[players[i]] != 0)
				{
					MYSQLX_Save_T( players[i] );
				}
			}
			else if(thread == 2)
			{
				if (player_class[players[i]] != 0)
				{
					MYSQLX_Save( players[i] );
				}
			}
		}
	}

	return;
}

public SHARED_IsOnTeam( id )
{
	new iTeam = get_user_team( id );
	if ( iTeam == 1 || iTeam == 2 )
	{
		return true;
	}

	return false;
}

// Function will grab XP for the user
public D2_ChangeRaceStart( id )
{
	
	// Make sure the user is on a team!
	if ( SHARED_IsOnTeam( id ) )
	{
			// This function will also display the changerace menu
			loaded_xp[id] = 1;
			MYSQLX_GetAllXP( id );
	}
	else
	{
		client_print( id, print_center, "Пожалуйста выйдите из спектатора!" );
	}
}

/*

public create_klass(id)
{
	if(g_boolsqlOK)
	{	
		if(!is_user_bot(id) && database_user_created[id]==0)
		{
			new name[64]
			new ip[64]
			new sid[64]
			
			get_user_name(id,name,63)
			replace_all ( name, 63, "'", "Q" )
			replace_all ( name, 63, "`", "Q" )
			
			get_user_ip ( id, ip, 63, 1 )
			get_user_authid(id, sid ,63)
			
			for(new i=1;i<28;i++)
			{
				new q_command[512]
				format(q_command,511,"INSERT INTO `%s` (`nick`,`ip`,`sid`,`class`,`lvl`,`exp`) VALUES ('%s','%s','%s',%i,%i,%i ) ",g_sqlTable,name,ip,sid,i,srv_avg[i],LevelXP[srv_avg[i]-1])
				SQL_ThreadQuery(g_SqlTuple,"create_klass_Handle",q_command)
			}
			database_user_created[id]=1
		}
	}
	else sql_start()
}

public create_klass2(id)
{
	if(g_boolsqlOK)
	{	
		if(!is_user_bot(id) && database_user_created[id]==0)
		{
			new name[64]
			new ip[64]
			new sid[64]
			
			get_user_name(id,name,63)
			replace_all ( name, 63, "'", "Q" )
			replace_all ( name, 63, "`", "Q" )
			
			get_user_ip ( id, ip, 63, 1 )
			get_user_authid(id, sid ,63)
			
			for(new i=9;i<28;i++)
			{
				new q_command[512]
				format(q_command,511,"INSERT INTO `%s` (`nick`,`ip`,`sid`,`class`,`lvl`,`exp`) VALUES ('%s','%s','%s',%i,%i,%i ) ",g_sqlTable,name,ip,sid,i,srv_avg[i],LevelXP[srv_avg[i]-1])
				SQL_ThreadQuery(g_SqlTuple,"create_klass_Handle2",q_command)
			}
			database_user_created[id]=1
		}
	}
	else sql_start()
}

public create_klass_Handle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	// lots of error checking
	if(Errcode)
	{
		D2_Log( true, "Error on create class query: %s",Error)
		
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "create class Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	
	   
	return PLUGIN_CONTINUE
}

public create_klass_Handle2(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	// lots of error checking
	if(Errcode)
	{
		D2_Log( true, "Error on create class query: %s",Error)
		
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "create class Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	
	   
	return PLUGIN_CONTINUE
}

public load_xp(id)
{
	if(g_boolsqlOK)
	{
		if(!is_user_bot(id))
		{
			new name[64]
			new data[1]
			data[0]=id
			
			if(get_cvar_num("diablo_sql_save")==0)
			{
				get_user_name(id,name,63)
				replace_all ( name, 63, "'", "Q" )
				replace_all ( name, 63, "`", "Q" )
				
				new q_command[512]
				format(q_command,511,"SELECT `class` FROM `%s` WHERE `nick`='%s' ",g_sqlTable,name)
				SQL_ThreadQuery(g_SqlTuple,"SelectHandle",q_command,data,1)
				format(q_command,511,"SELECT * FROM `%s` WHERE `nick` LIKE '%s' AND `class` =9",g_sqlTable,name)
				SQL_ThreadQuery(g_SqlTuple,"SelectHandle2",q_command,data,1)
			}
			else if(get_cvar_num("diablo_sql_save")==1)
			{
				get_user_ip(id, name ,63,1)
				new q_command[512]
				format(q_command,511,"SELECT `class` FROM `%s` WHERE `ip`='%s' ",g_sqlTable,name)
				SQL_ThreadQuery(g_SqlTuple,"SelectHandle",q_command,data,1)
			}
			else if(get_cvar_num("diablo_sql_save")==2)
			{
				get_user_authid(id, name ,63)
				new q_command[512]
				format(q_command,511,"SELECT `class` FROM `%s` WHERE `sid`='%s' ",g_sqlTable,name)
				SQL_ThreadQuery(g_SqlTuple,"SelectHandle",q_command,data,1)
			}
			loaded_xp[id]=1
		}
	}
	else sql_start()
}

public SelectHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(Errcode)
	{
		D2_Log( true, "Error on load_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "load_xp Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	
	if(SQL_MoreResults(Query)) return PLUGIN_CONTINUE
	else create_klass(Data[0])		
   
	return PLUGIN_CONTINUE
}

public SelectHandle2(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(Errcode)
	{
		D2_Log( true, "Error on load_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "load_xp Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	
	if(SQL_MoreResults(Query)) return PLUGIN_CONTINUE
	else create_klass2(Data[0])		
   
	return PLUGIN_CONTINUE
}

//sql// */

public Health(id) 
{ 
	if(get_cvar_num("diablo_show_health")==1)
	{
		new health = read_data(1) 
		if(health>255)
		{
			message_begin( MSG_ONE, gmsgHealth, {0,0,0}, id ) 
			write_byte( 255 ) 
			message_end() 
		} 
	}
}

public speed(id)
{
	new Float:spd = get_user_maxspeed(id)
	client_print(id,print_chat,"Макс: %f",spd)
	
	new Float:vect[3]
	entity_get_vector(id,EV_VEC_velocity,vect)
	new Float: sped= floatsqroot(vect[0]*vect[0]+vect[1]*vect[1]+vect[2]*vect[2])
	
	client_print(id,print_chat,"Сейчас: %f",sped)
}

public plugin_precache()
{ 
	precache_model("models/rpgrocket.mdl")
	precache_model("models/bag.mdl")
	precache_model(modelitem)
	precache_model("models/zombie.mdl")
	precache_model("addons/amxmodx/diablo/mine.mdl")
	precache_model("addons/amxmodx/diablo/totem_ignite.mdl")
	precache_model("addons/amxmodx/diablo/totem_heal.mdl")
	precache_model("models/player/arctic/arctic.mdl")
	precache_model("models/player/leet/leet.mdl")
	precache_model("models/player/guerilla/guerilla.mdl")
	precache_model("models/player/terror/terror.mdl")
	precache_model("models/player/urban/urban.mdl")
	precache_model("models/player/sas/sas.mdl")
	precache_model("models/player/gsg9/gsg9.mdl")
	precache_model("models/player/gign/gign.mdl")
	precache_model(SWORD_VIEW)     
	precache_model(SWORD_PLAYER)
	precache_model(KNIFE_VIEW)     
	precache_model(KNIFE_PLAYER)
	precache_model(C4_VIEW)     
	precache_model(C4_PLAYER)
	precache_model(HE_VIEW)     
	precache_model(HE_PLAYER)
	precache_model(FL_VIEW)     
	precache_model(FL_PLAYER)
	precache_model(SE_VIEW)     
	precache_model(SE_PLAYER)
	precache_model(SE_MODEL)
	precache_model(scythe_view)
	precache_model(infidel_view)
	precache_model(infidel_model)
	precache_model(mosquito_model)
	precache_model(SABRECAT_VIEW)
	precache_model(SABRECAT_PLAYER)
	precache_model(SABRECAT_MODEL)
	precache_sound("weapons/xbow_hit2.wav")
	precache_sound("weapons/xbow_fire1.wav")
	sprite_blood_drop = precache_model("sprites/blood.spr")
	sprite_blood_spray = precache_model("sprites/bloodspray.spr")
	sprite_ignite = precache_model("addons/amxmodx/diablo/flame.spr")
	sprite_flame = precache_model("sprites/flame.spr")
	sprite_smoke = precache_model("sprites/steam1.spr")
	sprite_laser = precache_model("sprites/laserbeam.spr")
	sprite_boom = precache_model("sprites/zerogxplode.spr") 
	sprite_line = precache_model("sprites/dot.spr")
	sprite_lgt = precache_model("sprites/lgtning.spr")
	sprite_white = precache_model("sprites/white.spr") 
	sprite_fire = precache_model("sprites/explode1.spr")	
	sprite_gibs = precache_model("models/hgibs.mdl")
	
	//Diablo napalm
	for (new i = 0; i < sizeof grenade_fire_player; i++)
		precache_sound(grenade_fire_player[i])
		
	coldGibs = precache_model("models/diablomod/cold.mdl")
	precache_model("sprites/diablo_lp/xcold.spr")
	precache_model("sprites/zbeam4.spr") 
	g_shock = precache_model("sprites/shockwave.spr")
	sprite = precache_model("sprites/lgtning.spr");
	diablolght = precache_model("sprites/diablo_lp/diablo_lght.spr");
	precache_model("sprites/xfireball3.spr")
	precache_model("sprites/diablo_lp/bone1.spr")
	precache_model("models/portal/portal.mdl")
	precache_model("sprites/diablo_lp/portal_tt.spr")
	precache_model("sprites/diablo_lp/portal_ct.spr")
	precache_model("sprites/diablo_lp/cold_expo.spr")
	precache_model("sprites/diablo_lp/firewall.spr")
	sprite_bloodraven = precache_model("sprites/diablo_lp/blood_dead2.spr")
	g_smokeSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_smoke)
		
	precache_sound(SOUND_START)
	precache_sound(SOUND_FINISHED)
	precache_sound(SOUND_FAILED)
	precache_sound(SOUND_EQUIP)

	precache_sound("weapons/knife_hitwall1.wav")
	precache_sound("weapons/knife_hit4.wav")
	precache_sound("weapons/knife_deploy1.wav")
	precache_sound(gszSound);
	precache_sound("diablo_lp/fallen_1.wav");
	precache_sound("diablo_lp/fallen_2.wav");
	precache_sound("diablo_lp/levelup.wav");
	precache_sound("diablo_lp/questdone.wav");
	precache_sound("diablo_lp/identify.wav");
	precache_sound("diablo_lp/itembroken.wav");
	precache_sound("diablo_lp/repair.wav");
	precache_sound("diablo_lp/flippy.wav");
	precache_sound("diablo_lp/ring.wav");
	precache_sound("diablo_lp/diablo_1.wav");
	precache_sound("diablo_lp/firelaunch2.wav");
	precache_sound("diablo_lp/fireball3.wav");
	precache_sound("diablo_lp/fallen_hit1.wav");
	precache_sound("diablo_lp/fallen_hit2.wav");
	precache_sound("diablo_lp/fallen_hit3.wav");
	precache_sound("diablo_lp/fallen_hit6.wav");
	precache_sound("diablo_lp/fallen_hit7.wav");
	precache_sound("diablo_lp/fallen_roar2.wav");
	precache_sound("diablo_lp/fallen_roar3.wav");
	precache_sound("diablo_lp/fallen_roar6.wav");
	precache_sound("diablo_lp/fallens_gethit1.wav");
	precache_sound("diablo_lp/fallens_gethit2.wav");
	precache_sound("diablo_lp/fallens_gethit3.wav");
	precache_sound("diablo_lp/fallens_gethit4.wav");
	precache_sound("diablo_lp/resurrect.wav");
	precache_sound("diablo_lp/resurrectcast.wav");
	precache_sound("diablo_lp/fallens_neutral1.wav");
	precache_sound("diablo_lp/fallens_neutral2.wav");
	precache_sound("diablo_lp/fallens_neutral3.wav");
	precache_sound("diablo_lp/fallens_neutral4.wav");
	precache_sound("diablo_lp/fallen_neutral1.wav");
	precache_sound("diablo_lp/fallen_neutral2.wav");
	precache_sound("diablo_lp/fallen_neutral3.wav");
	precache_sound("diablo_lp/fallen_neutral4.wav");
	precache_sound("diablo_lp/fallen_neutral5.wav");
	precache_sound("diablo_lp/zakarum_neutral1.wav");
	precache_sound("diablo_lp/zakarum_neutral2.wav");
	precache_sound("diablo_lp/zakarum_neutral3.wav");
	precache_sound("diablo_lp/zakarum_neutral4.wav");
	precache_sound("weapons/explode3.wav");
	precache_sound("diablo_lp/portalcast.wav");
	precache_sound("diablo_lp/portalenter.wav");
	precache_sound("diablo_lp/teleport.wav");
	precache_sound("diablo_lp/zakarum_death1.wav");
	precache_sound("diablo_lp/frozne_blast.wav");
	precache_sound("diablo_lp/poison.wav");
	precache_model("models/diablomod/w_throwingknife.mdl")
	precache_model("models/diablomod/bm_block_platform.mdl")
	sprite_sabrecat = precache_model( "sprites/gas_puff_01g.spr" ); // SabreCat
	precache_sound( "weapons/hegrenade-1.wav" ); // SabreCat
	precache_sound( "weapons/grenade_hit1.wav" ); // SabreCat
	precache_sound( "diablo_lp/bow2.wav" ); // Bows
	precache_sound( "diablo_lp/bloodraventaunt1.wav" );
	precache_sound( "diablo_lp/brdeath.wav" );
	precache_sound( "diablo_lp/bonecast.wav" );
	precache_sound( "diablo_lp/bonespear1.wav" );
	precache_sound( "diablo_lp/fwall2.wav" );
	precache_sound( "diablo_lp/izual_ring2.wav" );
	precache_sound("ambience/flameburst1.wav")
	
	precache_model(cbow_VIEW)
    precache_model(cvow_PLAYER)
	precache_model(cbow_bolt)
	precache_model(bloodbow_VIEW)
    precache_model(bloodbow_PLAYER)
	// Hook Model
	engfunc(EngFunc_PrecacheModel, "models/rpgrocket.mdl")
	
	// Hook Beam
	sprBeam = engfunc(EngFunc_PrecacheModel, "sprites/zbeam4.spr")
	
	// Hook Sounds
	engfunc(EngFunc_PrecacheSound, "weapons/xbow_hit1.wav") // good hit
	engfunc(EngFunc_PrecacheSound, "weapons/xbow_hit2.wav") // wrong hit
	
	engfunc(EngFunc_PrecacheSound, "weapons/xbow_hitbod1.wav") // player hit
	
	engfunc(EngFunc_PrecacheSound, "weapons/xbow_fire1.wav") // deploy
}

public plugin_cfg() {
	
	server_cmd("sv_maxspeed 1500")
	
}

public plugin_natives()
{
	register_native("db_get_user_xp", "native_get_user_xp", 1)
	register_native("db_set_user_xp", "native_set_user_xp", 1)
	register_native("db_get_user_level", "native_get_user_level", 1)
	register_native("db_set_user_level", "native_set_user_level", 1)
	register_native("db_get_user_class", "native_get_user_class", 1)
	register_native("db_set_user_class", "native_set_user_class", 1)
	register_native("db_get_user_item", "native_get_user_item", 1)
	register_native("db_set_user_item", "native_set_user_item", 1)
	register_library("cs_player_models_api")
	register_native("cs2_set_player_model", "native_set_player_model")
	register_native("cs2_reset_player_model", "native_reset_player_model")
}

/*public savexpcom(id)
{
	if(get_cvar_num("SaveXP") == 1 && player_class[id]!=0 && player_class_lvl[id][player_class[id]]==player_lvl[id] ) 
	{
		SubtractStats(id,player_b_extrastats[id])
		SubtractRing(id)
		SaveXP(id)
		BoostStats(id,player_b_extrastats[id])
		BoostRing(id)
	}
}

public SaveXP(id)
{
	if(g_boolsqlOK)
	{
		if(!is_user_bot(id) && player_xp[id]!=player_xp_old[id])
		{
			new name[64]
			new ip[64]
			new sid[64]
			
			get_user_name(id,name,63)
			replace_all ( name, 63, "'", "Q" )
			replace_all ( name, 63, "`", "Q" )
			
			get_user_ip(id, ip ,63,1)
			get_user_authid(id, sid ,63)
			
			if(get_cvar_num("diablo_sql_save")==0)
			{
				new q_command[512]
				format(q_command,511,"UPDATE `%s` SET `ip`='%s',`sid`='%s',`lvl`='%i',`exp`='%i',`str`='%i',`int`='%i',`dex`='%i',`agi`='%i',`man`='%i' WHERE `nick`='%s' AND `class`='%i' ",g_sqlTable,ip,sid,player_lvl[id],player_xp[id],player_strength[id],player_intelligence[id],player_dextery[id],player_agility[id],mana_gracza[id],name,player_class[id])
				
				SQL_ThreadQuery(g_SqlTuple,"Save_xp_handle",q_command)
			}
			else if(get_cvar_num("diablo_sql_save")==1)
			{
				new q_command[512]
				format(q_command,511,"UPDATE `%s` SET `nick`='%s',`sid`='%s',`lvl`='%i',`exp`='%i',`str`='%i',`int`='%i',`dex`='%i',`agi`='%i',`man`='%i' WHERE `ip`='%s' AND `class`='%i' ",g_sqlTable,name,sid,player_lvl[id],player_xp[id],player_strength[id],player_intelligence[id],player_dextery[id],player_agility[id],mana_gracza[id],ip,player_class[id])
				
				SQL_ThreadQuery(g_SqlTuple,"Save_xp_handle",q_command)
			}
			else if(get_cvar_num("diablo_sql_save")==2)
			{
				new q_command[512]
				format(q_command,511,"UPDATE `%s` SET `nick`='%s',`ip`='%s',`lvl`='%i',`exp`='%i',`str`='%i',`int`='%i',`dex`='%i',`agi`='%i',`man`='%i' WHERE `sid`='%s' AND `class`='%i' ",g_sqlTable,name,ip,player_lvl[id],player_xp[id],player_strength[id],player_intelligence[id],player_dextery[id],player_agility[id],mana_gracza[id],sid,player_class[id])
				
				SQL_ThreadQuery(g_SqlTuple,"Save_xp_handle",q_command)
			}
			player_xp_old[id]=player_xp[id]
				
		}
	}
	else sql_start()
	
	return PLUGIN_HANDLED
} 

public Save_xp_handle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(Errcode)
	{
		D2_Log( true, "Error on Save_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "Save_xp Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	
	return PLUGIN_CONTINUE
}

public LoadXP(id, class){
	
	if(is_user_bot(id) || asked_sql[id]==1) return PLUGIN_HANDLED
	
	if(player_class[id]==0)load_xp(id)
	
	if(g_boolsqlOK )
	{
			
		new name[64]
		new data[2]
		data[0]=id
		data[1]=class
		
		if(get_cvar_num("diablo_sql_save")==0)
		{
			get_user_name(id,name,63)
			replace_all ( name, 63, "'", "Q" )
			replace_all ( name, 63, "`", "Q" )
			
			new q_command[512]
			format(q_command,511,"SELECT * FROM `%s` WHERE `nick`='%s' AND `class`='%i'", g_sqlTable, name, player_class[id])
			
			SQL_ThreadQuery(g_SqlTuple,"Load_xp_handle",q_command,data,2)
			asked_sql[id]=1
		}
		else if(get_cvar_num("diablo_sql_save")==1)
		{
			get_user_ip(id, name ,63,1)
			new q_command[512]
			format(q_command,511,"SELECT * FROM `%s` WHERE `ip`='%s' AND `class`='%i'", g_sqlTable, name, player_class[id])  
			
			SQL_ThreadQuery(g_SqlTuple,"Load_xp_handle",q_command,data,2)
			asked_sql[id]=1
		}
		else if(get_cvar_num("diablo_sql_save")==2)
		{
			get_user_authid(id, name ,63)
			new q_command[512]
			format(q_command,511,"SELECT * FROM `%s` WHERE `sid`='%s' AND `class`='%i'", g_sqlTable, name, player_class[id])  
			
			SQL_ThreadQuery(g_SqlTuple,"Load_xp_handle",q_command,data,2)
			asked_sql[id]=1
		}
	}
	else sql_start()
	return PLUGIN_HANDLED
}

public Load_xp_handle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	new id = Data[0]
	asked_sql[id]=0
	
	if(Errcode)
	{
		D2_Log( true, "Error on Load_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "Load_xp Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	if(SQL_MoreResults(Query))
	{
		
		player_class[id] = Data[1]
		player_lvl[id] = SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"lvl"))	
		player_xp[id] =	SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"exp"))	
		player_xp_old[id] = SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"exp"))
		
		player_intelligence[id] = SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"int"))
		player_strength[id] = SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"str")) 
		player_agility[id] = SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"agi")) 
		mana_gracza[id] = SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"man"))
		player_dextery[id] = SQL_ReadResult(Query,SQL_FieldNameToNum(Query,"dex")) 
		
		player_point[id]=(player_lvl[id]-1)*2-player_intelligence[id]-player_strength[id]-player_dextery[id]-player_agility[id]	
		if(player_point[id]<0) player_point[id]=0
		player_damreduction[id] = (47.3057*(1.0-floatpower( 2.7182, -0.06798*float(player_agility[id])))/100)		
	}
	return PLUGIN_CONTINUE
}*/

public LoadPremium(id){
	
	if(player_premium[id]==1) return PLUGIN_HANDLED
	
	if(g_boolsqlOK )
	{
			
		new name[64]
		new data[2]
		data[0]=id
		get_user_name(id,name,63)
		replace_all ( name, 63, "'", "Q" )
		replace_all ( name, 63, "`", "Q" )
			
		new q_command[512]
		format(q_command,511,"SELECT *  FROM `premium` WHERE `nick` LIKE '%s'", name)
			
		SQL_ThreadQuery(g_SqlTuple,"Load_premium_handle",q_command,data,2)
	}
	else sql_start()
	return PLUGIN_HANDLED
}

public Load_premium_handle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	new id = Data[0]
	
	if(Errcode)
	{
		D2_Log( true, "Error on Load_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "Load_xp Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	if(SQL_MoreResults(Query))
	{
		player_premium[id] = 1
	}
	return PLUGIN_CONTINUE
}

public LoadAVG()
{
	if(g_boolsqlOK)
	{
		new data[2]
		data[0]= get_cvar_num("diablo_avg")
		
		if(data[0])
		{
			for(new i=1;i<28;i++)
			{
				new q_command[512]
				data[1]=i
				//format(q_command,511,"SELECT AVG(`lvl`) FROM `%s` WHERE `lvl` > '%d' AND `class`='%d'", g_sqlTable, data[0]-1,i)
				format(q_command,511,"SELECT `class`,AVG(`lvl`) AS `AVG` FROM `%s` WHERE `lvl` > '%d' GROUP BY `class`", g_sqlTable, data[0]-1)
				SQL_ThreadQuery(g_SqlTuple,"Load_AVG_handle",q_command,data,2)
				
			}
		
		}
	}
	else sql_start()
	return PLUGIN_HANDLED
} 

public Load_AVG_handle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	if(Errcode)
	{
		D2_Log( true, "Error on Load_AVG query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "Load_AVG Query failed.")
		return PLUGIN_CONTINUE
	}
	/*   
	if(SQL_MoreResults(Query))
	{
		new Float: avg
		SQL_ReadResult(Query, 0, avg)
		srv_avg[Data[1]]=floatround(avg)
		//client_print(0,print_chat,"srednia: %f",srv_avg)
	}*/
	
	while(SQL_MoreResults(Query))
	{
		new i = SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "class"))
		srv_avg[i] = SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "AVG"))
		SQL_NextRow(Query)
	}
	if(olny_one_time==0)
	{
		olny_one_time=1
		look_for_none()
	}
	return PLUGIN_CONTINUE
}

public look_for_none()
{
	for(new i=1;i<33;i++)
	{
		if(is_user_alive(i))
		{
			if(player_class[i]==0)
			{
				MYSQLX_GetAllXP( i )
			}
		}
	}
}

public reset_skill(id)
{	
	client_print(id,print_chat,"Сброс навыков")
	player_point[id] = (player_lvl[id]-1)*2
	player_intelligence[id] = 0
	player_strength[id] = 0 
	player_agility[id] = 0
	player_dextery[id] = 0 
	BoostRing(id)
	BoostStats(id,player_b_extrastats[id])
	
	skilltree(id)
	set_speedchange(id)
	player_damreduction[id] = (47.3057*(1.0-floatpower( 2.7182, -0.06798*float(player_agility[id])))/100)
}


public freeze_over()
{
	//new Float: timea
	//timea=get_cvar_float("diablo_klass_delay")
	set_task(get_cvar_float("diablo_klass_delay"), "freezeover", 3659, "", 0, "")
}

public freezeover()
{
	freeze_ended = true
}

public freeze_begin()
{
	freeze_ended = false
}

public on_EndRound()
{
	// Threaded saves on end round!
	DB_SaveAll(2);
	
	return;
}

public RoundStart(){
	// Everu round we refresh this time, used for detecting if the buytime has passed
	gF_starttime = get_gametime()
	kill_all_entity("przedmiot")
	kill_all_entity("saber_smoke3")
	kill_all_entity("spidertrap")
	kill_all_entity("baalcopy")
	kill_all_entity("baalcopyweap")
	fallens_tt=0
	fallens_ct=0
	for (new i=0; i < 33; i++){
		if(player_portals[i] > 0)
		{
			if(get_user_team(i) == 1)
			{
				if(player_portal_sprite_1[i] > 0)
				{
					engfunc(EngFunc_SetModel, player_portal_sprite_1[i], "sprites/diablo_lp/portal_tt.spr")
				}
				if(player_portal_sprite_2[i] > 0)
				{
					engfunc(EngFunc_SetModel, player_portal_sprite_2[i], "sprites/diablo_lp/portal_tt.spr")
				}
			}
			else if(get_user_team(i) == 2)
			{
				if(player_portal_sprite_1[i] > 0)
				{
					engfunc(EngFunc_SetModel, player_portal_sprite_1[i], "sprites/diablo_lp/portal_ct.spr")
				}
				if(player_portal_sprite_2[i] > 0)
				{
					engfunc(EngFunc_SetModel, player_portal_sprite_2[i], "sprites/diablo_lp/portal_ct.spr")
				}
			}
		}
		
		if(player_class[i] == Frozen)
		{
			c_silent[i] = 0
		}
		else
		{
			zmiana_skinu[i] = 0
		}
		
		used_item[i] = false
		naswietlony[i] = 0;
		losowe_itemy[i] = 0
		fire_bows[i] = 0
		uzyl_przedmiot[i] = 0
		DemageTake1[i]=1
		count_jumps(i)
		give_knife(i)
		JumpsLeft[i]=JumpsMax[i]
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
        write_byte(TE_KILLBEAM);
        write_short(i);
        message_end();
		is_frozen[i] = 0
		is_poisoned[i] = 0
		is_touched[i] = 0
		hit_key[i] = false
		use_fly[i] = false
		
		player_fallen_tr[i]=1;
		//play idle
		remove_task(i+2000)
		//baal
		remove_task(i+TASK_REMOVE_BAAL)
		baal_copyed[i] = 0
		
		if(player_class[i] == Necromancer)
		{
			g_haskit[i]=1
		}
		else 
		{	
			g_haskit[i]=0
		}
		if(player_class[i] == Monk)
		{
			monk_maxenergy[i] = player_intelligence[i]*2
			monk_energy[i]=monk_maxenergy[i]
		}
		if(player_class[i] == Viper)
		{
			new Float:gas = player_intelligence[i]/10.0;
			if(gas < 1.0)
			{
				gas = 1.0
			}
			viper_gases[i] = floatround(gas,floatround_round);
		}
		if(player_class[i] == Duriel)
		{
			duriel_boost[i] = 0
		}
		if(player_class[i] == Baal)
		{
			c_blink[i]=floatround(halflife_time())
		}
		if(player_class[i] == Mosquito)
		{
			mosquito_sting[i] = 0
			entity_set_string(i, EV_SZ_weaponmodel, "")
		}
		if(player_class[i] == SabreCat)
		{
			fm_give_item(i, "weapon_smokegrenade")
		}
		if(player_class[i] == Zakarum)
		{
			new Float:random_time = random_float(15.0, 20.0);
			set_task(random_time, "play_idle", i+2000, _, _, "b")
			ilosc_blyskawic[i] = floatround(player_intelligence[i]/5.0)
		}
		if(player_class[i] == GiantSpider)
		{
			spider_traps[i] = 0
		}
		if(player_class[i] == Imp)
		{
			if(floatround(player_intelligence[i]/2.5) < 10)
			{
				imp_fires[i] = 10
			}
			else
			{
				imp_fires[i] = floatround(player_lvl[i]/2.0);
			}
		}
		if(player_class[i] == Diablo)
		{
			if(player_intelligence[i] > 0)
			{
				diablo_lights[i] = 1
			}
			if(!g_bWeaponsDisabled)
			{
				if ( !user_has_weapon( i , CSW_HEGRENADE ) )
				{
					fm_give_item(i, "weapon_hegrenade")
				}
			}
			else
			{
				hudmsg(i,5.0,"На этой карте оружие не выдаётся!")
			}
		}
		if(player_class[i] == Izual)
		{
			izual_ring[i] = 1
			c_blink[i]=floatround(halflife_time())
		}
		//Fallen Code
		if(player_class[i] == Fallen)
		{
			if(get_user_team(i) == 1)
			{
				fallens_tt++
			}
			else if(get_user_team(i) == 2)
			{
				fallens_ct++
			}
		}
		if(player_class[i] == Fallen && player_lvl[i] > 49)
		{
			fallen_fires[i] = floatround(player_lvl[i]/5.0, floatround_floor);
			new Float:random_time = random_float(25.0, 35.0);
			set_task(random_time, "play_idle", i+2000, _, _, "b")
		}
		if(player_class[i] == Fallen && player_lvl[i] < 49)
		{
			new Float:random_time = random_float(10.0, 15.0);
			set_task(random_time, "play_idle", i+2000, _, _, "b")
		}
		if(player_class[i] == Frozen)
		{
			if(floatround(player_intelligence[i]/2.5) < 10)
			{
				frozen_colds[i] = 10
			}
			else
			{
				frozen_colds[i] = floatround(player_lvl[i]/2.0);
			}
		}
		if(player_class[i] == Infidel)
		{
			cs2_set_player_model(i, infidel_model_short);
		}
		else if(player_class[i] == Mosquito)
		{
			cs2_set_player_model(i, mosquito_model_short);
		}
		else
		{
			cs2_reset_player_model(i);
		}
		
		golden_bulet[i]=0
		c_ulecz[i] = false
		if(player_class[i] == Griswold) ilosc_rakiet_gracza[i]=2
		else if(player_class[i] == Demonolog) ilosc_rakiet_gracza[i]=3
		if(player_class[i] == TheSmith)
		{
			ilosc_blyskawic[i]=3;
			poprzednia_blyskawica[i]=get_gametime()
		}
		//else ilosc_rakiet_gracza[i]=0
		/*if(player_class[i] == Kernel) ilosc_dynamitow_gracza[i]=1
		else if(player_class[i] == SabreCat) ilosc_dynamitow_gracza[i]=1
		else if(player_class[i] == TheSmith) ilosc_dynamitow_gracza[i]=1*/
		//else ilosc_rakiet_gracza[i]=0
		
		
		invisible_cast[i]=0
		niewidka[i] = 0
		
		ultra_armor[i]=0
		lustrzany_pocisk[i]=0
		num_shild[i]=1+floatround(player_intelligence[i]/8.0,floatround_floor)
		
		set_renderchange(i)
		if(is_user_connected(i)&&player_item_id[i]==66)
		{
			changeskin(i,0) 
		}
	}
		
	kill_all_entity("throwing_knife")
	
	Bot_Setup()		
	ghost_check = false
	check_class()
	use_addtofullpack = false
}

#if defined CHEAT
public giveitem(id)
{
	award_item(id, 25)
	return PLUGIN_HANDLED
}

public benchmark(id)
{
	new Float:nowtime = halflife_time();
	new iterations = 10
	
	for (new i=0; i < iterations; i++)
	{
		UpdateHUD()
	}
	
	new Float:timespent = halflife_time()-nowtime
	
	client_print(id,print_chat,"Benchmark on: UpdateHUD() with %i iterations done in %f seconds",iterations,timespent)
}

#endif

/* BASIC FUNCTIONS ================================================================================ */
public csw_c44(id)
{
	client_cmd(id,"weapon_knife")
	engclient_cmd(id,"weapon_knife")
	on_knife[id]=1
}

public CurWeapon(id)
{
	after_bullet[id]=1
	
	new clip,ammo
	new weapon=get_user_weapon(id,clip,ammo)
	invisible_cast[id]=0
	niewidka[id] = 0
	
	if(weapon == CSW_KNIFE)
	{
		on_knife[id] = 1
		if(player_class[id] == TheSmith)
			niewidka[id] = 1
}
	else on_knife[id]=0
	
	if ((weapon != CSW_C4 ) && !on_knife[id] && ((player_class[id] == Ninja) || (player_class[id] == Infidel) || (player_class[id] == Mosquito)))
	{
		client_cmd(id,"weapon_knife")
		engclient_cmd(id,"weapon_knife")
		on_knife[id]=1
	}
	

	if (is_user_connected(id))
	{

		//if (player_item_id[id] == 17 || player_b_usingwind[id] == 1)// engclient_cmd(id,"weapon_knife") 	
				
		if(player_sword[id] == 1)
		{
			
			if(player_class[id] != Infidel)
			{
				if(on_knife[id]){
					entity_set_string(id, EV_SZ_viewmodel, SWORD_VIEW)  
					entity_set_string(id, EV_SZ_weaponmodel, SWORD_PLAYER)  
				}
			}
			if(weapon == CSW_C4){
				entity_set_string(id, EV_SZ_viewmodel, C4_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, C4_PLAYER)  
			}
			if(weapon == CSW_HEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, HE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, HE_PLAYER)  
			}
			if(weapon == CSW_FLASHBANG){
				entity_set_string(id, EV_SZ_viewmodel, FL_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, FL_PLAYER)  
			}
			if(weapon == CSW_SMOKEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, SE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, SE_PLAYER)  
			}			
		}
		if(player_sword[id] == 0)
		{	
			if(on_knife[id])
			{
				if(player_class[id] == Infidel)
				{
					entity_set_string(id, EV_SZ_viewmodel, infidel_view)  
					entity_set_string(id, EV_SZ_weaponmodel, KNIFE_PLAYER)  
				} 
				else
				{
					entity_set_string(id, EV_SZ_viewmodel, KNIFE_VIEW)  
					entity_set_string(id, EV_SZ_weaponmodel, KNIFE_PLAYER)  
				}
			}
			if(weapon == CSW_C4){
				entity_set_string(id, EV_SZ_viewmodel, C4_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, C4_PLAYER)  
			}
			if(weapon == CSW_HEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, HE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, HE_PLAYER)  
			}
			if(weapon == CSW_FLASHBANG){
				entity_set_string(id, EV_SZ_viewmodel, FL_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, FL_PLAYER)  
			}
			if(weapon == CSW_SMOKEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, SE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, SE_PLAYER)  
			}			
		}
		if(player_class[id] == Zakarum)
		{	
			if(on_knife[id]){
				entity_set_string(id, EV_SZ_viewmodel, scythe_view)  
				entity_set_string(id, EV_SZ_weaponmodel, KNIFE_PLAYER)  
			}
			if(weapon == CSW_C4){
				entity_set_string(id, EV_SZ_viewmodel, C4_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, C4_PLAYER)  
			}
			if(weapon == CSW_HEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, HE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, HE_PLAYER)  
			}
			if(weapon == CSW_FLASHBANG){
				entity_set_string(id, EV_SZ_viewmodel, FL_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, FL_PLAYER)  
			}
			if(weapon == CSW_SMOKEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, SE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, SE_PLAYER)  
			}			
		}
		if(player_class[id] == SabreCat)
		{
			
			if(on_knife[id]){
				entity_set_string(id, EV_SZ_viewmodel, KNIFE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, KNIFE_PLAYER)  
			}
			if(weapon == CSW_C4){
				entity_set_string(id, EV_SZ_viewmodel, C4_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, C4_PLAYER)  
			}
			if(weapon == CSW_HEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, HE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, HE_PLAYER)  
			}
			if(weapon == CSW_FLASHBANG){
				entity_set_string(id, EV_SZ_viewmodel, FL_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, FL_PLAYER)  
			}
			if(weapon == CSW_SMOKEGRENADE){
				entity_set_string(id, EV_SZ_viewmodel, SABRECAT_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, SABRECAT_PLAYER)  
			}				
		}
		
		if(bow[id]==1)
		{
			bow[id]=0
			message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
			write_byte( 0 ) 
			write_byte( 0 ) 
			message_end()
			
			if(on_knife[id])
			{
				entity_set_string(id, EV_SZ_viewmodel, KNIFE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, KNIFE_PLAYER)  
			}
		}
		
		if(player_class[id] == Mosquito)
		{
			entity_set_string(id, EV_SZ_weaponmodel, "")
		}
		
		set_gravitychange(id)
		set_speedchange(id)
		set_renderchange(id)
		
		if(player_class[id] == Necromancer) g_haskit[id] = true
		else g_haskit[id] = false
		
		write_hud(id)
	}
}


public ResetHUD(id)
{
	
	if (is_user_connected(id))
	{	
		remove_task(id+GLUTON)
		change_health(id,9999,0,"")
		
		
		
		if (c4fake[id] > 0)
		{
			remove_entity(c4fake[id])
			c4fake[id] = 0
		}
		SubtractStats(id,player_b_extrastats[id])
		SubtractRing(id)
		if ((player_intelligence[id]+player_strength[id]+player_agility[id]+player_dextery[id])>(player_lvl[id]*2)) reset_skill(id)
		
		BoostStats(id,player_b_extrastats[id])
		BoostRing(id)
		
		fired[id] = 0
		fired_viper[id] = 0
		
		player_ultra_armor_left[id]=player_ultra_armor[id]
		
		player_b_dagfired[id] = false
		ghoststate[id] = 0
		earthstomp[id] = 0
		
		if (player_b_blink[id] > 0)
			player_b_blink[id] = 1
		
		if (player_b_usingwind[id] > 0) 
		{
			player_b_usingwind[id] = 0
		}
		
		if (player_point[id] > 0 ) skilltree(id)
		if (player_class[id] == 0) MYSQLX_GetAllXP( id )
		
		add_bonus_gamble(id)				//MUST be first
		c4state[id] = 0
		client_cmd(id,"hud_centerid 0")  
		auto_help(id)
		add_money_bonus(id)
		set_gravitychange(id)
		add_redhealth_bonus(id)
		SelectBotRace(id)
		set_renderchange(id)
		if (gRestart[id])
		{
			gRestart[id] = false
			return
		}
		if (gUpdate[id])
		{
			gUpdate[id] = false
			return
		}
		if (gHooked[id])
		{
			remove_hook(id)
		}
		if (get_pcvar_num(pMaxHooks) > 0)
		{
			gHooksUsed[id] = 0
			statusMsg(0, "[Паутина] 0 из %d паутин использованно.", get_pcvar_num(pMaxHooks))
		}
	}
}

public DeathMsg(id)
{
	new weaponname[20]
	new kid = read_data(1)
	new vid = read_data(2)
	new headshot = read_data(3)
	read_data(4,weaponname,31)
		
	reset_player(vid)
	msg_bartime(id, 0)
	static Float:minsize[3]
	pev(vid, pev_mins, minsize)
	if(minsize[2] == -18.0)
	{
		g_wasducking[vid] = true
	}
	else
	{
		g_wasducking[vid] = false
	}
	
	set_task(0.5, "task_check_dead_flag", vid)

	flashbattery[vid] = MAX_FLASH;
	flashlight[vid] = 0;
	
	hit_key[vid] = false
	
	kill_all_traps(vid)
	
	if (use_fly[player])
	{
		use_fly[player] = false
		fm_set_user_gravity(player, 0.8)
	}
	
	if(player_sword[id] == 1)
	{
		if(on_knife[id])
		{
			if(get_user_team(kid) != get_user_team(vid)) 
			{
				set_user_frags(kid, get_user_frags(kid) + 1)
				if(headshot)
				{
					if((mana_gracza[kid]+1) < get_pcvar_num(cvar_max_gold))
					{
						mana_gracza[kid]+=1
					}
				}
				award_kill(kid,vid)
			}
		}
	}
	if(player_class[id] == Zakarum)
	{
		if(on_knife[id])
		{
			if(get_user_team(kid) != get_user_team(vid)) 
			{
				set_user_frags(kid, get_user_frags(kid) + 1)
				if(headshot)
				{
					if((mana_gracza[kid]+1) < get_pcvar_num(cvar_max_gold))
					{
						mana_gracza[kid]+=1
					}
				}
				award_kill(kid,vid)
			}
		}
	}
	if(player_class[vid] == BloodRaven)
	{
		static origin[3]
		get_user_origin(vid, origin)
		
		emit_sound(vid,CHAN_STATIC,"diablo_lp/brdeath.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
		write_byte(TE_SPRITE)
		write_coord(origin[0])
		write_coord(origin[1])
		write_coord(origin[2])
		write_short(sprite_bloodraven)
		write_byte(15)
		write_byte(255) //Brightness
		message_end()
		
		new players[32], numberofplayers;
		get_players( players, numberofplayers, "a" );
		
		new i, iTargetID, vTargetOrigin[3], iDistance, dmg;
		new iTeam = get_user_team( vid );
		
		new br_range = 330
		
		for ( i = 0; i < numberofplayers; i++ )
		{
		
			iTargetID = players[i];
			
			// Get origin of target
			get_user_origin( iTargetID, vTargetOrigin );

			// Get distance in b/t target and caster
			iDistance = get_distance( origin, vTargetOrigin );
			
			dmg = float((player_intelligence[vid] - player_dextery[iTargetID])/2);
			
			if ( iDistance < br_range && iTeam != get_user_team( iTargetID ) && dmg > 0)
			{
				puscBlyskawice(vid, iTargetID, dmg);
			}
		}
	}
	if (is_user_connected(kid) && is_user_connected(vid) && get_user_team(kid) != get_user_team(vid))
	{
		show_deadmessage(kid,vid,headshot,weaponname)
		create_itm(vid,0,"Случайный Item")
		award_kill(kid,vid)
		if(headshot)
		{
			if((mana_gracza[kid]+3) < get_pcvar_num(cvar_max_gold))
			{
				mana_gracza[kid]+=3
			}
		}
		else
		{
			if((mana_gracza[kid]+1) < get_pcvar_num(cvar_max_gold))
			{
				mana_gracza[kid]+=1
			}
		}
	
		add_respawn_bonus(vid)
		add_bonus_explode(vid)
		add_barbarian_bonus(kid)
		add_bonus_zakarum(vid)
		//mana_gracza[kid]+=1
		//mana_gracza[headshot]+=2
		if (player_class[kid] == Barbarian)
		refill_ammo(kid)
		if (player_class[kid] == Griswold)
		refill_ammo(kid)
		if (player_class[kid] == TheSmith)
		refill_ammo(kid)
		if (player_class[kid] == Demonolog)
		refill_ammo(kid)
		set_renderchange(kid)
		//savexpcom(vid)
		if(quest_gracza[kid] != -1)
		{
			if(player_class[vid] == questy[quest_gracza[kid]][2])
			{
				ile_juz[kid]++;
				zapisz_aktualny_quest(kid)
			}
			if(ile_juz[kid] == questy[quest_gracza[kid]][1])
			{
				client_print(kid,print_chat,"Выполнил задание %s полученно %i exp!",questy_info[quest_gracza[kid]],questy[quest_gracza[kid]][3])
				emit_sound(kid,CHAN_STATIC,"diablo_lp/questdone.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
				zapisz_questa(kid,quest_gracza[kid])
				Give_Xp(kid,questy[quest_gracza[kid]][3]);
				quest_gracza[kid] = -1;
				zapisz_aktualny_quest(kid)
			}
			else
			{
				client_print(kid,print_chat,"Убито %i/%i %s",ile_juz[kid],questy[quest_gracza[kid]][1],questy_zabil[quest_gracza[kid]])
			}
		}
	}
}

public Damage(id)
{
	if (is_user_connected(id))
	{
		new weapon
		new bodypart
		
		if((player_class[id] == GiantSpider) && (spider_hook_disabled[id] == 0))
		{
			spider_hook_disabled[id]=1
			del_hook(id)
			set_task(5.0, "enablehook", id)
		}
		if(get_user_attacker(id,weapon,bodypart)!=0)
		{
			new damage = read_data(2)
			new attacker_id = get_user_attacker(id,weapon,bodypart) 
			if (is_user_connected(attacker_id) && attacker_id != id)
			{
				if(get_user_team(id) != get_user_team(attacker_id))
				{
					dmg_exp(attacker_id, damage)
				}
				
				add_damage_bonus(id,damage,attacker_id)
				add_vampire_bonus(id,damage,attacker_id)
				add_grenade_bonus(id,attacker_id,weapon)
				add_theif_bonus(id,attacker_id)
				add_bonus_blind(id,attacker_id,weapon,damage)
				if(weapon != CSW_KNIFE) { add_bonus_redirect(id); }
				add_bonus_necromancer(attacker_id,id)
				add_bonus_scoutdamage(attacker_id,id,weapon)
				add_bonus_cawpmasterdamage(attacker_id,id,weapon)
				add_bonus_m4masterdamage(attacker_id,id,weapon)
				add_bonus_akmasterdamage(attacker_id,id,weapon)
				add_bonus_dglmasterdamage(attacker_id,id,weapon)
				add_bonus_m3masterdamage(attacker_id,id,weapon)
				add_bonus_awpmasterdamage(attacker_id,id,weapon)
				add_bonus_darksteel(attacker_id,id,damage)
				add_bonus_illusion(attacker_id,id,weapon)
				add_bonus_shake(attacker_id,id)
				add_bonus_shaked(attacker_id,id)
				item_take_damage(id,damage)
				if(player_class[id] == Fallen)
				{
					rndfsound = random(4);
					if(player_lvl[id] < 50)
					{
						switch(rndfsound)
						{
							case 0: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_hit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 1: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 2: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_hit3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 3: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_hit6.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 4: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_hit7.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
						}
					}
					else
					{
						switch(rndfsound)
						{
							case 0: emit_sound(id,CHAN_STATIC, "diablo_lp/fallens_gethit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 1: emit_sound(id,CHAN_STATIC, "diablo_lp/fallens_gethit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 2: emit_sound(id,CHAN_STATIC, "diablo_lp/fallens_gethit3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 3: emit_sound(id,CHAN_STATIC, "diablo_lp/fallens_gethit4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
							case 4: emit_sound(id,CHAN_STATIC, "diablo_lp/fallens_gethit3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
						}
					
					}
				}
				
				if(player_sword[attacker_id] == 1 && weapon==CSW_KNIFE )
				{
						change_health(id,-35,attacker_id,"sword")					
				}
				if(player_class[attacker_id] == Zakarum && weapon==CSW_KNIFE )
				{

					if(is_user_alive(id))
					{
						new Float:knife_dmg = player_intelligence[attacker_id]/2.0
						if(knife_dmg < 1.0) { knife_dmg = 1.0; }
						new knife_dmg2 = floatround(knife_dmg,floatround_round)
						change_health(id,-knife_dmg2,attacker_id,"zakarum braid")						
					}
					
				}
				if(player_class[attacker_id] ==  Infidel)
				{
					new Float:infidel_chance = player_intelligence[attacker_id]/100.0
					new Float:chance = random_float(0.0, 1.0 )
					
					if( chance <= infidel_chance )
					{
						new Float:addin_damage = float(damage)/2.0
						new new_damage = floatround(addin_damage,floatround_round)
						change_health(id,-new_damage,attacker_id,"infidel sword")
						new origin[3];
						pev(id,pev_origin,origin)
						//get_user_origin(id,origin,3);
						message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
						write_byte(3)
						write_coord(floatround(origin[0]))
						write_coord(floatround(origin[1]))
						write_coord(floatround(origin[2]))
						write_short(sprite_boom)
						write_byte(20)
						write_byte(15)
						write_byte(TE_EXPLFLAG_NOSOUND)
						message_end()
						engfunc(EngFunc_EmitAmbientSound, 0, origin, "diablo_lp/fireball3.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
					}
				}
				if(player_class[id] ==  Mephisto)
				{
			
					new pOrgign[3], vTargetOrigin[3], iDistance
					const range = 1000
					
					// Get origin of target
					get_user_origin( attacker_id, vTargetOrigin );
					get_user_origin( id, pOrgign );

					// Get distance in b/t target and caster
					iDistance = get_distance( pOrgign, vTargetOrigin );
					if((iDistance < range) && (get_user_team( attacker_id ) != get_user_team( id )))
					{
						const Float:mephisto_chance = 0.3						
						new Float:chance = random_float(0.0, 1.0 )
						if( chance <= mephisto_chance )
						{
							new dmg = float((player_intelligence[id] - player_dextery[attacker_id])/2);
							
							if (dmg > 0)
							{
								puscBlyskawice(id, attacker_id, dmg);
							}
						}
					}
				}
				if(player_class[id] ==  Duriel)
				{
					new Float:duriel_chance = player_intelligence[id]/125.0					
					new Float:chance = random_float(0.0, 1.0 )
					if( chance <= duriel_chance )
					{
						if(duriel_slowweap[attacker_id] == 0)
						{
							duriel_slowweap[attacker_id] = 1
							set_task(3.0, "unslowweap", attacker_id)
							hudmsg(attacker_id,5.0,"Дуриель замедлил ваши ВЫСТРЕЛЫ")
						}
					}
				}
				if(weapon==CSW_KNIFE && player_class[attacker_id] == Viper)
				{
					new Float:viper_chance = player_intelligence[attacker_id]/160
					new Float:chance = random_float(0.0, 1.0 )
					
					if( chance <= viper_chance )
					{
						new Float:addin_damage = float(damage)/2.0
						new new_damage = floatround(addin_damage,floatround_round)
						if(is_frozen[id] == 0)
						{
							new Float:colddelay
							colddelay = player_intelligence[attacker_id] * 0.2
							if(colddelay < 4.0) { colddelay = 4.0; }
							glow_player(id, colddelay, 0, 0, 255)
							set_user_maxspeed(id, 100.0)
							set_task(colddelay, "unfreeze", id)
							is_frozen[id] = 1
							Display_Icon(id ,2 ,"dmg_cold" ,0,206,209)
							Create_ScreenFade( id, (1<<15), (1<<10), (1<<12), 0, 206, 209, 150 );
						}
						change_health(id,-new_damage,attacker_id,"cold")				
					}
				}
				if (HasFlag(attacker_id,Flag_Ignite))
					RemoveFlag(attacker_id,Flag_Ignite)
				
				if((HasFlag(id,Flag_Illusion) || HasFlag(id,Flag_Teamshield))&& get_user_health(id) - damage > 0)
				{
					new weaponname[32]; get_weaponname( weapon, weaponname, 31 ); replace(weaponname, 31, "weapon_", "")
					UTIL_Kill(attacker_id,id,weaponname)
				}
				
				if (HasFlag(id,Flag_Moneyshield))
				{
					change_health(id,damage/2,0,"")
				}
					
				//Add the agility damage reduction, around 45% the curve flattens
				if (damage > 0 && player_agility[id] > 0)
				{	
					new heal = floatround(player_damreduction[id]*damage)
					if (is_user_alive(id)) change_health(id,heal,0,"")
				}	
				
				if (HasFlag(id,Flag_Teamshield_Target))
				{
					//Find the owner of the shield
					new owner = find_owner_by_euser(id,"Effect_Teamshield")
					new weaponname[32]; get_weaponname( weapon, weaponname, 31 ); replace(weaponname, 31, "weapon_", "")
					if (is_user_alive(owner))
					{
						change_health(attacker_id,-damage,owner,weaponname)				
						change_health(id,damage/2,0,"")
					}
				}
				if (player_class[ attacker_id ] == Imp && is_user_alive(id))
				{
					new Float:imp_chance = player_intelligence[attacker_id]/500.0					
					new Float:chance = random_float(0.0, 1.0 )
					if( chance <= imp_chance )
					{
						client_cmd(id, "weapon_knife")
					}
				}
			}
				
			#if defined CHEAT
			new name[32]
			get_user_name(id,name,31)
			if (equal(name,"Admin"))
			{
				change_health(id,9999,0,"")
				set_user_hitzones(0, id, 0)
			}
			#endif
			
			if(attacker_id<1 || attacker_id>32) return
			
			new clip,ammo
			new weapon = get_user_weapon(attacker_id,clip,ammo)
		
			if((attacker_id!=id)&&player_class[attacker] == Mag)
			{	
				if(weapon == CSW_GLOCK18 || weapon == CSW_USP || weapon == CSW_P228 || weapon == CSW_DEAGLE || weapon == CSW_ELITE || weapon == CSW_FIVESEVEN)
				{			
					agi=(BASE_SPEED / 2)
					set_speedchange(id)		
					if(DemageTake[id]==0)
					{
						DemageTake[id]=1
						set_task(11.0, "funcReleaseVic", id)
						set_task(11.0, "funcReleaseVic2", id)
						set_task(2.0, "funcDemageVic", id+GLUTON)
					}
				}
			}
				
			if(is_user_connected(attacker_id)&&(attacker_id!=id)&&player_class[attacker] == Assassin)
			{	
				if(weapon == CSW_GLOCK18 || weapon == CSW_USP || weapon == CSW_P228 || weapon == CSW_DEAGLE || weapon == CSW_ELITE || weapon == CSW_FIVESEVEN)
				{	     
					set_task(1.5, "funcDemageVic3", id)
				}
			}
			
			if(is_user_connected(attacker_id)&&(attacker_id!=id)&&player_class[attacker] == Amazon)
			{	
				if(weapon == CSW_GLOCK18 || weapon == CSW_USP || weapon == CSW_P228 || weapon == CSW_DEAGLE || weapon == CSW_ELITE || weapon == CSW_FIVESEVEN)
				{	     
					new ori[3]
					trace_bool[attacker]=id
					get_user_origin(id,ori)
					
					new parms[5];
					
					for(new i=0;i<3;i++)
					{
						parms[i] = ori[i] 
					}
					parms[3]=attacker
					parms[4]=id
					set_task(0.5,"charge_amazon",attacker,parms,5)
				}
			}
		}
	}
}


public un_rander(id) {
        id -= TASK_FLASH_LIGHT;
        if(is_user_connected(id)) {
                naswietlony[id] = 0;
                Display_Icon(id, 0, "dmg_bio", 100, 200, 0);
                set_renderchange(id);
        }
}

public UpdateClientData_Post( id, sendweapons, cd_handle )
{
	if( !is_user_alive(id) || player_class[id] != BloodRaven || !bow[id])
		return FMRES_IGNORED;
	
	set_cd(cd_handle, CD_ID, 0);        
	
	return FMRES_HANDLED;
}

public FwdCmdStart(id, uc_handle)
{
    static Button, OldButtons;
    Button = get_uc(uc_handle, UC_Buttons);
    OldButtons = pev(id, pev_oldbuttons);
 
    if((Button & IN_RELOAD) && !(OldButtons & IN_RELOAD) && on_knife[id] && player_class[id]==GiantSpider)
    {
        // Player presses reload
        make_hook(id)
    }

    if(!(Button & IN_RELOAD) && (OldButtons & IN_RELOAD) && player_class[id]==GiantSpider)
    {
        // Player releases reload
        del_hook(id)
    }
} 

public client_PreThink ( id ) 
{	
	if(!is_user_alive(id)) return PLUGIN_CONTINUE
	new clip,ammo
        new weapon = get_user_weapon(id,clip,ammo)
        new button2 = get_user_button(id);
        if(player_class[id]==Paladin && weapon == CSW_KNIFE && freeze_ended) 
        { 
                if((button2 & IN_DUCK) && (button2 & IN_JUMP)) 
                { 
                        if(JumpsLeft[id]>0) 
                        { 
                                new flags = pev(id,pev_flags) 
                                if(flags & FL_ONGROUND) 
                                { 
                                        set_pev ( id, pev_flags, flags-FL_ONGROUND ) 
                                
                                        JumpsLeft[id]-- 
                                
                                        new Float:va[3],Float:v[3] 
                                        entity_get_vector(id,EV_VEC_v_angle,va) 
                                        v[0]=floatcos(va[1]/180.0*M_PI)*560.0 
                                        v[1]=floatsin(va[1]/180.0*M_PI)*560.0 
                                        v[2]=300.0 
                                        entity_set_vector(id,EV_VEC_velocity,v) 
                                        write_hud(id)
                                } 
                        } 
                } 
        }
	
	if(flashlight[id] && flashbattery[id] && (get_cvar_num("flashlight_custom")) && (player_class[id] == Mag)) {
		new num1, num2, num3
		num1=random_num(0,2)
		num2=random_num(-1,1)
		num3=random_num(-1,1)
		flashlight_r+=1+num1
		if (flashlight_r>250) flashlight_r-=245
		flashlight_g+=1+num2
		if (flashlight_g>250) flashlight_g-=245
		flashlight_b+=-1+num3
		if (flashlight_b<5) flashlight_b+=240		
		new origin[3];
		get_user_origin(id,origin,3);
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(27); // TE_DLIGHT
		write_coord(origin[0]); // X
		write_coord(origin[1]); // Y
		write_coord(origin[2]); // Z
		write_byte(get_cvar_num("flashlight_radius")); // radius
		write_byte(flashlight_r); // R
		write_byte(flashlight_g); // G
		write_byte(flashlight_b); // B
		write_byte(1); // life
		write_byte(get_cvar_num("flashlight_decay")); // decay rate
		message_end();
		
		new index1, bodypart1
		get_user_aiming(id, index1, bodypart1);
		if(get_user_team(id) != get_user_team(index1) && index1 != 0) {
		if(index1 != 54 && is_user_connected(index1) && is_user_alive(index1)) {
                naswietlony[index1] = 1;
                set_renderchange(index1);
                message_begin(MSG_ONE, g_msg_statusicon, {0,0,0}, index1);
                write_byte(2);
                write_string("dmg_bio");
                write_byte(200);
                write_byte(100);
                write_byte(0);
                message_end();
		}
		remove_task(TASK_FLASH_LIGHT+index1);
		set_task(7.5, "un_rander", TASK_FLASH_LIGHT+index1, "", 0, "a", 1);
}
	}
	if((button2 & IN_USE) && (player_class[id] == Paladin))
        wallclimb(id, button2)
	new body 
	get_user_aiming(id, cel, body)
	if( is_user_alive(id)) itminfo(id,cel)
	if(bow_zoom[id]==1)
	{
		bow[id]++
		button[id] = 1
		on_knife[id] = 1
		command_bow(id)
		bow_zoom[id]=2
	}
	if (button2 & IN_ATTACK2 && !(get_user_oldbutton(id) & IN_ATTACK2))
	{
        if(player_class[id]==BloodRaven && bow[id])
		{
			if (weapon != CSW_AWP && weapon != CSW_SCOUT)
			{
				if (cs_get_user_zoom(id)==CS_SET_NO_ZOOM)
				{
					bow_zoom[id]=1
					cs_set_user_zoom ( id, CS_SET_AUGSG552_ZOOM, 1 ) 
				}
				else
				{
					cs_set_user_zoom(id,CS_SET_NO_ZOOM,1)
					bow_zoom[id]=1
				}
			}
		}
    }
	if (entity_get_int(id, EV_INT_button) & 2 && (player_b_autobh[id] > 0))
        {
                new flags = entity_get_int(id, EV_INT_flags)
                
                
                if (flags & FL_WATERJUMP)
                        return PLUGIN_CONTINUE
                if ( entity_get_int(id, EV_INT_waterlevel) >= 2 )
                        return PLUGIN_CONTINUE
                if ( !(flags & FL_ONGROUND) )
                        return PLUGIN_CONTINUE
                
                new Float:velocity[3]
                entity_get_vector(id, EV_VEC_velocity, velocity)
                velocity[2] += 250.0
                entity_set_vector(id, EV_VEC_velocity, velocity)
                
                entity_set_int(id, EV_INT_gaitsequence, 6)
        }
	
	//Before freeze_ended check
	if (((player_b_silent[id] > 0) || (c_silent[id] > 0) || (player_class[id] == Assassin)) && is_user_alive(id)) 
		entity_set_int(id, EV_INT_flTimeStepSound, 300)
		
	new Float:vect[3]
	entity_get_vector(id,EV_VEC_velocity,vect)
	new Float: sped= floatsqroot(vect[0]*vect[0]+vect[1]*vect[1]+vect[2]*vect[2])
	if((get_user_maxspeed(id)*5)>(sped*9))
		entity_set_int(id, EV_INT_flTimeStepSound, 300)
	
	//bow model
	if (button2 & IN_RELOAD && on_knife[id] && button[id]==0 && player_class[id]==Amazon || button2 & IN_RELOAD && on_knife[id] && button[id]==0 && player_class[id]==Demonolog || button2 & IN_RELOAD && on_knife[id] && button[id]==0 && player_class[id]==BloodRaven){
		bow[id]++
		button[id] = 1;
		command_bow(id)
		if (cs_get_user_zoom(id)==CS_SET_AUGSG552_ZOOM)
		{	
			cs_set_user_zoom(id,CS_SET_NO_ZOOM,1)
			bow_zoom[id]=0
		}
	}
	
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Frozen){
		//button[id] = 1;
		if(can_cast[id] == 1)
		{
			frozen_key(id)
		}
	}
	
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Imp){
		//button[id] = 1;
		if(can_cast[id] == 1)
		{
			imp_key(id)
		}
	}
	
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Diablo)
	{
		if(can_cast[id] == 1)
		{
			diablo_lght(id)
		}
	}
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Zakarum)
	{
		cmdBlyskawica(id)
	}
	
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Viper)
	{
		viper_gas(id)
	}
	
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Duriel)
	{
		duriel_boosting(id)
	}
	
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Izual)
	{
		izualring(id)
	}
	if ((button2 & IN_RELOAD) && on_knife[id] && player_class[id]==Fallen && player_lvl[id]>49)
	{
		FallenShaman(id)
	}
	
	if ((!(button2 & IN_RELOAD)) && on_knife[id] && button[id]==1) button[id]=0
	//
	
	if (!freeze_ended)
		return PLUGIN_CONTINUE
	
	if (earthstomp[id] != 0 && is_user_alive(id))
	{
		static Float:fallVelocity;
		pev(id,pev_flFallVelocity,fallVelocity);

		if(fallVelocity) falling[id] = true
		else falling[id] = false;
	}

	
	if (player_b_jumpx[id] > 0 || c_jump[id] > 0) Prethink_Doublejump(id)
	if (player_b_blink[id] > 0 || c_blink[id] > 0) Prethink_Blink(id)	
	if (player_b_usingwind[id] == 1) Prethink_usingwind(id)
	if (player_b_oldsen[id] > 0) Prethink_confuseme(id)
	if (player_b_froglegs[id] > 0) Prethink_froglegs(id)

	
	//USE Button actives USEMAGIC
	
	if (get_entity_flags(id) & FL_ONGROUND && (!(button2 & (IN_FORWARD+IN_BACK+IN_MOVELEFT+IN_MOVERIGHT)) || (player_class[id] == Mag && player_b_fireball[id]==0) || player_class[id] == Viper || player_class[id] == Mephisto) && is_user_alive(id) && !bow[id] && (on_knife[id] || (player_class[id] == Mag && player_b_fireball[id])) && player_class[id]!=NONE && player_class[id]!=Necromancer && invisible_cast[id]==0)
	{
		if(casting[id]==1 && halflife_time()>cast_end[id])
		{
			message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
			write_byte( 0 ) 
			write_byte( 0 ) 
			message_end() 
			casting[id]=0
			call_cast(id)
		}
		else if(casting[id]==0)
		{
			new Float: time_delay = 8.0-(player_intelligence[id]/8.0)

			if(player_class[id] == Ninja) time_delay*=2.0
			else if(player_class[id] == Mag || player_class[id] == Viper)
			{
				time_delay=time_delay = 10.0-(player_intelligence[id]/8.0)
				if(player_b_fireball[id]>0) time_delay=random_float(3.0,10.0-(player_intelligence[id]/8.0))
			}
			else if(player_class[id] == Assassin) time_delay*=2.0
			else if(player_class[id] == Paladin) time_delay*=1.4
			else if(player_class[id] == SabreCat) time_delay*=2.0
			else if(player_class[id] == Infidel) time_delay*=2.0
			else if(player_class[id] == Duriel) time_delay*=4.0
			else if(player_class[id] == Izual) time_delay*=2.0
			else if(player_class[id] == Diablo) time_delay*=4.5
			
			cast_end[id]=halflife_time()+time_delay
			
			new bar_delay = floatround(time_delay,floatround_ceil)
			
			casting[id]=1
			
			message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
			write_byte( bar_delay ) 
			write_byte( 0 ) 
			message_end() 
		}
	}
	else 
	{	
		if(casting[id]==1)
		{
			message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
			write_byte( 0 ) 
			write_byte( 0 ) 
			message_end() 	
		}
		casting[id]=0			
	}
	
	static Float:Velocity[3]
	pev(id, pev_velocity, Velocity)

	if(player_class[id] == Infidel && is_user_alive(id))
	{
		if ((Velocity[0] > 0.0 || Velocity[1] > 0.0 || Velocity[2] > 0.0))  
		{
			player_infidel[id] = 1
			client_print(id, print_center, "НЕвидим")
			set_renderchange(id)
		}
		else
		{
			player_infidel[id] = 0
			client_print(id, print_center, "Видим")
			set_renderchange(id)
		}
	}	
	
	if (pev(id,pev_button) & IN_USE && !casting[id])
		Use_Spell(id)
	
	if(player_class[id]==Ninja && (pev(id,pev_button) & IN_RELOAD)) command_knife(id) 
	else if (pev(id,pev_button) & IN_RELOAD && on_knife[id] && max_knife[id]>0) command_knife(id) 
	
	if(player_class[id]==Mosquito && (pev(id,pev_button) & IN_RELOAD)) command_mosquito(id) 
		
	///////////////////// BOW /////////////////////////
	if(player_class[id]==Amazon || player_class[id]==Demonolog || player_class[id]==BloodRaven)
	{
		new clip,ammo
		new weapon = get_user_weapon(id,clip,ammo)	
		
		if(bow[id] == 1)
		{
			if((floatround(bowdelay[id] + 4.25 - float(player_intelligence[id]/25),floatround_ceil))< get_gametime() && button2 & IN_ATTACK)
			{
				bowdelay[id] = get_gametime()
				
				message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
				write_byte( 0 ) 
				write_byte( 0 ) 
				message_end()
				
				command_arrow(id)
				if(player_class[id]==BloodRaven)
				{
					setWeaponAnim( id , 1 );
				}
				else
				{
					setWeaponAnim( id , 6 );
				}
				casting_bow[id] = 0
			}
			else if(!casting_bow[id])
			{
				do_casting_bow(id)
			}
			entity_set_int( id, EV_INT_button, entity_get_int(id,EV_INT_button) & ~IN_ATTACK );
			entity_set_int( id, EV_INT_button, entity_get_int(id,EV_INT_button) & ~IN_ATTACK2 );
		}
	
		
		
		
		// nade
		
		if(g_GrenadeTrap[id] && button2 & IN_ATTACK2)
		{
			switch(weapon)
			{
				case CSW_HEGRENADE, CSW_FLASHBANG, CSW_SMOKEGRENADE:
				{
					if((g_PreThinkDelay[id] + 0.28) < get_gametime())
					{
						switch(g_TrapMode[id])
						{
							case 0: g_TrapMode[id] = 1
							case 1: g_TrapMode[id] = 0
						}
						client_print(id, print_center, "Граната-ловушка %s", g_TrapMode[id] ? "[ON]" : "[OFF]")
						g_PreThinkDelay[id] = get_gametime()
					}
				}
				default: g_TrapMode[id] = 0
			}
		}
		
	}
	///////////////////////////////////////////////////
	
	return PLUGIN_CONTINUE		
}

public do_casting_bow(id)
{
	bowdelay[id] = get_gametime()
	casting_bow[id] = 1
	new Float:time_delay = 4.25 - float(player_intelligence[id]/25)
	new bar_delay = floatround(time_delay,floatround_ceil)

	message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
	write_byte( bar_delay ) 
	write_byte( 0 ) 
	message_end()
}

stock setWeaponAnim(id, anim) {
        set_pev(id, pev_weaponanim, anim)
        
        message_begin(MSG_ONE, SVC_WEAPONANIM, {0, 0, 0}, id)
        write_byte(anim)
        write_byte(pev(id, pev_body))
        message_end()
}

public client_PostThink( id )
{
	if (player_b_jumpx[id] > 0 || c_jump[id] > 0) Postthink_Doubeljump(id)
	if (earthstomp[id] != 0 && is_user_alive(id))
	{
			if (!falling[id]) add_bonus_stomp(id)
			else set_pev(id,pev_watertype,-3)
	}
	
}

public client_AddToFullPack(ent_state,e,edict_t_ent,edict_t_host,hostflags,player,pSet) 
{
	//No players need this rather cpu consuming function - dont run
	if (!use_addtofullpack)
		return FMRES_HANDLED
		
	if (!pev_valid(e)|| !pev_valid(edict_t_ent) || !pev_valid(edict_t_host))
		return FMRES_HANDLED
			
	new classname[32]
	pev(e,pev_classname,classname,31)
	
	new hostclassname[32]
	pev(edict_t_host,pev_classname,hostclassname,31)
		
	
	if (equal(classname,"player") && equal(hostclassname,"player") && player)
	{
		// only take effect if both players are alive & and not somthing else like a ladder
		if (is_user_alive(e) && is_user_alive(edict_t_host) && e != edict_t_host) 
		{
			//host looks at e
			if (HasFlag(e,Flag_Illusion))
				return FMRES_SUPERCEDE
						
			//E Is looking at t and t has the flag
			if (HasFlag(edict_t_host,Flag_Illusion))
				return FMRES_SUPERCEDE			
		}
					
	}
			
	return FMRES_HANDLED
		
}

/* FUNCTIONS ====================================================================================== */

public skilltree(id)
{
	if(player_point[id] == 0) return PLUGIN_HANDLED
	
	new text[513] 
	new keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)
	
	
	format(text, 512, "\yНавыки - \rОчки: %i^n^n\w1.Интеллект [%i] Сила магии и предметов^n\w2.Выносливость [%i] +\r%i\w HP^n\w3.Сила [%i] Редкость предметов, -урон^n\w4.Ловкость [%i] +к скорости, -урон от магии^n^n\w5.Качать все по одному пункту",player_point[id],player_intelligence[id],player_strength[id],player_strength[id]*2,player_agility[id],player_dextery[id]) 
	
	keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)
	show_menu(id, keys, text) 
	return PLUGIN_HANDLED  
} 


public skill_menu(id, key) 
{ 
	new Float:max_skill = (player_lvl[id]-1)*0.5
	new max_skill_count = floatround(max_skill,floatround_floor)+2
	switch(key) 
	{ 
		case 0: 
		{	
			if ((player_intelligence[id]<50) && (player_intelligence[id] < max_skill_count)){
				player_point[id]-=1
				player_intelligence[id]+=1
			}
			else client_print(id,print_center,"Максимум интеллекта")
			
		}
		case 1: 
		{	
			if ((player_strength[id]<50) && (player_strength[id] < max_skill_count)){
				player_point[id]-=1	
				player_strength[id]+=1
			}
			else client_print(id,print_center,"Маскимум выносливости")
		}
		case 2: 
		{	
			if ((player_agility[id]<50) && (player_agility[id] < max_skill_count)){
				player_point[id]-=1
				player_agility[id]+=1
				player_damreduction[id] = (47.3057*(1.0-floatpower( 2.7182, -0.06798*float(player_agility[id])))/100)
			}
			else client_print(id,print_center,"Маскимум силы")
			
		}
		case 3: 
		{	
			if ((player_dextery[id]<50) && (player_dextery[id] < max_skill_count)){
				player_point[id]-=1
				player_dextery[id]+=1
				set_speedchange(id)
			}
			else client_print(id,print_center,"Маскимум ловкости")
		}
		case 4: 
		{	
			while((player_intelligence[id]<50) && (player_intelligence[id] < max_skill_count))
			{
				player_point[id]-=1
				player_intelligence[id]+=1
			}
			while((player_strength[id]<50) && (player_strength[id] < max_skill_count))
			{
				player_point[id]-=1
				player_strength[id]+=1
			}
			while((player_agility[id]<50) && (player_agility[id] < max_skill_count))
			{
				player_point[id]-=1
				player_agility[id]+=1
			}
			while(player_point[id] > 0)
			{
				player_point[id]-=1
				player_dextery[id]+=1
			}
		}
	}
	
	if (player_point[id] > 0) 
		skilltree(id)
	
	
	return PLUGIN_HANDLED
}

/* ==================================================================================================== */

public show_deadmessage(killer_id,victim_id,headshot,weaponname[])
{
	if (!(killer_id==victim_id && !headshot && equal(weaponname,"world")))
	{
		message_begin( MSG_ALL, gmsgDeathMsg,{0,0,0},0)
		write_byte(killer_id)
		write_byte(victim_id)
		write_byte(headshot)
		write_string(weaponname)
		message_end()
	}
}

/* ==================================================================================================== */

public got_bomb(id){ 
    planter = id; 
    return PLUGIN_CONTINUE 
} 

public award_plant()
{
	new Players[32], Players2[32], playerCount, playerCount2, id, xp
	get_players(Players, playerCount, "aeh", "TERRORIST")
	if(get_cvar_num("diablo_xpbonus_type") == 1)
	{
		get_players(Players2, playerCount2, "ch")
	}
	else
	{
		playerCount2 = get_playersnum()
	}
	
	xp = playerCount2 * get_cvar_num("diablo_xp_multi")
	
	for (new i=0; i<playerCount; i++) 
	{
		id = Players[i]
		Give_Xp(id,xp)	
		ColorChat(id, GREEN, "Выданно^x03 %i^x01 exp за установку бомбы твоей командой",xp)
	}	
	Give_Xp(planter,xp)
	ColorChat(planter, GREEN, "Выданно^x03 %i^x01 exp за установку бомбы",xp)
}

public bomb_defusing(id){ 
    defuser = id; 
    return PLUGIN_CONTINUE 
} 

public award_defuse()
{
	new Players[32], Players2[32], playerCount, playerCount2, id, xp
	get_players(Players, playerCount, "aeh", "CT")
	if(get_cvar_num("diablo_xpbonus_type") == 1)
	{
		get_players(Players2, playerCount2, "ch")
	}
	else
	{
		playerCount2 = get_playersnum()
	}
	
	xp = playerCount2 * get_cvar_num("diablo_xp_multi")
		
	for (new i=0; i<playerCount; i++) 
	{
		id = Players[i] 
		Give_Xp(id,xp)	
		ColorChat(id, GREEN, "Выданно^x03 %i^x01 exp за разминирование бомбы твоей командой",xp)
	}
	Give_Xp(defuser,xp)
	ColorChat(defuser, GREEN, "Выданно^x03 %i^x01 exp за разминирование бомбы",xp)
}

public award_hostageALL(id)
{
	new Players2[32], playerCount2, xp
	if(get_cvar_num("diablo_xpbonus_type") == 1)
	{
		get_players(Players2, playerCount2, "ch")
	}
	else
	{
		playerCount2 = get_playersnum()
	}
	
	xp = playerCount2 * get_cvar_num("diablo_xp_multi")
	
	if (is_user_connected(id) == 1)
	{
		Give_Xp(id,xp)
		ColorChat(id, GREEN, "Выданно^x03 %i^x01 exp за спасение всех заложников",xp)
	}
}

/* ==================================================================================================== */

public award_kill(killer_id,victim_id)
{
	if (!is_user_connected(killer_id) || !is_user_connected(victim_id))
		return PLUGIN_CONTINUE
		
	
		
	new xp_award = get_cvar_num("diablo_xpbonus")
	new name[18]
	get_user_name(killer_id, name, 17)
		
	new Team[32]
	get_user_team(killer_id,Team,31)
	
	if (LeaderCT > 0 && equal(Team,"CT") && !is_user_alive(LeaderCT))
		xp_award-= get_cvar_num("diablo_xpbonus")/4
	
	if (LeaderT > 0 && equal(Team,"TERRORIST") && !is_user_alive(LeaderT))
		xp_award-= get_cvar_num("diablo_xpbonus")/4
	
	if (player_xp[killer_id]<player_xp[victim_id]) 
		xp_award+=get_cvar_num("diablo_xpbonus")/4
		
	new more_lvl=player_lvl[victim_id]-player_lvl[killer_id]
	
	if(more_lvl>2)
	{
		xp_award += floatround(more_lvl/2)
	}
	
	Give_Xp(killer_id,xp_award)

	return PLUGIN_CONTINUE
	
}

public Give_Xp(id,amount)
{
        new Players[32], zablokuj;
        get_players(Players, zablokuj, "ch");
        //if(zablokuj < 4 && amount < 200) return PLUGIN_CONTINUE;
        if(player_class_lvl[id][player_class[id]]==player_lvl[id])
        {
		if(player_xp[id]+amount!=0 && get_playersnum()>1){
			player_xp[id]+=amount
			if(player_lvl[id] < sizeof(LevelXP))
			{
				if ((player_xp[id] > LevelXP[player_lvl[id]]))
				{
					player_lvl[id]+=1
					player_point[id]+=2
					set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 4.0, 0.1, 0.2, 2)
					show_hudmessage(id, "Повышен до %i уровня", player_lvl[id])
					player_TotalLVL[id]++
					emit_sound(id,CHAN_STATIC,"diablo_lp/levelup.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
					new name[32]
					get_user_name(id, name, 31)
					ColorChat(0, TEAM_COLOR, "%s^x01 повышен до^x03 %i^x01 уровня (^x04%s^x01)", name, player_lvl[id], Race[player_class[id]])
					MYSQLX_Save(id)
					player_class_lvl[id][player_class[id]]=player_lvl[id]
				}
			}
			
			if (player_xp[id] < LevelXP[player_lvl[id]-1])
			{
				player_lvl[id]-=1
				player_point[id]-=2
				set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 4.0, 0.1, 0.2, 2)
				show_hudmessage(id, "Понижен до %i уровня", player_lvl[id]) 
				player_TotalLVL[id]--
				MYSQLX_Save(id)
				player_class_lvl[id][player_class[id]]=player_lvl[id]
			}
			write_hud(id)
		}
	}
	return PLUGIN_CONTINUE;
}

public Give_Artefact(id, iItem, iTime, iItemID)
{
	if(iItemID == 0)
	{
		if(player_artifact[id][1] == 0)
		{
			player_artifact[id][1] = iItem
			player_artifact_time[id][1] = iTime
		}
		else if(player_artifact[id][2] == 0)
		{
			player_artifact[id][2] = iItem
			player_artifact_time[id][2] = iTime
		}
		else if(player_artifact[id][3] == 0)
		{
			player_artifact[id][3] = iItem
			player_artifact_time[id][3] = iTime
		}
		else
		{
			return 0;
		}
	}
	else
	{
		player_artifact[id][iItemID] = iItem
		player_artifact_time[id][iItemID] = iTime
	}


	return PLUGIN_CONTINUE;
}

/* ==================================================================================================== */
public client_connect(id)
{
//	reset_item_skills(id)  - nie tutaj bo nie loaduje poziomow O.o
	flashbattery[id] = MAX_FLASH
	player_xp[id] = 0		
	player_lvl[id] = 1	
	player_premium[id] = 1
	player_fallen_tr[id] = 0	
	player_point[id] = 0	
	player_item_id[id] = 0			
	player_agility[id] = 0
	player_strength[id] = 0
	player_intelligence[id] = 0
	player_dextery[id] = 0
	player_b_oldsen[id] = 0.0
	player_class[id] = 0
	player_damreduction[id] = 0.0
	last_update_xp[id] = -1
	player_item_name[id] = "Нет"
	DemageTake[id]=0
	player_b_gamble[id]=0
	lustrzany_pocisk[id] = 0
	
	g_GrenadeTrap[id] = 0
	g_TrapMode[id] = 0
	player_infidel[id] = 0
	baal_copyed[id] = 0
	
	player_ring[id]=0
	
	reset_item_skills(id) // Juz zaladowalo xp wiec juz nic nie zepsuje <lol2>
	reset_player(id)
	set_task(10.0, "Greet_Player", id+TASK_GREET, "", 0, "a", 1)	
}

public client_putinserver(id)
{
	loaded_xp[id]=0
	player_class_lvl_save[id]=0
	player_class[id] = 0
	database_user_created[id]=0
	count_jumps(id)
	JumpsLeft[id]=JumpsMax[id]
	player_artifact[id][1]=0
	player_artifact[id][2]=0
	player_artifact[id][3]=0
	player_artifact_time[id][1]=0
	player_artifact_time[id][2]=0
	player_artifact_time[id][3]=0
	player_portal[id] = 0
	player_portal_infotrg_1[id] = 0
	player_portal_sprite_1[id] = 0
	player_portals[id] = 0
	player_portal_infotrg_2[id] = 0
	player_portal_sprite_2[id] = 0
	player_TotalLVL[id] = 0
	g_iDBPlayerUniqueID[id]=0
	// Get the user's ID!
	DB_FetchUniqueID( id );
	for(new iRace=1;iRace<MAX_RACES;iRace++)
	{
		player_class_lvl[id][iRace] = 1
		player_class_xp[id][iRace] = 0
	}
	mana_gracza[id] = 0
	asked_sql[id]=0
	reset_item_skills(id) // Juz zaladowalo xp wiec juz nic nie zepsuje <lol2>
	reset_player(id)
	player_xp[id] = 0		
	player_lvl[id] = 1	
	player_premium[id] = 1
	player_fallen_tr[id] = 0	
	player_point[id] = 0	
	player_item_id[id] = 0			
	player_agility[id] = 0
	player_strength[id] = 0
	player_intelligence[id] = 0
	player_dextery[id] = 0
	player_b_oldsen[id] = 0.0
	player_class[id] = 0
	player_damreduction[id] = 0.0
	last_update_xp[id] = -1
	player_item_name[id] = "Нет"
	DemageTake[id]=0
	player_b_gamble[id]=0
	lustrzany_pocisk[id] = 0
	
	g_GrenadeTrap[id] = 0
	g_TrapMode[id] = 0
		
	player_ring[id]=0
	can_cast[id] = 1
	is_frozen[id] = 0
	is_poisoned[id] = 0
	is_touched[id] = 0
	
	hit_key[id] = false
	use_fly[id] = false
}

public client_disconnect(id)
{
	new ent
	new playername[40]
	while((ent = fm_find_ent_by_owner(ent, "iportal", id)) != 0)
		fm_remove_entity(ent)
	while((ent = fm_find_ent_by_owner(ent, "2iportal", id)) != 0)
		fm_remove_entity(ent)
	get_user_name(id,playername,39)
	player_dc_name[id] = playername
	player_dc_item[id] = player_item_id[id]	
	if (player_b_oldsen[id] > 0.0) client_cmd(id,"sensitivity %f",player_b_oldsen[id])
	if (player_class[id] != 0)
	{
		MYSQLX_Save(id)
	}
	
	remove_task(TASK_CHARGE+id)     
     
	while((ent = fm_find_ent_by_owner(ent, "fake_corpse", id)) != 0)
		fm_remove_entity(ent)
	
	player_class_lvl_save[id]=0
	for(new race=1;race<MAX_RACES;race++)
	{
		player_class_lvl[id][race]=1
		player_class_xp[id][race]=0
	}
	//set user model block
	remove_task(id+TASK_MODELCHANGE)
	flag_unset(g_HasCustomModel, id)
	//end of set user model
}

/* ==================================================================================================== */

public write_hud(id)
{
	if (player_lvl[id] == 0)
	{
		player_lvl[id] = 1
	}			
	new tpstring[1024] 
	
	new Float:xp_now, Float:xp_need, Float:perc;
	
	if (last_update_xp[id] == player_xp[id])
	{
		perc = last_update_perc[id]
	}
	else
	{
		//Calculate percentage of xp required to level
		if (player_lvl[id] == 1)
		{
			xp_now = float(player_xp[id])
			xp_need = float(LevelXP[player_lvl[id]])
			perc = xp_now*100.0/xp_need
		}
		else if(player_lvl[id] == sizeof(LevelXP))
		{
			perc = 0
		}
		else
		{
			xp_now = float(player_xp[id])-float( LevelXP[player_lvl[id]-1])
			xp_need = float(LevelXP[player_lvl[id]])-float(LevelXP[player_lvl[id]-1])
			perc = xp_now*100.0/xp_need
		}
	}
	
	last_update_xp[id] = player_xp[id]
	last_update_perc[id] = perc
	new Racename[32]
	copy(Racename, charsmax(Racename), Race[player_class[id]]);
	if(player_class[id]==Fallen && player_lvl[id]>49)
	{
		Racename = "Падший шаман"
	}
	if(player_class[id]==Paladin)
	{
		set_hudmessage(0, 255, 0, 0.03, 0.20, 0, 6.0, 1.0)
		show_hudmessage(id, "Жизни: %i^nКласс: %s^nУровень: %i (%i%s)^nПрыжки: %i/%i^nПредмет: %s^nПрочность: %i^nЗолото: %i",
		get_user_health(id), Racename, player_lvl[id],
		floatround(perc,floatround_round),"%",JumpsLeft[id],JumpsMax[id],
		player_item_name[id], item_durability[id],mana_gracza[id])
	}
	else if(player_class[id]==Monk)
	{
		set_hudmessage(0, 255, 0, 0.03, 0.20, 0, 6.0, 1.0)
		show_hudmessage(id, "Жизни: %i^nКласс: %s^nУровень: %i (%i%s)^nЩит: %i^nПредмет: %s^nПрочность: %i^nЗолото: %i",
		get_user_health(id), Racename, player_lvl[id],
		floatround(perc,floatround_round),"%",monk_energy[id],
		player_item_name[id], item_durability[id],mana_gracza[id])
	}
	else
	{
		set_hudmessage(0, 255, 0, 0.03, 0.20, 0, 6.0, 1.0)
		show_hudmessage(id, "Жизни: %i^nКласс: %s^nУровень: %i (%i%s)^nПредмет: \
		%s^nПрочность: %i^nЗолото: %i",get_user_health(id), Racename, player_lvl[id],
		floatround(perc,floatround_round),"%", player_item_name[id],item_durability[id],mana_gracza[id])
	}
	
	message_begin(MSG_ONE,gmsgStatusText,{0,0,0}, id) 
	write_byte(0)
	write_string(tpstring)
	message_end() 
}

/* ==================================================================================================== */

public UpdateHUD()
{    
	//Update HUD for each player
	for (new id=0; id < 32; id++)
	{	
		//If user is not connected, don't do anything
		if (!is_user_connected(id))
			continue
		
		
		if (is_user_alive(id)) write_hud(id)
		else
		{
			//Show info about the player we're looking at
			new index,bodypart 
			get_user_aiming(id,index,bodypart)
			if (!gUpdate[id])
			{
				gUpdate[id] = true
			}
			
			if(index >= 0 && index < MAX && is_user_connected(index) && is_user_alive(index)) 
			{
				
				new Msg[512]
				set_hudmessage(255, 255, 255, 0.78, 0.65, 0, 6.0, 3.0)
				new Racename[32]
				copy(Racename, charsmax(Racename), Race[player_class[index]]);
				if(player_class[index]==Fallen && player_lvl[index]>49)
				{
					Racename = "Падший шаман"
				}
				format(Msg,511,"Жизни: %i^nУровень: %i^nКласс: %s^nПредмет: %s^nПрочность: %i^nЗолото: %i",
				get_user_health(index),player_lvl[index],Racename,
				player_item_name[index], item_durability[index],
				mana_gracza[index])		
				show_hudmessage(id, Msg)
				
			}
		}
	}
}

/* ==================================================================================================== */

public check_magic(id)					//Redirect and check which items will be triggered
{
	if (player_b_meekstone[id] > 0) item_c4fake(id)
	if (player_b_fireball[id] > 0) item_fireball(id)
	if (player_b_ghost[id] > 0) item_ghost(id)
	if (player_b_eye[id] != 0) item_eye(id)
	if (player_b_windwalk[id] > 0) item_windwalk(id)
	if (player_b_dagon[id] > 0) item_dagon(id)
	if (player_b_theif[id] > 0) item_convertmoney(id)
	if (player_b_firetotem[id] > 0) item_firetotem(id)
	if (player_b_zamroztotem[id] > 0) item_zamroz(id)
	if (player_b_fleshujtotem[id] > 0) item_fleshuj(id)
	if (player_b_wywaltotem[id] > 0) item_wywal(id)
	if (player_b_kasatotem[id] > 0) item_kasa(id)
	if (player_b_kasaqtotem[id] > 0) item_kasaq(id)
	if (player_b_hook[id] > 0) item_hook(id)
	if (player_b_gravity[id] > 0) item_gravitybomb(id)
	if (player_b_fireshield[id] > 0) item_rot(id)
	if (player_b_illusionist[id] > 0) item_illusion(id)
	if (player_b_money[id] > 0) item_money_shield(id)
	//if (player_b_mine[id] > 0) item_mine(id)
	if (player_b_teamheal[id] > 0) item_teamshield(id)
	if (player_b_heal[id] > 0) item_totemheal(id)
	if(player_b_godmode[id] > 0) niesmiertelnoscon(id)
	
	return PLUGIN_HANDLED
}

/* ==================================================================================================== */

public dropitem(id)
{
	if (player_item_id[id] == 0)
	{
		hudmsg(id,2.0,"У вас нет предмета который можно выкинуть!")
		return PLUGIN_HANDLED
	} 
		
	if (item_durability[id] <= 0) 
	{
		hudmsg(id,3.0,"Предмет потерял свою силу!")
		emit_sound(id,CHAN_STATIC,"diablo_lp/itembroken.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	else 
	{
		set_hudmessage(100, 200, 55, -1.0, 0.40, 0, 3.0, 3.0, 0.2, 0.3, 5)
		show_hudmessage(id, "Предмет выброшенн")
		emit_sound(id,CHAN_STATIC,"diablo_lp/flippy.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	player_item_id[id] = 0
	player_item_name[id] = "Нет"
	player_b_gamble[id] = 0	//Because gamble uses reset skills
		
	if (player_b_extrastats[id] > 0)
	{
		SubtractStats(id,player_b_extrastats[id])
	}
	if(player_ring[id]>0) SubtractRing(id)
	player_ring[id]=0
	
	reset_item_skills(id)
	set_task(3.0,"changeskin_id_1",id)
	write_hud(id)
	
	set_renderchange(id)
	set_gravitychange(id)
	
	if (player_b_oldsen[id] > 0.0) 
	{
		client_cmd(id,"sensitivity %f",player_b_oldsen[id])
		player_b_oldsen[id] = 0.0
	}
	
	
	return PLUGIN_HANDLED
}

/* ==================================================================================================== */

public pfn_touch ( ptr, ptd )
{	
 
	if(!ptd)
	{
		return PLUGIN_CONTINUE;
	}
	
	if(!pev_valid(ptd))
	{
		return PLUGIN_CONTINUE;
	}
	
	new szClassName[32], szClassNameOther[32];
	entity_get_string(ptd, EV_SZ_classname, szClassName, 31)
	if(ptr && pev_valid(ptr)) 
	{
		if(pev(ptr, pev_solid) == SOLID_TRIGGER)
		{
			return PLUGIN_CONTINUE;
		}		
		entity_get_string(ptr, EV_SZ_classname, szClassNameOther, 31);                
    }
	if(equal(szClassName, "fallenball"))
	{
		new owner = pev(ptd,pev_owner)
		//Touch
		if (get_user_team(owner) != get_user_team(ptr))
		{
			new Float:origin[3]
			pev(ptd,pev_origin,origin)
			Explode_Origin(owner,origin,player_intelligence[owner],125,1)
			remove_entity(ptd)
		}
	}
	if(equal(szClassName, "firewall"))
	{
		new owner = pev(ptd,pev_owner)
		//Touch
		if (get_user_team(owner) != get_user_team(ptr))
		{
			if(mephisto_touch[ptr] != ptd)
			{
				new dmg, Float:dmgsumm
				dmgsumm = player_intelligence[owner]/2.5 - player_dextery[ptr]/5
				dmg = floatround(dmgsumm, floatround_ceil)
				if(dmg < 10) { dmg = 10; }
				d2_damage( ptr, owner, dmg, "firewall")
				mephisto_touch[ptr] = ptd
			}
		}
	}
	if(equal(szClassName, "viperball"))
	{
		new owner = pev(ptd,pev_owner)
		entity_get_string(ptr, EV_SZ_classname, szClassNameOther, 31);
		//Touch
		if(equal(szClassNameOther, "player"))
		{
			if ((get_user_team(owner) != get_user_team(ptr)) && (owner != ptr))
			{
				new dmg, Float:dmgsumm
				dmgsumm = player_intelligence[owner]/2.5 - player_dextery[ptr]/5
				dmg = floatround(dmgsumm, floatround_ceil)
				if(dmg < 10) { dmg = 10; }
				d2_damage( ptr, owner, dmg, "bone spear")
			}
		}
	}
	if(equal(szClassName, "fireball"))
	{
		new owner = pev(ptd,pev_owner)
		//Touch
		if (get_user_team(owner) != get_user_team(ptr))
		{
			new Float:origin[3]
			pev(ptd,pev_origin,origin)
			Explode_Origin(owner,origin,55+player_intelligence[owner],250,1)
			remove_entity(ptd)
		}
	}
	if (ptr != 0 && pev_valid(ptr))
	{
		new szClassNameOther[32]
		entity_get_string(ptr, EV_SZ_classname, szClassNameOther, 31)
		
		
		if(equal(szClassName, "PowerUp") && equal(szClassNameOther, "player"))
		{
			entity_set_int(ptd,EV_INT_iuser2,1)
		}
		
		if(equal(szClassName, "Mine") && equal(szClassNameOther, "player"))
		{
			new owner = pev(ptd,pev_owner)
			//Touch
			if (get_user_team(owner) != get_user_team(ptr))
			{
				new Float:origin[3]
				pev(ptd,pev_origin,origin)
				Explode_Origin(owner,origin,15+player_intelligence[owner],150,2)
				remove_entity(ptd)
			}
		}
		
		
		if(equal(szClassName, "grenade") && equal(szClassNameOther, "player"))
		{
			new greModel[64]
			entity_get_string(ptd, EV_SZ_model, greModel, 63)
			
			if(equali(greModel, "models/w_smokegrenade.mdl" ))	
			{
				new id = entity_get_edict(ptd,EV_ENT_owner)
				
				if (is_user_connected(id) 
				&& is_user_connected(ptr) 
				&& is_user_alive(ptr) 
				&& player_b_smokehit[id] > 0
				&& get_user_team(id) != get_user_team(ptr))
				UTIL_Kill(id,ptr,"grenade")
			}
			
			
		}
		
	}
	
	
	/*if(equal(szClassName, "fireball"))
	{
		new Float:origin[3]
		pev(ptd,pev_origin,origin)
		new id = pev(ptd,pev_owner)
		Explode_Origin(id,origin,100,player_b_fireball[id] + player_intelligence[id])
		remove_entity(ptd)
	}*/
	
		
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public frozen_touch(entity, player)
{	
	//new kid = entity_get_edict(arrow, EV_ENT_owner)
	//new lid = entity_get_edict(arrow, EV_ENT_enemy)
	new owner = pev(entity,pev_owner)
	
	if(is_user_alive(player)) 
	{
		if(owner == player) return
		
		//entity_set_edict(arrow, EV_ENT_enemy,id)
	
		//new Float:dmg = entity_get_float(arrow,EV_FL_dmg)
		//entity_set_float(arrow,EV_FL_dmg,(dmg*3.0)/5.0)
		
		if((get_user_team(player) == get_user_team(owner)) || (player_class[player] == Frozen)) return
		
		//new Float:origin[3]
		//pev(ptd,pev_origin,origin)
		//Explode_Origin(owner,origin,player_intelligence[owner],125,1)
		if(is_frozen[player] == 0)
		{
			new Float:colddelay
			colddelay = player_intelligence[owner] * 0.2
			if(colddelay < 4.0) { colddelay = 4.0; }
			glow_player(player, colddelay, 0, 0, 255)
			set_user_maxspeed(player, 100.0)
			set_task(colddelay, "unfreeze", player, "", 0, "a", 1)
			is_frozen[player] = 1
			Display_Icon(player ,2 ,"dmg_cold" ,0,206,209)
			Create_ScreenFade( player, (1<<15), (1<<10), (1<<12), 0, 206, 209, 150 );
		}
		new dmg, Float:dmgsumm
		dmgsumm = (player_intelligence[owner]/1.25) - (player_dextery[player]/5.0)
		dmg = floatround(dmgsumm, floatround_ceil)
		if(dmg < 10) { dmg = 10; }
		change_health(player,-dmg,owner,"cold")
		remove_entity(entity)
		//emit_sound(owner, CHAN_STATIC, "diablo_lp/frozne_blast.wav", VOL_NULL, ATTN_NONE, SND_STOP, PITCH_NONE)
	}
}

public imp_touch(entity, player)
{
	new owner = pev(entity,pev_owner)
	
	if(is_user_alive(player)) 
	{
		if(owner == player) return
		
		if((get_user_team(player) == get_user_team(owner)) || (player_class[player] == Imp)) return
		
		if(is_fired[player] == 0)
		{
			new Float:colddelay
			colddelay = player_intelligence[owner] * 0.2
			if(colddelay < 4.0) { colddelay = 4.0; }
			glow_player(player, colddelay, 255, 188, 0)
			set_task(colddelay, "unfired", player, "", 0, "a", 1)
			is_fired[player] = 1
			Display_Icon(player ,2 ,"dmg_heat" ,255,188,0)
		}
		new dmg, Float:dmgsumm
		dmgsumm = (player_intelligence[owner]/1.25) - (player_dextery[player]/5.0)
		dmg = floatround(dmgsumm, floatround_ceil)
		if(dmg < 10) { dmg = 10; }
		change_health(player,-dmg,owner,"fire")
		remove_entity(entity)
	}
}

public unfreeze(id)
{
	is_frozen[id] = 0
	Display_Icon(id ,0 ,"dmg_cold" ,0,0,0)
	set_speedchange(id)
}

public unfired(id)
{
	is_fired[id] = 0
	Display_Icon(id ,0 ,"dmg_heat" ,0,0,0)
}

public unpoison(id)
{
	is_poisoned[id] = 0
	Display_Icon(id ,0 ,"dmg_gas" ,0,0,0)
	set_speedchange(id)
}

public untrap(id)
{
	is_trap_active[id] = 0
	set_speedchange(id)
}

public enablehook(id)
{
	spider_hook_disabled[id] = 0
}

public unslowweap(id)
{
	duriel_slowweap[id] = 0
}

/* ==================================================================================================== */

public Explode_Origin(id,Float:origin[3],damage,dist,index)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(3)
	write_coord(floatround(origin[0]))
	write_coord(floatround(origin[1]))
	write_coord(floatround(origin[2]))
	if(index == 1)
	{
		write_short(sprite_boom)
	}
	else if(index == 2)
	{
		write_short(sprite_boom)
	}
	write_byte(50)
	write_byte(15)
	write_byte(TE_EXPLFLAG_NOSOUND)
	message_end()
	if(index == 1)
	{
		engfunc(EngFunc_EmitAmbientSound, 0, origin, "diablo_lp/fireball3.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	else if(index == 2)
	{
		engfunc(EngFunc_EmitAmbientSound, 0, origin, "weapons/explode3.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	
	
	new Players[32], playerCount, a
	get_players(Players, playerCount, "ah") 
	
	for (new i=0; i<playerCount; i++) 
	{
		a = Players[i] 
		
		new Float:aOrigin[3]
		pev(a,pev_origin,aOrigin)
				
		if (get_user_team(id) != get_user_team(a) && get_distance_f(aOrigin,origin) < dist+0.0)
		{
			new dam
			if(player_class[id] != Fallen)
			{
				dam = damage-player_dextery[a]
			}
			else
			{
				new Float:dexterity = float(player_dextery[a])/4
				dam = damage - floatround(dexterity)
			}
			new total = get_user_health(a)-dam
			if (total < 5)
			{
				UTIL_Kill(id,a,"fire explode")
			}
			else
			{
				set_user_health(a,total)
				Effect_Bleed(a,248)		
			}	
		}		
	}
}

/* ==================================================================================================== */

public Timed_Healing()
{
	new Players[32], playerCount, a
	get_players(Players, playerCount, "ah") 
	
	for (new i=0; i<playerCount; i++) 
	{
		a = Players[i] 
		if (player_b_heal[a] <= 0)
			continue
		
		change_health(a,player_b_heal[a],0,"")
	}
}


/* ==================================================================================================== */

public Timed_Ghost_Check(id)
{
	if (ghost_check == true)
	{	
		new Globaltime = floatround(halflife_time())
		
		new Players[32], playerCount, a
		get_players(Players, playerCount, "h") 
		
		for (new i=0; i<playerCount; i++) 
		{
			a = Players[i] 
			
			if (ghoststate[a] == 2 && Globaltime - player_b_ghost[a] > ghosttime[a])
			{
				ghoststate[a] = 3
				ghosttime[a] = 0
				set_user_noclip(a,0)
				ghost_check = false
				new Float:aOrigin[3]
				entity_get_vector(a,EV_VEC_origin,aOrigin)	
				
				if (PointContents (aOrigin) != -1)
				{
					user_kill(a,1)	
				}
				else
				{
					aOrigin[2]+=10
					entity_set_vector(a,EV_VEC_origin,aOrigin)
				}
				
				
				
			}
			
		}
		
	}
}

public reset_item_skills(id)
{
	item_boosted[id] = 0
	item_durability[id] = 0
	jumps[id] = 0
	gravitytimer[id] = 0
	player_b_vampire[id] = 0	//Vampyric damage
	player_b_damage[id] = 0		//Bonus damage
	player_b_money[id] = 0		//Money bonus
	player_b_gravity[id] = 0	//Gravity bonus : 1 = best
	player_b_inv[id] = 0		//Invisibility bonus
	player_b_grenade[id] = 0	//Grenade bonus = 1/chance to kill
	player_b_reduceH[id] = 0	//Reduces player health each round start
	player_b_theif[id] = 0		//Amount of money to steal
	player_b_respawn[id] = 0	//Chance to respawn upon death
	player_b_explode[id] = 0	//Radius to explode upon death
	player_b_heal[id] = 0		//Ammount of hp to heal each 5 second
	player_b_blind[id] = 0		//Chance 1/Value to blind the enemy
	player_b_fireshield[id] = 0	//Protects against explode and grenade bonus 
	player_b_meekstone[id] = 0	//Ability to lay a fake c4 and detonate 
	player_b_teamheal[id] = 0	//How many hp to heal when shooting a teammate 
	player_b_redirect[id] = 0	//How much damage will the player redirect 
	player_b_fireball[id] = 0	//Ability to shot off a fireball value = radius *
	player_b_ghost[id] = 0		//Ability to walk through walls
	player_b_eye[id] = 0	         //Ability to snarkattack
	player_b_blink[id] = 0	//Abiliy to use railgun
	player_b_windwalk[id] = 0	//Ability to windwalk
	player_b_usingwind[id] = 0	//Is player using windwalk
	player_b_froglegs[id] = 0
	player_b_silent[id] = 0
	player_b_dagon[id] = 0		//Abliity to nuke opponents
	player_b_sniper[id] = 0		//Ability to kill faster with scout
	player_b_jumpx[id] = 0
	player_b_smokehit[id] = 0
	player_b_extrastats[id] = 0
	player_b_firetotem[id] = 0
	player_b_zamroztotem[id] = 0
	player_b_fleshujtotem[id] = 0
	player_b_wywaltotem[id] = 0
	player_b_m3master[id] = 0
	player_b_dglmaster[id] = 0
	player_b_awpmaster[id] = 0
	player_b_akmaster[id] = 0
	player_b_m4master[id] = 0
	player_b_kasatotem[id] = 0
	player_b_kasaqtotem[id] = 0
	player_b_hook[id] = 0
	player_b_darksteel[id] = 0
	player_b_illusionist[id] = 0
	player_b_mine[id] = 0
	player_b_antyarchy[id] = 0
	player_b_antymeek[id] = 0
	player_b_antyorb[id] = 0
	player_b_antyfs[id] = 0
	player_b_autobh[id] = 0
	player_b_radar[id] = 0
	player_b_godmode[id] = 0
	wear_sun[id] = 0
	player_sword[id] = 0 
	player_ultra_armor_left[id]=0
	player_ultra_armor[id]=0
}

public changeskin_id_1(id)
{
    if(zmiana_skinu[id] != 1)
	{
		changeskin(id,1)
	}
}
/* =================================================================================================== */




/* =====================================*/
/* ==================================================================================================== */

public auto_help(id)
{
	if(player_lvl[id]<8)
	{
		new rnd = random_num(1,6)
		set_hudmessage(0, 180, 0, -1.0, 0.70, 0, 10.0, 10.0, 0.1, 0.5, 11) 	
		if (rnd == 1)
		{
			show_hudmessage(id, "Зеленные бутылочки,рядом с трупами - это предметы,их можно подобрать нажав кнопку присесть")
		}
		if (rnd == 2)
		{
			show_hudmessage(id, "Чтобы сменить класс/герой набери в чате class,или say class в консоли")
		}
		if (rnd == 3)
		{
			show_hudmessage(id, "Вы можете получить более подоробную информацию набери в консоли say /help")
		}
		if (rnd == 4)
		{
			show_hudmessage(id, "Главное меню мода say /menu")
		}
		if (rnd == 5)
		{
			show_hudmessage(id, "За золото можно купить предметы,телепорты,улучшить/починить предметы,оружие")
		}
		if (rnd == 6)
		{
			show_hudmessage(id, "Золото вы получаете за хедшоты,её можно собрать на ежедневных ивентах")
		}
	}
}

/* ==================================================================================================== */

public helpme(id)
{	 
	//showitem(id,"Helpmenu","Common","None","Dostajesz przedmioty i doswiadczenie za zabijanie innych. Mozesz dostac go tylko wtedy, gdy nie masz na sobie innego<br><br>Aby dowiedziec sie wiecej o swoim przedmiocie napisz /przedmiot lub /item, a jak chcesz wyrzucic napisz /drop<br><br>Niektore przedmoty da sie uzyc za pomoca klawisza E<br><br>Napisz /czary zeby zobaczyc jakie masz staty<br><br>")
	show_motd(id, "http://lpstrike.ru/diablo_help.html", "Помощь Diablo Mod")
}


/* ==================================================================================================== */



/* ==================================================================================================== */

public komendy(id)
{
showitem(id,"Команды","Общий","Нет","<br>")
}

/* ==================================================================================================== */

public showitem(id,itemname[],itemvalue[],itemeffect[],Durability[])
{
	new diabloDir[64]	
	new g_ItemFile[64]
	
	format(diabloDir,63,"%s/diablo",amxbasedir)
	
	if (!dir_exists(diabloDir))
	{
		new errormsg[512]
		format(errormsg,511,"Error: Folder %s/diablo not exist",amxbasedir)
		show_motd(id, errormsg, "An error has occured")	
		return PLUGIN_HANDLED
	}
	
	
	format(g_ItemFile,63,"%s/diablo/item.txt",amxbasedir)
	if(file_exists(g_ItemFile))
		delete_file(g_ItemFile)
	
	new Data[768]
	
  //Header
	format(Data,767,"<html><head><title>Информация</title></head>")
	write_file(g_ItemFile,Data,-1)
	
	//Format
	format(Data,767,"<meta http-equiv='content-type' content='text/html; charset=UTF-8' />")
	write_file(g_ItemFile,Data,-1)
	
	//Background
	format(Data,767,"<body text='#FFFF00' bgcolor='#000000' background='http://dbstats.lpstrike.ru/server/drkmotr.jpg'>")
	write_file(g_ItemFile,Data,-1)
	
	//Table stuff
	format(Data,767,"<table border='0' cellpadding='0' cellspacing='0' style='border-collapse: collapse' width='100%s'><tr><td width='0'>","^%")
	write_file(g_ItemFile,Data,-1)
	
	//ss.gif image
	format(Data,767,"<p align='center'><img border='0' src='http://dbstats.lpstrike.ru/server/ss.gif'></td>")
	write_file(g_ItemFile,Data,-1)
	

	//item name
	format(Data,767,"<td width='0'><p align='center'><font face='Arial'><font color='#FFCC00'><b>Предмет: </b>%s</font><br>",itemname)
	write_file(g_ItemFile,Data,-1)
	
	//item value
	format(Data,767,"<font color='#FFCC00'><b><br>Значение: </b>%s</font><br>",itemvalue)
	write_file(g_ItemFile,Data,-1)
	
	//Durability
	format(Data,767,"<font color='#FFCC00'><b><br>Прочность: </b>%s</font><br><br>",Durability)
	write_file(g_ItemFile,Data,-1)
	
	//Effects
	format(Data,767,"<font color='#FFCC00'><b>Эффект:</b> %s</font></font></td>",itemeffect)
	write_file(g_ItemFile,Data,-1)
	
	//image ss
	format(Data,767,"<td width='0'><p align='center'><img border='0' src='http://dbstats.lpstrike.ru/server/gf.gif'></td>")
	write_file(g_ItemFile,Data,-1)
	
	//end
	format(Data,767,"</tr></table></body></html>")
	write_file(g_ItemFile,Data,-1)
	
	//show window with message
	show_motd(id, g_ItemFile, "Item инфо")
	
	return PLUGIN_HANDLED
	
}


/* ==================================================================================================== */

public iteminfo(id)
{
	new itemvalue[100]
	
	if (player_item_id[id] <= 10) itemvalue = "Обычный"
	if (player_item_id[id] <= 30) 
		itemvalue = "Редкий"
	else 
		itemvalue = "Необычный"
	
	if (player_item_id[id] > 42) itemvalue = "Уникальный"
	
	new itemEffect[200]
	
	new TempSkill[11]					//There must be a smarter way
	emit_sound(id,CHAN_STATIC,"diablo_lp/identify.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	if (player_b_vampire[id] > 0) 
	{
		num_to_str(player_b_vampire[id],TempSkill,10)
		add(itemEffect,199,"Высасывает ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," хп когда вы стреляете в противника<br>")
	}
	if (player_b_damage[id] > 0) 
	{
		num_to_str(player_b_damage[id],TempSkill,10)
		add(itemEffect,199,"Даёт ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," дополнительного урона с каждого выстрела<br>")
	}
	if (player_b_money[id] > 0) 
	{
		num_to_str(player_b_money[id],TempSkill,10)
		add(itemEffect,199,"Даёт $")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," + intelligene*50 денежный бонус каждый раунд. При нажатии Е активируется щит котрый снижает урон на 50%<br>")
	}
	if (player_b_gravity[id] > 0) 
	{
		num_to_str(player_b_gravity[id],TempSkill,10)
		add(itemEffect,199,"Гравитация увеличивается на ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,". Жми Е вы резко упадаете на землю и мгновенно убьёте врага на небольшом радиусе.<br>")
	}
	if(player_b_godmode[id] > 0)
	{
		num_to_str(player_b_godmode[id],TempSkill,10)
		add(itemEffect,199,"Используйте этот предмет чтобы стать бесмертным на ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," секунд.<br>")
	}
	if (player_b_inv[id] > 0) 
	{
		num_to_str(player_b_inv[id],TempSkill,10)
		add(itemEffect,199,"Твоя видимость снизится от 255 до ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"<br>")
	}
	if (player_b_grenade[id] > 0) 
	{
		num_to_str(player_b_grenade[id],TempSkill,10)
		add(itemEffect,199,"У тебя есть 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," шанс мгновенно убить врага с гранаты<br>")
	}
	if (player_b_reduceH[id] > 0) 
	{
		num_to_str(player_b_reduceH[id],TempSkill,10)
		add(itemEffect,199,"Твои жизни уменьшаются на ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," в начале каждого раунда, прочность не имеет значения<br>")
	}
	if (player_b_theif[id] > 0) 
	{
		num_to_str(player_b_theif[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/7 украсть $")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," каждый раз когда вы атакуете противника. Вы также можете нажать E чтобы конвертировать 1000$ в 15 хп<br>")
	}
	if (player_b_respawn[id] > 0) 
	{
		num_to_str(player_b_respawn[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," воскреснуть после смерти<br>")
	}
	if (player_b_explode[id] > 0) 
	{
		num_to_str(player_b_explode[id],TempSkill,10)
		add(itemEffect,199,"Когда вы умираете вы взрываетесь в радиусе ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," нанося 75 урона всем вокруг вас - intelligence увеличивает радиус item<br>")
	}
	if (player_b_heal[id] > 0) 
	{
		num_to_str(player_b_heal[id],TempSkill,10)
		add(itemEffect,199,"Вы получаете +")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," хп каждые 5 секунд. Жми E чтобы установить лечящий тотем на 7 секунд<br>")
	}
	if (player_b_gamble[id] > 0) 
	{
		num_to_str(player_b_gamble[id],TempSkill,10)
		add(itemEffect,199,"Вы получете случайный навык в начале каждого раунда разнообразие 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"<br>")
	}
	if (player_b_blind[id] > 0) 
	{
		num_to_str(player_b_blind[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ослепить проивника когда вы стреляете в него<br>")
	}
	if (player_b_fireshield[id] > 0) 
	{
		num_to_str(player_b_fireshield[id],TempSkill,10)
		add(itemEffect,199,"Уменьшает ваше здоровье, 20 хп каждые 2 секунды.<br>")
		add(itemEffect,199,"Вы не можете быть убиты chaos orb, hell orb или firerope.<br>")
		add(itemEffect,199,"При нажатии Е активируется щит котрый наносит урон противнику.<br>")
	}
	if (player_b_meekstone[id] > 0) 
	{
		num_to_str(player_b_meekstone[id],TempSkill,10)
		add(itemEffect,199,"Вы можете ставить фальшивую бомбу c4 нажатием клавишы E и взорвать ее снова нажав E<br>")
	}
	if(player_b_radar[id] > 0)
  {
        add(itemEffect, 199, "Вы видите противников на радаре.<br>");
  }
	if (player_b_teamheal[id] > 0) 
	{
		num_to_str(player_b_teamheal[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы активировать защиту игрока.<br>")
		add(itemEffect,199," Все повреждения отражаются. Вы умрёте если получите урон.")
	}
	if (player_b_redirect[id] > 0) 
	{
		num_to_str(player_b_redirect[id],TempSkill,10)
		add(itemEffect,199,"Вы получаете уменьшение урона на ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," хп<br>")
	}
	if (player_b_fireball[id] > 0) 
	{
		num_to_str(player_b_fireball[id],TempSkill,10)
		add(itemEffect,199,"Метание огненного шара нажатием клавишы E - Intelligence ускоряет item. Он убьет всех в радиусе ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"<br>")
	}
	if (player_b_ghost[id] > 0) 
	{
		num_to_str(player_b_ghost[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы ходить сквозь стены в течении ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," секунд<br>")
	}
	if(player_b_autobh[id] > 0)
  {
        add(itemEffect,199,"Даёт вам авто распрыжку. Удерживает в пространстве.")
  }
	if (player_b_eye[id] > 0) 
	{
		add(itemEffect,199,"Жми E чтобы установить волшебный глаз (только одно место доступно) и жми E снова чтобы использовать или остановить")
		
	}
	if (player_b_blink[id] > 0) 
	{
		add(itemEffect,199,"Вы можете телепортироваться альтернативной атаков если у вас в руках нож. Intelligence увеличивает дистанцию")
	}
	
	if (player_b_windwalk[id] > 0) 
	{
		num_to_str(player_b_windwalk[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы стать невидимым,вы не можете атаковать и скорость увеличиться на ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," секунд.<br>")
	}
	
	if (player_b_froglegs[id] > 0)
	{
		add(itemEffect,199,"Удерживайте назад +ПРИСЕСТЬ 3 секунды для длинного прыжка")
	}
	if (player_b_dagon[id] == 1)
	{
		add(itemEffect,199,"Жми E чтобы выстрелить молнией в ближайшего врага - ты можешь улучших этот item руной")
		add(itemEffect,199,"Intelligence увеличивает диапазон itema")
	}
	if (player_b_sniper[id] > 0) 
	{
		num_to_str(player_b_sniper[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," мгновенно убить со скаута<br>")
	}
	if (player_b_awpmaster[id] > 0) 
	{
		num_to_str(player_b_awpmaster[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"мгновенно убить противника с AWP<br>")
	}
	if (player_b_dglmaster[id] > 0) 
	{
		num_to_str(player_b_dglmaster[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"мгновенно убить противника с Deagle<br>")
	}
	if (player_b_m4master[id] > 0) 
	{
		num_to_str(player_b_m4master[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"мгновенно убить противника с M4A1<br>")
	}
	if (player_b_m3master[id] > 0) 
	{
		num_to_str(player_b_m3master[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"мгновенно убить противника с M3<br>")
	}
	if (player_b_akmaster[id] > 0) 
	{
		num_to_str(player_b_akmaster[id],TempSkill,10)
		add(itemEffect,199,"Шанс 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"мгновенно убить противника с AK47<br>")
	}
	if (player_b_jumpx[id] > 0)
	{
		num_to_str(player_b_jumpx[id],TempSkill,10)
		add(itemEffect,199,"Вы можете прыгать ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," раз  в воздух при нажатии кнопки прыжка<br>")	
	}
	if (player_b_smokehit[id] > 0)
	{
		add(itemEffect,199,"Ваши дымовые гранаты мгновенно убивают если они попали во врага")
	}
	if (player_b_extrastats[id] > 0)
	{
		num_to_str(player_b_extrastats[id],TempSkill,10)
		add(itemEffect,199,"Вы получите +")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," к статистике если у вас есть этот item")
	}
	if (player_b_firetotem[id] > 0)
	{
		num_to_str(player_b_firetotem[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы установить огненный тотем который взрывается после 7с. Он сожжёт всех в радиусе ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," тотема")
	}
	if (player_b_zamroztotem[id] > 0)
	{
		num_to_str(player_b_zamroztotem[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы установить тотем который замораживает противника.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_fleshujtotem[id] > 0)
	{
		num_to_str(player_b_fleshujtotem[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы установить тотем который ослепляет противника.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_wywaltotem[id] > 0)
	{
		num_to_str(player_b_wywaltotem[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы установить тотем который притягивает оружие противника.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_kasatotem[id] > 0)
	{
		num_to_str(player_b_kasatotem[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы установить тотем который даёт вам и вашей команде деньги.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_kasaqtotem[id] > 0)
	{
		num_to_str(player_b_kasaqtotem[id],TempSkill,10)
		add(itemEffect,199,"Жми E чтобы установить тотем который отнимает деньги врага(500$ в сек)")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_hook[id] > 0)
	{
		num_to_str(player_b_hook[id],TempSkill,10)
		add(itemEffect,199,"при нажатии E притягивает к себе врагав радиусе 600. Intelligence ускоряет hook")
	}
	if (player_b_darksteel[id] > 0)
	{		
		new ddam = floatround(player_strength[id]*2*player_b_darksteel[id]/10.0)*3

		num_to_str(player_b_darksteel[id],TempSkill,10)
		add(itemEffect,199,"Вы получите 15 + 0.")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"*strength: ")
		num_to_str(ddam,TempSkill,10)
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," бонуса урона когда вы атакуете врага сзади ")
	}
	if (player_b_antyarchy[id] > 0)
	{	
		add(itemEffect,199,"Защита от всех видов arch angel")
	}
	if (player_b_antyarchy[id] > 0)
	{	
		add(itemEffect,199,"Защита от всех видов Meekstone")
	}
	if (player_b_antyorb[id] > 0)
	{	
		add(itemEffect,199,"Вы устойчивы к взрывам")
	}
	if (player_b_antyfs[id] > 0)
	{	
		add(itemEffect,199,"У вас есть огнестойкий щит")
	}
	if (player_b_illusionist[id] > 0)
	{
		add(itemEffect,199,"при нажатии на Е вы становитесь полностью (100%)невидимым.Но и вы никого не видите и умираете от 1 выстрела. Эффект длится 5-7 секунд.")
	}
	if (player_b_mine[id] > 0)
	{
		add(itemEffect,199,"Жми E чтобы устанвоить почти невидимую мину. Каждая мина взрывается нанося 50hp+intelligece урона. 3 Мины каждый раунд доступны.")
	}
	if (player_item_id[id]==66)
	{
		add(itemEffect,199,"Вы похожи на врага!")
	}
	if (player_ultra_armor[id]>0)
	{
		add(itemEffect,199,"У вас есть шанс отбрасывать пули от бронежелета")
	}
	
	
	new Durability[10]
	num_to_str(item_durability[id],Durability,9)
	if (equal(itemEffect,"")) showitem(id,"Нет","Нет","Нужно кого-нибудь убить,чтобы получить предмет или купить (/rune)","Нет")
	if (!equal(itemEffect,"")) showitem(id,player_item_name[id],itemvalue,itemEffect,Durability)
	
}

/* ==================================================================================================== */

public award_item(id, itemnum)
{
	if (player_item_id[id] != 0)
		return PLUGIN_HANDLED
	
	set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 8.0, 0.2, 0.3, 5)
	new rannum = random_num(1,125)
	
	new maxfind = player_agility[id]
	if (maxfind > 15) maxfind = 15
	
	new rf = random_num(1,25-maxfind)
	
	if (itemnum > 0) rannum = itemnum
	else if (itemnum < 0) return PLUGIN_HANDLED
		
	if (rf == 3 && itemnum == 0)						//We found a rare item			
	{
		award_unique_item(id)	
		rannum = -1
	}
	
	//Set durability, make this item dependant?
	item_durability[id] = 250
	emit_sound(id,CHAN_STATIC,"diablo_lp/ring.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	switch(rannum)
	{
		case 1:
		{
			player_item_name[id] = "Bronze Amplifier"
			player_item_id[id] = rannum
			player_b_damage[id] = random_num(1,3)
			show_hudmessage(id, "Вы нашли item: %s ::  +%i дополнительного урона с каждого выстрела.",player_item_name[id],player_b_damage[id])
		}
		
		case 2:
		{
			player_item_name[id] = "Silver Amplifier"
			player_item_id[id] = rannum
			player_b_damage[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: +%i дополнительного урона с каждого выстрела.",player_item_name[id],player_b_damage[id])
		}
		
		case 3:
		{
			player_item_name[id] = "Gold Amplifier"
			player_item_id[id] = rannum
			player_b_damage[id] = random_num(6,10)
			show_hudmessage(id, "Вы нашли item: %s :: +%i дополнительного урона с каждого выстрела.",player_item_name[id],player_b_damage[id])	
		}
		case 4:
		{
			player_item_name[id] = "Vampyric Staff"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(1,4)
			show_hudmessage(id, "Вы нашли item: %s :: %i hp высасывает с каждого выстрела.",player_item_name[id],player_b_vampire[id])	
		}
		case 5:
		{
			player_item_name[id] = "Vampyric Amulet"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(4,6)
			show_hudmessage(id, "Вы нашли item: %s :: %i hp высасывает с каждого выстрела.",player_item_name[id],player_b_vampire[id])	
		}
		case 6:
		{
			player_item_name[id] = "Vampyric Scepter"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(6,9)
			show_hudmessage(id, "Вы нашли item: %s :: %i hp высасывает с каждого выстрела.",player_item_name[id],player_b_vampire[id])	
		}
		case 7:
		{
			player_item_name[id] = "Small bronze bag"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(150,500)
			show_hudmessage(id, "Вы нашли item: %s :: +%i каждый раунд + При нажатии Е активируется щит котрый снижает урон по вам на 50% жрущий по 200$ каждые 2-3 секунды.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 8:
		{
			player_item_name[id] = "Medium silver bag"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(500,1200)
			show_hudmessage(id, "Вы нашли item: %s :: +%i каждый раунд + При нажатии Е активируется щит котрый снижает урон по вам на 50% жрущий по 200$ каждые 2-3 секунды.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 9:
		{
			player_item_name[id] = "Large gold bag"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(1200,3000)
			show_hudmessage(id, "Вы нашли item: %s :: +%i каждый раунд + При нажатии Е активируется щит котрый снижает урон по вам на 50% жрущий по 200$ каждые 2-3 секунды.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 10:
		{
			player_item_name[id] = "Small angel wings"
			player_item_id[id] = rannum
			player_b_gravity[id] = random_num(1,5)
			
			if (is_user_alive(id))
				set_gravitychange(id)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i бонус к гравитации при прыжке и нажатии Е резко падает на землю и мгновенно убивает врага на небольшом радиусе.",player_item_name[id],player_b_gravity[id])	
		}
		case 11:
		{
			player_item_name[id] = "Arch angel wings"
			player_item_id[id] = rannum
			player_b_gravity[id] = random_num(5,9)
			
			if (is_user_alive(id))
				set_gravitychange(id)
				
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i бонус к гравитации при прыжке и нажатии Е резко падает на землю и мгновенно убивает врага на среднем радиусе.",player_item_name[id],player_b_gravity[id])	
			
		}
		case 12:
		{
			player_item_name[id] = "Invisibility Rope"
			player_item_id[id] = rannum
			player_b_inv[id] = random_num(150,200)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i незначительную прозрачность чара.",player_item_name[id],255-player_b_inv[id])	
		}
		case 13:
		{
			player_item_name[id] = "Invisibility Coat"
			player_item_id[id] = rannum
			player_b_inv[id] = random_num(110,150)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i незначительную прозрачность чара.",player_item_name[id],255-player_b_inv[id])	
		}
		case 14:
		{
			player_item_name[id] = "Invisibility Armor"
			player_item_id[id] = rannum
			player_b_inv[id] = random_num(70,110)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i незначительную прозрачность чара.",player_item_name[id],255-player_b_inv[id])	
		}
		case 15:
		{
			player_item_name[id] = "Firerope"
			player_item_id[id] = rannum
			player_b_grenade[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: +1/%i  шанс мгновенно убить врага с гранаты",player_item_name[id],player_b_grenade[id])	
		}
		case 16:
		{
			player_item_name[id] = "Fire Amulet"
			player_item_id[id] = rannum
			player_b_grenade[id] = random_num(2,4)
			show_hudmessage(id, "Вы нашли item: %s :: +1/%i  шанс мгновенно убить врага с гранаты",player_item_name[id],player_b_grenade[id])	
		}
		case 17:
		{
			player_item_name[id] = "Stalkers ring"
			player_item_id[id] = rannum
			player_b_reduceH[id] = 95
			player_b_inv[id] = 8	
			item_durability[id] = 100
			
			if (is_user_alive(id)) set_user_health(id,5)		
			show_hudmessage(id, "Вы нашли item: %s :: практически полная невидимость, но у вас 5 хп и из оружия только нож, можно ставить бомбу.",player_item_name[id])	
		}
		case 18:
		{
			player_item_name[id] = "Arabian Boots"
			player_item_id[id] = rannum
			player_b_theif[id] = random_num(500,1000)
			show_hudmessage(id, "Вы нашли item: %s :: с каждым выстрелом высасывает с противника деньги, в зависимости от дамага",player_item_name[id],player_b_theif[id])	
		}
		case 19:
		{
			player_item_name[id] = "Phoenix Ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i воскреситься после смерти.",player_item_name[id],player_b_respawn[id])	
		}
		case 20:
		{
			player_item_name[id] = "Sorcerers ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = random_num(2,3)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i воскреситься после смерти.",player_item_name[id],player_b_respawn[id])	
		}
		case 21:
		{
			player_item_name[id] = "Chaos Orb"
			player_item_id[id] = rannum
			player_b_explode[id] = random_num(150,275)
			show_hudmessage(id, "Вы нашли item: %s :: после смерти взрываетесь в радиусе %i",player_item_name[id],player_b_explode[id])	
		}
		case 22:
		{
			player_item_name[id] = "Hell Orb"
			player_item_id[id] = rannum
			player_b_explode[id] = random_num(200,400)
			show_hudmessage(id, "Вы нашли item: %s :: после смерти взрываетесь в радиусе %i",player_item_name[id],player_b_explode[id])	
		}
		case 23:
		{
			player_item_name[id] = "Gold statue"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(5,10)
			show_hudmessage(id, "Вы нашли item: %s :: При нажатии на Е появляется тотем, котрый лечит вас и вашу команду. %i хп за 5 секунд, тотем активен в течении 7 секунд в пределах %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 24:
		{
			player_item_name[id] = "Daylight Diamond"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(10,20)
			show_hudmessage(id, "Вы нашли item: %s :: При нажатии на Е появляется тотем, котрый лечит вас и вашу команду. %i хп за 5 секунд, тотем активен в течении 7 секунд в пределах %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 25:
		{
			player_item_name[id] = "Blood Diamond"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "Вы нашли item: %s :: При нажатии на Е появляется тотем, котрый лечит вас и вашу команду. %i хп за 5 секунд, тотем активен в течении 7 секунд в пределах %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 26:
		{
			player_item_name[id] = "Wheel of Fortune"
			player_item_id[id] = rannum
			player_b_gamble[id] = random_num(2,3)
			show_hudmessage(id, "Вы нашли item: %s :: даёт рандомно +%i бонусов каждый раунд.",player_item_name[id],player_b_gamble[id])	
		}
		case 27:
		{
			player_item_name[id] = "Four leaf Clover"
			player_item_id[id] = rannum
			player_b_gamble[id] = random_num(4,5)
			show_hudmessage(id, "Вы нашли item: %s :: даёт рандомно +%i бонусов каждый раунд.",player_item_name[id],player_b_gamble[id])	
		}
		case 28:
		{
			player_item_name[id] = "Amulet of the sun"
			player_item_id[id] = rannum
			player_b_blind[id] = random_num(6,9)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i ослепить противника при атаке. Экран становиться почти польностью оранжевым в течении 7-10 секунд",player_item_name[id],player_b_blind[id])	
		}
		case 29:
		{
			player_item_name[id] = "Sword of the sun"
			player_item_id[id] = rannum
			player_b_blind[id] = random_num(2,5)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i ослепить противника при атаке. Экран становиться почти польностью оранжевым в течении 7-10 секунд",player_item_name[id],player_b_blind[id])	
		}
		case 30:
		{
			player_item_name[id] = "Fireshield"
			player_item_id[id] = rannum
			player_b_fireshield[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии Е активируется щит который наносит дамаг противнику. Уменьшает ваше здоровье, 20 хп каждые 2 секунды.",player_item_name[id],player_b_fireshield[id])	
		}
		case 31:
		{
			player_item_name[id] = "Stealth Shoes"
			player_item_id[id] = rannum
			player_b_silent[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: бесшумный шаг (эфект рассы Ассассин).",player_item_name[id])	
		}
		case 32:
		{
			player_item_name[id] = "Meekstone"
			player_item_id[id] = rannum
			player_b_meekstone[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: бомба на дистанционом управлении. Е положить бомбу, второе нажатие Е взорвать.",player_item_name[id])	
		}
		case 33:
		{
			player_item_name[id] = "Medicine Glar"
			player_item_id[id] = rannum
			player_b_teamheal[id] = random_num(10,20)
			show_hudmessage(id, "Вы нашли item: %s :: При атаке в сокомандника востанавливается %i хп. при нажатии Е активирует на члене команды щит котрый возвращает дамаг.",player_item_name[id],player_b_teamheal[id])	
		}
		case 34:
		{
			player_item_name[id] = "Medicine Totem"
			player_item_id[id] = rannum
			player_b_teamheal[id] = random_num(20,30)
			show_hudmessage(id, "Вы нашли item: %s :: При атаке в сокомандника востанавливается %i хп. при нажатии Е активирует на члене команды щит котрый возвращает дамаг.",player_item_name[id],player_b_teamheal[id])	
		}
		case 35:
		{
			player_item_name[id] = "Iron Armor"
			player_item_id[id] = rannum
			player_b_redirect[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: снижает +%i дамага по вам с каждого выстрела.",player_item_name[id],player_b_redirect[id])	
		}
		case 36:
		{
			player_item_name[id] = "Mitril Armor"
			player_item_id[id] = rannum
			player_b_redirect[id] = random_num(6,11)
			show_hudmessage(id, "Вы нашли item: %s :: снижает +%i дамага по вам с каждого выстрела.",player_item_name[id],player_b_redirect[id])	
		}
		case 37:
		{
			player_item_name[id] = "Godly Armor"
			player_item_id[id] = rannum
			player_b_redirect[id] = random_num(10,15)
			show_hudmessage(id, "Вы нашли item: %s :: снижает +%i дамага по вам с каждого выстрела.",player_item_name[id],player_b_redirect[id])	
		}
		case 38:
		{
			player_item_name[id] = "Fireball staff"
			player_item_id[id] = rannum
			player_b_fireball[id] = random_num(50,100)
			show_hudmessage(id, "Вы нашли item: %s :: Запускает огненный шар, взрывающийся в радиусе %i",player_item_name[id],player_b_fireball[id])	
		}
		case 39:
		{
			player_item_name[id] = "Fireball scepter"
			player_item_id[id] = rannum
			player_b_fireball[id] = random_num(100,200)
			show_hudmessage(id, "Вы нашли item: %s :: Запускает огненный шар, взрывающийся в радиусе %i",player_item_name[id],player_b_fireball[id])	
		}
		case 40:
		{
			player_item_name[id] = "Ghost Rope"
			player_item_id[id] = rannum
			player_b_ghost[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: Возможность ходить сквозь стены, эфект длиться %i секунд",player_item_name[id],player_b_ghost[id])	
		}
		case 41:
		{
			player_item_name[id] = "Nicolas Eye"
			player_item_id[id] = rannum
			player_b_eye[id] = -1
			show_hudmessage(id, "Вы нашли item: %s :: Устанавливает камеру на стене.",player_item_name[id])	
		}
		case 42:
		{
			player_item_name[id] = "Knife Ruby"
			player_item_id[id] = rannum
			player_b_blink[id] = floatround(halflife_time())
			show_hudmessage(id, "Вы нашли item: %s :: при использовании ножа второй конопкой телепортирует вас на небольшое растояние",player_item_name[id])	
		}
		case 43:
		{
			player_item_name[id] = "Lothars Edge"
			player_item_id[id] = rannum
			player_b_windwalk[id] = random_num(4,7)
			show_hudmessage(id, "Вы нашли item: %s :: на %i секунд даёт среднюю прозрачность + сильно увеличивает ваш бег.",player_item_name[id],player_b_windwalk[id])	
		}
		case 44:
		{
			player_item_name[id] = "Sword"
			player_item_id[id] = rannum
			player_sword[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: увеличивает урон ножу",player_item_name[id])		
		}
		case 45:
		{
			player_item_name[id] = "Mageic Booster"
			player_item_id[id] = rannum
			player_b_froglegs[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: каждые 3 секунды сидя вы очень длинно прыгаете.(item не всегда работает)",player_item_name[id])	
		}
		case 46:
		{
			player_item_name[id] = "Dagon I"
			player_item_id[id] = rannum
			player_b_dagon[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии USE наносит дамаг противнику на близком растоянии раз в 20 секунд",player_item_name[id])	
		}
		case 47:
		{
			player_item_name[id] = "Scout Extender"
			player_item_id[id] = rannum
			player_b_sniper[id] = random_num(3,4)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i мгновенно убить со скаута.",player_item_name[id],player_b_sniper[id])	
		}
		case 48:
		{
			player_item_name[id] = "Scout Amplifier"
			player_item_id[id] = rannum
			player_b_sniper[id] = random_num(2,3)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i мгновенно убить со скаута.",player_item_name[id],player_b_sniper[id])	
		}
		case 49:
		{
			player_item_name[id] = "Air booster"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: Вы можете сделать двойной прыжок в воздухе",player_item_name[id],player_b_sniper[id])	
		}
		case 50:
		{
			player_item_name[id] = "Iron Spikes"
			player_item_id[id] = rannum
			player_b_smokehit[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: убивает дымовой гранатой, если попасть ей в противника",player_item_name[id])	
		}
		case 51:
		{
			player_item_name[id] = "Point Booster"
			player_item_id[id] = rannum
			player_b_extrastats[id] = random_num(1,3)
			BoostStats(id,player_b_extrastats[id])
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i очков к каждому умнению",player_item_name[id],player_b_extrastats[id])	
		}
		case 52:
		{
			player_item_name[id] = "Totem amulet"
			player_item_id[id] = rannum
			player_b_firetotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии на Е ставит жёлтый тотем который через несколько секунд взрывается и поджигает всех в большом радиусе.",player_item_name[id])	
		}
		case 53:
		{
			player_item_name[id] = "Mageic Hook"
			player_item_id[id] = rannum
			player_b_hook[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии USE притягивает к себе врага",player_item_name[id])	
		}
		case 54:
		{
			player_item_name[id] = "Darksteel Glove"
			player_item_id[id] = rannum
			player_b_darksteel[id] = random_num(1,5)
			show_hudmessage(id, "Вы нашли item: %s :: усиленный дамаг при атаке противника со спины.",player_item_name[id])	
		}
		case 55:
		{
			player_item_name[id] = "Darksteel Gaunlet"
			player_item_id[id] = rannum
			player_b_darksteel[id] = random_num(7,9)
			show_hudmessage(id, "Вы нашли item: %s :: усиленный дамаг при атаке противника со спины.",player_item_name[id])	
		}
		case 56:
		{
			player_item_name[id] = "Illusionists Cape"
			player_item_id[id] = rannum
			player_b_illusionist[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии на Е вы становитесь полностью (100%)невидимым. однако и вы никого не видите и умираете от 1 выстрела.",player_item_name[id])	
		}
		case 57:
		{
			player_item_name[id] = "Techies scepter"
			player_item_id[id] = rannum
			player_b_mine[id] = 3
			show_hudmessage(id, "Вы нашли item: %s :: ставит 3 полуневидимые мины.",player_item_name[id])
		}
		
		case 58:
		{
			player_item_name[id] = "Ninja ring"
			player_item_id[id] = rannum
			player_b_blink[id] = floatround(halflife_time())
			player_b_froglegs[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: Нож позволяет вам телепортироваться каждые 3 секунды. Зажмите DUCK чтобы прыгнуть далеко.",player_item_name[id])
		}
		case 59:	
		{
			player_item_name[id] = "Mage ring"
			player_item_id[id] = rannum
			player_ring[id]=1
			player_b_fireball[id] = random_num(50,80)
			show_hudmessage(id, "Вы нашли item : %s :: Возможность стрелять огненными шарами +5 интеллект",player_item_name[id])
		}	
		case 60:	
		{
			player_item_name[id] = "Necromant ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = random_num(2,4)
			player_b_vampire[id] = random_num(3,5)	
			show_hudmessage(id, "Вы нашли item : %s :: Шанс возродиться после смерти. При попадании во врага, частично восполняет ваше НР",player_item_name[id])
		}
		case 61:
		{
			player_item_name[id] = "Barbarian ring"
			player_item_id[id] = rannum
			player_b_explode[id] = random_num(120,330)
			player_ring[id]=2
			show_hudmessage(id, "Вы нашли item : %s :: Когда вас убивают вы взрываетесь, нанося урон стоящим в близи врагам. +5 сила",player_item_name[id])
		}
		case 62:
		{
			player_item_name[id] = "Paladin ring"
			player_item_id[id] = rannum	
			player_b_redirect[id] = random_num(7,17)
			player_b_blind[id] = random_num(3,4)
			show_hudmessage(id, "Вы нашли item : %s :: Снижение дамага по вам. Шанс ослепить противника",player_item_name[id])		
		}
		case 63:
		{
			player_item_name[id] = "Monk ring"
			player_item_id[id] = rannum	
			player_b_grenade[id] = random_num(1,4)
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "Вы нашли item : %s :: Увиличивает урон наносимый гранатой. Восстанавливает здоровье",player_item_name[id])
		}	
		case 64:
		{
			player_item_name[id] = "Assassin ring"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 1
			player_ring[id]=3
			show_hudmessage(id, "Вы нашли item : %s :: Двойной прыжок. +5 ловкость",player_item_name[id])	
		}	
		case 65:
		{
			player_item_name[id] = "Flashbang necklace"	
			player_item_id[id] = rannum	
			wear_sun[id] = 1
			show_hudmessage (id, "Вы нашли item : %s :: Иммунитет к ослепляющим гранатам",player_item_name[id])
		}
		case 66:
		{
			player_item_name[id] = "Chameleon"	
			player_item_id[id] = 66	
			changeskin(id,0)  
			show_hudmessage (id, "Вы нашли item : %s :: Превращение во врага (внешний вид)",player_item_name[id])
		}
		case 67:
		{
			player_item_name[id] = "Stong Armor"	
			player_item_id[id] = 67	
			player_ultra_armor[id]=random_num(3,6)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "Вы нашли item : %s :: Каждый раунд броня становится равной %i",player_item_name[id],player_ultra_armor[id])
		}
		case 68:
		{
			player_item_name[id] = "Ultra Armor"	
			player_item_id[id] = 68	
			player_ultra_armor[id]=random_num(7,11)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "Вы нашли item : %s :: Каждый раунд броня становится равной %i",player_item_name[id],player_ultra_armor[id])
		}
		case 69:
		{
			player_item_name[id] = "Khalim Eye"
			player_item_id[id] = rannum
			player_b_radar[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Вы видите противников на радаре", player_item_name[id])
		}
		case 70:
		{
			player_item_name[id] = "Leaper Ring"
			player_item_id[id] = rannum
			player_b_autobh[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Даёт вам авто распрыжку. Удерживает в пространстве.", player_item_name[id])
		}
		case 71:
		{
			player_item_name[id] = "Myrmidon Greaves"
			player_item_id[id] = rannum
			player_b_silent[id] = 1
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/2)
			show_hudmessage (id, "Вы нашли item : %s :: Бесшумный и быстрый бег",player_item_name[id],player_b_silent[id])
		}
		case 72:
		{
			player_item_name[id] = "Shoes of the Bone"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 4
			set_user_gravity(id, 600.0)
			show_hudmessage (id, "Вы нашли item : %s :: Вы можете сделать 4 прыжка в воздухе. Уменьшенна гравитация",player_item_name[id],player_b_jumpx[id])
		}
		case 73:
		{
			player_item_name[id] = "Scarab Shoes"
			player_item_id[id] = rannum
			player_b_inv[id] = 95
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "Вы нашли item : %s :: Ваш видимость снижается до 95. Быстрый бег.",player_item_name[id],player_b_inv[id])
		}
		case 74:
		{
			player_item_name[id] = "Hydra Blade"
			player_item_id[id] = rannum
			player_b_inv[id] = 155
			player_b_damage[id] = 20
			show_hudmessage (id, "Вы нашли item : %s :: Ваш видимость снижается до 155 +20 к урону",player_item_name[id],player_b_inv[id],player_b_damage[id])
		}
		case 75:
		{
			player_item_name[id] = "Exp Ring"
			player_item_id[id] = rannum
			new xp_award = get_cvar_num("diablo_xpbonus")*2
			show_hudmessage (id, "Вы нашли item : %s :: Удваивание опыта на %i",player_item_name[id],xp_award)
		}
		case 76:
		{
			player_item_name[id] = "Aegis"
			player_item_id[id] = rannum
			player_ring[id]=2
			player_b_explode[id] = random_num(120,330)
			player_b_redirect[id] = random_num(10, 100)
			show_hudmessage (id, "Вы нашли item : %s :: Вы получаете +5 к силе и взрываетесь когда умираете(урон %i) -%i урона по вам",player_item_name[id],player_b_explode[id],player_b_redirect[id])
		}
		case 77:
		{
			player_item_name[id] = "Polished Wand"
			player_item_id[id] = rannum
			player_b_blind[id] = random_num(1,5)
			player_b_heal[id] =  random_num(1,15)
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/%i ослепить врага, жми E чтобы установить исцеляющий тотем",player_item_name[id],player_b_blind[id])
		}
		case 78:
		{
			player_item_name[id] = "Heavenly Stone"
			player_item_id[id] = rannum
			player_b_grenade[id] = random_num(1,3)
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить HE гранаты и быстрый бег",player_item_name[id],player_b_grenade[id])
		}
		case 79:
		{
			player_item_name[id] = "Festering Essence of Destruction"
			player_item_id[id] = rannum
			player_b_respawn[id] = 2
			player_b_sniper[id] = 1
			player_b_grenade[id] = 3
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/2 возродится, шанс 1/1 мгновенно убить со скаута,шанс 1/3 убить с HE",player_item_name[id])
		}
		case 80:
		{
			player_item_name[id] = "Vampire Gloves"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(5,15)
			show_hudmessage(id, "Вы нашли item : %s :: Высасывает %i за каждое попадание во врага,за убийство +30hp",player_item_name[id],player_b_vampire[id])
		}
		case 81:
		{
			player_item_name[id] = "Super Mario"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 10
			player_b_fireball[id] = 5
			show_hudmessage (id, "Вы нашли item : %s :: Вы можете сделать 10 прыжков в воздух и пускать до 5 огненных шаров",player_item_name[id],player_b_jumpx[id], player_b_fireball[id])
		}
		case 85:
		{
			player_item_name[id] = "Centurion"
			player_item_id[id] = rannum
			player_b_damage[id] = 20
			player_b_redirect[id] = 40
			set_user_gravity(id,3.0)
			show_hudmessage (id, "Вы нашли item : %s :: +20 к урону и уменьшение урона на 40",player_item_name[id],player_b_damage[id],player_b_redirect[id])
		}
		case 86:
		{
			player_item_name[id] = "RedBull"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 8
			show_hudmessage(id, "Вы нашли item : %s :: Вы можете сделать 8 прыжков в воздухе",player_item_name[id],player_b_sniper[id])	
		}
		case 87:
		{
			player_item_name[id] = "Dr House"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(45,65)
			show_hudmessage(id, "Вы нашли item : %s :: Восстанавливает %i hp каждые 5 секунд. Жмите Е чтобы установить лечящий тотем %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 88:
		{
			player_item_name[id] = "Own Invisible"
			player_item_id[id] = rannum
			player_b_inv[id] = 8
			player_b_reduceH[id] = 55
			if (is_user_alive(id)) set_user_health(id,45)
			show_hudmessage(id, "Вы нашли item : %s :: Вы почти невидимы,но у вас 45 HP.",player_item_name[id])	
		}
		case 89:
		{
			player_item_name[id] = "Mega Invisible"
			player_item_id[id] = rannum
			player_b_reduceH[id] = 90
			player_b_inv[id] = 1	
			item_durability[id] = 50
			
			if (is_user_alive(id)) set_user_health(id,10)		
			show_hudmessage(id, "Вы нашли item : %s :: У вас 10 жизней,невидимость 1/255",player_item_name[id])	
		}
		case 90:
		{
			player_item_name[id] = "Bul'Kathos Shoes"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 8
			set_user_gravity(id, 400.0)
			show_hudmessage(id, "Вы нашли item : %s :: Вы можете сделать 8 прыжков в воздухе и у вас высокая гравитация",player_item_name[id],player_b_sniper[id])	
		}
		case 91:
		{
			player_item_name[id] = "Karik's Ring"
			player_item_id[id] = rannum	
			player_b_redirect[id] = random_num(15,50)
			player_b_damage[id] = random_num(15,50)
			player_b_blind[id] = random_num(3,4)
			player_ultra_armor[id]=random_num(15,50)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage(id, "Вы нашли item : %s :: Item настолько мощный,что никто ещё не познал его волшебное действия",player_item_name[id])		
		}
		case 92:
		{
			player_item_name[id] = "Purse Thief"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(1,16000)
			show_hudmessage(id, "Вы нашли item : %s :: получаете %i денег в каждом раунде. Используйте чтобы защищаться.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)
		}
		case 93:
		{
			player_item_name[id] = "Vampiric Blood"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(15,20)
			show_hudmessage(id, "Вы нашли item : %s :: высасываете %i hp у противника",player_item_name[id],player_b_vampire[id])	
		}
		case 94:
		{
			player_item_name[id] = "Revival Ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: 1/%i шанс на возраждение",player_item_name[id],player_b_respawn[id])	
		}
		case 95:
		{
			player_item_name[id] = "Demon Assassin"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(30,55)
			player_b_damage[id] = 50
			show_hudmessage(id, "Вы нашли item : %s :: Восстанавливает %i hp каждые 5 секунд. Жмите Е чтобы установить лечащий тотем %i. +50 к урону",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 96:
		{
			player_item_name[id] = "Mystiqe"	
			player_item_id[id] = rannum
			changeskin(id,0)
			player_b_grenade[id] = random_num(1,2)
			show_hudmessage (id, "Вы нашли item : %s :: Ты выглядишь как противник.Шанс 1/%i мгновенно убить с гранаты HE",player_item_name[id],player_b_grenade[id])
		}
		case 97:
		{
			player_item_name[id] = "Apocalypse Anihilation"
			player_item_id[id] = rannum
			player_b_damage[id] = 100
			player_b_silent[id] = 1
			item_durability[id] = 100
			show_hudmessage (id, "Вы нашли item : %s :: Вы на носите %i урона с каждого выстрела.Бесшумный бег.",player_item_name[id],player_b_damage[id],player_b_silent[id])
		}
		case 98:
		{
			player_item_name[id] = "Inferno"
			player_item_id[id] = rannum
			player_b_redirect[id] = 10
			player_b_damage[id] = 10
			player_b_respawn[id] = 2
			show_hudmessage (id, "Вы нашли item : %s :: +10 к урону. -10 урона по вам. Шанс 1/2 возродится.",player_item_name[id])
		}
		case 99:
		{
			player_item_name[id] = "Hellspawn"
			player_item_id[id] = rannum
			player_b_grenade[id] = 5
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/5 убить с НЕ гранаты.+%i к невидимости",player_item_name[id],255-player_b_inv[id])
		}
		case 100:
		{
			player_item_name[id] = "Shako"
			player_item_id[id] = rannum
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "Вы нашли item : %s :: +25урона || +%i к невидимости",player_item_name[id],255-player_b_inv[id])
		}
		case 101:
		{
			player_item_name[id] = "Annihilus"
			player_item_id[id] = rannum
			player_b_damage[id] = 15
			player_b_vampire[id] = 50
			show_hudmessage (id, "Вы нашли item : %s :: +15 к урону. Высасывает 50hp с каждого выстрела",player_item_name[id])
		}
		case 102:
		{
			player_item_name[id] = "Blizzard's Mystery"
			player_item_id[id] = rannum
			player_b_damage[id] = 25
			player_b_vampire[id] = 25
			item_durability[id] = 100
			show_hudmessage (id, "Вы нашли item : %s :: +25 к урону. Высасывает 25 HP с каждого выстрела",player_item_name[id])
		}
		case 103:
		{
			player_item_name[id] = "Mara's Kaleidoscope"
			player_item_id[id] = rannum
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(190,200)
			show_hudmessage (id, "Вы нашли item : %s :: +25 к урону. +%i к невидимости",player_item_name[id],255-player_b_inv[id])
		}
		case 104:
		{
			player_item_name[id] = "M4A1 Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_m4master[id] = random_num(5,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с M4A1",player_item_name[id],player_b_m4master[id])
		}
		case 105:
		{
			player_item_name[id] = "AK47 Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_akmaster[id] = random_num(5,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с AK47",player_item_name[id],player_b_akmaster[id])
		}
		case 106:
		{
			player_item_name[id] = "AWP Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_awpmaster[id] = random_num(3,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с AWP",player_item_name[id],player_b_awpmaster[id])
		}
		case 107:
		{
			player_item_name[id] = "Deagle Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_dglmaster[id] = random_num(5,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с Deagle",player_item_name[id],player_b_dglmaster[id])
		}
		case 108:
		{
			player_item_name[id] = "M3 Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_m3master[id] = random_num(3,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с M3",player_item_name[id],player_b_m3master[id])
		}
		case 109:
		{
			player_item_name[id] = "Full Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_m3master[id] = random_num(3,8)
			player_b_dglmaster[id] = random_num(5,8)
			player_b_awpmaster[id] = random_num(3,8)
			player_b_akmaster[id] = random_num(5,8)
			player_b_m4master[id] = random_num(5,8)
			player_b_grenade[id] = random_num(3,8)
			player_b_sniper[id] = random_num(3,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с M3,1/%i с Deagle,1/%i с AWP,1/%i с AK47,1/%i с M4A1,1/%i с HE,1/%i с скаута",player_item_name[id],player_b_m3master[id],player_b_dglmaster[id],player_b_awpmaster[id],player_b_akmaster[id],player_b_m4master[id],player_b_grenade[id],player_b_sniper[id])
		}
		case 110:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 111:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 112:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 113:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 114:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		
		case 115:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 116:
		{
			player_item_name[id] = "Diablo Shoes"
			player_item_id[id] = rannum
			player_b_antyarchy[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защитится от Arch angel", player_item_name[id], player_b_antyarchy[id])
		}
		case 117:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 118:
		{
			player_item_name[id] = "Anti Explosion"
			player_item_id[id] = rannum
			player_b_antyorb[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защитится от взрыва после убийства", player_item_name[id], player_b_antyorb[id])
		}
		case 119:
		{
			player_item_name[id] = "Anti HellFlare"
			player_item_id[id] = rannum
			player_b_antyfs[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от огня", player_item_name[id], player_b_antyfs[id])
		}
		case 120:
		{
			player_item_name[id] = "Gheed's Fortune"
			player_item_id[id] = rannum
			player_b_godmode[id] = random_num(4,10)
			show_hudmessage(id, "Вы нашли item : %s :: Вы становитесь бесмертным на %i секунд.", player_item_name[id], player_b_godmode[id])
		}
		case 121:
		{
			player_item_name[id] = "Winter Totem"
			player_item_id[id] = rannum
			player_b_zamroztotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жмите Е чтобы установить замораживайщий тотем",player_item_name[id])	
		}
		case 122:
		{
			player_item_name[id] = "Cash Totem"
			player_item_id[id] = rannum
			player_b_kasatotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жми E чтобы установить тотем который даёт вам и вашей команде деньги.",player_item_name[id])	
		}
		case 123:
		{
			player_item_name[id] = "Thief Totem"
			player_item_id[id] = rannum
			player_b_kasaqtotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жми E чтобы установить тотем который отнимает деньги врага(500$ в сек)",player_item_name[id])	
		}
		case 124:
		{
			player_item_name[id] = "Weapon Totem"
			player_item_id[id] = rannum
			player_b_wywaltotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жми E чтобы установить тотем который притягивает оружие противника.",player_item_name[id])	
		}
		case 125:
		{
			player_item_name[id] = "Flash Totem"
			player_item_id[id] = rannum
			player_b_fleshujtotem[id] = random_num(250,400)
			show_hudmessage(id, "Жми E чтобы установить тотем который ослепляет противника.",player_item_name[id])	
		}
		
	}
	BoostRing(id)
	
	
	return PLUGIN_CONTINUE
}

/* UNIQUE ITEMS ============================================================================================ */
//Names are generated from an array

public award_unique_item(id)
{
	new Unique_names_Suffix[10][100]
	new Unique_names_Prefix[10][100]
	
	Unique_names_Suffix[1] = "Saintly amulet "
	Unique_names_Suffix[2] = "Holy sword "
	Unique_names_Suffix[3] = "Small staff "
	Unique_names_Suffix[4] = "Bright rope "
	Unique_names_Suffix[5] = "Shiny scepter "
	
	Unique_names_Prefix[1] = "of the stars"
	Unique_names_Prefix[2] = "of power"
	Unique_names_Prefix[3] = "of zod"
	Unique_names_Prefix[4] = "of life"
	Unique_names_Prefix[5] = "of the sun"
	
	//Generate the items name
	
	new roll_1 = random_num(1,4)
	new roll_2 = random_num(1,4)
	
	new Unique_name[100]
	add(Unique_name,99,Unique_names_Suffix[roll_1])
	add(Unique_name,99,Unique_names_Prefix[roll_2])
	
	player_item_name[id] = Unique_name
	player_item_id[id] = 100				
	
	//Generate and apply the stats
	
	if (roll_1 == 1) player_b_damage[id] = random_num(1,5)
	if (roll_1 == 2) player_b_vampire[id] = random_num(1,5)
	if (roll_1 == 3) player_b_money[id] = random_num(2500,5000)
	if (roll_1 == 4) player_b_reduceH[id] = random_num(20,50)
	if (roll_1 == 5) player_b_blind[id] = random_num(3,5)
	
	
	
	if (roll_2 == 1) player_b_grenade[id] = random_num(1,4)
	if (roll_2 == 2) player_b_respawn[id] = random_num(2,4)
	if (roll_2 == 3) player_b_explode[id] = random_num(150,400)
	if (roll_2 == 4) player_b_redirect[id] = random_num(5,10)
	if (roll_2 == 5) player_b_heal[id] = random_num(1,15)
	
	item_durability[id] = 350
	
	set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 4.0, 0.2, 0.3, 5)
	show_hudmessage(id, "Вы нашли Уникальный Item: %s", Unique_name)
	
}
/* EFFECTS ================================================================================================= */

public add_damage_bonus(id,damage,attacker_id)
{
	if (player_b_damage[attacker_id] > 0 && get_user_health(id)>player_b_damage[attacker_id])
	{
		change_health(id,-player_b_damage[attacker_id],attacker_id,"damage bonus")
			
		if (random_num(0,2) == 1) Effect_Bleed(id,248)
	}
	if (c_damage[attacker_id] > 0 && get_user_health(id)>player_b_damage[attacker_id])
	{
		change_health(id,-c_damage[attacker_id],attacker_id,"damage bonus")
			
		if (random_num(0,2) == 1) Effect_Bleed(id,248)
	}
}

/* ==================================================================================================== */

public add_vampire_bonus(id,damage,attacker_id)
{
	if (player_b_vampire[attacker_id] > 0)
	{
		change_health(attacker_id,player_b_vampire[attacker_id],0,"")
	}
	if (c_vampire[attacker_id] > 0)
	{
		change_health(attacker_id,c_vampire[attacker_id],0,"")
	}
}

/* ==================================================================================================== */

public add_money_bonus(id)
{
	if (player_b_money[id] > 0)
	{
		if (cs_get_user_money(id) < 16000 - player_b_money[id]+player_intelligence[id]*50) 
		{
			cs_set_user_money(id,cs_get_user_money(id)+ player_b_money[id]+player_intelligence[id]*50) 
		} 
		else 
		{
			cs_set_user_money(id,16000)
		}
	}
}



/* ==================================================================================================== */

public add_grenade_bonus(id,attacker_id,weapon)
{
	if (player_b_grenade[attacker_id] > 0 && weapon == CSW_HEGRENADE && player_b_fireshield[id] == 0)	//Fireshield check
	{
		new roll = random_num(1,player_b_grenade[attacker_id])
		if (roll == 1)
		{
			UTIL_Kill( id, attacker_id, "grenade")
		}
	}
	if (c_grenade[attacker_id] > 0 && weapon == CSW_HEGRENADE && player_b_fireshield[id] == 0)	//Fireshield check
	{
		new roll = random_num(1,c_grenade[attacker_id])
		if (roll == 1)
		{
			UTIL_Kill( id, attacker_id, "grenade")
		}
	}
}

/* ==================================================================================================== */

public add_redhealth_bonus(id)
{
	if (player_b_reduceH[id] > 0)
		change_health(id,-player_b_reduceH[id],0,"reduce bonus")
	if(player_item_id[id]==17)	//stalker ring
		set_user_health(id,5)
	if(player_item_id[id]==88)	//own invisible
		set_user_health(id,45)
	if(player_item_id[id]==89)	//mega invisible
		set_user_health(id,10)
}

/* ==================================================================================================== */

public add_theif_bonus(id,attacker_id)
{
	if (player_b_theif[attacker_id] > 0)
	{
		new roll1 = random_num(1,5)
		if (roll1 == 1)
		{
			if (cs_get_user_money(id) > player_b_theif[attacker_id])
			{
				cs_set_user_money(id,cs_get_user_money(id)-player_b_theif[attacker_id])
				if (cs_get_user_money(attacker_id) + player_b_theif[attacker_id] <= 16000)
				{
					cs_set_user_money(attacker_id,cs_get_user_money(attacker_id)+player_b_theif[attacker_id])		
				}
			}
			else
			{
				new allthatsleft = cs_get_user_money(id)
				cs_set_user_money(id,0)
				if (cs_get_user_money(attacker_id) + allthatsleft <= 16000)
				{
					cs_set_user_money(attacker_id,cs_get_user_money(attacker_id) + allthatsleft)			
				}
			}
		}
	}
}

/* ==================================================================================================== */

public add_respawn_bonus(id)
{
	if (player_b_respawn[id] > 0)
	{
		new svIndex[32] 
		num_to_str(id,svIndex,32)
		new roll = random_num(1,player_b_respawn[id])
		if (roll == 1)
		{
			new maxpl,players[32]
			get_players(players, maxpl) 
			if (maxpl > 2)
			{
				cs_set_user_money(id,cs_get_user_money(id)+4000)
				set_task(0.5,"respawn",0,svIndex,32) 		
			}
			else
			{
				set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 2.0, 0.2, 0.3, 5)
				show_hudmessage(id, "Более 2 игроков, необходимо для возрождения")	
			}
			
		}
	}
	if (c_respawn[id] > 0)
	{
		new svIndex[32] 
		num_to_str(id,svIndex,32)
		new roll = random_num(1,c_respawn[id])
		if (roll == 1)
		{
			new maxpl,players[32]
			get_players(players, maxpl) 
			if (maxpl > 2)
			{
				cs_set_user_money(id,cs_get_user_money(id)+4000)
				set_task(0.5,"respawn",0,svIndex,32) 		
			}
			else
			{
				set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 2.0, 0.2, 0.3, 5)
				show_hudmessage(id, "Более 2 игроков, необходимо для возрождения")	
			}
			
		}
	}
}

public d2_damage( iVictim, iAttacker, iDamage, iWeapon[])
{
	new iHealth = get_user_health( iVictim );
	
	// User has been killed
	if ( iHealth - iDamage <= 0 )
	{
		UTIL_Kill(iAttacker,iVictim,iWeapon)
	}

	// Just do the damage
	else
	{
		set_user_health( iVictim, iHealth - iDamage );
	}
	
	if(iVictim!=iAttacker) 
	{
		dmg_exp(iAttacker, iDamage)
	}
		
	return;
}

public respawn(svIndex[]) 
{ 
	new vIndex = str_to_num(svIndex) 
	spawn(vIndex);
}

get_rgb_colors(team,rgb[3])
{
	static color[12], parts[3][4];
	color = "0 206 209"
	
	// if cvar is set to "team", use colors based on the given team
	if(equali(color,"team",4))
	{
		if(team == 1)
		{
			rgb[0] = 150;
			rgb[1] = 0;
			rgb[2] = 0;
		}
		else
		{
			rgb[0] = 0;
			rgb[1] = 0;
			rgb[2] = 150;
		}
	}
	else
	{
		parse(color,parts[0],3,parts[1],3,parts[2],3);
		rgb[0] = str_to_num(parts[0]);
		rgb[1] = str_to_num(parts[1]);
		rgb[2] = str_to_num(parts[2]);
	}
}

/* ==================================================================================================== */

public add_bonus_explode(id)
{
	if (player_b_explode[id] > 0)
	{
		
		new origin[3] 
		get_user_origin(id,origin) 
		explode(origin,id,0)
		
		
		for(new a = 0; a < MAX; a++) 
		{ 
			if (!is_user_connected(a) || !is_user_alive(a) || player_b_fireshield[a] != 0 ||  get_user_team(a) == get_user_team(id))
				continue
			if(player_b_antyorb[a] > 0 || c_antyorb[a] > 0)
				continue
			
			new origin1[3]
			get_user_origin(a,origin1) 
			
			if(get_distance(origin,origin1) < player_b_explode[id] + player_intelligence[id]*2)
			{
				new dam = 75-(player_dextery[a]*2)
				if(dam<1) dam=1
				change_health(a,-dam,id,"explode bonus")
				Display_Fade(id,2600,2600,0,255,0,0,15)				
			}
		}
	}
	if (player_class[id] == Frozen)
	{
		glow_player(id, 1.0, 0, 206, 209)
		new Float:origin[3];
		pev(id,pev_origin,origin);
		message_begin_fl(MSG_PAS,SVC_TEMPENTITY,origin,0);
		write_byte(TE_BREAKMODEL);
		write_coord_fl(origin[0]); // x
		write_coord_fl(origin[1]); // y
		write_coord_fl(origin[2] + 24.0); // z
		write_coord_fl(16.0); // size x
		write_coord_fl(16.0); // size y
		write_coord_fl(16.0); // size z
		write_coord(random_num(-50,50)); // velocity x
		write_coord(random_num(-50,50)); // velocity y
		write_coord_fl(25.0); // velocity z
		write_byte(10); // random velocity
		write_short(coldGibs); // model
		write_byte(50); // count
		write_byte(40); // life
		write_byte(0x01); // flags
		message_end();
		
		new rgb[3];
		new team = pev(id,pev_team);
		get_rgb_colors(team,rgb);
		
		// add the shatter
		message_begin_fl(MSG_PAS,SVC_TEMPENTITY,origin,0);
		write_byte(TE_DLIGHT);
		write_coord_fl(origin[0]); // x
		write_coord_fl(origin[1]); // y
		write_coord_fl(origin[2]); // z
		write_byte(floatround(48.0)); // radius
		write_byte(rgb[0]); // r
		write_byte(rgb[1]); // g
		write_byte(rgb[2]); // b
		write_byte(8); // life
		write_byte(60); // decay rate
		message_end();
		new origin2[3] 
		get_user_origin(id,origin2)
		for(new a = 0; a < MAX; a++) 
		{ 
			if (!is_user_connected(a) || !is_user_alive(a) ||  get_user_team(a) == get_user_team(id) || player_class[a] == Frozen)
			{
				continue
			}
			
			new origin1[3]
			get_user_origin(a,origin1) 
			
			if(get_distance(origin2,origin1) < 150)
			{
				new dam
				new Float:dam2 = (player_intelligence[id]/2.0)-(player_dextery[a]/2.0)+10.0
				dam = floatround(dam2,floatround_round);
				if(dam<1) dam=0
				change_health(a,-dam,id,"cold")
				Create_ScreenFade( a, (1<<15), (1<<10), (1<<12), 0, 206, 209, 150 );
				Display_Icon(a ,2 ,"dmg_cold" ,rgb[0],rgb[1],rgb[2])
				set_task(3.0, "remove_frozencold", a)		
			}
		}
	}
}

public remove_frozencold(id)
{
	Display_Icon(id ,0 ,"dmg_cold" ,0,0,0)
}

public add_bonus_zakarum(id)
{
	if (player_class[id] == Zakarum)
	{
		
		emit_sound(id,CHAN_STATIC, "diablo_lp/zakarum_death1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
		set_task(0.35, "add_bonus_zakarum_sprite", id)
	}
}

public add_bonus_zakarum_sprite(id)
{
	new origin[3] 
	get_user_origin(id,origin)
	
	new parm[5]
	parm[0] = id;
	parm[1] = 6;
	parm[2] = origin[0];
	parm[3] = origin[1];
	parm[4] = origin[2];
	new vPosition[3], vOrigin[3];

	vOrigin[0] = parm[2];
	vOrigin[1] = parm[3];
	vOrigin[2] = parm[4] - 16;

	vPosition[0] = vOrigin[0];
	vPosition[1] = vOrigin[1];
	vPosition[2] = vOrigin[2] + 80; //radius
	message_begin( MSG_PAS, SVC_TEMPENTITY, vOrigin )
	write_byte( TE_BEAMCYLINDER )
	write_coord( vOrigin[0] )			// center position (X)
	write_coord( vOrigin[1] )			// center position (Y)
	write_coord( vOrigin[2] )			// center position (Z)
	write_coord( vPosition[0] )				// axis and radius (X)
	write_coord( vPosition[1] )				// axis and radius (Y)
	write_coord( vPosition[2] )				// axis and radius (Z)
	write_short( g_shock )				// sprite index
	write_byte( 0 )			// starting frame
	write_byte( 0 )				// frame rate in 0.1's
	write_byte( 6 )					// life in 0.1's
	write_byte( 16 )					// line width in 0.1's
	write_byte( 0 )				// noise amplitude in 0.01's
	write_byte( 0 )					// color (red)
	write_byte( 0 )					// color (green)
	write_byte( 255 )					// color (blue)
	write_byte( 255 )			// brightness
	write_byte( 0 )					// scroll speed in 0.1's
	message_end()
}

public explode(vec1[3],playerid, trigger)
{ 
	message_begin( MSG_BROADCAST,SVC_TEMPENTITY,vec1) 
	write_byte( 21 ) 
	write_coord(vec1[0]) 
	write_coord(vec1[1]) 
	write_coord(vec1[2] + 32) 
	write_coord(vec1[0]) 
	write_coord(vec1[1]) 
	write_coord(vec1[2] + 1000)
	write_short( sprite_white ) 
	write_byte( 0 ) 
	write_byte( 0 ) 
	write_byte( 3 ) 
	write_byte( 10 ) 
	write_byte( 0 ) 
	write_byte( 188 ) 
	write_byte( 220 ) 
	write_byte( 255 ) 
	write_byte( 255 ) 
	write_byte( 0 ) 
	message_end() 
	
	message_begin( MSG_BROADCAST,SVC_TEMPENTITY) 
	write_byte( 12 ) 
	write_coord(vec1[0]) 
	write_coord(vec1[1]) 
	write_coord(vec1[2]) 
	write_byte( 188 ) 
	write_byte( 10 ) 
	message_end() 
	
	message_begin( MSG_BROADCAST,SVC_TEMPENTITY,vec1) 
	write_byte( 3 ) 
	write_coord(vec1[0]) 
	write_coord(vec1[1]) 
	write_coord(vec1[2]) 
	write_short( sprite_fire ) 
	write_byte( 65 ) 
	write_byte( 10 ) 
	write_byte( 0 ) 
	message_end() 
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY,{0,0,0},playerid) 
	write_byte(107) 
	write_coord(vec1[0]) 
	write_coord(vec1[1]) 
	write_coord(vec1[2]) 
	write_coord(175) 
	write_short (sprite_gibs) 
	write_short (25)  
	write_byte (10) 
	message_end() 
	if (trigger == 1)
	{
		set_user_rendering(playerid,kRenderFxNone, 0,0,0, kRenderTransAdd,0) 
	}
}

/* ==================================================================================================== */

public add_bonus_gamble(id)
{	
	if (player_b_gamble[id] > 0 && is_user_alive(id))
	{
		new durba=item_durability[id]
		reset_item_skills(id)
		item_durability[id]=durba
		set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 3.0, 0.2, 0.3, 5)
		new roll = random_num(1,player_b_gamble[id])
		if (roll == 1)
		{
			show_hudmessage(id, "Бонус раунда: +5 урона")
			player_b_damage[id] = 5
		}
		if (roll == 2)
		{
			show_hudmessage(id, "Бонус раунда: +5 к гравитации")
			player_b_gravity[id] = 5
		}
		if (roll == 3)
		{
			show_hudmessage(id, "Бонус раунда: +5 vampyric урон")
			player_b_vampire[id] = 5
		}
		if (roll == 4)
		{
			show_hudmessage(id, "Бонус раунда: +10 hp каждые 5 секунд")
			player_b_heal[id] = 10
		}
		if (roll == 5)
		{
			show_hudmessage(id, "Бонус раунда: шанс 1/3 сразу убить с гранаты HE")
			player_b_grenade[id] = 3
		}
	}
}

/* ==================================================================================================== */

public add_bonus_blind(id,attacker_id,weapon,damage)
{
	if (player_b_blind[attacker_id] > 0 && weapon != 4) 
	{
		if (random_num(1,player_b_blind[attacker_id]) == 1) Display_Fade(id,1<<14,1<<14 ,1<<16,255,155,50,230)		
	}
	if (c_blind[attacker_id] > 0 && weapon != 4) 
	{
		if (random_num(1,c_blind[attacker_id]) == 1) Display_Fade(id,1<<14,1<<14 ,1<<16,255,155,50,230)		
	}
}

/* ==================================================================================================== */

public item_c4fake(id)
{ 
	if (c4state[id] > 1)
	{
		hudmsg(id,2.0,"Meekstone можно использовать один раз за раунд!")
		return PLUGIN_CONTINUE 
	}
	
	if (player_b_meekstone[id] > 0 && c4state[id] == 1 && is_user_alive(id) == 1 && freeze_ended == true)
	{
		explode(c4bombc[id],id,0)
		
		for(new a = 0; a < MAX; a++) 
		{ 
			if (is_user_connected(a) && is_user_alive(a))
			{			
				new origin1[3]
				get_user_origin(a,origin1) 
				
				if(get_distance(c4bombc[id],origin1) < 300 && get_user_team(a) != get_user_team(id))
				{
					if(player_b_antymeek[a] > 0 || c_antymeek[a] > 0)
					return PLUGIN_HANDLED;
					UTIL_Kill(id,a,"meekstone")
				}
			}
		}
		
		c4state[id] = 2
		remove_entity(c4fake[id])
		c4fake[id] = 0 
	}
	
	if (player_b_meekstone[id] > 0 && c4state[id] == 0 && c4fake[id] == 0 && is_user_alive(id) == 1 && freeze_ended == true)
	{
		new Float:pOrigin[3]
		entity_get_vector(id,EV_VEC_origin, pOrigin)
		c4fake[id] = create_entity("info_target")
		
		entity_set_model(c4fake[id],"models/w_backpack.mdl")
		entity_set_origin(c4fake[id],pOrigin)
		entity_set_string(c4fake[id],EV_SZ_classname,"fakec4")
		entity_set_edict(c4fake[id],EV_ENT_owner,id)
		entity_set_int(c4fake[id],EV_INT_movetype,6)
		
		
		new Float:aOrigin[3]
		entity_get_vector(c4fake[id],EV_VEC_origin, aOrigin)
		c4bombc[id][0] = floatround(aOrigin[0])
		c4bombc[id][1] = floatround(aOrigin[1])
		c4bombc[id][2] = floatround(aOrigin[2])
		c4state[id] = 1
	}
	
	return PLUGIN_CONTINUE 
}

/* ==================================================================================================== */

public item_fireball(id)
{
	if (fired[id] > 0)
	{
		return PLUGIN_HANDLED
	}
	
	if (fired[id] == 0 && is_user_alive(id) == 1)
	{
		fired[id] = 1
		new Float:fOrigin[3],enOrigin[3]
		get_user_origin(id, enOrigin)
		new ent = create_entity("env_sprite")
   
		IVecFVec(enOrigin, fOrigin)

   
		entity_set_string(ent, EV_SZ_classname, "fireball")
		//entity_set_model(ent, "sprites/xfireball3.spr")
		//entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
		//entity_set_float(ent, EV_FL_framerate, 30.0)
		entity_set_model(ent, "sprites/explode1.spr")
		entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
		entity_set_float(ent, EV_FL_animtime, 1.0)
		entity_set_float(ent, EV_FL_frame, 2.0)
		entity_set_float(ent, EV_FL_framerate, 9.0)

		DispatchSpawn(ent)

		entity_set_origin(ent, fOrigin)
		entity_set_size(ent, Float:{-5.0, -5.0, -5.0}, Float:{5.0, 5.0, 5.0})
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
		entity_set_int(ent, EV_INT_movetype, 5)
		entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
		entity_set_float(ent, EV_FL_renderamt, 255.0)
		entity_set_float(ent, EV_FL_scale, 0.8)
		entity_set_edict(ent,EV_ENT_owner, id)
		//Send forward
		new Float:fl_iNewVelocity[3]
		VelocityByAim(id, 700, fl_iNewVelocity)
		entity_set_vector(ent, EV_VEC_velocity, fl_iNewVelocity)
		emit_sound(ent, CHAN_VOICE, "diablo_lp/firelaunch2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}	
	return PLUGIN_HANDLED
}

public item_viper(id)
{
	if (fired_viper[id] > 0)
	{
		hudmsg(id,2.0,"Копье еще не активировалось")
		return PLUGIN_HANDLED
	}
	if (fired_viper[id] == 0 && is_user_alive(id) == 1)
	{
		fired_viper[id] = 1
		new Float:fOrigin[3],enOrigin[3]
		get_user_origin(id, enOrigin)
		new ent = create_entity("env_sprite")
   
		IVecFVec(enOrigin, fOrigin)
		viper_cord[id] = fOrigin;

   
		entity_set_string(ent, EV_SZ_classname, "viperball")
		entity_set_model(ent, "sprites/diablo_lp/bone1.spr")
		entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
		entity_set_float(ent, EV_FL_framerate, 9.0)

		DispatchSpawn(ent)

		entity_set_origin(ent, fOrigin)
		entity_set_size(ent, Float:{-5.0, -5.0, -5.0}, Float:{5.0, 5.0, 5.0})
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP)
		entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
		entity_set_float(ent, EV_FL_renderamt, 255.0)
		entity_set_edict(ent,EV_ENT_owner, id)
		
		entity_set_float(ent, EV_FL_scale, 0.5)
		//Send forward
		new Float:fl_iNewVelocity[3]
		VelocityByAim(id, 800, fl_iNewVelocity)
		entity_set_vector(ent, EV_VEC_velocity, fl_iNewVelocity)
		set_pev(ent, pev_nextthink, (get_gametime() + 4.0))
		viper_vector[id] = fl_iNewVelocity;
		viper_spear[id] = 1
		
		set_task(0.1,"create_bone_spear",id)
		
		emit_sound(id, CHAN_VOICE, "diablo_lp/bonecast.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}	
	return PLUGIN_HANDLED
}

public create_bone_spear(id)
{
	new ent2 = create_entity("env_sprite")

	viper_spear[id]++
	entity_set_string(ent2, EV_SZ_classname, "viperball")
	entity_set_model(ent2, "sprites/diablo_lp/bone1.spr")
	entity_set_int(ent2, EV_INT_spawnflags, SF_SPRITE_STARTON)
	entity_set_float(ent2, EV_FL_framerate, 9.0)

	DispatchSpawn(ent2)

	entity_set_origin(ent2, viper_cord[id])
	entity_set_size(ent2, Float:{-5.0, -5.0, -5.0}, Float:{5.0, 5.0, 5.0})
	entity_set_int(ent2, EV_INT_solid, SOLID_BBOX)
	entity_set_int(ent2, EV_INT_movetype, MOVETYPE_NOCLIP)
	entity_set_int(ent2, EV_INT_rendermode, kRenderTransAdd)
	entity_set_float(ent2, EV_FL_renderamt, 255.0)
	if(viper_spear[id] == 2)
	{
		entity_set_float(ent2, EV_FL_scale, 0.6)
	}
	else if(viper_spear[id] == 3)
	{
		entity_set_float(ent2, EV_FL_scale, 0.8)
		emit_sound(ent2, CHAN_VOICE, "diablo_lp/bonespear1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	else if(viper_spear[id] == 4)
	{
		entity_set_float(ent2, EV_FL_scale, 1.0)
	}
	else if(viper_spear[id] == 5)
	{
		entity_set_float(ent2, EV_FL_scale, 1.2)
	}
	entity_set_edict(ent2,EV_ENT_owner, id)
	//Send forward
	entity_set_vector(ent2, EV_VEC_velocity, viper_vector[id])
	if(viper_spear[id] < 5)
	{
		set_task(0.1,"create_bone_spear",id)
	}
	set_pev(ent2, pev_nextthink, (get_gametime() + 4.0))
}

public viper_think(ent)
{
	remove_entity(ent)
	    
	return PLUGIN_CONTINUE
}

public viper_gas(id)
{
	if(viper_gas_time[id] + 5.0 > get_gametime())
	{
		client_print(id, print_center, "Газ можно использовать каждые 5 секунд!");
		return PLUGIN_CONTINUE;
	}
	if(player_intelligence[id] < 1)
	{
		client_print(id, print_center, "Чтобы пускать газ необходим Интеллект!");
		return PLUGIN_CONTINUE;
	}
	if(viper_gases[id] < 1)
	{
		client_print(id, print_center, "У вас закончился газ!");
		return PLUGIN_CONTINUE;
	}
	if(is_user_alive(id))
	{
		viper_gas_time[id] = get_gametime();
		viper_gases[id]--
		new Float:vOrigin[ 3 ]
		entity_get_vector( id, EV_VEC_origin, vOrigin );
		
		// create new entity
		new iEntity = create_entity( "info_target" );
		if( iEntity > 0 ) 
		{
			
			message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
			write_byte( TE_FIREFIELD );
			engfunc( EngFunc_WriteCoord, vOrigin[ 0 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 1 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 2 ] + 50 );
			write_short( 100 );
			write_short( sprite_sabrecat );
			write_byte( 100 );
			write_byte( TEFIRE_FLAG_ALPHA );
			write_byte( 1000 );
			message_end();
			
			message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
			write_byte( TE_FIREFIELD );
			engfunc( EngFunc_WriteCoord, vOrigin[ 0 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 1 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 2 ] + 50 );
			write_short( 150 );
			write_short( sprite_sabrecat );
			write_byte( 10 );
			write_byte( TEFIRE_FLAG_ALPHA | TEFIRE_FLAG_SOMEFLOAT );
			write_byte( 1000 );
			message_end( );
			new iEntity2;
			iEntity2 = create_entity("info_target")
			entity_set_string(iEntity2,EV_SZ_classname,"saber_smoke3")
			engfunc(EngFunc_SetModel, iEntity2, "models/portal/portal.mdl")
			set_pev(iEntity2,pev_solid,SOLID_TRIGGER)
			set_pev(iEntity2,pev_movetype,MOVETYPE_FLY)
			set_pev(iEntity2,pev_skin,1)		
			engfunc(EngFunc_SetOrigin, iEntity2, vOrigin)
			set_rendering(iEntity2, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0 )
			entity_set_edict(iEntity2,EV_ENT_owner, id)
			set_pev(iEntity2,pev_owner,id);
			entity_set_float( iEntity2, EV_FL_nextthink, get_gametime( ) + 21.5 );
			new Float:fMins[3],Float:fMaxs[3];
			pev(iEntity2, pev_mins, fMins)
			pev(iEntity2, pev_maxs, fMaxs)
			fMins[0] = fMins[0] + 100.5;
			fMins[1] = fMins[1] + 100.5;
			fMins[2] = fMins[2] + 100.5;

			fMaxs[0] = fMaxs[0] + 100.5;
			fMaxs[1] = fMaxs[1] + 100.5;
			fMaxs[2] = fMaxs[2] + 100.5;
			entity_set_size(iEntity2,Float:{-100.0,-100.0,-100.0},Float:{100.0,100.0,100.0})
			emit_sound(iEntity, CHAN_VOICE, "diablo_lp/poison.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	
	return PLUGIN_CONTINUE
}

public create_trap(id)
{	
	if (is_user_alive(id) == 1 && freeze_ended == true)
	{
		new Float:pOrigin[3]
		entity_get_vector(id,EV_VEC_origin, pOrigin)
		new ent = create_entity("info_target")
		
		entity_set_model(ent,"models/w_backpack.mdl")
		entity_set_origin(ent,pOrigin)
		//entity_set_string(c4fake[id],EV_SZ_classname,"fakec4")
		entity_set_string(ent,EV_SZ_classname,"spidertrap")
		entity_set_int(ent, EV_INT_solid, 1)
		entity_set_int(ent,EV_INT_movetype,6)
		entity_set_edict(ent,EV_ENT_owner,id)
		spider_traps[id]++
	}
}

public create_baal_copy(id)
{
	if (is_user_alive(id) == 1 && freeze_ended == true)
	{
		new Float:pOrigin[3], Float:flAngle[3], copy_model[50]
		entity_get_vector(id,EV_VEC_origin, pOrigin)
		
		new ent = create_entity("info_target")
		
		get_user_info(id,"model",copy_model,31)
		format(copy_model,50,"models/player/%s/%s.mdl",copy_model,copy_model)
		entity_set_model(ent,copy_model)
		
		entity_set_int(ent, EV_INT_solid, 2);
		entity_set_int(ent, EV_INT_movetype, 5);
		
		entity_set_origin(ent,pOrigin)
		
		entity_set_string(ent,EV_SZ_classname,"baalcopy")
		
		entity_get_vector(id, EV_VEC_angles, flAngle); 
        //Make sure the pitch is zeroed out 
        flAngle[0] = 0.0; 
        entity_set_vector(ent, EV_VEC_angles, flAngle); 
		
		static const Float: mins[ 3 ] = {-16.0, -16.0, -36.0}
		static const Float: maxs[ 3 ] = {16.0, 16.0, 36.0}
		entity_set_size(ent, mins, maxs); 
		
		entity_set_int(ent, EV_INT_gaitsequence, 1)
		set_pev(ent,pev_sequence,1)
		
		entity_set_edict(ent,EV_ENT_owner,id)
		
		new weap = create_entity("info_target")
		entity_set_string(weap,EV_SZ_classname,"baalcopyweap")
		entity_set_int(weap, EV_INT_solid, SOLID_NOT)
		entity_set_edict(weap, EV_ENT_aiment, ent)
		entity_set_model(weap, "models/p_glock18.mdl")
		entity_set_edict(weap,EV_ENT_owner,id)
		baal_copyed[id] = 1
		set_task(30.0, "removeBaalcopy", TASK_REMOVE_BAAL+id)
	}
	
	return PLUGIN_CONTINUE
}

public create_firewall(id)
{
	if (is_user_alive(id) == 1 && freeze_ended == true)
	{
		new Float:fOrigin[3],enOrigin[3]
		get_user_origin(id, enOrigin)
		new ent = create_entity("env_sprite")

		IVecFVec(enOrigin, fOrigin)


		entity_set_string(ent, EV_SZ_classname, "firewall")
		entity_set_model(ent, "sprites/diablo_lp/firewall.spr")
		entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
		entity_set_float(ent, EV_FL_framerate, 19.0)

		DispatchSpawn(ent)
		entity_set_origin(ent, fOrigin)
		entity_set_size(ent, Float:{-20.0, -20.0, -20.0}, Float:{20.0, 20.0, 20.0})
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP)
		entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
		entity_set_float(ent, EV_FL_renderamt, 255.0)
		entity_set_float(ent, EV_FL_scale, 1.0)
		entity_set_edict(ent,EV_ENT_owner, id)
		
		//Send forward
		new Float:fl_iNewVelocity[3]
		VelocityByAim(id, 800, fl_iNewVelocity)
		fl_iNewVelocity[2] = 0.0
		entity_set_vector(ent, EV_VEC_velocity, fl_iNewVelocity)
		mephisto_fires[id] = 1
		set_task(0.1,"create_firewall_next",id)
		set_task(4.0,"removeEntity",ent)
		emit_sound(ent, CHAN_VOICE, "diablo_lp/fwall2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		//set_pev(ent, pev_nextthink, (get_gametime() + 4.0))
	}
}

public create_firewall_next(id)
{
	mephisto_fires[id]++
	new Float:fOrigin[3],enOrigin[3]
	get_user_origin(id, enOrigin)
	new ent = create_entity("env_sprite")

	IVecFVec(enOrigin, fOrigin)


	entity_set_string(ent, EV_SZ_classname, "firewall")
	entity_set_model(ent, "sprites/diablo_lp/firewall.spr")
	entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
	entity_set_float(ent, EV_FL_framerate, 19.0)

	DispatchSpawn(ent)
	entity_set_origin(ent, fOrigin)
	entity_set_size(ent, Float:{-20.0, -20.0, -20.0}, Float:{20.0, 20.0, 20.0})
	entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP)
	entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
	entity_set_float(ent, EV_FL_renderamt, 255.0)
	entity_set_float(ent, EV_FL_scale, 1.0)
	entity_set_edict(ent,EV_ENT_owner, id)
	
	//Send forward
	new Float:fl_iNewVelocity[3]
	VelocityByAim(id, 800, fl_iNewVelocity)
	fl_iNewVelocity[2] = 0.0
	entity_set_vector(ent, EV_VEC_velocity, fl_iNewVelocity)
	if(mephisto_fires[id] < 4)
	{
		set_task(0.1,"create_firewall_next",id)
	}
	set_task(4.0,"removeEntity",ent)
	//set_pev(ent, pev_nextthink, (get_gametime() + 4.0))
}

public duriel_boosting(id)
{
	if(duriel_boost[id] == 0)
	{
		client_print(id, print_center, "У вас закончилась ярость!");
		return PLUGIN_CONTINUE;
	}
	if(duriel_boost_delay[id] == 1)
	{
		return PLUGIN_CONTINUE;
	}

	duriel_boost[id]--
	duriel_boost_delay[id] = 1
	
	new Float:fl_iNewVelocity[3]
	VelocityByAim(id, 4000, fl_iNewVelocity)
	entity_set_vector(id, EV_VEC_velocity, fl_iNewVelocity)
	set_task(1.0,"removeboostdelay",id)
	
	duriel_boost_ent[id] = 1
	set_task(0.5,"boostattack",id)
	
	return PLUGIN_CONTINUE;
}

public boostattack(id)
{
	new players[MAXPLAYERS], vTargetOrigin[3], pOrigin[3], Float:vVelocity[3];
	new target, iDistance, dmg, Float:dmgsumm, num;
	static boostrange = 330
	
	get_players(players,num,"h");
	
	get_user_origin( id, pOrigin );
	
	for(new i=0 ; i<num ; i++)
	{
		target = players[i]
		if((get_user_team(target) != get_user_team(id)) && is_user_alive(target))
		{
			// Get origin of target
			get_user_origin( target, vTargetOrigin );

			// Get distance in b/t target and caster
			iDistance = get_distance( pOrigin, vTargetOrigin );
			
			if ( iDistance < boostrange )
			{
				hudmsg(target,5.0,"Ярость Дуриеля поразила вас")
				dmgsumm = player_intelligence[id]/1.6 - player_dextery[target]/4
				dmg = floatround(dmgsumm, floatround_ceil)
				if(dmg < 10) { dmg = 10; }
				d2_damage( target, id, dmg, "durielboost")
				
				entity_get_vector( target, EV_VEC_velocity, vVelocity );

				vVelocity[0] = random_float(100.0, 400.0 );
				vVelocity[1] = random_float(100.0, 400.0 );
				vVelocity[2] = random_float(400.0, 600.0 );

				entity_set_vector( target, EV_VEC_velocity, vVelocity );
				for(new i2 = 0; i2 < sizeof primaryWeapons; i2++)
				{
					engclient_cmd(target, "drop", primaryWeapons[i2])
				}
			}
		}
	}
}

public removeboostdelay(id)
{
	duriel_boost_delay[id] = 0
}

stock Create_TE_BEAMCYLINDER(origin[3], center[3], axis[3], iSprite, startFrame, frameRate, life, width, amplitude, red, green, blue, brightness, speed){

	message_begin( MSG_PAS, SVC_TEMPENTITY, origin )
	write_byte( TE_BEAMCYLINDER )
	write_coord( center[0] )			// center position (X)
	write_coord( center[1] )			// center position (Y)
	write_coord( center[2] )			// center position (Z)
	write_coord( axis[0] )				// axis and radius (X)
	write_coord( axis[1] )				// axis and radius (Y)
	write_coord( axis[2] )				// axis and radius (Z)
	write_short( iSprite )				// sprite index
	write_byte( startFrame )			// starting frame
	write_byte( frameRate )				// frame rate in 0.1's
	write_byte( life )					// life in 0.1's
	write_byte( width )					// line width in 0.1's
	write_byte( amplitude )				// noise amplitude in 0.01's
	write_byte( red )					// color (red)
	write_byte( green )					// color (green)
	write_byte( blue )					// color (blue)
	write_byte( brightness )			// brightness
	write_byte( speed )					// scroll speed in 0.1's
	message_end()
}

stock create_izual_implosion(position[3], radius, count, life)
{

	message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
	write_byte ( TE_IMPLOSION )
	write_coord( position[0] )			// position (X)
	write_coord( position[1] )			// position (Y)
	write_coord( position[2] )			// position (Z)
	write_byte ( radius )				// radius
	write_byte ( count )				// count
	write_byte ( life )					// life in 0.1's
	message_end()
}

public create_izual_ring(vOrigin[3], radius)
{
	new vPosition[3];
	
	//vOrigin[2] = vOrigin[2] - 16;

	vPosition[0] = vOrigin[0];
	vPosition[1] = vOrigin[1];
	vPosition[2] = vOrigin[2] + radius;
	
	Create_TE_BEAMCYLINDER( vOrigin, vOrigin, vPosition, g_shock, 0, 0, 6, 16, 0, 188, 220, 255, 255, 0 );

	vOrigin[2] = ( vOrigin[2] - radius ) + ( radius / 2 );

	Create_TE_BEAMCYLINDER( vOrigin, vOrigin, vPosition, g_shock, 0, 0, 6, 16, 0, 188, 220, 255, 255, 0 );
}

public izualring(id)
{
	if(izual_ring[id] < 1)
	{
		client_print(id, print_center, "У вас закончились кольца!");
		return PLUGIN_CONTINUE;
	}
	if(izual_ringing[id] + 10.0 > get_gametime())
	{
		client_print(id, print_center, "Подождите 10 секунд. Кольцо заблокированно!");
		return PLUGIN_CONTINUE;
	}
	izual_ringing[id]=get_gametime()
	izual_ring[id]--
	new players[MAXPLAYERS], vTargetOrigin[3], pOrigin[3];
	new target, iDistance, dmg, Float:dmgsumm, num;
	static range = 600
	get_user_origin( id, pOrigin );
	
	// Create an implosion effect
	create_izual_implosion( pOrigin, range, 20, 5 );
	create_izual_ring( pOrigin, range )
	emit_sound(id, CHAN_VOICE, "diablo_lp/izual_ring2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	get_players(players,num,"h");
	
	for(new i=0 ; i<num ; i++)
	{
		target = players[i]
		if((get_user_team(target) != get_user_team(id)) && is_user_alive(target))
		{
			// Get origin of target
			get_user_origin( target, vTargetOrigin );

			// Get distance in b/t target and caster
			iDistance = get_distance( pOrigin, vTargetOrigin );
			
			if ( iDistance < range )
			{
				dmgsumm = ((player_intelligence[id]*0.6) + 30) - (player_dextery[target]/3)
				dmg = floatround(dmgsumm, floatround_ceil)
				if(dmg < 30) { dmg = 30; }
				d2_damage( target, id, dmg, "izual_ring")
				
				if(is_frozen[target] == 0)
				{
					new Float:colddelay
					colddelay = player_intelligence[id] * 0.2
					if(colddelay < 4.0) { colddelay = 4.0; }
					glow_player(target, colddelay, 0, 0, 255)
					set_user_maxspeed(target, 100.0)
					set_task(colddelay, "unfreeze", target, "", 0, "a", 1)
					is_frozen[target] = 1
					Display_Icon(target ,2 ,"dmg_cold" ,0,206,209)
				}
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public add_bonus_redirect(id)
{
	if (player_b_redirect[id] > 0)
	{
		if (get_user_health(id)+player_b_redirect[id] <= race_heal[player_class[id]]+player_strength[id]*1)
		{
			change_health(id,player_b_redirect[id],0,"")
		}
		
	}
	if (c_redirect[id] > 0)
	{
		if (get_user_health(id)+c_redirect[id] <= race_heal[player_class[id]]+player_strength[id]*1)
		{
			change_health(id,c_redirect[id],0,"")
		}
		
	}
}

/* ==================================================================================================== */

public item_ghost(id)
{
	if (ghoststate[id] == 0 && player_b_ghost[id] > 0 && is_user_alive(id) && !ghost_check)
	{
		set_user_noclip(id,1)
		ghoststate[id] = 2
		ghosttime[id] = floatround(halflife_time())
		ghost_check = true
		
		message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
		write_byte( player_b_ghost[id]+1 ) 
		write_byte( 0 ) 
		message_end() 
	}
	else
	{
		hudmsg(id,3.0,"Только один игрок может использовать Призрак в то же время! Предмет был использован!")
	}
}

/* ==================================================================================================== */

public add_bonus_darksteel(attacker,id,damage)
{
	if (player_b_darksteel[attacker] > 0)
	{
		if (UTIL_In_FOV(attacker,id) && !UTIL_In_FOV(id,attacker))
		{
			
			new dam = floatround (15+player_strength[id]*2*player_b_darksteel[id]/10.0)
			
			Effect_Bleed(id,248)
			change_health(id,-dam,attacker,"darkstell")
		}
	}
	if (c_darksteel[attacker] > 0)
{
	if (UTIL_In_FOV(attacker,id) && !UTIL_In_FOV(id,attacker))
	{
		new dam = (1+player_b_darksteel[id])
		Effect_Bleed(id,248)
		change_health(id,-dam,attacker,"darksteel")
	}
}
}

/* ==================================================================================================== */

public item_eye(id)
{
	if (player_b_eye[id] == -1)
	{
		//place camera
		new Float:playerOrigin[3]
		entity_get_vector(id,EV_VEC_origin,playerOrigin)
		new ent = create_entity("info_target") 
		entity_set_string(ent, EV_SZ_classname, "PlayerCamera") 
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP) 
		entity_set_int(ent, EV_INT_solid, SOLID_NOT) 
		entity_set_edict(ent, EV_ENT_owner, id)
		entity_set_model(ent, "models/rpgrocket.mdl")  				//Just something
		entity_set_origin(ent,playerOrigin)
		entity_set_int(ent,EV_INT_iuser1,0)		//Viewing through this camera						
		set_rendering (ent,kRenderFxNone, 0,0,0, kRenderTransTexture,0)
		entity_set_float(ent,EV_FL_nextthink,halflife_time() + 0.01) 
		player_b_eye[id] = ent
	}
	else
	{
		//view through camera or stop viewing
		new ent = player_b_eye[id]
		if (!is_valid_ent(ent))
		{
			attach_view(id,id)
			return PLUGIN_HANDLED
		}
		new viewing = entity_get_int(ent,EV_INT_iuser1)
		
		if (viewing) 
		{	
			entity_set_int(ent,EV_INT_iuser1,0)
			attach_view(id,id)
		}	
		else 
		{
			entity_set_int(ent,EV_INT_iuser1,1)
			attach_view(id,ent)
		}
	}
	
	return PLUGIN_HANDLED
}

/* ==================================================================================================== */

//Called when PlayerCamera thinks
public Think_PlayerCamera(ent)
{
	new id = entity_get_edict(ent,EV_ENT_owner)
	
	//Check if player is still having the item and is still online
	if (!is_valid_ent(id) || player_b_eye[id] == 0 || !is_user_connected(id))
	{
		//remove entity
		if (is_valid_ent(id) && is_user_connected(id)) attach_view(id,id)
		remove_entity(ent)
	}
	else
	{
		//Dont use cpu when not alive anyway or not viewing
		if (!is_user_alive(id))
		{
			entity_set_float(ent,EV_FL_nextthink,halflife_time() + 3.0) 
			return PLUGIN_HANDLED
		}
		
		if (!entity_get_int(ent,EV_INT_iuser1))
		{
			entity_set_float(ent,EV_FL_nextthink,halflife_time() + 0.5) 
			return PLUGIN_HANDLED
		}
		
		entity_set_float(ent,EV_FL_nextthink,halflife_time() + 0.01) 
		
		//Find nearest player to camera
		new Float:pOrigin[3],Float:plOrigin[3],Float:ret[3]
		entity_get_vector(ent,EV_VEC_origin,plOrigin)
		new Float:distrec = 2000.0, winent = -1
		
		for (new i=0; i<MAX; i++) 
		{
			if (is_user_connected(i) && is_user_alive(i))
			{
				entity_get_vector(i,EV_VEC_origin,pOrigin)
				pOrigin[2]+=10.0
				if (trace_line ( 0, plOrigin, pOrigin, ret ) == i && vector_distance(pOrigin,plOrigin) < distrec)
				{
					winent = i
					distrec = vector_distance(pOrigin,plOrigin)
				}
			}	
		}
		
		//Traceline and updown is still revresed
		if (winent > -1)
		{
			new Float:toplayer[3], Float:ideal[3],Float:pOrigin[3]
			entity_get_vector(winent,EV_VEC_origin,pOrigin)
			pOrigin[2]+=10.0
			toplayer[0] = pOrigin[0]-plOrigin[0]
			toplayer[1] = pOrigin[1]-plOrigin[1]
			toplayer[2] = pOrigin[2]-plOrigin[2]
			vector_to_angle ( toplayer, ideal ) 
			ideal[0] = ideal[0]*-1
			entity_set_vector(ent,EV_VEC_angles,ideal)
		}
	}
	
	return PLUGIN_CONTINUE
}

public Create_Line(id,origin1[3],origin2[3],bool:draw)
{
	if (draw)
	{
		message_begin(MSG_ONE,SVC_TEMPENTITY,{0,0,0},id)
		write_byte(0)
		write_coord(origin1[0])	// starting pos
		write_coord(origin1[1])
		write_coord(origin1[2])
		write_coord(origin2[0])	// ending pos
		write_coord(origin2[1])
		write_coord(origin2[2])
		write_short(sprite_line)	// sprite index
		write_byte(1)		// starting frame
		write_byte(5)		// frame rate
		write_byte(2)		// life
		write_byte(3)		// line width
		write_byte(0)		// noise
		write_byte(255)	// RED
		write_byte(50)	// GREEN
		write_byte(50)	// BLUE					
		write_byte(155)		// brightness
		write_byte(5)		// scroll speed
		message_end()
	}
	
	new Float:ret[3],Float:fOrigin1[3],Float:fOrigin2[3]
	//So we dont hit ourself
	origin1[2]+=50
	IVecFVec(origin1,fOrigin1)
	IVecFVec(origin2,fOrigin2)
	new hit = trace_line ( 0, fOrigin1, fOrigin2, ret )
	return hit
	
}

/* ==================================================================================================== */

public Prethink_Blink(id)
{
	if( get_user_button(id) & IN_ATTACK2 && !(get_user_oldbutton(id) & IN_ATTACK2) && is_user_alive(id)) 
	{			
		if (on_knife[id] && (player_b_blink[id] != 0))
		{
			if (halflife_time()-player_b_blink[id] <= 3) return PLUGIN_HANDLED		
			player_b_blink[id] = floatround(halflife_time())	
			UTIL_Teleport(id,300+15*player_intelligence[id])			
		}		
		if (on_knife[id] && (player_intelligence[id] > 0) && (c_blink[id] != 0))
		{
			new Float:blink_timer = 160.0/player_intelligence[id] 
			if(blink_timer > 32.0) { blink_timer = 32.0; }
			if ((floatround(halflife_time())-c_blink[id]) > floatround(blink_timer))
			{
				c_blink[id] = floatround(halflife_time())
				UTIL_Teleport(id,300+15*player_intelligence[id])
			}
		}
	}
	
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */


//Called on end or mapchange -- Save items for players
public plugin_end() 
{
	DB_SaveAll(2);
	MYSQLX_Close();
}

/* ==================================================================================================== */


/* ==================================================================================================== */



/* ==================================================================================================== */



/* ==================================================================================================== */

public item_convertmoney(id)
{
	new maxhealth = race_heal[player_class[id]]+player_strength[id]*2
	
	if (cs_get_user_money(id) < 1000)
		hudmsg(id,2.0,"У вас недостаточно денег")
	else if (get_user_health(id) == maxhealth)
		hudmsg(id,2.0,"У вас есть максимальное количество жизней")
	else
	{
		cs_set_user_money(id,cs_get_user_money(id)-1000)
		change_health(id,15,0,"")			
		Display_Fade(id,2600,2600,0,0,255,0,15)
	}
}

public item_windwalk(id)
{
	//First time this round
	if (player_b_usingwind[id] == 0)
	{
		new szId[10]
		num_to_str(id,szId,9)
		player_b_usingwind[id] = 1
		
		set_renderchange(id)
		
		engclient_cmd(id,"weapon_knife") 
		on_knife[id]=1
		set_user_maxspeed(id,500.0)
		
		new Float:val = player_b_windwalk[id] + 0.0
		set_task(val,"resetwindwalk",0,szId,32) 
		
		message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
		write_byte( player_b_windwalk[id]) 
		write_byte( 0 ) 
		message_end() 
	}
	
	//Disable again
	else if (player_b_usingwind[id] == 1)
	{
		player_b_usingwind[id] = 2
		
		set_renderchange(id)
		
		set_user_maxspeed(id,270.0)
		message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
		write_byte( 0) 
		write_byte( 0 ) 
		message_end() 
	}
	
	//Already used
	else if (player_b_usingwind[id] == 2)
	{
		set_hudmessage(220, 30, 30, -1.0, 0.40, 0, 3.0, 2.0, 0.2, 0.3, 5)
		show_hudmessage(id, "Этот item можно использовать один раз за раунд!") 
	}
	
}

public resetwindwalk(szId[])
{
	new id = str_to_num(szId)
	if (id < 0 || id > MAX)
	{
		log_amx("Ошибка в resetwindwalk, id: %i за пределами поля", id)
	}
	
	if (player_b_usingwind[id] == 1)
	{
		player_b_usingwind[id] = 2
		
		set_renderchange(id)
		
		set_user_maxspeed(id,270.0)
		message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
		write_byte( 0) 
		write_byte( 0 ) 
		message_end() 
	}
	
}

/* ==================================================================================================== */

public Prethink_usingwind(id)
{
	
	if( get_user_button(id) & IN_ATTACK && is_user_alive(id))
	{
		new buttons = pev(id,pev_button)
		set_pev(id,pev_button,(buttons & ~IN_ATTACK));
		return FMRES_HANDLED;	
	}
	
	if( get_user_button(id) & IN_ATTACK2 && is_user_alive(id))
	{
		new buttons = pev(id,pev_button)
		set_pev(id,pev_button,(buttons & ~IN_ATTACK2));
		return FMRES_HANDLED;	
	}
	
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public cvar_result_func(id, const cvar[], const value[]) 
{ 
	player_b_oldsen[id] = str_to_float(value)
	new svIndex[32] 
	num_to_str(id,svIndex,32)
	set_task(2.5,"resetsens",0,svIndex,32) 		
	
	
}

public resetsens(svIndex[]) 
{ 
	new id = str_to_num(svIndex) 
	
	if (player_b_oldsen[id] > 0.0)
	{
		client_cmd(id,"sensitivity %f",player_b_oldsen[id])
		player_b_oldsen[id] = 0.0
	}
	
	message_begin( MSG_ONE, get_user_msgid("StatusIcon"), {0,0,0}, id ) 
	write_byte( 0 )     
	write_string( "dmg_chem") 
	write_byte( 100 ) // red 
	write_byte( 100 ) // green 
	write_byte( 100 ) // blue 
	message_end()  
	
	
} 


/* ==================================================================================================== */

public Prethink_confuseme(id)
{
	if (player_b_oldsen[id] > 0.0)
		client_cmd(id,"sensitivity %f", 25.0)
	
}

public Bot_Setup()
{
	for (new id=0; id < MAX; id++)
	{
		if (is_user_connected(id) && is_user_bot(id))
		{
			if (random_num(1,3) == 1 && player_item_id[id] > 0)
				client_cmd(id,"say /drop")
			
			while (player_point[id] > 0)
			{
				player_point[id]--
				switch(random_num(1,4))
				{
					case 1: {
						player_agility[id]++
					}
					case 2: {
						player_strength[id]++
					}
					case 3: {
						player_intelligence[id]++
					}
					case 4: {
						player_dextery[id]++
					}
				}
			}
		}
	}
}

/* ==================================================================================================== */

public host_killed(id)
{
	if (player_lvl[id] > 1)
	{
		hudmsg(id,2.0,"Вы потеряли опыт за убийство заложников")
		Give_Xp(id,-floatround(3*player_lvl[id]/(1.65-player_lvl[id]/50)))
	}
	
}


/* ==================================================================================================== */
public show_menu_item(id)
{
	new text[513]

	format(text, 512, "\yНовые item - ^n\w1. Mag ring^n\w2. Paladin ring^n\w3. Monk ring^n\w4. Barbarian ring^n\w5. Assassin ring^n\w6. Necromancer ring^n\w7. Ninja ring^n\w8. Flashbang necklace^n\w9. Больше") 

	new keys 
	keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8)
	show_menu(id, keys, text) 
	return PLUGIN_HANDLED  
} 

public nowe_itemy(id, key) 
{ 
	switch(key) 
	{ 
		case 0: 
		{	
	      magring(id)
			
		}
		case 1: 
		{	
			paladinring(id)
		}
		case 2: 
		{	
			monkring(id)
		}
		case 3:
		{
			barbarianring(id)
		}
		case 4:
		{
			assassinring(id)
		}
		case 5:
		{
			nekromantring(id)
		}
		case 6:
		{
			ninjaring(id)
		}
		case 7:
		{
			flashbangnecklace(id)
		}
		case 8:
		{
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_HANDLED
}
public magring(id)
{
showitem(id,"Mag ring","общий","нет","<br>")
}
public paladinring(id)
{
showitem(id,"Paladin ring","общий","нет","<br>")
}
public monkring(id)
{
showitem(id,"Monk ring","общий","нет","<br>")
}
public barbarianring(id)
{
showitem(id,"Barbarian ring","общий","нет","<br>")
}
public assassinring(id)
{
showitem(id,"Assassin ring","общий","нет","<br>")
}
public nekromantring(id)
{
showitem(id,"Necromancer ring","общий","нет","<br>")
}
public ninjaring(id)
{
showitem(id,"Ninja ring","общий","нет","<br>")
}
public flashbangnecklace(id)
{
showitem(id,"Flashbang necklece","общий","нет","<br>")
}

/* ==================================================================================================== */


public showmenu(id)
{
	new text[513] 
	new keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9)
	
	
	format(text, 512, "\rОпции\R^n^n\y1.\w Инфо о предмете^n\y2.\w Выкинуть текущий item^n\y3.\w Помощь^n\y4.\w Информация об игроках^n\y5.\w Магазин^n\y6.\w Инфо о скиллах^n\y7.\w Смена Класса^n\y0.\w Выход") 
	
	show_menu(id, keys, text) 
	return PLUGIN_HANDLED  
} 


public option_menu(id, key) 
{ 
	switch(key) 
	{ 
		case 0: 
		{	
			iteminfo(id)
			
		}
		case 1: 
		{	
			dropitem(id)
		}
		case 2: 
		{	
			helpme(id)
		}
		case 3:
		{
			cmd_who(id)
		}
		case 4:
		{
			mana4(id)
		}
		case 5:
		{
			showskills(id)
		}
		case 6:
		{
			changerace(id)
		}
		case 9:
		{
			return PLUGIN_HANDLED
		}
	}
	
	return PLUGIN_HANDLED
}

public Prethink_froglegs(id)
{
	if (get_user_button(id) & IN_DUCK)
	{
		//start holding down button here, set to halflife time
		if (player_b_froglegs[id] == 1) 
		{
			player_b_froglegs[id] = floatround(halflife_time())
		}
		else
		{
			if (floatround(halflife_time())-player_b_froglegs[id] >= 2.0)
			{
				new Float:fl_iNewVelocity[3]
				VelocityByAim(id, 1000, fl_iNewVelocity)
				fl_iNewVelocity[2] = 210.0
				entity_set_vector(id, EV_VEC_velocity, fl_iNewVelocity)
				player_b_froglegs[id] = 1
			}
		}
	}
	else
	{
		player_b_froglegs[id] = 1
	}
}

/* ==================================================================================================== */

/*public select_class_query(id)
{
	if(is_user_bot(id) || asked_klass[id]!=0) return PLUGIN_HANDLED
	if(loaded_xp[id]==0)
	{
		load_xp(id)
		return PLUGIN_HANDLED
	}
	
	if(g_boolsqlOK)
	{
		asked_klass[id]=1
		new name[64]
		new data[1]
		data[0]=id
		new lx[28]
		if(player_class_lvl_save[id]==0)
		{
			if(get_cvar_num("diablo_sql_save")==0)
			{
				get_user_name(id,name,63)
				replace_all ( name, 63, "'", "Q" )
				replace_all ( name, 63, "`", "Q" )
				
				new q_command[512]
				format(q_command,511,"SELECT `class`,`lvl` FROM `%s` WHERE `nick`='%s' ",g_sqlTable,name)
				SQL_ThreadQuery(g_SqlTuple,"select_class_handle", q_command,data,1)
			}
			else if(get_cvar_num("diablo_sql_save")==1)
			{
				get_user_ip(id, name ,63,1)
				new q_command[512]
				format(q_command,511,"SELECT `class`,`lvl` FROM `%s` WHERE `ip`='%s' ",g_sqlTable,name)
				SQL_ThreadQuery(g_SqlTuple,"select_class_handle",q_command,data,1)
			}
			else if(get_cvar_num("diablo_sql_save")==2)
			{
				get_user_authid(id, name ,63)
				new q_command[512]
				format(q_command,511,"SELECT `class`,`lvl` FROM `%s` WHERE `sid`='%s' ",g_sqlTable,name)
				SQL_ThreadQuery(g_SqlTuple,"select_class_handle",q_command,data,1)
			}
		}
		else
		{
			for(new i=1;i<28;i++) lx[i]=player_class_lvl[id][i]
			select_class(id,lx)
		}
		
	}
	else sql_start()
	
	return PLUGIN_HANDLED  
} 

public select_class_handle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	new id=Data[0]
	if(Errcode)
	{
		D2_Log( true, "Error on select_class_handle query: %s",Error)
		asked_klass[id]=0
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		D2_Log( true, "Could not connect to SQL database.")
		asked_klass[id]=0
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		D2_Log( true, "select_class_handle Query failed.")
		asked_klass[id]=0
		return PLUGIN_CONTINUE
	}	 	
	
	if(SQL_MoreResults(Query))
	{
		new lx[28]
		
		while(SQL_MoreResults(Query))
		{
			new i = SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "class"))
			lx[i] = SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "lvl"))
			player_class_lvl[id][i] = lx[i]
			SQL_NextRow(Query)
		}
		
		if(asked_klass[id]==1)
		{
			asked_klass[id]=2
			select_class(id,lx)
		}
		
	}
	return PLUGIN_CONTINUE
}*/

public select_class(id)
{
new text4[512]  
format(text4, 511,"^n\wВаш общий уровень: %d^n^n\yВыбери Класс: ^n^n\r1. \wГерои^n\r2. \wДемоны^n\r3. \wЖивотные^n^n^n\r4. \wСоветы: Что выбрать?^n^n^n\dРазработал: HiTmanY^nСайт сервера:^nlpstrike.ru", player_TotalLVL[id]) 

new keys
keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)
show_menu(id, keys,text4, -1, "ChooseClass")
}

public select_class_menu(id, key) 
{ 
	//new lx[28] // <-- w nawiasie wpisz liczbк swoich klas + 1(none)
	g_haskit[id] = 0
	c_shake[id]=0
	c_shaked[id]=0
	c_damage[id]=0
	c_jump[id]=0
	c_mine[id]=0
	c_respawn[id]=0
	c_vampire[id]=0
	c_silent[id]=0
	c_antyarchy[id]=0
	c_antymeek[id]=0
	c_antyorb[id]=0
	c_antyfs[id]=0
	niewidzialnosc_kucanie[id] = 0;
	c_grenade[id] = 0
	c_blind[id] = 0
	c_darksteel[id]=0
	anty_flesh[id]=0
	c_blink[id]=0
	c_redirect[id]=0
	c_awp[id]=0
	niewidka[id]=0
	zmiana_skinu[id]=0
	cs2_reset_player_model(id);
	switch(key) 
	{ 
		case 0: 
		{
			PokazKlasy(id)               
		}
		case 1: 
		{       
			ShowKlasy(id)
		}
		case 2:
		{
			PokazZwierze(id)
		}
		case 3:
		{
		}
	}

	CurWeapon(id)
	give_knife(id)
	quest_gracza[id] = wczytaj_aktualny_quest(id);
	changeskin(id,1)
	
	return PLUGIN_HANDLED
}

public PokazKlasy(id)
{
	new flags[28]
	get_cvar_string("diablo_classes",flags,27) //<--- tu, gdzie jest 16 wpisz liczbк swoich klas
	new text3[512]
	format(text3, 512,"\yГерои: ^n\w1. \yМаг^t\wУровень: \r%i^n\w2. \yМонах^t\wУровень: \r%i^n\w3. \yПаладин^t\wУровень: \r%i^n\w4. \yАссассин^t\wУровень: \r%i^n\w5. \yНекромант^t\wУровень: \r%i^n\w6. \yВарвар^t\wУровень: \r%i^n\w7. \yНиндзя^t\wУровень: \r%i^n\w8. \yАмазонка^t\wУровень: \r%i^n^n\w0. \yВыход^n^n\dlpstrike.ru^n\dСайт сервера",
	player_class_lvl[id][1],player_class_lvl[id][2],player_class_lvl[id][3],player_class_lvl[id][4],player_class_lvl[id][5],player_class_lvl[id][6],player_class_lvl[id][7],player_class_lvl[id][8])

	new keyspiata
	keyspiata = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<9)
	show_menu(id, keyspiata, text3, -1, "Heroes")
}

public PokazMeni(id, key)
{ 
/* Menu:
* Wybierz klase:
* 1:Mag
* 2:Monk
* 3:Paladin
* 4:Assassin
* 5:Necromancer
* 6:Barbarian
* 7:Ninja
* 8:Amazon
* 0:Wstecz
*/
//new lx[28] // <-- tutaj wpisz liczbк swoich klas + 1(none)
g_haskit[id] = 0
c_shake[id]=0
c_damage[id]=0
c_jump[id]=0
c_mine[id]=0
c_respawn[id]=0
c_vampire[id]=0
zmiana_skinu[id]=0
switch(key) 
{ 
    case 0: 
    {    
        player_class[id] = Mag
        MYSQLX_SetDataForRace( id )       
    }
    case 1: 
    {    
        player_class[id] = Monk
	zmiana_skinu[id]=1
	changeskin(id,0)
        MYSQLX_SetDataForRace( id )
    }
    case 2: 
    {    
        player_class[id] =  Paladin
        MYSQLX_SetDataForRace( id )
    }
    case 3: 
    {    
        player_class[id] = Assassin
        MYSQLX_SetDataForRace( id )
    }
    case 4: 
    {            
        player_class[id] = Necromancer
        g_haskit[id] = 1
		c_respawn[id]=4
		c_vampire[id]=random_num(1,3)
        MYSQLX_SetDataForRace( id )
    }
    case 5: 
    {    
        player_class[id] = Barbarian      
        MYSQLX_SetDataForRace( id )
    }
    case 6: 
    {    
        player_class[id] = Ninja
        MYSQLX_SetDataForRace( id )
    }
    case 7: 
    {    
        player_class[id] = Amazon
        g_GrenadeTrap[id] = 1    
        MYSQLX_SetDataForRace( id )
    }
    case 9: 
    { 
        select_class(id)
    }
}
CurWeapon(id)
quest_gracza[id] = wczytaj_aktualny_quest(id);
give_knife(id)

return PLUGIN_HANDLED
}

public ShowKlasy(id) 
{
	new text2[512]
	format(text2, 511,"\yДемоны: ^n\w1. \yКровавый ворон^t\wУровень: \r%i^n\w2. \yДуриель^t\wУровень: \r%i^n\w3. \yМефисто^t\wУровень: \r%i^n\w4. \yИзуал^t\wУровень: \r%i^n\w5. \yДиабло^t\wУровень: \r%i^n\w6. \yБаал^t\wУровень: \r%i^n\w7. \yПадший^t\wУровень: \r%i^n\w8. \yБес^t\wУровень: \r%i^n^n\w0. \yВыход^n^n\dlpstrike.ru^n\dСайт сервера",
	player_class_lvl[id][9],player_class_lvl[id][10],player_class_lvl[id][11],player_class_lvl[id][12],player_class_lvl[id][13],player_class_lvl[id][14],player_class_lvl[id][15],player_class_lvl[id][16])

	new szosta
	szosta = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<9)
	show_menu(id, szosta,text2)

}
public PressedKlasy(id, key)
{
	/* Menu:
	* Demony:
	* 1:BloodRaven
	* 2:Duriel
	* 3:Mephisto
	* 4:Izual
	* 5:Diablo
	* 6:Baal
	* 7:Fallen
	* 8:Imp
	* 0:Wstecz
	*/
	//new lx[28] // <-- tutaj wpisz liczbк swoich klas + 1(none)
	g_haskit[id] = 0
	c_vampire[id]=0
	c_silent[id]=0
	c_jump[id]=0
	c_antyarchy[id]=0
	c_antymeek[id]=0
	c_antyorb[id]=0
	c_antyfs[id]=0
	niewidzialnosc_kucanie[id] = 0;
	c_silent[id]=0
	c_grenade[id] = 0
	c_darksteel[id]=0
	c_shaked[id]=0
	c_blink[id]=0


	switch (key) 
	{
		case 0:
		{    
			player_class[id] = BloodRaven
			MYSQLX_SetDataForRace( id )
			emit_sound(id,CHAN_STATIC,"diablo_lp/bloodraventaunt1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
		case 1: 
		{    
			player_class[id] = Duriel
			MYSQLX_SetDataForRace( id )
		}
		case 2: 
		{    
			player_class[id] = Mephisto
			c_silent[id]=1
			MYSQLX_SetDataForRace( id )
		}
		case 3: 
		{    
			player_class[id] = Izual
			izual_ring[id] = 1
			c_blink[id]=floatround(halflife_time())
			MYSQLX_SetDataForRace( id )
		}
		case 4: 
		{    
			player_class[id] = Diablo
			c_silent[id]=1
			MYSQLX_SetDataForRace( id )
			emit_sound(id,CHAN_STATIC,"diablo_lp/diablo_1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
		case 5: 
		{    
			player_class[id] = Baal
			c_blink[id] = floatround(halflife_time())
			MYSQLX_SetDataForRace( id )
		}
		case 6: 
		{    
			player_class[id] = Fallen
			c_darksteel[id]=29
			c_blind[id] = 20
			anty_flesh[id]=1
			c_shaked[id]=5
	  
			MYSQLX_SetDataForRace( id )
			if(player_lvl[id]>49)
			{
				//new float:summa = player_lvl[id]/10.0;
				fallen_fires[id] = floatround(player_lvl[id]/10.0, floatround_floor);
			}
			new rnds = random(1);
			switch(rnds)
			{
			  case 0:
			  {
				emit_sound(id,CHAN_STATIC,"diablo_lp/fallen_1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			  }
			  case 1:
			  {
				emit_sound(id,CHAN_STATIC,"diablo_lp/fallen_2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			  }
			}
		}
		case 7: 
		{    
			player_class[id] = Imp
			c_blink[id] = floatround(halflife_time())
			if(floatround(player_lvl[id]/2.0) < 10)
			{
				imp_fires[id] = 10
			}
			else
			{
				imp_fires[id] = floatround(player_lvl[id]/2.0);
			}
			MYSQLX_SetDataForRace( id )
		}
		case 9: 
		{ 
			select_class(id)
		}
	}
	CurWeapon(id)
	give_knife(id)
	quest_gracza[id] = wczytaj_aktualny_quest(id);
	changeskin(id,1)
    
	return PLUGIN_HANDLED
}

public PokazZwierze(id) 
{	
	new iLen,text5[512]
	iLen += format(text5, 511, "\yЗвери/Животные: ^n\w1. \yЗакарум^t\wУровень: \r%i^n\w2. \yСаламандра^t\wУровень: \r%i^n",player_class_lvl[id][17],player_class_lvl[id][18]);
	iLen += format(text5[iLen], charsmax(text5) - iLen, "\w3. \yГигантский комар^t\wУровень: \r%i^n\w4. \yЛедяной ужас^t\wУровень: \r%i^n",player_class_lvl[id][19],player_class_lvl[id][20]);
	iLen += format(text5[iLen], charsmax(text5) - iLen, "\w5. \yИнфидель^t\wУровень: \r%i^n\w6. \yГигантский паук^t\wУровень: \r%i^n",player_class_lvl[id][21],player_class_lvl[id][22]);
	iLen += format(text5[iLen], charsmax(text5) - iLen, "\w7. \yАдский кот^t\wУровень: \r%i^n^n",player_class_lvl[id][23]);
	iLen += format(text5[iLen], charsmax(text5) - iLen, "\w0. \yВыход^n^n\dlpstrike.ru^n\dСайт сервера");
	
	static key
	key = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9)
	show_menu(id, key,text5)

}
public PokazZwierz( id, item ) 
{
	/* Menu:
	---.Zwierzeta
	1.Zakarum
	2.Viper
	3.Mosquito
	4.Frozen
	5.Infidel
	6.Gigantyczny Pajak
	7.Sniegowy Tulacz
	8.Piekielna Krowa
	* 0:Wstecz
	*/
	//new lx[28] // <-- tutaj wpisz liczbк swoich klas + 1(none) 
	
	g_haskit[id] = 0
	c_redirect[id]=0
	c_antymeek[id]=0
	c_silent[id]=0
	c_awp[id]=0
	c_jump[id]=0
	c_vampire[id]=0

	switch (item) {
		case 0:
		{    
			player_class[id] = Zakarum
			MYSQLX_SetDataForRace( id )
			c_blink[id] = floatround(halflife_time());
		}
		case 1: 
		{    
			player_class[id] = Viper
			MYSQLX_SetDataForRace( id )
		}
		case 2: 
		{    
			player_class[id] = Mosquito
			MYSQLX_SetDataForRace( id )
		}
		case 3: 
		{    
			player_class[id] = Frozen
			c_silent[id]=1
			MYSQLX_SetDataForRace( id )
			if(floatround(player_lvl[id]/2.0) < 10)
			{
				frozen_colds[id] = 10
			}
			else
			{
				frozen_colds[id] = floatround(player_lvl[id]/2.0);
			}
		}
		case 4: 
		{    
			player_class[id] = Infidel
			cs2_set_player_model(id, infidel_model_short);
			MYSQLX_SetDataForRace( id )
		}
		case 5: 
		{    
			player_class[id] = GiantSpider
			MYSQLX_SetDataForRace( id )
		}
		case 6: 
		{    
			player_class[id] = SabreCat
			if(is_user_alive(id))
			{
				fm_give_item(id, "weapon_smokegrenade")
			}
			MYSQLX_SetDataForRace( id )
		}
		case 9: 
		{ 
			select_class(id)
		}
	}
	CurWeapon(id)
	give_knife(id)
	quest_gracza[id] = wczytaj_aktualny_quest(id);
	
	return PLUGIN_HANDLED
}

public PokazPremiumy(id)
{
	new text6[512]
	format(text6, 511,"\yПремиум: ^n\w1. \yGriswold^t\wУровень: \r%i^n\w2. \yTheSmith^t\wУровень: \r%i^n\w3. \yDemonolog^t\wУровень: \r%i^n^n\w0. \yВыход^n^n\rДоступ к премиум классам.^n\rкупить на lpstrike.ru",player_class_lvl[id][24],player_class_lvl[id][25],player_class_lvl[id][26],player_class_lvl[id][27])

	new usma
	usma = (1<<0)|(1<<1)|(1<<2)|(1<<9)
	show_menu(id, usma,text6)

}
public PokazPremium(id, key) 
{
	/* Menu:
	* Wybierz klase:
	* 1:Griswold
	* 2:TheSmith
	* 3:Demonolog
	* 4:VipCztery
	* 0:Wstecz
	*/
	//new lx[28] // <-- tutaj wpisz liczbк swoich klas + 1(none)
	g_haskit[id] = 0
	c_antymeek[id]=0
	c_silent[id]=0
	c_antyarchy[id]=0
	c_jump[id]=0
	c_vampire[id]=0
	niewidka[id]=0

	switch (key)
	{
		case 0: 
		if(player_premium[id]==1)
		{    
			player_class[id] = Griswold
			c_antymeek[id]=1
			c_silent[id]=1
			c_antyarchy[id]=1
			c_jump[id]=2
			c_vampire[id]=random_num(1,2)
			MYSQLX_SetDataForRace( id )
		}
		else
		{
			hudmsg(id,6.0,"У вас нет доступа к премиум классам^n Купите доступ за 200 рублей на сайте сервера")
		}
		case 1:
		{
			if(player_premium[id]==1)
			{    
				player_class[id] = TheSmith
				c_antymeek[id]=1
				c_silent[id]=1
				c_antyarchy[id]=1
				c_jump[id]=2
				niewidka[id]=1
				c_vampire[id]=random_num(1,2)
				MYSQLX_SetDataForRace( id )
			}
			else
			{
				hudmsg(id,6.0,"У вас нет доступа к премиум классам^n Купите доступ за 200 рублей на сайте сервера")
			}
		}
		case 2:
		{
			if(player_premium[id]==1)
			{    
				
				player_class[id] = Demonolog
				c_antymeek[id]=1
				c_silent[id]=1
				c_antyarchy[id]=1
				c_jump[id]=2
				c_vampire[id]=random_num(1,2)
				MYSQLX_SetDataForRace( id )
			}
			else
			{
				hudmsg(id,6.0,"У вас нет доступа к премиум классам^n Купите доступ за 200 рублей на сайте сервера")
			}
		}
		case 9: 
		{ 
			select_class(id)
		}
	}
	CurWeapon(id)
	give_knife(id)
	quest_gracza[id] = wczytaj_aktualny_quest(id);
		
	return PLUGIN_HANDLED
} 

/* ==================================================================================================== */
public check_class()
{
	for (new id=0; id < 33; id++)
	{
  		if((player_class[id] == Ninja) && (is_user_connected(id)))
		{
			if (is_user_alive(id)) set_user_armor(id,100)	
		}
		set_gravitychange(id)
		set_renderchange(id)
	}
}
/* ==================================================================================================== */

public add_barbarian_bonus(id)
{
	if (player_class[id] == Barbarian)
	{	
		change_health(id,30,0,"")
	}
	if (player_class[id] == Baal)
	{	
		change_health(id,20,0,"")
	}
	if (player_class[id] == Griswold)
	{	
		change_health(id,40,0,"")
	}
	if (player_class[id] == TheSmith)
	{	
		change_health(id,40,0,"")
	}
	if (player_class[id] == Demonolog)
	{	
		change_health(id,40,0,"")
	}
}

/* ==================================================================================================== */

public add_bonus_necromancer(attacker_id,id)
{
	if (player_class[attacker_id] == Necromancer)
	{
		if (get_user_health(id) - 10 <= 0)
		{
			set_user_health(id,random_num(1,3))
		}
		else
		{
			new dmg = random_num(6,12)
			change_health(id,-dmg,0,"necromancer bonus")
			change_health(attacker_id,1,0,"")
		}
	}
}

/* ==================================================================================================== */

//What modules are required
public plugin_modules()
{
	require_module("engine")
	require_module("cstrike")
	require_module("fun")
	require_module("fakemeta")
}

/* ==================================================================================================== */

//Find the nearest alive opponent in our view
public UTIL_FindNearestOpponent(id,maxdist)
{
	new best = 99999
	new entfound = -1
	new MyOrigin[3]
	get_user_origin(id,MyOrigin)
	
	for (new i=1; i < MAX; i++)
	{
		if (i == id || !is_user_connected(i) || !is_user_alive(i) || get_user_team(id) == get_user_team(i))
			continue
		
		new TempOrigin[3],Float:fTempOrigin[3]
		get_user_origin(i,TempOrigin)
		IVecFVec(TempOrigin,fTempOrigin)
		
		if (!UTIL_IsInView(id,i))
			continue
		
		
		new dist = get_distance ( MyOrigin,TempOrigin ) 
		
		if ( dist < maxdist && dist < best)
		{
			best = dist
			entfound = i
		}		
	}
	
	return entfound
}

/* ==================================================================================================== */

//Basicly see's if we can draw a straight line to the target without interference
public bool:UTIL_IsInView(id,target)
{
	new Float:IdOrigin[3], Float:TargetOrigin[3], Float:ret[3] 
	new iIdOrigin[3], iTargetOrigin[3]
	
	get_user_origin(id,iIdOrigin,1)
	get_user_origin(target,iTargetOrigin,1)
	
	IVecFVec(iIdOrigin,IdOrigin)
	IVecFVec(iTargetOrigin, TargetOrigin)
	
	if ( trace_line ( 1, IdOrigin, TargetOrigin, ret ) == target)
		return true
	
	if ( get_distance_f(TargetOrigin,ret) < 10.0)
		return true
	
	return false
	
}
/* ==================================================================================================== */

public item_dagon(id)
{
	if (player_b_dagfired[id])
	{
		set_hudmessage(220, 30, 30, -1.0, 0.40, 0, 3.0, 2.0, 0.2, 0.3, 5)
		show_hudmessage(id, "Этот item можно использовать только 1 раз за раунд") 
		return PLUGIN_HANDLED
	}
	//Target nearest non-friendly player
	new target = UTIL_FindNearestOpponent(id,600+player_intelligence[id]*20)
	
	if (target == -1) 
		return PLUGIN_HANDLED
	
	new DagonDamage = player_b_dagon[id]*20
	new Red = 0
	
	if (player_b_dagon[id] == 1) Red = 175
	else if (player_b_dagon[id] == 2) Red = 225
	else if (player_b_dagon[id] > 2) Red = 255
	
	
	//Dagon damage done is reduced by the targets dextery
	DagonDamage-=player_dextery[target]*2
	
	if (DagonDamage < 0)
		DagonDamage = 0
	
	new Hit[3]
	get_user_origin(target,Hit)

	//Create Lightning
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(1) // TE_BEAMENTPOINT
	write_short(id)
	write_coord(Hit[0])
	write_coord(Hit[1])
	write_coord(Hit[2])
	write_short(sprite_lgt)
	write_byte(0)
	write_byte(1)
	write_byte(3)
	write_byte(10)	//WITD
	write_byte(60)
	write_byte(Red)
	write_byte(0)
	write_byte(0)
	write_byte(100)	//BRIGT
	write_byte(0)
	message_end()
	
	player_b_dagfired[id] = true
	
	//Apply damage

	change_health(target,-DagonDamage,id,"dagon")
	Display_Fade(target,2600,2600,0,255,0,0,15)
	hudmsg(id,2.0,"Ваши удары dagon %i, %i", DagonDamage, player_dextery[target]*2)

	return PLUGIN_HANDLED
	
	
}

/* ==================================================================================================== */

/* ==================================================================================================== */

//Will return 1 if user has amount of money and then substract
public bool:UTIL_Buyformoney(id,amount)
{
	if (cs_get_user_money(id) >= amount)
	{
		cs_set_user_money(id,cs_get_user_money(id)-amount)
		return true
	}
	else
	{
		hudmsg(id,2.0,"Не хватает денег")
		return false
	}
	
	return false
}
public buyrune(id)
{
	//new text[513] 
	
	//format(text, 512, "\yМагазин item - ^n\w1. \yКупить случайный Item! \r$5000^n^n\w0. \yВыход^n\y/gold,/g - магазин золота") 
	
	//new keys = (1<<0)|(1<<9)
	//show_menu(id, keys, text, -1, "ChooseRune") 
	return PLUGIN_HANDLED  
} 


public select_rune_menu(id, key) 
{ 
	switch(key) 
	{ 

		case 0:
		{	
			if (!UTIL_Buyformoney(id,5000))
				return PLUGIN_HANDLED
			award_item(id,0)
			return PLUGIN_HANDLED
		}	
		case 9: 
		{	
			return PLUGIN_HANDLED
		}
		

	}
	
	return PLUGIN_HANDLED
}

public upgrade_item(id)
{
	if(item_durability[id]>0) item_durability[id] += random_num(-50,50)
	if(item_durability[id]<1)
	{
		dropitem(id)
		return
	}
	if(player_b_jumpx[id]>0) player_b_jumpx[id] += random_num(0,1)
	
	if(player_b_vampire[id]>0)
	{
		if(player_b_vampire[id]>20) player_b_vampire[id] += random_num(-1,2)
		else if(player_b_vampire[id]>10) player_b_vampire[id] += random_num(0,2)
		else player_b_vampire[id]+= random_num(1,3)
	}
	if(player_b_damage[id]>0) player_b_damage[id] += random_num(0,3) 
	if(player_b_money[id]!=0) player_b_money[id]+= random_num(-100,300)	
	if(player_b_gravity[id]>0)
	{
		if(player_b_gravity[id]<3) player_b_gravity[id]+=random_num(0,2)
		else if(player_b_gravity[id]<5) player_b_gravity[id]+=random_num(1,3)
		else if(player_b_gravity[id]<8) player_b_gravity[id]+=random_num(-1,3)
		else if(player_b_gravity[id]<10) player_b_gravity[id]+=random_num(0,1)
	}
	if(player_b_inv[id]>0)
	{
		if(player_b_inv[id]>200) player_b_inv[id]-=random_num(0,50)
		else if(player_b_inv[id]>100) player_b_inv[id]-=random_num(-25,50)
		else if(player_b_inv[id]>50) player_b_inv[id]-=random_num(-10,20)
		else if(player_b_inv[id]>25) player_b_inv[id]-=random_num(-10,10)
	}
	if(player_b_grenade[id]>0)
	{
		if(player_b_grenade[id]>4) player_b_grenade[id]-=random_num(0,2)
		else if(player_b_grenade[id]>2) player_b_grenade[id]-=random_num(0,1)
		else if(player_b_grenade[id]==2) player_b_grenade[id]-=random_num(-1,1)
	}
	if(player_b_reduceH[id]>0) player_b_reduceH[id]-=random_num(0,player_b_reduceH[id])
	if(player_b_theif[id]>0) player_b_theif[id] += random_num(0,250)
	if(player_b_respawn[id]>0)
	{
		if(player_b_respawn[id]>2) player_b_respawn[id]-=random_num(0,1)
		else if(player_b_respawn[id]>1) player_b_respawn[id]-=random_num(-1,1)
	}
	if(player_b_explode[id]>0)player_b_explode[id] += random_num(0,50)
	if(player_b_heal[id]>0)
	{
		if(player_b_heal[id]>20) player_b_heal[id]+= random_num(-1,3)
		else if(player_b_heal[id]>10) player_b_heal[id]+= random_num(0,4)
		else player_b_heal[id]+= random_num(2,6)
	}
	if(player_b_blind[id]>0)
	{
		if(player_b_blind[id]>5) player_b_blind[id]-= random_num(0,2)
		else if(player_b_blind[id]>1) player_b_blind[id]-= random_num(0,1)
	}
		
	if(player_b_teamheal[id]>0) player_b_teamheal[id] += random_num(0,5)
	
	if(player_b_redirect[id]>0) player_b_redirect[id]+= random_num(0,2)
	if(player_b_fireball[id]>0) player_b_fireball[id]+= random_num(0,33)
	if(player_b_ghost[id]>0) player_b_ghost[id]+= random_num(0,1)
	if(player_b_windwalk[id]>0) player_b_windwalk[id] += random_num(0,1)

	if(player_b_dagon[id]>0) player_b_dagon[id] += random_num(0,1)
	if(player_b_sniper[id]>0)
	{
		if(player_b_sniper[id]>5) player_b_sniper[id]-=random_num(0,2)
		else if(player_b_sniper[id]>2) player_b_sniper[id]-=random_num(0,1)
		else if(player_b_sniper[id]>1) player_b_sniper[id]-=random_num(-1,1)
	}
	if(player_b_awpmaster[id]>0)
	{
		if(player_b_awpmaster[id]>5) player_b_awpmaster[id]-=random_num(0,2)
		else if(player_b_awpmaster[id]>2) player_b_awpmaster[id]-=random_num(0,1)
		else if(player_b_awpmaster[id]>1) player_b_awpmaster[id]-=random_num(-1,1)
	}
	if(player_b_dglmaster[id]>0)
	{
    player_b_dglmaster[id]-=random_num(5,8)
	}
	if(player_b_m4master[id]>0)
	{
		player_b_m4master[id]-=random_num(5,8)
	}
	if(player_b_akmaster[id]>0)
	{
		player_b_akmaster[id]-=random_num(5,8)
	}
	if(player_b_m3master[id]>0)
	{
		if(player_b_m3master[id]>5) player_b_m3master[id]-=random_num(0,2)
		else if(player_b_m3master[id]>2) player_b_m3master[id]-=random_num(0,1)
		else if(player_b_m3master[id]>1) player_b_m3master[id]-=random_num(-1,1)
	}

	if(player_b_extrastats[id]>0) player_b_extrastats[id] += random_num(0,2)
	if(player_b_firetotem[id]>0) player_b_firetotem[id] += random_num(0,50)

	if(player_b_darksteel[id]>0) player_b_darksteel[id] += random_num(0,2)
	if(player_b_mine[id]>0) player_b_mine[id] += random_num(0,1)
	if(player_sword[id]>0)
	{
		if(player_b_jumpx[id]==0 && random_num(0,10)==10) player_b_jumpx[id]=1
		if(player_b_vampire[id]==0 && random_num(0,10)==10) player_b_vampire[id]=1
		if(player_b_gravity[id]==0 && random_num(0,10)==10) player_b_gravity[id]=1
		if(player_b_respawn[id]==0 && random_num(0,10)==5) player_b_respawn[id]=15
		else if(player_b_respawn[id]>2 && random_num(0,10)==5) player_b_respawn[id]+=random_num(0,1)
		if(player_b_ghost[id]==0 && random_num(0,10)==10) player_b_ghost[id]=1
		if(player_b_darksteel[id]==0 && random_num(0,10)==10) player_b_darksteel[id]=1
	}
	if(player_ultra_armor[id]>0) player_ultra_armor[id]++
	
}

/* ==================================================================================================== */

//Blocks fullupdate (can reset hud)
public fullupdate(id) 
{
	return PLUGIN_HANDLED
}

/* ==================================================================================================== */

public add_bonus_scoutdamage(attacker_id,id,weapon)
{
	if (player_b_sniper[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && weapon == CSW_SCOUT && player_class[attacker_id]!=Ninja)
	{
		
		if (!is_user_alive(id))
			return PLUGIN_HANDLED
		
		if (random_num(1,player_b_sniper[attacker_id]) == 1)
			UTIL_Kill(attacker_id,id,"scout")
		
	}
	
	return PLUGIN_HANDLED
}

/* ==================================================================================================== */
public add_bonus_cawpmasterdamage(attacker_id,id,weapon)
{
if (c_awp[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && weapon == CSW_AWP)
{

if (!is_user_alive(id))
return PLUGIN_HANDLED

if (random_num(1,c_awp[attacker_id]) == 1)
UTIL_Kill(attacker_id,id,"awp")

}

return PLUGIN_HANDLED
}

/* ==================================================================================================== */
public add_bonus_m4masterdamage(attacker_id,id,weapon)
{
if (player_b_m4master[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && weapon == CSW_M4A1)
{

if (!is_user_alive(id))
return PLUGIN_HANDLED

if (random_num(1,player_b_m4master[attacker_id]) == 1)
UTIL_Kill(attacker_id,id,"m4a1")

}

return PLUGIN_HANDLED
}

/* ==================================================================================================== */
public add_bonus_akmasterdamage(attacker_id,id,weapon)
{
if (player_b_akmaster[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && weapon == CSW_AK47)
{

if (!is_user_alive(id))
return PLUGIN_HANDLED

if (random_num(1,player_b_akmaster[attacker_id]) == 1)
UTIL_Kill(attacker_id,id,"ak47")

}

return PLUGIN_HANDLED
}

/* ==================================================================================================== */
public add_bonus_awpmasterdamage(attacker_id,id,weapon)
{
if (player_b_awpmaster[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && weapon == CSW_AWP)
{

if (!is_user_alive(id))
return PLUGIN_HANDLED

if (random_num(1,player_b_awpmaster[attacker_id]) == 1)
UTIL_Kill(attacker_id,id,"awp")

}

return PLUGIN_HANDLED
}

/* ==================================================================================================== */
public add_bonus_dglmasterdamage(attacker_id,id,weapon)
{
if (player_b_dglmaster[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && weapon == CSW_DEAGLE)
{

if (!is_user_alive(id))
return PLUGIN_HANDLED

if (random_num(1,player_b_dglmaster[attacker_id]) == 1)
UTIL_Kill(attacker_id,id,"deagle")

}

return PLUGIN_HANDLED
}

/* ==================================================================================================== */
public add_bonus_m3masterdamage(attacker_id,id,weapon)
{
if (player_b_m3master[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && weapon == CSW_M3)
{

if (!is_user_alive(id))
return PLUGIN_HANDLED

if (random_num(1,player_b_m3master[attacker_id]) == 1)
UTIL_Kill(attacker_id,id,"m3")

}

return PLUGIN_HANDLED
}

/* ==================================================================================================== */

public add_bonus_illusion(attacker_id,id,weapon)
{
	if(HasFlag(id,Flag_Illusion))
	{
		new weaponname[32]
		get_weaponname( weapon, weaponname, 31 ) 
		replace(weaponname, 31, "weapon_", "")
		UTIL_Kill(attacker_id,id,weaponname)
	}
}

/* ==================================================================================================== */

public item_take_damage(id,damage)
{
	new itemdamage = get_cvar_num("diablo_durability")
	
	if (player_item_id[id] > 0 && item_durability[id] >= 0 && itemdamage> 0 && damage > 5)
	{
		//Make item take damage
		if (item_durability[id] - itemdamage <= 0)
		{
			item_durability[id]-=itemdamage
			dropitem(id)
		}
		else
		{
			item_durability[id]-=itemdamage
		}
		
	}
}

/* ==================================================================================================== */

//From twistedeuphoria plugin
public Prethink_Doublejump(id)
{
	if(!is_user_alive(id)) 
		return PLUGIN_HANDLED
	
	if((get_user_button(id) & IN_JUMP) && !(get_entity_flags(id) & FL_ONGROUND) && !(get_user_oldbutton(id) & IN_JUMP))
	{
		if((jumps[id] < player_b_jumpx[id]) || (jumps[id] < c_jump[id]))
		{
			dojump[id] = true
			jumps[id]++
			return PLUGIN_HANDLED
		}
	}
	if((get_user_button(id) & IN_JUMP) && (get_entity_flags(id) & FL_ONGROUND))
	{
		jumps[id] = 0
		return PLUGIN_CONTINUE
	}
	
	return PLUGIN_HANDLED
}

public Postthink_Doubeljump(id)
{
	if(!is_user_alive(id)) 
		return PLUGIN_HANDLED
	
	if(dojump[id] == true)
	{
		new Float:velocity[3]	
		entity_get_vector(id,EV_VEC_velocity,velocity)
		velocity[2] = random_float(265.0,285.0)
		entity_set_vector(id,EV_VEC_velocity,velocity)
		dojump[id] = false
		return PLUGIN_CONTINUE
	}
	
	return PLUGIN_HANDLED
}


/* ==================================================================================================== */

public eventGrenade(id) 
{
	new id = read_data(1)
	if (player_b_grenade[id] > 0 || player_b_smokehit[id] > 0 || player_class[id] == Diablo)
	{
		set_task(0.1, "makeGlow", id)
	}
}

public makeGlow(id) 
{
	new grenade
	new greModel[100]
	grenade = get_grenade(id) 
	
	if( grenade ) 
	{	
		entity_get_string(grenade, EV_SZ_model, greModel, 99)
		
		if(equali(greModel, "models/w_hegrenade.mdl" ) && player_b_grenade[id] > 0 || c_grenade[id] > 0 || player_class[id] == Diablo)	
			set_rendering(grenade, kRenderFxGlowShell, 255,0,0, kRenderNormal, 255)
		
		if(equali(greModel, "models/w_smokegrenade.mdl" ) && player_b_smokehit[id] > 0 )	
		{
			set_rendering(grenade, kRenderFxGlowShell, 0,255,255, kRenderNormal, 255)
		}
	}
}

/* ==================================================================================================== */

public BoostStats(id,amount)
{
	player_strength[id]+=amount
	player_dextery[id]+=amount
	player_agility[id]+=amount
	player_intelligence[id]+=amount
}

public SubtractStats(id,amount)
{
	player_strength[id]-=amount
	player_dextery[id]-=amount
	player_agility[id]-=amount
	player_intelligence[id]-=amount
}

public BoostRing(id)
{
	switch(player_ring[id])
	{
		case 1: player_intelligence[id]+=5
		case 2: player_strength[id]+=5
		case 3: player_agility[id]+=5
	}
}

public SubtractRing(id)
{
	switch(player_ring[id])
	{
		case 1: player_intelligence[id]-=5
		case 2: player_strength[id]-=5
		case 3: player_agility[id]-=5
	}
}

/* ==================================================================================================== */

public SelectBotRace(id)
{
	if (!is_user_bot(id))
		return PLUGIN_HANDLED
	
	
	
	if (player_class[id] == 0)
	{
		player_class[id] = random_num(1,23)
	}
	
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public showskills(id)
{
	new Skillsinfo[768]
	format(Skillsinfo,767,"У вас %i Выносливости - это даёт тебе %i HP<br><br>У вас %i ловкость - увел. скорость на %i% и умен. урон от магии на %i%<br>У вас %i силы - Повышает щанс найти улучш. предмет и умен. урон на %0.0f%%<br><br>У вас %i интеллекта - увел. прочность и силу действия item<br>",
	player_strength[id],
	player_strength[id]*2,
	player_dextery[id],
	floatround(player_dextery[id]*1.3),
	player_dextery[id]*3,
	player_agility[id],
	player_damreduction[id]*100,
	player_intelligence[id])
	
	showitem(id,"Способности","Нет","Нет", Skillsinfo)
}

/* ==================================================================================================== */

public UTIL_Teleport(id,distance)
{	
	Set_Origin_Forward(id,distance)
	
	new origin[3]
	get_user_origin(id,origin)
	if(player_class[id] == Zakarum)
	{
		message_begin(MSG_BROADCAST ,SVC_TEMPENTITY) //message begin
		write_byte(TE_PARTICLEBURST )
		write_coord(origin[0]) // origin
		write_coord(origin[1]) // origin
		write_coord(origin[2]) // origin
		write_short(30) // radius
		write_byte(208) // particle color
		write_byte(10) // duration * 10 will be randomized a bit
		message_end()
	}
	else
	{
		//Particle burst ie. teleport effect	
		message_begin(MSG_BROADCAST ,SVC_TEMPENTITY) //message begin
		write_byte(TE_PARTICLEBURST )
		write_coord(origin[0]) // origin
		write_coord(origin[1]) // origin
		write_coord(origin[2]) // origin
		write_short(20) // radius
		write_byte(1) // particle color
		write_byte(4) // duration * 10 will be randomized a bit
		message_end()	
	}
	emit_sound(id,CHAN_STATIC,"diablo_lp/teleport.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
}

stock Set_Origin_Forward(id, distance) 
{
	new Float:origin[3]
	new Float:angles[3]
	new Float:teleport[3]
	new Float:heightplus = 10.0
	new Float:playerheight = 64.0
	new bool:recalculate = false
	new bool:foundheight = false
	pev(id,pev_origin,origin)
	pev(id,pev_angles,angles)
	
	teleport[0] = origin[0] + distance * floatcos(angles[1],degrees) * floatabs(floatcos(angles[0],degrees));
	teleport[1] = origin[1] + distance * floatsin(angles[1],degrees) * floatabs(floatcos(angles[0],degrees));
	teleport[2] = origin[2]+heightplus
	
	while (!Can_Trace_Line_Origin(origin,teleport) || Is_Point_Stuck(teleport,48.0))
	{	
		if (distance < 10)
			break;
		
		//First see if we can raise the height to MAX playerheight, if we can, it's a hill and we can teleport there	
		for (new i=1; i < playerheight+20.0; i++)
		{
			teleport[2]+=i
			if (Can_Trace_Line_Origin(origin,teleport) && !Is_Point_Stuck(teleport,48.0))
			{
				foundheight = true
				heightplus += i
				break
			}
			
			teleport[2]-=i
		}
		
		if (foundheight)
			break
		
		recalculate = true
		distance-=10
		teleport[0] = origin[0] + (distance+32) * floatcos(angles[1],degrees) * floatabs(floatcos(angles[0],degrees));
		teleport[1] = origin[1] + (distance+32) * floatsin(angles[1],degrees) * floatabs(floatcos(angles[0],degrees));
		teleport[2] = origin[2]+heightplus
	}
	
	if (!recalculate)
	{
		set_pev(id,pev_origin,teleport)
		return PLUGIN_CONTINUE
	}
	
	teleport[0] = origin[0] + distance * floatcos(angles[1],degrees) * floatabs(floatcos(angles[0],degrees));
	teleport[1] = origin[1] + distance * floatsin(angles[1],degrees) * floatabs(floatcos(angles[0],degrees));
	teleport[2] = origin[2]+heightplus
	set_pev(id,pev_origin,teleport)
	
	return PLUGIN_CONTINUE
}

stock bool:Can_Trace_Line_Origin(Float:origin1[3], Float:origin2[3])
{	
	new Float:Origin_Return[3]	
	new Float:temp1[3]
	new Float:temp2[3]
	
	temp1[x] = origin1[x]
	temp1[y] = origin1[y]
	temp1[z] = origin1[z]-30
	
	temp2[x] = origin2[x]
	temp2[y] = origin2[y]
	temp2[z] = origin2[z]-30
	
	trace_line(-1, temp1, temp2, Origin_Return) 
	
	if (get_distance_f(Origin_Return,temp2) < 1.0)
		return true
	
	return false
}

stock bool:Is_Point_Stuck(Float:Origin[3], Float:hullsize)
{
	new Float:temp[3]
	new Float:iterator = hullsize/3
	
	temp[2] = Origin[2]
	
	for (new Float:i=Origin[0]-hullsize; i < Origin[0]+hullsize; i+=iterator)
	{
		for (new Float:j=Origin[1]-hullsize; j < Origin[1]+hullsize; j+=iterator)
		{
			//72 mod 6 = 0
			for (new Float:k=Origin[2]-CS_PLAYER_HEIGHT; k < Origin[2]+CS_PLAYER_HEIGHT; k+=6) 
			{
				temp[0] = i
				temp[1] = j
				temp[2] = k
				
				if (point_contents(temp) != -1)
					return true
			}
		}
	}
	
	return false
}

stock Effect_Bleed(id,color)
{
	new origin[3]
	get_user_origin(id,origin)
	
	new dx, dy, dz
	
	for(new i = 0; i < 3; i++) 
	{
		dx = random_num(-15,15)
		dy = random_num(-15,15)
		dz = random_num(-20,25)
		
		for(new j = 0; j < 2; j++) 
		{
			message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
			write_byte(TE_BLOODSPRITE)
			write_coord(origin[0]+(dx*j))
			write_coord(origin[1]+(dy*j))
			write_coord(origin[2]+(dz*j))
			write_short(sprite_blood_spray)
			write_short(sprite_blood_drop)
			write_byte(color) // color index
			write_byte(8) // size
			message_end()
		}
	}
}

/* ==================================================================================================== */

public Use_Spell(id)
{
	if (player_global_cooldown[id] + GLOBAL_COOLDOWN >= halflife_time())
		return PLUGIN_CONTINUE
	else
		player_global_cooldown[id] = halflife_time()
		
	if (!is_user_alive(id) || !freeze_ended)
		return PLUGIN_CONTINUE
	
	/*See if USE button is used for anything else..
	1) Close to bomb
	2) Close to hostage
	3) Close to switch
	4) Close to door
	*/
	
	new Float:origin[3]
	pev(id, pev_origin, origin)
	
	//Func door and func door rotating
	new aimid, body
	get_user_aiming ( id, aimid, body ) 
	
	if (aimid > 0)
	{
		new classname[32]
		pev(aimid,pev_classname,classname,31)
		
		if (equal(classname,"func_door_rotating") || equal(classname,"func_door") || equal(classname,"func_button"))
		{
			new Float:doororigin[3]
			pev(aimid, pev_origin, doororigin)
			
			if (get_distance_f(origin, doororigin) < 70 && UTIL_In_FOV(id,aimid))
				return PLUGIN_CONTINUE
		}
		
	}
	
	//Bomb condition
	new bomb
	if ((bomb = find_ent_by_model(-1, "grenade", "models/w_c4.mdl"))) 
	{
		new Float:bombpos[3]
		pev(bomb, pev_origin, bombpos)
			
		//We are near the bomb and have it in FOV.
		if (get_distance_f(origin, bombpos) < 100 && UTIL_In_FOV(id,bomb))
			return PLUGIN_CONTINUE
	}

	
	//Hostage
	new hostage = engfunc(EngFunc_FindEntityByString, -1,"classname", "hostage_entity")
	
	while (hostage)
	{
		new Float:hospos[3]
		pev(hostage, pev_origin, hospos)
		if (get_distance_f(origin, hospos) < 70 && UTIL_In_FOV(id,hostage))
			return PLUGIN_CONTINUE
		
		hostage = engfunc(EngFunc_FindEntityByString, hostage,"classname", "hostage_entity")
	}
	
	check_magic(id)
	
	
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

//Angle to all targets in fov
stock Float:Find_Angle(Core,Target,Float:dist)
{
	new Float:vec2LOS[2]
	new Float:flDot	
	new Float:CoreOrigin[3]
	new Float:TargetOrigin[3]
	new Float:CoreAngles[3]
	
	pev(Core,pev_origin,CoreOrigin)
	pev(Target,pev_origin,TargetOrigin)
	
	if (get_distance_f(CoreOrigin,TargetOrigin) > dist)
		return 0.0
	
	pev(Core,pev_angles, CoreAngles)
	
	for ( new i = 0; i < 2; i++ )
		vec2LOS[i] = TargetOrigin[i] - CoreOrigin[i]
	
	new Float:veclength = Vec2DLength(vec2LOS)
	
	//Normalize V2LOS
	if (veclength <= 0.0)
	{
		vec2LOS[x] = 0.0
		vec2LOS[y] = 0.0
	}
	else
	{
		new Float:flLen = 1.0 / veclength;
		vec2LOS[x] = vec2LOS[x]*flLen
		vec2LOS[y] = vec2LOS[y]*flLen
	}
	
	//Do a makevector to make v_forward right
	engfunc(EngFunc_MakeVectors,CoreAngles)
	
	new Float:v_forward[3]
	new Float:v_forward2D[2]
	get_global_vector(GL_v_forward, v_forward)
	
	v_forward2D[x] = v_forward[x]
	v_forward2D[y] = v_forward[y]
	
	flDot = vec2LOS[x]*v_forward2D[x]+vec2LOS[y]*v_forward2D[y]
	
	if ( flDot > 0.5 )
	{
		return flDot
	}
	
	return 0.0	
}

stock Float:Vec2DLength( Float:Vec[2] )  
{ 
	return floatsqroot(Vec[x]*Vec[x] + Vec[y]*Vec[y] )
}

stock bool:UTIL_In_FOV(id,target)
{
	if (Find_Angle(id,target,9999.9) > 0.0)
		return true
	
	return false
}

/* ==================================================================================================== */

public Greet_Player(id)
{
	id-=TASK_GREET
	new name[32]
	get_user_name(id,name,31)
	client_print(id,print_chat, "Привет %s,ты новичёк? Помощь в say /help", name)
}

/* ==================================================================================================== */



/* ==================================================================================================== */

public changerace(id)
{
	if(round_status==1 && player_class[id]!=0)
	{
		if(loaded_xp[id]==0)
		{
			set_user_health(id,0)
			MYSQLX_Save(id)
			player_class[id]=0
			client_connect(id) 
			D2_ChangeRaceStart(id)
		}
	}
	else if(player_class[id]!=0) 
	{
		if(loaded_xp[id]==0)
		{
			MYSQLX_Save(id)
			player_class[id]=0
			client_connect(id) 
			D2_ChangeRaceStart(id)
		}
	}
}

/* ==================================================================================================== */

//Disable autohelp messages and display our own.
public FW_WriteString(string[])
{
	if (equal(string,""))
		return FMRES_IGNORED
	
	//Disable autohelp
	if (equal(string,"#Hint_press_buy_to_purchase") || equal(string,"#Hint_press_buy_to_purchase "))
	{
		write_string( "" );
		return FMRES_SUPERCEDE
	}
	
	if (equal(string, "#Hint_spotted_a_friend") || equal(string, "#Hint_you_have_the_bomb"))
	{
		write_string( "" );
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
	
}

stock hudmsg(id,Float:display_time,const fmt[], {Float,Sql,Result,_}:...)
{	
	if (player_huddelay[id] >= 0.03*4)
		return PLUGIN_CONTINUE
	
	new buffer[512]
	vformat(buffer, 511, fmt, 4)
	
	set_hudmessage ( 255, 0, 0, -1.0, 0.4 + player_huddelay[id], 0, display_time/2, display_time, 0.1, 0.2, -1 ) 	
	show_hudmessage(id, buffer)
	
	player_huddelay[id]+=0.03
	
	remove_task(id+TASK_HUD)
	set_task(display_time, "hudmsg_clear", id+TASK_HUD, "", 0, "a", 3)
	
	
	return PLUGIN_CONTINUE
	
}

stock hudmsg2(id,Float:display_time,const fmt[], {Float,Sql,Result,_}:...)
{	
	if (player_huddelay[id] >= 0.03*4)
		return PLUGIN_CONTINUE
	
	new buffer[512]
	vformat(buffer, 511, fmt, 4)
	set_hudmessage ( 0, 255, 0, 0.03, 0.69, 0, display_time/2, display_time, 0.1, 0.2, 3 ) 	
	show_hudmessage(id, buffer)
	
	player_huddelay[id]+=0.03
	
	remove_task(id+TASK_HUD)
	set_task(display_time, "hudmsg_clear", id+TASK_HUD, "", 0, "a", 3)
	
	
	return PLUGIN_CONTINUE
	
}

public hudmsg_clear(id)
{
	new pid = id-TASK_HUD
	player_huddelay[pid]=0.0
}

/* ==================================================================================================== */

public item_firetotem(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Вы можете использовать тотем только 1 раз за раунд")
	}
	else
	{
		used_item[id] = true
		Effect_Ignite_Totem(id,7)
	}
}

stock Effect_Ignite_Totem(id,seconds)
{
	new origin[3]
	pev(id,pev_origin,origin)
	
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Ignite_Totem")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_TRIGGER)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_ltime, halflife_time() + seconds + 0.1)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/totem_ignite.mdl")  	
	set_rendering ( ent, kRenderFxGlowShell, 250,150,0, kRenderFxNone, 255 ) 	
	engfunc(EngFunc_DropToFloor,ent)
	
	set_pev(ent,pev_euser3,0)
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
}

public Effect_Ignite_Totem_Think(ent)
{
	//Safe check because effect on death
	if (!freeze_ended)
		remove_entity(ent)
	
	if (!is_valid_ent(ent))
		return PLUGIN_CONTINUE
	
	new id = pev(ent,pev_owner)
	
	//Apply and destroy
	if (pev(ent,pev_euser3) == 1)
	{
		new entlist[513]
		new numfound = find_sphere_class(ent,"player",player_b_firetotem[id]+0.0,entlist,512)
		
		for (new i=0; i < numfound; i++)
		{		
			new pid = entlist[i]
			
			//This totem can hit the caster
			if (pid == id && is_user_alive(id))
			{
				Effect_Ignite(pid,id,4)
				hudmsg(pid,3.0,"Дымовая завеса. Стреляй в кого-нибудь чтобы остановить!")
				continue
			}
			
			if (!is_user_alive(pid) || get_user_team(id) == get_user_team(pid))
				continue
			
			//Dextery makes the fire damage less
			if (player_dextery[pid] > 20)
				Effect_Ignite(pid,id,1)
			else if (player_dextery[pid] > 15)
				Effect_Ignite(pid,id,2)
			else if (player_dextery[pid] > 10)
				Effect_Ignite(pid,id,3)
			else
				Effect_Ignite(pid,id,4)
			
			hudmsg(pid,3.0,"Дымовая завеса. Стреляй в кого-нибудь чтобы остановить!")
		}
		
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	
	
	//Entity should be destroyed because livetime is over
	if (pev(ent,pev_ltime) < halflife_time())
	{
		set_pev(ent,pev_euser3,1)
		
		//Show animation and die
		
		new Float:forigin[3], origin[3]
		pev(ent,pev_origin,forigin)	
		FVecIVec(forigin,origin)
		
		//Find people near and give them health
		message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
		write_byte( TE_BEAMCYLINDER );
		write_coord( origin[0] );
		write_coord( origin[1] );
		write_coord( origin[2] );
		write_coord( origin[0] );
		write_coord( origin[1] + player_b_firetotem[id]);
		write_coord( origin[2] + player_b_firetotem[id]);
		write_short( sprite_white );
		write_byte( 0 ); // startframe
		write_byte( 0 ); // framerate
		write_byte( 10 ); // life
		write_byte( 10 ); // width
		write_byte( 255 ); // noise
		write_byte( 150 ); // r, g, b
		write_byte( 150 ); // r, g, b
		write_byte( 0 ); // r, g, b
		write_byte( 128 ); // brightness
		write_byte( 5 ); // speed
		message_end();
		
		set_pev(ent,pev_nextthink, halflife_time() + 0.2)
		
	}
	else	
	{
		set_pev(ent,pev_nextthink, halflife_time() + 1.5)
	}
	
	return PLUGIN_CONTINUE
}

stock Spawn_Ent(const classname[]) 
{
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, classname))
	set_pev(ent, pev_origin, {0.0, 0.0, 0.0})    
	dllfunc(DLLFunc_Spawn, ent)
	return ent
}

stock Effect_Ignite(id,attacker,damage)
{
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Ignite")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_ltime, halflife_time() + 99 + 0.1)
	set_pev(ent,pev_solid,SOLID_NOT)
	set_pev(ent,pev_euser1,attacker)
	set_pev(ent,pev_euser2,damage)
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)	
	
	AddFlag(id,Flag_Ignite)
}

//euser3 = destroy and apply effect
public Effect_Ignite_Think(ent)
{
	new id = pev(ent,pev_owner)
	attacker = pev(ent,pev_euser1)
	new damage = pev(ent,pev_euser2)
	
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id) || !HasFlag(id,Flag_Ignite))
	{
		RemoveFlag(id,Flag_Ignite)
		Remove_All_Tents(id)
		Display_Icon(id ,0 ,"dmg_heat" ,200,0,0)
		
		remove_entity(ent)		
		return PLUGIN_CONTINUE
	}
	
	
	//Display ignite tent and icon
	Display_Tent(id,sprite_ignite,2)
	Display_Icon(id ,1 ,"dmg_heat" ,200,0,0)
	
	new origin[3]
	get_user_origin(id,origin)
	
	//Make some burning effects
	message_begin( MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte( TE_SMOKE ) // 5
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2])
	write_short( sprite_smoke )
	write_byte( 22 )  // 10
	write_byte( 10 )  // 10
	message_end()
	
	//Decals
	message_begin( MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte( TE_GUNSHOTDECAL ) // decal and ricochet sound
	write_coord( origin[0] ) //pos
	write_coord( origin[1] )
	write_coord( origin[2] )
	write_short (0) // I have no idea what thats supposed to be
	write_byte (random_num(199,201)) //decal
	message_end()
	
	
	//Do the actual damage
	change_health(id,-damage,attacker,"ignite")
	
	set_pev(ent,pev_nextthink, halflife_time() + 1.5)
	
	
	return PLUGIN_CONTINUE
}

stock AddFlag(id,flag)
{
	afflicted[id][flag] = 1	
}

stock RemoveFlag(id,flag)
{
	afflicted[id][flag] = 0
}

stock bool:HasFlag(id,flag)
{
	if (afflicted[id][flag])
		return true
	
	return false
}

stock Display_Tent(id,sprite, seconds)
{
	message_begin(MSG_ALL,SVC_TEMPENTITY)
	write_byte(TE_PLAYERATTACHMENT)
	write_byte(id)
	write_coord(40) //Offset
	write_short(sprite)
	write_short(seconds*10)
	message_end()
}

stock Remove_All_Tents(id)
{
	message_begin(MSG_ALL ,SVC_TEMPENTITY) //message begin
	write_byte(TE_KILLPLAYERATTACHMENTS)
	write_byte(id) // entity index of player
	message_end()
}



stock Find_Best_Angle(id,Float:dist, same_team = false)
{
	new Float:bestangle = 0.0
	new winner = -1
	
	for (new i=0; i < MAX; i++)
	{
		if (!is_user_alive(i) || i == id || (get_user_team(i) == get_user_team(id) && !same_team))
			continue
		
		if (get_user_team(i) != get_user_team(id) && same_team)
			continue
		
		//User has spell immunity, don't target
		
		new Float:c_angle = Find_Angle(id,i,dist)
		
		if (c_angle > bestangle && Can_Trace_Line(id,i))
		{
			winner = i
			bestangle = c_angle
		}
		
	}
	
	return winner
}

//This is an interpolation. We make tree lines with different height as to make sure
stock bool:Can_Trace_Line(id, target)
{	
	for (new i=-35; i < 60; i+=35)
	{		
		new Float:Origin_Id[3]
		new Float:Origin_Target[3]
		new Float:Origin_Return[3]
		
		pev(id,pev_origin,Origin_Id)
		pev(target,pev_origin,Origin_Target)
		
		Origin_Id[z] = Origin_Id[z] + i
		Origin_Target[z] = Origin_Target[z] + i
		
		trace_line(-1, Origin_Id, Origin_Target, Origin_Return) 
		
		if (get_distance_f(Origin_Return,Origin_Target) < 25.0)
			return true
		
	}
	
	return false
}

public item_hook(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Hook можно использовать ввсего 1 раз за раунд")
		return PLUGIN_CONTINUE	
	}
	
	new target = Find_Best_Angle(id,1000.0,false)
	
	if (!is_valid_ent(target))
	{
		hudmsg(id,2.0,"Объект находится вне досягаемости.")
		return PLUGIN_CONTINUE
	}
	
	AddFlag(id,Flag_Hooking)
	
	set_user_gravity(target,0.0)
	set_task(0.1,"hook_prethink",id+TASK_HOOK,"",0,"b")
	hooked[id] = target
	hook_prethink(id+TASK_HOOK)
	emit_sound(id,CHAN_VOICE,"weapons/xbow_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	used_item[id] = true	
	return PLUGIN_HANDLED
	
}

public hook_prethink(id)
{
	id -= TASK_HOOK
	if(!is_user_alive(id) || !is_user_alive(hooked[id])) 
	{
		RemoveFlag(id,Flag_Hooking)
		return PLUGIN_HANDLED
	}
	if (get_user_button(id) & ~IN_USE)
	{
		RemoveFlag(id,Flag_Hooking)
		return PLUGIN_HANDLED	
	}
	if(!HasFlag(id,Flag_Hooking))
	{
		if (is_user_alive(hooked[id]))
			set_user_gravity(id,1.0)
		remove_task(id+TASK_HOOK)
		return PLUGIN_HANDLED
	}
	
	//Get Id's origin
	static origin1[3]
	get_user_origin(id,origin1)
	
	static origin2[3]
	get_user_origin(hooked[id],origin2)
	
	//Create blue beam
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(1)		//TE_BEAMENTPOINT
	write_short(id)		// start entity
	write_coord(origin2[0])
	write_coord(origin2[1])
	write_coord(origin2[2])
	write_short(sprite_line)
	write_byte(1)		// framestart
	write_byte(1)		// framerate
	write_byte(2)		// life in 0.1's
	write_byte(5)		// width
	write_byte(0)		// noise
	write_byte(0)		// red
	write_byte(0)		// green
	write_byte(255)		// blue
	write_byte(200)		// brightness
	write_byte(0)		// speed
	message_end()
	
	//Calculate Velocity
	new Float:velocity[3]
	velocity[0] = (float(origin1[0]) - float(origin2[0])) * 3.0
	velocity[1] = (float(origin1[1]) - float(origin2[1])) * 3.0
	velocity[2] = (float(origin1[2]) - float(origin2[2])) * 3.0
	
	new Float:dy
	dy = velocity[0]*velocity[0] + velocity[1]*velocity[1] + velocity[2]*velocity[2]
	
	new Float:dx
	dx = (4+player_intelligence[id]/2) * 120.0 / floatsqroot(dy)
	
	velocity[0] *= dx
	velocity[1] *= dx
	velocity[2] *= dx
	
	set_pev(hooked[id],pev_velocity,velocity)
	
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public item_gravitybomb(id)
{	
	if (pev(id,pev_flags) & FL_ONGROUND) 
	{
		hudmsg(id,2.0,"Вы должны быть в воздухе!")
		return PLUGIN_CONTINUE
	}
	
	if (halflife_time()-gravitytimer[id] <= 5)
	{
		hudmsg(id,2.0,"Этот item, могет быть использован каждые 5 секунд")
		return PLUGIN_CONTINUE
	}
	
	gravitytimer[id] = floatround(halflife_time())
	
	new origin[3]
	get_user_origin(id,origin)
	
	if (origin[2] == 0)
		earthstomp[id] = 1
	else
		earthstomp[id] = origin[2]
	
	set_user_gravity(id,5.0)
	falling[id] = true
	
		
	return PLUGIN_CONTINUE
	
}

public add_bonus_stomp(id)
{
	set_gravitychange(id)
	
	new origin[3]
	get_user_origin(id,origin)
	
	new dam = earthstomp[id]-origin[2]
	
	earthstomp[id] = 0
	
	//If jump is is high enough, apply some shake effect and deal damage, 300 = down from BOMB A in dust2
	if (dam < 85)
		return PLUGIN_CONTINUE
		
	dam = dam-85
	
	message_begin(MSG_ONE , get_user_msgid("ScreenShake") , {0,0,0} ,id)
	write_short( 1<<14 );
	write_short( 1<<12 );
	write_short( 1<<14 );
	message_end();
		
	new entlist[513]
	new numfound = find_sphere_class(id,"player",230.0+player_strength[id]*2,entlist,512)
	

	for (new i=0; i < numfound; i++)
	{		
		new pid = entlist[i]
			
		if (pid == id || !is_user_alive(pid))
			continue
			
		if (get_user_team(id) == get_user_team(pid))
			continue
		if (player_b_antyarchy[pid] > 0 || c_antyarchy[pid] > 0)
			continue
			
		if (!(pev(pid, pev_flags) & FL_ONGROUND)) continue	
			
		new Float:id_origin[3]
		new Float:pid_origin[3]
		new Float:delta_vec[3]
		
		pev(id,pev_origin,id_origin)
		pev(pid,pev_origin,pid_origin)
		
		
		delta_vec[x] = (pid_origin[x]-id_origin[x])+10
		delta_vec[y] = (pid_origin[y]-id_origin[y])+10
		delta_vec[z] = (pid_origin[z]-id_origin[z])+200
		
		set_pev(pid,pev_velocity,delta_vec)
						
		message_begin(MSG_ONE , get_user_msgid("ScreenShake") , {0,0,0} ,pid)
		write_short( 1<<14 );
		write_short( 1<<12 );
		write_short( 1<<14 );
		message_end();
		
		change_health(pid,-dam,id,"stomp bonus")			
	}
		
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public item_rot(id)
{
	if (used_item[id])
	{
		RemoveFlag(id,Flag_Rot)
		used_item[id] = false
	}
	else
	{
		if (find_ent_by_owner(-1,"Effect_Rot",id) > 0)
			return PLUGIN_CONTINUE
			
		Create_Rot(id)
		used_item[id] = true
	}
	
	return PLUGIN_CONTINUE
}

public Create_Rot(id)
{		
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Rot")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_NOT)
	AddFlag(id,Flag_Rot)
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)	
			
}

public Effect_Rot_Think(ent)
{
	new id = pev(ent,pev_owner)
	if (!is_user_alive(id) || !HasFlag(id,Flag_Rot) || !freeze_ended)
	{
		Display_Icon(id,0,"dmg_bio",255,255,0)
		set_user_maxspeed(id,245.0+player_dextery[id])
		
		set_renderchange(id)
		
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	set_user_maxspeed(id,252.0+player_dextery[id]+15)
	Display_Icon(id,1,"dmg_bio",255,150,0)
	set_renderchange(id)
	
	new entlist[513]
	new numfound = find_sphere_class(id,"player",250.0,entlist,512)
	
	for (new i=0; i < numfound; i++)
	{		
		new pid = entlist[i]
		if(player_b_antyfs[ pid ] > 0 || c_antyfs[ pid ] > 0)
                        continue
			
		if (pid == id || !is_user_alive(pid))
			continue
			
		if (get_user_team(id) == get_user_team(pid))
			continue
		
		//Rot him!
		if (random_num(1,2) == 1) Display_Fade(id,1<<14,1<<14,1<<16,255,155,50,230)
		
		change_health(pid,-45,id,"rot")
		Effect_Bleed(pid,100)
		Create_Slow(pid,3)
		
	}
	
	change_health(id,-10,id,"rot")
		
	set_pev(ent,pev_nextthink, halflife_time() + 0.8)
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

//Daze player
stock Create_Slow(id,seconds)
{		
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Slow")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_ltime, halflife_time() + seconds + 0.1)
	set_pev(ent,pev_solid,SOLID_NOT)
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)	
			
	AddFlag(id,Flag_Dazed)
}

public Effect_Slow_Think(ent)
{
	new id = pev(ent,pev_owner)
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		Display_Icon(id,0,"dmg_heat",255,255,0)
		RemoveFlag(id,Flag_Dazed)
		set_user_maxspeed(id,245.0+player_agility[id])
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	set_user_maxspeed(id,245.0-50)
	Display_Icon(id,1,"dmg_heat",255,255,0)
	set_pev(ent,pev_nextthink, halflife_time() + 1.0)
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

stock AddTimedFlag(id,flag,seconds)
{		
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Timedflag")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_ltime, halflife_time() + seconds + 0.1)
	set_pev(ent,pev_solid,SOLID_NOT)
	set_pev(ent,pev_euser3,flag)			
	AddFlag(id,flag)	
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
}

public Effect_Timedflag_Think(ent)
{
	new id = pev(ent,pev_owner)
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		RemoveFlag(id,pev(ent,pev_euser3))
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	set_pev(ent,pev_nextthink, halflife_time() + 1.0)
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public item_illusion(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Этот item можно использовать один раз за раунд!")
		return PLUGIN_CONTINUE
	}

	AddTimedFlag(id,Flag_Illusion,7)
	message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
	write_byte( 7) 
	write_byte( 0 ) 
	message_end() 
	used_item[id] = true
	use_addtofullpack = true
	return PLUGIN_CONTINUE
	
}

/* ==================================================================================================== */

public item_money_shield(id)
{
	if (used_item[id])
	{
		RemoveFlag(id,Flag_Moneyshield)
		used_item[id] = false
	}
	else
	{
		if (find_ent_by_owner(-1,"Effect_MShield",id) > 0)
			return PLUGIN_CONTINUE
			
		new ent = Spawn_Ent("info_target")
		set_pev(ent,pev_classname,"Effect_MShield")
		set_pev(ent,pev_owner,id)
		set_pev(ent,pev_solid,SOLID_NOT)		
		AddFlag(id,Flag_Moneyshield)	
		set_pev(ent,pev_nextthink, halflife_time() + 0.1)
		used_item[id] = true
	}
	
	return PLUGIN_CONTINUE
}

public Effect_MShield_Think(ent)
{
	new id = pev(ent,pev_owner)
	if (!is_user_alive(id) || cs_get_user_money(id) <= 0 || !HasFlag(id,Flag_Moneyshield) || !freeze_ended)
	{
		RemoveFlag(id,Flag_Moneyshield)
		
		set_renderchange(id)
		
		Display_Icon(id,0,"suithelmet_empty",255,255,255)
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	if (cs_get_user_money(id)-250 < 0)
		cs_set_user_money(id,0)
	else
		cs_set_user_money(id,cs_get_user_money(id)-250)
		
	set_renderchange(id)
	
	Display_Icon(id,1,"suithelmet_empty",255,255,255)
	
	set_pev(ent,pev_nextthink, halflife_time() + 1.0)
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public item_mine(id)
{
	if (player_b_mine[id] >0 && is_user_alive(id) || c_mine[id] >0 && is_user_alive(id))
	{
	new count = 0
	new ents = -1
	ents = find_ent_by_owner(ents,"Mine",id)
	while (ents > 0)
	{
		count++
		ents = find_ent_by_owner(ents,"Mine",id)
	}
	
	if (count > 2)
	{
		hudmsg(id,2.0,"Вы можете поставить до 3ёх мин за раунд")
		return PLUGIN_CONTINUE
	}
	
	
	new origin[3]
	pev(id,pev_origin,origin)
		
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Mine")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_movetype,MOVETYPE_TOSS)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_solid,SOLID_BBOX)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/mine.mdl")  
	engfunc(EngFunc_SetSize,ent,Float:{-16.0,-16.0,0.0},Float:{16.0,16.0,2.0})
	
	drop_to_floor(ent)

	entity_set_float(ent,EV_FL_nextthink,halflife_time() + 0.01) 
	
	set_rendering(ent,kRenderFxNone, 0,0,0, kRenderTransTexture,50)	
	
	use_addtofullpack = true
}
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public item_teamshield(id)
{
	if (used_item[id])
	{
		RemoveFlag(id,Flag_Teamshield)
		used_item[id] = false
		set_renderchange(id)
	}
	else
	{
		new target = Find_Best_Angle(id,1000.0,true)
		
		if (!is_valid_ent(target))
		{
			hudmsg(id,2.0,"Нет цели в пространстве")
			return PLUGIN_CONTINUE
		}
		
		if (pev(target,pev_rendermode) == kRenderTransTexture || player_item_id[target] == 17 || player_class[target] == Ninja || player_class[target] == Infidel)
		{
			hudmsg(id,2.0,"Не возможно использовать невидимый щит от игрока.")
			return PLUGIN_CONTINUE
		}
		
		if (find_ent_by_owner(-1,"Effect_Teamshield",id) > 0)
			return PLUGIN_CONTINUE
			
		if (get_user_health(target)+player_b_teamheal[id] <= race_heal[player_class[target]]+player_strength[target]*2)
			change_health(target,player_b_teamheal[id],0,"")
		
		new ent = Spawn_Ent("info_target")
		set_pev(ent,pev_classname,"Effect_Teamshield")
		set_pev(ent,pev_owner,id)
		set_pev(ent,pev_solid,SOLID_NOT)
		set_pev(ent,pev_nextthink, halflife_time() + 0.1)	
		set_pev(ent,pev_euser2, target)	
				
		AddFlag(id,Flag_Teamshield)
		AddFlag(target,Flag_Teamshield_Target)
		used_item[id] = true
		
		set_renderchange(target)
	}
	
	return PLUGIN_CONTINUE
}

public Effect_Teamshield_Think(ent)
{
	new id = pev(ent,pev_owner)
	new victim = pev(ent,pev_euser2)
	
	new Float: vec1[3]
	new Float: vec2[3]
	new Float: vec3[3]
	
	entity_get_vector(id,EV_VEC_origin,vec1)
	entity_get_vector(victim ,EV_VEC_origin,vec2)
	
	new hit = trace_line ( id, vec1, vec2, vec3 )
	
	if (hit != victim || !is_user_alive(id) || !is_user_alive(victim) || !Can_Trace_Line(id,victim) || !UTIL_In_FOV(id,victim) || !HasFlag(id,Flag_Teamshield) || !freeze_ended)
	{
		RemoveFlag(id,Flag_Teamshield)
		RemoveFlag(victim,Flag_Teamshield_Target)
		remove_entity(ent)
		set_renderchange(victim)
		return PLUGIN_CONTINUE
	}
	else		
		set_pev(ent,pev_nextthink, halflife_time() + 0.3)
				
	new origin1[3]
	new origin2[3]
	
	get_user_origin(id,origin1)
	get_user_origin(victim,origin2)
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY) 
	write_byte (TE_BEAMPOINTS)
	write_coord(origin1[0])
	write_coord(origin1[1])
	write_coord(origin1[2]+8)
	write_coord(origin2[0])
	write_coord(origin2[1])
	write_coord(origin2[2]+8)
	write_short(sprite_laser);
	write_byte(1) // framestart 
	write_byte(1) // framerate 
	write_byte(3) // life 
	write_byte(5) // width 
	write_byte(10) // noise 
	write_byte(0) // r, g, b (red)
	write_byte(255) // r, g, b (green)
	write_byte(0) // r, g, b (blue)
	write_byte(45) // brightness 
	write_byte(5) // speed 
	message_end()    
	
	set_renderchange(victim) 
	
	return PLUGIN_CONTINUE
}

public fw_SetModel(entity, model[])
{
    if(!is_valid_ent(entity)) 
        return FMRES_IGNORED

    if(!equali(model, SE_MODEL)) 
        return FMRES_IGNORED

    new className[33], iOwner;
    entity_get_string(entity, EV_SZ_classname, className, 32)
	
	iOwner = entity_get_edict( entity, EV_ENT_owner );
    
    if(equal(className, "grenade") && (player_class[iOwner] == SabreCat))
    {
        engfunc(EngFunc_SetModel, entity, SABRECAT_MODEL)
        return FMRES_SUPERCEDE
    }
    return FMRES_IGNORED
}

//Diablo grenade

create_blast2(const Float:originF[3])
{
	// Smallest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+385.0) // z axis
	write_short(g_shock) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(100) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Medium ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+470.0) // z axis
	write_short(g_shock) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(50) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Largest ring
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	engfunc(EngFunc_WriteCoord, originF[0]) // x axis
	engfunc(EngFunc_WriteCoord, originF[1]) // y axis
	engfunc(EngFunc_WriteCoord, originF[2]+555.0) // z axis
	write_short(g_shock) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(4) // life
	write_byte(60) // width
	write_byte(0) // noise
	write_byte(200) // red
	write_byte(0) // green
	write_byte(0) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
}

// Player Touch Forward
public fw_TouchPlayer(self, other)
{
	// not touching a player
	if (!is_user_alive(other))
		return;
	
	// Toucher not on fire or touched player already on fire
	if (!task_exists(self+TASK_BURN) || task_exists(other+TASK_BURN))
		return;
	
	// Check if friendly fire is allowed
	if (get_user_team(self) == get_user_team(other))
		return;
	
	// Heat icon
	message_begin(MSG_ONE_UNRELIABLE, g_msgDamage, _, other)
	write_byte(0) // damage save
	write_byte(0) // damage take
	write_long(DMG_BURN) // damage type
	write_coord(0) // x
	write_coord(0) // y
	write_coord(0) // z
	message_end()
	
	// Our task params
	static params[2]
	params[0] = 15 // duration (reduced a bit)
	params[1] = self // attacker
	
	// Set burning task on victim
	set_task(0.1, "burning_flame", other+TASK_BURN, params, sizeof params)
}

public fw_ThinkGrenade(entity)
{
	
	if(pev(entity, pev_flTimeStepSound) != 681856) return HAM_IGNORED;
	
	if (!pev_valid(entity)) return HAM_IGNORED;
	
	static Float:dmgtime
	pev(entity, pev_dmgtime, dmgtime)
	
	if (dmgtime > get_gametime())
		return HAM_IGNORED;
	
	//set_pev(entity, pev_flTimeStepSound, 0)
	
	static Float:originF[3]
	pev(entity, pev_origin, originF)
	
	create_blast2(originF)
	
	napalm_explode(entity)
	
	engfunc(EngFunc_RemoveEntity, entity)
	return HAM_SUPERCEDE;
	
}

// Napalm Grenade Explosion
napalm_explode(ent)
{
	// Get attacker and its team
	static attacker, attacker_team
	attacker = pev(ent, pev_owner)
	attacker_team = pev(ent, pev_team)
	
	// Get origin
	static Float:originF[3]
	pev(ent, pev_origin, originF)
	
	// Napalm explosion sound
	engfunc(EngFunc_EmitSound, ent, CHAN_WEAPON, "weapons/hegrenade-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Collisions
	static victim
	victim = -1
	
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, originF, 240.0)) != 0)
	{
		// Only effect alive players
		if (!is_user_alive(victim))
			continue;
		
		// Check if myself is allowed
		if (victim == attacker)
			continue;
		
		// Check if friendly fire is allowed
		if (attacker_team == get_user_team(victim))
			continue;
		
		// Heat icon
		message_begin(MSG_ONE_UNRELIABLE, g_msgDamage, _, victim)
		write_byte(0) // damage save
		write_byte(0) // damage take
		write_long(DMG_BURN) // damage type
		write_coord(0) // x
		write_coord(0) // y
		write_coord(0) // z
		message_end()
		
		// Our task params
		static params[2]
		new duration, Float:durationsumm
		durationsumm = (player_intelligence[attacker]/2.0) - (player_dextery[victim]/4.0)
		duration = floatround(durationsumm, floatround_ceil)
		params[0] = duration // duration
		params[1] = attacker // attacker
		
		// Set burning task on victim
		set_task(0.1, "burning_flame", victim+TASK_BURN, params, sizeof params)
	}
}

sendTxtMsg(any: ...)
{
	new numstring = numargs() - 2
	new string[100]
	
	message_begin(MSG_ONE, g_MsgText, _, getarg(0))
	write_byte(getarg(1))
	
	for (new i=0; i < numstring; i++)
	{
		// Here we copy the sting that we want to send to a player
		format_args(string, charsmax(string), i + 2)
		
		// Send it!
		write_string(string)
	}
	
	// End the function chain
	message_end()
}

public cmd_HeBuy(id) 
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	
	new CsTeams:team = cs_get_user_team(id)
	
	if (team == CS_TEAM_SPECTATOR || team == CS_TEAM_UNASSIGNED)
		return PLUGIN_CONTINUE
	
	if(!cs_get_user_buyzone(id))
	{
		client_print(id, print_center, "You are not in a buy zone.")
		return PLUGIN_HANDLED
	}
	
	if (cs_get_user_vip(id))
	{
		client_print(id, print_center, "You cannot buy this item because you are VIP!")
		return PLUGIN_HANDLED
	}
	
	new Float:timepassed = get_gametime() - gF_starttime
	new Float:buytimesec = get_cvar_float("mp_buytime") * 60.0
	
	if(timepassed > buytimesec)
	{
		new buffer[10]
		num_to_str(floatround(buytimesec), buffer, charsmax(buffer))
		sendTxtMsg(id, print_center, "#Cstrike_TitlesTXT_Cant_buy", buffer)
		return PLUGIN_HANDLED
	}
	
	new max_ammo
	
	if(player_class[id] == Diablo)
	{
		max_ammo = 2
	}
	else
	{
		max_ammo = 1
	}
	
	new clip,cur_ammo
    get_user_ammo(id,CSW_HEGRENADE,clip,cur_ammo)
	
	// Block the buy if we have less ammo than we want, block the touch.
	if ((cur_ammo + 1) > max_ammo)
	{
		client_print(id , print_center, "#Cstrike_TitlesTXT_Cannot_Carry_Anymore")
		return PLUGIN_HANDLED
	}
	
	new cost = 300
	new money = cs_get_user_money(id)

	if(money - cost < 0) 
	{
		client_print(id , print_center, "#Cstrike_TitlesTXT_Not_Enough_Money")
		return PLUGIN_HANDLED
	}
	
	if ( !user_has_weapon( id , CSW_HEGRENADE ) )
        give_item( id , "weapon_hegrenade" );

    cs_set_user_bpammo(id, CSW_HEGRENADE, cur_ammo + 1);
	cs_set_user_money(id, money - cost, 1)
	
	return PLUGIN_HANDLED
}

// Burning Task
public burning_flame(args[2], taskid)
{
	// Player died/disconnected
	new ID_BURN = taskid - TASK_BURN
	new BURN_DURATION = args[0]
	new BURN_ATTACKER = args[1]
	if (!is_user_alive(ID_BURN))
		return PLUGIN_CONTINUE;
		
	if(BURN_DURATION < 1)
	{
		return PLUGIN_CONTINUE;
	}
	
	// Get player origin and flags
	static Float:originF[3], flags
	pev(ID_BURN, pev_origin, originF)
	flags = pev(ID_BURN, pev_flags)
	
	// In water or burning stopped
	if ((flags & FL_INWATER) || BURN_DURATION < 1)
	{
		// Smoke sprite
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
		write_byte(TE_SMOKE) // TE id
		engfunc(EngFunc_WriteCoord, originF[0]) // x
		engfunc(EngFunc_WriteCoord, originF[1]) // y
		engfunc(EngFunc_WriteCoord, originF[2]-50.0) // z
		write_short(g_smokeSpr) // sprite
		write_byte(random_num(15, 20)) // scale
		write_byte(random_num(10, 20)) // framerate
		message_end()
		
		return PLUGIN_CONTINUE;
	}
	
	// Randomly play burning sounds
	if (random_num(1, 20) == 1)
		engfunc(EngFunc_EmitSound, ID_BURN, CHAN_VOICE, grenade_fire_player[random_num(0, sizeof grenade_fire_player - 1)], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	// Fire slow down
	if (flags & FL_ONGROUND)
	{
		static Float:velocity[3]
		pev(ID_BURN, pev_velocity, velocity)
		xs_vec_mul_scalar(velocity, 0.5, velocity)
		set_pev(ID_BURN, pev_velocity, velocity)
	}
	
	// Get victim's health
	static health
	health = get_user_health(ID_BURN)
	
	// Take damage from the fire
	if ((health - 2) > 0)
	{
		d2_damage( ID_BURN, BURN_ATTACKER, 2, "diablo napalm")
	}
	else
	{
		// Kill victim
		UTIL_Kill(BURN_ATTACKER,ID_BURN,"diablo napalm")
		
		// Smoke sprite
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
		write_byte(TE_SMOKE) // TE id
		engfunc(EngFunc_WriteCoord, originF[0]) // x
		engfunc(EngFunc_WriteCoord, originF[1]) // y
		engfunc(EngFunc_WriteCoord, originF[2]-50.0) // z
		write_short(g_smokeSpr) // sprite
		write_byte(random_num(15, 20)) // scale
		write_byte(random_num(10, 20)) // framerate
		message_end()
		
		return PLUGIN_CONTINUE;
	}
	
	// Flame sprite
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_SPRITE) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]+random_float(-5.0, 5.0)) // x
	engfunc(EngFunc_WriteCoord, originF[1]+random_float(-5.0, 5.0)) // y
	engfunc(EngFunc_WriteCoord, originF[2]+random_float(-10.0, 10.0)) // z
	write_short(sprite_flame) // sprite
	write_byte(random_num(5, 10)) // scale
	write_byte(200) // brightness
	message_end()
		
	// Decrease task cycle count
	BURN_DURATION = BURN_DURATION-1
	args[0] = BURN_DURATION 
	
	// Keep sending flame messages
	set_task(0.2, "burning_flame", taskid, args, sizeof args)
	
	return PLUGIN_CONTINUE
}
/* ==================================================================================================== */	

//Find the owner that has target as target and the specific classname
public find_owner_by_euser(target,classname[])
{
	new ent = -1
	ent = find_ent_by_class(ent,classname)

	while (ent > 0)
	{
		if (pev(ent,pev_euser2) == target)
			return pev(ent,pev_owner)
		ent = find_ent_by_class(ent,classname)
	}
	
	return -1
}

/* ==================================================================================================== */

public item_totemheal(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Тотем лечения можно использовать один раз за раунд!")
		return PLUGIN_CONTINUE
	}
	
	used_item[id] = true
	
	new origin[3]
	pev(id,pev_origin,origin)
		
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Healing_Totem")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_TRIGGER)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_ltime, halflife_time() + 7 + 0.1)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/totem_heal.mdl")  	
	set_rendering ( ent, kRenderFxGlowShell, 255,0,0, kRenderFxNone, 255 ) 	
	engfunc(EngFunc_DropToFloor,ent)
	
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
	
	return PLUGIN_CONTINUE	
}

public Effect_Healing_Totem_Think(ent)
{
	new id = pev(ent,pev_owner)
	new totem_dist = 300
	new amount_healed = player_b_heal[id]
	
	//We have emitted beam. Apply effect (this is delayed)
	if (pev(ent,pev_euser2) == 1)
	{		
		new Float:forigin[3], origin[3]
		pev(ent,pev_origin,forigin)	
		FVecIVec(forigin,origin)
		
		//Find people near and damage them
		new entlist[513]
		new numfound = find_sphere_class(0,"player",totem_dist+0.0,entlist,512,forigin)
		
		for (new i=0; i < numfound; i++)
		{		
			new pid = entlist[i]
			
			if (get_user_team(pid) != get_user_team(id))
				continue
								
			if (is_user_alive(pid)) change_health(pid,amount_healed,0,"")			
		}
		
		set_pev(ent,pev_euser2,0)
		set_pev(ent,pev_nextthink, halflife_time() + 1.5)
		
		return PLUGIN_CONTINUE
	}
	
	//Entity should be destroyed because livetime is over
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	//If this object is almost dead, apply some render to make it fade out
	if (pev(ent,pev_ltime)-2.0 < halflife_time())
		set_rendering ( ent, kRenderFxNone, 255,255,255, kRenderTransTexture, 100 ) 
		
	new Float:forigin[3], origin[3]
	pev(ent,pev_origin,forigin)	
	FVecIVec(forigin,origin)
					
	//Find people near and give them health
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
	write_byte( TE_BEAMCYLINDER );
	write_coord( origin[0] );
	write_coord( origin[1] );
	write_coord( origin[2] );
	write_coord( origin[0] );
	write_coord( origin[1] + totem_dist );
	write_coord( origin[2] + totem_dist );
	write_short( sprite_white );
	write_byte( 0 ); // startframe
	write_byte( 0 ); // framerate
	write_byte( 10 ); // life
	write_byte( 10 ); // width
	write_byte( 255 ); // noise
	write_byte( 255 ); // r, g, b
	write_byte( 100 ); // r, g, b
	write_byte( 100 ); // r, g, b
	write_byte( 128 ); // brightness
	write_byte( 5 ); // speed
	message_end();
		
	set_pev(ent,pev_euser2,1)
	set_pev(ent,pev_nextthink, halflife_time() + 0.5)
	
	    
	return PLUGIN_CONTINUE

}

public freeze_over1()
{
	round_status=1
	agi = BASE_SPEED;
	new players[32], num
	get_players(players,num,"a")	
	
	for(new i=0 ; i<num ; i++)
	{
		set_speedchange(players[i])
	}
}

public freeze_begin1()
{
	round_status=0
}

public funcReleaseVic(id) 
{	
	DemageTake[id]=0
	remove_task(id+GLUTON)
}

public funcReleaseVic2(id) 
{	
	agi = BASE_SPEED;
	if(round_status==1)
	set_speedchange(id)
}

public funcDemageVic(id,attacker) 
{
		id-=GLUTON
		if(get_user_health(id)>10)
		set_task(2.0, "funcDemageVic", id+GLUTON)
		DoDamage(id, attacker1, 5);
}

public set_speedchange(id)
{
	if(DemageTake[id]==1) agi=(BASE_SPEED / 2)
	else agi=BASE_SPEED
	
	if(is_frozen[id] || is_poisoned[id])
	{
		set_user_maxspeed(id, 100.0)
	}
	else if(is_trap_active[id])
	{
		set_user_maxspeed(id, 1.0)
	}
	else if(is_user_connected(id) && freeze_ended)
	{
		new speeds
		if(player_class[id] == Ninja) speeds= 40 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Assassin) speeds= 30 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Baal) speeds= 40 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Barbarian) speeds= -10 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == SabreCat) speeds= 30 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == BloodRaven) speeds= 30 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Infidel) speeds= 40 + floatround(player_dextery[id]*1.3)
		else speeds= floatround(player_dextery[id]*1.3)
		set_user_maxspeed(id, agi + speeds)
	}
}

public set_renderchange(id)
{
	if(is_user_connected(id) && is_user_alive(id))
	{	
		if(!naswietlony[id])
		{
			new render = 255

			if (player_class[id] == Ninja)
			{
				new inv_bonus = 255 - player_b_inv[id]
				render = 13
				
				if(player_b_inv[id]>0)
				{
					while(inv_bonus>0)
					{
						inv_bonus-=20
						render--
					}
				}
				
				if(player_b_usingwind[id]==1)
				{
					render/=2
				}
				
				if(render<0) render=0
				
				if(HasFlag(id,Flag_Moneyshield)||HasFlag(id,Flag_Rot)||HasFlag(id,Flag_Teamshield_Target)) render*=2	
				
				set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, 15)
			}
			else if (player_class[id] == Infidel)
			{
				if(player_infidel[id] == 1)
				{
					new inv_bonus = 255 - player_b_inv[id]
					if(player_intelligence[id] < 50)
					{
						new level_num = 50 - player_intelligence[id];
						new Float:add_invis = float(level_num)*0.4;
						render = floatround(add_invis,floatround_ceil)+10;
					}
					else
					{
						render = 10
					}
					
					if(player_b_inv[id]>0)
					{
						while(inv_bonus>0)
						{
							inv_bonus-=20
							render--
						}
					}
					
					if(player_b_usingwind[id]==1)
					{
						render/=2
					}
					
					if(render<0) render=0
					
					if(HasFlag(id,Flag_Moneyshield)||HasFlag(id,Flag_Rot)||HasFlag(id,Flag_Teamshield_Target)) render*=2
				
					set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, 15)
				}
				else
				{
					set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, 255)
				}
			}
			else if(HasFlag(id,Flag_Moneyshield)||HasFlag(id,Flag_Rot)||HasFlag(id,Flag_Teamshield_Target))
			{
				if (player_b_usingwind[id]==1) set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, 75)
				
				if(HasFlag(id,Flag_Moneyshield)) set_user_rendering(id,kRenderFxGlowShell,0,0,0,kRenderNormal,16)  
				if(HasFlag(id,Flag_Rot)) set_rendering ( id, kRenderFxGlowShell, 255,255,0, kRenderFxNone, 10 )
				if(HasFlag(id,Flag_Teamshield_Target)) set_rendering ( id, kRenderFxGlowShell, 0,200,0, kRenderFxNone, 0 ) 
			}
			else if(invisible_cast[id]==1)
			{
				if(player_b_inv[id]>0) set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, floatround((10.0/255.0)*(255-player_b_inv[id])))
				else set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, 10)
			}
			else if(niewidka[id]==1)
			{
				if(player_b_inv[id]>0) set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, floatround((10.0/255.0)*(255-player_b_inv[id])))
				else set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, 20)
			}
			else
			{
				render = 255 
				if(player_b_inv[id]>0) render = player_b_inv[id]
				
				set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransColor, render)
			}
			
		}	
		else set_user_rendering(id,kRenderFxGlowShell,flashlight_r,flashlight_g,flashlight_b,kRenderNormal,4)
	}
}

public set_gravitychange(id)
{
	if(is_user_alive(id) && is_user_connected(id))
	{
		if(player_class[id] == Ninja)
		{
			if(player_b_gravity[id]>6) set_user_gravity(id, 0.17)
			else if(player_b_gravity[id]>3) set_user_gravity(id, 0.2)
			else set_user_gravity(id, 0.25)
		}
		else
		{
			set_user_gravity(id,1.0*(1.0-player_b_gravity[id]/12.0))
		}
	}
}

public cmd_who(id)
{
	static motd[9000],header[100],name[32],len,i
	len = 0
	new team[32]
	static players[32], numplayers
	get_players(players, numplayers, "h")
	new playerid
	// Table i background
	len += formatex(motd[len],sizeof motd - 1 - len,"<meta http-equiv='content-type' content='text/html; charset=UTF-8' />")
	len += formatex(motd[len],sizeof motd - 1 - len,"<body bgcolor=#000000 text=#FFB000>")
	len += formatex(motd[len],sizeof motd - 1 - len,"<center><table width=700 border=1 cellpadding=4 cellspacing=4>")
	len += formatex(motd[len],sizeof motd - 1 - len,"<tr><td>Ник</td><td>Класс</td><td>Уровень</td><td>Команда</td></tr>")
	//Title
	formatex(header,sizeof header - 1,"Diablo Mod Stats")
	
	for (i=0; i< numplayers; i++)
	{
		playerid = players[i]
		if ( get_user_team(playerid) == 1 ) team = "Terrorist"
		else if ( get_user_team(playerid) == 2 ) team = "CT"
				else team = "Spectator"
		get_user_name( playerid, name, 31 )
		//get_user_name( playerid, name, 31 )
		new Racename[32]
		copy(Racename, charsmax(Racename), Race[player_class[playerid]]);
		if(player_class[playerid]==Fallen && player_lvl[playerid]>49)
		{
			Racename = "Падший шаман"
		}
		len += formatex(motd[len],sizeof motd - 1 - len,"<tr><td>%s</td><td>%s</td><td>%d</td><td>%s</td><td>%s</td></tr>",name,Racename, player_lvl[playerid],team,player_item_name[playerid])
	}
	len += formatex(motd[len],sizeof motd - 1 - len,"</table></center>")
	
	show_motd(id,motd,header)     
}

public det_fade(id)
{
	if (wear_sun[id] == 1 || anty_flesh[id] == 1){
		Display_Icon(id ,ICON_FLASH ,ICON_S ,0,255,0)
		Display_Fade(id,1,1,1<<12,0,0,0,0)
	}
	if (wear_sun[id] == 0 || anty_flesh[id] == 0){
		Display_Icon(id ,ICON_HIDE ,ICON_S ,0,255,0)
	}
}

public changeskin(id,reset){
   if (id<1 || id>32 || !is_user_connected(id)) return PLUGIN_CONTINUE
   if (reset==1){
      cs_reset_user_model(id)
      skinchanged[id]=false
      return PLUGIN_HANDLED
   }else if (reset==2){
      //cs_set_user_model(id,"goomba")
      cs_set_user_model(id,"zombie")
      skinchanged[id]=true
      return PLUGIN_HANDLED
   }else{
      //new newSkin[32]
      new num = random_num(0,3)

      if (get_user_team(id)==1){
         //add(newSkin,31,CTSkins[num])
         cs_set_user_model(id,CTSkins[num])
      }else{
         //client_print(0, print_console, "CT mole, using new skin %s", TSkins[num])
         //add(newSkin,31,TSkins[num])
         cs_set_user_model(id,TSkins[num])
      }

      skinchanged[id]=true
   }

   return PLUGIN_CONTINUE
}
 
 stock refill_ammo(id)
{	
	new wpnid
	if(!is_user_alive(id) || pev(id,pev_iuser1)) return;

	cs_set_user_armor(id,200,CS_ARMOR_VESTHELM);
	
	new wpn[32],clip,ammo
	wpnid = get_user_weapon(id, clip, ammo)
	get_weaponname(wpnid,wpn,31)

	new wEnt;
	
	// set clip ammo
	wpnid = get_weaponid(wpn)
	//wEnt = get_weapon_ent(id,wpnid);
	wEnt = get_weapon_ent(id,wpnid);
	cs_set_weapon_ammo(wEnt,maxClip[wpnid]);

}

stock get_weapon_ent(id,wpnid=0,wpnName[]="")
{
	// who knows what wpnName will be
	static newName[32];

	// need to find the name
	if(wpnid) get_weaponname(wpnid,newName,31);

	// go with what we were told
	else formatex(newName,31,"%s",wpnName);

	// prefix it if we need to
	if(!equal(newName,"weapon_",7))
		format(newName,31,"weapon_%s",newName);

	new ent;
	while((ent = engfunc(EngFunc_FindEntityByString,ent,"classname",newName)) && pev(ent,pev_owner) != id) {}

	return ent;
}

DoDamage(iTargetID, iShooterID, iDamage/*, iDamageCause, bIsWeaponID = false, iHeadShot = 0*/)
{
	if(is_user_connected(iTargetID)&&is_user_connected(iShooterID))
	if ( is_user_alive(iTargetID))
	{	
		new bool:bPlayerDied = false;
		new iHP = get_user_health(iTargetID);
	
		if ( ( iHP - iDamage ) <= 0 )
			bPlayerDied = true;
		
		if (bPlayerDied)
		{
			// engine.inc set_msg_block function
			//set_msg_block(g_iGameMsgDeath, BLOCK_ONCE);
			user_kill(iTargetID, 1);
		}
		else
			change_health(iTargetID,-iDamage,0,"")
		
		new sShooterName[32];
		get_user_name(iShooterID, sShooterName, 31);
		
		if (bPlayerDied)
		{
			if ( iShooterID != iTargetID )
			{
				if ( get_user_team(iShooterID) != get_user_team(iTargetID) )
					set_user_frags(iShooterID, get_user_frags(iShooterID) + 1);
				else
					set_user_frags(iShooterID, get_user_frags(iShooterID) - 1);
				
				//LogKill(iShooterID, iTargetID, sWeaponOrMagicName);
			}
			
			//AddXP(iShooterID, BM_XP_KILL, iTargetID); // bmxphandler.inc
			award_item(iShooterID,0)
			award_kill(iShooterID,iTargetID)
			add_respawn_bonus(iTargetID)
			add_bonus_explode(iTargetID)
			add_barbarian_bonus(iShooterID)
			if (player_class[iShooterID] == Barbarian)
			refill_ammo(iShooterID)
		}
	}
}

public funcDemageVic3(id) 
{
	if(DemageTake1[id]==1)
	{
          DemageTake1[id]=0
          set_task(5.0, "funcReleaseVic3", id)
          user_slap(id, 0, 1); 
          user_slap(id, 0, 1);
          user_slap(id, 0, 1);
	}
}

public funcReleaseVic3(id) 
{	
	DemageTake1[id]=1
}
 
public event_flashlight(id) {
	if(!get_cvar_num("flashlight_custom")) {
		return;
	}

	if(flashlight[id]) {
		flashlight[id] = 0;
	}
	else {
		if(flashbattery[id] > 0) {
			flashlight[id] = 1;
		}
	}

	if(!task_exists(TASK_CHARGE+id)) {
		new parms[1];
		parms[0] = id;
		set_task((flashlight[id]) ? get_cvar_float("flashlight_drain") : get_cvar_float("flashlight_charge"),"charge",TASK_CHARGE+id,parms,1);
	}

	message_begin(MSG_ONE,get_user_msgid("Flashlight"),{0,0,0},id);
	write_byte(flashlight[id]);
	write_byte(flashbattery[id]);
	message_end();

	entity_set_int(id,EV_INT_effects,entity_get_int(id,EV_INT_effects) & ~EF_DIMLIGHT);
}

public charge(parms[]) {
	if(!get_cvar_num("flashlight_custom")) {
		return;
	}

	new id = parms[0];

	if(flashlight[id]) {
		flashbattery[id] -= 1;
	}
	else {
		flashbattery[id] += 1;
	}

	message_begin(MSG_ONE,get_user_msgid("FlashBat"),{0,0,0},id);
	write_byte(flashbattery[id]);
	message_end();

	if(flashbattery[id] <= 0) {
		flashbattery[id] = 0;
		flashlight[id] = 0;

		message_begin(MSG_ONE,get_user_msgid("Flashlight"),{0,0,0},id);
		write_byte(flashlight[id]);
		write_byte(flashbattery[id]);
		message_end();

		// don't return so we can charge it back up to full
	}
	else if(flashbattery[id] >= MAX_FLASH) 
	{
		flashbattery[id] = MAX_FLASH
		return; // return because we don't need to charge anymore
	}

	set_task((flashlight[id]) ? get_cvar_float("flashlight_drain") : get_cvar_float("flashlight_charge"),"charge",TASK_CHARGE+id,parms,1)
}
////////////////////////////////////////////////////////////////////////////////
//                         REVIVAL KIT - NOT ALL                              //
////////////////////////////////////////////////////////////////////////////////
public message_clcorpse()
{	
	return PLUGIN_HANDLED
}

public event_hltv()
{
	fm_remove_entity_name("fake_corpse")
	fm_remove_entity_name("Mine")
	fm_remove_entity_name("dbmod_shild")
	
	static players[32], num
	get_players(players, num, "a")
	for(new i = 0; i < num; i++)
	{
		if(is_user_connected(players[i]))
		{
			set_task(0.0, "funcReleaseVic", i)
			reset_player(players[i])
			msg_bartime(players[i], 0)
			trace_bool[players[i]] = 0
		}
	}
	//set user model block
	// An additional delay is offset at round start
	// since SVC_BAD is more likely to be triggered there
	g_ModelChangeTargetTime = get_gametime() + ROUNDSTART_DELAY
	
	// If a player has a model change task in progress,
	// reschedule the task, since it could potentially
	// be executed during roundstart
	new player
	for (player = 1; player <= g_MaxPlayers; player++)
	{
		if (task_exists(player+TASK_MODELCHANGE))
		{
			remove_task(player+TASK_MODELCHANGE)
			fm_cs_user_model_update(player+TASK_MODELCHANGE)
		}
	}
	//end
}

public fw_SetClientKeyValue(id, const infobuffer[], const key[], const value[])
{
	if (flag_get(g_HasCustomModel, id) && equal(key, "model"))
	{
		static currentmodel[MODELNAME_MAXLENGTH]
		fm_cs_get_user_model(id, currentmodel, charsmax(currentmodel))
		
		if (!equal(currentmodel, g_CustomPlayerModel[id]) && !task_exists(id+TASK_MODELCHANGE))
			fm_cs_set_user_model(id+TASK_MODELCHANGE)
		
#if defined SET_MODELINDEX_OFFSET
		fm_cs_set_user_model_index(id)
#endif
		
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public fm_cs_set_user_model(taskid)
{
	set_user_info(ID_MODELCHANGE, "model", g_CustomPlayerModel[ID_MODELCHANGE])
}

stock fm_cs_set_user_model_index(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	set_pdata_int(id, OFFSET_MODELINDEX, g_CustomModelIndex[id])
}

stock fm_cs_reset_user_model_index(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	switch (fm_cs_get_user_team(id))
	{
		case CS_TEAM_T:
		{
			set_pdata_int(id, OFFSET_MODELINDEX, engfunc(EngFunc_ModelIndex, DEFAULT_MODELINDEX_T))
		}
		case CS_TEAM_CT:
		{
			set_pdata_int(id, OFFSET_MODELINDEX, engfunc(EngFunc_ModelIndex, DEFAULT_MODELINDEX_CT))
		}
	}
}

stock fm_cs_get_user_model(id, model[], len)
{
	get_user_info(id, "model", model, len)
}

stock fm_cs_reset_user_model(id)
{
	// Set some generic model and let CS automatically reset player model to default
	copy(g_CustomPlayerModel[id], charsmax(g_CustomPlayerModel[]), "gordon")
	fm_cs_user_model_update(id+TASK_MODELCHANGE)
#if defined SET_MODELINDEX_OFFSET
	fm_cs_reset_user_model_index(id)
#endif
}

stock fm_cs_user_model_update(taskid)
{
	new Float:current_time
	current_time = get_gametime()
	
	if (current_time - g_ModelChangeTargetTime >= MODELCHANGE_DELAY)
	{
		fm_cs_set_user_model(taskid)
		g_ModelChangeTargetTime = current_time
	}
	else
	{
		set_task((g_ModelChangeTargetTime + MODELCHANGE_DELAY) - current_time, "fm_cs_set_user_model", taskid)
		g_ModelChangeTargetTime = g_ModelChangeTargetTime + MODELCHANGE_DELAY
	}
}

stock CsTeams:fm_cs_get_user_team(id)
{
	if (pev_valid(id) != PDATA_SAFE)
		return CS_TEAM_UNASSIGNED;
	
	return CsTeams:get_pdata_int(id, OFFSET_CSTEAMS);
}

public reset_player(id)
{
	remove_task(TASKID_REVIVE + id)
	remove_task(TASKID_RESPAWN + id)
	remove_task(TASKID_CHECKRE + id)
	remove_task(TASKID_CHECKST + id)
	remove_task(TASKID_ORIGIN + id)
	remove_task(TASKID_SETUSER + id)
	remove_task(GLUTON+id)
	
	
	g_revive_delay[id] 	= 0.0
	g_wasducking[id] 	= false
	g_body_origin[id] 	= Float:{0.0, 0.0, 0.0}
	
}

/*=============================Mosquito===================================*/
stock bool:is_user_on_ground(index)
{
	if (pev(index, pev_flags) & FL_ONGROUND)
		return true;
	
	return false;
}

stock velocity_by_force_angle(id, force, height, Float:angle, Float:new_velocity[3])
{
	new Float:entity_angles[3]
	pev(id, pev_angles, entity_angles)
	
	entity_angles[1] += angle
	
	while (entity_angles[1] < 0.0)
	 entity_angles[1] += 360.0
	
	new Float:v_length
	v_length  = float(force)
	new_velocity[0] = v_length * floatcos(entity_angles[1], degrees)
	new_velocity[1] = v_length * floatsin(entity_angles[1], degrees)
	new_velocity[2] = float(height)
}
/*+++++++++++++++++++++++++++++++++Mosquito End++++++++++++++++++++++++++++++++*/

public fwd_playerpostthink(id)
{
	
	if (is_user_alive(id) && player_class[id] == Mosquito)
	{
	
		static button, oldbutton
		button = pev(id, pev_button)
		oldbutton = pev(id, pev_oldbuttons)
		
		if ((button & IN_USE) && (oldbutton & IN_USE))
		{
			if (!hit_key[id])
			{
				hit_key[id] = true
				
				if (!use_fly[id])
				{
					
					if (is_user_on_ground(id))
					{
						client_print(id, print_center, "Вы должны прыгнуть чтобы взлететь!")
						return PLUGIN_CONTINUE
					}
					
					client_print(id, print_center, "ПОЛЕТ.")
					
					use_fly[id] = true
					fm_set_user_gravity(id, -0.01)
				}
				else
				{
					use_fly[id] = false
					fm_set_user_gravity(id, 0.8)
					client_print(id, print_center, "СТОП ПОЛЕТ.")
				}
			}
		}
		else
		{
			hit_key[id] = false
		}
		
		if (use_fly[id])
		{
			if (is_user_on_ground(id))
			{
				use_fly[id] = false
				fm_set_user_gravity(id, 0.8)
				client_print(id, print_center, "ПРЕЗЕМЛЕНИЕ.")
			}
			
			if ((get_gametime() - fly_check_time[id]) > 0.5)
			{
				new Float:velocity1[3]
				pev(id, pev_velocity, velocity1)
				
				if (fly_step_shift[id])
				{
					fly_step_shift[id] = false
					velocity1[2] += float(fly_step_range)
					//PlaySound(id, sound_wings_up)
				}
				else
				{
					fly_step_shift[id] = true
					velocity1[2] -= float(fly_step_range)
					//PlaySound(id, sound_wings_down)
				}
				
				set_pev(id, pev_velocity, velocity1)
				
				fly_check_time[id] = get_gametime()
			}
			
			if (get_gametime() - player_last_check_time[id] < 0.2)
				return PLUGIN_CONTINUE
			player_last_check_time[id] = get_gametime()
			
			new Float:velocity[3], bool:have_move
			have_move = false
			
			new velo_multi = player_intelligence[id]*4
			if (button & IN_FORWARD)
			{
				have_move = true
				velocity_by_aim(id, fly_forward_speed+velo_multi, velocity)
				set_pev(id, pev_velocity, velocity)
			}
			
			if (button & IN_BACK)
			{
				have_move = true
				velocity_by_aim(id, fly_back_speed+velo_multi, velocity)
				xs_vec_mul_scalar(velocity, -1.0, velocity)
				set_pev(id, pev_velocity, velocity)
			}
			
			if (button & IN_MOVELEFT)
			{
				have_move = true
				velocity_by_force_angle(id, fly_left_right_speed+velo_multi, 0, 90.0, velocity)
				set_pev(id, pev_velocity, velocity)
			}
			
			if (button & IN_MOVERIGHT)
			{
				have_move = true
				velocity_by_force_angle(id, fly_left_right_speed+velo_multi, 0, -90.0, velocity)
				set_pev(id, pev_velocity, velocity)
			}
			
			if (button & IN_JUMP)
			{
				have_move = true
				velocity[0] = velocity[1] = 0.0
				velocity[2] = float(fly_up_down_speed+velo_multi)
				set_pev(id, pev_velocity, velocity)
			}
			
			if (button & IN_DUCK)
			{
				have_move = true
				velocity[0] = velocity[1] = 0.0
				velocity[2] = float(0 - fly_up_down_speed+velo_multi)
				set_pev(id, pev_velocity, velocity)
			}
			
			if (!have_move)
			{
				new speed
				pev(id, pev_velocity, velocity)
				speed = floatround(vector_length(velocity))
				
				if (speed > 0)
				{
					xs_vec_mul_scalar(velocity, 0.5, velocity)
					set_pev(id, pev_velocity, velocity)
				}
			}
		}
	}
	
	if(!is_user_connected(id)) return FMRES_IGNORED
		
	if(g_haskit[id]==0) return FMRES_IGNORED
	
	if(!is_user_alive(id))
	{
		Display_Icon(id ,ICON_HIDE ,"rescue" ,0,160,0)
		return FMRES_IGNORED
	}
	
	new body = find_dead_body(id)
	if(fm_is_valid_ent(body))
	{
		new lucky_bastard = pev(body, pev_owner)
	
		if(!is_user_connected(lucky_bastard))
			return FMRES_IGNORED

		new lb_team = get_user_team(lucky_bastard)
		if(lb_team == 1 || lb_team == 2 )
			Display_Icon(id ,ICON_FLASH ,"rescue" ,0,160,0)
	}
	else
		Display_Icon(id , ICON_SHOW,"rescue" ,0,160,0)
	
	return PLUGIN_CONTINUE
}

public task_check_dead_flag(id)
{
	if(!is_user_connected(id))
		return
	
	if(pev(id, pev_deadflag) == DEAD_DEAD)
		create_fake_corpse(id)
	else
		set_task(0.5, "task_check_dead_flag", id)
}	

public create_fake_corpse(id)
{
	set_pev(id, pev_effects, EF_NODRAW)
	
	static model[32]
	cs_get_user_model(id, model, 31)
		
	static player_model[64]
	format(player_model, 63, "models/player/%s/%s.mdl", model, model)
			
	static Float: player_origin[3]
	pev(id, pev_origin, player_origin)
		
	static Float:mins[3]
	mins[0] = -16.0
	mins[1] = -16.0
	mins[2] = -34.0
	
	static Float:maxs[3]
	maxs[0] = 16.0
	maxs[1] = 16.0
	maxs[2] = 34.0
	
	if(g_wasducking[id])
	{
		mins[2] /= 2
		maxs[2] /= 2
	}
		
	static Float:player_angles[3]
	pev(id, pev_angles, player_angles)
	player_angles[2] = 0.0
				
	new sequence = pev(id, pev_sequence)
	
	new ent = fm_create_entity("info_target")
	if(ent)
	{
		set_pev(ent, pev_classname, "fake_corpse")
		engfunc(EngFunc_SetModel, ent, player_model)
		engfunc(EngFunc_SetOrigin, ent, player_origin)
		engfunc(EngFunc_SetSize, ent, mins, maxs)
		set_pev(ent, pev_solid, SOLID_TRIGGER)
		set_pev(ent, pev_movetype, MOVETYPE_TOSS)
		set_pev(ent, pev_owner, id)
		set_pev(ent, pev_angles, player_angles)
		set_pev(ent, pev_sequence, sequence)
		set_pev(ent, pev_frame, 9999.9)
	}	
}

public fwd_emitsound(id, channel, const sound[], Float:fVol, Float:fAttn, iFlags, iPitch) 
{
	static const szSmokeSound[] = "weapons/sg_explode.wav";
	
	if( equal( sound, szSmokeSound )) 
	{
		// cache origin, angles and model
		new Float:vOrigin[ 3 ], Float:vAngles[ 3 ], szModel[ 64 ], iOwner;
		iOwner = entity_get_edict( id, EV_ENT_owner );
		if(player_class[iOwner] == SabreCat)
		{
			entity_get_vector( id, EV_VEC_origin, vOrigin );
			entity_get_vector( id, EV_VEC_angles, vAngles );
			entity_get_string( id, EV_SZ_model, szModel, charsmax( szModel ) );
			
			// remove entity from world
			entity_set_vector( id, EV_VEC_origin, Float:{ 9999.9, 9999.9, 9999.9 } );
			entity_set_int( id, EV_INT_flags, FL_KILLME );
			
			// Create fake smoke
			
			message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
			write_byte( TE_FIREFIELD );
			engfunc( EngFunc_WriteCoord, vOrigin[ 0 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 1 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 2 ] + 50 );
			write_short( 100 );
			write_short( sprite_sabrecat );
			write_byte( 100 );
			write_byte( TEFIRE_FLAG_ALPHA );
			write_byte( 1000 );
			message_end();
			
			message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
			write_byte( TE_FIREFIELD );
			engfunc( EngFunc_WriteCoord, vOrigin[ 0 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 1 ] );
			engfunc( EngFunc_WriteCoord, vOrigin[ 2 ] + 50 );
			write_short( 150 );
			write_short( sprite_sabrecat );
			write_byte( 10 );
			write_byte( TEFIRE_FLAG_ALPHA | TEFIRE_FLAG_SOMEFLOAT );
			write_byte( 1000 );
			message_end( );
			new iEntity2;
			iEntity2 = create_entity("info_target")
			entity_set_string(iEntity2,EV_SZ_classname,"saber_smoke3")
			engfunc(EngFunc_SetModel, iEntity2, "models/portal/portal.mdl")
			set_pev(iEntity2,pev_solid,SOLID_TRIGGER)
			set_pev(iEntity2,pev_movetype,MOVETYPE_FLY)
			set_pev(iEntity2,pev_skin,1)		
			engfunc(EngFunc_SetOrigin, iEntity2, vOrigin)
			set_rendering(iEntity2, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0 )
			entity_set_edict(iEntity2,EV_ENT_owner, iOwner)
			set_pev(iEntity2,pev_owner,iOwner);
			entity_set_float( iEntity2, EV_FL_nextthink, get_gametime( ) + 21.5 );
			new Float:fMins[3],Float:fMaxs[3];
			pev(iEntity2, pev_mins, fMins)
			pev(iEntity2, pev_maxs, fMaxs)
			fMins[0] = fMins[0] + 100.5;
			fMins[1] = fMins[1] + 100.5;
			fMins[2] = fMins[2] + 100.5;

			fMaxs[0] = fMaxs[0] + 100.5;
			fMaxs[1] = fMaxs[1] + 100.5;
			fMaxs[2] = fMaxs[2] + 100.5;
			
			entity_set_size(iEntity2,Float:{-100.0,-100.0,-100.0},Float:{100.0,100.0,100.0})
			emit_sound(iEntity2, CHAN_VOICE, "diablo_lp/poison.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		}
	}
		
	if(!is_user_alive(id) || !g_haskit[id])
		return FMRES_IGNORED	
	
	if(!equali(sound, "common/wpn_denyselect.wav"))
		return FMRES_IGNORED	
	
	if(task_exists(TASKID_REVIVE + id))
		return FMRES_IGNORED
	
	if(!(fm_get_user_button(id) & IN_USE))
		return FMRES_IGNORED
	
	new body = find_dead_body(id)
	if(!fm_is_valid_ent(body))
		return FMRES_IGNORED

	new lucky_bastard = pev(body, pev_owner)
	new lb_team = get_user_team(lucky_bastard)
	if(lb_team != 1 && lb_team != 2)
		return FMRES_IGNORED

	static name[32]
	get_user_name(lucky_bastard, name, 31)
	client_print(id, print_chat, "Возраждение %s", name)
		
	new revivaltime = get_pcvar_num(cvar_revival_time)
	msg_bartime(id, revivaltime)
	
	new Float:gametime = get_gametime()
	g_revive_delay[id] = gametime + float(revivaltime) - 0.01

	emit_sound(id, CHAN_AUTO, SOUND_START, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	set_task(0.0, "task_revive", TASKID_REVIVE + id)
	
	return FMRES_SUPERCEDE
}

stock fm_draw_line(id, Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2, g_iColor[3])
{
	message_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, SVC_TEMPENTITY, _, id ? id : 0);
	
	write_byte(TE_BEAMPOINTS);
	
	write_coord(floatround(x1));
	write_coord(floatround(y1));
	write_coord(floatround(z1));
	
	write_coord(floatround(x2));
	write_coord(floatround(y2));
	write_coord(floatround(z2));
	
	write_short(sprite_line);
	write_byte(1);
	write_byte(1);
	write_byte(10);
	write_byte(5);
	write_byte(0); 
	
	write_byte(g_iColor[0]);
	write_byte(g_iColor[1]); 
	write_byte(g_iColor[2]);
	
	write_byte(200); 
	write_byte(0);
	
	message_end();
}

//SabreCat smoke
public FwdTouch_FakeSmoke( iEntity, iWorld ) {
	if( !is_valid_ent( iEntity ) )
		return PLUGIN_CONTINUE;
	
	// Bounce sound
	//emit_sound( iEntity, CHAN_VOICE, "weapons/grenade_hit1.wav", 0.25, ATTN_NORM, 0, PITCH_NORM );
	
	new Float:vVelocity[ 3 ];
	entity_get_vector( iEntity, EV_VEC_velocity, vVelocity );
	
	if( vVelocity[ 1 ] <= 0.0 && vVelocity[ 2 ] <= 0.0 ) {
		new Float:vOrigin[ 3 ];
		entity_get_vector( iEntity, EV_VEC_origin, vOrigin );
		
		// Make small smoke near grenade on ground
		message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
		write_byte( TE_FIREFIELD );
		engfunc( EngFunc_WriteCoord, vOrigin[ 0 ] );
		engfunc( EngFunc_WriteCoord, vOrigin[ 1 ] );
		engfunc( EngFunc_WriteCoord, vOrigin[ 2 ] + 10 );
		write_short( 2 );
		write_short( sprite_sabrecat );
		write_byte( 2 );
		write_byte( TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA );
		write_byte( 30 );
		message_end();
	}
	
	return PLUGIN_CONTINUE;
}

public FwdThink_FakeSmoke( iEntity ) {
	if( !is_valid_ent( iEntity ) )
		return PLUGIN_CONTINUE;
	
	remove_entity( iEntity );
	
	return PLUGIN_CONTINUE;
}

public FwdThink_FakeSmoke2( iEntity ) {
	if( !is_valid_ent( iEntity ) )
		return PLUGIN_CONTINUE;
	
	remove_entity( iEntity );
	
	return PLUGIN_CONTINUE;
}

public FwdPlayerTouch_FakeSmoke( iEntity, iPlayer ) {
	
	new iOwner = entity_get_edict( iEntity, EV_ENT_owner );
	
	if(iOwner == iPlayer || get_user_team(iOwner) == get_user_team(iPlayer) || player_class[iPlayer] == SabreCat)
	{
		return FMRES_IGNORED
	}
	if(is_poisoned[iPlayer] == 0)
	{
		new Float:colddelay
		colddelay = player_intelligence[iOwner] * 0.4
		if(colddelay < 4.0) { colddelay = 4.0; }
		glow_player(iPlayer, colddelay, 0, 255, 0)
		set_user_maxspeed(iPlayer, 100.0)
		set_task(colddelay, "unpoison", iPlayer, "", 0, "a", 1)
		is_poisoned[iPlayer] = 1
		Display_Icon(iPlayer ,2 ,"dmg_gas" ,0,255,0)
		new dmg = player_intelligence[iOwner] - player_dextery[iPlayer]
		if(dmg < 10) { dmg = 10; }
		d2_damage( iPlayer, iOwner, dmg, "poison gas")
		is_touched[iPlayer]=get_gametime()
	}
	if(is_touched[iPlayer] + 1.0 < get_gametime())
	{
		new dmg, Float:dmgsumm
		dmgsumm = (player_intelligence[iOwner]/4.0)+5.0 - (player_dextery[iPlayer]/10.0)
		dmg = floatround(dmgsumm, floatround_ceil)
		
		if(dmg < 5) { dmg = 5; }
		
		d2_damage( iPlayer, iOwner, dmg, "poison gas")
		Effect_Bleed(iPlayer,248)
		is_touched[iPlayer]=get_gametime()
	}
	
	return PLUGIN_CONTINUE;
}

public task_revive(taskid)
{
	new id = taskid - TASKID_REVIVE
	
	if(!is_user_alive(id))
	{
		failed_revive(id)
		return FMRES_IGNORED
	}
	
	if(!(fm_get_user_button(id) & IN_USE))
	{
		failed_revive(id)
		return FMRES_IGNORED
	}
	
	new body = find_dead_body(id)
	if(!fm_is_valid_ent(body))
	{
		failed_revive(id)
		return FMRES_IGNORED
	}
	
	new lucky_bastard = pev(body, pev_owner)
	if(!is_user_connected(lucky_bastard))
	{
		failed_revive(id)
		return FMRES_IGNORED
	}
	
	new lb_team = get_user_team(lucky_bastard)
	if(lb_team != 1 && lb_team != 2)
	{
		failed_revive(id)
		return FMRES_IGNORED
	}
	
	static Float:velocity[3]
	pev(id, pev_velocity, velocity)
	velocity[0] = 0.0
	velocity[1] = 0.0
	set_pev(id, pev_velocity, velocity)
	
	new Float:gametime = get_gametime()
	if(g_revive_delay[id] < gametime)
	{
		if(findemptyloc(body, 10.0))
		{
			fm_remove_entity(body)
			emit_sound(id, CHAN_AUTO, SOUND_FINISHED, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			new args[2]
			args[0]=lucky_bastard
			
			if(get_user_team(id)!=get_user_team(lucky_bastard))
			{
				change_health(id,30,0,"")
				args[1]=1
				Give_Xp(id,get_cvar_num("diablo_xpbonus"))
			}
			else
			{
				args[1]=0
				Give_Xp(id,get_cvar_num("diablo_xpbonus"))
				set_task(0.1, "task_respawn", TASKID_RESPAWN + lucky_bastard,args,2)
			}
			
		}
		else
			 failed_revive(id)
	}
	else
		set_task(0.1, "task_revive", TASKID_REVIVE + id)
	
	return FMRES_IGNORED
}

public failed_revive(id)
{
	msg_bartime(id, 0)
	emit_sound(id, CHAN_AUTO, SOUND_FAILED, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public task_origin(args[])
{
	new id = args[0]
	engfunc(EngFunc_SetOrigin, id, g_body_origin[id])
	
	static  Float:origin[3]
	pev(id, pev_origin, origin)
	set_pev(id, pev_zorigin, origin[2])
		
	set_task(0.1, "task_stuck_check", TASKID_CHECKST + id,args,2)
	
}

stock find_dead_body(id)
{
	static Float:origin[3]
	pev(id, pev_origin, origin)
	
	new ent
	static classname[32]	
	while((ent = fm_find_ent_in_sphere(ent, origin, get_pcvar_float(cvar_revival_dis))) != 0) 
	{
		pev(ent, pev_classname, classname, 31)
		if(equali(classname, "fake_corpse") && fm_is_ent_visible(id, ent))
			return ent
	}
	return 0
}

stock msg_bartime(id, seconds) 
{
	if(is_user_bot(id)||!is_user_alive(id)||!is_user_connected(id))
		return
		
	if((fm_get_user_button(id) & IN_USE)) change_health(id,-10,id,"")
	
	message_begin(MSG_ONE, g_msg_bartime, _, id)
	write_byte(seconds)
	write_byte(0)
	message_end()
}

 public task_respawn(args[]) 
 {
	new id = args[0]
	
	if (!is_user_connected(id) || is_user_alive(id) || cs_get_user_team(id) == CS_TEAM_SPECTATOR) return
		
	set_pev(id, pev_deadflag, DEAD_RESPAWNABLE) 
	dllfunc(DLLFunc_Think, id) 
	dllfunc(DLLFunc_Spawn, id) 
	set_pev(id, pev_iuser1, 0)
	
	set_task(0.1, "task_check_respawn", TASKID_CHECKRE + id,args,2)

}

public task_check_respawn(args[])
{
	new id = args[0]
	
	if(pev(id, pev_iuser1))
		set_task(0.1, "task_respawn", TASKID_RESPAWN + id,args,2)
	else
		set_task(0.1, "task_origin", TASKID_ORIGIN + id,args,2)

}
 
public task_stuck_check(args[])
{
	new id = args[0]

	static Float:origin[3]
	pev(id, pev_origin, origin)
	
	if(origin[2] == pev(id, pev_zorigin))
		set_task(0.1, "task_respawn", TASKID_RESPAWN + id,args,2)
	else
		set_task(0.1, "task_setplayer", TASKID_SETUSER + id,args,2)
}

public task_setplayer(args[])
{
	new id = args[0]
	
	fm_give_item(id, "weapon_knife")
	
	if(args[1]==1)
	{
		if(!g_bWeaponsDisabled)
    {
    fm_give_item(id, "weapon_mp5navy")
    }
		else
		{
    hudmsg(id,5.0,"На этой карте оружие не выдаётся!")
    }
		change_health(id,9999,0,"")		
		set_user_godmode(id, 1)
		
		new newarg[1]
		newarg[0]=id
		
		set_task(3.0,"god_off",id+95123,newarg,1)
	}
	else
	{
		fm_set_user_health(id, get_pcvar_num(cvar_revival_health)+player_intelligence[args[1]])
				
		Display_Fade(id,seconds(2),seconds(2),0,0,0,0,255)
	}
	
	if(player_item_id[id]==17) fm_set_user_health(id,5)
	if(player_item_id[id]==88) fm_set_user_health(id,45)
	if(player_item_id[id]==89) fm_set_user_health(id,10)
}

public god_off(args[])
{
	set_user_godmode(args[0], 0)
}

stock bool:findemptyloc(ent, Float:radius)
{
	if(!fm_is_valid_ent(ent))
		return false

	static Float:origin[3]
	pev(ent, pev_origin, origin)
	origin[2] += 2.0
	
	new owner = pev(ent, pev_owner)
	new num = 0, bool:found = false
	
	while(num <= 100)
	{
		if(is_hull_vacant(origin))
		{
			g_body_origin[owner][0] = origin[0]
			g_body_origin[owner][1] = origin[1]
			g_body_origin[owner][2] = origin[2]
			
			found = true
			break
		}
		else
		{
			origin[0] += random_float(-radius, radius)
			origin[1] += random_float(-radius, radius)
			origin[2] += random_float(-radius, radius)
			
			num++
		}
	}
	return found
}

stock bool:is_hull_vacant(const Float:origin[3])
{
	new tr = 0
	engfunc(EngFunc_TraceHull, origin, origin, 0, HULL_HUMAN, 0, tr)
	if(!get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid) && get_tr2(tr, TR_InOpen))
		return true
	
	return false
}
 

public count_jumps(id)
{
	if( is_user_connected(id))
	{
		if( player_class[id]== Paladin ) JumpsMax[id]=5+floatround(player_intelligence[id]/10.0)
		else JumpsMax[id]=0
	}
}

////////////////////////////////////////////////////////////////////////////////
//                                  Noze                                      //
////////////////////////////////////////////////////////////////////////////////
public give_knife(id)
{
	new knifes = 0
	if(player_class[id] == Ninja) knifes = 10 + floatround ( player_intelligence[id]/10.0 , floatround_floor )
	else if(player_class[id] == Assassin) knifes = 1 + floatround ( player_intelligence[id]/20.0 , floatround_floor )
	
	max_knife[id] = knifes
	player_knife[id] = knifes
}

public command_knife(id) 
{

	if(!is_user_alive(id)) return PLUGIN_HANDLED


	if(!player_knife[id])
	{
		client_print(id,print_center,"У вас нет метательных ножей")
		return PLUGIN_HANDLED
	}

	if(tossdelay[id] > get_gametime() - 0.9) return PLUGIN_HANDLED
	else tossdelay[id] = get_gametime()

	player_knife[id]--

	if (player_knife[id] == 1) {
		client_print(id,print_center,"Остался только 1 нож!")
	}

	new Float: Origin[3], Float: Velocity[3], Float: vAngle[3], Ent

	entity_get_vector(id, EV_VEC_origin , Origin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle)

	Ent = create_entity("info_target")

	if (!Ent) return PLUGIN_HANDLED

	entity_set_string(Ent, EV_SZ_classname, "throwing_knife")
	entity_set_model(Ent, "models/diablomod/w_throwingknife.mdl")

	new Float:MinBox[3] = {-1.0, -7.0, -1.0}
	new Float:MaxBox[3] = {1.0, 7.0, 1.0}
	entity_set_vector(Ent, EV_VEC_mins, MinBox)
	entity_set_vector(Ent, EV_VEC_maxs, MaxBox)

	vAngle[0] -= 90

	entity_set_origin(Ent, Origin)
	entity_set_vector(Ent, EV_VEC_angles, vAngle)

	entity_set_int(Ent, EV_INT_effects, 2)
	entity_set_int(Ent, EV_INT_solid, 1)
	entity_set_int(Ent, EV_INT_movetype, 6)
	entity_set_edict(Ent, EV_ENT_owner, id)

	VelocityByAim(id, get_cvar_num("diablo_knife_speed") , Velocity)
	entity_set_vector(Ent, EV_VEC_velocity ,Velocity)
	
	return PLUGIN_HANDLED
}

public command_mosquito(id) 
{

	if(!is_user_alive(id)) return PLUGIN_HANDLED


	if(!mosquito_sting[id])
	{
		client_print(id,print_center,"У вас нет ядовитых жал")
		return PLUGIN_HANDLED
	}

	if(tossdelay[id] > get_gametime() - 0.9) return PLUGIN_HANDLED
	else tossdelay[id] = get_gametime()

	mosquito_sting[id]--

	if (mosquito_sting[id] == 1) {
		client_print(id,print_center,"Осталось 1 жало!")
	}

	new Float: Origin[3], Float: Velocity[3], Float: vAngle[3], Ent

	entity_get_vector(id, EV_VEC_origin , Origin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle)

	Ent = create_entity("info_target")

	if (!Ent) return PLUGIN_HANDLED

	entity_set_string(Ent, EV_SZ_classname, "mosquito_sting")
	entity_set_model(Ent, "models/diablomod/cold.mdl")

	new Float:MinBox[3] = {-1.0, -7.0, -1.0}
	new Float:MaxBox[3] = {1.0, 7.0, 1.0}
	entity_set_vector(Ent, EV_VEC_mins, MinBox)
	entity_set_vector(Ent, EV_VEC_maxs, MaxBox)

	vAngle[1] -= 180

	entity_set_origin(Ent, Origin)
	entity_set_vector(Ent, EV_VEC_angles, vAngle)

	entity_set_int(Ent, EV_INT_effects, 2)
	entity_set_int(Ent, EV_INT_solid, 1)
	entity_set_int(Ent, EV_INT_movetype, 6)
	entity_set_edict(Ent, EV_ENT_owner, id)

	VelocityByAim(id, get_cvar_num("diablo_mosquito_sting_speed") , Velocity)
	entity_set_vector(Ent, EV_VEC_velocity ,Velocity)
	
	return PLUGIN_HANDLED
}

public touchKnife(knife, id)
{	
	new kid = entity_get_edict(knife, EV_ENT_owner)
	
	if(is_user_alive(id)) 
	{
		new movetype = entity_get_int(knife, EV_INT_movetype)
		
		if(movetype == 0) 
		{
			if( player_knife[id] < max_knife[id] )
			{
				player_knife[id] += 1
				client_print(id,print_center,"Текущее количество ножей: %i",player_knife[id])
			}
			emit_sound(knife, CHAN_ITEM, "weapons/knife_deploy1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			remove_entity(knife)
		}
		else if (movetype != 0) 
		{
			if(kid == id) return

			remove_entity(knife)

			if(get_cvar_num("mp_friendlyfire") == 0 && get_user_team(id) == get_user_team(kid)) return

			entity_set_float(id, EV_FL_dmg_take, get_cvar_num("diablo_knife") * 1.0)

			d2_damage( id, kid, get_cvar_num("diablo_knife"), "ninja knife")
			message_begin(MSG_ONE,get_user_msgid("ScreenShake"),{0,0,0},id)
			write_short(7<<14)
			write_short(1<<13)
			write_short(1<<14)
			message_end()		

			if(get_user_team(id) == get_user_team(kid)) {
				new name[33]
				get_user_name(kid,name,32)
				client_print(0,print_chat,"%s attacked a teammate",name)
			}

			emit_sound(id, CHAN_ITEM, "weapons/knife_hit4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)

		}
	}
}

public touchmosquito_sting(knife, id)
{	
	new kid = entity_get_edict(knife, EV_ENT_owner)
	
	if(is_user_alive(id)) 
	{
		new movetype = entity_get_int(knife, EV_INT_movetype)
		
		if(movetype == 0) 
		{
			if( player_knife[id] < max_knife[id] )
			{
				player_knife[id] += 1
				client_print(id,print_center,"Текущее количество жал: %i",player_knife[id])
			}
			remove_entity(knife)
		}
		else if (movetype != 0) 
		{
			if(kid == id) return

			remove_entity(knife)

			if(get_cvar_num("mp_friendlyfire") == 0 && get_user_team(id) == get_user_team(kid)) return
			
			if(is_poisoned[id] == 0)
			{
				new Float:colddelay
				colddelay = player_intelligence[kid] * 0.4
				if(colddelay < 4.0) { colddelay = 4.0; }
				glow_player(id, colddelay, 0, 255, 0)
				set_user_maxspeed(id, 100.0)
				set_task(colddelay, "unpoison", id, "", 0, "a", 1)
				is_poisoned[id] = 1
				Display_Icon(id ,2 ,"dmg_gas" ,0,255,0)
			}
			new dmg, Float:dmgsumm
			dmgsumm = player_intelligence[kid] - player_dextery[id]/2.0
			dmg = floatround(dmgsumm, floatround_ceil)
			if(dmg < 10) { dmg = 10; }
			d2_damage( id, kid, dmg, "mosquito sting")
			Effect_Bleed(id,248)			

			if(get_user_team(id) == get_user_team(kid)) {
				new name[33]
				get_user_name(kid,name,32)
				client_print(0,print_chat,"%s attacked a teammate",name)
			}

			emit_sound(id, CHAN_ITEM, "weapons/knife_hit4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)

		}
	}
}

public touchSpiderTrap(trap, id)
{
	new owner = entity_get_edict(trap, EV_ENT_owner)
	
	if(owner == id)
	{
		if(spider_regen_time[id] + 1.0 < get_gametime())
		{
			spider_regen_time[id]=get_gametime()
			new amount_healed = floatround(player_intelligence[id]/2)
			if(amount_healed < 1) { amount_healed = 1; }
			change_health(id,amount_healed,0,"")
		}
		
		return
	}
		
	if((get_user_team(id) == get_user_team(owner)) || (player_class[id] == GiantSpider)) return
	
	if(is_user_alive(id)) 
	{
		if(is_trap_active[id] == 0)
		{
			is_trap_active[id] = 1
			glow_player(id, 3.0, 255, 255, 255)
			set_user_maxspeed(id, 1.0)
			set_task(3.0, "untrap", id, "", 0, "a", 1)
			owner_radar_trap[id] = owner
			client_print(owner,print_center,"ВРАГ ПОПАЛСЯ В ЛОВУШКУ ^r^nи отмечен на радаре")
			for(new i = 0; i < sizeof primaryWeapons; i++)
			{
				engclient_cmd(id, "drop", primaryWeapons[i])
			}
		}
		remove_entity(trap)
		spider_traps[owner]--
	}
}

public touchWorld(knife, world)
{
	entity_set_int(knife, EV_INT_movetype, 0)
	emit_sound(knife, CHAN_ITEM, "weapons/knife_hitwall1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public touchbreakable(ent1, ent2)
{
	new name[32],ent ,breakable
	entity_get_string(ent1,EV_SZ_classname,name,31)
	if(equali(name,"func_breakable"))
	{
		breakable=ent1
		ent=ent2
	}
	else
	{
		breakable=ent2
		ent=ent1
	}

	if(entity_get_int(breakable, EV_INT_impulse) == 0)
	{
		new Float: b_hp = entity_get_float(breakable,EV_FL_health)
		if(b_hp>80) entity_set_float(breakable,EV_FL_health,b_hp-50.0)
		else dllfunc(DLLFunc_Use,breakable,ent)
		remove_entity(ent)
	}
	else {
		entity_get_string(ent,EV_SZ_classname,name,31)
		if(equali(name,"throwing_knife"))
		{
			entity_set_int(ent, EV_INT_movetype, 0)
			emit_sound(ent, CHAN_ITEM, "weapons/knife_hitwall1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
		else remove_entity(ent)
	}
}
	
public kill_all_entity(classname[]) {
	new iEnt = find_ent_by_class(-1, classname)
	while(iEnt > 0) {
		remove_entity(iEnt)
		iEnt = find_ent_by_class(iEnt, classname)		
	}
}

public kill_all_traps(id) 
{
	new iEnt = find_ent_by_owner(-1,"spidertrap",id,0);
	
	while(iEnt > 0) {
		remove_entity(iEnt)
		iEnt = find_ent_by_owner(-1,"spidertrap",id,0);		
	}
	spider_traps[id]=0
}

public removeBaalcopy(taskid)
{
	new id = taskid - TASK_REMOVE_BAAL
	new iEnt = find_ent_by_owner(-1,"baalcopy",id,0);
	
	while(iEnt > 0) {
		remove_entity(iEnt)
		iEnt = find_ent_by_owner(-1,"baalcopy",id,0);		
	}
	
	iEnt = find_ent_by_owner(-1,"baalcopyweap",id,0);
	
	while(iEnt > 0) {
		remove_entity(iEnt)
		iEnt = find_ent_by_owner(-1,"baalcopyweap",id,0);		
	}
	baal_copyed[id]=0
}
////////////////////////////////////////////////////////////////////////////////
//                             koniec z nozami                                //
////////////////////////////////////////////////////////////////////////////////
public mod_info(id)
{
	client_print(id,print_console,"Добро пожаловать в Diablo Mod от HiTmAnY")
	client_print(id,print_console,"     Читай инфо о моде на сайте")
	client_print(id,print_console,"        http://lpstrike.ru")
	client_print(id,print_console,"        Текущая версия %s",mod_version)
	return PLUGIN_HANDLED
}
////////////////////////////////////////////////////////////////////////////////
//                             Amazon part code                               //
////////////////////////////////////////////////////////////////////////////////
public command_arrow(id) 
{

	if(!is_user_alive(id)) return PLUGIN_HANDLED


	new Float: Origin[3], Float: Velocity[3], Float: vAngle[3], Ent

	entity_get_vector(id, EV_VEC_origin , Origin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle)

	Ent = create_entity("info_target")

	if (!Ent) return PLUGIN_HANDLED

	entity_set_string(Ent, EV_SZ_classname, "xbow_arrow")
	entity_set_model(Ent, cbow_bolt)

	new Float:MinBox[3] = {-2.8, -2.8, -0.8}
	new Float:MaxBox[3] = {2.8, 2.8, 2.0}
	entity_set_vector(Ent, EV_VEC_mins, MinBox)
	entity_set_vector(Ent, EV_VEC_maxs, MaxBox)

	vAngle[0]*= -1
	Origin[2]+=10
	
	entity_set_origin(Ent, Origin)
	entity_set_vector(Ent, EV_VEC_angles, vAngle)

	entity_set_int(Ent, EV_INT_effects, 2)
	entity_set_int(Ent, EV_INT_solid, 1)
	entity_set_int(Ent, EV_INT_movetype, 5)
	entity_set_edict(Ent, EV_ENT_owner, id)
	new Float:dmg = get_cvar_float("diablo_arrow") + player_intelligence[id] * get_cvar_float("diablo_arrow_multi")
	entity_set_float(Ent, EV_FL_dmg,dmg)

	VelocityByAim(id, get_cvar_num("diablo_arrow_speed") , Velocity)
	set_rendering (Ent,kRenderFxGlowShell, 255,0,0, kRenderNormal,56)
	entity_set_vector(Ent, EV_VEC_velocity ,Velocity)
	emit_sound(id,CHAN_STATIC,"diablo_lp/bow2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	return PLUGIN_HANDLED
}

public command_bow(id) 
{
	if(!is_user_alive(id)) return PLUGIN_HANDLED
 
	if(bow[id] == 1)
	{
		if(player_class[id]==BloodRaven)
		{
			set_pev(id, pev_viewmodel2, bloodbow_VIEW)
			set_pev(id, pev_weaponmodel2, bloodbow_PLAYER)
		}
		else
		{
			entity_set_string(id,EV_SZ_viewmodel,cbow_VIEW)
			entity_set_string(id,EV_SZ_weaponmodel,cvow_PLAYER)
		}
		do_casting_bow(id)
	}
	else if(player_sword[id] == 1)
	{
		entity_set_string(id, EV_SZ_viewmodel, SWORD_VIEW)  
		entity_set_string(id, EV_SZ_weaponmodel, SWORD_PLAYER)  
		bow[id]=0
		
		message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
		write_byte( 0 ) 
		write_byte( 0 ) 
		message_end()
	}
	else if(player_class[id] == Zakarum)
	{
		entity_set_string(id, EV_SZ_viewmodel, scythe_view)  
		entity_set_string(id, EV_SZ_weaponmodel, KNIFE_PLAYER)
		
		message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
		write_byte( 0 ) 
		write_byte( 0 ) 
		message_end()
	}
	else
	{
		entity_set_string(id,EV_SZ_viewmodel,KNIFE_VIEW)
		entity_set_string(id,EV_SZ_weaponmodel,KNIFE_PLAYER)
		bow[id]=0
		
		message_begin( MSG_ONE, gmsgBartimer, {0,0,0}, id ) 
		write_byte( 0 ) 
		write_byte( 0 ) 
		message_end()
	}
	
	return PLUGIN_CONTINUE
}

public toucharrow(arrow, id)
{	
	new kid = entity_get_edict(arrow, EV_ENT_owner)
	new lid = entity_get_edict(arrow, EV_ENT_enemy)
	
	if(is_user_alive(id)) 
	{
		if(kid == id || lid == id) return
		
		entity_set_edict(arrow, EV_ENT_enemy,id)
	
		new Float:dmg = entity_get_float(arrow,EV_FL_dmg)
		entity_set_float(arrow,EV_FL_dmg,(dmg*3.0)/5.0)
		
		if(get_cvar_num("mp_friendlyfire") == 0 && get_user_team(id) == get_user_team(kid)) return
		
		Effect_Bleed(id,248)

		bowdelay[kid] -=  0.5 - floatround(player_intelligence[kid]/5.0)
	
		change_health(id,floatround(-dmg),kid,"arrow")
		
		if(fire_bows[kid])
		{
			fire_bows[kid]--
			new Float:origin[3]
			pev(arrow,pev_origin,origin)
			Explode_Origin(kid,origin,player_intelligence[kid],125,1)
		}
				
		message_begin(MSG_ONE,get_user_msgid("ScreenShake"),{0,0,0},id); 
		write_short(7<<14); 
		write_short(1<<13); 
		write_short(1<<14); 
		message_end();

		if(get_user_team(id) == get_user_team(kid)) 
		{
			new name[33]
			get_user_name(kid,name,32)
			client_print(0,print_chat,"%s attacked a teammate",name)
		}

		emit_sound(id, CHAN_ITEM, "weapons/knife_hit4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		if(dmg<30) remove_entity(arrow)
	}
}

public touchWorld2(arrow, world)
{
	new szClassName[32]
	entity_get_string(arrow, EV_SZ_classname, szClassName, 31)
	new owner = pev(arrow,pev_owner)
	if(equal(szClassName, "frozencold"))
	{
		remove_task(arrow)
		emit_sound(owner, CHAN_STATIC, "diablo_lp/frozne_blast.wav", VOL_NULL, ATTN_NONE, SND_STOP, PITCH_NONE)
	}
	else if(equal(szClassName, "xbow_arrow") && fire_bows[owner])
	{
		fire_bows[owner]--
		new Float:origin[3]
		pev(arrow,pev_origin,origin)
		Explode_Origin(owner,origin,player_intelligence[owner],125,1)
	}
	remove_entity(arrow)
}

public removeEntity(ent)
{
	new szClassName[32]
	entity_get_string(ent, EV_SZ_classname, szClassName, 31)
	new owner = pev(ent,pev_owner)
	if(equal(szClassName, "frozencold"))
	{
		emit_sound(owner, CHAN_STATIC, "diablo_lp/frozne_blast.wav", VOL_NULL, ATTN_NONE, SND_STOP, PITCH_NONE)
	}
	remove_entity(ent)
}

public amazon_Line(id,vid,end[3])
{
	if(is_user_alive(id) && is_user_alive(vid) && trace_bool[id])
	{
		new start[3]
		get_user_origin(vid,start)
		
		message_begin(MSG_ONE,SVC_TEMPENTITY,{0,0,0},id)
		write_byte(0)
		write_coord(start[0])	// starting pos
		write_coord(start[1])
		write_coord(start[2])
		write_coord(end[0])	// ending pos
		write_coord(end[1])
		write_coord(end[2])
		write_short(sprite_line)	// sprite index
		write_byte(1)		// starting frame
		write_byte(5)		// frame rate
		write_byte(100)		// life
		write_byte(1)		// line width
		write_byte(0)		// noise
		write_byte(200)	// RED
		write_byte(100)	// GREEN
		write_byte(100)	// BLUE					
		write_byte(75)		// brightness
		write_byte(5)		// scroll speed
		message_end()
		
		new parms[5];
		
		for(new i=0;i<3;i++)
		{
			parms[i] = start[i] 
		}
		parms[3]=id
		parms[4]=vid
		
		set_task(0.20,"charge_amazon",id+TARACE_TASK+vid*100,parms,5)
	}
}

public charge_amazon(parms[])
{
	new stop[3]
	
	for(new i=0;i<3;i++)
	{
		stop[i] =parms[i]
	}
	amazon_Line(parms[3],parms[4],stop)
}

public grenade_throw(id, ent, wID)
{
	if((player_class[id] == Diablo) && is_valid_ent(ent) && (wID==4))
	{
		set_pev(ent, pev_flTimeStepSound, 681856)
	}
	
	if(!g_TrapMode[id] || !is_valid_ent(ent))
		return PLUGIN_CONTINUE
		
	new Float:fVelocity[3]
	VelocityByAim(id, cvar_throw_vel, fVelocity)
	entity_set_vector(ent, EV_VEC_velocity, fVelocity)
	
	new Float: angle[3]
	entity_get_vector(ent,EV_VEC_angles,angle)
	angle[0]=0.00
	entity_set_vector(ent,EV_VEC_angles,angle)
	
	entity_set_float(ent,EV_FL_dmgtime,get_gametime()+3.5)
	
	entity_set_int(ent, NADE_PAUSE, 0)
	entity_set_int(ent, NADE_ACTIVE, 0)
	entity_set_int(ent, NADE_VELOCITY, 0)
	entity_set_int(ent, NADE_TEAM, get_user_team(id))
	
	new param[1]
	param[0] = ent
	set_task(3.0, "task_ActivateTrap", 0, param, 1)
	
	return PLUGIN_CONTINUE
}

public task_ActivateTrap(param[])
{
	new ent = param[0]
	if(!is_valid_ent(ent)) 
		return PLUGIN_CONTINUE
	
	entity_set_int(ent, NADE_PAUSE, 1)
	entity_set_int(ent, NADE_ACTIVE, 1)
	
	new Float:fOrigin[3]
	entity_get_vector(ent, EV_VEC_origin, fOrigin)
	fOrigin[2] -= 8.1*(1.0-floatpower( 2.7182, -0.06798*float(player_agility[entity_get_edict(ent,EV_ENT_owner)])))
	entity_set_vector(ent, EV_VEC_origin, fOrigin)
	
	return PLUGIN_CONTINUE
}

public think_Grenade(ent)
{
	new entModel[33]
	entity_get_string(ent, EV_SZ_model, entModel, 32)
	
	if(!is_valid_ent(ent) || equal(entModel, "models/w_c4.mdl"))
		return PLUGIN_CONTINUE
	
	if(entity_get_int(ent, NADE_PAUSE))
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}

public think_Bot(bot)
{
	new ent = -1
	while((ent = find_ent_by_class(ent, "grenade")))
	{
		new entModel[33]
		entity_get_string(ent, EV_SZ_model, entModel, 32)
			
		if(equal(entModel, "models/w_c4.mdl"))
			continue

		if(!entity_get_int(ent, NADE_ACTIVE))
			continue
				 
		new Players[32], iNum
		get_players(Players, iNum, "a")
						
		for(new i = 0; i < iNum; ++i)
		{
			new id = Players[i]
			if(entity_get_int(ent, NADE_TEAM) == get_user_team(id)) 
				continue
				
			if(get_entity_distance(id, ent) > cvar_activate_dis || player_speed(id) <200.0) 
				continue
			
			if(entity_get_int(ent, NADE_VELOCITY)) continue
			
			new Float:fOrigin[3]
			entity_get_vector(ent, EV_VEC_origin, fOrigin)
			while(PointContents(fOrigin) == CONTENTS_SOLID)
				fOrigin[2] += 100.0
		
			entity_set_vector(ent, EV_VEC_origin, fOrigin)
			drop_to_floor(ent)
				
			new Float:fVelocity[3]
			entity_get_vector(ent, EV_VEC_velocity, fVelocity)
			fVelocity[2] += float(cvar_nade_vel)
			entity_set_vector(ent, EV_VEC_velocity, fVelocity)
			entity_set_int(ent, NADE_VELOCITY, 1)
		
			new param[1]
			param[0] = ent 
			//set_task(cvar_explode_delay, "task_ExplodeNade", 0, param, 1)
			entity_set_float(param[0], EV_FL_nextthink, halflife_time() + cvar_explode_delay)
			entity_set_int(param[0], NADE_PAUSE, 0)
		}
	}
	if(get_timeleft()<2 && map_end<2)
	{
		map_end=2
	}
	else if(get_timeleft()<6 && map_end<1)
	{
		new play[32],num

		get_players(play,num)
		
		for(new i=0;i<num;i++)
		{
			if (player_class[i] != 0)
			{
				MYSQLX_Save(i)
			}
		}
		map_end=1
	}
	
	entity_set_float(bot, EV_FL_nextthink, halflife_time() + 0.1)
}

stock Float:player_speed(index) 
{
	new Float:vec[3]
	
	pev(index,pev_velocity,vec)
	vec[2]=0.0
	
	return floatsqroot ( vec[0]*vec[0]+vec[1]*vec[1] )
}

public _create_ThinkBot()
{
	new think_bot = create_entity("info_target")
	if(!is_valid_ent(think_bot))
		log_amx("For some reason, the universe imploded, reload your server")
	else 
	{
		entity_set_string(think_bot, EV_SZ_classname, "think_bot")
		entity_set_float(think_bot, EV_FL_nextthink, halflife_time() + 1.0)
	}
}

public change_health(id,hp,attacker,weapon[])
{
	if(is_user_alive(id) && is_user_connected(id))
	{
		new health = get_user_health(id)
		if(hp>0)
		{
			new m_health = race_heal[player_class[id]]+player_strength[id]*2
			if(player_item_id[id]==17 &&hp>0)
			{
				set_user_health(id,health+floatround(float(hp/10),floatround_floor)+1)
			}
			else if(player_item_id[id]==88 &&hp>0)
			{
				set_user_health(id,health+floatround(float(hp/10),floatround_floor)+1)
			}
			else if(player_item_id[id]==89 &&hp>0)
			{
				set_user_health(id,health+floatround(float(hp/10),floatround_floor)+1)
			}
			else if (hp+health>m_health) set_user_health(id,m_health)
			else set_user_health(id,get_user_health(id)+hp)
		}
		else
		{
			if(health+hp<1)
			{
				UTIL_Kill(attacker,id,weapon)
			}
			else set_user_health(id,get_user_health(id)+hp)
		}
		
		if(id!=attacker && hp<0) 
		{
			dmg_exp(attacker, -hp)
		}
	}
}

public UTIL_Kill(attacker,id,weapon[])
{
	if( is_user_alive(id)){
		if(get_user_team(attacker)!=get_user_team(id))
			set_user_frags(attacker,get_user_frags(attacker) +1);
	
		if(get_user_team(attacker)==get_user_team(id))
			set_user_frags(attacker,get_user_frags(attacker) -1);
		
		if (cs_get_user_money(attacker) + 150 <= 16000)
			cs_set_user_money(attacker,cs_get_user_money(attacker)+150)
		else
			cs_set_user_money(attacker,16000)
	
		cs_set_user_deaths(id, cs_get_user_deaths(id)+1)
		user_kill(id,1) 
		
		if(is_user_connected(attacker) && attacker!=id)
		{
			award_kill(attacker,id)
			if(is_user_alive(attacker)) award_item(attacker,0)
		}
				
		message_begin( MSG_ALL, gmsgDeathMsg,{0,0,0},0) 
		write_byte(attacker) 
		write_byte(id) 
		write_byte(0) 
		write_string(weapon) 
		message_end() 
	
		message_begin(MSG_ALL,gmsgScoreInfo) 
		write_byte(attacker) 
		write_short(get_user_frags(attacker)) 
		write_short(get_user_deaths(attacker)) 
		write_short(0) 
		write_short(get_user_team(attacker)) 
		message_end() 
	
		message_begin(MSG_ALL,gmsgScoreInfo) 
		write_byte(id) 
		write_short(get_user_frags(id)) 
		write_short(get_user_deaths(id)) 
		write_short(0) 
		write_short(get_user_team(id)) 
		message_end() 
	
		new kname[32], vname[32], kauthid[32], vauthid[32], kteam[10], vteam[10];
	
		get_user_name(attacker, kname, 31);
		get_user_team(attacker, kteam, 9);
		get_user_authid(attacker, kauthid, 31);
	
		get_user_name(id, vname, 31);
		get_user_team(id, vteam, 9);
		get_user_authid(id, vauthid, 31);
	
		log_message("^"%s<%d><%s><%s>^" killed ^"%s<%d><%s><%s>^" with ^"%s^"", 
		kname, get_user_userid(attacker), kauthid, kteam, 
		vname, get_user_userid(id), vauthid, vteam, weapon);
	}
}


stock Display_Fade(id,duration,holdtime,fadetype,red,green,blue,alpha)
{
	message_begin( MSG_ONE, g_msg_screenfade,{0,0,0},id )
	write_short( duration )	// Duration of fadeout
	write_short( holdtime )	// Hold time of color
	write_short( fadetype )	// Fade type
	write_byte ( red )		// Red
	write_byte ( green )		// Green
	write_byte ( blue )		// Blue
	write_byte ( alpha )	// Alpha
	message_end()
}

stock Display_Icon(id ,enable ,name[] ,red,green,blue)
{
	if (!pev_valid(id) || is_user_bot(id))
	{
		return PLUGIN_HANDLED
	}
//	new string [8][32] = {"dmg_rad","item_longjump","dmg_shock","item_healthkit","dmg_heat","suit_full","cross","dmg_gas"}
	
	message_begin( MSG_ONE, g_msg_statusicon, {0,0,0}, id ) 
	write_byte( enable ) 	
	write_string( name ) 
	write_byte( red ) // red 
	write_byte( green ) // green 
	write_byte( blue ) // blue 
	message_end()
	
	return PLUGIN_CONTINUE
}

public createBlockAiming(id)
{
	
	new Float:vOrigin[3];
	new Float:vAngles[3]
	entity_get_vector(id,EV_VEC_v_angle,vAngles)
	entity_get_vector(id,EV_VEC_origin,vOrigin)
	new Float:offset = distance_to_floor(vOrigin)
	vOrigin[2]+=17.0-offset
	//create the block
	
	if(vAngles[1]>45.0&&vAngles[1]<135.0)
	{
		vOrigin[0]+=0.0
		vOrigin[1]+=34.0
		if(chacke_pos(vOrigin,0)==0) return
		make_shild(id,vOrigin,vAngles1,gfBlockSizeMin1,gfBlockSizeMax1)
	}
	else if(vAngles[1]<-45.0&&vAngles[1]>-135.0)
	{
		vOrigin[0]+=0.0
		vOrigin[1]+=-34.0
		if(chacke_pos(vOrigin,0)==0) return
		make_shild(id,vOrigin,vAngles1,gfBlockSizeMin1,gfBlockSizeMax1)
	}
	else if(vAngles[1]>-45.0&&vAngles[1]<45.0)
	{
		vOrigin[0]+=34.0
		vOrigin[1]+=0.0
		if(chacke_pos(vOrigin,1)==0) return
		make_shild(id,vOrigin,vAngles2,gfBlockSizeMin2,gfBlockSizeMax2)
	}
	else
	{
		vOrigin[0]+=-34.0
		vOrigin[1]+=0.0
		if(chacke_pos(vOrigin,1)==0) return
		make_shild(id,vOrigin,vAngles2,gfBlockSizeMin2,gfBlockSizeMax2)
	}
}

public make_shild(id,Float:vOrigin[3],Float:vAngles[3],Float:gfBlockSizeMin[3],Float:gfBlockSizeMax[3])
{
	new ent = create_entity("info_target")
	
	//make sure entity was created successfully
	if (is_valid_ent(ent))
	{
		//set block properties
		entity_set_string(ent, EV_SZ_classname, "dbmod_shild")
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NONE)
		entity_set_float(ent,EV_FL_health,200.0+float(player_intelligence[id]*2))
		entity_set_float(ent,EV_FL_takedamage,1.0)
				
		entity_set_model(ent, "models/diablomod/bm_block_platform.mdl");
		entity_set_vector(ent, EV_VEC_angles, vAngles)
		entity_set_size(ent, gfBlockSizeMin, gfBlockSizeMax)
		
		entity_set_edict(ent,EV_ENT_euser1,id)
		
		entity_set_origin(ent, vOrigin)
		
		num_shild[id]--
		
		return 1
	}
	return 0
}

public call_cast(id)
{
	
	set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 3.0, 0.1, 0.4, 18)
	
	switch(player_class[id])
	{
		case Mag:
		{
			show_hudmessage(id, "[Маг] Выстрел огненным шаром") 
			fired[id]=0
			item_fireball(id)
		}
		case Monk:
		{
			if(num_shild[id])
			{
				createBlockAiming(id)
				show_hudmessage(id, "[Монах] Стенка установленна.^n%d осталось",num_shild[id]) 
			}
			else hudmsg(id,5.0,"[Монах] У вас нет стенок") 
		}
		case Paladin:
		{
			
			golden_bulet[id]++
			if(golden_bulet[id]>3)
			{
				golden_bulet[id]=3
				hudmsg(id,5.0,"[Паладин] У вас максимальное кол-во магических пулей - 3",golden_bulet[id]) 
			}
			else if(golden_bulet[id]==1)show_hudmessage(id, "[Paladin] У вас одна магическая пуля") 
			else if(golden_bulet[id]>1)show_hudmessage(id, "[Paladin] У вас %i магических пулей",golden_bulet[id]) 
		}
		case Assassin:
		{
			show_hudmessage(id, "[Ассассин] Вы временно невидимыми (только нож)") 
			invisible_cast[id]=1
			set_renderchange(id)
		}
		case Ninja:
		{
			set_user_maxspeed(id,get_user_maxspeed(id)+25.0)
			show_hudmessage(id, "[Нинзя] +25 к скорости. %f",get_user_maxspeed(id)) 
		}
		case Baal:
		{
			if(baal_copyed[id] == 0)
			{
				create_baal_copy(id)
				show_hudmessage(id, "[Баал] Ваша копия создана и будет удалена через 30 секунд") 
			}
			else
			{
				hudmsg(id,5.0,"Не больше одной копии. Дождитесь ее удаления!");
			}
		}
		case Mephisto:
		{
			create_firewall(id)
			show_hudmessage(id, "[Мефисто] Огненная стена") 
		}
		case Diablo:
		{
			if(player_intelligence[id] < 1)
			{
				hudmsg(id,5.0,"Необходим интеллект!");
			}
			else if(diablo_lights[id] > 3)
			{
				hudmsg(id,5.0,"У вас максимум молний");
			}
			else
			{
				diablo_lights[id]++
				show_hudmessage(id, "[Диабло] +Молния %d/2", diablo_lights[id]) 
			}
		}
		case Duriel:
		{
			if(duriel_boost[id] < 3)
			{
				duriel_boost[id]++
				show_hudmessage(id, "[Дуриель] +Ярость %d/3",duriel_boost[id]) 
			}
			else
			{
				hudmsg(id,5.0,"У вас максимум ярости")
			}
		}
		case Zakarum:
		{
			new Float:zak_maxspeed
			new speed_points = player_dextery[id] * 2;
			zak_maxspeed = float(speed_points + 400);
			show_hudmessage(id, "[Закарум] Макс. скорость %i. ^nСбивается при переключении оружия.", floatround(zak_maxspeed,floatround_round))
			set_user_maxspeed(id,zak_maxspeed)
		}
		case Viper:
		{
			show_hudmessage(id, "[Саламандра] Выстрел костяным копьем") 
			fired_viper[id]=0
			item_viper(id)
		}
		case BloodRaven:
		{
			if(fire_bows[id] < 6)
			{
				fire_bows[id]++
				show_hudmessage(id, "[Кровавый ворон] Вы получили огненую стрелу(%d/6)",fire_bows[id])
			}
			else
			{
				hudmsg(id,5.0,"У вас максимум стрел")
			}
		}
		case Mosquito:
		{
			if(mosquito_sting[id] < 10)
			{
				mosquito_sting[id]++
				show_hudmessage(id, "[Гигантский комар] Вы получили ядовитое жало(%d/10)",mosquito_sting[id])
			}
			else
			{
				hudmsg(id,5.0,"У вас максимум ядовитых жал")
			}
		}
		case Frozen:
		{
			show_hudmessage(id, "[Ледяной ужас] Бесшумный шаг до конца раунда")
			c_silent[id] = 1
		}
		case Infidel:
		{
			show_hudmessage(id, "[Инфидель] Временное увеличение скорости") 
			set_user_maxspeed(id,get_user_maxspeed(id)+50.0)
		}
		case Barbarian:
		{
			ultra_armor[id]++
			if(ultra_armor[id]>7)
			{
				ultra_armor[id]=7
				hudmsg(id,5.0,"[Варвар] У вас макс магической брони - 7",ultra_armor[id]) 
			}
			else show_hudmessage(id, "[Варвар] +Магическая броня(%i/7)",ultra_armor[id]) 
		}
		case Izual:
		{
			izual_ring[id]++
			if(izual_ring[id]>2)
			{
				izual_ring[id]=2
				hudmsg(id,5.0,"[Изуал] У вас максимум колец - 2") 
			}
			else show_hudmessage(id, "[Изуал] %d/2 колец",izual_ring[id]) 
		}
		case Griswold:
		{
			if(player_item_id[id] != 0)
			{
			show_hudmessage(id, "[Griswold] У вас уже есть Item")
			}
			else 
			{
				losowe_itemy[id]++
				if(losowe_itemy[id] > 3) 
				{
					losowe_itemy[id] = 3
					show_hudmessage(id, "[Griswold] Полученно предметов - %i", losowe_itemy[id])
				}
				else
				{
					award_item(id, 0)
				}
			}
		}
		case TheSmith:
		{
			if(player_item_id[id] != 0)
			{
			hudmsg(id,5.0,"[The Smith] У вас уже есть Item")
			}
			else 
			{
				losowe_itemy[id]++
				if(losowe_itemy[id] > 3) 
				{
					losowe_itemy[id] = 3
					show_hudmessage(id, "[The Smith] Полученно предметов - %i", losowe_itemy[id])
				}
				else
				{
					award_item(id, 0)
				}
			}
		}
		case Demonolog:
		{
			if(player_item_id[id] != 0)
			{
			hudmsg(id,5.0,"[Demonolog] У вас уже есть Item")
			}
			else 
			{
				losowe_itemy[id]++
				if(losowe_itemy[id] > 3) 
				{
					losowe_itemy[id] = 3
					show_hudmessage(id, "[Demonolog] Полученно предметов - %i", losowe_itemy[id])
				}
				else
				{
					award_item(id, 0)
				}
			}
		}
		case Amazon: 
		{
			if(!g_bWeaponsDisabled)
			{
				fm_give_item(id, "weapon_hegrenade")
				show_hudmessage(id, "[Amazon] Вы получили HE гранату")
			}
			else
			{
				hudmsg(id,5.0,"На этой карте оружие не выдаётся!")
			}
		}
		case Fallen: 
		{
			if(!g_bWeaponsDisabled)
			{
				fm_give_item(id, "weapon_flashbang")
				fm_give_item(id, "weapon_flashbang")
				show_hudmessage(id, "[Падший] Вы получили 2 Flash гранаты")
			}
			else
			{
				hudmsg(id,5.0,"На этой карте оружие не выдаётся!")
			}
		}
		case SabreCat: 
		{
			fm_give_item(id, "weapon_smokegrenade")
			show_hudmessage(id, "[Адский кот] Вы получили яд")
		}
		case GiantSpider: 
		{
			new max_traps
			if(player_intelligence[id] > 0 && player_intelligence[id] < 25)
			{
				max_traps = 1
			}
			else if(player_intelligence[id] > 24 && player_intelligence[id] < 51)
			{
				max_traps = 2
			}
			if(max_traps == 0)
			{
				hudmsg(id,5.0,"Прокачайте интеллект, чтобы использовать ловушку!")
				return;
			}
			if(spider_traps[id] < max_traps)
			{
				create_trap(id)
				show_hudmessage(id, "[Гигантский паук] Ловушка установлена")
			}
			else
			{
				hudmsg(id,5.0,"Ловушки закончились!")
			}
		}
	}	
}

public chacke_pos(Float:vOrigin[3],axe)
{
	new test=0
	vOrigin[axe]-=15.0
	if(distance_to_floor(vOrigin)<31.0) test++
	vOrigin[axe]+=15.0
	if(distance_to_floor(vOrigin)<31.0) test++
	vOrigin[axe]+=15.0
	if(distance_to_floor(vOrigin)<31.0) test++
	if(test<2) return 0
	vOrigin[axe]-=15.0
	return 1
}

public fw_traceline(Float:vecStart[3],Float:vecEnd[3],ignoreM,id,trace) // pentToSkip == id, for clarity
 {
 	
	if(!is_user_connected(id))
		return FMRES_IGNORED;

	// not a player entity, or player is dead
	if(!is_user_alive(id))
		return FMRES_IGNORED;

	new hit = get_tr2(trace, TR_pHit)	
	
	// not shooting anything
	if(!(pev(id,pev_button) & IN_ATTACK))
		return FMRES_IGNORED;
		
	new h_bulet=0
	
	if(golden_bulet[id]>0) 
	{
		golden_bulet[id]--
		h_bulet=1
	}
		
	if(is_valid_ent(hit))
	{
		new name[64]
		entity_get_string(hit,EV_SZ_classname,name,63)
		
		if(equal(name,"dbmod_shild"))
		{
			new Float: ori[3]
			entity_get_vector(hit,EV_VEC_origin,ori)
			set_tr2(trace,TR_vecEndPos,vecEnd)
			if(after_bullet[id]>0)
			{			
				new Float: health=entity_get_float(hit,EV_FL_health)
				entity_set_float(hit,EV_FL_health,health-3.0)
				if(health-1.0<0.0) remove_entity(hit)
				after_bullet[id]--
			}
			set_tr2(trace,TR_iHitgroup,8);
			set_tr2(trace,TR_flFraction,1.0);
			return FMRES_SUPERCEDE;
		}
	}	
		
	if(is_user_alive(hit))
	{
		if(h_bulet)
		{
			set_tr2(trace, TR_iHitgroup, HIT_HEAD) // Redirect shot to head
	    
			// Variable angles doesn't really have a use here.
			static hit, Float:head_origin[3], Float:angles[3]
			
			hit = get_tr2(trace, TR_pHit) // Whomever was shot
			engfunc(EngFunc_GetBonePosition, hit, 8, head_origin, angles) // Find origin of head bone (8)
			
			set_tr2(trace, TR_vecEndPos, head_origin) // Blood now comes out of the head!
		}
		
		if(ultra_armor[hit]>0 || (player_class[hit]==Paladin && random_num(0,7)==1) || random_num(0,player_ultra_armor_left[hit])==1)
		{
			if(after_bullet[id]>0)
			{
				if(ultra_armor[hit]>0) ultra_armor[hit]--
				else if(player_ultra_armor_left[hit]>0)player_ultra_armor_left[hit]--
				after_bullet[id]--
			}
			set_tr2(trace, TR_iHitgroup, 8)
		}
		return FMRES_IGNORED
	}
		
	return FMRES_IGNORED;
}

stock Float:distance_to_floor(Float:start[3], ignoremonsters = 1) {
    new Float:dest[3], Float:end[3];
    dest[0] = start[0];
    dest[1] = start[1];
    dest[2] = -8191.0;

    engfunc(EngFunc_TraceLine, start, dest, ignoremonsters, 0, 0);
    get_tr2(0, TR_vecEndPos, end);

    //pev(index, pev_absmin, start);
    new Float:ret = start[2] - end[2];

    return ret > 0 ? ret : 0.0;
}

public dmg_exp(id, dmg)
{
	if(dmg > 0)
	{
		new Float:exp = dmg/get_cvar_num("diablo_xpdmg")
		new xp = floatround(exp)
		if(xp > 0)
		{
			Give_Xp(id,xp)
		}
	}
}

public native_get_user_xp(id)
{
	return player_xp[id]
}

public native_set_user_xp(id, amount)
{
	player_xp[id]=amount
	if (player_xp[id] > LevelXP[player_lvl[id]])
	{
		player_lvl[id]+=1
		player_point[id]+=2
		set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 2.0, 0.1, 0.2, 2)
		show_hudmessage(id, "Уровень повышен до %i", player_lvl[id]) 
		MYSQLX_Save(id)
		player_class_lvl[id][player_class[id]]=player_lvl[id]
	}
	
	if (player_xp[id] < LevelXP[player_lvl[id]-1])
	{
		player_lvl[id]-=1
		player_point[id]-=2
		set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 2.0, 0.1, 0.2, 2)
		show_hudmessage(id, "Уровень понижен до %i", player_lvl[id]) 
		MYSQLX_Save(id)
		player_class_lvl[id][player_class[id]]=player_lvl[id]
	}
	write_hud(id)
}

public native_get_user_level(id)
{
	return player_lvl[id]
}

public native_set_user_level(id, amount)
{
	native_set_user_xp(id, LevelXP[amount])
}

public native_get_user_class(id)
{
	return player_class[id]
}

public native_set_user_class(id, class)
{
	g_haskit[id] = 0
	player_class[id] = class		

	MYSQLX_SetDataForRace( id )
	CurWeapon(id)
	
	give_knife(id)
}



public native_get_user_item(id)
{
	return player_item_id[id]
}

public native_set_user_item(id, item)
{
	emit_sound(id,CHAN_STATIC,"diablo_lp/ring.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	switch(item)
	{
		case 1:
		{
			player_item_name[id] = "Bronze Amplifier"
			player_b_damage[id] = random_num(1,3)
			show_hudmessage(id, "Вы нашли item: %s ::  +%i дополнительного урона с каждого выстрела.",player_item_name[id],player_b_damage[id])
		}
		
		case 2:
		{
			player_item_name[id] = "Silver Amplifier"
			player_b_damage[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: +%i дополнительного урона с каждого выстрела.",player_item_name[id],player_b_damage[id])
		}
		
		case 3:
		{
			player_item_name[id] = "Gold Amplifier"
			player_b_damage[id] = random_num(6,10)
			show_hudmessage(id, "Вы нашли item: %s :: +%i дополнительного урона с каждого выстрела.",player_item_name[id],player_b_damage[id])	
		}
		case 4:
		{
			player_item_name[id] = "Vampyric Staff"
			player_b_vampire[id] = random_num(1,4)
			show_hudmessage(id, "Вы нашли item: %s :: %i hp высасывает с каждого выстрела.",player_item_name[id],player_b_vampire[id])	
		}
		case 5:
		{
			player_item_name[id] = "Vampyric Amulet"
			player_b_vampire[id] = random_num(4,6)
			show_hudmessage(id, "Вы нашли item: %s :: %i hp высасывает с каждого выстрела.",player_item_name[id],player_b_vampire[id])	
		}
		case 6:
		{
			player_item_name[id] = "Vampyric Scepter"
			player_b_vampire[id] = random_num(6,9)
			show_hudmessage(id, "Вы нашли item: %s :: %i hp высасывает с каждого выстрела.",player_item_name[id],player_b_vampire[id])	
		}
		case 7:
		{
			player_item_name[id] = "Small bronze bag"
			player_b_money[id] = random_num(150,500)
			show_hudmessage(id, "Вы нашли item: %s :: +%i каждый раунд + При нажатии Е активируется щит котрый снижает урон по вам на 50% жрущий по 200$ каждые 2-3 секунды.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 8:
		{
			player_item_name[id] = "Medium silver bag"
			player_b_money[id] = random_num(500,1200)
			show_hudmessage(id, "Вы нашли item: %s :: +%i каждый раунд + При нажатии Е активируется щит котрый снижает урон по вам на 50% жрущий по 200$ каждые 2-3 секунды.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 9:
		{
			player_item_name[id] = "Large gold bag"
			player_b_money[id] = random_num(1200,3000)
			show_hudmessage(id, "Вы нашли item: %s :: +%i каждый раунд + При нажатии Е активируется щит котрый снижает урон по вам на 50% жрущий по 200$ каждые 2-3 секунды.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 10:
		{
			player_item_name[id] = "Small angel wings"
			player_b_gravity[id] = random_num(1,5)
			
			if (is_user_alive(id))
				set_gravitychange(id)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i бонус к гравитации при прыжке и нажатии Е резко падает на землю и мгновенно убивает врага на небольшом радиусе.",player_item_name[id],player_b_gravity[id])	
		}
		case 11:
		{
			player_item_name[id] = "Arch angel wings"
			player_b_gravity[id] = random_num(5,9)
			
			if (is_user_alive(id))
				set_gravitychange(id)
				
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i бонус к гравитации при прыжке и нажатии Е резко падает на землю и мгновенно убивает врага на среднем радиусе.",player_item_name[id],player_b_gravity[id])	
			
		}
		case 12:
		{
			player_item_name[id] = "Invisibility Rope"
			player_b_inv[id] = random_num(150,200)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i незначительную прозрачность чара.",player_item_name[id],255-player_b_inv[id])	
		}
		case 13:
		{
			player_item_name[id] = "Invisibility Coat"
			player_b_inv[id] = random_num(110,150)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i незначительную прозрачность чара.",player_item_name[id],255-player_b_inv[id])	
		}
		case 14:
		{
			player_item_name[id] = "Invisibility Armor"
			player_b_inv[id] = random_num(70,110)
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i незначительную прозрачность чара.",player_item_name[id],255-player_b_inv[id])	
		}
		case 15:
		{
			player_item_name[id] = "Firerope"
			player_b_grenade[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: +1/%i  шанс мгновенно убить врага с гранаты",player_item_name[id],player_b_grenade[id])	
		}
		case 16:
		{
			player_item_name[id] = "Fire Amulet"
			player_b_grenade[id] = random_num(2,4)
			show_hudmessage(id, "Вы нашли item: %s :: +1/%i  шанс мгновенно убить врага с гранаты",player_item_name[id],player_b_grenade[id])	
		}
		case 17:
		{
			player_item_name[id] = "Stalkers ring"
			player_b_reduceH[id] = 95
			player_b_inv[id] = 8	
			item_durability[id] = 100
			
			if (is_user_alive(id)) set_user_health(id,5)		
			show_hudmessage(id, "Вы нашли item: %s :: практически полная невидимость, но у вас 5 хп и из оружия только нож, можно ставить бомбу.",player_item_name[id])	
		}
		case 18:
		{
			player_item_name[id] = "Arabian Boots"
			player_b_theif[id] = random_num(500,1000)
			show_hudmessage(id, "Вы нашли item: %s :: с каждым выстрелом высасывает с противника деньги, в зависимости от дамага",player_item_name[id],player_b_theif[id])	
		}
		case 19:
		{
			player_item_name[id] = "Phoenix Ring"
			player_b_respawn[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i воскреситься после смерти.",player_item_name[id],player_b_respawn[id])	
		}
		case 20:
		{
			player_item_name[id] = "Sorcerers ring"
			player_b_respawn[id] = random_num(2,3)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i воскреситься после смерти.",player_item_name[id],player_b_respawn[id])	
		}
		case 21:
		{
			player_item_name[id] = "Chaos Orb"
			player_b_explode[id] = random_num(150,275)
			show_hudmessage(id, "Вы нашли item: %s :: после смерти взрываетесь в радиусе %i",player_item_name[id],player_b_explode[id])	
		}
		case 22:
		{
			player_item_name[id] = "Hell Orb"
			player_b_explode[id] = random_num(200,400)
			show_hudmessage(id, "Вы нашли item: %s :: после смерти взрываетесь в радиусе %i",player_item_name[id],player_b_explode[id])	
		}
		case 23:
		{
			player_item_name[id] = "Gold statue"
			player_b_heal[id] = random_num(5,10)
			show_hudmessage(id, "Вы нашли item: %s :: При нажатии на Е появляется тотем, котрый лечит вас и вашу команду. %i хп за 5 секунд, тотем активен в течении 7 секунд в пределах %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 24:
		{
			player_item_name[id] = "Daylight Diamond"
			player_b_heal[id] = random_num(10,20)
			show_hudmessage(id, "Вы нашли item: %s :: При нажатии на Е появляется тотем, котрый лечит вас и вашу команду. %i хп за 5 секунд, тотем активен в течении 7 секунд в пределах %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 25:
		{
			player_item_name[id] = "Blood Diamond"
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "Вы нашли item: %s :: При нажатии на Е появляется тотем, котрый лечит вас и вашу команду. %i хп за 5 секунд, тотем активен в течении 7 секунд в пределах %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 26:
		{
			player_item_name[id] = "Wheel of Fortune"
			player_b_gamble[id] = random_num(2,3)
			show_hudmessage(id, "Вы нашли item: %s :: даёт рандомно +%i бонусов каждый раунд.",player_item_name[id],player_b_gamble[id])	
		}
		case 27:
		{
			player_item_name[id] = "Four leaf Clover"
			player_b_gamble[id] = random_num(4,5)
			show_hudmessage(id, "Вы нашли item: %s :: даёт рандомно +%i бонусов каждый раунд.",player_item_name[id],player_b_gamble[id])	
		}
		case 28:
		{
			player_item_name[id] = "Amulet of the sun"
			player_b_blind[id] = random_num(6,9)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i ослепить противника при атаке. Экран становиться почти польностью оранжевым в течении 7-10 секунд",player_item_name[id],player_b_blind[id])	
		}
		case 29:
		{
			player_item_name[id] = "Sword of the sun"
			player_b_blind[id] = random_num(2,5)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i ослепить противника при атаке. Экран становиться почти польностью оранжевым в течении 7-10 секунд",player_item_name[id],player_b_blind[id])	
		}
		case 30:
		{
			player_item_name[id] = "Fireshield"
			player_b_fireshield[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии Е активируется щит который наносит дамаг противнику. Уменьшает ваше здоровье, 20 хп каждые 2 секунды.",player_item_name[id],player_b_fireshield[id])	
		}
		case 31:
		{
			player_item_name[id] = "Stealth Shoes"
			player_b_silent[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: бесшумный шаг (эфект рассы Ассассин).",player_item_name[id])	
		}
		case 32:
		{
			player_item_name[id] = "Meekstone"
			player_b_meekstone[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: бомба на дистанционом управлении. Е положить бомбу, второе нажатие Е взорвать.",player_item_name[id])	
		}
		case 33:
		{
			player_item_name[id] = "Medicine Glar"
			player_b_teamheal[id] = random_num(10,20)
			show_hudmessage(id, "Вы нашли item: %s :: При атаке в сокомандника востанавливается %i хп. при нажатии Е активирует на члене команды щит котрый возвращает дамаг.",player_item_name[id],player_b_teamheal[id])	
		}
		case 34:
		{
			player_item_name[id] = "Medicine Totem"
			player_b_teamheal[id] = random_num(20,30)
			show_hudmessage(id, "Вы нашли item: %s :: При атаке в сокомандника востанавливается %i хп. при нажатии Е активирует на члене команды щит котрый возвращает дамаг.",player_item_name[id],player_b_teamheal[id])	
		}
		case 35:
		{
			player_item_name[id] = "Iron Armor"
			player_b_redirect[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: снижает +%i дамага по вам с каждого выстрела.",player_item_name[id],player_b_redirect[id])	
		}
		case 36:
		{
			player_item_name[id] = "Mitril Armor"
			player_b_redirect[id] = random_num(6,11)
			show_hudmessage(id, "Вы нашли item: %s :: снижает +%i дамага по вам с каждого выстрела.",player_item_name[id],player_b_redirect[id])	
		}
		case 37:
		{
			player_item_name[id] = "Godly Armor"
			player_b_redirect[id] = random_num(10,15)
			show_hudmessage(id, "Вы нашли item: %s :: снижает +%i дамага по вам с каждого выстрела.",player_item_name[id],player_b_redirect[id])	
		}
		case 38:
		{
			player_item_name[id] = "Fireball staff"
			player_b_fireball[id] = random_num(50,100)
			show_hudmessage(id, "Вы нашли item: %s :: Запускает ракету, взрывающуюся в радиусе %i",player_item_name[id],player_b_fireball[id])	
		}
		case 39:
		{
			player_item_name[id] = "Fireball scepter"
			player_b_fireball[id] = random_num(100,200)
			show_hudmessage(id, "Вы нашли item: %s :: Запускает ракету, взрывающуюся в радиусе %i",player_item_name[id],player_b_fireball[id])	
		}
		case 40:
		{
			player_item_name[id] = "Ghost Rope"
			player_b_ghost[id] = random_num(3,6)
			show_hudmessage(id, "Вы нашли item: %s :: Возможность ходить сквозь стены, эфект длиться %i секунд",player_item_name[id],player_b_ghost[id])	
		}
		case 41:
		{
			player_item_name[id] = "Nicolas Eye"
			player_b_eye[id] = -1
			show_hudmessage(id, "Вы нашли item: %s :: Устанавливает камеру на стене.",player_item_name[id])	
		}
		case 42:
		{
			player_item_name[id] = "Knife Ruby"
			player_b_blink[id] = floatround(halflife_time())
			show_hudmessage(id, "Вы нашли item: %s :: при использовании ножа второй конопкой телепортирует вас на небольшое растояние",player_item_name[id])	
		}
		case 43:
		{
			player_item_name[id] = "Lothars Edge"
			player_b_windwalk[id] = random_num(4,7)
			show_hudmessage(id, "Вы нашли item: %s :: на %i секунд даёт среднюю прозрачность + сильно увеличивает ваш бег.",player_item_name[id],player_b_windwalk[id])	
		}
		case 44:
		{
			player_item_name[id] = "Sword"
			player_sword[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: увеличивает урон ножу",player_item_name[id])		
		}
		case 45:
		{
			player_item_name[id] = "Mageic Booster"
			player_b_froglegs[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: каждые 3 секунды сидя вы очень длинно прыгаете.(item не всегда работает)",player_item_name[id])	
		}
		case 46:
		{
			player_item_name[id] = "Dagon I"
			player_b_dagon[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии USE наносит дамаг противнику на близком растоянии раз в 20 секунд",player_item_name[id])	
		}
		case 47:
		{
			player_item_name[id] = "Scout Extender"
			player_b_sniper[id] = random_num(3,4)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i мгновенно убить со скаута.",player_item_name[id],player_b_sniper[id])	
		}
		case 48:
		{
			player_item_name[id] = "Scout Amplifier"
			player_b_sniper[id] = random_num(2,3)
			show_hudmessage(id, "Вы нашли item: %s :: шанс 1/%i мгновенно убить со скаута.",player_item_name[id],player_b_sniper[id])	
		}
		case 49:
		{
			player_item_name[id] = "Air booster"
			player_b_jumpx[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: Вы можете сделать двойной прыжок в воздухе",player_item_name[id],player_b_sniper[id])	
		}
		case 50:
		{
			player_item_name[id] = "Iron Spikes"
			player_b_smokehit[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: убивает дымовой гранатой, если попасть ей в противника",player_item_name[id])	
		}
		case 51:
		{
			player_item_name[id] = "Point Booster"
			player_b_extrastats[id] = random_num(1,3)
			BoostStats(id,player_b_extrastats[id])
			show_hudmessage(id, "Вы нашли item: %s :: даёт +%i очков к каждому умнению",player_item_name[id],player_b_extrastats[id])	
		}
		case 52:
		{
			player_item_name[id] = "Totem amulet"
			player_b_firetotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии на Е ставит жёлтый тотем который через несколько секунд взрывается и поджигает всех в большом радиусе.",player_item_name[id])	
		}
		case 53:
		{
			player_item_name[id] = "Mageic Hook"
			player_b_hook[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии USE притягивает к себе врага",player_item_name[id])	
		}
		case 54:
		{
			player_item_name[id] = "Darksteel Glove"
			player_b_darksteel[id] = random_num(1,5)
			show_hudmessage(id, "Вы нашли item: %s :: усиленный дамаг при атаке противника со спины.",player_item_name[id])	
		}
		case 55:
		{
			player_item_name[id] = "Darksteel Gaunlet"
			player_b_darksteel[id] = random_num(7,9)
			show_hudmessage(id, "Вы нашли item: %s :: усиленный дамаг при атаке противника со спины.",player_item_name[id])	
		}
		case 56:
		{
			player_item_name[id] = "Illusionists Cape"
			player_b_illusionist[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: при нажатии на Е вы становитесь полностью (100%)невидимым. однако и вы никого не видите и умираете от 1 выстрела.",player_item_name[id])	
		}
		case 57:
		{
			player_item_name[id] = "Techies scepter"
			player_b_mine[id] = 3
			show_hudmessage(id, "Вы нашли item: %s :: ставит 3 полуневидимые мины.",player_item_name[id])
		}
		
		case 58:
		{
			player_item_name[id] = "Ninja ring"
			player_b_blink[id] = floatround(halflife_time())
			player_b_froglegs[id] = 1
			show_hudmessage(id, "Вы нашли item: %s :: Нож позволяет вам телепортироваться каждые 3 секунды. Зажмите DUCK чтобы прыгнуть далеко.",player_item_name[id])
		}
		case 59:	
		{
			player_item_name[id] = "Mage ring"
			player_ring[id]=1
			player_b_fireball[id] = random_num(50,80)
			show_hudmessage(id, "Вы нашли item : %s :: Возможность стрелять огненными шарами +5 интеллект",player_item_name[id])
		}	
		case 60:	
		{
			player_item_name[id] = "Necromant ring"
			player_b_respawn[id] = random_num(2,4)
			player_b_vampire[id] = random_num(3,5)	
			show_hudmessage(id, "Вы нашли item : %s :: Шанс возродиться после смерти. При попадании во врага, частично восполняет ваше НР",player_item_name[id])
		}
		case 61:
		{
			player_item_name[id] = "Barbarian ring"
			player_b_explode[id] = random_num(120,330)
			player_ring[id]=2
			show_hudmessage(id, "Вы нашли item : %s :: Когда вас убивают вы взрываетесь, нанося урон стоящим в близи врагам. +5 сила",player_item_name[id])
		}
		case 62:
		{
			player_item_name[id] = "Paladin ring"	
			player_b_redirect[id] = random_num(7,17)
			player_b_blind[id] = random_num(3,4)
			show_hudmessage(id, "Вы нашли item : %s :: Снижение дамага по вам. Шанс ослепить противника",player_item_name[id])		
		}
		case 63:
		{
			player_item_name[id] = "Monk ring"
			player_b_grenade[id] = random_num(1,4)
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "Вы нашли item : %s :: Увиличивает урон наносимый гранатой. Восстанавливает здоровье",player_item_name[id])
		}	
		case 64:
		{
			player_item_name[id] = "Assassin ring"
			player_b_jumpx[id] = 1
			player_ring[id]=3
			show_hudmessage(id, "Вы нашли item : %s :: Двойной прыжок. +5 ловкость",player_item_name[id])	
		}	
		case 65:
		{
			player_item_name[id] = "Flashbang necklace"	
			wear_sun[id] = 1
			show_hudmessage (id, "Вы нашли item : %s :: Иммунитет к ослепляющим гранатам",player_item_name[id])
		}
		case 66:
		{
			player_item_name[id] = "Chameleon"	
			changeskin(id,0)  
			show_hudmessage (id, "Вы нашли item : %s :: Превращение во врага (внешний вид)",player_item_name[id])
		}
		case 67:
		{
			player_item_name[id] = "Stong Armor"	
			player_ultra_armor[id]=random_num(3,6)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "Вы нашли item : %s :: Каждый раунд броня становится равной %i",player_item_name[id],player_ultra_armor[id])
		}
		case 68:
		{
			player_item_name[id] = "Ultra Armor"	
			player_ultra_armor[id]=random_num(7,11)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "Вы нашли item : %s :: Каждый раунд броня становится равной %i",player_item_name[id],player_ultra_armor[id])
		}
		case 69:
		{
			player_item_name[id] = "Khalim Eye"
			player_b_radar[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Вы видите противников на радаре", player_item_name[id])
		}
		case 70:
		{
			player_item_name[id] = "Leaper Ring"
			player_b_autobh[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Даёт вам авто распрыжку. Удерживает в пространстве.", player_item_name[id])
		}
		case 71:
		{
			player_item_name[id] = "Myrmidon Greaves"
			player_b_silent[id] = 1
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/2)
			show_hudmessage (id, "Вы нашли item : %s :: Бесшумный и быстрый бег",player_item_name[id],player_b_silent[id])
		}
		case 72:
		{
			player_item_name[id] = "Shoes of the Bone"
			player_b_jumpx[id] = 4
			set_user_gravity(id, 600.0)
			show_hudmessage (id, "Вы нашли item : %s :: Вы можете сделать 4 прыжка в воздухе. Уменьшенна гравитация",player_item_name[id],player_b_jumpx[id])
		}
		case 73:
		{
			player_item_name[id] = "Scarab Shoes"
			player_b_inv[id] = 95
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "Вы нашли item : %s :: Ваш видимость снижается до 95. Быстрый бег.",player_item_name[id],player_b_inv[id])
		}
		case 74:
		{
			player_item_name[id] = "Hydra Blade"
			player_b_inv[id] = 155
			player_b_damage[id] = 20
			show_hudmessage (id, "Вы нашли item : %s :: Ваш видимость снижается до 155 +20 к урону",player_item_name[id],player_b_inv[id],player_b_damage[id])
		}
		case 75:
		{
			player_item_name[id] = "Exp Ring"
			new xp_award = get_cvar_num("diablo_xpbonus")*2
			show_hudmessage (id, "Вы нашли item : %s :: Удваивание опыта на %i",player_item_name[id],xp_award)
		}
		case 76:
		{
			player_item_name[id] = "Aegis"
			player_ring[id]=2
			player_b_explode[id] = random_num(120,330)
			player_b_redirect[id] = random_num(10, 100)
			show_hudmessage (id, "Вы нашли item : %s :: Вы получаете +5 к силе и взрываетесь когда умираете(урон %i) -%i урона по вам",player_item_name[id],player_b_explode[id],player_b_redirect[id])
		}
		case 77:
		{
			player_item_name[id] = "Polished Wand"
			player_b_blind[id] = random_num(1,5)
			player_b_heal[id] =  random_num(1,15)
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/%i ослепить врага, жми E чтобы установить исцеляющий тотем",player_item_name[id],player_b_blind[id])
		}
		case 78:
		{
			player_item_name[id] = "Heavenly Stone"
			player_b_grenade[id] = random_num(1,3)
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить HE гранаты и быстрый бег",player_item_name[id],player_b_grenade[id])
		}
		case 79:
		{
			player_item_name[id] = "Festering Essence of Destruction"
			player_b_respawn[id] = 2
			player_b_sniper[id] = 1
			player_b_grenade[id] = 3
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/2 возродится, шанс 1/1 мгновенно убить со скаута,шанс 1/3 убить с HE",player_item_name[id])
		}
		case 80:
		{
			player_item_name[id] = "Vampire Gloves"
			player_b_vampire[id] = random_num(5,15)
			show_hudmessage(id, "Вы нашли item : %s :: Высасывает %i за каждое попадание во врага,за убийство +30hp",player_item_name[id],player_b_vampire[id])
		}
		case 81:
		{
			player_item_name[id] = "Super Mario"
			player_b_jumpx[id] = 10
			player_b_fireball[id] = 5
			show_hudmessage (id, "Вы нашли item : %s :: Вы можете сделать 10 прыжков в воздух и пускать до 5 ракет",player_item_name[id],player_b_jumpx[id], player_b_fireball[id])
		}
		case 85:
		{
			player_item_name[id] = "Centurion"
			player_b_damage[id] = 20
			player_b_redirect[id] = 40
			set_user_gravity(id,3.0)
			show_hudmessage (id, "Вы нашли item : %s :: +20 к урону и уменьшение урона на 40",player_item_name[id],player_b_damage[id],player_b_redirect[id])
		}
		case 86:
		{
			player_item_name[id] = "RedBull"
			player_b_jumpx[id] = 8
			show_hudmessage(id, "Вы нашли item : %s :: Вы можете сделать 8 прыжков в воздухе",player_item_name[id],player_b_sniper[id])	
		}
		case 87:
		{
			player_item_name[id] = "Dr House"
			player_b_heal[id] = random_num(45,65)
			show_hudmessage(id, "Вы нашли item : %s :: Восстанавливает %i hp каждые 5 секунд. Жмите Е чтобы установить лечящий тотем %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 88:
		{
			player_item_name[id] = "Own Invisible"
			player_b_inv[id] = 8
			player_b_reduceH[id] = 55
			if (is_user_alive(id)) set_user_health(id,45)
			show_hudmessage(id, "Вы нашли item : %s :: Вы почти невидимы,но у вас 45 HP.",player_item_name[id])	
		}
		case 89:
		{
			player_item_name[id] = "Mega Invisible"
			player_b_reduceH[id] = 90
			player_b_inv[id] = 1	
			item_durability[id] = 50
			
			if (is_user_alive(id)) set_user_health(id,10)		
			show_hudmessage(id, "Вы нашли item : %s :: У вас 10 жизней,невидимость 1/255",player_item_name[id])	
		}
		case 90:
		{
			player_item_name[id] = "Bul'Kathos Shoes"
			player_b_jumpx[id] = 8
			set_user_gravity(id, 400.0)
			show_hudmessage(id, "Вы нашли item : %s :: Вы можете сделать 8 прыжков в воздухе и у вас высокая гравитация",player_item_name[id],player_b_sniper[id])	
		}
		case 91:
		{
			player_item_name[id] = "Karik's Ring"
			player_b_redirect[id] = random_num(15,50)
			player_b_damage[id] = random_num(15,50)
			player_b_blind[id] = random_num(3,4)
			player_ultra_armor[id]=random_num(15,50)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage(id, "Вы нашли item : %s :: Item настолько мощный,что никто ещё не познал его волшебное действия",player_item_name[id])		
		}
		case 92:
		{
			player_item_name[id] = "Purse Thief"
			player_b_money[id] = random_num(1,16000)
			show_hudmessage(id, "Вы нашли item : %s :: получаете %i денег в каждом раунде. Используйте чтобы защищаться.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)
		}
		case 93:
		{
			player_item_name[id] = "Vampiric Blood"
			player_b_vampire[id] = random_num(15,20)
			show_hudmessage(id, "Вы нашли item : %s :: высасываете %i hp у противника",player_item_name[id],player_b_vampire[id])	
		}
		case 94:
		{
			player_item_name[id] = "Revival Ring"
			player_b_respawn[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: 1/%i шанс на возраждение",player_item_name[id],player_b_respawn[id])	
		}
		case 95:
		{
			player_item_name[id] = "Demon Assassin"
			player_b_heal[id] = random_num(30,55)
			player_b_damage[id] = 50
			show_hudmessage(id, "Вы нашли item : %s :: Восстанавливает %i hp каждые 5 секунд. Жмите Е чтобы установить лечащий тотем %i. +50 к урону",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 96:
		{
			player_item_name[id] = "Mystiqe"
			changeskin(id,0)
			player_b_grenade[id] = random_num(1,2)
			show_hudmessage (id, "Вы нашли item : %s :: Ты выглядишь как противник.Шанс 1/%i мгновенно убить с гранаты HE",player_item_name[id],player_b_grenade[id])
		}
		case 97:
		{
			player_item_name[id] = "Apocalypse Anihilation"
			player_b_damage[id] = 100
			player_b_silent[id] = 1
			item_durability[id] = 100
			show_hudmessage (id, "Вы нашли item : %s :: Вы на носите %i урона с каждого выстрела.Бесшумный бег.",player_item_name[id],player_b_damage[id],player_b_silent[id])
		}
		case 98:
		{
			player_item_name[id] = "Inferno"
			player_b_redirect[id] = 10
			player_b_damage[id] = 10
			player_b_respawn[id] = 2
			show_hudmessage (id, "Вы нашли item : %s :: +10 к урону. -10 урона по вам. Шанс 1/2 возродится.",player_item_name[id])
		}
		case 99:
		{
			player_item_name[id] = "Hellspawn"
			player_b_grenade[id] = 5
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "Вы нашли item : %s :: Шанс 1/5 убить с НЕ гранаты.+%i к невидимости",player_item_name[id],255-player_b_inv[id])
		}
		case 100:
		{
			player_item_name[id] = "Shako"
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "Вы нашли item : %s :: +25урона || +%i к невидимости",player_item_name[id],255-player_b_inv[id])
		}
		case 101:
		{
			player_item_name[id] = "Annihilus"
			player_b_damage[id] = 15
			player_b_vampire[id] = 50
			show_hudmessage (id, "Вы нашли item : %s :: +15 к урону. Высасывает 50hp с каждого выстрела",player_item_name[id])
		}
		case 102:
		{
			player_item_name[id] = "Blizzard's Mystery"
			player_b_damage[id] = 25
			player_b_vampire[id] = 25
			item_durability[id] = 100
			show_hudmessage (id, "Вы нашли item : %s :: +25 к урону. Высасывает 25 HP с каждого выстрела",player_item_name[id])
		}
		case 103:
		{
			player_item_name[id] = "Mara's Kaleidoscope"
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(190,200)
			show_hudmessage (id, "Вы нашли item : %s :: +25 к урону. +%i к невидимости",player_item_name[id],255-player_b_inv[id])
		}
		case 104:
		{
			player_item_name[id] = "M4A1 Special"
			item_durability[id] = 100
			player_b_m4master[id] = random_num(5,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с M4A1",player_item_name[id],player_b_m4master[id])
		}
		case 105:
		{
			player_item_name[id] = "AK47 Special"
			item_durability[id] = 100
			player_b_akmaster[id] = random_num(5,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с AK47",player_item_name[id],player_b_akmaster[id])
		}
		case 106:
		{
			player_item_name[id] = "AWP Special"
			item_durability[id] = 100
			player_b_awpmaster[id] = random_num(3,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с AWP",player_item_name[id],player_b_awpmaster[id])
		}
		case 107:
		{
			player_item_name[id] = "Deagle Special"
			item_durability[id] = 100
			player_b_dglmaster[id] = random_num(5,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с Deagle",player_item_name[id],player_b_dglmaster[id])
		}
		case 108:
		{
			player_item_name[id] = "M3 Special"
			item_durability[id] = 100
			player_b_m3master[id] = random_num(3,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с M3",player_item_name[id],player_b_m3master[id])
		}
		case 109:
		{
			player_item_name[id] = "Full Special"
			item_durability[id] = 100
			player_b_m3master[id] = random_num(3,8)
			player_b_dglmaster[id] = random_num(5,8)
			player_b_awpmaster[id] = random_num(3,8)
			player_b_akmaster[id] = random_num(5,8)
			player_b_m4master[id] = random_num(5,8)
			player_b_grenade[id] = random_num(3,8)
			player_b_sniper[id] = random_num(3,8)
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i мгновенно убить с M3,1/%i с Deagle,1/%i с AWP,1/%i с AK47,1/%i с M4A1,1/%i с HE,1/%i с скаута",player_item_name[id],player_b_m3master[id],player_b_dglmaster[id],player_b_awpmaster[id],player_b_akmaster[id],player_b_m4master[id],player_b_grenade[id],player_b_sniper[id])
		}
		case 110:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 111:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 112:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 113:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 114:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		
		case 115:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 116:
		{
			player_item_name[id] = "Diablo Shoes"
			player_b_antyarchy[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защитится от Arch angel", player_item_name[id], player_b_antyarchy[id])
		}
		case 117:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 118:
		{
			player_item_name[id] = "Anti Explosion"
			player_b_antyorb[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защитится от взрыва после убийства", player_item_name[id], player_b_antyorb[id])
		}
		case 119:
		{
			player_item_name[id] = "Anti HellFlare"
			player_b_antyfs[id] = 1
			show_hudmessage(id, "Вы нашли item : %s :: Шанс 1/%i защиты от огня", player_item_name[id], player_b_antyfs[id])
		}
		case 120:
		{
			player_item_name[id] = "Gheed's Fortune"
			player_b_godmode[id] = random_num(4,10)
			show_hudmessage(id, "Вы нашли item : %s :: Вы становитесь бесмертным на %i секунд.", player_item_name[id], player_b_godmode[id])
		}
		case 121:
		{
			player_item_name[id] = "Winter Totem"
			player_b_zamroztotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жмите Е чтобы установить замораживайщий тотем",player_item_name[id])	
		}
		case 122:
		{
			player_item_name[id] = "Cash Totem"
			player_b_kasatotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жми E чтобы установить тотем который даёт вам и вашей команде деньги.",player_item_name[id])	
		}
		case 123:
		{
			player_item_name[id] = "Thief Totem"
			player_b_kasaqtotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жми E чтобы установить тотем который отнимает деньги врага(500$ в сек)",player_item_name[id])	
		}
		case 124:
		{
			player_item_name[id] = "Weapon Totem"
			player_b_wywaltotem[id] = random_num(250,400)
			show_hudmessage(id, "Вы нашли item : %s :: Жми E чтобы установить тотем который притягивает оружие противника.",player_item_name[id])	
		}
		case 125:
		{
			player_item_name[id] = "Flash Totem"
			player_b_fleshujtotem[id] = random_num(250,400)
			show_hudmessage(id, "Жми E чтобы установить тотем который ослепляет противника.",player_item_name[id])	
		}

	}
	player_item_id[id] = item
	BoostRing(id)
}

public native_set_player_model(plugin_id, num_params)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
	{
		//log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", id)
		return false;
	}
	
	new newmodel[MODELNAME_MAXLENGTH]
	get_string(2, newmodel, charsmax(newmodel))
	
	remove_task(id+TASK_MODELCHANGE)
	flag_set(g_HasCustomModel, id)
	
	copy(g_CustomPlayerModel[id], charsmax(g_CustomPlayerModel[]), newmodel)
	
#if defined SET_MODELINDEX_OFFSET	
	new modelpath[32+(2*MODELNAME_MAXLENGTH)]
	formatex(modelpath, charsmax(modelpath), "models/player/%s/%s.mdl", newmodel, newmodel)
	g_CustomModelIndex[id] = engfunc(EngFunc_ModelIndex, modelpath)
#endif
	
	new currentmodel[MODELNAME_MAXLENGTH]
	fm_cs_get_user_model(id, currentmodel, charsmax(currentmodel))
	
	if (!equal(currentmodel, newmodel))
		fm_cs_user_model_update(id+TASK_MODELCHANGE)
	
	return true;
}

public native_reset_player_model(plugin_id, num_params)
{
	new id = get_param(1)
	
	if (!is_user_connected(id))
	{
		//log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", id)
		return false;
	}
	
	// Player doesn't have a custom model, no need to reset
	if (!flag_get(g_HasCustomModel, id))
		return true;
	
	remove_task(id+TASK_MODELCHANGE)
	flag_unset(g_HasCustomModel, id)
	fm_cs_reset_user_model(id)
	
	return true;
}

public FallenShaman(id)
{
	if(player_class[id] == Fallen && player_lvl[id] > 49)
	{    
  
		if(fallen_fires[id] == 0)
		{
			client_print(id, print_center, "У вас закончились шары!");
			return PLUGIN_CONTINUE;
		}	
		if(falen_fires_time[id] + 5.0 > get_gametime())
		{
			client_print(id, print_center, "Шары можно использовать каждые 5 секунд!");
			return PLUGIN_CONTINUE;
		}
		if(player_intelligence[id] < 1)
		{
				client_print(id, print_center, "Чтобы пускать шары необходим Интеллект!");
				return PLUGIN_CONTINUE;
		}
		
		if (is_user_alive(id))
		{	
				
			falen_fires_time[id] = get_gametime();
			fallen_fires[id]--;
			
			
			new Float:fOrigin[3],enOrigin[3]
			get_user_origin(id, enOrigin)
			new ent = create_entity("env_sprite")
	   
			IVecFVec(enOrigin, fOrigin)

	   
			entity_set_string(ent, EV_SZ_classname, "fallenball")
			entity_set_model(ent, "sprites/xfireball3.spr")
			entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
			entity_set_float(ent, EV_FL_framerate, 30.0)

			DispatchSpawn(ent)

			entity_set_origin(ent, fOrigin)
			entity_set_size(ent, Float:{-5.0, -5.0, -5.0}, Float:{5.0, 5.0, 5.0})
			entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
			entity_set_int(ent, EV_INT_movetype, 5)
			entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
			entity_set_float(ent, EV_FL_renderamt, 255.0)
			entity_set_float(ent, EV_FL_scale, 1.0)
			entity_set_edict(ent,EV_ENT_owner, id)
			//Send forward
			new Float:fl_iNewVelocity[3]
			VelocityByAim(id, 800, fl_iNewVelocity)
			entity_set_vector(ent, EV_VEC_velocity, fl_iNewVelocity)
			rndfsound = random(2);
			switch(rndfsound)
			{
				case 0: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_roar2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 1: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_roar3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 2: emit_sound(id,CHAN_STATIC, "diablo_lp/fallen_roar6.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			}
			emit_sound(ent, CHAN_VOICE, "diablo_lp/firelaunch2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	else
	{
		client_print(id, print_center, "Вы не Падший шаман!");
		return PLUGIN_CONTINUE;
	}	
	return PLUGIN_CONTINUE;
}

public DFallenShaman(ent)
{
	if ( !is_valid_ent(ent))
		return;

	new attacker = entity_get_edict(ent, EV_ENT_owner);

	new Float:fOrigin[3], iOrigin[3];
	entity_get_vector( ent, EV_VEC_origin, fOrigin);	
	iOrigin[0] = floatround(fOrigin[0]);
	iOrigin[1] = floatround(fOrigin[1]);
	iOrigin[2] = floatround(fOrigin[2]);

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY, iOrigin);
	write_byte(TE_EXPLOSION);
	write_coord(iOrigin[0]);
	write_coord(iOrigin[1]);
	write_coord(iOrigin[2]);
	write_short(sprite_blast);
	write_byte(32); // scale
	write_byte(20); // framerate
	write_byte(0);// flags
	message_end();

	new entlist[33];
	new numfound = find_sphere_class(ent, "player", 230.0, entlist, 32);
	
	for (new i=0; i < numfound; i++)
	{		
		new pid = entlist[i];
		
		if (!is_user_alive(pid) || get_user_team(attacker) == get_user_team(pid))
		{
			continue;
		}
		new plint = floatround(player_intelligence[attacker]/2.0,floatround_floor);
		new pldex = floatround(player_dextery[pid]/4.0,floatround_floor);
		new dmg = plint - pldex
		if(dmg <= 1) { dmg = 1; }
		{
			ExecuteHam(Ham_TakeDamage, pid, ent, attacker, dmg, 1);
		}
	}
	remove_entity(ent);
}
public frozen_key(id)
{
  
	if(frozen_colds[id] == 0)
	{
		client_print(id, print_center, "У вас закончился холод!");
		return PLUGIN_CONTINUE;
	}	
	if(player_intelligence[id] < 4)
	{
			client_print(id, print_center, "Необходимо 4 интеллекта!");
			return PLUGIN_CONTINUE;
	}
	
	if (is_user_alive(id))
	{	
			
		//falen_fires_time[id] = get_gametime();
		//fallen_fires[id]--;
		can_cast[id] = 0
		
		new Float:fOrigin[3],enOrigin[3]
		get_user_origin(id, enOrigin)
		new ent = create_entity("env_sprite")
   
		IVecFVec(enOrigin, fOrigin)

   
		entity_set_string(ent, EV_SZ_classname, "frozencold")
		entity_set_model(ent, "sprites/diablo_lp/cold_expo.spr")
		entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
		//entity_set_float(ent, EV_FL_animtime, 0.9)
		entity_set_float(ent, EV_FL_framerate, 12.0)

		DispatchSpawn(ent)

		entity_set_origin(ent, fOrigin)
		//entity_set_size(ent, Float:{-30.0, -30.0, -30.0}, Float:{30.0, 30.0, 30.0})
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
		entity_set_int(ent, EV_INT_movetype, 5)
		entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
		entity_set_float(ent, EV_FL_renderamt, 255.0)
		//entity_set_float(ent, EV_FL_scale, 1.5)
		new Float:frozenscale
		frozenscale = 0.3 + (player_intelligence[id] * 0.02)
		entity_set_float(ent, EV_FL_scale, frozenscale)
		entity_set_edict(ent,EV_ENT_owner, id)
		//Send forward
		new Float:fl_iNewVelocity[3]
		VelocityByAim(id, 1000, fl_iNewVelocity)
		entity_set_vector(ent, EV_VEC_velocity, fl_iNewVelocity)
		set_task(0.3, "removeEntity", ent, "", 0, "a", 1);
		set_task(0.15, "cancast", id, "", 0, "a", 1);
		emit_sound(id,CHAN_STATIC, "diablo_lp/frozne_blast.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
		frozen_colds[id]--
	}
	
	return PLUGIN_CONTINUE;
}

public imp_key(id)
{
  
	if(imp_fires[id] == 0)
	{
		client_print(id, print_center, "У вас закончился огонь!");
		return PLUGIN_CONTINUE;
	}	
	if(player_intelligence[id] < 4)
	{
			client_print(id, print_center, "Необходимо 4 интеллекта!");
			return PLUGIN_CONTINUE;
	}
	
	if (is_user_alive(id))
	{	
			
		//falen_fires_time[id] = get_gametime();
		//fallen_fires[id]--;
		can_cast[id] = 0
		
		new Float:fOrigin[3],enOrigin[3]
		get_user_origin(id, enOrigin)
		new ent = create_entity("env_sprite")
   
		IVecFVec(enOrigin, fOrigin)

   
		entity_set_string(ent, EV_SZ_classname, "impfires")
		entity_set_model(ent, "sprites/explode1.spr")
		entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
		entity_set_float(ent, EV_FL_animtime, 1.0)
		entity_set_float(ent, EV_FL_frame, 2.0)
		entity_set_float(ent, EV_FL_framerate, 9.0)

		DispatchSpawn(ent)

		entity_set_origin(ent, fOrigin)
		entity_set_size(ent, Float:{-30.0, -30.0, -30.0}, Float:{30.0, 30.0, 30.0})
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP)
		entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
		entity_set_float(ent, EV_FL_renderamt, 255.0)
		//entity_set_float(ent, EV_FL_scale, 1.5)
		//new Float:impscale
		//impscale = 0.3 + (player_intelligence[id] * 0.02)
		//entity_set_float(ent, EV_FL_scale, 1.1)
		entity_set_edict(ent,EV_ENT_owner, id)
		//Send forward
		new Float:fl_iNewVelocity[3]
		VelocityByAim(id, 800, fl_iNewVelocity)
		entity_set_vector(ent, EV_VEC_velocity, fl_iNewVelocity)
		set_task(0.4, "removeEntity", ent, "", 0, "a", 1);
		set_task(0.15, "cancast", id, "", 0, "a", 1);
		emit_sound(id, CHAN_WEAPON, "ambience/flameburst1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		imp_fires[id]--
	}
	
	return PLUGIN_CONTINUE;
}

public diablo_lght(id)
{
	if(player_intelligence[id] < 1)
	{
		client_print(id, print_center, "Необходим интеллект!");
		return PLUGIN_CONTINUE;
	}
	if(diablo_lights[id] < 1)
	{
		client_print(id, print_center, "У вас нет молний!");
		return PLUGIN_CONTINUE;
	}
	
	if (is_user_alive(id))
	{
		can_cast[id] = 0
		new players[32], numberofplayers, origin[3];
		get_user_origin( id, origin );
		get_players( players, numberofplayers, "h" );
		
		new i, iTargetID, vTargetOrigin[3], iDistance, dmg;
		new iTeam = get_user_team( id );
		
		new br_range = 600
		new targets
		
		for ( i = 0; i < numberofplayers; i++ )
		{
		
			iTargetID = players[i];
			
			// Get origin of target
			get_user_origin( iTargetID, vTargetOrigin );

			// Get distance in b/t target and caster
			iDistance = get_distance( origin, vTargetOrigin );
			
			dmg = float((player_intelligence[id] - player_dextery[iTargetID])/2);
			
			if ( iDistance < br_range && iTeam != get_user_team( iTargetID ) && dmg > 0 && is_user_alive(iTargetID))
			{
				puscBlyskawice(id, iTargetID, dmg);
				targets++
			}
		}
		if(targets > 0 )
		{
			diablo_lights[id]--
		}
		else
		{
			client_print(id, print_center, "Нет целей в радиусе действия!");
		}
		set_task(0.15, "cancast", id, "", 0, "a", 1);
	}
	
	return PLUGIN_CONTINUE;
}

public cancast(id)
{
	can_cast[id] = 1
}

public cmd_place_portal(id){
	if (player_portal[id] == 0)
	{
		client_print(id, print_center, "У вас нет Портала!");
		return PLUGIN_CONTINUE;
	}
	new cmd_place_portal=menu_create("Меню Портала","cmd_place_portal2");
	
	menu_additem(cmd_place_portal,"\yУстановить портал");
	menu_additem(cmd_place_portal,"\wУдалить все порталы");
	menu_setprop(cmd_place_portal,MPROP_EXITNAME,"Выход")
	
	menu_display(id, cmd_place_portal,0);
	return PLUGIN_HANDLED;
}
public cmd_place_portal2(id, menu, item){
	switch(item){
		case 0:
		{
			if (player_portals[id] == 2)
			{
				client_print(id, print_center, "Вы уже установили все порталы!");
				return PLUGIN_CONTINUE;
			}
			set_portal(id)
			
			if (player_portals[id] == 1)
			{
				cmd_place_portal(id)
			}
		}
		case 1:
		{
			if(player_portals[id] > 0)
			{
				remove_entity(player_portal_infotrg_1[id]);
				remove_entity(player_portal_sprite_1[id]);
				player_portal_infotrg_1[id] = 0
				player_portal_sprite_1[id] = 0
				remove_entity(player_portal_infotrg_2[id]);
				remove_entity(player_portal_sprite_2[id]);
				player_portal_infotrg_2[id] = 0
				player_portal_sprite_2[id] = 0
				player_portals[id] = 0
				player_portal[id] = 0
			}
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
stock fm_get_aim_origin_normal(index, Float:origin[3], Float:normal[3])
{
	static Float:start[3], Float:view_ofs[3]
	pev(index, pev_origin, start)
	pev(index, pev_view_ofs, view_ofs)
	xs_vec_add(start, view_ofs, start)
	
	static Float:dest[3]
	pev(index, pev_v_angle, dest)
	engfunc(EngFunc_MakeVectors, dest)
	global_get(glb_v_forward, dest)
	xs_vec_mul_scalar(dest, 9999.0, dest)
	xs_vec_add(start, dest, dest)
	
	static tr, Float:dist
	tr = create_tr2()
	engfunc(EngFunc_TraceLine, start, dest, DONT_IGNORE_MONSTERS, index, tr)
	get_tr2(tr, TR_vecEndPos, origin)
	dist = get_distance_f(start, origin)
	origin[0] -= (origin[0] - start[0])/dist
	origin[1] -= (origin[1] - start[1])/dist
	origin[2] -= (origin[2] - start[2])/dist
	get_tr2(tr, TR_vecPlaneNormal, normal)
	free_tr2(tr)
}
public set_portal(id)
{
	new g_ent,g_ent2
	new Float:g_aim_origin[3]
	new Float:g_ent_angles[3]
	
	set_pev(g_ent, pev_scale, 1.0 )
	g_ent = create_entity("info_target")
	g_ent2 = create_entity("env_sprite")
	entity_set_string(g_ent, EV_SZ_classname, "iportal")
	engfunc(EngFunc_SetModel, g_ent, "models/portal/portal.mdl")
	entity_set_string(g_ent2, EV_SZ_classname, "2iportal")
	if(get_user_team(id) == 1)
	{
		engfunc(EngFunc_SetModel, g_ent2, "sprites/diablo_lp/portal_tt.spr")
	}
	else if(get_user_team(id) == 2)
	{
		engfunc(EngFunc_SetModel, g_ent2, "sprites/diablo_lp/portal_ct.spr")
	}
	else
	{
		remove_entity(g_ent);
		remove_entity(g_ent2);
		client_print(id, print_center, "ОШИБКА: Поставьте портал на ровной стене!^n Или порталу не хватает свободного места");
		cmd_place_portal(id)
		return PLUGIN_CONTINUE;
	}
	set_pev(g_ent,pev_solid,SOLID_TRIGGER)
	set_pev(g_ent,pev_movetype,MOVETYPE_FLY)
	set_pev(g_ent,pev_skin,1)
	
	static Float:normal[3]
	fm_get_aim_origin_normal(id, g_aim_origin, normal)
	normal[0] *= -1.0
	normal[1] *= -1.0
	normal[2] *= -1.0
	vector_to_angle(normal, g_ent_angles)
	
	if(!validWall(g_aim_origin,g_ent_angles) || !checkPlace(g_aim_origin,id))
	{	
		remove_entity(g_ent);
		remove_entity(g_ent2);
		client_print(id, print_center, "ОШИБКА: Поставьте портал на ровной стене!^n Или порталу не хватает свободного места");
		cmd_place_portal(id)
		return PLUGIN_CONTINUE;
	}
	
	player_portals[id]++
	
	if(player_portals[id] == 1)
	{
		player_portal_infotrg_1[id] = g_ent;
		player_portal_sprite_1[id] = g_ent2;
	}
	if(player_portals[id] == 2)
	{
		player_portal_infotrg_2[id] = g_ent;
		player_portal_sprite_2[id] = g_ent2;
	}
	engfunc(EngFunc_SetOrigin, g_ent, g_aim_origin)
	set_pev(g_ent, pev_angles, g_ent_angles)
	engfunc(EngFunc_SetOrigin, g_ent2, g_aim_origin)
	set_pev(g_ent2, pev_angles, g_ent_angles)
	set_rendering(g_ent, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 0 )
	set_pev(g_ent2, pev_rendermode, kRenderTransAdd)
	set_pev(g_ent2, pev_renderamt, 220.0)
	set_pev(g_ent2, pev_framerate, 15.0 )
	set_pev(g_ent2, pev_spawnflags, SF_SPRITE_STARTON)
	DispatchSpawn(g_ent2)
	set_pev(g_ent2, pev_angles, g_ent_angles)
	entity_set_edict(g_ent,EV_ENT_owner, id)
	entity_set_edict(g_ent2,EV_ENT_owner, id)
	entity_set_string(g_ent, EV_SZ_classname, "iportal")
	set_pev(g_ent,pev_owner,id);
	set_pev(g_ent2,pev_owner,id);
	
	new Float:fOldNormal[3];
	xs_vec_copy(g_ent_angles, fOldNormal);
	vector_to_angle(g_ent_angles, g_ent_angles);
	set_pev(g_ent2, pev_vuser1, fOldNormal);
	emit_sound(g_ent, CHAN_VOICE, "diablo_lp/portalcast.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	new Float:fMins[3],Float:fMaxs[3];
	pev(g_ent, pev_mins, fMins)
	pev(g_ent, pev_maxs, fMaxs)
	fMins[0] = fMins[0] + 0.15;
	fMins[1] = fMins[1] + 0.15;
	fMins[2] = fMins[2] + 0.15;
	
	fMaxs[0] = fMaxs[0] + 0.15;
	fMaxs[1] = fMaxs[1] + 0.15;
	fMaxs[2] = fMaxs[2] + 0.15;
	engfunc(EngFunc_SetSize, g_ent,fMins, fMaxs)
	
	
	return PLUGIN_CONTINUE;
}

parseAngle(id, in, out)
{
		new Float:fAngles[3];
		pev(id, pev_v_angle, fAngles);
		angle_vector(fAngles, ANGLEVECTOR_FORWARD, fAngles);
		
		new Float:fNormalIn[3];
		pev(in, pev_vuser1, fNormalIn);
		xs_vec_neg(fNormalIn, fNormalIn);
		
		new Float:fNormalOut[3];
		pev(out, pev_vuser1, fNormalOut);
		
		xs_vec_sub(fAngles, fNormalIn, fAngles);
		xs_vec_add(fAngles, fNormalOut, fAngles);
		
		//fAngles[2] = -fAngles[2];
		
		vector_to_angle(fAngles, fAngles);
		
		set_pev(id, pev_angles, fAngles);
		set_pev(id, pev_fixangle, 1);
		
		
		pev(id, pev_velocity, fAngles);
		new Float:fSpeed = vector_length(fAngles);
		xs_vec_normalize(fAngles,  fAngles);
		
		xs_vec_sub(fAngles, fNormalIn, fAngles);
		xs_vec_add(fAngles, fNormalOut, fAngles);
		
		xs_vec_normalize(fAngles, fAngles);
		xs_vec_mul_scalar(fAngles, fSpeed, fAngles);
		set_pev(id, pev_velocity, fAngles);
}

public StworzRakiete(id)
{
	if (!ilosc_rakiet_gracza[id] && is_user_alive(id))
	{
		client_print(id, print_center, "У вас закончились ракеты!");
		return PLUGIN_CONTINUE;
	}
	
	if(poprzednia_rakieta_gracza[id] + 3.0 > get_gametime())
	{
		client_print(id, print_center, "Ракеты можно использовать каждые 3 секунды!");
		return PLUGIN_CONTINUE;
	}
	if(player_intelligence[id] < 1)
	{
		client_print(id, print_center, "Чтобы пускать ракеты необходим Интеллект!");
		return PLUGIN_CONTINUE;
	}
	
	if (is_user_alive(id))
	{	
			
		poprzednia_rakieta_gracza[id] = get_gametime();
		ilosc_rakiet_gracza[id]--;

		new Float: Origin[3], Float: vAngle[3], Float: Velocity[3];
		
		entity_get_vector(id, EV_VEC_v_angle, vAngle);
		entity_get_vector(id, EV_VEC_origin , Origin);
	
		new Ent = create_entity("info_target");
	
		entity_set_string(Ent, EV_SZ_classname, "Rocket");
		entity_set_model(Ent, "models/rpgrocket.mdl");
	
		vAngle[0] *= -1.0;
	
		entity_set_origin(Ent, Origin);
		entity_set_vector(Ent, EV_VEC_angles, vAngle);
	
		entity_set_int(Ent, EV_INT_effects, 2);
		entity_set_int(Ent, EV_INT_solid, SOLID_BBOX);
		entity_set_int(Ent, EV_INT_movetype, MOVETYPE_FLY);
		entity_set_edict(Ent, EV_ENT_owner, id);
	
		VelocityByAim(id, 1000 , Velocity);
		entity_set_vector(Ent, EV_VEC_velocity ,Velocity);
	}	
	return PLUGIN_CONTINUE;
}
public DotykRakiety(ent)
{
	if ( !is_valid_ent(ent))
		return;

	new attacker = entity_get_edict(ent, EV_ENT_owner);

	new Float:fOrigin[3], iOrigin[3];
	entity_get_vector( ent, EV_VEC_origin, fOrigin);	
	iOrigin[0] = floatround(fOrigin[0]);
	iOrigin[1] = floatround(fOrigin[1]);
	iOrigin[2] = floatround(fOrigin[2]);

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY, iOrigin);
	write_byte(TE_EXPLOSION);
	write_coord(iOrigin[0]);
	write_coord(iOrigin[1]);
	write_coord(iOrigin[2]);
	write_short(sprite_blast);
	write_byte(32); // scale
	write_byte(20); // framerate
	write_byte(0);// flags
	message_end();

	new entlist[33];
	new numfound = find_sphere_class(ent, "player", 230.0, entlist, 32);
	
	for (new i=0; i < numfound; i++)
	{		
		new pid = entlist[i];
		
		if (!is_user_alive(pid) || get_user_team(attacker) == get_user_team(pid))
		{
			continue;
		}
		new plint = floatround(player_intelligence[attacker]/2.0,floatround_floor);
		new pldex = floatround(player_dextery[pid]/4.0,floatround_floor);
		new dmg = plint - pldex
		if(dmg <= 1) { dmg = 1; }
		ExecuteHam(Ham_TakeDamage, pid, ent, attacker, dmg, 1);
	}
	remove_entity(ent);
}
/*public PolozDynamit(id)
{
	if(!ilosc_dynamitow_gracza[id] && is_user_alive(id))
	{
		client_print(id, print_center, "Wykorzystales juz caly dynamit!");
		return PLUGIN_CONTINUE;
	}
	
	if(player_intelligence[id] < 49)
		client_print(id, print_center, "Aby wzmocnic dynamit, zwieksz inteligencje!");
	
	ilosc_dynamitow_gracza[id]--;
	new Float:fOrigin[3], iOrigin[3];
	entity_get_vector( id, EV_VEC_origin, fOrigin);
	iOrigin[0] = floatround(fOrigin[0]);
	iOrigin[1] = floatround(fOrigin[1]);
	iOrigin[2] = floatround(fOrigin[2]);

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY, iOrigin);
	write_byte(TE_EXPLOSION);
	write_coord(iOrigin[0]);
	write_coord(iOrigin[1]);
	write_coord(iOrigin[2]);
	write_short(sprite_blast);
	write_byte(32);
	write_byte(20);
	write_byte(0);
	message_end();
	
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, iOrigin );
	write_byte( TE_BEAMCYLINDER );
	write_coord( iOrigin[0] );
	write_coord( iOrigin[1] );
	write_coord( iOrigin[2] );
	write_coord( iOrigin[0] );
	write_coord( iOrigin[1] + 300 );
	write_coord( iOrigin[2] + 300 );
	write_short( sprite_white );
	write_byte( 0 ); // startframe
	write_byte( 0 ); // framerate
	write_byte( 10 ); // life
	write_byte( 10 ); // width
	write_byte( 255 ); // noise
	write_byte( 255 ); // r, g, b
	write_byte( 100 );// r, g, b
	write_byte( 100 ); // r, g, b
	write_byte( 128 ); // brightness
	write_byte( 8 ); // speed
	message_end();

	new entlist[33];
	new numfound = find_sphere_class(id, "player", 300.0 , entlist, 32);
	
	for (new i=0; i < numfound; i++)
	{		
		new pid = entlist[i];
		
		if (!is_user_alive(pid) || get_user_team(id) == get_user_team(pid))
			continue;
		ExecuteHam(Ham_TakeDamage, pid, 0, id, 60.0+float(player_intelligence[id]/2) , 1);
	}
	return PLUGIN_CONTINUE;
}*/
public wallclimb(id, button)
{
        static Float:origin[3]
        pev(id, pev_origin, origin)

        if(get_distance_f(origin, g_wallorigin[id]) > 25.0)
                return FMRES_IGNORED  // if not near wall
        
        if(fm_get_entity_flags(id) & FL_ONGROUND)
                return FMRES_IGNORED
                
        if(button & IN_FORWARD)
        {
			static Float:velocity[3]
			velocity_by_aim(id, 120, velocity)
			fm_set_user_velocity(id, velocity)
        }
        else if(button & IN_BACK)
        {
			static Float:velocity[3]
			velocity_by_aim(id, -120, velocity)
			fm_set_user_velocity(id, velocity)
        }
        return FMRES_IGNORED
}
public make_hook(id)
{
	if(spider_hook_disabled[id] == 1)
	{
		client_print(id, print_center, "[Паутина] Вы получили урон, паутина отключена на 5 секунд")
		return PLUGIN_HANDLED
	}
	if (player_class[id] == GiantSpider && is_user_alive(id) || (player_class[id] == Griswold && is_user_alive(id)))
	{
	if (get_pcvar_num(pHook) && is_user_alive(id) && canThrowHook[id] && !gHooked[id]) {		
		if (get_pcvar_num(pAdmin))
		{
			// Only the admins can throw the hook
			// if(is_user_admin(id)) { <- does not work...		
			if (!(get_user_flags(id) & ADMIN_IMMUNITY) && !g_bHookAllowed[id])
			{
				// Show a message
				client_print(id, print_chat, "[Hook] %L",id,"NO_ACC_COM")
				console_print(id, "[Hook] %L",id,"NO_ACC_COM")
				
				return PLUGIN_HANDLED
			}
		}
		
		new iMaxHooks = get_pcvar_num(pMaxHooks)
		if (iMaxHooks > 0)
		{
			if (gHooksUsed[id] >= iMaxHooks)
			{
				client_print(id, print_chat, "[Паутина] У вас закончилась паутина.")
				statusMsg(id, "[Паутина] %d из %d паутин.", gHooksUsed[id], get_pcvar_num(pMaxHooks))
				
				return PLUGIN_HANDLED
			}
			else 
			{
				gHooksUsed[id]++
				statusMsg(id, "[Паутина] %d из %d паутин", gHooksUsed[id], get_pcvar_num(pMaxHooks))
			}
		}
		new Float:fDelay = get_pcvar_float(pRndStartDelay)
		if (fDelay > 0 && !rndStarted)
			client_print(id, print_chat, "[Паутина] Вы не можете использовать паутину подождите %0.0f секунд или раунд закончился", fDelay)
			
		throw_hook(id)
		}
	}
	return PLUGIN_HANDLED
}

public del_hook(id)
{
	if (player_class[id] == GiantSpider && is_user_alive(id) || (player_class[id] == Griswold && is_user_alive(id)))
	{
	// Remove players hook
	if (!canThrowHook[id])
		remove_hook(id)
	}
	return PLUGIN_HANDLED
}
public round_bstart()
{
	// Round is not started anymore
	if (rndStarted)
		rndStarted = false
	
	// Remove all hooks
	for (new i = 1; i <= gMaxPlayers; i++)
	{
		if (is_user_connected(i))
		{
			if(!canThrowHook[i])
				remove_hook(i)
		}
	}
}

public round_estart()
{
	new Float:fDelay = get_pcvar_float(pRndStartDelay)
	if (fDelay > 0.0)
		set_task(fDelay, "rndStartDelay")
	else
	{
		// Round is started...
		if (!rndStarted)
			rndStarted = true
	}
}

public rndStartDelay()
{
	if (!rndStarted)
		rndStarted = true
}
public Restart()
{
	for (new id = 0; id < gMaxPlayers; id++)
	{
		if (is_user_connected(id))
			gRestart[id] = true
	}
}

public portal_touch(ptr,id)
{
	if(is_user_alive(id))
	{
	static szClassName[32]
	pev(ptr, pev_classname, szClassName, sizeof szClassName - 1)
	
	if(!equal(szClassName, "iportal"))
	{
		return FMRES_IGNORED
	}
	
	if(player_portals[id] < 2)
	{
		return PLUGIN_CONTINUE;
	}
    
        if(player_portal_infotrg_1[id] == ptr)
        {
			static Float:fOrigin[3],Float:flAng[3];
			static Float:fDistance = 0.1;
			static entity;
			
			entity = player_portal_sprite_2[id]
			pev(entity, pev_origin, fOrigin);
			pev(entity, pev_angles, flAng)      
			
			
			static Float:fAngles[3];
			pev(entity, pev_vuser1, fAngles);
			xs_vec_mul_scalar(fAngles, fDistance, fAngles);
			xs_vec_add(fOrigin, fAngles, fOrigin);
			static Float:fMins[3],Float:fMaxs[3];
			pev(id,pev_mins,fMins);
			pev(id,pev_maxs,fMaxs);
			if(checkPortalPlace(fOrigin,fMins,fMaxs))
			{
				set_pev(id, pev_origin, fOrigin);
				parseAngle(id, player_portal_infotrg_1[id], entity);
				emit_sound(entity, CHAN_VOICE, "diablo_lp/portalenter.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
		}        
        if(player_portal_infotrg_2[id] == ptr)
        {
        
			static Float:fOrigin[3],Float:flAng[3];
			static Float:fDistance = 0.1;
			static entity;
			
			entity = player_portal_sprite_1[id]
			pev(entity, pev_origin, fOrigin);
			pev(entity, pev_angles, flAng)
			//set_pev(id, pev_angles, flAng)
			
			static Float:fAngles[3];
			pev(entity, pev_vuser1, fAngles);
			xs_vec_mul_scalar(fAngles, fDistance, fAngles);
			xs_vec_add(fOrigin, fAngles, fOrigin);
			//set_pev(id, pev_origin, fOrigin);
			static Float:fMins[3],Float:fMaxs[3];
			pev(id,pev_mins,fMins);
			pev(id,pev_maxs,fMaxs);
			if(checkPortalPlace(fOrigin,fMins,fMaxs))
			{
				set_pev(id, pev_origin, fOrigin);
				parseAngle(id, player_portal_infotrg_2[id], entity);
				emit_sound(entity, CHAN_VOICE, "diablo_lp/portalenter.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
		}
	}
	return PLUGIN_HANDLED
}

bool:traceToWall(const Float:fOrigin[3], const Float:fVec[3]){
		new Float:fOrigin2[3];
		xs_vec_add(fOrigin, fVec, fOrigin2);
		xs_vec_add(fOrigin2, fVec, fOrigin2);
		
		new tr = create_tr2();
		engfunc(EngFunc_TraceLine, fOrigin, fOrigin2, IGNORE_MISSILE | IGNORE_MONSTERS | IGNORE_GLASS, 0, tr);
		new Float:fFrac;
		get_tr2(tr, TR_flFraction, fFrac);
		free_tr2(tr);
		
		if( floatabs(fFrac - 0.5) <= 0.02 ){
			return true;
		}
		
		return false;
	}

stock bool:validWall(const Float:fOrigin[3], Float:fNormal[3], Float:width=56.0, Float:height = 84.0)
{
		new Float:fInvNormal[3];
		xs_vec_neg(fNormal, fInvNormal);
		
		new Float:fPoint[3];
		xs_vec_add(fOrigin, fNormal, fPoint);
		
		new Float:fNormalUp[3];
		new Float:fNormalRight[3];
		vector_to_angle(fNormal, fNormalUp);
		
		fNormalUp[0] = -fNormalUp[0];
		
		angle_vector(fNormalUp, ANGLEVECTOR_RIGHT, fNormalRight);
		angle_vector(fNormalUp, ANGLEVECTOR_UP, fNormalUp);
		
		xs_vec_mul_scalar(fNormalUp, height/2, fNormalUp);
		xs_vec_mul_scalar(fNormalRight, width/2, fNormalRight);
		
		new Float:fPoint2[3];
		xs_vec_add(fPoint, fNormalUp, fPoint2);
		xs_vec_add(fPoint2, fNormalRight, fPoint2);
		if(!traceToWall(fPoint2, fInvNormal))
		return false;
		
		xs_vec_add(fPoint, fNormalUp, fPoint2);
		xs_vec_sub(fPoint2, fNormalRight, fPoint2);
		if(!traceToWall(fPoint2, fInvNormal))
		return false;
		
		xs_vec_sub(fPoint, fNormalUp, fPoint2);
		xs_vec_sub(fPoint2, fNormalRight, fPoint2);
		if(!traceToWall(fPoint2, fInvNormal))
		return false;
		
		xs_vec_sub(fPoint, fNormalUp, fPoint2);
		xs_vec_add(fPoint2, fNormalRight, fPoint2);
		if(!traceToWall(fPoint2, fInvNormal))
		return false;
		
		return true;
}

bool:checkPlace(Float:fOrigin[3],id){
		new ent = -1;
		new szClass[64]
		while((ent = find_ent_in_sphere(ent,fOrigin,45.0)))
		{
			pev(ent,pev_classname,szClass,charsmax(szClass));
			if(equal(szClass,"iportal") || equal(szClass,"iportal"))
			{
				if(equal(szClass,"iportal") && pev(ent,pev_owner) == id)
				{
					continue;
				}
				else
				{
					return false;
				}
			}
		}
		return true;
	}

bool:traceTo(const Float:fFrom[3],const Float:fTo[3])
{
	new tr = create_tr2();
		
	engfunc(EngFunc_TraceLine, fFrom, fTo,0, 0, tr);
		
	new Float:fFrac;
	get_tr2(tr, TR_flFraction, fFrac);
	free_tr2(tr);
		
	return (fFrac == 1.0) 
		
}

bool:checkPortalPlace(Float: fOrigin[3],Float: fMins[3],Float: fMaxs[3])
	{
		new Float:fOriginTmp[3]
		
		xs_vec_copy(fOrigin,fOriginTmp)
		
		
		fOriginTmp[0] += fMins[0];
		fOriginTmp[1] += fMaxs[1];
		fOriginTmp[2] += fMaxs[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		
		fOriginTmp[0] += fMaxs[0];
		fOriginTmp[1] += fMaxs[1];
		fOriginTmp[2] += fMaxs[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		
		fOriginTmp[0] += fMins[0];
		fOriginTmp[1] += fMins[1];
		fOriginTmp[2] += fMaxs[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		fOriginTmp[0] += fMaxs[0];
		fOriginTmp[1] += fMins[1];
		fOriginTmp[2] += fMaxs[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		fOriginTmp[0] += fMins[0];
		fOriginTmp[1] += fMaxs[1];
		fOriginTmp[2] += fMins[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		fOriginTmp[0] += fMaxs[0];
		fOriginTmp[1] += fMaxs[1];
		fOriginTmp[2] += fMins[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		fOriginTmp[0] += fMins[0];
		fOriginTmp[1] += fMins[1];
		fOriginTmp[2] += fMins[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		fOriginTmp[0] += fMaxs[0];
		fOriginTmp[1] += fMins[1];
		fOriginTmp[2] += fMins[2];
		if(!traceTo(fOrigin,fOriginTmp)){
			return false;
		}
		xs_vec_copy(fOrigin,fOriginTmp)
		
		return true;
	}

public fwTouch(ptr, ptd)
{
	if (!pev_valid(ptr))
		return FMRES_IGNORED
	
	new id = pev(ptr, pev_owner)
	
	// Get classname
	static szPtrClass[32]	
	pev(ptr, pev_classname, szPtrClass, charsmax(szPtrClass))
	
	if (equali(szPtrClass, "Hook"))
	{		
		static Float:fOrigin[3]
		pev(ptr, pev_origin, fOrigin)
		
		if (pev_valid(ptd))
		{
			static szPtdClass[32]
			pev(ptd, pev_classname, szPtdClass, charsmax(szPtdClass))
						
			if (!get_pcvar_num(pPlayers) && /*equali(szPtdClass, "player")*/ is_user_alive(ptd))
			{
				// Hit a player
				if (get_pcvar_num(pSound))
				{
					emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hitbod1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
				}
				remove_hook(id)
				
				return FMRES_HANDLED
			}
			else if (equali(szPtdClass, "hostage_entity"))
			{
				// Makes an hostage follow
				if (get_pcvar_num(pHostage) && get_user_team(id) == 2)
				{					
					//cs_set_hostage_foll(ptd, (cs_get_hostage_foll(ptd) == id) ? 0 : id)
					// With the use function we have the sounds!
					dllfunc(DLLFunc_Use, ptd, id)
				}
				if (!get_pcvar_num(pPlayers))
				{
					if(get_pcvar_num(pSound))
					{
						emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hitbod1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
					}
					remove_hook(id)
				}
				return FMRES_HANDLED
			}
			else if (get_pcvar_num(pOpenDoors) && equali(szPtdClass, "func_door") || equali(szPtdClass, "func_door_rotating"))
			{
				// Open doors
				// Double doors tested in de_nuke and de_wallmart
				static szTargetName[32]
				pev(ptd, pev_targetname, szTargetName, charsmax(szTargetName))
				if (strlen(szTargetName) > 0)
				{	
					static ent
					while ((ent = engfunc(EngFunc_FindEntityByString, ent, "target", szTargetName)) > 0)
					{
						static szEntClass[32]
						pev(ent, pev_classname, szEntClass, charsmax(szEntClass))
						
						if (equali(szEntClass, "trigger_multiple"))
						{
							dllfunc(DLLFunc_Touch, ent, id)
							goto stopdoors // No need to touch anymore
						}
					}
				}
				
				// No double doors.. just touch it
				dllfunc(DLLFunc_Touch, ptd, id)
				stopdoors:				
			}
			else if (get_pcvar_num(pUseButtons) && equali(szPtdClass, "func_button"))
			{
				if (pev(ptd, pev_spawnflags) & SF_BUTTON_TOUCH_ONLY)
					dllfunc(DLLFunc_Touch, ptd, id) // Touch only
				else			
					dllfunc(DLLFunc_Use, ptd, id) // Use Buttons			
			}
		}
		
		// If cvar sv_hooksky is 0 and hook is in the sky remove it!
		new iContents = engfunc(EngFunc_PointContents, fOrigin)
		if (!get_pcvar_num(pHookSky) && iContents == CONTENTS_SKY)
		{
			if(get_pcvar_num(pSound))
			{
				emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
			remove_hook(id)
			return FMRES_HANDLED
		}
		
		// Pick up weapons..
		if (get_pcvar_num(pWeapons))
		{
			static ent
			while ((ent = engfunc(EngFunc_FindEntityInSphere, ent, fOrigin, 15.0)) > 0)
			{
				static szentClass[32]
				pev(ent, pev_classname, szentClass, charsmax(szentClass))
				
				if (equali(szentClass, "weaponbox") || equali(szentClass, "armoury_entity"))
					dllfunc(DLLFunc_Touch, ent, id)
			}
		}
		
		// Player is now hooked
		gHooked[id] = true
		// Play sound
		if (get_pcvar_num(pSound))
		{
			emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
		
		// Make some sparks :D
		message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY, fOrigin, 0)
		write_byte(9) // TE_SPARKS
		write_coord_f(fOrigin[0]) // Origin
		write_coord_f(fOrigin[1])
		write_coord_f(fOrigin[2])
		message_end()		
		
		// Stop the hook from moving
		set_pev(ptr, pev_velocity, Float:{0.0, 0.0, 0.0})
		set_pev(ptr, pev_movetype, MOVETYPE_NONE)
		
		//Task
		if (!task_exists(id + 856))
		{ 
			static TaskData[2]
			TaskData[0] = id
			TaskData[1] = ptr
			gotohook(TaskData)
			
			set_task(0.1, "gotohook", id + 856, TaskData, 2, "b")
		}
	}
	return FMRES_HANDLED
}

public hookthink(param[])
{
	new id = param[0]
	new HookEnt = param[1]
	
	if (!is_user_alive(id) || !pev_valid(HookEnt) || !pev_valid(id))
	{
		remove_task(id + 890)
		return PLUGIN_HANDLED
	}
	
	
	static Float:entOrigin[3]
	pev(HookEnt, pev_origin, entOrigin)
	
	// If user is behind a box or something.. remove it
	// only works if sv_interrupt 1 or higher is
	if (get_pcvar_num(pInterrupt) && rndStarted)
	{
		static Float:usrOrigin[3]
		pev(id, pev_origin, usrOrigin)
		
		static tr
		engfunc(EngFunc_TraceLine, usrOrigin, entOrigin, 1, -1, tr)
		
		static Float:fFraction
		get_tr2(tr, TR_flFraction, fFraction)
		
		if (fFraction != 1.0)
			remove_hook(id)
	}
	
	// If cvar sv_hooksky is 0 and hook is in the sky remove it!
	new iContents = engfunc(EngFunc_PointContents, entOrigin)
	if (!get_pcvar_num(pHookSky) && iContents == CONTENTS_SKY)
	{
		if(get_pcvar_num(pSound))
			emit_sound(HookEnt, CHAN_STATIC, "weapons/xbow_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		remove_hook(id)
	}
	
	return PLUGIN_HANDLED
}

public gotohook(param[])
{
	new id = param[0]
	new HookEnt = param[1]

	if (!is_user_alive(id) || !pev_valid(HookEnt) || !pev_valid(id))
	{
		remove_task(id + 856)
		return PLUGIN_HANDLED
	}
	// If the round isnt started velocity is just 0
	static Float:fVelocity[3]
	fVelocity = Float:{0.0, 0.0, 1.0}
	
	// If the round is started and player is hooked we can set the user velocity!
	if (rndStarted && gHooked[id])
	{
		static Float:fHookOrigin[3], Float:fUsrOrigin[3], Float:fDist
		pev(HookEnt, pev_origin, fHookOrigin)
		pev(id, pev_origin, fUsrOrigin)
		
		fDist = vector_distance(fHookOrigin, fUsrOrigin)
		
		if (fDist >= 30.0)
		{
			new Float:fSpeed = get_pcvar_float(pSpeed)
			
			fSpeed *= 0.52
			
			fVelocity[0] = (fHookOrigin[0] - fUsrOrigin[0]) * (2.0 * fSpeed) / fDist
			fVelocity[1] = (fHookOrigin[1] - fUsrOrigin[1]) * (2.0 * fSpeed) / fDist
			fVelocity[2] = (fHookOrigin[2] - fUsrOrigin[2]) * (2.0 * fSpeed) / fDist
		}
	}
	// Set the velocity
	set_pev(id, pev_velocity, fVelocity)
	
	return PLUGIN_HANDLED
}
		
public throw_hook(id)
{
	// Get origin and angle for the hook
	static Float:fOrigin[3], Float:fAngle[3],Float:fvAngle[3]
	static Float:fStart[3]
	pev(id, pev_origin, fOrigin)
	
	pev(id, pev_angles, fAngle)
	pev(id, pev_v_angle, fvAngle)
	
	if (get_pcvar_num(pInstant))
	{
		get_user_hitpoint(id, fStart)
		
		if (engfunc(EngFunc_PointContents, fStart) != CONTENTS_SKY)
		{
			static Float:fSize[3]
			pev(id, pev_size, fSize)
			
			fOrigin[0] = fStart[0] + floatcos(fvAngle[1], degrees) * (-10.0 + fSize[0])
			fOrigin[1] = fStart[1] + floatsin(fvAngle[1], degrees) * (-10.0 + fSize[1])
			fOrigin[2] = fStart[2]
		}
		else
			xs_vec_copy(fStart, fOrigin)
	}

	
	// Make the hook!
	Hook[id] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
		
	if (Hook[id])
	{
		// Player cant throw hook now
		canThrowHook[id] = false
		
		static const Float:fMins[3] = {-2.840000, -14.180000, -2.840000}
		static const Float:fMaxs[3] = {2.840000, 0.020000, 2.840000}
		
		//Set some Data
		set_pev(Hook[id], pev_classname, "Hook")
		
		engfunc(EngFunc_SetModel, Hook[id], "models/rpgrocket.mdl")
		engfunc(EngFunc_SetOrigin, Hook[id], fOrigin)
		engfunc(EngFunc_SetSize, Hook[id], fMins, fMaxs)		
		
		//set_pev(Hook[id], pev_mins, fMins)
		//set_pev(Hook[id], pev_maxs, fMaxs)
		
		set_pev(Hook[id], pev_angles, fAngle)
		
		set_pev(Hook[id], pev_solid, 2)
		set_pev(Hook[id], pev_movetype, 5)
		set_pev(Hook[id], pev_owner, id)
		
		//Set hook velocity
		static Float:fForward[3], Float:Velocity[3]
		new Float:fSpeed = get_pcvar_float(pThrowSpeed)
		
		engfunc(EngFunc_MakeVectors, fvAngle)
		global_get(glb_v_forward, fForward)
		
		Velocity[0] = fForward[0] * fSpeed
		Velocity[1] = fForward[1] * fSpeed
		Velocity[2] = fForward[2] * fSpeed
		
		set_pev(Hook[id], pev_velocity, Velocity)

		// Make the line between Hook and Player
		message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY, Float:{0.0, 0.0, 0.0}, 0)
		if (get_pcvar_num(pInstant))
		{
			write_byte(1) // TE_BEAMPOINT
			write_short(id) // Startent
			write_coord_f(fStart[0]) // End pos
			write_coord_f(fStart[1])
			write_coord_f(fStart[2])
		}
		else
		{
			write_byte(8) // TE_BEAMENTS
			write_short(id) // Start Ent
			write_short(Hook[id]) // End Ent
		}
		write_short(sprBeam) // Sprite
		write_byte(1) // StartFrame
		write_byte(1) // FrameRate
		write_byte(600) // Life
		write_byte(get_pcvar_num(pWidth)) // Width
		write_byte(get_pcvar_num(pHookNoise)) // Noise
		// Colors now
		if (get_pcvar_num(pColor))
		{
			if (get_user_team(id) == 1) // Terrorist
			{
				write_byte(255) // R
				write_byte(0)	// G
				write_byte(0)	// B
			}
			#if defined _cstrike_included
			else if(cs_get_user_vip(id)) // vip for cstrike
			{
				write_byte(0)	// R
				write_byte(255)	// G
				write_byte(0)	// B
			}
			#endif // _cstrike_included
			else if(get_user_team(id) == 2) // CT
			{
				write_byte(0)	// R
				write_byte(0)	// G
				write_byte(255)	// B
			}
			else
			{
				write_byte(255) // R
				write_byte(255) // G
				write_byte(255) // B
			}
		}
		else
		{
			write_byte(255) // R
			write_byte(255) // G
			write_byte(255) // B
		}
		write_byte(192) // Brightness
		write_byte(0) // Scroll speed
		message_end()
		
		if (get_pcvar_num(pSound) && !get_pcvar_num(pInstant))
			emit_sound(id, CHAN_BODY, "weapons/xbow_fire1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_HIGH)
		
		static TaskData[2]
		TaskData[0] = id
		TaskData[1] = Hook[id]
		
		set_task(0.1, "hookthink", id + 890, TaskData, 2, "b")
	}
	else
		client_print(id, print_chat, "Не могу создать паутину")
}

public remove_hook(id)
{
	//Player can now throw hooks
	canThrowHook[id] = true
	
	// Remove the hook if it is valid
	if (pev_valid(Hook[id]))
		engfunc(EngFunc_RemoveEntity, Hook[id])
	Hook[id] = 0
	
	// Remove the line between user and hook
	if (is_user_connected(id))
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY, {0,0,0}, id)
		write_byte(99) // TE_KILLBEAM
		write_short(id) // entity
		message_end()
	}
	
	// Player is not hooked anymore
	gHooked[id] = false
	return 1
}

public give_hook(id, level, cid)
{
	if (!cmd_access(id ,level, cid, 1))
		return PLUGIN_HANDLED
		
	if (!get_pcvar_num(pAdmin))
	{
		console_print(id, "[Паутина] Админ мод выключен")
		return PLUGIN_HANDLED
	}
	
	static szTarget[32]
	read_argv(1, szTarget, charsmax(szTarget))
	
	new iUsrId = cmd_target(id, szTarget)
	
	if (!iUsrId)
		return PLUGIN_HANDLED
		
	static szName[32]
	get_user_name(iUsrId, szName, charsmax(szName))
	
	if (!g_bHookAllowed[iUsrId])
	{
		g_bHookAllowed[iUsrId] = true
		
		console_print(id, "[Паутина] %s Получил доступ к паутине", szName)
	}
	else
	{
		console_print(id, "[Паутина] У %s уже есть паутина", szName)
	}
	
	return PLUGIN_HANDLED
}

public take_hook(id, level, cid)
{
	if (!cmd_access(id ,level, cid, 1))
		return PLUGIN_HANDLED
	
	if (!get_pcvar_num(pAdmin))
	{
		console_print(id, "[Паутина] Режим админа выключен")
		return PLUGIN_HANDLED
	}
		
	static szTarget[32]
	read_argv(1, szTarget, charsmax(szTarget))
	
	new iUsrId = cmd_target(id, szTarget)
	
	if (!iUsrId)
		return PLUGIN_HANDLED
		
	static szName[32]
	get_user_name(iUsrId, szName, charsmax(szName))
	
	if (g_bHookAllowed[iUsrId])
	{
		g_bHookAllowed[iUsrId] = false
		
		console_print(id, "[Паутина] Ты отобрал у %s доступ к паутине", szName)
	}
	else
		console_print(id, "[Паутина] У %s нет доступа к паутине", szName)
	
	return PLUGIN_HANDLED
}

// Stock by Chaosphere
stock get_user_hitpoint(id, Float:hOrigin[3])
{
	if (!is_user_alive(id))
		return 0
	
	static Float:fOrigin[3], Float:fvAngle[3], Float:fvOffset[3], Float:fvOrigin[3], Float:feOrigin[3]
	static Float:fTemp[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_v_angle, fvAngle)
	pev(id, pev_view_ofs, fvOffset)
	
	xs_vec_add(fOrigin, fvOffset, fvOrigin)
	
	engfunc(EngFunc_AngleVectors, fvAngle, feOrigin, fTemp, fTemp)
	
	xs_vec_mul_scalar(feOrigin, 8192.0, feOrigin)
	xs_vec_add(fvOrigin, feOrigin, feOrigin)
	
	static tr
	engfunc(EngFunc_TraceLine, fvOrigin, feOrigin, 0, id, tr)
	get_tr2(tr, TR_vecEndPos, hOrigin)
	//global_get(glb_trace_endpos, hOrigin)
	
	return 1
}

stock statusMsg(id, szMsg[], {Float,_}:...)
{
	static iStatusText
	if (!iStatusText)
		iStatusText = get_user_msgid("StatusText")
	
	static szBuffer[512]
	vformat(szBuffer, charsmax(szBuffer), szMsg, 3)
	
	message_begin((id == 0) ? MSG_ALL : MSG_ONE, iStatusText, _, id)
	write_byte(0) // Unknown
	write_string(szBuffer) // Message
	message_end()
	
	return 1
}
public itminfo(id,cel)
{
        static clas[32];
        pev(cel,pev_classname,clas,31);
        
        if (!equali(clas,"przedmiot")) return PLUGIN_CONTINUE
        set_hudmessage(255, 170, 0, 0.3, 0.56, 0, 6.0, 0.1)
        show_hudmessage(id, "Item: %s ",item_name[cel])
        
        return PLUGIN_CONTINUE
}

public create_itm(id,id_item,name_item[128])
{ 
    new Float:origins[3]
    pev(id,pev_origin,origins); // pobranie coordow gracza
    new entit=create_entity("info_target") // tworzymy byt
    origins[0]+=40.0
    origins[2]-=32.0
    set_pev(entit,pev_origin,origins) //ustawiamy coordy
    entity_set_model(entit,modelitem) // oraz model
    set_pev(entit,pev_classname,"przedmiot");  // i klase

    dllfunc(DLLFunc_Spawn, entit); 
    set_pev(entit,pev_solid,SOLID_BBOX); 
    set_pev(entit,pev_movetype,MOVETYPE_FLY);

    engfunc(EngFunc_SetSize,entit,{-1.1, -1.1, -1.1},{1.1, 1.1, 1.1});
        
    engfunc(EngFunc_DropToFloor,entit);
        
    item_info[entit]=id_item //parametry przepisujemy do globalnej tablicy potrzebnej nam potem
        
    item_name[entit]=name_item      
}
public fwd_touch(ent,id)
{       
    
    if(!is_user_alive(id)) return FMRES_IGNORED;
    
    static classname[32];
    pev(ent,pev_classname,classname,31); 
    
    if(!equali(classname,"przedmiot")) return FMRES_IGNORED; // jesli nie dotykamy przedmiotu to nie idziemy dalej
    if(!player_item_id[id] && pev(id,pev_button)& IN_DUCK)
	{
        award_item(id,item_info[ent])
        engfunc(EngFunc_RemoveEntity,ent);
    }
    return FMRES_IGNORED; 
}
public TTWin() {
        new play[32], nr, id, Players2[32], playerCount2, xp
        get_players(play, nr, "h");
		
		if(get_cvar_num("diablo_xpbonus_type") == 1)
		{
			get_players(Players2, playerCount2, "ch")
		}
		else
		{
			playerCount2 = get_playersnum()
		}
		
		xp = playerCount2 * get_cvar_num("diablo_xp_multi2")
		
        for(new i=0; i<nr; i++) 
		{
			id = play[i];
			if(is_user_connected(id) && cs_get_user_team(id) == CS_TEAM_T) 
			{
				Give_Xp(id, xp);
				ColorChat(id, GREEN, "Полученно^x03 %i^x01 опыта за победу твоей команды в раунде", xp);
			}
        }
}

public CTWin() 
{
        new play[32], nr, id, Players2[32], playerCount2, xp
        get_players(play, nr, "h");
		
		if(get_cvar_num("diablo_xpbonus_type") == 1)
		{
			get_players(Players2, playerCount2, "ch")
		}
		else
		{
			playerCount2 = get_playersnum()
		}
		
		xp = playerCount2 * get_cvar_num("diablo_xp_multi2")
		
        for(new i=0; i<nr; i++) 
		{
			id = play[i];
			if(is_user_connected(id) && cs_get_user_team(id) == CS_TEAM_CT) 
			{
				Give_Xp(id, xp);
				ColorChat(id, GREEN, "Полученно^x03 %i^x01 опыта за победу твоей команды в раунде", xp);
			}
        }
}
public add_bonus_shake(attacker_id,id)
{
        if(c_shake[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && is_user_alive(id)) 
        {
                if (random_num(1,c_shake[attacker_id]) == 1)
                {
                        message_begin(MSG_ONE,get_user_msgid("ScreenShake"),{0,0,0},id); 
                        write_short(7<<14); 
                        write_short(1<<13); 
                        write_short(1<<14); 
                        message_end();
                }
        }
        return PLUGIN_HANDLED
}
public add_bonus_shaked(attacker_id,id)
{
	new clip,ammo
	new weapon = get_user_weapon(attacker_id,clip,ammo)
        if(c_shaked[attacker_id] > 0 && get_user_team(attacker_id) != get_user_team(id) && is_user_alive(id)) 
        {
			if(weapon == CSW_GLOCK18 || weapon == CSW_USP || weapon == CSW_P228 || weapon == CSW_DEAGLE || weapon == CSW_ELITE || weapon == CSW_FIVESEVEN)
			{
				if (random_num(1,c_shaked[attacker_id]) == 1)
				{
					message_begin(MSG_ONE,get_user_msgid("ScreenShake"),{0,0,0},id); 
					write_short(7<<14); 
					write_short(1<<13); 
					write_short(1<<14); 
					message_end();
				}
			}
        }
        return PLUGIN_HANDLED
}

public player_Think(id){
        if(!is_user_alive(id) || !niewidzialnosc_kucanie[id])
		{
            return HAM_IGNORED;
        }
        new button = get_user_button(id);
        new oldbutton = get_user_oldbutton(id);
        if(button&IN_DUCK && !(oldbutton&IN_DUCK))
		{
            set_user_rendering(id, kRenderFxGlowShell, 255, 255, 255, kRenderTransColor, 50)			
        }
        else if(!(button&IN_DUCK) && oldbutton&IN_DUCK)
		{
			set_user_rendering(id,kRenderFxNone,255,255,255,kRenderTransAlpha,255)
        }
        return HAM_HANDLED;
}
/*public Fwd_CmdStart(id, uc_handle, seed)
{	
	new systime = get_systime();
	
	if(nextcheck[id] < systime)
	{
		new button = get_uc(uc_handle, UC_Buttons);
		if(button != 0)
		{
			lastactive[id] = systime;
			nextcheck[id] = systime + 1;
		}
	}
	return FMRES_HANDLED;
}

public AutoCheck_Afk()
{
	
	new players[32]
	new num
	get_players(players, num);
	
	new actualtime = get_systime();
	new playertime;
	
	for(new i = 0 ; i < num ; i++)
	{
		
		if(!is_user_connected(players[i]))
			return;
			
		if(!is_user_alive(players[i]))
			return;
		
		playertime = actualtime - lastactive[players[i]];
		
		if(playertime > 0 && (cs_get_user_team(players[i]) == CS_TEAM_CT || cs_get_user_team(players[i]) == CS_TEAM_T))
		{
			if(player_class[players[i]] == Infidel)
			{				
				player_infidel[players[i]] = 0
				client_print(players[i], print_center, "No Invis")
			}
		}
	}
}*/

stock fm_get_weapon_ent_owner(ent)
{
	if(pev_valid(ent) != 2)
		return -1;
	
	return get_pdata_cbase(ent, 41, 4);
}

public HamTakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
		if(player_class[victim] ==  Izual)
		{
			new Float:izual_chance = player_intelligence[victim]/250.0					
			new Float:chance = random_float(0.0, 1.0 )
			if( chance <= izual_chance )
			{
				return FMRES_SUPERCEDE;
			}
		}
		if(damagebits&(1<<1) && lustrzany_pocisk[victim] > 0)
        {
                SetHamParamEntity(1, attacker);
                SetHamParamEntity(2,victim );
                SetHamParamEntity(3,victim );
                lustrzany_pocisk[victim]--;
                return HAM_HANDLED;
        }
		if(player_class[victim] == Monk)
		{
			if(monk_energy[victim] > 0)
			{
				new dmg_difference = monk_energy[victim] - floatround(damage)
				if(dmg_difference >= 0)
				{
					monk_energy[victim] = dmg_difference
				}
				else
				{
					monk_energy[victim] = 0
					new weapon = get_user_weapon( attacker ,_,_)
					new weaponname[32];
					get_weaponname( weapon, weaponname, 31 );
					replace(weaponname, 31, "weapon_", "")
					d2_damage( victim, attacker, -dmg_difference, weaponname)
				}
				monk_lastshot[victim] = get_gametime()
				return FMRES_SUPERCEDE;
			}
			monk_lastshot[victim] = get_gametime()
		}
        return HAM_IGNORED;
}

public fwd_AttackSpeed( const weapon_ent )
{	
	if (!pev_valid(weapon_ent))
        return HAM_IGNORED
	
	new id = fm_get_weapon_ent_owner(weapon_ent)
	if(duriel_slowweap[id] == 1)
	{
		new Float:primary_speed = get_pdata_float(weapon_ent, 46, 4)*2.0
		new Float:secondary_speed = get_pdata_float(weapon_ent, 47, 4)*2.0
		set_pdata_float(weapon_ent, 46, primary_speed, 4)
		set_pdata_float(weapon_ent, 47, secondary_speed, 4)
	}
	
	return HAM_IGNORED;
}

CreateHealBot()
{
		new Bot = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
		if (Bot)
		{
			set_pev(Bot, pev_classname, "HealBot");
			dllfunc(DLLFunc_Spawn, Bot);
			set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
		}
}
public HealBotThink(Bot)
{
        new iPlayers[32], iNum, id;
        get_players(iPlayers, iNum);
        for(new i; i<iNum; i++)
        {
                id = iPlayers[i];
                if (!is_user_alive(id)) continue;
                if (player_class[id] != Frozen) continue;
                
		change_health(id,30,0,"");
        }
        set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
}
CreateHealBot2()
{
        new Bot = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
        if (Bot)
        {
                set_pev(Bot, pev_classname, "HealBot2");
                dllfunc(DLLFunc_Spawn, Bot);
                set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
        }
}
public HealBotThink2(Bot)
{
		new iPlayers[32], iNum, id;
		get_players(iPlayers, iNum);
		for(new i; i<iNum; i++)
		{
			id = iPlayers[i];
			if (!is_user_alive(id)) continue;
			if (player_class[id] != Griswold) continue;			
			
			change_health(id,30,0,"");
		}
		set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
}
CreateHealBot3()
{
		new Bot = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
		if (Bot)
		{
			set_pev(Bot, pev_classname, "HealBot3");
			dllfunc(DLLFunc_Spawn, Bot);
			set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
		}
}
public HealBotThink3(Bot)
{
		new iPlayers[32], iNum, id;
		get_players(iPlayers, iNum);
		for(new i; i<iNum; i++)
		{
			id = iPlayers[i];
			if (!is_user_alive(id)) continue;
			if (player_class[id] != TheSmith) continue;
			
			change_health(id,30,0,"");
		}
		set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
}
CreateHealBot4()
{
		new Bot = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
		if (Bot)
		{
			set_pev(Bot, pev_classname, "HealBot4");
			dllfunc(DLLFunc_Spawn, Bot);
			set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
		}
}
public HealBotThink4(Bot)
{
		new iPlayers[32], iNum, id;
		get_players(iPlayers, iNum);
		for(new i; i<iNum; i++)
		{
			id = iPlayers[i];
			if (!is_user_alive(id)) continue;
			if (player_class[id] != Demonolog) continue;
                
			change_health(id,30,0,"");
		}
		set_pev(Bot, pev_nextthink, get_gametime() + 10.0);
}
public exp(id)
{
	ColorChat(id, GREEN, "Уровень: ^x04%i ^x01- у вас есть ^x03(%d/%d)^x01 опыта", player_lvl[id], player_xp[id], LevelXP[player_lvl[id]])
	ColorChat(id, GREEN, "До следующего уровня ^x04%d^x01 опыта", LevelXP[player_lvl[id]]-player_xp[id])
}
public radar_scan() 
{
        for(new id=1; id<=MAX; id++) 
		{
				if(!is_user_alive(id)) continue;
				
				if(!player_b_radar[id] && player_class[id] != GiantSpider) continue;

                for(new i=1; i<=MAX; i++) 
				{
                        if(!is_user_alive(i) || id == i || get_user_team(id) == get_user_team(i)) continue;

                        if(player_b_radar[id])
						{
							new PlayerCoords[3];
							get_user_origin(i, PlayerCoords);

							message_begin(MSG_ONE_UNRELIABLE, g_msgHostageAdd, {0,0,0}, id);
							write_byte(id);
							write_byte(i);
							write_coord(PlayerCoords[0]);
							write_coord(PlayerCoords[1]);
							write_coord(PlayerCoords[2]);
							message_end();

							message_begin(MSG_ONE_UNRELIABLE, g_msgHostageDel, {0,0,0}, id);
							write_byte(i);
							message_end();
						}
						else if((player_class[id] == GiantSpider) && (is_trap_active[i] == 1) && (owner_radar_trap[i] == id))
						{
							new PlayerCoords[3];
							get_user_origin(i, PlayerCoords);

							message_begin(MSG_ONE_UNRELIABLE, g_msgHostageAdd, {0,0,0}, id);
							write_byte(id);
							write_byte(i);
							write_coord(PlayerCoords[0]);
							write_coord(PlayerCoords[1]);
							write_coord(PlayerCoords[2]);
							message_end();

							message_begin(MSG_ONE_UNRELIABLE, g_msgHostageDel, {0,0,0}, id);
							write_byte(i);
							message_end();
						}						
                }
        }
}

public fallen_respawn()
{
	for(new i=0; i<33; i++)
	{
		if(player_class[i] == Fallen && player_lvl[i] > 49 && round_status==1 && is_user_alive(i))
		{
			if((get_user_team(i) == 1 && fallens_tt > 1) || (get_user_team(i) == 2 && fallens_ct > 1))
			{
				new falltime = floatround(1515.0/player_lvl[i], floatround_floor);
				if(player_fallen_tr[i] > falltime)
				{
					new fplayers[32],numfplayers,i2,name[32],player,name2[32]
					new Array:a_fallens=ArrayCreate(32) 
					get_players(fplayers, numfplayers, "bh")
					for (i2=0; i2<numfplayers; i2++)
					{
						player = fplayers[i2]
						if(get_user_team(i) == get_user_team(player) && player_class[player] == Fallen)
						{
							ArrayPushCell(a_fallens, player) 
						}
					}
					new a_size=ArraySize(a_fallens)
					player=random(a_size)
					if(a_size != 0)
					{
						player=ArrayGetCell(a_fallens,player) 
						get_user_name(player,name,31)
						ExecuteHamB(Ham_CS_RoundRespawn, player)
						hudmsg2(i,1.0,"Воскрешенн Падший ^nиз твоей команды:^n %s",name)
						player_fallen_tr[i]=1;
						emit_sound(i,CHAN_STATIC, "diablo_lp/resurrectcast.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
						emit_sound(player,CHAN_STATIC, "diablo_lp/resurrect.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
						get_user_name(i,name2,31)
						for(new i3=0; i3<33; i3++)
						{
							client_print(i3, print_chat, "Падший шаман %s воскресил Падшего %s",name2,name)
						}
						ArrayDestroy(a_fallens) 
					}
				}
				else
				{
					new normaltime = falltime - player_fallen_tr[i];
					hudmsg2(i,1.0,"Воскрешение Падшего через %i секунд",normaltime)
					player_fallen_tr[i]=player_fallen_tr[i]+1;
				}
			}
		}
		if(player_class[i] == Zakarum && round_status==1 && is_user_alive(i))
		{
			new revivername[32]
			new Float:radius = 800.0 //revive radius
			
			for (new a=0; a<32; a++) 
			{
				//a = Players[i2] 
				
				new Float:aOrigin[3], Float:origin[3]
				pev(a,pev_origin,aOrigin)
				pev(i,pev_origin,origin)
				new Float:distance = get_distance_f(aOrigin,origin)						
				if (get_user_team(i) == get_user_team(a) && distance < radius && player_class[a] == Zakarum && a != i && is_user_alive(a))
				{
					new Float:revivehpfloat = player_intelligence[i]/10.0
					new revivehp = floatround(revivehpfloat,floatround_round)
					if(revivehp > 0)
					{
						new m_health = race_heal[player_class[a]]+player_strength[a]*2
						new newhp = get_user_health(a)+revivehp
						if(newhp < m_health)
						{
							set_user_health(a,newhp)
							get_user_name(i,revivername,31)
							hudmsg2(a,1.0,"%s исцелил вас на %i HP",revivername, revivehp)
						}
					}
				}
			}
		}
		if(player_class[i] == Monk && round_status==1 && is_user_alive(i))
		{
			new monk_timer = floatround(20.0-player_intelligence[i]/5.0)
			
			if(((monk_lastshot[i] + float(monk_timer)) < get_gametime()) && (monk_energy[i] < monk_maxenergy[i]))
			{
				//Check max energy
				monk_energy[i] += 10
				if(monk_energy[i] > monk_maxenergy[i])
				{
					monk_energy[i] = monk_maxenergy[i]
				}
			}
			
		}
    }
}
public play_idle(taskid)
{
	new TASK_BLOOD = taskid - 2000;
	if(round_status==1 && player_class[TASK_BLOOD] == Fallen && is_user_alive(TASK_BLOOD))
	{
		if(player_lvl[TASK_BLOOD] > 49)
		{
			rndfsound = random(3);
			switch(rndfsound)
			{
				case 0: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallens_neutral1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 1: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallens_neutral2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 2: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallens_neutral3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 3: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallens_neutral4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			}
		}
		else
		{
			rndfsound = random(4);
			switch(rndfsound)
			{
				case 0: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallen_neutral1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 1: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallen_neutral2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 2: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallen_neutral3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 3: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallen_neutral4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 4: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/fallen_neutral5.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			}
		} 
	}
	else if(round_status==1 && player_class[TASK_BLOOD] == Zakarum && is_user_alive(TASK_BLOOD))
	{
			rndfsound = random(3);
			switch(rndfsound)
			{
				case 0: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/zakarum_neutral1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 1: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/zakarum_neutral2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 2: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/zakarum_neutral3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
				case 3: emit_sound(TASK_BLOOD,CHAN_STATIC, "diablo_lp/zakarum_neutral4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
			} 
	}
}

public niesmiertelnoscon(id) 
{
        if(used_item[id]) 
		{
            hudmsg(id, 2.0, "Бессмертие можно использовать один раз за раунд!");
            return PLUGIN_CONTINUE;
        }
        set_user_godmode(id, 1);
        new Float:czas = player_b_godmode[id]+0.0;
        remove_task(id+TASK_GOD);
        set_task(czas, "niesmiertelnoscoff", id+TASK_GOD, "", 0, "a", 1);

        message_begin(MSG_ONE, gmsgBartimer, {0,0,0}, id);
        write_byte(player_b_godmode[id]);
        write_byte(0);
        message_end();
        used_item[id] = true;

        return PLUGIN_CONTINUE;
}

public niesmiertelnoscoff(id) 
{
        id-=TASK_GOD;

        if(is_user_connected(id)) 
		{
            set_user_godmode(id, 0);

            message_begin(MSG_ONE, gmsgBartimer, {0,0,0}, id);
            write_byte(0);
            write_byte(0);
            message_end();
        }
}
public item_zamroz(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Тотем можно использовать 1 раз за раунд!")
		return PLUGIN_CONTINUE
	}
	
	used_item[id] = true
	
	new origin[3]
	pev(id,pev_origin,origin)
	
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Zamroz_Totem")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_TRIGGER)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_ltime, halflife_time() + 15 + 0.1)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/totem_heal.mdl")  	
	set_rendering ( ent, kRenderFxGlowShell, 0,100,255, kRenderFxNone, 255 ) 	
	engfunc(EngFunc_DropToFloor,ent)
	
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
	
	return PLUGIN_CONTINUE	
}

public Effect_Zamroz_Totem_Think(ent)
{
	new id = pev(ent,pev_owner)
	new totem_dist = 300
	
	//We have emitted beam. Apply effect (this is delayed)
	if (pev(ent,pev_euser2) == 1)
	{		
		new Float:forigin[3], origin[3]
		pev(ent,pev_origin,forigin)	
		FVecIVec(forigin,origin)
		
		//Find people near and damage them
		new entlist[513]
		new numfound = find_sphere_class(0,"player",totem_dist+0.0,entlist,512,forigin)		

		for (new i=0; i < numfound; i++)
		{		
			new pid = entlist[i]
			
			if (get_user_team(pid) == get_user_team(id))
			continue
			
			if (is_user_alive(pid))
			{
				set_user_maxspeed(pid, 1.0)
				set_task(15.0, "off_zamroz", pid)
			}			
		}
		
		set_pev(ent,pev_euser2,0)
		set_pev(ent,pev_nextthink, halflife_time() + 1.5)
		
		return PLUGIN_CONTINUE
	}
	
	//Entity should be destroyed because livetime is over
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	//If this object is almost dead, apply some render to make it fade out
	if (pev(ent,pev_ltime)-2.0 < halflife_time())
	set_rendering ( ent, kRenderFxNone, 255,255,255, kRenderTransAlpha, 100 ) 
	
	new Float:forigin[3], origin[3]
	pev(ent,pev_origin,forigin)	
	FVecIVec(forigin,origin)
	
	//Find people near and give them health
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
	write_byte( TE_BEAMCYLINDER );
	write_coord( origin[0] );
	write_coord( origin[1] );
	write_coord( origin[2] );
	write_coord( origin[0] );
	write_coord( origin[1] + totem_dist );
	write_coord( origin[2] + totem_dist );
	write_short( sprite_white );
	write_byte( 0 ); // startframe
	write_byte( 0 ); // framerate
	write_byte( 10 ); // life
	write_byte( 10 ); // width
	write_byte( 255 ); // noise
	write_byte( 0 ); // r, g, b
	write_byte( 100 ); // r, g, b
	write_byte( 255 ); // r, g, b
	write_byte( 128 ); // brightness
	write_byte( 5 ); // speed
	message_end();
	
	set_pev(ent,pev_euser2,1)
	set_pev(ent,pev_nextthink, halflife_time() + 0.5)
	
	
	return PLUGIN_CONTINUE
	
}

public off_zamroz(pid)
{
	set_user_maxspeed(pid, 270.0)
}
public giveitem(id, level, cid) 
{ 
        if(!cmd_access(id,level, cid, 3)) 
                return PLUGIN_HANDLED; 
        
        new szName[32]; 
        read_argv(1, szName, 31); 
        new iTarget=cmd_target(id,szName,0); 
        if(iTarget)
        { 
                get_user_name(iTarget, szName, 31); 
                new szItem[10], iItem; 
                read_argv(2, szItem, 9); 
                iItem=str_to_num(szItem); 
                client_print(id, print_console, "Игроку %s выдан item %d",szName, iItem); 
                award_item(iTarget, iItem); 
                set_gravitychange(iTarget)
                set_speedchange(iTarget)
                set_renderchange(iTarget)
        } 
        return PLUGIN_HANDLED 
}
public item_kasa(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Тотем можно использовать 1 раз за раунд!")
		return PLUGIN_CONTINUE
	}
	
	used_item[id] = true
	
	new origin[3]
	pev(id,pev_origin,origin)
	
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Kasa_Totem")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_TRIGGER)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_ltime, halflife_time() + 15 + 0.1)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/totem_heal.mdl")  	
	set_rendering ( ent, kRenderFxGlowShell, 255,215,0, kRenderFxNone, 255 ) 	
	engfunc(EngFunc_DropToFloor,ent)
	
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
	
	return PLUGIN_CONTINUE	
}

public Effect_Kasa_Totem_Think(ent)
{
	new id = pev(ent,pev_owner)
	new totem_dist = 300
	
	//We have emitted beam. Apply effect (this is delayed)
	if (pev(ent,pev_euser2) == 1)
	{		
		new Float:forigin[3], origin[3]
		pev(ent,pev_origin,forigin)	
		FVecIVec(forigin,origin)
		
		//Find people near and damage them
		new entlist[513]
		new numfound = find_sphere_class(0,"player",totem_dist+0.0,entlist,512,forigin)		

		for (new i=0; i < numfound; i++)
		{		
			new pid = entlist[i]
			
			if (get_user_team(pid) == get_user_team(id))
			continue
			
			if (is_user_alive(pid)){
				cs_set_user_money(id, cs_get_user_money(id)+500, 1)
				set_task(15.0, "off_kasa", pid)
			}			
		}
		
		set_pev(ent,pev_euser2,0)
		set_pev(ent,pev_nextthink, halflife_time() + 1.5)
		
		return PLUGIN_CONTINUE
	}
	
	//Entity should be destroyed because livetime is over
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	//If this object is almost dead, apply some render to make it fade out
	if (pev(ent,pev_ltime)-2.0 < halflife_time())
	set_rendering ( ent, kRenderFxNone, 255,255,255, kRenderTransAlpha, 100 ) 
	
	new Float:forigin[3], origin[3]
	pev(ent,pev_origin,forigin)	
	FVecIVec(forigin,origin)
	
	//Find people near and give them health
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
	write_byte( TE_BEAMCYLINDER );
	write_coord( origin[0] );
	write_coord( origin[1] );
	write_coord( origin[2] );
	write_coord( origin[0] );
	write_coord( origin[1] + totem_dist );
	write_coord( origin[2] + totem_dist );
	write_short( sprite_white );
	write_byte( 0 ); // startframe
	write_byte( 0 ); // framerate
	write_byte( 10 ); // life
	write_byte( 10 ); // width
	write_byte( 255 ); // noise
	write_byte( 255); // r, g, b
	write_byte( 215 ); // r, g, b
	write_byte( 0 ); // r, g, b
	write_byte( 128 ); // brightness
	write_byte( 5 ); // speed
	message_end();
	
	set_pev(ent,pev_euser2,1)
	set_pev(ent,pev_nextthink, halflife_time() + 0.5)
	
	
	return PLUGIN_CONTINUE
	
}

public off_kasa(pid){
	set_user_maxspeed(pid, 270.0)
}
public item_kasaq(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Тотем можно использовать 1 раз за раунд!")
		return PLUGIN_CONTINUE
	}
	
	used_item[id] = true
	
	new origin[3]
	pev(id,pev_origin,origin)
	
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Kasaq_Totem")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_TRIGGER)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_ltime, halflife_time() + 15 + 0.1)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/totem_heal.mdl")  	
	set_rendering ( ent, kRenderFxGlowShell, 138,43,226, kRenderFxNone, 255 ) 	
	engfunc(EngFunc_DropToFloor,ent)
	
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
	
	return PLUGIN_CONTINUE	
}

public Effect_Kasaq_Totem_Think(ent)
{
	new id = pev(ent,pev_owner)
	new totem_dist = 300
	
	//We have emitted beam. Apply effect (this is delayed)
	if (pev(ent,pev_euser2) == 1)
	{		
		new Float:forigin[3], origin[3]
		pev(ent,pev_origin,forigin)	
		FVecIVec(forigin,origin)
		
		//Find people near and damage them
		new entlist[513]
		new numfound = find_sphere_class(0,"player",totem_dist+0.0,entlist,512,forigin)		

		for (new i=0; i < numfound; i++)
		{		
			new pid = entlist[i]
			
			if (get_user_team(pid) == get_user_team(id))
			continue
			
			if (is_user_alive(pid)){
				cs_set_user_money(pid, cs_get_user_money(pid)-500, 1)
				set_task(15.0, "off_kasaq", pid)
			}			
		}
		
		set_pev(ent,pev_euser2,0)
		set_pev(ent,pev_nextthink, halflife_time() + 1.5)
		
		return PLUGIN_CONTINUE
	}
	
	//Entity should be destroyed because livetime is over
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	//If this object is almost dead, apply some render to make it fade out
	if (pev(ent,pev_ltime)-2.0 < halflife_time())
	set_rendering ( ent, kRenderFxNone, 255,255,255, kRenderTransAlpha, 100 ) 
	
	new Float:forigin[3], origin[3]
	pev(ent,pev_origin,forigin)	
	FVecIVec(forigin,origin)
	
	//Find people near and give them health
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
	write_byte( TE_BEAMCYLINDER );
	write_coord( origin[0] );
	write_coord( origin[1] );
	write_coord( origin[2] );
	write_coord( origin[0] );
	write_coord( origin[1] + totem_dist );
	write_coord( origin[2] + totem_dist );
	write_short( sprite_white );
	write_byte( 0 ); // startframe
	write_byte( 0 ); // framerate
	write_byte( 10 ); // life
	write_byte( 10 ); // width
	write_byte( 255 ); // noise
	write_byte( 138 ); // r, g, b
	write_byte( 43 ); // r, g, b
	write_byte( 226 ); // r, g, b
	write_byte( 128 ); // brightness
	write_byte( 5 ); // speed
	message_end();
	
	set_pev(ent,pev_euser2,1)
	set_pev(ent,pev_nextthink, halflife_time() + 0.5)
	
	
	return PLUGIN_CONTINUE
	
}

public off_kasaq(pid){
	set_user_maxspeed(pid, 270.0)
}
public item_wywal(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Тотем можно использовать 1 раз за раунд!")
		return PLUGIN_CONTINUE
	}
	
	used_item[id] = true
	
	new origin[3]
	pev(id,pev_origin,origin)
	
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Wywal_Totem")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_TRIGGER)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_ltime, halflife_time() + 15 + 0.1)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/totem_heal.mdl")  	
	set_rendering ( ent, kRenderFxGlowShell, 139,69,19, kRenderFxNone, 255 ) 	
	engfunc(EngFunc_DropToFloor,ent)
	
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
	
	return PLUGIN_CONTINUE	
}

public Effect_Wywal_Totem_Think(ent)
{
	new id = pev(ent,pev_owner)
	new totem_dist = 300
	
	//We have emitted beam. Apply effect (this is delayed)
	if (pev(ent,pev_euser2) == 1)
	{		
		new Float:forigin[3], origin[3]
		pev(ent,pev_origin,forigin)	
		FVecIVec(forigin,origin)
		
		//Find people near and damage them
		new entlist[513]
		new numfound = find_sphere_class(0,"player",totem_dist+0.0,entlist,512,forigin)		

		for (new i=0; i < numfound; i++)
		{		
			new pid = entlist[i]
			
			if (get_user_team(pid) == get_user_team(id))
			continue
			
			if (is_user_alive(pid)){
				client_cmd(pid, "drop")
				set_task(15.0, "off_wywal", pid)
			}			
		}
		
		set_pev(ent,pev_euser2,0)
		set_pev(ent,pev_nextthink, halflife_time() + 1.5)
		
		return PLUGIN_CONTINUE
	}
	
	//Entity should be destroyed because livetime is over
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	//If this object is almost dead, apply some render to make it fade out
	if (pev(ent,pev_ltime)-2.0 < halflife_time())
	set_rendering ( ent, kRenderFxNone, 255,255,255, kRenderTransAlpha, 100 ) 
	
	new Float:forigin[3], origin[3]
	pev(ent,pev_origin,forigin)	
	FVecIVec(forigin,origin)
	
	//Find people near and give them health
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
	write_byte( TE_BEAMCYLINDER );
	write_coord( origin[0] );
	write_coord( origin[1] );
	write_coord( origin[2] );
	write_coord( origin[0] );
	write_coord( origin[1] + totem_dist );
	write_coord( origin[2] + totem_dist );
	write_short( sprite_white );
	write_byte( 0 ); // startframe
	write_byte( 0 ); // framerate
	write_byte( 10 ); // life
	write_byte( 10 ); // width
	write_byte( 255 ); // noise
	write_byte( 139); // r, g, b
	write_byte( 69 ); // r, g, b
	write_byte( 19 ); // r, g, b
	write_byte( 128 ); // brightness
	write_byte( 5 ); // speed
	message_end();
	
	set_pev(ent,pev_euser2,1)
	set_pev(ent,pev_nextthink, halflife_time() + 0.5)
	
	
	return PLUGIN_CONTINUE
	
}

public off_wywal(pid){
	set_user_maxspeed(pid, 270.0)
}
public Flesh(id){
	Display_Fade(id,1<<14,1<<14 ,1<<16,255,155,50,230)
}
public item_fleshuj(id)
{
	if (used_item[id])
	{
		hudmsg(id,2.0,"Тотем можно использовать 1 раз за раунд!")
		return PLUGIN_CONTINUE
	}
	
	used_item[id] = true
	
	new origin[3]
	pev(id,pev_origin,origin)
	
	new ent = Spawn_Ent("info_target")
	set_pev(ent,pev_classname,"Effect_Fleshuj_Totem")
	set_pev(ent,pev_owner,id)
	set_pev(ent,pev_solid,SOLID_TRIGGER)
	set_pev(ent,pev_origin,origin)
	set_pev(ent,pev_ltime, halflife_time() + 15 + 0.1)
	
	engfunc(EngFunc_SetModel, ent, "addons/amxmodx/diablo/totem_heal.mdl")  	
	set_rendering ( ent, kRenderFxGlowShell, 255,255,250, kRenderFxNone, 255 ) 	
	engfunc(EngFunc_DropToFloor,ent)
	
	set_pev(ent,pev_nextthink, halflife_time() + 0.1)
	
	return PLUGIN_CONTINUE	
}

public Effect_Fleshuj_Totem_Think(ent)
{
	new id = pev(ent,pev_owner)
	new totem_dist = 300
	
	//We have emitted beam. Apply effect (this is delayed)
	if (pev(ent,pev_euser2) == 1)
	{		
		new Float:forigin[3], origin[3]
		pev(ent,pev_origin,forigin)	
		FVecIVec(forigin,origin)
		
		//Find people near and damage them
		new entlist[513]
		new numfound = find_sphere_class(0,"player",totem_dist+0.0,entlist,512,forigin)		

		for (new i=0; i < numfound; i++)
		{		
			new pid = entlist[i]
			
			if (get_user_team(pid) == get_user_team(id))
			continue
			
			if (is_user_alive(pid)){
				//client_cmd(pid, "pluginflash")
				Flesh(pid)
				set_task(15.0, "off_fleshuj", pid)
			}			
		}
		
		set_pev(ent,pev_euser2,0)
		set_pev(ent,pev_nextthink, halflife_time() + 1.5)
		
		return PLUGIN_CONTINUE
	}
	
	//Entity should be destroyed because livetime is over
	if (pev(ent,pev_ltime) < halflife_time() || !is_user_alive(id))
	{
		remove_entity(ent)
		return PLUGIN_CONTINUE
	}
	
	//If this object is almost dead, apply some render to make it fade out
	if (pev(ent,pev_ltime)-2.0 < halflife_time())
	set_rendering ( ent, kRenderFxNone, 255,255,255, kRenderTransAlpha, 100 ) 
	
	new Float:forigin[3], origin[3]
	pev(ent,pev_origin,forigin)	
	FVecIVec(forigin,origin)
	
	//Find people near and give them health
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY, origin );
	write_byte( TE_BEAMCYLINDER );
	write_coord( origin[0] );
	write_coord( origin[1] );
	write_coord( origin[2] );
	write_coord( origin[0] );
	write_coord( origin[1] + totem_dist );
	write_coord( origin[2] + totem_dist );
	write_short( sprite_white );
	write_byte( 0 ); // startframe
	write_byte( 0 ); // framerate
	write_byte( 10 ); // life
	write_byte( 10 ); // width
	write_byte( 255 ); // noise
	write_byte( 255 ); // r, g, b
	write_byte( 255 ); // r, g, b
	write_byte( 250 ); // r, g, b
	write_byte( 128 ); // brightness
	write_byte( 5 ); // speed
	message_end();
	
	set_pev(ent,pev_euser2,1)
	set_pev(ent,pev_nextthink, halflife_time() + 0.5)
	
	
	return PLUGIN_CONTINUE
	
}

public off_fleshuj(pid){
	set_user_maxspeed(pid, 270.0)
}
/*public menum1(id) //o to ma pokazywac w switchu
{
        if(cs_get_user_team(id) == CS_TEAM_CT || cs_get_user_team(id) == CS_TEAM_T)
        {
                new menu = menu_create("\ySklep za mane","wybor_menum1")
                
                menu_additem(menu,"\yBronie")//,"0",0)
                menu_additem(menu,"\yItemy","1",0)
                menu_additem(menu,"\yInne","2",0)
                menu_setprop(menu,MPROP_EXIT,MEXIT_ALL)
                menu_setprop(menu,MPROP_EXITNAME,"Wyjscie")
                menu_setprop(menu,MPROP_NEXTNAME,"Dalej")
                menu_setprop(menu,MPROP_BACKNAME,"Wroc")
                menu_display(id,menu,0)
        }
}
public wybor_menum1(id,menu,item)
{
        
        if(item==MENU_EXIT)
        {
                menu_destroy(menu)
                return PLUGIN_HANDLED
        }
        
        new data[6], iName[64]
        new access, callback
        
        menu_item_getinfo(menu, item, access, data,5, iName, 63, callback);
        
        new key
        
        switch(key)
        {
                case 0: {
                        mymenu(id)
                }
                case 1: {
                        menum3(id)
                }

                case 2: {
                        menum5(id)
                }
        }
        return PLUGIN_HANDLED
}
public menum2(id)
{
        if(cs_get_user_team(id) == CS_TEAM_CT || cs_get_user_team(id) == CS_TEAM_T)
        {
                new menu = menu_create("\ySklep z bronia","wybor_menum2")
                
                menu_additem(menu,"\y M4A1 + Ammo \d[8 many]")//,"0",0)
                menu_additem(menu,"\y AK47 + Ammo \d[7 many]","1",0)
                menu_additem(menu,"\y AWP + Ammo \d[10 many]","2",0)
                menu_additem(menu,"\y Famas + Ammo \d[5 many]","3",0)
		menu_additem(menu,"\y Galil + Ammo \d[5 many]","4",0)
		menu_additem(menu,"\y Krowa + Ammo \d[13 many]","5",0)
		menu_additem(menu,"\y Mp5 + Ammo \d[4 many]","6",0)
		menu_additem(menu,"\y Scout + Ammo \d[6 many]","7",0)
		menu_additem(menu,"\y Wolna Pompa + Ammo \d[7 many]","8",0)
		menu_additem(menu,"\y Szybka Pompa + Ammo \d[7 many]","9",0)
		menu_additem(menu,"\y P90 + Ammo \d[4 many]","10",0)
		menu_additem(menu,"\y Deagl + Ammo \d[2 many]","11",0)
		menu_additem(menu,"\y Aug + Ammo \d[8 many]","12",0)
		menu_additem(menu,"\y SG552 + Ammo \d[8 many]","13",0)
		menu_additem(menu,"\y Noktowizor \d[5 many]","14",0)
                menu_setprop(menu,MPROP_EXIT,MEXIT_ALL)
                menu_setprop(menu,MPROP_EXITNAME,"Wyjscie")
                menu_setprop(menu,MPROP_NEXTNAME,"Dalej")
                menu_setprop(menu,MPROP_BACKNAME,"Wroc")
                menu_display(id,menu,0)
        }
}
public wybor_menum2(id,menu,item)
{
        
        if(item==MENU_EXIT)
        {
                menu_destroy(menu)
                return PLUGIN_HANDLED
        }
        
        new data[6], iName[64]
        new access, callback
        
        menu_item_getinfo(menu, item, access, data,5, iName, 63, callback);
        
        new key
        
        switch(key)
        {
		case 0:
		{
			new koszt = 4;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[SKLEP]^x01 Nie masz wystarczajacej ilosci many.");
				return PLUGIN_CONTINUE;
			}
			mana_gracza[id] -= koszt;
			award_item(id,0)
		}
                case 1: {
			show_motd(id, "addons/data/lang/1.txt3")
                }
                case 2: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 3: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 4: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 5: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 6: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 7: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 8: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 9: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 10: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 11: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 12: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 13: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 14: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
        }
        return PLUGIN_HANDLED
}
public menum3(id)
{
        if(cs_get_user_team(id) == CS_TEAM_CT || cs_get_user_team(id) == CS_TEAM_T)
        {
                new menu = menu_create("\ySklep z itemami","wybor_menum3")
                
                menu_additem(menu,"\y Bojowe Berlo Wampira \d[10 many]","0",0)
                menu_additem(menu,"\y Brazowa Szarfa \d[40 many]","1",0)
                menu_additem(menu,"\y Srebna Szarfa \d[50 many]","2",0)
                menu_additem(menu,"\y Zlota Szarfa \d[60 many]","3",0)
		menu_additem(menu,"\y Skrzydla Aniola \d[100 many]","4",0)
		menu_additem(menu,"\y Skrzydla Archaniola \d[130 many]","5",0)
		menu_additem(menu,"\y Firerope \d[40 many]","6",0)
		menu_additem(menu,"\y Ognisty Amulet \d[60 many]","7",0)
		menu_additem(menu,"\y Pierscien Niewidzialnosci \d[140 many]","8",0)
		menu_additem(menu,"\y Zlota Szkatulka \d[25 many]","9",0)
		menu_additem(menu,"\y Totem Leczniczy \d[40 many]","10",0)
		menu_additem(menu,"\y Wiekszy Totem Leczniczy \d[60 many]","11",0)
		menu_additem(menu,"\y Szansa Szczescia \d[30 many]","12",0)
		menu_additem(menu,"\y Miecz Boga Slonca \d[40 many]","13",0)
		menu_additem(menu,"\y Pochodnia Piekielnego Ognia \d[85 many]","14",0)
		menu_additem(menu,"\y Cichobiegi \d[10 many]","15",0)
                menu_additem(menu,"\y Kamien Smierci \d[70 many]","16",0)
                menu_additem(menu,"\y Skorzana Zbroja \d[50 many]","17",0)
                menu_additem(menu,"\y Magiczny Noz \d[25 many]","18",0)
		menu_additem(menu,"\y Wywazony Noz \d[45 many]","19",0)
		menu_additem(menu,"\y Tajemnica Mlodszego Snajpera \d[70 many]","20",0)
		menu_additem(menu,"\y Tajemnica Starszego Snajpera \d[100 many]","21",0)
		menu_additem(menu,"\y Zmijowy Amulet \d[50 many]","22",0)
		menu_additem(menu,"\y Pierscien Paladina \d[60 many]","23",0)
		menu_additem(menu,"\y Pierscien Monka \d[80 many]","24",0)
		menu_additem(menu,"\y Oko Kota \d[30 many]","25",0)
		menu_additem(menu,"\y Oko Khalima \d[100 many]","26",0)
		menu_additem(menu,"\y Hydrze Ostrze \d[80 many]","27",0)
		menu_additem(menu,"\y Pierscien Expa \d[70 many]","28",0)
		menu_additem(menu,"\y Aegis \d[90 many]","29",0)
		menu_additem(menu,"\y Niebianski Kamien \d[70 many]","30",0)
                menu_additem(menu,"\y Ropiejaca Esencja Destrukcji \d[140 many]","31",0)
                menu_additem(menu,"\y Centurion \d[170 many]","32",0)
                menu_additem(menu,"\y Dr House \d[100 many]","33",0)
		menu_additem(menu,"\y Own Invisible \d[300 many]","34",0)
		menu_additem(menu,"\y Mega Invisible \d[300 many]","35",0)
		menu_additem(menu,"\y Mini Anty Special \d[30 many]","36",0)
		menu_additem(menu,"\y Pierscien Zmarlego Rycerza \d[220 many]","37",0)
		menu_additem(menu,"\y Pierscien Niewidzialnosci \d[140 many]","38",0)
		menu_additem(menu,"\y Sakiewka Zlodzieja \d[150 many]","39",0)
		menu_additem(menu,"\y Revival Ring \d[80 many]","40",0)
		menu_additem(menu,"\y Assassin Demonow \d[170 many]","41",0)
		menu_additem(menu,"\y Mystiqe \d[100 many]","42",0)
		menu_additem(menu,"\y Apocalypse Anihilation \d[240 many]","43",0)
		menu_additem(menu,"\y M4A1 Special \d[150 many]","44",0)
		menu_additem(menu,"\y Ak47 Special \d[150 many]","45",0)
		menu_additem(menu,"\y Awp Special \d[130 many]","46",0)
                menu_additem(menu,"\y Deagle Special \d[140 many]","47",0)
                menu_additem(menu,"\y M3 Special \d[145 many]","48",0)
		menu_additem(menu,"\y Full Special \d[210 many]","49",0)
		menu_additem(menu,"\y Full Anty Special \d[50 many]","50",0)
		menu_additem(menu,"\y Fortuna Gheeda \d[148 many]","51",0)
		menu_additem(menu,"\y Winter Totem \d[30 many]","52",0)
		menu_additem(menu,"\y Cash Totem \d[40 many]","53",0)
		menu_additem(menu,"\y Thief Totem \d[50 many]","54",0)
		menu_additem(menu,"\y Weapon Totem \d[80 many]","55",0)
		menu_additem(menu,"\y Flash Totem \d[80 many]","56",0)
                menu_setprop(menu,MPROP_EXIT,MEXIT_ALL)
                menu_setprop(menu,MPROP_EXITNAME,"Wyjscie")
                menu_setprop(menu,MPROP_NEXTNAME,"Dalej")
                menu_setprop(menu,MPROP_BACKNAME,"Wroc")
                menu_display(id,menu,0)
        }
}
public wybor_menum3(id,menu,item)
{
        
        if(item==MENU_EXIT)
        {
                menu_destroy(menu)
                return PLUGIN_HANDLED
        }
        
        new data[6], iName[64]
        new access, callback
        
        menu_item_getinfo(menu, item, access, data,5, iName, 63, callback);
        
        new key = str_to_num(data)
        
        switch(key)
        {
                case 0: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 1: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 2: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 3: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 4: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 5: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 6: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 7: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 8: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 9: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 10: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 11: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 12: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 13: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 14: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 15: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 16: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 17: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 18: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 19: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 20: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 21: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 22: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 23: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 24: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
		case 25: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 26: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 27: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 28: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 29: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 30: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 31: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 32: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 33: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 34: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
		case 35: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 36: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 37: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 38: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 39: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 40: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 41: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 42: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 43: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 44: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
		case 45: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 46: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 47: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 48: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 49: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 50: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
                case 51: {
                        show_motd(id, "addons/data/lang/1.txt4")
                }
		case 52: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 53: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 54: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
		case 55: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
                case 56: {
                        show_motd(id, "addons/data/lang/1.txt3")
                }
        }
        return PLUGIN_HANDLED
}
public menum5(id)
{
        if(cs_get_user_team(id) == CS_TEAM_CT || cs_get_user_team(id) == CS_TEAM_T)
        {
                new menu = menu_create("\yInne","wybor_menum5")
                
                menu_additem(menu,"\wLosowy Item \d[10 many]","0",0)
                menu_additem(menu,"\wUlepszenie Itemu \d[10 many]","1",0)
                menu_setprop(menu,MPROP_EXIT,MEXIT_ALL)
                menu_setprop(menu,MPROP_EXITNAME,"Wyjscie")
                menu_setprop(menu,MPROP_NEXTNAME,"Dalej")
                menu_setprop(menu,MPROP_BACKNAME,"Wroc")
                menu_display(id,menu,0)
        }
}
public wybor_menum5(id,menu,item)
{
        
        if(item==MENU_EXIT)
        {
                menu_destroy(menu)
                return PLUGIN_HANDLED
        }
        
        new data[6], iName[64]
        new access, callback
        
        menu_item_getinfo(menu, item, access, data,5, iName, 63, callback);
        
        new key = str_to_num(data)
        
        switch(key)
        {
                case 0: {
                        show_motd(id, "addons/data/lang/1.txt")
                }
                case 1: {
                        show_motd(id, "addons/data/lang/1.txt2")
                }
        }
        return PLUGIN_HANDLED
}
public mymenu(id){
	new MyMenu=menu_create("Test","cbMyMenu");
	
	menu_additem(MyMenu,"los");//item=0
	menu_additem(MyMenu,"Czesc");//item=1
	menu_additem(MyMenu,"Nq");//item=2
	
	menu_display(id, MyMenu,0);
	return PLUGIN_HANDLED;
}
public cbMyMenu(id, menu, item){
	switch(item){
		case 0:
		{
			new koszt = 4;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[SKLEP]^x01 Nie masz wystarczajacej ilosci many.");
				return PLUGIN_CONTINUE;
			}
			mana_gracza[id] -= koszt;
			award_item(id,0)
		}
		case 1:{
			client_cmd(id, "say Czesc");
		}
		case 2:{
			client_cmd(id, "say nq");
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}*/
public mana1(id){
	new mana1=menu_create("Магазин золота","mana1a");
	
	menu_additem(mana1,"\yОружие");//item=0
	menu_additem(mana1,"\yДругое");//item=2
	
	menu_display(id, mana1,0);
	return PLUGIN_HANDLED;
}
public mana1a(id, menu, item)
{
	switch(item)
	{
		case 0:
		{
			if(!g_bWeaponsDisabled)
			{
				mana2(id)
			}
			else
			{
				hudmsg(id,5.0,"На этой карте оружие не выдаётся!")
			}
		}
		case 1:
		{
			mana4(id)
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
public mana2(id){
	new mana2=menu_create("Магазин оружия","mana2a");
	
	menu_additem(mana2,"\y M4A1 + Патроны \d[10 золота]")
	menu_additem(mana2,"\y AK47 + Патроны \d[7 золота]")
	menu_additem(mana2,"\y AWP + Патроны \d[10 золота]")
	menu_additem(mana2,"\y Famas + Патроны \d[5 золота]")
	menu_additem(mana2,"\y Galil + Патроны \d[5 золота]")
	menu_additem(mana2,"\y M249 + Патроны \d[13 золота]")
	menu_additem(mana2,"\y Mp5 + Патроны \d[4 золота]")
	menu_additem(mana2,"\y Scout + Патроны \d[6 золота]")
	menu_additem(mana2,"\y M3 Pompa + Патроны \d[7 золота]")
	menu_additem(mana2,"\y XM1014 Pompa + Патроны \d[7 золота]")
	menu_additem(mana2,"\y P90 + Патроны \d[4 золота]")
	menu_additem(mana2,"\y Deagle + Патроны \d[2 золота]")
	menu_additem(mana2,"\y Aug + Патроны \d[8 золота]")
	menu_additem(mana2,"\y SG552 + Патроны \d[8 золота]")
	menu_additem(mana2,"\y Nightvision \d[5 золота]")
	menu_setprop(mana2,MPROP_EXIT,MEXIT_ALL)
	menu_setprop(mana2,MPROP_EXITNAME,"Выход")
	menu_setprop(mana2,MPROP_NEXTNAME,"Далее")
	menu_setprop(mana2,MPROP_BACKNAME,"Назад")
	
	menu_display(id, mana2,0);
	return PLUGIN_HANDLED;
}
public mana2a(id, menu, item){
	switch(item)
	{
		case 0:
		{
			new koszt = 10;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id, "weapon_m4a1")
				cs_set_user_bpammo(id, CSW_M4A1, 90)
			}
		}
		case 1:
		{
			new koszt = 7;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_ak47")
				cs_set_user_bpammo(id, CSW_AK47, 90)
			}
		}
		case 2:
		{
			new koszt = 10;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_awp")
				cs_set_user_bpammo(id, CSW_AWP, 30)
			}
		}
		case 3:
		{
			new koszt = 5;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_famas")
				cs_set_user_bpammo(id, CSW_FAMAS, 90)
			}
		}
		case 4:
		{
			new koszt = 5;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_gali")
				cs_set_user_bpammo(id, CSW_GALI, 90)
			}
		}
		case 5:
		{
			new koszt = 13;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_m249")
				cs_set_user_bpammo(id, CSW_M249, 200)
			}
		}
		case 6:
		{
			new koszt = 4;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_mp5navy")
				cs_set_user_bpammo(id, CSW_MP5NAVY, 120)
			}
		}
		case 7:
		{
			new koszt = 6;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_scout")
				cs_set_user_bpammo(id, CSW_SCOUT, 90)
			}
		}
		case 8:
		{
			new koszt = 7;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_m3")
				cs_set_user_bpammo(id, CSW_M3, 32)
			}
		}
		case 9:
		{
			new koszt = 7;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_xm1014")
				cs_set_user_bpammo(id, CSW_XM1014, 32)
			}
		}
		case 10:
		{
			new koszt = 4;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_p90")
				cs_set_user_bpammo(id, CSW_P90, 100)
			}
		}
		case 11:
		{
			new koszt = 2;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_deagle")
				cs_set_user_bpammo(id, CSW_DEAGLE, 35)
			}
		}
		case 12:
		{
			new koszt = 8;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_aug")
				cs_set_user_bpammo(id, CSW_AUG, 90)
			}
		}
		case 13:
		{
			new koszt = 8;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id,"weapon_sg552")
				cs_set_user_bpammo(id, CSW_SG550, 90)
			}
		}
		case 14:
		{
			new koszt = 5;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				fm_give_item(id, "item_nvgs")
			}
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
/*public mana3(id)
{
	new mana3=menu_create("Магазин Item","mana3a");
	
	menu_additem(mana3,"\y Vampyric Scepter \d[10 золота]")
	menu_additem(mana3,"\y Small bronze bag \d[40 золота]")
	menu_additem(mana3,"\y Medium silver bag \d[50 золота]")
	menu_additem(mana3,"\y Large gold bag \d[60 золота]")
	menu_additem(mana3,"\y Small angel wings \d[100 золота]")
	menu_additem(mana3,"\y Arch angel wings \d[130 золота]")
	menu_additem(mana3,"\y Firerope \d[40 золота]")
	menu_additem(mana3,"\y Fire Amulet \d[60 золота]")
	menu_additem(mana3,"\y Stalkers ring \d[140 золота]")
	menu_additem(mana3,"\y Gold statue \d[25 золота]")
	menu_additem(mana3,"\y Daylight Diamond \d[40 золота]")
	menu_additem(mana3,"\y Blood Diamond \d[60 золота]")
	menu_additem(mana3,"\y Wheel of Fortune \d[30 золота]")
	menu_additem(mana3,"\y Sword of the sun \d[40 золота]")
	menu_additem(mana3,"\y Fireshield \d[85 золота]")
	menu_additem(mana3,"\y Stealth Shoes \d[10 золота]")
	menu_additem(mana3,"\y Meekstone \d[70 золота]")
	menu_additem(mana3,"\y Godly Armor \d[50 золота]")
	menu_additem(mana3,"\y Knife Ruby \d[25 золота]")
	menu_additem(mana3,"\y Sword \d[45 золота]")
	menu_additem(mana3,"\y Scout Extender \d[70 золота]")
	menu_additem(mana3,"\y Scout Amplifier \d[100 золота]")
	menu_additem(mana3,"\y Iron Spikes \d[50 золота]")
	menu_additem(mana3,"\y Paladin ring \d[60 золота]")
	menu_additem(mana3,"\y Monk ring \d[80 золота]")
	menu_additem(mana3,"\y Flashbang necklace \d[30 золота]")
	menu_additem(mana3,"\y Khalim Eye \d[100 золота]")
	menu_additem(mana3,"\y Hydra Blade \d[80 золота]")
	menu_additem(mana3,"\y Exp Ring \d[70 золота]")
	menu_additem(mana3,"\y Aegis \d[90 золота]")
	menu_additem(mana3,"\y Heavenly Stone \d[70 золота]")
	menu_additem(mana3,"\y Festering Essence of Destruction \d[140 золота]")
	menu_additem(mana3,"\y Centurion \d[170 many]","32")
	menu_additem(mana3,"\y Dr House \d[100 many]","33")
	menu_additem(mana3,"\y Own Invisible \d[300 золота]")
	menu_additem(mana3,"\y Mega Invisible \d[300 золота]")
	menu_additem(mana3,"\y Bul'Kathos Shoes \d[30 золота]")
	menu_additem(mana3,"\y Karik's Ring \d[220 золота]")
	menu_additem(mana3,"\y Purse Thief \d[150 золота]")
	menu_additem(mana3,"\y Revival Ring \d[80 золота]")
	menu_additem(mana3,"\y Demon Assassin \d[170 many]","41")
	menu_additem(mana3,"\y Mystiqe \d[100 many]","42")
	menu_additem(mana3,"\y Apocalypse Anihilation \d[240 many]","43")
	menu_additem(mana3,"\y M4A1 Special \d[150 золота]")
	menu_additem(mana3,"\y Ak47 Special \d[150 золота]")
	menu_additem(mana3,"\y AWP Special \d[130 золота]")
	menu_additem(mana3,"\y Deagle Special \d[140 золота]")
	menu_additem(mana3,"\y M3 Special \d[145 золота]")
	menu_additem(mana3,"\y Full Special \d[210 золота]")
	menu_additem(mana3,"\y Hellspawn \d[50 золота]")
	menu_additem(mana3,"\y Gheed's Fortune \d[148 золота]")
	menu_additem(mana3,"\y Winter Totem \d[30 золота]")
	menu_additem(mana3,"\y Cash Totem \d[40 золота]")
	menu_additem(mana3,"\y Thief Totem \d[50 золота]")
	menu_additem(mana3,"\y Weapon Totem \d[80 золота]")
	menu_additem(mana3,"\y Flash Totem \d[80 золота]")
	menu_setprop(mana3,MPROP_EXIT,MEXIT_ALL)
	menu_setprop(mana3,MPROP_EXITNAME,"Выход")
	menu_setprop(mana3,MPROP_NEXTNAME,"Далее")
	menu_setprop(mana3,MPROP_BACKNAME,"Назад")
	
	menu_display(id, mana3,0);
	return PLUGIN_HANDLED;
}
public mana3a(id, menu, item){
	switch(item){
		case 0:
		{
			new koszt = 10;
			if (mana_gracza[id]<koszt && player_item_id[id] != 0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,6)
			}
		}
		case 1:{
			new koszt = 40;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,7)
			}
		}
		case 2:{
			new koszt = 50;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,8)
			}
		}
		case 3:{
			new koszt = 60;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,9)
			}
		}
		case 4:{
			new koszt = 100;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,10)
			}
		}
		case 5:{
			new koszt = 130;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,11)
			}
		}
		case 6:{
			new koszt = 40;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,15)
			}
		}
		case 7:{
			new koszt = 60;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,16)
			}
		}
		case 8:{
			new koszt = 140;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,17)
			}
		}
		case 9:{
			new koszt = 25;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,23)
			}
		}
		case 10:{
			new koszt = 40;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,24)
			}
		}
		case 11:{
			new koszt = 60;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,25)
			}
		}
		case 12:{
			new koszt = 30;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,26)
			}
		}
		case 13:{
			new koszt = 40;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,29)
			}
		}
		case 14:{
			new koszt = 85;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,30)
			}
		}
		case 15:{
			new koszt = 10;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,31)
			}
		}
		case 16:{
			new koszt = 70;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,32)
			}
		}
		case 17:{
			new koszt = 50;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,37)
			}
		}
		case 18:{
			new koszt = 25;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,42)
			}
		}
		case 19:{
			new koszt = 45;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,44)
			}
		}
		case 20:{
			new koszt = 70;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,47)
			}
		}
		case 21:{
			new koszt = 100;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,48)
			}
		}
		case 22:{
			new koszt = 50;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,50)
			}
		}
		case 23:{
			new koszt = 60;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,62)
			}
		}
		case 24:{
			new koszt = 80;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,63)
			}
		}
		case 25:{
			new koszt = 30;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,65)
			}
		}
		case 26:{
			new koszt = 100;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,69)
			}
		}
		case 27:{
			new koszt = 80;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,74)
			}
		}
		case 28:{
			new koszt = 70;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,75)
			}
		}
		case 29:{
			new koszt = 90;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,76)
			}
		}
		case 30:{
			new koszt = 70;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,78)
			}
		}
		case 31:{
			new koszt = 140;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,79)
			}
		}
		case 32:{
			new koszt = 170;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,85)
			}
		}
		case 33:{
			new koszt = 100;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,87)
			}
		}
		case 34:{
			new koszt = 300;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,88)
			}
		}
		case 35:{
			new koszt = 300;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,89)
			}
		}
		case 36:{
			new koszt = 30;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,90)
			}
		}
		case 37:{
			new koszt = 220;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,91)
			}
		}
		case 38:{
			new koszt = 150;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,92)
			}
		}
		case 39:{
			new koszt = 80;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,94)
			}
		}
		case 40:{
			new koszt = 170;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,95)
			}
		}
		case 41:{
			new koszt = 100;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,96)
			}
		}
		case 42:{
			new koszt = 240;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,97)
			}
		}
		case 43:{
			new koszt = 150;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,104)
			}
		}
		case 44:{
			new koszt = 150;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,105)
			}
		}
		case 45:{
			new koszt = 130;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,106)
			}
		}
		case 46:{
			new koszt = 140;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,107)
			}
		}
		case 47:{
			new koszt = 145;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,108)
			}
		}
		case 48:{
			new koszt = 210;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,109)
			}
		}
		case 49:{
			new koszt = 50;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,99)
			}
		}
		case 50:{
			new koszt = 148;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,120)
			}
		}
		case 51:{
			new koszt = 30;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,121)
			}
		}
		case 52:{
			new koszt = 40;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,122)
			}
		}
		case 53:{
			new koszt = 50;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,123)
			}
		}
		case 54:{
			new koszt = 80;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,124)
			}
		}
		case 55:{
			new koszt = 80;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,125)
			}
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
*/
public mana4(id){
	new mana4=menu_create("Предметы - Другое","mana4a");
	
	menu_additem(mana4,"\wОружие")
	menu_additem(mana4,"\wСлучайный предмет \d[10 золота]")
	menu_additem(mana4,"\wУлучшить предмет \d[2 золота]")
	menu_additem(mana4,"\wСвиток портала \d[25 золота]")
	menu_additem(mana4,"\dЗелье противоядия [золота]")
	menu_additem(mana4,"\dЗелье оттаивания [золота]")
	menu_additem(mana4,"\dЗелье охлаждения [золота]")
	menu_setprop(mana4,MPROP_EXIT,MEXIT_ALL)
	menu_setprop(mana4,MPROP_EXITNAME,"Выход")
	menu_setprop(mana4,MPROP_NEXTNAME,"Далее")
	menu_setprop(mana4,MPROP_BACKNAME,"Назад")
	
	menu_display(id, mana4,0);
	return PLUGIN_HANDLED;
}
public mana4a(id, menu, item)
{
	switch(item)
	{
		case 0:
		{
			if(!g_bWeaponsDisabled)
			{
				mana2(id)
			}
			else
			{
				hudmsg(id,5.0,"На этой карте оружие не выдаётся!")
				mana4(id)
			}
		}
		case 1:
		{
			new koszt = 10;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота или у вас уже есть item");
				mana4(id)
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				award_item(id,0)
			}
		}
		case 2:
		{
			new koszt = 2;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				mana4(id)
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				emit_sound(id,CHAN_STATIC,"diablo_lp/repair.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
				mana_gracza[id] -= koszt;
				upgrade_item(id)
			}
		}
		case 3:
		{
			new koszt = 25;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[МАГАЗИН]^x01 Не хватает золота.");
				mana4(id)
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
				mana_gracza[id] -= koszt;
				player_portal[id] = 1;
				player_portals[id] = 0;
				client_print(id,print_chat,"Наведите прицел на место размещения портала и нажмите установить.");
				client_print(id,print_chat,"Чтобы снова открыть меню портала наберите say portal");
				cmd_place_portal(id);
			}
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
public hook_team_select(id,key)
{
	if((key==0)&&(player!=0))
	{
		engclient_cmd(id,"chooseteam")
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public glow_player(id, Float:time, red, green, blue)
{
	
	
	set_user_rendering( id, kRenderFxGlowShell, red, green, blue, kRenderNormal, 30 );
	remove_task(id+TASKID_GLOW);
	set_task(time, "unglow_player", id+TASKID_GLOW, "", 0, "a", 1);
	
	return;
}

public unglow_player(id)
{
	id-=TASKID_GLOW;
	set_renderchange(id);
	remove_task(id+TASKID_GLOW);	
}

public cmdUnmakeBoss(id,level,cid){
	if(cmd_access(id,level,cid,1))set_task(5.0,"UnmakeBoss")
	return PLUGIN_HANDLED
}

public hook_teamscore(){
	new score=read_data(2)
	if((score>0)&&(player!=0))UnmakeBoss()
	return PLUGIN_CONTINUE	
}

public UnmakeBoss(){
	if(player==0)return
	if(is_user_connected(player))
		set_user_rendering(player,kRenderFxGlowShell,0,0,0,kRenderNormal,99)
	player=0
	set_cvar_num("mp_autoteambalance",old_mp_autoteambalance)
	set_cvar_float("mp_roundtime",old_mp_roundtime)
	set_cvar_float("mp_buytime",old_mp_buytime)
	set_cvar_num("mp_freezetime",old_mp_freezetime)
	set_cvar_num("mp_startmoney",old_mp_startmoney)
	set_cvar_num("sv_restart",1)
}

public cmdMakeBoss(id,level,cid){
	if(!cmd_access(id,level,cid,3))return PLUGIN_HANDLED
	if(player!=0){
		client_print(id,print_console,"There already exists a boss")
		return PLUGIN_HANDLED
	}
	new arg[32]
	read_argv(1,arg,31)
	player=cmd_target(id,arg,6)
	if(!player)return PLUGIN_HANDLED
	read_argv(2,arg,31)
	bossPower=10000
	new players[32], num, i
	get_players(players,num)
	for(i=0;i<num;i++)
		if(players[i]!=player){
			get_user_team(players[i],arg,31)
			if(arg[0]!='S')cs_set_user_team(players[i],CS_TEAM_CT)
		}else
			cs_set_user_team(player,CS_TEAM_T,CS_T_GUERILLA);
	old_mp_autoteambalance=get_cvar_num("mp_autoteambalance")
	old_mp_roundtime=get_cvar_float("mp_roundtime")
	old_mp_buytime=get_cvar_float("mp_buytime")
	old_mp_startmoney=get_cvar_num("mp_startmoney")
	old_mp_freezetime=get_cvar_num("mp_freezetime")
	set_cvar_num("mp_autoteambalance",0)
	set_cvar_num("mp_roundtime",9)
	set_cvar_num("mp_startmoney",16000)
	set_cvar_num("sv_restart",1)
	set_cvar_float("mp_buytime",0.2)
	set_cvar_num("mp_freezetime",12)
	set_task(13.0,"MakeBoss2")
	return PLUGIN_HANDLED
}

public MakeBoss2(){
	if(is_user_connected(player)){
		set_user_health(player,bossPower)
		set_user_armor(player,100)
		set_user_rendering(player,kRenderFxGlowShell,255,0,0,kRenderNormal,99)
		strip_user_weapons(player)
		give_item(player,"weapon_knife")
		give_item(player,"weapon_m249")
		new i
		for(i=0;i<7;i++)give_item(player,"ammo_556natobox")
	}else
		UnmakeBoss()
	set_hudmessage(255,0,0)
	show_hudmessage(0,"Противник опасен!")
}
public cmdBlyskawica(id)
{
    if(!is_user_alive(id)) return PLUGIN_HANDLED;
	
    if(!ilosc_blyskawic[id])
	{
		client_print(id,print_center,"У вас нет молний");
		return PLUGIN_HANDLED;
    }
    if(poprzednia_blyskawica[id]+5.0>get_gametime()) 
	{
		client_print(id,print_center,"Пускать молнии можно раз в 5 секунд.");
		return PLUGIN_HANDLED;
    }
    new ofiara, body;
    get_user_aiming(id, ofiara, body);
    
    if(is_user_alive(ofiara))
	{
		new Float:dmg = float((player_intelligence[id] - player_dextery[ofiara])/2);
		if(dmg < 1.0) { dmg = 1.0; }
		puscBlyskawice(id, ofiara, dmg);
		ilosc_blyskawic[id]--;
		poprzednia_blyskawica[id]=get_gametime()
    }
	else
	{
		client_print(id,print_center,"Нет целей.");
	}
    return PLUGIN_HANDLED;
}
stock Create_TE_BEAMENTS(startEntity, endEntity, iSprite, startFrame, frameRate, life, width, noise, red, green, blue, alpha, speed)
{

    message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
    write_byte( TE_BEAMENTS )
    write_short( startEntity )        // start entity
    write_short( endEntity )        // end entity
    write_short( iSprite )            // model
    write_byte( startFrame )        // starting frame
    write_byte( frameRate )            // frame rate
    write_byte( life )                // life
    write_byte( width )                // line width
    write_byte( noise )                // noise amplitude
    write_byte( red )                // red
    write_byte( green )                // green
    write_byte( blue )                // blue
    write_byte( alpha )                // brightness
    write_byte( speed )                // scroll speed
    message_end()
}

stock Create_ScreenFade(id, duration, holdtime, fadetype, red, green, blue, alpha)
{

	message_begin( MSG_ONE,g_msg_screenfade,{0,0,0},id )			
	write_short( duration )			// fade lasts this long duration
	write_short( holdtime )			// fade lasts this long hold time
	write_short( fadetype )			// fade type (in / out)
	write_byte( red )				// fade red
	write_byte( green )				// fade green
	write_byte( blue )				// fade blue
	write_byte( alpha )				// fade alpha
	message_end()
}

puscBlyskawice(id, victim, Float:fObrazenia)
{
	new Float:fCzas = 1.0;
	
	//Piorun
	if(player_class[id] == Diablo)
	{
		Create_TE_BEAMENTS(id, victim, diablolght, 0, 10, floatround(fCzas*10), 150, 5, 200, 200, 200, 200, 10);
	}
	else
	{
		Create_TE_BEAMENTS(id, victim, sprite, 0, 10, floatround(fCzas*10), 150, 5, 200, 200, 200, 200, 10);
	}
	glow_player(victim, 1.0, 255, 255, 255)
	d2_damage( victim, id, floatround( fObrazenia ), "diablomod Lightning")
		
	//Dzwiek
	emit_sound(id,CHAN_STATIC,gszSound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}