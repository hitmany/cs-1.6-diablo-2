/* ================================================================================================ /
*
*	Diablo Mod: 
*	------------------
*
*	Need:		This compiled and items files
*	Works with:	AMXX � Cs 1.6
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


#define RESTORETIME 30.0	 //How long from server start can players still get their item trasferred (s)
#define MAX 32			 //Max number of valid player entities

//#define CHEAT 1		 //Cheat for testing purposes
#define CS_PLAYER_HEIGHT 72.0
#define GLOBAL_COOLDOWN 0.5
#define TASK_GREET 240
#define TASK_HUD 120
#define TASK_HOOK 360
#define MAX_PLAYERS 32
#define BASE_SPEED 	245.0
#define GLUTON 95841
#define TASK_GOD 129
new Float:agi=BASE_SPEED
new round_status
new DemageTake[33]
new DemageTake1[33]
//new weapon, clip, ammo
#define x 0
#define y 1
#define z 2

#define TASK_CHARGE 100
#define TASK_NAME 48424
#define TASK_FLASH_LIGHT 81184

#define TASKID_REVIVE 	1337
#define TASKID_RESPAWN 	1338
#define TASKID_CHECKRE 	1339
#define TASKID_CHECKST 	13310
#define TASKID_ORIGIN 	13311
#define TASKID_SETUSER 	13312
#define FL_ONGROUND (1<<9)
#define message_begin_f(%1,%2,%3,%4) engfunc(EngFunc_MessageBegin, %1, %2, %3, %4)
#define write_coord_f(%1) engfunc(EngFunc_WriteCoord, %1)

#define pev_zorigin	pev_fuser4
#define seconds(%1) ((1<<12) * (%1))

#define OFFSET_CAN_LONGJUMP    356

#define MAX_FLASH 15		//pojemnosc barejii maga (sekund)

new SOUND_START[] 	= "items/medshot4.wav"
new SOUND_FINISHED[] 	= "items/smallmedkit2.wav"
new SOUND_FAILED[] 	= "items/medshotno1.wav"
new SOUND_EQUIP[]	= "items/ammopickup2.wav"

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
new c4state[33]
new c4bombc[33][3] 
new c4fake[33]
new fired[33]
new bool:ghost_check
new ghosttime[33]
new ghoststate[33]
new naswietlony[33]

new sprite_blood_drop = 0
new sprite_blood_spray = 0
new sprite_gibs = 0
new sprite_white = 0
new sprite_fire = 0
new sprite_beam = 0
new sprite_boom = 0
new sprite_line = 0
new sprite_lgt = 0
new sprite_laser = 0
new sprite_ignite = 0
new sprite_smoke = 0
new sprite_blast;
new sprite;

new player_xp[33] = 0		//Holds players experience
new player_lvl[33] = 1			//Holds players level
new player_point[33] = 0		//Holds players level points
new player_item_id[33] = 0	//Items id
new player_item_name[33][128]   //The items name
new player_intelligence[33]
new player_strength[33]
new player_agility[33]
new mana_gracza[33]
new Float:player_damreduction[33]
new player_dextery[33]
new player_class[33]		
new Float:player_huddelay[33]

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
new c_blink[33]
new lustrzany_pocisk[33] = 1
new c_redirect[33]
new losowe_itemy[33]
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
new c_piorun[33]
new skinchanged[33]
new player_dc_name[33][99]	//Information about last disconnected players name
new player_dc_item[33]		//Information about last disconnected players item
new player_sword[33] 		//nowyitem
new player_ring[33]		//ring stats bust +5
new Float:poprzednia_rakieta_gracza[33];
new ilosc_rakiet_gracza[33];
new ilosc_blyskawic[33],poprzednia_blyskawica[33];
//new ilosc_dynamitow_gracza[33];
new Float:g_wallorigin[33][3]
new cel // do pokazywania statusu
new item_info[513] //id itemu  
new item_name[513][128] //nazwa itemu
new const modelitem[]="models/winebottle.mdl" //tutaj zmieniacie model itemu
new const gszSound[] = "ambience/thunder_clap.wav";
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

new cbow_VIEW[]  = "models/diablomod/v_crossbow.mdl" 
new cvow_PLAYER[]= "models/diablomod/p_crossbow.mdl" 
new cbow_bolt[]  = "models/diablomod/Crossbow_bolt.mdl"

new LeaderCT = -1
new LeaderT = -1

new JumpsLeft[33]
new JumpsMax[33]

new loaded_xp[33]
new sqlstart = 30 // Tyle prob jest na mape na poprawne polaczenie - bo cos sie zapetla gdy wylancza sie serwer (zmiena mapy?)
new asked_sql[33]
new asked_klass[33]
new olny_one_time=0

enum { NONE = 0, Mag, Monk, Paladin, Assassin, Necromancer, Barbarian, Ninja, Amazon, Andariel, Duriel, Mephisto, Hephasto, Diablo, Baal, Fallen, Imp, Izual, Jumper, Enslaved, Kernel, PoisonCreeper, GiantSpider, SnowWanderer, Griswold, TheSmith, Demonolog, VipCztery }
new Race[28][18] = { "���","Mag","Monk","Paladin","Assassin","Necromancer","Barbarian", "Ninja", "Amazon","Andariel", "Duriel", "Mephisto", "Hephasto", "Diablo", "Baal", "Fallen", "Imp", "Izual", "Jumper", "Enslaved", "Kernel", "Poison Creeper", "Giant Spider", "Snow Wanderer","Griswold","The Smith","Demonolog","VipCztery" }
new race_heal[28] = { 100,110,150,130,140,110,120,170,140,110,130,120,140,130,120,123,110,135,135,127,130,140,115,135,145,145,145,145 }

new LevelXP[101] = { 0,50,125,225,340,510,765,1150,1500,1950,2550,3300,4000,4800,5800,7000,8500,9500,10500,11750,13000, //21
14300,15730,17300,19030,20900,23000,24000,25200,26400,27700,29000,30500,32000,33600,35300,37000,39000,41000,43000,45100,//41
47400,49800,52300,55000,57800,60700,63700,66900,70200,73700,77400,80000,82400,84900,87500,90000,92700,95500,98300,101000,//61
104000,107000,110000,113000,116000,120000,123000,126700,130000,134000,138000,142000,146000,150000,154000,158000,163000,168000,173000,178000,//81
183000,188000,194000,200000,206000,212000,218000,225000,232000,239000,246000,253000,261000,269000,277000,285000,294000,303000,500000,9999999/*101*/}

new player_class_lvl[33][28]
new player_class_lvl_save[33]

new player_xp_old[33]

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
new button[33]

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
new Float:cast_end[33]
new on_knife[33]
new golden_bulet[33]
new ultra_armor[33]
new after_bullet[33]
new num_shild[33]
new invisible_cast[33]
new player_dmg[33]

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
	{1,2,Ninja,500,0},
	{1,3,Mag,1200,1},
	{1,6,Assassin,2000,0},
	{2,6,Amazon,5000,0},
	{2,15,Barbarian,15000,1},
	{2,20,Paladin,20000,1},
	{3,65,Barbarian,150000,1},
	{3,120,Paladin,200000,1}
}

new vault_questy;
new vault_questy2;

//od , do , hp
new prze[][]={
	{1,50,20},
	{51,80,40},
	{81,140,60}
}

new prze_wybrany[33]

new questy_info[][]={
	"���� 2 Ninja (������ 500 �����)",
	"���� 3 Mag (������ 1200 �����)",
	"���� 6 Assassin (������ 2000 �����)",
	"���� 6 Amazon (������ 5000 �����)",
	"���� 15 Barbarian (������ 15000 �����)",
	"���� 20 Paladin (������ 20000 �����)",
	"���� 65 Barbarian (������ 150000 �����)",
	"���� 120 Paladin (������ 200000 �����)"
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
	new map[32]
	get_mapname(map,31)
	new times[64]
	get_time("%m/%d/%Y - %H:%M:%S" ,times,63)
	log_to_file("addons/amxmodx/logs/diablo.log","%s ### MAP: %s ### ",times,map)
	
	register_cvar("diablo_sql_host","localhost",FCVAR_PROTECTED)
	register_cvar("diablo_sql_user","root",FCVAR_PROTECTED)
	register_cvar("diablo_sql_pass","Ahluxi5AeC",FCVAR_PROTECTED)
	register_cvar("diablo_sql_database","dbmod",FCVAR_PROTECTED)
	
	register_cvar("diablo_sql_table","dbmod_table222",FCVAR_PROTECTED)
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

	register_message(g_msg_clcorpse, "message_clcorpse")
	
	register_event("HLTV", 		"event_hltv", 	"a", "1=0", "2=0")
	
	register_forward(FM_Touch, 		"fwd_touch")
	register_forward(FM_Touch, "fwTouch")
	register_forward(FM_EmitSound, 		"fwd_emitsound")
	register_forward(FM_PlayerPostThink, 	"fwd_playerpostthink")
	RegisterHam(Ham_TakeDamage, "player", "lustrzanypocisk")

	
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
	register_event("Damage", "Damage", "b", "2!0")
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
	register_clcmd("flash", "cmdBlyskawica");
	register_concmd("rocket","StworzRakiete")
	register_concmd("pluginflash","Flesh")
	//register_concmd("dynamit","PolozDynamit")
	register_concmd("paladin","check_palek")
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
	
	register_clcmd("say class","changerace")
        register_clcmd("say /who","cmd_who")	
	register_clcmd("say /skills", "showskills")
	register_clcmd("say skills", "showskills")
	register_clcmd("say /menu","showmenu") 
	register_clcmd("menu","showmenu")
	register_clcmd("say /commands","komendy")
	//register_clcmd("pomoc","helpme") 
	register_clcmd("say /rune","buyrune") 
	register_clcmd("rune","buyrune")
	register_clcmd("say /r","buyrune")
	register_clcmd("say /savexp","savexpcom")
	//register_clcmd("say /loadxp","LoadXP")
	register_clcmd("say /reset","reset_skill")
	register_clcmd("say /exp", "exp")
	register_clcmd("say exp", "exp")
	register_clcmd("reset","reset_skill")	 
	//register_clcmd("/reset","reset_skill")
	register_clcmd("say /mana","mana1")
	register_clcmd("say /m","mana1")
		
	register_clcmd("mod","mod_info")
	
	register_menucmd(register_menuid("������ �����"), 1023, "skill_menu")
	register_menucmd(register_menuid("�����"), 1023, "option_menu")
	register_menucmd(register_menuid("������ �����"), 1023, "select_class_menu")
	register_menucmd(register_menuid("������� ���"), 1023, "select_rune_menu")
	register_menucmd(register_menuid("����� ��������"), 1023, "nowe_itemy")
	register_menucmd(register_menuid("������"), 1023, "PressedKlasy")
	register_menucmd(register_menuid("�����"), 1023, "PokazMeni")
	register_menucmd(register_menuid("��������"), 1023, "PokazZwierz")
	register_menucmd(register_menuid("�������"), 1023, "PokazPremium")
	gmsgDeathMsg = get_user_msgid("DeathMsg")
	gmsgStatusText = get_user_msgid("StatusText")
	gmsgBartimer = get_user_msgid("BarTime") 
	gmsgScoreInfo = get_user_msgid("ScoreInfo") 
	register_cvar("diablo_dmg_exp","20",0)
	register_cvar("diablo_xpbonus","5",0)
	register_cvar("diablo_xpbonus2","50",0)
	register_cvar("diablo_xpbonus3","20",0)
	register_cvar("diablo_durability","5",0) 
	register_cvar("SaveXP", "1")
	set_msg_block ( gmsgDeathMsg, BLOCK_SET ) 
	set_task(5.0, "Timed_Healing", 0, "", 0, "b")
	set_task(1.0, "radar_scan", 0, _, _, "b"); // radar
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
	register_forward(FM_AddToFullPack, "client_AddToFullPack")
	register_event("SendAudio","freeze_over1","b","2=%!MRAD_GO","2=%!MRAD_MOVEOUT","2=%!MRAD_LETSGO","2=%!MRAD_LOCKNLOAD")
	register_event("SendAudio","freeze_begin1","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw")

	register_forward(FM_PlayerPreThink, "Forward_FM_PlayerPreThink")
		
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
	
	register_cvar("diablo_knife","20")
	register_cvar("diablo_knife_speed","1000")
	
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
	
	register_cvar("diablo_arrow","120.0")
	register_cvar("diablo_arrow_multi","2.0")
	register_cvar("diablo_arrow_speed","1500")
	
	register_cvar("diablo_klass_delay","2.5")
	pHook = 	register_cvar("sv_hook", "1")
	pThrowSpeed = 	register_cvar("sv_hookthrowspeed", "1000")
	pSpeed = 	register_cvar("sv_hookspeed", "300")
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
	
	return PLUGIN_CONTINUE  
}
public menu_questow(id){
	if(quest_gracza[id] == -1 || quest_gracza[id] == -2){
		
		new menu = menu_create("���� �������","menu_questow_handle")
		new formats[128]
		for(new i = 0;i<sizeof prze;i++){
			formatex(formats,127,"������ �� %d �� %d ������",prze[i][0],prze[i][1]);
			menu_additem(menu,formats)
		}
		menu_display(id,menu,0)
	}
	else
	{
		client_print(id,print_chat,"�� �� ��������� ���������� �������")
	}
}

public menu_questow_handle(id,menu,item){
	if(item == MENU_EXIT){
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	if(player_lvl[id] < prze[item][0]){
		client_print(id,print_chat,"��� ������� ������ ����������!");
		menu_questow(id)
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	new formats[128]
	formatex(formats,127,"������ �� %d �� %d ������",prze[item][0],prze[item][1]);
	new menu2 = menu_create(formats,"menu_questow_handle2")
	for(new i = 0;i<sizeof(questy);i++){
		if(questy[i][0] == item+1){
			menu_additem(menu2,questy_info[i]);
		}
	}
	menu_setprop(menu2, MPROP_EXITNAME, "�����");
	menu_setprop(menu2, MPROP_BACKNAME, "�����");
	menu_setprop(menu2, MPROP_NEXTNAME, "������");
	prze_wybrany[id] = item+1;
	menu_display(id,menu2)
	return PLUGIN_CONTINUE;
}

public zapisz_questa(id,quest){
	new name[64];
	get_user_name(id,name,63)
	strtolower(name)
	new key[64];
	format(key,63,"questy-%i-%s-%i",player_class[id],name,quest);
	nvault_set(vault_questy,key,"1");
}

public zapisz_aktualny_quest(id){
	new name[64];
	get_user_name(id,name,63)
	strtolower(name)
	new key[256];
	format(key,255,"questy-%d-%s",player_class[id],name);
	new data[32]
	formatex(data,charsmax(data),"#%d#%d",quest_gracza[id]+1,ile_juz[id]);
	nvault_set(vault_questy2,key,data);
}

public wczytaj_aktualny_quest(id){
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

public wczytaj_questa(id,quest){
	new name[64];
	get_user_name(id,name,63)
	strtolower(name)
	new key[64];
	format(key,63,"questy-%i-%s-%i",player_class[id],name,quest);
	new data[64];
	nvault_get(vault_questy,key,data,63);
	return str_to_num(data);
}

public menu_questow_handle2(id,menu,item){
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
	if(questy[item][4] && !(get_user_flags(id) & ADMIN_LEVEL_H)){
		client_print(id,print_chat,"���� ����� ������ ��� VIP! ������� VIP �� lp.hitmany.net");
		menu_questow(id)
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	if(wczytaj_questa(id,item)){
		client_print(id,print_chat,"�� ��� �������� ��� ������!");
		menu_questow(id)
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}
	quest_gracza[id] = item;
	ile_juz[id] = 0
	zapisz_aktualny_quest(id)
	client_print(id,print_chat,"�� ������� �������: %s ����� !",questy_info[item]);
	quest_gracza[id] = wczytaj_aktualny_quest(id);
	menu_destroy(menu);
	return PLUGIN_CONTINUE;
}

public sql_start()
{
	if(sqlstart<0) return
	if(g_boolsqlOK) return
	
	new host[128]
	new user[64]
	new pass[64]
	new database[64]
	
	get_cvar_string("diablo_sql_database",database,63)
	get_cvar_string("diablo_sql_host",host,127)
	get_cvar_string("diablo_sql_user",user,63)
	get_cvar_string("diablo_sql_pass",pass,63)
	
	g_SqlTuple = SQL_MakeDbTuple(host,user,pass,database)
	
	
		
	get_cvar_string("diablo_sql_table",g_sqlTable,63)
	
	new q_command[512]
	format(q_command,511,"CREATE TABLE IF NOT EXISTS `%s` ( `nick` VARCHAR( 64 ),`ip` VARCHAR( 64 ),`sid` VARCHAR( 64 ), `class` integer( 2 ) , `lvl` integer( 3 ) DEFAULT 1, `exp` integer( 9 ) DEFAULT 0,  `str` integer( 3 ) DEFAULT 0, `int` integer( 3 ) DEFAULT 0, `dex` integer( 3 ) DEFAULT 0, `agi` integer( 3 ) DEFAULT 0, `man` integer( 3 ) DEFAULT 0 ) ",g_sqlTable)
	
	SQL_ThreadQuery(g_SqlTuple,"TableHandle",q_command)
}

//sql//

public TableHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	// lots of error checking
	g_boolsqlOK=1
	if(Errcode)
	{
		g_boolsqlOK=0
		log_to_file("addons/amxmodx/logs/diablo.log","Error on Table query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Could not connect to SQL database.")
		g_boolsqlOK=0
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Table Query failed.")
		g_boolsqlOK=0
		return PLUGIN_CONTINUE
	}
	 	
	LoadAVG()
	   
	return PLUGIN_CONTINUE
}


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
			
			log_to_file("addons/amxmodx/logs/test_log.log","*** %s %s *** Create Class ***",name,sid)
			
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

public create_klass_Handle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
	// lots of error checking
	if(Errcode)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Error on create class query: %s",Error)
		
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","create class Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	
	   
	return PLUGIN_CONTINUE
}

public load_xp(id)
{
	if(g_boolsqlOK /*&& */)
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
		log_to_file("addons/amxmodx/logs/diablo.log","Error on load_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","load_xp Query failed.")
		return PLUGIN_CONTINUE
	}
	   
	
	if(SQL_MoreResults(Query)) return PLUGIN_CONTINUE
	else create_klass(Data[0])		
   
	return PLUGIN_CONTINUE
}

//sql//

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
	client_print(id,print_chat,"����: %f",spd)
	
	new Float:vect[3]
	entity_get_vector(id,EV_VEC_velocity,vect)
	new Float: sped= floatsqroot(vect[0]*vect[0]+vect[1]*vect[1]+vect[2]*vect[2])
	
	client_print(id,print_chat,"������: %f",sped)
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
	precache_sound("weapons/xbow_hit2.wav")
	precache_sound("weapons/xbow_fire1.wav")
	sprite_blood_drop = precache_model("sprites/blood.spr")
	sprite_blood_spray = precache_model("sprites/bloodspray.spr")
	sprite_ignite = precache_model("addons/amxmodx/diablo/flame.spr")
	sprite_smoke = precache_model("sprites/steam1.spr")
	sprite_laser = precache_model("sprites/laserbeam.spr")
	sprite_boom = precache_model("sprites/zerogxplode.spr") 
	sprite_line = precache_model("sprites/dot.spr")
	sprite_lgt = precache_model("sprites/lgtning.spr")
	sprite_white = precache_model("sprites/white.spr") 
	sprite_fire = precache_model("sprites/explode1.spr") 
	sprite_gibs = precache_model("models/hgibs.mdl")
	sprite_beam = precache_model("sprites/zbeam4.spr") 
	sprite = precache_model("sprites/lgtning.spr");
	
	precache_model("models/player/arctic/arctic.mdl")
	precache_model("models/player/terror/terror.mdl")
	precache_model("models/player/leet/leet.mdl")
	precache_model("models/player/guerilla/guerilla.mdl")
	precache_model("models/player/gign/gign.mdl")
	precache_model("models/player/sas/sas.mdl")
	precache_model("models/player/gsg9/gsg9.mdl")
	precache_model("models/player/urban/urban.mdl")
	precache_model("models/player/vip/vip.mdl")
		
	precache_sound(SOUND_START)
	precache_sound(SOUND_FINISHED)
	precache_sound(SOUND_FAILED)
	precache_sound(SOUND_EQUIP)

	precache_sound("weapons/knife_hitwall1.wav")
	precache_sound("weapons/knife_hit4.wav")
	precache_sound("weapons/knife_deploy1.wav")
	precache_sound(gszSound);
	precache_model("models/diablomod/w_throwingknife.mdl")
	precache_model("models/diablomod/bm_block_platform.mdl")
	
	precache_model(cbow_VIEW)
        precache_model(cvow_PLAYER)
	precache_model(cbow_bolt)
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
}

public savexpcom(id)
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
		log_to_file("addons/amxmodx/logs/diablo.log","Error on Save_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Save_xp Query failed.")
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
		log_to_file("addons/amxmodx/logs/diablo.log","Error on Load_xp query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Load_xp Query failed.")
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
		log_to_file("addons/amxmodx/logs/diablo.log","Error on Load_AVG query: %s",Error)
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Could not connect to SQL database.")
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Load_AVG Query failed.")
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
				select_class_query(i)
			}
		}
	}
}

public reset_skill(id)
{	
	client_print(id,print_chat,"����� �������")
	player_point[id] = player_lvl[id]*2-2
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


public RoundStart(){
	for (new i=0; i < 33; i++){
		if(player_class[i] == Baal) {
			zmiana_skinu[i] = random(5)
			if(zmiana_skinu[i] == 1) {
				changeskin(i,0)
				ColorChat(i, TEAM_COLOR, "[��������] �� ��������� ��� ����!")
						}
							else
								changeskin(i,1)
								}
								else
								zmiana_skinu[i] = 0
		used_item[i] = false
		naswietlony[i] = 0;
		losowe_itemy[i] = 0
		uzyl_przedmiot[i] = 0
		DemageTake1[i]=1
		count_jumps(i)
		give_knife(i)
		JumpsLeft[i]=JumpsMax[i]
		kill_all_entity("przedmiot")
		
		if(player_class[i] == Necromancer) g_haskit[i]=1
		else g_haskit[i]=0
		if(player_class[i] == Amazon)
		{
			fm_give_item(i,"weapon_deagle")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
		}
		if(player_class[i] == Jumper)
		{
			fm_give_item(i,"weapon_deagle")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"weapon_ak47")
			fm_give_item(i,"ammo_762nato")
			fm_give_item(i,"ammo_762nato")
			fm_give_item(i,"ammo_762nato")
			fm_give_item(i,"ammo_762nato")
		}
		if(player_class[i] == Enslaved)
		{
			fm_give_item(i,"weapon_m4a1")
			fm_give_item(i,"ammo_556nato")
			fm_give_item(i,"ammo_556nato")
			fm_give_item(i,"ammo_556nato")
			fm_give_item(i,"ammo_556nato")
		}
		if(player_class[i] == SnowWanderer)
		{
			fm_give_item(i,"weapon_famas")
			fm_give_item(i,"ammo_556nato")
			fm_give_item(i,"ammo_556nato")
			fm_give_item(i,"ammo_556nato")
			fm_give_item(i,"ammo_556nato")
		}
		if(player_class[i] == PoisonCreeper)
		{
			fm_give_item(i,"weapon_awp")
			fm_give_item(i,"ammo_338magnum")
			fm_give_item(i,"ammo_338magnum")
			fm_give_item(i,"ammo_338magnum")
			fm_give_item(i,"ammo_338magnum")
		}
		if(player_class[i] == Kernel)
		{
			fm_give_item(i,"weapon_p90")
			fm_give_item(i,"ammo_57mm")
			fm_give_item(i,"ammo_57mm")
			fm_give_item(i,"ammo_57mm")
		}
		if(player_class[i] == Imp)
		{
			fm_give_item(i,"weapon_hegrenade")
			fm_give_item(i,"weapon_flashbang")
			fm_give_item(i,"weapon_flasgbang")
			fm_give_item(i,"weapon_smokegrenade")
		}
		if(player_class[i] == Baal)
		{
			fm_give_item(i,"weapon_m3")
			fm_give_item(i,"ammo_buckshot")
			fm_give_item(i,"ammo_buckshot")
			fm_give_item(i,"ammo_buckshot")
			fm_give_item(i,"ammo_buckshot")
			fm_give_item(i,"ammo_buckshot")
		}
		if(player_class[i] == Diablo)
		{
			fm_give_item(i,"weapon_elite")
			fm_give_item(i,"ammo_9mm")
			fm_give_item(i,"ammo_9mm")
			fm_give_item(i,"ammo_9mm")
			fm_give_item(i,"ammo_9mm")
			fm_give_item(i,"ammo_9mm")
			fm_give_item(i,"ammo_9mm")
		}
		if(player_class[i] == Hephasto)
		{
			fm_give_item(i,"weapon_hegrenade")
			fm_give_item(i,"weapon_deagle")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
			fm_give_item(i,"ammo_50ae")
		}
		
		golden_bulet[i]=0
		c_ulecz[i] = false
		if(player_class[i] == Duriel) ilosc_rakiet_gracza[i]=3
		else if(player_class[i] == Griswold) ilosc_rakiet_gracza[i]=2
		else if(player_class[i] == Demonolog) ilosc_rakiet_gracza[i]=3
		if(player_class[i] == Kernel)
		{
		ilosc_blyskawic[i]=3;
		poprzednia_blyskawica[i]=0
		}	
		else if(player_class[i] == SnowWanderer)
		{
		ilosc_blyskawic[i]=3;
		poprzednia_blyskawica[i]=0
		}
		else if(player_class[i] == TheSmith)
		{
		ilosc_blyskawic[i]=3;
		poprzednia_blyskawica[i]=0
		}
		//else ilosc_rakiet_gracza[i]=0
		/*if(player_class[i] == Kernel) ilosc_dynamitow_gracza[i]=1
		else if(player_class[i] == SnowWanderer) ilosc_dynamitow_gracza[i]=1
		else if(player_class[i] == TheSmith) ilosc_dynamitow_gracza[i]=1*/
		//else ilosc_rakiet_gracza[i]=0
		
		
		invisible_cast[i]=0
		niewidka[i] = 0
		
		ultra_armor[i]=0
		lustrzany_pocisk[i]=0
		num_shild[i]=2+floatround(player_intelligence[i]/25.0,floatround_floor)
		
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
	
	if ((weapon != CSW_C4 ) && !on_knife[id] && (player_class[id] == Ninja))
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
			
			if(on_knife[id]){
				entity_set_string(id, EV_SZ_viewmodel, SWORD_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, SWORD_PLAYER)  
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
				entity_set_string(id, EV_SZ_viewmodel, SE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, SE_PLAYER)  
			}			
		}
		
		if(bow[id]==1)
		{
			bow[id]=0
			if(on_knife[id])
			{
				entity_set_string(id, EV_SZ_viewmodel, KNIFE_VIEW)  
				entity_set_string(id, EV_SZ_weaponmodel, KNIFE_PLAYER)  
			}
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
		if (player_class[id] == 0) select_class_query(id)
		
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
			statusMsg(0, "[�������] 0 �� %d ������ �������������.", get_pcvar_num(pMaxHooks))
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
		g_wasducking[vid] = true
	else
		g_wasducking[vid] = false
	
	set_task(0.5, "task_check_dead_flag", vid)

	flashbattery[vid] = MAX_FLASH;
	flashlight[vid] = 0;
	
	if(player_sword[id] == 1){
		if(on_knife[id]){
			if(get_user_team(kid) != get_user_team(vid)) {
				set_user_frags(kid, get_user_frags(kid) + 1)
				award_kill(kid,vid)
			}
		}
	}
	if (is_user_connected(kid) && is_user_connected(vid) && get_user_team(kid) != get_user_team(vid))
	{
		show_deadmessage(kid,vid,headshot,weaponname)
		create_itm(vid,0,"��������� Item")
		award_kill(kid,vid)
		add_respawn_bonus(vid)
		add_bonus_explode(vid)
		add_barbarian_bonus(kid)
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
		savexpcom(vid)
		if(quest_gracza[kid] != -1){
			if(player_class[vid] == questy[quest_gracza[kid]][2]){
				ile_juz[kid]++;
				zapisz_aktualny_quest(kid)
			}
			if(ile_juz[kid] == questy[quest_gracza[kid]][1]){
				client_print(kid,print_chat,"�������� ������� %s ��������� %i exp!",questy_info[quest_gracza[kid]],questy[quest_gracza[kid]][3])
				zapisz_questa(kid,quest_gracza[kid])
				Give_Xp(kid,questy[quest_gracza[kid]][3]);
				quest_gracza[kid] = -1;
				zapisz_aktualny_quest(kid)
			}
			else
			{
				client_print(kid,print_chat,"����� %i/%i %s",ile_juz[kid],questy[quest_gracza[kid]][1],questy_zabil[quest_gracza[kid]])
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
		
		if(get_user_attacker(id,weapon,bodypart)!=0)
		{
			new damage = read_data(2)
			new attacker_id = get_user_attacker(id,weapon,bodypart) 
			if (is_user_connected(attacker_id) && attacker_id != id)
			{
				if(get_user_team(id) != get_user_team(attacker_id))
				{				
					if(damage>175) player_dmg[attacker_id]+=damage/2
					else player_dmg[attacker_id]+=damage
					dmg_exp(attacker_id)
				}
				
				add_damage_bonus(id,damage,attacker_id)
				add_vampire_bonus(id,damage,attacker_id)
				add_grenade_bonus(id,attacker_id,weapon)
				add_theif_bonus(id,attacker_id)
				add_bonus_blind(id,attacker_id,weapon,damage)
				add_bonus_redirect(id)
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
				
				if(player_sword[attacker_id] == 1 && weapon==CSW_KNIFE ){

					change_health(id,-35,attacker_id,"world")
					
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
				if (player_class[ attacker_id ] == Imp && is_user_alive(id)&&random_num(1,30)==1)
				client_cmd(id, "weapon_knife")
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

public client_PreThink ( id ) 
{	
	if(!is_user_alive(id)||is_user_bot(id)) return PLUGIN_CONTINUE
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
	if (button2 & IN_ATTACK2 && player_class[id]==Diablo &&  !(get_user_oldbutton(id) & IN_ATTACK2)){
        if (weapon !=CSW_KNIFE && weapon != CSW_AWP && weapon != CSW_SCOUT){
                        if (cs_get_user_zoom(id)==CS_SET_NO_ZOOM) cs_set_user_zoom ( id, CS_SET_AUGSG552_ZOOM, 1 ) 
                        else cs_set_user_zoom(id,CS_SET_NO_ZOOM,1)
                }
        }
	if (entity_get_int(id, EV_INT_button) & 2 && (player_class[id]== Jumper))
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
	if (button2 & IN_RELOAD && on_knife[id] && button[id]==0 && player_class[id]==Amazon || button2 & IN_RELOAD && on_knife[id] && button[id]==0 && player_class[id]==Demonolog){
		bow[id]++
		button[id] = 1;
		command_bow(id)
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
	
	if (get_entity_flags(id) & FL_ONGROUND && (!(button2 & (IN_FORWARD+IN_BACK+IN_MOVELEFT+IN_MOVERIGHT)) || (player_class[id] == Mag && player_b_fireball[id]==0)) && is_user_alive(id) && !bow[id] && (on_knife[id] || (player_class[id] == Mag && player_b_fireball[id])) && player_class[id]!=NONE && player_class[id]!=Necromancer && invisible_cast[id]==0)
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
			new Float: time_delay = 5.0-(player_intelligence[id]/25.0)

			if(player_class[id] == Ninja) time_delay*=2.0
			else if(player_class[id] == Mag)
			{
				time_delay=time_delay = 4.0-(player_intelligence[id]/25.0)
				if(player_b_fireball[id]>0) time_delay=random_float(0.5,4.0-(player_intelligence[id]/25.0))
			}
			else if(player_class[id] == Assassin) time_delay*=2.0
			else if(player_class[id] == Paladin) time_delay*=1.4
			
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
	
	
	if (pev(id,pev_button) & IN_USE && !casting[id])
		Use_Spell(id)
	
	if(player_class[id]==Ninja && (pev(id,pev_button) & IN_RELOAD)) command_knife(id) 
	else if (pev(id,pev_button) & IN_RELOAD && on_knife[id] && max_knife[id]>0) command_knife(id) 
		
	///////////////////// BOW /////////////////////////
	if(player_class[id]==Amazon || player_class[id]==Demonolog)
	{
		new clip,ammo
		new weapon = get_user_weapon(id,clip,ammo)	
		
		if(bow[id] == 1)
		{
			if((bowdelay[id] + 4.25 - float(player_intelligence[id]/25))< get_gametime() && button2 & IN_ATTACK)
			{
				bowdelay[id] = get_gametime()
				command_arrow(id) 
			}
			entity_set_int(id, EV_INT_button, (button2 & ~IN_ATTACK) & ~IN_ATTACK2)
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
						client_print(id, print_center, "Grenade Trap %s", g_TrapMode[id] ? "[ON]" : "[OFF]")
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
	new text[513] 
	new keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)
	
	
	format(text, 512, "\y������ �����- \r�����: %i^n^n\w1. Intelligence [%i] [������ � ������ ���� Item]^n\w2. Strength [%i] [������ �� \r%i\w]^n\w3. Agility [%i] [���������� ����� item � �����]^n\w4. Dextery [%i] [����. �������� � ������� ����� �� �����]",player_point[id],player_intelligence[id],player_strength[id],player_strength[id]*2,player_agility[id],player_dextery[id]) 
	
	keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)
	show_menu(id, keys, text) 
	return PLUGIN_HANDLED  
} 


public skill_menu(id, key) 
{ 
	switch(key) 
	{ 
		case 0: 
		{	
			if (player_intelligence[id]<50){
				player_point[id]-=1
				player_intelligence[id]+=1
			}
			else client_print(id,print_center,"������������ Intelligence ����������")
			
		}
		case 1: 
		{	
			if (player_strength[id]<50){
				player_point[id]-=1	
				player_strength[id]+=1
			}
			else client_print(id,print_center,"������������ Strength ����������")
		}
		case 2: 
		{	
			if (player_agility[id]<50){
				player_point[id]-=1
				player_agility[id]+=1
				player_damreduction[id] = (47.3057*(1.0-floatpower( 2.7182, -0.06798*float(player_agility[id])))/100)
			}
			else client_print(id,print_center,"������������ Agility ����������")
			
		}
		case 3: 
		{	
			if (player_dextery[id]<50){
				player_point[id]-=1
				player_dextery[id]+=1
				set_speedchange(id)
			}
			else client_print(id,print_center,"������������ Dextery ����������")
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
	new Players[32], playerCount, id
	get_players(Players, playerCount, "aeh", "TERRORIST") 
		
	for (new i=0; i<playerCount; i++) 
	{
		id = Players[i]
		Give_Xp(id,get_cvar_num("diablo_xpbonus"))	
		ColorChat(id, GREEN, "�������^x03 *%i*^x01 exp �� ��������� ����� ����� ��������",get_cvar_num("diablo_xpbonus2"))
	}	
	Give_Xp(planter,get_cvar_num("diablo_xpbonus2"))
}

public bomb_defusing(id){ 
    defuser = id; 
    return PLUGIN_CONTINUE 
} 

public award_defuse()
{
	new Players[32], playerCount, id
	get_players(Players, playerCount, "aeh", "CT") 
		
	for (new i=0; i<playerCount; i++) 
	{
		id = Players[i] 
		Give_Xp(id,get_cvar_num("diablo_xpbonus"))	
		ColorChat(id, GREEN, "�������^x03 *%i*^x01 exp �� �������������� ����� ����� ��������",get_cvar_num("diablo_xpbonus2"))
	}
	Give_Xp(defuser,get_cvar_num("diablo_xpbonus2"))
}

public award_hostageALL(id)
{
	if (is_user_connected(id) == 1)
		Give_Xp(id,get_cvar_num("diablo_xpbonus2")/2)	
}

/* ==================================================================================================== */

public award_kill(killer_id,victim_id)
{
	if (!is_user_connected(killer_id) || !is_user_connected(victim_id))
		return PLUGIN_CONTINUE
		
	mana_gracza[killer_id]+=random_num(1,2)
	
		
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
	
	if(more_lvl>0) xp_award += floatround((get_cvar_num("diablo_xpbonus")/7)*(more_lvl*((2.0-more_lvl/40.0)/3.0)))
	else if(more_lvl<-50)xp_award -= get_cvar_num("diablo_xpbonus")*(2/3)
	else if(more_lvl<-40)xp_award -= get_cvar_num("diablo_xpbonus")/2
	else if(more_lvl<-30)xp_award -= get_cvar_num("diablo_xpbonus")/3
	else if(more_lvl<-20)xp_award -= get_cvar_num("diablo_xpbonus")/4
	else if(more_lvl<-10)xp_award -= get_cvar_num("diablo_xpbonus")/7
	
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
			if (player_xp[id] > LevelXP[player_lvl[id]])
			{
				player_lvl[id]+=1
				player_point[id]+=2
				set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 2.0, 0.1, 0.2, 2)
				show_hudmessage(id, "������� �� %i ������", player_lvl[id])
				new name[32]
				get_user_name(id, name, 31)
				ColorChat(0, TEAM_COLOR, "%s^x01 ������� ��^x03 %i^x01 ������ (^x04%s^x01)", name, player_lvl[id], Race[player_class[id]])
				savexpcom(id)
				player_class_lvl[id][player_class[id]]=player_lvl[id]
			}
			
			if (player_xp[id] < LevelXP[player_lvl[id]-1])
			{
				player_lvl[id]-=1
				player_point[id]-=2
				set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 2.0, 0.1, 0.2, 2)
				show_hudmessage(id, "������� �� %i ������", player_lvl[id]) 
				savexpcom(id)
				player_class_lvl[id][player_class[id]]=player_lvl[id]
			}
			write_hud(id)
		}
	}
	return PLUGIN_CONTINUE;
}

/* ==================================================================================================== */
public client_connect(id)
{
//	reset_item_skills(id)  - nie tutaj bo nie loaduje poziomow O.o
	asked_sql[id]=0
	flashbattery[id] = MAX_FLASH
	player_xp[id] = 0		
	player_lvl[id] = 1		
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
	player_item_name[id] = "���"
	DemageTake[id]=0
	player_b_gamble[id]=0
	lustrzany_pocisk[id] = 0
	
	g_GrenadeTrap[id] = 0
	g_TrapMode[id] = 0
		
	player_ring[id]=0
	
	reset_item_skills(id) // Juz zaladowalo xp wiec juz nic nie zepsuje <lol2>
	reset_player(id)
	set_task(10.0, "Greet_Player", id+TASK_GREET, "", 0, "a", 1)
}

public client_putinserver(id)
{
	loaded_xp[id]=0
	player_class_lvl_save[id]=0
	database_user_created[id]=0
	count_jumps(id)
	JumpsLeft[id]=JumpsMax[id]
}

public client_disconnect(id)
{
	new ent
	new playername[40]
	get_user_name(id,playername,39)
	player_dc_name[id] = playername
	player_dc_item[id] = player_item_id[id]	
	if (player_b_oldsen[id] > 0.0) client_cmd(id,"sensitivity %f",player_b_oldsen[id])
	savexpcom(id)
	
	remove_task(TASK_CHARGE+id)     
     
	while((ent = fm_find_ent_by_owner(ent, "fake_corpse", id)) != 0)
		fm_remove_entity(ent)
	
	player_class_lvl_save[id]=0
	loaded_xp[id]=0
}

/* ==================================================================================================== */

public write_hud(id)
{
	if (player_lvl[id] == 0)
		player_lvl[id] = 1
			
	new tpstring[1024] 
	
	new Float:xp_now
	new Float:xp_need
	new Float:perc
	
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
		else
		{
			xp_now = float(player_xp[id])-float( LevelXP[player_lvl[id]-1])
			xp_need = float(LevelXP[player_lvl[id]])-float(LevelXP[player_lvl[id]-1])
			perc = xp_now*100.0/xp_need
		}
	}
	
	last_update_xp[id] = player_xp[id]
	last_update_perc[id] = perc
	
	if(player_class[id]!=Paladin)
{
    set_hudmessage(0, 255, 0, 0.03, 0.20, 0, 6.0, 1.0)
    show_hudmessage(id, "�����: %i^n�����: %s^n�������: %i (%0.0f%s)^nItem: %s^n���������: %i^n����: %i",get_user_health(id), Race[player_class[id]], player_lvl[id], perc,"%%", player_item_name[id],item_durability[id],mana_gracza[id])
}
	else
{
    set_hudmessage(0, 255, 0, 0.03, 0.20, 0, 6.0, 1.0)
    show_hudmessage(id, "�����: %i^n�����: %s^n�������: %i^n(%0.0f%s)^n������: %i/%i^nItem: %s^n���������: %i^n����: %i",get_user_health(id), Race[player_class[id]], player_lvl[id], perc,"%%",JumpsLeft[id],JumpsMax[id], player_item_name[id], item_durability[id],mana_gracza[id])
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
		gUpdate[id] = true
			
			if(index >= 0 && index < MAX && is_user_connected(index) && is_user_alive(index)) 
			{
				new pname[32]
				get_user_name(index,pname,31)
				
				new Msg[512]
				set_hudmessage(255, 255, 255, 0.78, 0.65, 0, 6.0, 3.0)
				format(Msg,511,"���: %s^n�������: %i^n�����: %s^nItem: %s^nIntelligence: %i^nStrength: %i^nAgility: %i^nDextery: %i",pname,player_lvl[index],Race[player_class[index]],player_item_name[index], player_intelligence[index],player_strength[index], player_dextery[index], player_agility[index])		
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
		hudmsg(id,2.0,"� ��� ��� �������� ������� ����� ��������!")
		return PLUGIN_HANDLED
	} 
		
	if (item_durability[id] <= 0) 
	{
		hudmsg(id,3.0,"Item ������� ���� ����!")
	}
	else 
	{
		set_hudmessage(100, 200, 55, -1.0, 0.40, 0, 3.0, 2.0, 0.2, 0.3, 5)
		show_hudmessage(id, "Item ���������")
	}
	player_item_id[id] = 0
	player_item_name[id] = "���"
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
	if (ptd == 0)
		return PLUGIN_CONTINUE
	
	new szClassName[32]
	if(pev_valid(ptd)){
		entity_get_string(ptd, EV_SZ_classname, szClassName, 31)
	}
	else return PLUGIN_HANDLED
	
	if(equal(szClassName, "fireball"))
		{
			new owner = pev(ptd,pev_owner)
			//Touch
			if (get_user_team(owner) != get_user_team(ptr))
			{
				new Float:origin[3]
				pev(ptd,pev_origin,origin)
				Explode_Origin(owner,origin,55+player_intelligence[owner],150)
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
				Explode_Origin(owner,origin,15+player_intelligence[owner],150)
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

public Explode_Origin(id,Float:origin[3],damage,dist)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(3)
	write_coord(floatround(origin[0]))
	write_coord(floatround(origin[1]))
	write_coord(floatround(origin[2]))
	write_short(sprite_boom)
	write_byte(50)
	write_byte(15)
	write_byte(0)
	message_end()
	
	new Players[32], playerCount, a
	get_players(Players, playerCount, "ah") 
	
	for (new i=0; i<playerCount; i++) 
	{
		a = Players[i] 
		
		new Float:aOrigin[3]
		pev(a,pev_origin,aOrigin)
				
		if (get_user_team(id) != get_user_team(a) && get_distance_f(aOrigin,origin) < dist+0.0)
		{
			new dam = damage-player_dextery[a]*2
			change_health(a,-dam,id,"grenade")
			Effect_Bleed(a,248)		
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

public reset_item_skills(id){
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
        changeskin(id,1)
}
/* =================================================================================================== */




/* =====================================*/
/* ==================================================================================================== */

public auto_help(id)
{
	new rnd = random_num(1,5+player_lvl[id])
	if (rnd <= 5)
		set_hudmessage(0, 180, 0, -1.0, 0.70, 0, 10.0, 5.0, 0.1, 0.5, 11) 	
	if (rnd == 1)
		show_hudmessage(id, "�������� item ����� ������ /drop ����� ����� ���������� ���������� � ��� /item")
	if (rnd == 2)
		show_hudmessage(id, "�� ������ ������������ �������� item ������� E")
	if (rnd == 3)
		show_hudmessage(id, "�� ������ �������� ����� ���������� ���������� ������ � ������� say /help")
	if (rnd == 4)
		show_hudmessage(id, "������� ���� ���� say /menu")
	if (rnd == 5)
		show_hudmessage(id, "��������� item ����� ���� ��������� �����. �������� /rune ����� ������� ������� � ������")
}

/* ==================================================================================================== */

public helpme(id)
{	 
	//showitem(id,"Helpmenu","Common","None","Dostajesz przedmioty i doswiadczenie za zabijanie innych. Mozesz dostac go tylko wtedy, gdy nie masz na sobie innego<br><br>Aby dowiedziec sie wiecej o swoim przedmiocie napisz /przedmiot lub /item, a jak chcesz wyrzucic napisz /drop<br><br>Niektore przedmoty da sie uzyc za pomoca klawisza E<br><br>Napisz /czary zeby zobaczyc jakie masz staty<br><br>")
	show_motd(id, "http://lp.hitmany.net/diablo_help.html", "������ Diablo Mod")
}


/* ==================================================================================================== */



/* ==================================================================================================== */

public komendy(id)
{
showitem(id,"�������","�����","���","<br>")
}

/* ==================================================================================================== */

public showitem(id,itemname[],itemvalue[],itemeffect[],Durability[])
{
	new diabloDir[64]	
	new g_ItemFile[64]
	new amxbasedir[64]
	get_basedir(amxbasedir,63)
	
	format(diabloDir,63,"%s/diablo",amxbasedir)
	
	if (!dir_exists(diabloDir))
	{
		new errormsg[512]
		format(errormsg,511,"Blad: Folder %s/diablo nie mog� by� znaleziony. Prosze skopiowac ten folder z archiwum do folderu amxmodx",amxbasedir)
		show_motd(id, errormsg, "An error has occured")	
		return PLUGIN_HANDLED
	}
	
	
	format(g_ItemFile,63,"%s/diablo/item.txt",amxbasedir)
	if(file_exists(g_ItemFile))
		delete_file(g_ItemFile)
	
	new Data[768]
	
  //Header
	format(Data,767,"<html><head><title>����������</title></head>")
	write_file(g_ItemFile,Data,-1)
	
	//Format
	format(Data,767,"<meta http-equiv='content-type' content='text/html; charset=UTF-8' />")
	write_file(g_ItemFile,Data,-1)
	
	//Background
	format(Data,767,"<body text='#FFFF00' bgcolor='#000000' background='http://dbstats.lp.hitmany.net/server/drkmotr.jpg'>")
	write_file(g_ItemFile,Data,-1)
	
	//Table stuff
	format(Data,767,"<table border='0' cellpadding='0' cellspacing='0' style='border-collapse: collapse' width='100%s'><tr><td width='0'>","^%")
	write_file(g_ItemFile,Data,-1)
	
	//ss.gif image
	format(Data,767,"<p align='center'><img border='0' src='http://dbstats.lp.hitmany.net/server/ss.gif'></td>")
	write_file(g_ItemFile,Data,-1)
	

	//item name
	format(Data,767,"<td width='0'><p align='center'><font face='Arial'><font color='#FFCC00'><b>�������: </b>%s</font><br>",itemname)
	write_file(g_ItemFile,Data,-1)
	
	//item value
	format(Data,767,"<font color='#FFCC00'><b><br>��������: </b>%s</font><br>",itemvalue)
	write_file(g_ItemFile,Data,-1)
	
	//Durability
	format(Data,767,"<font color='#FFCC00'><b><br>���������: </b>%s</font><br><br>",Durability)
	write_file(g_ItemFile,Data,-1)
	
	//Effects
	format(Data,767,"<font color='#FFCC00'><b>������:</b> %s</font></font></td>",itemeffect)
	write_file(g_ItemFile,Data,-1)
	
	//image ss
	format(Data,767,"<td width='0'><p align='center'><img border='0' src='http://dbstats.lp.hitmany.net/server/gf.gif'></td>")
	write_file(g_ItemFile,Data,-1)
	
	//end
	format(Data,767,"</tr></table></body></html>")
	write_file(g_ItemFile,Data,-1)
	
	//show window with message
	show_motd(id, g_ItemFile, "Item ����")
	
	return PLUGIN_HANDLED
	
}


/* ==================================================================================================== */

public iteminfo(id)
{
	new itemvalue[100]
	
	if (player_item_id[id] <= 10) itemvalue = "�������"
	if (player_item_id[id] <= 30) 
		itemvalue = "������"
	else 
		itemvalue = "���������"
	
	if (player_item_id[id] > 42) itemvalue = "����������"
	
	new itemEffect[200]
	
	new TempSkill[11]					//There must be a smarter way
	
	if (player_b_vampire[id] > 0) 
	{
		num_to_str(player_b_vampire[id],TempSkill,10)
		add(itemEffect,199,"���������� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," �� ����� �� ��������� � ����������<br>")
	}
	if (player_b_damage[id] > 0) 
	{
		num_to_str(player_b_damage[id],TempSkill,10)
		add(itemEffect,199,"��� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ��������������� ����� � ������� ��������<br>")
	}
	if (player_b_money[id] > 0) 
	{
		num_to_str(player_b_money[id],TempSkill,10)
		add(itemEffect,199,"��� $")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," + intelligene*50 �������� ����� ������ �����. ��� ������� � ������������ ��� ������ ������� ���� �� 50%<br>")
	}
	if (player_b_gravity[id] > 0) 
	{
		num_to_str(player_b_gravity[id],TempSkill,10)
		add(itemEffect,199,"���������� ������������� �� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,". ��� � �� ����� �������� �� ����� � ��������� ������ ����� �� ��������� �������.<br>")
	}
	if(player_b_godmode[id] > 0)
	{
		num_to_str(player_b_godmode[id],TempSkill,10)
		add(itemEffect,199,"����������� ���� ������� ����� ����� ���������� �� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ������.<br>")
	}
	if (player_b_inv[id] > 0) 
	{
		num_to_str(player_b_inv[id],TempSkill,10)
		add(itemEffect,199,"���� ��������� �������� �� 255 �� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"<br>")
	}
	if (player_b_grenade[id] > 0) 
	{
		num_to_str(player_b_grenade[id],TempSkill,10)
		add(itemEffect,199,"� ���� ���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ���� ��������� ����� ����� � �������<br>")
	}
	if (player_b_reduceH[id] > 0) 
	{
		num_to_str(player_b_reduceH[id],TempSkill,10)
		add(itemEffect,199,"���� ����� ����������� �� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," � ������ ������� ������, ��������� �� ����� ��������<br>")
	}
	if (player_b_theif[id] > 0) 
	{
		num_to_str(player_b_theif[id],TempSkill,10)
		add(itemEffect,199,"���� 1/7 ������� $")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ������ ��� ����� �� �������� ����������. �� ����� ������ ������ E ����� �������������� 1000$ � 15 ��<br>")
	}
	if (player_b_respawn[id] > 0) 
	{
		num_to_str(player_b_respawn[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ����������� ����� ������<br>")
	}
	if (player_b_explode[id] > 0) 
	{
		num_to_str(player_b_explode[id],TempSkill,10)
		add(itemEffect,199,"����� �� �������� �� ����������� � ������� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ������ 75 ����� ���� ������ ��� - intelligence ����������� ������ item<br>")
	}
	if (player_b_heal[id] > 0) 
	{
		num_to_str(player_b_heal[id],TempSkill,10)
		add(itemEffect,199,"�� ��������� +")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," �� ������ 5 ������. ��� E ����� ���������� ������� ����� �� 7 ������<br>")
	}
	if (player_b_gamble[id] > 0) 
	{
		num_to_str(player_b_gamble[id],TempSkill,10)
		add(itemEffect,199,"�� �������� ��������� ����� � ������ ������� ������ ������������ 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"<br>")
	}
	if (player_b_blind[id] > 0) 
	{
		num_to_str(player_b_blind[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," �������� ��������� ����� �� ��������� � ����<br>")
	}
	if (player_b_fireshield[id] > 0) 
	{
		num_to_str(player_b_fireshield[id],TempSkill,10)
		add(itemEffect,199,"��������� ���� ��������, 20 �� ������ 2 �������.<br>")
		add(itemEffect,199,"�� �� ������ ���� ����� chaos orb, hell orb ��� firerope.<br>")
		add(itemEffect,199,"��� ������� � ������������ ��� ������ ������� ���� ����������.<br>")
	}
	if (player_b_meekstone[id] > 0) 
	{
		num_to_str(player_b_meekstone[id],TempSkill,10)
		add(itemEffect,199,"�� ������ ������� ��������� ����� c4 �������� ������� E � �������� �� ����� ����� E<br>")
	}
	if(player_b_radar[id] > 0)
  {
        add(itemEffect, 199, "�� ������ ����������� �� ������.<br>");
  }
	if (player_b_teamheal[id] > 0) 
	{
		num_to_str(player_b_teamheal[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ������������ ������ ������.<br>")
		add(itemEffect,199," ��� ����������� ����������. �� ����� ���� �������� ����.")
	}
	if (player_b_redirect[id] > 0) 
	{
		num_to_str(player_b_redirect[id],TempSkill,10)
		add(itemEffect,199,"�� ��������� ���������� ����� �� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ��<br>")
	}
	if (player_b_fireball[id] > 0) 
	{
		num_to_str(player_b_fireball[id],TempSkill,10)
		add(itemEffect,199,"������� ��������� ���� �������� ������� E - Intelligence �������� item. �� ����� ���� � ������� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"<br>")
	}
	if (player_b_ghost[id] > 0) 
	{
		num_to_str(player_b_ghost[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ������ ������ ����� � ������� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ������<br>")
	}
	if(player_b_autobh[id] > 0)
  {
        add(itemEffect,199,"��� ��� ���� ���������. ���������� � ������������.")
  }
	if (player_b_eye[id] > 0) 
	{
		add(itemEffect,199,"��� E ����� ���������� ��������� ���� (������ ���� ����� ��������) � ��� E ����� ����� ������������ ��� ����������")
		
	}
	if (player_b_blink[id] > 0) 
	{
		add(itemEffect,199,"�� ������ ����������������� �������������� ������ ���� � ��� � ����� ���. Intelligence ����������� ���������")
	}
	
	if (player_b_windwalk[id] > 0) 
	{
		num_to_str(player_b_windwalk[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ����� ���������,�� �� ������ ��������� � �������� ����������� �� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ������.<br>")
	}
	
	if (player_b_froglegs[id] > 0)
	{
		add(itemEffect,199,"����������� ����� +�������� 3 ������� ��� �������� ������")
	}
	if (player_b_dagon[id] == 1)
	{
		add(itemEffect,199,"��� E ����� ���������� ������� � ���������� ����� - �� ������ ������� ���� item �����")
		add(itemEffect,199,"Intelligence ����������� �������� itema")
	}
	if (player_b_sniper[id] > 0) 
	{
		num_to_str(player_b_sniper[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ��������� ����� �� ������<br>")
	}
	if (player_b_awpmaster[id] > 0) 
	{
		num_to_str(player_b_awpmaster[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"��������� ����� ���������� � AWP<br>")
	}
	if (player_b_dglmaster[id] > 0) 
	{
		num_to_str(player_b_dglmaster[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"��������� ����� ���������� � Deagle<br>")
	}
	if (player_b_m4master[id] > 0) 
	{
		num_to_str(player_b_m4master[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"��������� ����� ���������� � M4A1<br>")
	}
	if (player_b_m3master[id] > 0) 
	{
		num_to_str(player_b_m3master[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"��������� ����� ���������� � M3<br>")
	}
	if (player_b_akmaster[id] > 0) 
	{
		num_to_str(player_b_akmaster[id],TempSkill,10)
		add(itemEffect,199,"���� 1/")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"��������� ����� ���������� � AK47<br>")
	}
	if (player_b_jumpx[id] > 0)
	{
		num_to_str(player_b_jumpx[id],TempSkill,10)
		add(itemEffect,199,"�� ������ ������� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ���  � ������ ��� ������� ������ ������<br>")	
	}
	if (player_b_smokehit[id] > 0)
	{
		add(itemEffect,199,"���� ������� ������� ��������� ������� ���� ��� ������ �� �����")
	}
	if (player_b_extrastats[id] > 0)
	{
		num_to_str(player_b_extrastats[id],TempSkill,10)
		add(itemEffect,199,"�� �������� +")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," � ���������� ���� � ��� ���� ���� item")
	}
	if (player_b_firetotem[id] > 0)
	{
		num_to_str(player_b_firetotem[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ���������� �������� ����� ������� ���������� ����� 7�. �� ����� ���� � ������� ")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ������")
	}
	if (player_b_zamroztotem[id] > 0)
	{
		num_to_str(player_b_zamroztotem[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ���������� ����� ������� ������������ ����������.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_fleshujtotem[id] > 0)
	{
		num_to_str(player_b_fleshujtotem[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ���������� ����� ������� ��������� ����������.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_wywaltotem[id] > 0)
	{
		num_to_str(player_b_wywaltotem[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ���������� ����� ������� ����������� ������ ����������.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_kasatotem[id] > 0)
	{
		num_to_str(player_b_kasatotem[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ���������� ����� ������� ��� ��� � ����� ������� ������.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_kasaqtotem[id] > 0)
	{
		num_to_str(player_b_kasaqtotem[id],TempSkill,10)
		add(itemEffect,199,"��� E ����� ���������� ����� ������� ����������� ������� �����.")
		add(itemEffect,199,TempSkill)
	}
	if (player_b_hook[id] > 0)
	{
		num_to_str(player_b_hook[id],TempSkill,10)
		add(itemEffect,199,"��� ������� E ����������� � ���� ������ ������� 600. Intelligence �������� hook")
	}
	if (player_b_darksteel[id] > 0)
	{		
		new ddam = floatround(player_strength[id]*2*player_b_darksteel[id]/10.0)*3

		num_to_str(player_b_darksteel[id],TempSkill,10)
		add(itemEffect,199,"�� �������� 15 + 0.")
		add(itemEffect,199,TempSkill)
		add(itemEffect,199,"*strength: ")
		num_to_str(ddam,TempSkill,10)
		add(itemEffect,199,TempSkill)
		add(itemEffect,199," ������ ����� ����� �� �������� ����� ����� ")
	}
	if (player_b_antyarchy[id] > 0)
	{	
		add(itemEffect,199,"������ �� ���� ����� arch angel")
	}
	if (player_b_antyarchy[id] > 0)
	{	
		add(itemEffect,199,"������ �� ���� ����� Meekstone")
	}
	if (player_b_antyorb[id] > 0)
	{	
		add(itemEffect,199,"�� ��������� � �������")
	}
	if (player_b_antyfs[id] > 0)
	{	
		add(itemEffect,199,"� ��� ���� ����������� ���")
	}
	if (player_b_illusionist[id] > 0)
	{
		add(itemEffect,199,"��� ������� �� � �� ����������� ��������� (100%)���������.�� � �� ������ �� ������ � �������� �� 1 ��������. ������ ������ 5-7 ������.")
	}
	if (player_b_mine[id] > 0)
	{
		add(itemEffect,199,"��� E ����� ���������� ����� ��������� ����. ������ ���� ���������� ������ 50hp+intelligece �����. 3 ���� ������ ����� ��������.")
	}
	if (player_item_id[id]==66)
	{
		add(itemEffect,199,"�� ������ �� �����!")
	}
	if (player_ultra_armor[id]>0)
	{
		add(itemEffect,199,"� ��� ���� ���� ����������� ���� �� �����������")
	}
	
	
	new Durability[10]
	num_to_str(item_durability[id],Durability,9)
	if (equal(itemEffect,"")) showitem(id,"���","���","����� ����-������ �����,����� �������� ������� ��� ������ (/rune)","���")
	if (!equal(itemEffect,"")) showitem(id,player_item_name[id],itemvalue,itemEffect,Durability)
	
}

/* ==================================================================================================== */

public award_item(id, itemnum)
{
	if (player_item_id[id] != 0)
		return PLUGIN_HANDLED
	
	set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 4.0, 0.2, 0.3, 5)
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
	switch(rannum)
	{
		case 1:
		{
			player_item_name[id] = "Bronze Amplifier"
			player_item_id[id] = rannum
			player_b_damage[id] = random_num(1,3)
			show_hudmessage(id, "�� ����� item: %s ::  +%i ��������������� ����� � ������� ��������.",player_item_name[id],player_b_damage[id])
		}
		
		case 2:
		{
			player_item_name[id] = "Silver Amplifier"
			player_item_id[id] = rannum
			player_b_damage[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: +%i ��������������� ����� � ������� ��������.",player_item_name[id],player_b_damage[id])
		}
		
		case 3:
		{
			player_item_name[id] = "Gold Amplifier"
			player_item_id[id] = rannum
			player_b_damage[id] = random_num(6,10)
			show_hudmessage(id, "�� ����� item: %s :: +%i ��������������� ����� � ������� ��������.",player_item_name[id],player_b_damage[id])	
		}
		case 4:
		{
			player_item_name[id] = "Vampyric Staff"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(1,4)
			show_hudmessage(id, "�� ����� item: %s :: %i hp ���������� � ������� ��������.",player_item_name[id],player_b_vampire[id])	
		}
		case 5:
		{
			player_item_name[id] = "Vampyric Amulet"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(4,6)
			show_hudmessage(id, "�� ����� item: %s :: %i hp ���������� � ������� ��������.",player_item_name[id],player_b_vampire[id])	
		}
		case 6:
		{
			player_item_name[id] = "Vampyric Scepter"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(6,9)
			show_hudmessage(id, "�� ����� item: %s :: %i hp ���������� � ������� ��������.",player_item_name[id],player_b_vampire[id])	
		}
		case 7:
		{
			player_item_name[id] = "Small bronze bag"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(150,500)
			show_hudmessage(id, "�� ����� item: %s :: +%i ������ ����� + ��� ������� � ������������ ��� ������ ������� ���� �� ��� �� 50% ������ �� 200$ ������ 2-3 �������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 8:
		{
			player_item_name[id] = "Medium silver bag"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(500,1200)
			show_hudmessage(id, "�� ����� item: %s :: +%i ������ ����� + ��� ������� � ������������ ��� ������ ������� ���� �� ��� �� 50% ������ �� 200$ ������ 2-3 �������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 9:
		{
			player_item_name[id] = "Large gold bag"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(1200,3000)
			show_hudmessage(id, "�� ����� item: %s :: +%i ������ ����� + ��� ������� � ������������ ��� ������ ������� ���� �� ��� �� 50% ������ �� 200$ ������ 2-3 �������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 10:
		{
			player_item_name[id] = "Small angel wings"
			player_item_id[id] = rannum
			player_b_gravity[id] = random_num(1,5)
			
			if (is_user_alive(id))
				set_gravitychange(id)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i ����� � ���������� ��� ������ � ������� � ����� ������ �� ����� � ��������� ������� ����� �� ��������� �������.",player_item_name[id],player_b_gravity[id])	
		}
		case 11:
		{
			player_item_name[id] = "Arch angel wings"
			player_item_id[id] = rannum
			player_b_gravity[id] = random_num(5,9)
			
			if (is_user_alive(id))
				set_gravitychange(id)
				
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i ����� � ���������� ��� ������ � ������� � ����� ������ �� ����� � ��������� ������� ����� �� ������� �������.",player_item_name[id],player_b_gravity[id])	
			
		}
		case 12:
		{
			player_item_name[id] = "Invisibility Rope"
			player_item_id[id] = rannum
			player_b_inv[id] = random_num(150,200)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i �������������� ������������ ����.",player_item_name[id],255-player_b_inv[id])	
		}
		case 13:
		{
			player_item_name[id] = "Invisibility Coat"
			player_item_id[id] = rannum
			player_b_inv[id] = random_num(110,150)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i �������������� ������������ ����.",player_item_name[id],255-player_b_inv[id])	
		}
		case 14:
		{
			player_item_name[id] = "Invisibility Armor"
			player_item_id[id] = rannum
			player_b_inv[id] = random_num(70,110)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i �������������� ������������ ����.",player_item_name[id],255-player_b_inv[id])	
		}
		case 15:
		{
			player_item_name[id] = "Firerope"
			player_item_id[id] = rannum
			player_b_grenade[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: +1/%i  ���� ��������� ����� ����� � �������",player_item_name[id],player_b_grenade[id])	
		}
		case 16:
		{
			player_item_name[id] = "Fire Amulet"
			player_item_id[id] = rannum
			player_b_grenade[id] = random_num(2,4)
			show_hudmessage(id, "�� ����� item: %s :: +1/%i  ���� ��������� ����� ����� � �������",player_item_name[id],player_b_grenade[id])	
		}
		case 17:
		{
			player_item_name[id] = "Stalkers ring"
			player_item_id[id] = rannum
			player_b_reduceH[id] = 95
			player_b_inv[id] = 8	
			item_durability[id] = 100
			
			if (is_user_alive(id)) set_user_health(id,5)		
			show_hudmessage(id, "�� ����� item: %s :: ����������� ������ �����������, �� � ��� 5 �� � �� ������ ������ ���, ����� ������� �����.",player_item_name[id])	
		}
		case 18:
		{
			player_item_name[id] = "Arabian Boots"
			player_item_id[id] = rannum
			player_b_theif[id] = random_num(500,1000)
			show_hudmessage(id, "�� ����� item: %s :: � ������ ��������� ���������� � ���������� ������, � ����������� �� ������",player_item_name[id],player_b_theif[id])	
		}
		case 19:
		{
			player_item_name[id] = "Phoenix Ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ������������ ����� ������.",player_item_name[id],player_b_respawn[id])	
		}
		case 20:
		{
			player_item_name[id] = "Sorcerers ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = random_num(2,3)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ������������ ����� ������.",player_item_name[id],player_b_respawn[id])	
		}
		case 21:
		{
			player_item_name[id] = "Chaos Orb"
			player_item_id[id] = rannum
			player_b_explode[id] = random_num(150,275)
			show_hudmessage(id, "�� ����� item: %s :: ����� ������ ����������� � ������� %i",player_item_name[id],player_b_explode[id])	
		}
		case 22:
		{
			player_item_name[id] = "Hell Orb"
			player_item_id[id] = rannum
			player_b_explode[id] = random_num(200,400)
			show_hudmessage(id, "�� ����� item: %s :: ����� ������ ����������� � ������� %i",player_item_name[id],player_b_explode[id])	
		}
		case 23:
		{
			player_item_name[id] = "Gold statue"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(5,10)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ���������� �����, ������ ����� ��� � ���� �������. %i �� �� 5 ������, ����� ������� � ������� 7 ������ � �������� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 24:
		{
			player_item_name[id] = "Daylight Diamond"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(10,20)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ���������� �����, ������ ����� ��� � ���� �������. %i �� �� 5 ������, ����� ������� � ������� 7 ������ � �������� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 25:
		{
			player_item_name[id] = "Blood Diamond"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ���������� �����, ������ ����� ��� � ���� �������. %i �� �� 5 ������, ����� ������� � ������� 7 ������ � �������� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 26:
		{
			player_item_name[id] = "Wheel of Fortune"
			player_item_id[id] = rannum
			player_b_gamble[id] = random_num(2,3)
			show_hudmessage(id, "�� ����� item: %s :: ��� �������� +%i ������� ������ �����.",player_item_name[id],player_b_gamble[id])	
		}
		case 27:
		{
			player_item_name[id] = "Four leaf Clover"
			player_item_id[id] = rannum
			player_b_gamble[id] = random_num(4,5)
			show_hudmessage(id, "�� ����� item: %s :: ��� �������� +%i ������� ������ �����.",player_item_name[id],player_b_gamble[id])	
		}
		case 28:
		{
			player_item_name[id] = "Amulet of the sun"
			player_item_id[id] = rannum
			player_b_blind[id] = random_num(6,9)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i �������� ���������� ��� �����. ����� ����������� ����� ���������� ��������� � ������� 7-10 ������",player_item_name[id],player_b_blind[id])	
		}
		case 29:
		{
			player_item_name[id] = "Sword of the sun"
			player_item_id[id] = rannum
			player_b_blind[id] = random_num(2,5)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i �������� ���������� ��� �����. ����� ����������� ����� ���������� ��������� � ������� 7-10 ������",player_item_name[id],player_b_blind[id])	
		}
		case 30:
		{
			player_item_name[id] = "Fireshield"
			player_item_id[id] = rannum
			player_b_fireshield[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� � ������������ ��� ������� ������� ����� ����������. ��������� ���� ��������, 20 �� ������ 2 �������.",player_item_name[id],player_b_fireshield[id])	
		}
		case 31:
		{
			player_item_name[id] = "Stealth Shoes"
			player_item_id[id] = rannum
			player_b_silent[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��������� ��� (����� ����� assassin).",player_item_name[id])	
		}
		case 32:
		{
			player_item_name[id] = "Meekstone"
			player_item_id[id] = rannum
			player_b_meekstone[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ����� �� ������������ ����������. � �������� �����, ������ ������� � ��������.",player_item_name[id])	
		}
		case 33:
		{
			player_item_name[id] = "Medicine Glar"
			player_item_id[id] = rannum
			player_b_teamheal[id] = random_num(10,20)
			show_hudmessage(id, "�� ����� item: %s :: ��� ����� � ������������ ���������������� %i ��. ��� ������� � ���������� �� ����� ������� ��� ������ ���������� �����.",player_item_name[id],player_b_teamheal[id])	
		}
		case 34:
		{
			player_item_name[id] = "Medicine Totem"
			player_item_id[id] = rannum
			player_b_teamheal[id] = random_num(20,30)
			show_hudmessage(id, "�� ����� item: %s :: ��� ����� � ������������ ���������������� %i ��. ��� ������� � ���������� �� ����� ������� ��� ������ ���������� �����.",player_item_name[id],player_b_teamheal[id])	
		}
		case 35:
		{
			player_item_name[id] = "Iron Armor"
			player_item_id[id] = rannum
			player_b_redirect[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: ������� +%i ������ �� ��� � ������� ��������.",player_item_name[id],player_b_redirect[id])	
		}
		case 36:
		{
			player_item_name[id] = "Mitril Armor"
			player_item_id[id] = rannum
			player_b_redirect[id] = random_num(6,11)
			show_hudmessage(id, "�� ����� item: %s :: ������� +%i ������ �� ��� � ������� ��������.",player_item_name[id],player_b_redirect[id])	
		}
		case 37:
		{
			player_item_name[id] = "Godly Armor"
			player_item_id[id] = rannum
			player_b_redirect[id] = random_num(10,15)
			show_hudmessage(id, "�� ����� item: %s :: ������� +%i ������ �� ��� � ������� ��������.",player_item_name[id],player_b_redirect[id])	
		}
		case 38:
		{
			player_item_name[id] = "Fireball staff"
			player_item_id[id] = rannum
			player_b_fireball[id] = random_num(50,100)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ������, ������������ � ������� %i",player_item_name[id],player_b_fireball[id])	
		}
		case 39:
		{
			player_item_name[id] = "Fireball scepter"
			player_item_id[id] = rannum
			player_b_fireball[id] = random_num(100,200)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ������, ������������ � ������� %i",player_item_name[id],player_b_fireball[id])	
		}
		case 40:
		{
			player_item_name[id] = "Ghost Rope"
			player_item_id[id] = rannum
			player_b_ghost[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: ����������� ������ ������ �����, ����� ������� %i ������",player_item_name[id],player_b_ghost[id])	
		}
		case 41:
		{
			player_item_name[id] = "Nicolas Eye"
			player_item_id[id] = rannum
			player_b_eye[id] = -1
			show_hudmessage(id, "�� ����� item: %s :: ������������� ������ �� �����.",player_item_name[id])	
		}
		case 42:
		{
			player_item_name[id] = "Knife Ruby"
			player_item_id[id] = rannum
			player_b_blink[id] = floatround(halflife_time())
			show_hudmessage(id, "�� ����� item: %s :: ��� ������������� ���� ������ �������� ������������� ��� �� ��������� ���������",player_item_name[id])	
		}
		case 43:
		{
			player_item_name[id] = "Lothars Edge"
			player_item_id[id] = rannum
			player_b_windwalk[id] = random_num(4,7)
			show_hudmessage(id, "�� ����� item: %s :: �� %i ������ ��� ������� ������������ + ������ ����������� ��� ���.",player_item_name[id],player_b_windwalk[id])	
		}
		case 44:
		{
			player_item_name[id] = "Sword"
			player_item_id[id] = rannum
			player_sword[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ����������� ���� ����",player_item_name[id])		
		}
		case 45:
		{
			player_item_name[id] = "Mageic Booster"
			player_item_id[id] = rannum
			player_b_froglegs[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ������ 3 ������� ���� �� ����� ������ ��������.(item �� ������ ��������)",player_item_name[id])	
		}
		case 46:
		{
			player_item_name[id] = "Dagon I"
			player_item_id[id] = rannum
			player_b_dagon[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� USE ������� ����� ���������� �� ������� ��������� ��� � 20 ������",player_item_name[id])	
		}
		case 47:
		{
			player_item_name[id] = "Scout Extender"
			player_item_id[id] = rannum
			player_b_sniper[id] = random_num(3,4)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ��������� ����� �� ������.",player_item_name[id],player_b_sniper[id])	
		}
		case 48:
		{
			player_item_name[id] = "Scout Amplifier"
			player_item_id[id] = rannum
			player_b_sniper[id] = random_num(2,3)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ��������� ����� �� ������.",player_item_name[id],player_b_sniper[id])	
		}
		case 49:
		{
			player_item_name[id] = "Air booster"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: �� ������ ������� ������� ������ � �������",player_item_name[id],player_b_sniper[id])	
		}
		case 50:
		{
			player_item_name[id] = "Iron Spikes"
			player_item_id[id] = rannum
			player_b_smokehit[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ������� ������� ��������, ���� ������� �� � ����������",player_item_name[id])	
		}
		case 51:
		{
			player_item_name[id] = "Point Booster"
			player_item_id[id] = rannum
			player_b_extrastats[id] = random_num(1,3)
			BoostStats(id,player_b_extrastats[id])
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i ����� � ������� �������",player_item_name[id],player_b_extrastats[id])	
		}
		case 52:
		{
			player_item_name[id] = "Totem amulet"
			player_item_id[id] = rannum
			player_b_firetotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ������ ����� ����� ������� ����� ��������� ������ ���������� � ��������� ���� � ������� �������.",player_item_name[id])	
		}
		case 53:
		{
			player_item_name[id] = "Mageic Hook"
			player_item_id[id] = rannum
			player_b_hook[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� USE ����������� � ���� �����",player_item_name[id])	
		}
		case 54:
		{
			player_item_name[id] = "Darksteel Glove"
			player_item_id[id] = rannum
			player_b_darksteel[id] = random_num(1,5)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ����� ��� ����� ���������� �� �����.",player_item_name[id])	
		}
		case 55:
		{
			player_item_name[id] = "Darksteel Gaunlet"
			player_item_id[id] = rannum
			player_b_darksteel[id] = random_num(7,9)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ����� ��� ����� ���������� �� �����.",player_item_name[id])	
		}
		case 56:
		{
			player_item_name[id] = "Illusionists Cape"
			player_item_id[id] = rannum
			player_b_illusionist[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � �� ����������� ��������� (100%)���������. ������ � �� ������ �� ������ � �������� �� 1 ��������.",player_item_name[id])	
		}
		case 57:
		{
			player_item_name[id] = "Techies scepter"
			player_item_id[id] = rannum
			player_b_mine[id] = 3
			show_hudmessage(id, "�� ����� item: %s :: ������ 3 ������������� ����.",player_item_name[id])
		}
		
		case 58:
		{
			player_item_name[id] = "Ninja ring"
			player_item_id[id] = rannum
			player_b_blink[id] = floatround(halflife_time())
			player_b_froglegs[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ��������� ��� ����������������� ������ 3 �������. ������� DUCK ����� �������� ������.",player_item_name[id])
		}
		case 59:	
		{
			player_item_name[id] = "Mage ring"
			player_item_id[id] = rannum
			player_ring[id]=1
			player_b_fireball[id] = random_num(50,80)
			show_hudmessage(id, "�� ����� item : %s :: ����������� �������� ��������� ������ +5 ���������",player_item_name[id])
		}	
		case 60:	
		{
			player_item_name[id] = "Necromant ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = random_num(2,4)
			player_b_vampire[id] = random_num(3,5)	
			show_hudmessage(id, "�� ����� item : %s :: ���� ����������� ����� ������. ��� ��������� �� �����, �������� ���������� ���� ��",player_item_name[id])
		}
		case 61:
		{
			player_item_name[id] = "Barbarian ring"
			player_item_id[id] = rannum
			player_b_explode[id] = random_num(120,330)
			player_ring[id]=2
			show_hudmessage(id, "�� ����� item : %s :: ����� ��� ������� �� �����������, ������ ���� ������� � ����� ������. +5 ����",player_item_name[id])
		}
		case 62:
		{
			player_item_name[id] = "Paladin ring"
			player_item_id[id] = rannum	
			player_b_redirect[id] = random_num(7,17)
			player_b_blind[id] = random_num(3,4)
			show_hudmessage(id, "�� ����� item : %s :: �������� ������ �� ���. ���� �������� ����������",player_item_name[id])		
		}
		case 63:
		{
			player_item_name[id] = "Monk ring"
			player_item_id[id] = rannum	
			player_b_grenade[id] = random_num(1,4)
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "�� ����� item : %s :: ����������� ���� ��������� ��������. ��������������� ��������",player_item_name[id])
		}	
		case 64:
		{
			player_item_name[id] = "Assassin ring"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 1
			player_ring[id]=3
			show_hudmessage(id, "�� ����� item : %s :: ������� ������. +5 ��������",player_item_name[id])	
		}	
		case 65:
		{
			player_item_name[id] = "Flashbang necklace"	
			player_item_id[id] = rannum	
			wear_sun[id] = 1
			show_hudmessage (id, "�� ����� item : %s :: ��������� � ����������� ��������",player_item_name[id])
		}
		case 66:
		{
			player_item_name[id] = "Chameleon"	
			player_item_id[id] = 66	
			changeskin(id,0)  
			show_hudmessage (id, "�� ����� item : %s :: ����������� �� ����� (������� ���)",player_item_name[id])
		}
		case 67:
		{
			player_item_name[id] = "Stong Armor"	
			player_item_id[id] = 67	
			player_ultra_armor[id]=random_num(3,6)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "�� ����� item : %s :: ������ ����� ����� ���������� ������ %i",player_item_name[id],player_ultra_armor[id])
		}
		case 68:
		{
			player_item_name[id] = "Ultra Armor"	
			player_item_id[id] = 68	
			player_ultra_armor[id]=random_num(7,11)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "�� ����� item : %s :: ������ ����� ����� ���������� ������ %i",player_item_name[id],player_ultra_armor[id])
		}
		case 69:
		{
			player_item_name[id] = "Khalim Eye"
			player_item_id[id] = rannum
			player_b_radar[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: �� ������ ����������� �� ������", player_item_name[id])
		}
		case 70:
		{
			player_item_name[id] = "Jumper Ring"
			player_item_id[id] = rannum
			player_b_autobh[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ��� ��� ���� ���������. ���������� � ������������.", player_item_name[id])
		}
		case 71:
		{
			player_item_name[id] = "Myrmidon Greaves"
			player_item_id[id] = rannum
			player_b_silent[id] = 1
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/2)
			show_hudmessage (id, "�� ����� item : %s :: ��������� � ������� ���",player_item_name[id],player_b_silent[id])
		}
		case 72:
		{
			player_item_name[id] = "Shoes of the Bone"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 4
			set_user_gravity(id, 600.0)
			show_hudmessage (id, "�� ����� item : %s :: �� ������ ������� 4 ������ � �������. ���������� ����������",player_item_name[id],player_b_jumpx[id])
		}
		case 73:
		{
			player_item_name[id] = "Scarab Shoes"
			player_item_id[id] = rannum
			player_b_inv[id] = 95
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "�� ����� item : %s :: ��� ��������� ��������� �� 95. ������� ���.",player_item_name[id],player_b_inv[id])
		}
		case 74:
		{
			player_item_name[id] = "Hydra Blade"
			player_item_id[id] = rannum
			player_b_inv[id] = 155
			player_b_damage[id] = 20
			show_hudmessage (id, "�� ����� item : %s :: ��� ��������� ��������� �� 155 +20 � �����",player_item_name[id],player_b_inv[id],player_b_damage[id])
		}
		case 75:
		{
			player_item_name[id] = "Exp Ring"
			player_item_id[id] = rannum
			new xp_award = get_cvar_num("diablo_xpbonus")*2
			show_hudmessage (id, "�� ����� item : %s :: ���������� ����� �� %i",player_item_name[id],xp_award)
		}
		case 76:
		{
			player_item_name[id] = "Aegis"
			player_item_id[id] = rannum
			player_ring[id]=2
			player_b_explode[id] = random_num(120,330)
			player_b_redirect[id] = random_num(10, 100)
			show_hudmessage (id, "�� ����� item : %s :: �� ��������� +5 � ���� � ����������� ����� ��������(���� %i) -%i ����� �� ���",player_item_name[id],player_b_explode[id],player_b_redirect[id])
		}
		case 77:
		{
			player_item_name[id] = "Polished Wand"
			player_item_id[id] = rannum
			player_b_blind[id] = random_num(1,5)
			player_b_heal[id] =  random_num(1,15)
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/%i �������� �����, ��� E ����� ���������� ���������� �����",player_item_name[id],player_b_blind[id])
		}
		case 78:
		{
			player_item_name[id] = "Heavenly Stone"
			player_item_id[id] = rannum
			player_b_grenade[id] = random_num(1,3)
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/%i ��������� ����� HE ������� � ������� ���",player_item_name[id],player_b_grenade[id])
		}
		case 79:
		{
			player_item_name[id] = "Festering Essence of Destruction"
			player_item_id[id] = rannum
			player_b_respawn[id] = 2
			player_b_sniper[id] = 1
			player_b_grenade[id] = 3
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/2 ����������, ���� 1/1 ��������� ����� �� ������,���� 1/3 ����� � HE",player_item_name[id])
		}
		case 80:
		{
			player_item_name[id] = "Vampire Gloves"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(5,15)
			show_hudmessage(id, "�� ����� item : %s :: ���������� %i �� ������ ��������� �� �����,�� �������� +30hp",player_item_name[id],player_b_vampire[id])
		}
		case 81:
		{
			player_item_name[id] = "Super Mario"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 10
			player_b_fireball[id] = 5
			show_hudmessage (id, "�� ����� item : %s :: �� ������ ������� 10 ������� � ������ � ������� �� 5 �����",player_item_name[id],player_b_jumpx[id], player_b_fireball[id])
		}
		case 85:
		{
			player_item_name[id] = "Centurion"
			player_item_id[id] = rannum
			player_b_damage[id] = 20
			player_b_redirect[id] = 40
			set_user_gravity(id,3.0)
			show_hudmessage (id, "�� ����� item : %s :: +20 � ����� � ���������� ����� �� 40",player_item_name[id],player_b_damage[id],player_b_redirect[id])
		}
		case 86:
		{
			player_item_name[id] = "RedBull"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 8
			show_hudmessage(id, "�� ����� item : %s :: �� ������ ������� 8 ������� � �������",player_item_name[id],player_b_sniper[id])	
		}
		case 87:
		{
			player_item_name[id] = "Dr House"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(45,65)
			show_hudmessage(id, "�� ����� item : %s :: ��������������� %i hp ������ 5 ������. ����� � ����� ���������� ������� ����� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 88:
		{
			player_item_name[id] = "Own Invisible"
			player_item_id[id] = rannum
			player_b_inv[id] = 8
			player_b_reduceH[id] = 55
			if (is_user_alive(id)) set_user_health(id,45)
			show_hudmessage(id, "�� ����� item : %s :: �� ����� ��������,�� � ��� 45 HP.",player_item_name[id])	
		}
		case 89:
		{
			player_item_name[id] = "Mega Invisible"
			player_item_id[id] = rannum
			player_b_reduceH[id] = 90
			player_b_inv[id] = 1	
			item_durability[id] = 50
			
			if (is_user_alive(id)) set_user_health(id,10)		
			show_hudmessage(id, "�� ����� item : %s :: � ��� 10 ������,����������� 1/255",player_item_name[id])	
		}
		case 90:
		{
			player_item_name[id] = "Bul'Kathos Shoes"
			player_item_id[id] = rannum
			player_b_jumpx[id] = 8
			set_user_gravity(id, 400.0)
			show_hudmessage(id, "�� ����� item : %s :: �� ������ ������� 8 ������� � ������� � � ��� ������� ����������",player_item_name[id],player_b_sniper[id])	
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
			show_hudmessage(id, "�� ����� item : %s :: Item ��������� ������,��� ����� ��� �� ������ ��� ��������� ��������",player_item_name[id])		
		}
		case 92:
		{
			player_item_name[id] = "Purse Thief"
			player_item_id[id] = rannum
			player_b_money[id] = random_num(1,16000)
			show_hudmessage(id, "�� ����� item : %s :: ��������� %i ����� � ������ ������. ����������� ����� ����������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)
		}
		case 93:
		{
			player_item_name[id] = "Vampiric Blood"
			player_item_id[id] = rannum
			player_b_vampire[id] = random_num(15,20)
			show_hudmessage(id, "�� ����� item : %s :: ����������� %i hp � ����������",player_item_name[id],player_b_vampire[id])	
		}
		case 94:
		{
			player_item_name[id] = "Revival Ring"
			player_item_id[id] = rannum
			player_b_respawn[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: 1/%i ���� �� �����������",player_item_name[id],player_b_respawn[id])	
		}
		case 95:
		{
			player_item_name[id] = "Demon Assassin"
			player_item_id[id] = rannum
			player_b_heal[id] = random_num(30,55)
			player_b_damage[id] = 50
			show_hudmessage(id, "�� ����� item : %s :: ��������������� %i hp ������ 5 ������. ����� � ����� ���������� ������� ����� %i. +50 � �����",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 96:
		{
			player_item_name[id] = "Mystiqe"	
			player_item_id[id] = rannum
			changeskin(id,0)
			player_b_grenade[id] = random_num(1,2)
			show_hudmessage (id, "�� ����� item : %s :: �� ��������� ��� ���������.���� 1/%i ��������� ����� � ������� HE",player_item_name[id],player_b_grenade[id])
		}
		case 97:
		{
			player_item_name[id] = "Apocalypse Anihilation"
			player_item_id[id] = rannum
			player_b_damage[id] = 100
			player_b_silent[id] = 1
			item_durability[id] = 100
			show_hudmessage (id, "�� ����� item : %s :: �� �� ������ %i ����� � ������� ��������.��������� ���.",player_item_name[id],player_b_damage[id],player_b_silent[id])
		}
		case 98:
		{
			player_item_name[id] = "Inferno"
			player_item_id[id] = rannum
			player_b_redirect[id] = 10
			player_b_damage[id] = 10
			player_b_respawn[id] = 2
			show_hudmessage (id, "�� ����� item : %s :: +10 � �����. -10 ����� �� ���. ���� 1/2 ����������.",player_item_name[id])
		}
		case 99:
		{
			player_item_name[id] = "Hellspawn"
			player_item_id[id] = rannum
			player_b_grenade[id] = 5
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/5 ����� � �� �������.+%i � �����������",player_item_name[id],255-player_b_inv[id])
		}
		case 100:
		{
			player_item_name[id] = "Shako"
			player_item_id[id] = rannum
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "�� ����� item : %s :: +25����� || +%i � �����������",player_item_name[id],255-player_b_inv[id])
		}
		case 101:
		{
			player_item_name[id] = "Annihilus"
			player_item_id[id] = rannum
			player_b_damage[id] = 15
			player_b_vampire[id] = 50
			show_hudmessage (id, "�� ����� item : %s :: +15 � �����. ���������� 50hp � ������� ��������",player_item_name[id])
		}
		case 102:
		{
			player_item_name[id] = "Blizzard's Mystery"
			player_item_id[id] = rannum
			player_b_damage[id] = 25
			player_b_vampire[id] = 25
			item_durability[id] = 100
			show_hudmessage (id, "�� ����� item : %s :: +25 � �����. ���������� 25 HP � ������� ��������",player_item_name[id])
		}
		case 103:
		{
			player_item_name[id] = "Mara's Kaleidoscope"
			player_item_id[id] = rannum
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(190,200)
			show_hudmessage (id, "�� ����� item : %s :: +25 � �����. +%i � �����������",player_item_name[id],255-player_b_inv[id])
		}
		case 104:
		{
			player_item_name[id] = "M4A1 Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_m4master[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � M4A1",player_item_name[id],player_b_m4master[id])
		}
		case 105:
		{
			player_item_name[id] = "AK47 Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_akmaster[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � AK47",player_item_name[id],player_b_akmaster[id])
		}
		case 106:
		{
			player_item_name[id] = "AWP Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_awpmaster[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � AWP",player_item_name[id],player_b_awpmaster[id])
		}
		case 107:
		{
			player_item_name[id] = "Deagle Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_dglmaster[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � Deagle",player_item_name[id],player_b_dglmaster[id])
		}
		case 108:
		{
			player_item_name[id] = "M3 Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_m3master[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � M3",player_item_name[id],player_b_m3master[id])
		}
		case 109:
		{
			player_item_name[id] = "Full Special"
			player_item_id[id] = rannum
			item_durability[id] = 100
			player_b_m3master[id] = random_num(1,8)
			player_b_dglmaster[id] = random_num(1,8)
			player_b_awpmaster[id] = random_num(1,8)
			player_b_akmaster[id] = random_num(1,8)
			player_b_m4master[id] = random_num(1,8)
			player_b_grenade[id] = random_num(1,8)
			player_b_sniper[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � M3,1/%i � Deagle,1/%i � AWP,1/%i � AK47,1/%i � M4A1,1/%i � HE,1/%i � ������",player_item_name[id],player_b_m3master[id],player_b_dglmaster[id],player_b_awpmaster[id],player_b_akmaster[id],player_b_m4master[id],player_b_grenade[id],player_b_sniper[id])
		}
		case 110:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 111:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 112:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 113:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 114:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		
		case 115:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 116:
		{
			player_item_name[id] = "Diablo Shoes"
			player_item_id[id] = rannum
			player_b_antyarchy[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� �� Arch angel", player_item_name[id], player_b_antyarchy[id])
		}
		case 117:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_item_id[id] = rannum
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 118:
		{
			player_item_name[id] = "Anti Explosion"
			player_item_id[id] = rannum
			player_b_antyorb[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� �� ������ ����� ��������", player_item_name[id], player_b_antyorb[id])
		}
		case 119:
		{
			player_item_name[id] = "Anti HellFlare"
			player_item_id[id] = rannum
			player_b_antyfs[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� ����", player_item_name[id], player_b_antyfs[id])
		}
		case 120:
		{
			player_item_name[id] = "Gheed's Fortune"
			player_item_id[id] = rannum
			player_b_godmode[id] = random_num(4,10)
			show_hudmessage(id, "�� ����� item : %s :: �� ����������� ���������� �� %i ������.", player_item_name[id], player_b_godmode[id])
		}
		case 121:
		{
			player_item_name[id] = "Winter Totem"
			player_item_id[id] = rannum
			player_b_zamroztotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ����� � ����� ���������� �������������� �����",player_item_name[id])	
		}
		case 122:
		{
			player_item_name[id] = "Cash Totem"
			player_item_id[id] = rannum
			player_b_kasatotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ��� E ����� ���������� ����� ������� ��� ��� � ����� ������� ������.",player_item_name[id])	
		}
		case 123:
		{
			player_item_name[id] = "Thief Totem"
			player_item_id[id] = rannum
			player_b_kasaqtotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ��� E ����� ���������� ����� ������� ����������� ������� �����.",player_item_name[id])	
		}
		case 124:
		{
			player_item_name[id] = "Weapon Totem"
			player_item_id[id] = rannum
			player_b_wywaltotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ��� E ����� ���������� ����� ������� ����������� ������ ����������.",player_item_name[id])	
		}
		case 125:
		{
			player_item_name[id] = "Flash Totem"
			player_item_id[id] = rannum
			player_b_fleshujtotem[id] = random_num(250,400)
			show_hudmessage(id, "��� E ����� ���������� ����� ������� ��������� ����������.",player_item_name[id])	
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
	
	set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 2.0, 0.2, 0.3, 5)
	show_hudmessage(id, "�� ����� ���������� Item: %s", Unique_name)
	
}
/* EFFECTS ================================================================================================= */

public add_damage_bonus(id,damage,attacker_id)
{
	if (player_b_damage[attacker_id] > 0 && get_user_health(id)>player_b_damage[attacker_id])
	{
		change_health(id,-player_b_damage[attacker_id],attacker_id,"")
			
		if (random_num(0,2) == 1) Effect_Bleed(id,248)
	}
	if (c_damage[attacker_id] > 0 && get_user_health(id)>player_b_damage[attacker_id])
	{
		change_health(id,-c_damage[attacker_id],attacker_id,"")
			
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
			set_user_health(id, 0)
			message_begin( MSG_ALL, gmsgDeathMsg,{0,0,0},0) 
			write_byte(attacker_id) 
			write_byte(id) 
			write_byte(0) 
			write_string("grenade") 
			message_end() 
			set_user_frags(attacker_id, get_user_frags(attacker_id)+1) 
			set_user_frags(id, get_user_frags(id)+1)
			cs_set_user_money(attacker_id, cs_get_user_money(attacker_id)+150) 
		}
	}
	if (c_grenade[attacker_id] > 0 && weapon == CSW_HEGRENADE && player_b_fireshield[id] == 0)	//Fireshield check
	{
		new roll = random_num(1,c_grenade[attacker_id])
		if (roll == 1)
		{
			set_user_health(id, 0)
			message_begin( MSG_ALL, gmsgDeathMsg,{0,0,0},0) 
			write_byte(attacker_id) 
			write_byte(id) 
			write_byte(0) 
			write_string("grenade") 
			message_end() 
			set_user_frags(attacker_id, get_user_frags(attacker_id)+1) 
			set_user_frags(id, get_user_frags(id)+1)
			cs_set_user_money(attacker_id, cs_get_user_money(attacker_id)+150) 
		}
	}
}

/* ==================================================================================================== */

public add_redhealth_bonus(id)
{
	if (player_b_reduceH[id] > 0)
		change_health(id,-player_b_reduceH[id],0,"")
	if(player_item_id[id]==17)	//stalker ring
		set_user_health(id,5)
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
				show_hudmessage(id, "����� 2 �������, ���������� ��� �����������")	
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
				show_hudmessage(id, "����� 2 �������, ���������� ��� �����������")	
			}
			
		}
	}
}

public respawn(svIndex[]) 
{ 
	new vIndex = str_to_num(svIndex) 
	spawn(vIndex);
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
				change_health(a,-dam,id,"grenade")
				Display_Fade(id,2600,2600,0,255,0,0,15)				
			}
		}
	}
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
		set_hudmessage(220, 115, 70, -1.0, 0.40, 0, 3.0, 2.0, 0.2, 0.3, 5)
		new roll = random_num(1,player_b_gamble[id])
		if (roll == 1)
		{
			show_hudmessage(id, "����� ������: +5 �����")
			player_b_damage[id] = 5
		}
		if (roll == 2)
		{
			show_hudmessage(id, "����� ������: +5 � ����������")
			player_b_gravity[id] = 5
		}
		if (roll == 3)
		{
			show_hudmessage(id, "����� ������: +5 vampyric ����")
			player_b_vampire[id] = 5
		}
		if (roll == 4)
		{
			show_hudmessage(id, "����� ������: +10 hp ������ 5 ������")
			player_b_heal[id] = 10
		}
		if (roll == 5)
		{
			show_hudmessage(id, "����� ������: ���� 1/3 ����� ����� � ������� HE")
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
		hudmsg(id,2.0,"Meekstone ����� ������������ ���� ��� �� �����!")
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
					UTIL_Kill(id,a,"grenade")
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
		hudmsg(id,2.0,"��� ����� ������������ ���� ��� �� �����!")
		return PLUGIN_HANDLED
	}
	
	if (fired[id] == 0 && is_user_alive(id) == 1)
	{
		fired[id] = 1
		new Float:vOrigin[3]
		new fEntity
		entity_get_vector(id,EV_VEC_origin, vOrigin)
		fEntity = create_entity("info_target")
		entity_set_model(fEntity, "models/rpgrocket.mdl")
		entity_set_origin(fEntity, vOrigin)
		entity_set_int(fEntity,EV_INT_effects,64)
		entity_set_string(fEntity,EV_SZ_classname,"fireball")
		entity_set_int(fEntity, EV_INT_solid, SOLID_BBOX)
		entity_set_int(fEntity,EV_INT_movetype,5)
		entity_set_edict(fEntity,EV_ENT_owner,id)
		
		
		
		//Send forward
		new Float:fl_iNewVelocity[3]
		VelocityByAim(id, 500, fl_iNewVelocity)
		entity_set_vector(fEntity, EV_VEC_velocity, fl_iNewVelocity)
		
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
		write_byte(22) 
		write_short(fEntity) 
		write_short(sprite_beam) 
		write_byte(45) 
		write_byte(4) 
		write_byte(255) 
		write_byte(0) 
		write_byte(0) 
		write_byte(25)
		message_end() 
	}	
	return PLUGIN_HANDLED
}

/* ==================================================================================================== */

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
		hudmsg(id,3.0,"������ ���� ����� ����� ������������ ������� � �� �� �����! ������� ��� �����������!")
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
			change_health(id,-dam,attacker,"world")
		}
	}
	if (c_darksteel[attacker] > 0)
{
	if (UTIL_In_FOV(attacker,id) && !UTIL_In_FOV(id,attacker))
	{
		new dam = (1+player_b_darksteel[id])
		Effect_Bleed(id,248)
		change_health(id,-dam,attacker,"world")
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
		if (on_knife[id])
		{
			if (halflife_time()-player_b_blink[id] <= 3) return PLUGIN_HANDLED		
			player_b_blink[id] = floatround(halflife_time())	
			UTIL_Teleport(id,300+15*player_intelligence[id])			
		}
	}
	if( get_user_button(id) & IN_ATTACK2 && !(get_user_oldbutton(id) & IN_ATTACK2) && is_user_alive(id)) 
	{			
		if (on_knife[id])
		{
			if (halflife_time()-c_blink[id] <= 3) return PLUGIN_HANDLED		
			c_blink[id] = floatround(halflife_time())	
			UTIL_Teleport(id,300+15*player_intelligence[id])			
		}
	}
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

/*
Called on end or mapchange -- Save items for players
public plugin_end() 
{
	new Datafile[64], amxbasedir[64]
	//build_path(Datafile,63,"$basedir/diablo/datafile.txt") 
	
	get_basedir(amxbasedir,63)
	format(Datafile,63,"%s/diablo/datafile.txt",amxbasedir)
	
	if(file_exists(Datafile)) delete_file(Datafile)
	
	//Write name and item for each player
	for (new i=0; i < MAX; i++)
	{
		if (player_dc_item[i] > 0 && player_dc_item[i] != 100) //unique
		{
			new data[100]
			format(data,99,"%s^"%i^"",player_dc_name[i],player_dc_item[i])
			write_file(Datafile,data)
		}
	}
}
*/

/* ==================================================================================================== */


/* ==================================================================================================== */



/* ==================================================================================================== */



/* ==================================================================================================== */

public item_convertmoney(id)
{
	new maxhealth = race_heal[player_class[id]]+player_strength[id]*2
	
	if (cs_get_user_money(id) < 1000)
		hudmsg(id,2.0,"� ��� ������������ �����")
	else if (get_user_health(id) == maxhealth)
		hudmsg(id,2.0,"� ��� ���� ������������ ���������� ������")
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
		show_hudmessage(id, "���� item ����� ������������ ���� ��� �� �����!") 
	}
	
}

public resetwindwalk(szId[])
{
	new id = str_to_num(szId)
	if (id < 0 || id > MAX)
	{
		log_amx("������ � resetwindwalk, id: %i �� ��������� ����", id)
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
		hudmsg(id,2.0,"�� �������� ���� �� �������� ����������")
		Give_Xp(id,-floatround(3*player_lvl[id]/(1.65-player_lvl[id]/50)))
	}
	
}


/* ==================================================================================================== */
public show_menu_item(id)
{
	new text[513]

	format(text, 512, "\y����� item - ^n\w1. Mag ring^n\w2. Paladin ring^n\w3. Monk ring^n\w4. Barbarian ring^n\w5. Assassin ring^n\w6. Necromancer ring^n\w7. Ninja ring^n\w8. Flashbang necklace^n\w9. ������") 

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
showitem(id,"Mag ring","�����","���","<br>")
}
public paladinring(id)
{
showitem(id,"Paladin ring","�����","���","<br>")
}
public monkring(id)
{
showitem(id,"Monk ring","�����","���","<br>")
}
public barbarianring(id)
{
showitem(id,"Barbarian ring","�����","���","<br>")
}
public assassinring(id)
{
showitem(id,"Assassin ring","�����","���","<br>")
}
public nekromantring(id)
{
showitem(id,"Necromancer ring","�����","���","<br>")
}
public ninjaring(id)
{
showitem(id,"Ninja ring","�����","���","<br>")
}
public flashbangnecklace(id)
{
showitem(id,"Flashbang necklece","�����","���","<br>")
}

/* ==================================================================================================== */


public showmenu(id)
{
	new text[513] 
	new keys = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9)
	
	
	format(text, 512, "\r�����\R^n^n\y1.\w ����^n\y2.\w �������� ������� item^n\y3.\w ������^n\y4.\w ������������ ���� item^n\y5.\w ������� ���^n\y6.\w ���� � �������^n^n\y0.\w �������") 
	
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
			Use_Spell(id)
		}
		case 4:
		{
			buyrune(id)
		}
		case 5:
		{
			showskills(id)
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

public select_class_query(id)
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
		/*
			
			if(ret == RESULT_FAILED)
			{
				new szError[126]
				dbi_error(sql,szError,125)
				log_to_file("addons/amxmodx/logs/diablo.log","[Command Log] nie moglem wczytac lvl'i dla %s | klasy :*** %s",name,szError)
				dbi_free_result(ret)
				g_boolsqlOK=0
				player_class_lvl_save[id]=0
				dbi_close(sql)
				return PLUGIN_HANDLED
			}
			else if(ret == RESULT_NONE)
			{
				log_to_file("addons/amxmodx/logs/diablo.log","[Command Log] nie ma danych dla /class")
				create_klass(id)
				return PLUGIN_HANDLED
			}
			else while(ret && dbi_nextrow(ret)>0)
			{
				new i = dbi_result(ret, "class")
				lx[i] = dbi_result(ret, "lvl")
				player_class_lvl[id][i] = lx[i]
			}
			dbi_free_result(ret)
			player_class_lvl_save[id]=1
		*/
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
		log_to_file("addons/amxmodx/logs/diablo.log","Error on select_class_handle query: %s",Error)
		asked_klass[id]=0
	}
	if(FailState == TQUERY_CONNECT_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","Could not connect to SQL database.")
		asked_klass[id]=0
		return PLUGIN_CONTINUE
	}
	else if(FailState == TQUERY_QUERY_FAILED)
	{
		log_to_file("addons/amxmodx/logs/diablo.log","select_class_handle Query failed.")
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
}

public select_class(id,lx[])
{
new text4[512]  
format(text4, 511,"\y������ �����: ^n\r1. \w�����^n\r2. \w������^n\r3. \w��������^n\r4. \w�������^n^n\d �������� ���� �� �����^n\y����������: \rHiTmanY^n^n\y/mana,/m - ������� ����^n\dlp.hitmany.net^n\d���� �������") 

new keysczwarta
keysczwarta = (1<<0)|(1<<1)|(1<<2)|(1<<3)
show_menu(id, keysczwarta,text4, -1, "�������� �����")
}

public select_class_menu(id, key) 
{ 
new lx[28] // <-- w nawiasie wpisz liczb� swoich klas + 1(none)
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
c_piorun[id]=0
switch(key) 
{ 
        case 0: 
        {       
                PokazKlasy(id,lx)               
        }
        case 1: 
        {       
                ShowKlasy(id,lx)
        }
	case 2:
	{
		PokazZwierze(id,lx)
	}
	case 3:
	{
		PokazPremiumy(id,lx)
	}
}
LoadXP(id, player_class[id]) 

CurWeapon(id)
        
give_knife(id)
quest_gracza[id] = wczytaj_aktualny_quest(id);
changeskin(id,1)
        
return PLUGIN_HANDLED
}
public PokazKlasy(id,lx[])
{
new flags[28]
get_cvar_string("diablo_classes",flags,27) //<--- tu, gdzie jest 16 wpisz liczb� swoich klas
new text3[512]
asked_klass[id]=0
for(new i=0;i<8;i++)  //Tego masz nigdy nie zmienia�!!!!
{
    format(text3, 512,"\y�����: ^n\w1. \yMag^t\w�������: \r%i^n\w2. \yMonk^t\w�������: \r%i^n\w3. \yPaladin^t\w�������: \r%i^n\w4. \yAssassin^t\w�������: \r%i^n\w5. \yNecromancer^t\w�������: \r%i^n\w6. \yBarbarian^t\w�������: \r%i^n\w7. \yNinja^t\w�������: \r%i^n\w8. \yAmazon^t\w�������: \r%i^n^n\w0. \y�����^n^n\y�����5 ��� ������ ��� ������� �����^n\dlp.hitmany.net^n\d���� �������",
    player_class_lvl[id][1],player_class_lvl[id][2],player_class_lvl[id][3],player_class_lvl[id][4],player_class_lvl[id][5],player_class_lvl[id][6],player_class_lvl[id][7],player_class_lvl[id][8])
}

new keyspiata
keyspiata = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<9)
show_menu(id, keyspiata, text3, -1, "�����")
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
new lx[28] // <-- tutaj wpisz liczb� swoich klas + 1(none)
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
	c_shake[id]=20
        LoadXP(id, player_class[id])        
    }
    case 1: 
    {    
        player_class[id] = Monk
	c_damage[id]=3
	zmiana_skinu[id]=1
	changeskin(id,0)
        LoadXP(id, player_class[id])
    }
    case 2: 
    {    
        player_class[id] =  Paladin
        LoadXP(id, player_class[id])
    }
    case 3: 
    {    
        player_class[id] = Assassin
	c_jump[id]=1
	c_mine[id]=2
        LoadXP(id, player_class[id])
    }
    case 4: 
    {            
        player_class[id] = Necromancer
        g_haskit[id] = 1
	c_respawn[id]=4
	c_vampire[id]=random_num(1,3)
        LoadXP(id, player_class[id])
    }
    case 5: 
    {    
        player_class[id] = Barbarian      
        LoadXP(id, player_class[id])
    }
    case 6: 
    {    
        player_class[id] = Ninja
        LoadXP(id, player_class[id])
    }
    case 7: 
    {    
        player_class[id] = Amazon
        g_GrenadeTrap[id] = 1    
        LoadXP(id, player_class[id])
    }
    case 9: 
    { 
        select_class(id,lx)
    }
}
CurWeapon(id)
quest_gracza[id] = wczytaj_aktualny_quest(id);
give_knife(id)

return PLUGIN_HANDLED
}

public ShowKlasy(id,lx[]) {
new text2[512]
asked_klass[id]=0
format(text2, 511,"\y������: ^n\w1. \yAndariel^t\w�������: \r%i^n\w2. \yDuriel^t\w�������: \r%i^n\w3. \yMephisto^t\w�������: \r%i^n\w4. \yHephasto^t\w�������: \r%i^n\w5. \yDiablo^t\w�������: \r%i^n\w6. \yBaal^t\w�������: \r%i^n\w7. \yFallen^t\w�������: \r%i^n\w8. \yImp^t\w�������: \r%i^n^n\w0. \y�����^n^n\y����� 5��� ������ ��� ������� �����^n\dlp.hitmany.net^n\d���� �������",
player_class_lvl[id][9],player_class_lvl[id][10],player_class_lvl[id][11],player_class_lvl[id][12],player_class_lvl[id][13],player_class_lvl[id][14],player_class_lvl[id][15],player_class_lvl[id][16])

new szosta
szosta = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<9)
show_menu(id, szosta,text2, -1, "������")

}
public PressedKlasy(id, key) {
/* Menu:
* Demony:
* 1:Andariel
* 2:Duriel
* 3:Mephisto
* 4:Hephasto
* 5:Diablo
* 6:Baal
* 7:Fallen
* 8:Imp
* 0:Wstecz
*/
new lx[28] // <-- tutaj wpisz liczb� swoich klas + 1(none)
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


switch (key) {
    case 0:
    {    
        player_class[id] = Andariel
	c_vampire[id]=random_num(1,3)
	c_silent[id]=1
	c_jump[id]=1
	c_antyarchy[id]=1
	c_antymeek[id]=1
	c_antyorb[id]=1
	c_antyfs[id]=1
        LoadXP(id, player_class[id])
    }
    case 1: 
    {    
        player_class[id] = Duriel
	niewidzialnosc_kucanie[id] = 1;
        LoadXP(id, player_class[id])
    }
   case 2: 
    {    
        player_class[id] = Mephisto
	c_silent[id]=1
	c_jump[id]=2
        LoadXP(id, player_class[id])
    }
   case 3: 
    {    
        player_class[id] = Hephasto
	c_grenade[id] = 6
        LoadXP(id, player_class[id])
    }
   case 4: 
    {    
        player_class[id] = Diablo
	c_jump[id]=1
	c_silent[id]=1
	c_blind[id] = 20
        LoadXP(id, player_class[id])
    }
   case 5: 
    {    
        player_class[id] = Baal
	c_antyarchy[id]=0
        LoadXP(id, player_class[id])
    }
   case 6: 
    {    
        player_class[id] = Fallen
	c_darksteel[id]=29
	c_blind[id] = 20
	anty_flesh[id]=1
	c_shaked[id]=5
        LoadXP(id, player_class[id])
    }
   case 7: 
    {    
        player_class[id] = Imp
	c_blink[id] = floatround(halflife_time())
        LoadXP(id, player_class[id])
    }
   case 9: 
    { 
        select_class(id,lx)
    }
}
CurWeapon(id)
give_knife(id)
quest_gracza[id] = wczytaj_aktualny_quest(id);
changeskin(id,1)
    
return PLUGIN_HANDLED
}
public PokazZwierze(id,lx[]) {
new text5[512]
asked_klass[id]=0
format(text5, 511,"\y��������: ^n\w1. \yIzual^t\w�������: \r%i^n\w2. \yJumper^t\w�������: \r%i^n\w3. \yEnslaved^t\w�������: \r%i^n\w4. \yKernel^t\w�������: \r%i^n\w5. \yPoison Creeper^t\w�������: \r%i^n\w6. \yGiant Spider^t\w�������: \r%i^n\w7. \ySnow Wanderer^t\w�������: \r%i^n\w0. \y�����^n^n\y����� 5��� ������ ��� ������� �����^n\dlp.hitmany.net^n\d���� �������",
player_class_lvl[id][17],player_class_lvl[id][18],player_class_lvl[id][19],player_class_lvl[id][20],player_class_lvl[id][21],player_class_lvl[id][22],player_class_lvl[id][23])

new siodma
siodma = (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9)
show_menu(id, siodma,text5, -1, "��������")

}
public PokazZwierz(id, key) {
/* Menu:
---.Zwierzeta
1.Izual
2.Jumper
3.Enslaved
4.Kernel
5.PoisonCreeper
6.Gigantyczny Pajak
7.Sniegowy Tulacz
8.Piekielna Krowa
* 0:Wstecz
*/
new lx[28] // <-- tutaj wpisz liczb� swoich klas + 1(none)
g_haskit[id] = 0
c_redirect[id]=0
c_antymeek[id]=0
c_silent[id]=0
c_awp[id]=0
c_jump[id]=0
c_piorun[id]=0
c_vampire[id]=0

switch (key) {
    case 0:
    {    
        player_class[id] = Izual
	c_redirect[id]=4
	c_antymeek[id]=1
        LoadXP(id, player_class[id])
    }
    case 1: 
    {    
        player_class[id] = Jumper
        LoadXP(id, player_class[id])
    }
   case 2: 
    {    
        player_class[id] = Enslaved
        LoadXP(id, player_class[id])
    }
   case 3: 
    {    
        player_class[id] = Kernel
	c_silent[id]=1
	c_piorun[id]=1
        LoadXP(id, player_class[id])
    }
   case 4: 
    {    
        player_class[id] = PoisonCreeper
	c_awp[id]=5
	c_silent[id]=1
	c_jump[id]=1
	c_vampire[id]=1
        LoadXP(id, player_class[id])
    }
   case 5: 
    {    
        player_class[id] = GiantSpider
        LoadXP(id, player_class[id])
    }
   case 6: 
    {    
        player_class[id] = SnowWanderer
	c_piorun[id]=1
        LoadXP(id, player_class[id])
    }
   case 8: 
    { 
        select_class(id,lx)
    }
}
CurWeapon(id)
give_knife(id)
quest_gracza[id] = wczytaj_aktualny_quest(id);
    
return PLUGIN_HANDLED
}
public PokazPremiumy(id,lx[]) {
new text6[512]
asked_klass[id]=0
format(text6, 511,"\y�������: ^n\w1. \yGriswold^t\w�������: \r%i^n\w2. \yTheSmith^t\w�������: \r%i^n\w3. \yDemonolog^t\w�������: \r%i^n^n\w0. \y�����^n^n\r������ � ������� �������.^n\d������ �� lp.hitmany.net^n\d���� �������",player_class_lvl[id][24],player_class_lvl[id][25],player_class_lvl[id][26],player_class_lvl[id][27])

new usma
usma = (1<<0)|(1<<1)|(1<<2)|(1<<9)
show_menu(id, usma,text6, -1, "�������")

}
public PokazPremium(id, key) {
/* Menu:
* Wybierz klase:
* 1:Griswold
* 2:TheSmith
* 3:Demonolog
* 4:VipCztery
* 0:Wstecz
*/
new lx[28] // <-- tutaj wpisz liczb� swoich klas + 1(none)
g_haskit[id] = 0
c_antymeek[id]=0
c_silent[id]=0
c_antyarchy[id]=0
c_jump[id]=0
c_vampire[id]=0
niewidka[id]=0

switch (key) {
    case 0: 
    if( get_user_flags(id) & ADMIN_LEVEL_F)
    {    
    player_class[id] = Griswold
    c_antymeek[id]=1
    c_silent[id]=1
    c_antyarchy[id]=1
    c_jump[id]=2
    c_vampire[id]=random_num(1,2)
    LoadXP(id, player_class[id])
    }
    case 1: 
    if( get_user_flags(id) & ADMIN_LEVEL_F)
    {    
        player_class[id] = TheSmith
	c_antymeek[id]=1
	c_silent[id]=1
	c_antyarchy[id]=1
	c_jump[id]=2
	niewidka[id]=1
	c_piorun[id]=1
	c_vampire[id]=random_num(1,2)
        LoadXP(id, player_class[id])
    }
   case 2: 
   if( get_user_flags(id) & ADMIN_LEVEL_F)
    {    
    	
        player_class[id] = Demonolog
	c_antymeek[id]=1
	c_silent[id]=1
	c_antyarchy[id]=1
	c_jump[id]=2
	c_vampire[id]=random_num(1,2)
        LoadXP(id, player_class[id])
    }
   case 9: 
    { 
        select_class(id,lx)
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
	new headshot = read_data(3)
	if (player_class[id] == Barbarian)
	{	
		change_health(id,30,0,"")
	}
	if (player_class[id] == Mephisto)
	{	
		change_health(id,15,0,"")
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
	if (player_class[headshot] == SnowWanderer)
	{	
		change_health(id,30,0,"")
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
			change_health(id,-dmg,0,"")
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
		show_hudmessage(id, "���� item ����� ������������ ������ 1 ��� �� �����") 
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

	change_health(target,-DagonDamage,id,"world")
	Display_Fade(target,2600,2600,0,255,0,0,15)
	hudmsg(id,2.0,"���� ����� dagon %i, %i", DagonDamage, player_dextery[target]*2)

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
		hudmsg(id,2.0,"�� ������� �����")
		return false
	}
	
	return false
}
public buyrune(id)
{
	new text[513] 
	
	format(text, 512, "\y������� item - ^n\w1. \y������ ��������� Item! \r$5000^n^n\w0. \y�����^n\y/mana,/m - ������� ����") 
	
	new keys = (1<<0)|(1<<9)
	show_menu(id, keys, text) 
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
		if(player_b_dglmaster[id]>5) player_b_dglmaster[id]-=random_num(0,2)
		else if(player_b_dglmaster[id]>2) player_b_dglmaster[id]-=random_num(0,1)
		else if(player_b_dglmaster[id]>1) player_b_dglmaster[id]-=random_num(-1,1)
	}
	if(player_b_m4master[id]>0)
	{
		if(player_b_m4master[id]>5) player_b_m4master[id]-=random_num(0,2)
		else if(player_b_m4master[id]>2) player_b_m4master[id]-=random_num(0,1)
		else if(player_b_m4master[id]>1) player_b_m4master[id]-=random_num(-1,1)
	}
	if(player_b_akmaster[id]>0)
	{
		if(player_b_akmaster[id]>5) player_b_akmaster[id]-=random_num(0,2)
		else if(player_b_akmaster[id]>2) player_b_akmaster[id]-=random_num(0,1)
		else if(player_b_akmaster[id]>1) player_b_akmaster[id]-=random_num(-1,1)
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
	if (player_b_grenade[id] > 0 || player_b_smokehit[id] > 0)
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
		
		if(equali(greModel, "models/w_hegrenade.mdl" ) && player_b_grenade[id] > 0 || c_grenade[id] > 0)	
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
		player_class[id] = random_num(1,7)
		//load_xp(id)
	}
	
	return PLUGIN_CONTINUE
}

/* ==================================================================================================== */

public showskills(id)
{
	new Skillsinfo[768]
	format(Skillsinfo,767,"� ��� %i Strength - ��� ��� ���� %i HP<br><br>� ��� %i Dextery - ����. �������� �� %i% � ����. ���� �� ����� �� %i%<br>� ��� %i Agility - �������� ���� ����� �����. item � ����. ���� �� %0.0f%%<br><br>� ��� %i Intelligence - ����. ��������� � ���� �������� item<br>",
	player_strength[id],
	player_strength[id]*2,
	player_dextery[id],
	floatround(player_dextery[id]*1.3),
	player_dextery[id]*3,
	player_agility[id],
	player_damreduction[id]*100,
	player_intelligence[id])
	
	showitem(id,"�����������","���","���", Skillsinfo)
}

/* ==================================================================================================== */

public UTIL_Teleport(id,distance)
{	
	Set_Origin_Forward(id,distance)
	
	new origin[3]
	get_user_origin(id,origin)
	
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
	client_print(id,print_chat, "������ %s,�� �������? ������ � say /help", name)
}

/* ==================================================================================================== */



/* ==================================================================================================== */

public changerace(id)
{
	if(freeze_ended && player_class[id]!=NONE ) set_user_health(id,0)
	if(player_class[id]!=NONE) savexpcom(id)
	player_class[id]=NONE
	client_connect(id) 
	select_class_query(id)
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
		hudmsg(id,2.0,"�� ������ ������������ ����� ������ 1 ��� �� �����")
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
				hudmsg(pid,3.0,"������� ������. ������� � ����-������ ����� ����������!")
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
			
			hudmsg(pid,3.0,"������� ������. ������� � ����-������ ����� ����������!")
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
	change_health(id,-damage,attacker,"world")
	
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
		hudmsg(id,2.0,"Hook ����� ������������ ������ 1 ��� �� �����")
		return PLUGIN_CONTINUE	
	}
	
	new target = Find_Best_Angle(id,1000.0,false)
	
	if (!is_valid_ent(target))
	{
		hudmsg(id,2.0,"������ ��������� ��� ������������.")
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
		hudmsg(id,2.0,"�� ������ ���� � �������!")
		return PLUGIN_CONTINUE
	}
	
	if (halflife_time()-gravitytimer[id] <= 5)
	{
		hudmsg(id,2.0,"���� item, ����� ���� ����������� ������ 5 ������")
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
		
		change_health(pid,-dam,id,"world")			
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
		
		change_health(pid,-45,id,"world")
		Effect_Bleed(pid,100)
		Create_Slow(pid,3)
		
	}
	
	change_health(id,-10,id,"world")
		
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
		hudmsg(id,2.0,"���� item ����� ������������ ���� ��� �� �����!")
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
		hudmsg(id,2.0,"�� ������ ��������� �� 3�� ��� �� �����")
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
			hudmsg(id,2.0,"��� ���� � ������������")
			return PLUGIN_CONTINUE
		}
		
		if (pev(target,pev_rendermode) == kRenderTransTexture || player_item_id[target] == 17 || player_class[target] == Ninja)
		{
			hudmsg(id,2.0,"�� �������� ������������ ��������� ��� �� ������.")
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
		hudmsg(id,2.0,"����� ������� ����� ������������ ���� ��� �� �����!")
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
	
	if (is_user_connected(id) && freeze_ended)
	{
		new speeds
		if(player_class[id] == Ninja) speeds= 40 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Assassin) speeds= 30 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Baal) speeds= 40 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Mag) speeds= 20 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Duriel) speeds= -10 + floatround(player_dextery[id]*1.3)
		else if(player_class[id] == Barbarian) speeds= -10 + floatround(player_dextery[id]*1.3)
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
				
				set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, render)
			}
			else if (player_class[id] == Monk)
			{
				new inv_bonus = 255 - player_b_inv[id]
				render = 200
				
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
				
				set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, render)
			}
			else if (player_class[id] == Mephisto)
			{
				new inv_bonus = 255 - player_b_inv[id]
				render = 150
				
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
				
				set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, render)
			}
			else if(HasFlag(id,Flag_Moneyshield)||HasFlag(id,Flag_Rot)||HasFlag(id,Flag_Teamshield_Target))
			{
				if (player_b_usingwind[id]==1) set_user_rendering(id,kRenderFxNone, 0,0,0, kRenderTransTexture,75)
				
				if(HasFlag(id,Flag_Moneyshield)) set_user_rendering(id,kRenderFxGlowShell,0,0,0,kRenderNormal,16)  
				if(HasFlag(id,Flag_Rot)) set_rendering ( id, kRenderFxGlowShell, 255,255,0, kRenderFxNone, 10 )
				if(HasFlag(id,Flag_Teamshield_Target)) set_rendering ( id, kRenderFxGlowShell, 0,200,0, kRenderFxNone, 0 ) 
			}
			else if(invisible_cast[id]==1)
			{
				if(player_b_inv[id]>0) set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, floatround((10.0/255.0)*(255-player_b_inv[id])))
				else set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 10)
			}
			else if(niewidka[id]==1)
			{
				if(player_b_inv[id]>0) set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, floatround((10.0/255.0)*(255-player_b_inv[id])))
				else set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 20)
			}
			else
			{
				render = 255 
				if(player_b_inv[id]>0) render = player_b_inv[id]
				
				set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, render)
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
		else if(player_class[id] == Mephisto)
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
        len += formatex(motd[len],sizeof motd - 1 - len,"<tr><td>���</td><td>�����</td><td>�������</td><td>�������</td></tr>")
        //Title
        formatex(header,sizeof header - 1,"Diablo Mod Stats")
        
        for (i=0; i< numplayers; i++)
        {
                playerid = players[i]
                if ( get_user_team(playerid) == 1 ) team = "Terrorist"
                else if ( get_user_team(playerid) == 2 ) team = "CT"
                        else team = "Spectator"
                get_user_name( playerid, name, 31 )
                get_user_name( playerid, name, 31 )
                
                len += formatex(motd[len],sizeof motd - 1 - len,"<tr><td>%s</td><td>%s</td><td>%d</td><td>%s</td><td>%s</td></tr>",name,Race[player_class[playerid]], player_lvl[playerid],team,player_item_name[playerid])
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

public fwd_playerpostthink(id)
{
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
	
	return FMRES_IGNORED
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

public fwd_emitsound(id, channel, sound[]) 
{
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
	client_print(id, print_chat, "����������� %s", name)
		
	new revivaltime = get_pcvar_num(cvar_revival_time)
	msg_bartime(id, revivaltime)
	
	new Float:gametime = get_gametime()
	g_revive_delay[id] = gametime + float(revivaltime) - 0.01

	emit_sound(id, CHAN_AUTO, SOUND_START, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	set_task(0.0, "task_revive", TASKID_REVIVE + id)
	
	return FMRES_SUPERCEDE
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
		fm_give_item(id, "weapon_mp5navy")
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
		client_print(id,print_center,"� ��� ��� ���� ����������� ����")
		return PLUGIN_HANDLED
	}

	if(tossdelay[id] > get_gametime() - 0.9) return PLUGIN_HANDLED
	else tossdelay[id] = get_gametime()

	player_knife[id]--

	if (player_knife[id] == 1) {
		client_print(id,print_center,"������� ������ 1 ���!")
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
				client_print(id,print_center,"������� ���������� �����: %i",player_knife[id])
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

			change_health(id,-get_cvar_num("diablo_knife"),kid,"knife")
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
////////////////////////////////////////////////////////////////////////////////
//                             koniec z nozami                                //
////////////////////////////////////////////////////////////////////////////////
public mod_info(id)
{
	client_print(id,print_console,"����� ���������� � Diablo Mod �� HiTmAnY")
	client_print(id,print_console,"     ����� ���� � ���� �� �����")
	client_print(id,print_console,"        http://lp.hitmany.net")
	client_print(id,print_console,"        ������� ������ %s",mod_version)
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
	
	return PLUGIN_HANDLED
}

public command_bow(id) 
{
        if(!is_user_alive(id)) return PLUGIN_HANDLED
 
        if(bow[id] == 1){
                entity_set_string(id,EV_SZ_viewmodel,cbow_VIEW)
                entity_set_string(id,EV_SZ_weaponmodel,cvow_PLAYER)
		bowdelay[id] = get_gametime()
        }else if(player_sword[id] == 1)
	{
		entity_set_string(id, EV_SZ_viewmodel, SWORD_VIEW)  
		entity_set_string(id, EV_SZ_weaponmodel, SWORD_PLAYER)  
		bow[id]=0
	}
	else
	{
                entity_set_string(id,EV_SZ_viewmodel,KNIFE_VIEW)
                entity_set_string(id,EV_SZ_weaponmodel,KNIFE_PLAYER)
		bow[id]=0
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
	
		change_health(id,floatround(-dmg),kid,"knife")
				
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
	remove_entity(arrow)
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
			savexpcom(play[i])
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
			player_dmg[attacker]-=hp
			dmg_exp(attacker)
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
		entity_set_float(ent,EV_FL_health,50.0+float(player_intelligence[id]*2))
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
	
	set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 2.0, 0.1, 0.2, 2)
				
	switch(player_class[id])
	{
		case Mag:
		{
			show_hudmessage(id, "[Mag] ��������� ��������� ����") 
			fired[id]=0
			item_fireball(id)
		}
		case Monk:
		{
			if(num_shild[id])
			{
				show_hudmessage(id, "[Monk] ������ ������������") 
				createBlockAiming(id)
			}
			else show_hudmessage(id, "[Monk] �� �� ������ �������") 
		}
		case Paladin:
		{
			
			golden_bulet[id]++
			if(golden_bulet[id]>3)
			{
				golden_bulet[id]=3
				show_hudmessage(id, "[Paladin] � ��� ������������ ���-�� ���������� ����� - 3",golden_bulet[id]) 
			}
			else if(golden_bulet[id]==1)show_hudmessage(id, "[Paladin] � ��� ���� ���������� ����") 
			else if(golden_bulet[id]>1)show_hudmessage(id, "[Paladin] � ��� %i ���������� �����",golden_bulet[id]) 
		}
		case Assassin:
		{
			show_hudmessage(id, "[Assassin] Jestes tymczasowo niewidzialny (noz)") 
			invisible_cast[id]=1
			set_renderchange(id)
		}
		case Ninja:
		{
			show_hudmessage(id, "[Ninja] �� �������� ��������") 
			set_user_maxspeed(id,get_user_maxspeed(id)+25.0)
		}
		case Necromancer:
		{
			fm_give_item(id, "weapon_mp5navy")
			fm_give_item(id, "ammo_9mm")
			fm_give_item(id, "ammo_9mm")
			fm_give_item(id, "ammo_9mm")
			fm_give_item(id, "ammo_9mm")
			show_hudmessage(id, "[Necromancer] �� �������� MP5")
		}
		case Andariel:
		{
			fm_give_item(id, "weapon_galil")
			fm_give_item(id, "ammo_556nato")
			fm_give_item(id, "ammo_556nato")
			fm_give_item(id, "ammo_556nato")
			fm_give_item(id, "ammo_556nato")
			show_hudmessage(id, "[Andariel] �� �������� Galil")
		}
		case Izual:
		{
			lustrzany_pocisk[id]++
			if(lustrzany_pocisk[id]>2)
			{
				lustrzany_pocisk[id]=2
				show_hudmessage(id, "[Izual] � ��� �������� ������ ��������� - 2",lustrzany_pocisk[id]) 
			}
			else show_hudmessage(id, "[Izual] ���-�� ������ ��������� ����� - %i",lustrzany_pocisk[id]) 
		}
		case Barbarian:
		{
			ultra_armor[id]++
			if(ultra_armor[id]>7)
			{
				ultra_armor[id]=7
				show_hudmessage(id, "[Barbarian] ���������� ����������� ���-�� Ultra Armor - 7",ultra_armor[id]) 
			}
			else show_hudmessage(id, "[Barbarian] � ��� %i Ultra Armor",ultra_armor[id]) 
		}
		case Hephasto:
		{
			ultra_armor[id]++
			if(ultra_armor[id]>2)
			{
				ultra_armor[id]=2
				show_hudmessage(id, "[Hephasto] ������������ �������� �����. �������� - 2",ultra_armor[id]) 
			}
			else show_hudmessage(id, "[Hephasto] � ��� %i ���������� ��������",ultra_armor[id]) 
		}
		case Griswold:
		{
			if(player_item_id[id] != 0)
			show_hudmessage(id, "[Griswold] � ��� ��� ���� Item")
			else {
				losowe_itemy[id]++
				if(losowe_itemy[id] > 3) {
				losowe_itemy[id] = 3
				show_hudmessage(id, "[Griswold] ��������� ��������� - %i", losowe_itemy[id])
				}
				else
				award_item(id, 0)
		}
		}
		case TheSmith:
		{
			if(player_item_id[id] != 0)
			show_hudmessage(id, "[The Smith] � ��� ��� ���� Item")
			else {
				losowe_itemy[id]++
				if(losowe_itemy[id] > 3) {
				losowe_itemy[id] = 3
				show_hudmessage(id, "[The Smith] ��������� ��������� - %i", losowe_itemy[id])
				}
				else
				award_item(id, 0)
		}
		}
		case Demonolog:
		{
			if(player_item_id[id] != 0)
			show_hudmessage(id, "[Demonolog] � ��� ��� ���� Item")
			else {
				losowe_itemy[id]++
				if(losowe_itemy[id] > 3) {
				losowe_itemy[id] = 3
				show_hudmessage(id, "[Demonolog] ��������� ��������� - %i", losowe_itemy[id])
				}
				else
				award_item(id, 0)
		}
		}
		case Enslaved: 
		{
			change_health(id, 40, id, "")
			show_hudmessage(id, "[Enslaved] �� �������� 40hp")
		}
		case Amazon: 
		{
			fm_give_item(id, "weapon_hegrenade")
			show_hudmessage(id, "[Amazon] �� �������� HE �������")
		}
		case Fallen: 
		{
			fm_give_item(id, "weapon_flashbang")
			fm_give_item(id, "weapon_flashbang")
			show_hudmessage(id, "[Fallen] �� �������� 2 Flash �������")
		}
		case SnowWanderer: 
		{
			fm_give_item(id, "weapon_flashbang")
			fm_give_item(id, "weapon_flashbang")
			show_hudmessage(id, "[Snow Wanderer] �� �������� 2 Flash �������")
		}
		case GiantSpider: 
		{
			fm_give_item(id, "weapon_flashbang")
			fm_give_item(id, "weapon_flashbang")
			fm_give_item(id, "weapon_hegrenade")
			fm_give_item(id, "weapon_smokegrenade")
			fm_give_item(id, "weapon_deagle")
			fm_give_item(id,"ammo_50ae")
			fm_give_item(id,"ammo_50ae")
			fm_give_item(id,"ammo_50ae")
			fm_give_item(id,"ammo_50ae")
			fm_give_item(id,"ammo_50ae")
			fm_give_item(id,"ammo_50ae")
			show_hudmessage(id, "[Giant Spider] �� �������� ������ ����� ������ � Deagle")
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

public dmg_exp(id)
{
	new min=get_cvar_num("diablo_dmg_exp")
	if(min<1) return
	new exp=0
	while(player_dmg[id]>min)
	{
		player_dmg[id]-=min
		exp++
	}
	Give_Xp(id,exp)
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
		show_hudmessage(id, "������� ������� �� %i", player_lvl[id]) 
		savexpcom(id)
		player_class_lvl[id][player_class[id]]=player_lvl[id]
	}
	
	if (player_xp[id] < LevelXP[player_lvl[id]-1])
	{
		player_lvl[id]-=1
		player_point[id]-=2
		set_hudmessage(60, 200, 25, -1.0, 0.25, 0, 1.0, 2.0, 0.1, 0.2, 2)
		show_hudmessage(id, "������� ������� �� %i", player_lvl[id]) 
		savexpcom(id)
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

	LoadXP(id, player_class[id])
	CurWeapon(id)
	
	give_knife(id)
}



public native_get_user_item(id)
{
	return player_item_id[id]
}

public native_set_user_item(id, item)
{
	switch(item)
	{
		case 1:
		{
			player_item_name[id] = "Bronze Amplifier"
			player_b_damage[id] = random_num(1,3)
			show_hudmessage(id, "�� ����� item: %s ::  +%i ��������������� ����� � ������� ��������.",player_item_name[id],player_b_damage[id])
		}
		
		case 2:
		{
			player_item_name[id] = "Silver Amplifier"
			player_b_damage[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: +%i ��������������� ����� � ������� ��������.",player_item_name[id],player_b_damage[id])
		}
		
		case 3:
		{
			player_item_name[id] = "Gold Amplifier"
			player_b_damage[id] = random_num(6,10)
			show_hudmessage(id, "�� ����� item: %s :: +%i ��������������� ����� � ������� ��������.",player_item_name[id],player_b_damage[id])	
		}
		case 4:
		{
			player_item_name[id] = "Vampyric Staff"
			player_b_vampire[id] = random_num(1,4)
			show_hudmessage(id, "�� ����� item: %s :: %i hp ���������� � ������� ��������.",player_item_name[id],player_b_vampire[id])	
		}
		case 5:
		{
			player_item_name[id] = "Vampyric Amulet"
			player_b_vampire[id] = random_num(4,6)
			show_hudmessage(id, "�� ����� item: %s :: %i hp ���������� � ������� ��������.",player_item_name[id],player_b_vampire[id])	
		}
		case 6:
		{
			player_item_name[id] = "Vampyric Scepter"
			player_b_vampire[id] = random_num(6,9)
			show_hudmessage(id, "�� ����� item: %s :: %i hp ���������� � ������� ��������.",player_item_name[id],player_b_vampire[id])	
		}
		case 7:
		{
			player_item_name[id] = "Small bronze bag"
			player_b_money[id] = random_num(150,500)
			show_hudmessage(id, "�� ����� item: %s :: +%i ������ ����� + ��� ������� � ������������ ��� ������ ������� ���� �� ��� �� 50% ������ �� 200$ ������ 2-3 �������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 8:
		{
			player_item_name[id] = "Medium silver bag"
			player_b_money[id] = random_num(500,1200)
			show_hudmessage(id, "�� ����� item: %s :: +%i ������ ����� + ��� ������� � ������������ ��� ������ ������� ���� �� ��� �� 50% ������ �� 200$ ������ 2-3 �������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 9:
		{
			player_item_name[id] = "Large gold bag"
			player_b_money[id] = random_num(1200,3000)
			show_hudmessage(id, "�� ����� item: %s :: +%i ������ ����� + ��� ������� � ������������ ��� ������ ������� ���� �� ��� �� 50% ������ �� 200$ ������ 2-3 �������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)	
		}
		case 10:
		{
			player_item_name[id] = "Small angel wings"
			player_b_gravity[id] = random_num(1,5)
			
			if (is_user_alive(id))
				set_gravitychange(id)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i ����� � ���������� ��� ������ � ������� � ����� ������ �� ����� � ��������� ������� ����� �� ��������� �������.",player_item_name[id],player_b_gravity[id])	
		}
		case 11:
		{
			player_item_name[id] = "Arch angel wings"
			player_b_gravity[id] = random_num(5,9)
			
			if (is_user_alive(id))
				set_gravitychange(id)
				
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i ����� � ���������� ��� ������ � ������� � ����� ������ �� ����� � ��������� ������� ����� �� ������� �������.",player_item_name[id],player_b_gravity[id])	
			
		}
		case 12:
		{
			player_item_name[id] = "Invisibility Rope"
			player_b_inv[id] = random_num(150,200)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i �������������� ������������ ����.",player_item_name[id],255-player_b_inv[id])	
		}
		case 13:
		{
			player_item_name[id] = "Invisibility Coat"
			player_b_inv[id] = random_num(110,150)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i �������������� ������������ ����.",player_item_name[id],255-player_b_inv[id])	
		}
		case 14:
		{
			player_item_name[id] = "Invisibility Armor"
			player_b_inv[id] = random_num(70,110)
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i �������������� ������������ ����.",player_item_name[id],255-player_b_inv[id])	
		}
		case 15:
		{
			player_item_name[id] = "Firerope"
			player_b_grenade[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: +1/%i  ���� ��������� ����� ����� � �������",player_item_name[id],player_b_grenade[id])	
		}
		case 16:
		{
			player_item_name[id] = "Fire Amulet"
			player_b_grenade[id] = random_num(2,4)
			show_hudmessage(id, "�� ����� item: %s :: +1/%i  ���� ��������� ����� ����� � �������",player_item_name[id],player_b_grenade[id])	
		}
		case 17:
		{
			player_item_name[id] = "Stalkers ring"
			player_b_reduceH[id] = 95
			player_b_inv[id] = 8	
			item_durability[id] = 100
			
			if (is_user_alive(id)) set_user_health(id,5)		
			show_hudmessage(id, "�� ����� item: %s :: ����������� ������ �����������, �� � ��� 5 �� � �� ������ ������ ���, ����� ������� �����.",player_item_name[id])	
		}
		case 18:
		{
			player_item_name[id] = "Arabian Boots"
			player_b_theif[id] = random_num(500,1000)
			show_hudmessage(id, "�� ����� item: %s :: � ������ ��������� ���������� � ���������� ������, � ����������� �� ������",player_item_name[id],player_b_theif[id])	
		}
		case 19:
		{
			player_item_name[id] = "Phoenix Ring"
			player_b_respawn[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ������������ ����� ������.",player_item_name[id],player_b_respawn[id])	
		}
		case 20:
		{
			player_item_name[id] = "Sorcerers ring"
			player_b_respawn[id] = random_num(2,3)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ������������ ����� ������.",player_item_name[id],player_b_respawn[id])	
		}
		case 21:
		{
			player_item_name[id] = "Chaos Orb"
			player_b_explode[id] = random_num(150,275)
			show_hudmessage(id, "�� ����� item: %s :: ����� ������ ����������� � ������� %i",player_item_name[id],player_b_explode[id])	
		}
		case 22:
		{
			player_item_name[id] = "Hell Orb"
			player_b_explode[id] = random_num(200,400)
			show_hudmessage(id, "�� ����� item: %s :: ����� ������ ����������� � ������� %i",player_item_name[id],player_b_explode[id])	
		}
		case 23:
		{
			player_item_name[id] = "Gold statue"
			player_b_heal[id] = random_num(5,10)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ���������� �����, ������ ����� ��� � ���� �������. %i �� �� 5 ������, ����� ������� � ������� 7 ������ � �������� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 24:
		{
			player_item_name[id] = "Daylight Diamond"
			player_b_heal[id] = random_num(10,20)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ���������� �����, ������ ����� ��� � ���� �������. %i �� �� 5 ������, ����� ������� � ������� 7 ������ � �������� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 25:
		{
			player_item_name[id] = "Blood Diamond"
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ���������� �����, ������ ����� ��� � ���� �������. %i �� �� 5 ������, ����� ������� � ������� 7 ������ � �������� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 26:
		{
			player_item_name[id] = "Wheel of Fortune"
			player_b_gamble[id] = random_num(2,3)
			show_hudmessage(id, "�� ����� item: %s :: ��� �������� +%i ������� ������ �����.",player_item_name[id],player_b_gamble[id])	
		}
		case 27:
		{
			player_item_name[id] = "Four leaf Clover"
			player_b_gamble[id] = random_num(4,5)
			show_hudmessage(id, "�� ����� item: %s :: ��� �������� +%i ������� ������ �����.",player_item_name[id],player_b_gamble[id])	
		}
		case 28:
		{
			player_item_name[id] = "Amulet of the sun"
			player_b_blind[id] = random_num(6,9)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i �������� ���������� ��� �����. ����� ����������� ����� ���������� ��������� � ������� 7-10 ������",player_item_name[id],player_b_blind[id])	
		}
		case 29:
		{
			player_item_name[id] = "Sword of the sun"
			player_b_blind[id] = random_num(2,5)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i �������� ���������� ��� �����. ����� ����������� ����� ���������� ��������� � ������� 7-10 ������",player_item_name[id],player_b_blind[id])	
		}
		case 30:
		{
			player_item_name[id] = "Fireshield"
			player_b_fireshield[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� � ������������ ��� ������� ������� ����� ����������. ��������� ���� ��������, 20 �� ������ 2 �������.",player_item_name[id],player_b_fireshield[id])	
		}
		case 31:
		{
			player_item_name[id] = "Stealth Shoes"
			player_b_silent[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��������� ��� (����� ����� assassin).",player_item_name[id])	
		}
		case 32:
		{
			player_item_name[id] = "Meekstone"
			player_b_meekstone[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ����� �� ������������ ����������. � �������� �����, ������ ������� � ��������.",player_item_name[id])	
		}
		case 33:
		{
			player_item_name[id] = "Medicine Glar"
			player_b_teamheal[id] = random_num(10,20)
			show_hudmessage(id, "�� ����� item: %s :: ��� ����� � ������������ ���������������� %i ��. ��� ������� � ���������� �� ����� ������� ��� ������ ���������� �����.",player_item_name[id],player_b_teamheal[id])	
		}
		case 34:
		{
			player_item_name[id] = "Medicine Totem"
			player_b_teamheal[id] = random_num(20,30)
			show_hudmessage(id, "�� ����� item: %s :: ��� ����� � ������������ ���������������� %i ��. ��� ������� � ���������� �� ����� ������� ��� ������ ���������� �����.",player_item_name[id],player_b_teamheal[id])	
		}
		case 35:
		{
			player_item_name[id] = "Iron Armor"
			player_b_redirect[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: ������� +%i ������ �� ��� � ������� ��������.",player_item_name[id],player_b_redirect[id])	
		}
		case 36:
		{
			player_item_name[id] = "Mitril Armor"
			player_b_redirect[id] = random_num(6,11)
			show_hudmessage(id, "�� ����� item: %s :: ������� +%i ������ �� ��� � ������� ��������.",player_item_name[id],player_b_redirect[id])	
		}
		case 37:
		{
			player_item_name[id] = "Godly Armor"
			player_b_redirect[id] = random_num(10,15)
			show_hudmessage(id, "�� ����� item: %s :: ������� +%i ������ �� ��� � ������� ��������.",player_item_name[id],player_b_redirect[id])	
		}
		case 38:
		{
			player_item_name[id] = "Fireball staff"
			player_b_fireball[id] = random_num(50,100)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ������, ������������ � ������� %i",player_item_name[id],player_b_fireball[id])	
		}
		case 39:
		{
			player_item_name[id] = "Fireball scepter"
			player_b_fireball[id] = random_num(100,200)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ������, ������������ � ������� %i",player_item_name[id],player_b_fireball[id])	
		}
		case 40:
		{
			player_item_name[id] = "Ghost Rope"
			player_b_ghost[id] = random_num(3,6)
			show_hudmessage(id, "�� ����� item: %s :: ����������� ������ ������ �����, ����� ������� %i ������",player_item_name[id],player_b_ghost[id])	
		}
		case 41:
		{
			player_item_name[id] = "Nicolas Eye"
			player_b_eye[id] = -1
			show_hudmessage(id, "�� ����� item: %s :: ������������� ������ �� �����.",player_item_name[id])	
		}
		case 42:
		{
			player_item_name[id] = "Knife Ruby"
			player_b_blink[id] = floatround(halflife_time())
			show_hudmessage(id, "�� ����� item: %s :: ��� ������������� ���� ������ �������� ������������� ��� �� ��������� ���������",player_item_name[id])	
		}
		case 43:
		{
			player_item_name[id] = "Lothars Edge"
			player_b_windwalk[id] = random_num(4,7)
			show_hudmessage(id, "�� ����� item: %s :: �� %i ������ ��� ������� ������������ + ������ ����������� ��� ���.",player_item_name[id],player_b_windwalk[id])	
		}
		case 44:
		{
			player_item_name[id] = "Sword"
			player_sword[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ����������� ���� ����",player_item_name[id])		
		}
		case 45:
		{
			player_item_name[id] = "Mageic Booster"
			player_b_froglegs[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ������ 3 ������� ���� �� ����� ������ ��������.(item �� ������ ��������)",player_item_name[id])	
		}
		case 46:
		{
			player_item_name[id] = "Dagon I"
			player_b_dagon[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� USE ������� ����� ���������� �� ������� ��������� ��� � 20 ������",player_item_name[id])	
		}
		case 47:
		{
			player_item_name[id] = "Scout Extender"
			player_b_sniper[id] = random_num(3,4)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ��������� ����� �� ������.",player_item_name[id],player_b_sniper[id])	
		}
		case 48:
		{
			player_item_name[id] = "Scout Amplifier"
			player_b_sniper[id] = random_num(2,3)
			show_hudmessage(id, "�� ����� item: %s :: ���� 1/%i ��������� ����� �� ������.",player_item_name[id],player_b_sniper[id])	
		}
		case 49:
		{
			player_item_name[id] = "Air booster"
			player_b_jumpx[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: �� ������ ������� ������� ������ � �������",player_item_name[id],player_b_sniper[id])	
		}
		case 50:
		{
			player_item_name[id] = "Iron Spikes"
			player_b_smokehit[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ������� ������� ��������, ���� ������� �� � ����������",player_item_name[id])	
		}
		case 51:
		{
			player_item_name[id] = "Point Booster"
			player_b_extrastats[id] = random_num(1,3)
			BoostStats(id,player_b_extrastats[id])
			show_hudmessage(id, "�� ����� item: %s :: ��� +%i ����� � ������� �������",player_item_name[id],player_b_extrastats[id])	
		}
		case 52:
		{
			player_item_name[id] = "Totem amulet"
			player_b_firetotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � ������ ����� ����� ������� ����� ��������� ������ ���������� � ��������� ���� � ������� �������.",player_item_name[id])	
		}
		case 53:
		{
			player_item_name[id] = "Mageic Hook"
			player_b_hook[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� USE ����������� � ���� �����",player_item_name[id])	
		}
		case 54:
		{
			player_item_name[id] = "Darksteel Glove"
			player_b_darksteel[id] = random_num(1,5)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ����� ��� ����� ���������� �� �����.",player_item_name[id])	
		}
		case 55:
		{
			player_item_name[id] = "Darksteel Gaunlet"
			player_b_darksteel[id] = random_num(7,9)
			show_hudmessage(id, "�� ����� item: %s :: ��������� ����� ��� ����� ���������� �� �����.",player_item_name[id])	
		}
		case 56:
		{
			player_item_name[id] = "Illusionists Cape"
			player_b_illusionist[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ������� �� � �� ����������� ��������� (100%)���������. ������ � �� ������ �� ������ � �������� �� 1 ��������.",player_item_name[id])	
		}
		case 57:
		{
			player_item_name[id] = "Techies scepter"
			player_b_mine[id] = 3
			show_hudmessage(id, "�� ����� item: %s :: ������ 3 ������������� ����.",player_item_name[id])
		}
		
		case 58:
		{
			player_item_name[id] = "Ninja ring"
			player_b_blink[id] = floatround(halflife_time())
			player_b_froglegs[id] = 1
			show_hudmessage(id, "�� ����� item: %s :: ��� ��������� ��� ����������������� ������ 3 �������. ������� DUCK ����� �������� ������.",player_item_name[id])
		}
		case 59:	
		{
			player_item_name[id] = "Mage ring"
			player_ring[id]=1
			player_b_fireball[id] = random_num(50,80)
			show_hudmessage(id, "�� ����� item : %s :: ����������� �������� ��������� ������ +5 ���������",player_item_name[id])
		}	
		case 60:	
		{
			player_item_name[id] = "Necromant ring"
			player_b_respawn[id] = random_num(2,4)
			player_b_vampire[id] = random_num(3,5)	
			show_hudmessage(id, "�� ����� item : %s :: ���� ����������� ����� ������. ��� ��������� �� �����, �������� ���������� ���� ��",player_item_name[id])
		}
		case 61:
		{
			player_item_name[id] = "Barbarian ring"
			player_b_explode[id] = random_num(120,330)
			player_ring[id]=2
			show_hudmessage(id, "�� ����� item : %s :: ����� ��� ������� �� �����������, ������ ���� ������� � ����� ������. +5 ����",player_item_name[id])
		}
		case 62:
		{
			player_item_name[id] = "Paladin ring"	
			player_b_redirect[id] = random_num(7,17)
			player_b_blind[id] = random_num(3,4)
			show_hudmessage(id, "�� ����� item : %s :: �������� ������ �� ���. ���� �������� ����������",player_item_name[id])		
		}
		case 63:
		{
			player_item_name[id] = "Monk ring"
			player_b_grenade[id] = random_num(1,4)
			player_b_heal[id] = random_num(20,35)
			show_hudmessage(id, "�� ����� item : %s :: ����������� ���� ��������� ��������. ��������������� ��������",player_item_name[id])
		}	
		case 64:
		{
			player_item_name[id] = "Assassin ring"
			player_b_jumpx[id] = 1
			player_ring[id]=3
			show_hudmessage(id, "�� ����� item : %s :: ������� ������. +5 ��������",player_item_name[id])	
		}	
		case 65:
		{
			player_item_name[id] = "Flashbang necklace"	
			wear_sun[id] = 1
			show_hudmessage (id, "�� ����� item : %s :: ��������� � ����������� ��������",player_item_name[id])
		}
		case 66:
		{
			player_item_name[id] = "Chameleon"	
			changeskin(id,0)  
			show_hudmessage (id, "�� ����� item : %s :: ����������� �� ����� (������� ���)",player_item_name[id])
		}
		case 67:
		{
			player_item_name[id] = "Stong Armor"	
			player_ultra_armor[id]=random_num(3,6)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "�� ����� item : %s :: ������ ����� ����� ���������� ������ %i",player_item_name[id],player_ultra_armor[id])
		}
		case 68:
		{
			player_item_name[id] = "Ultra Armor"	
			player_ultra_armor[id]=random_num(7,11)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage (id, "�� ����� item : %s :: ������ ����� ����� ���������� ������ %i",player_item_name[id],player_ultra_armor[id])
		}
		case 69:
		{
			player_item_name[id] = "Khalim Eye"
			player_b_radar[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: �� ������ ����������� �� ������", player_item_name[id])
		}
		case 70:
		{
			player_item_name[id] = "Jumper Ring"
			player_b_autobh[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ��� ��� ���� ���������. ���������� � ������������.", player_item_name[id])
		}
		case 71:
		{
			player_item_name[id] = "Myrmidon Greaves"
			player_b_silent[id] = 1
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/2)
			show_hudmessage (id, "�� ����� item : %s :: ��������� � ������� ���",player_item_name[id],player_b_silent[id])
		}
		case 72:
		{
			player_item_name[id] = "Shoes of the Bone"
			player_b_jumpx[id] = 4
			set_user_gravity(id, 600.0)
			show_hudmessage (id, "�� ����� item : %s :: �� ������ ������� 4 ������ � �������. ���������� ����������",player_item_name[id],player_b_jumpx[id])
		}
		case 73:
		{
			player_item_name[id] = "Scarab Shoes"
			player_b_inv[id] = 95
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "�� ����� item : %s :: ��� ��������� ��������� �� 95. ������� ���.",player_item_name[id],player_b_inv[id])
		}
		case 74:
		{
			player_item_name[id] = "Hydra Blade"
			player_b_inv[id] = 155
			player_b_damage[id] = 20
			show_hudmessage (id, "�� ����� item : %s :: ��� ��������� ��������� �� 155 +20 � �����",player_item_name[id],player_b_inv[id],player_b_damage[id])
		}
		case 75:
		{
			player_item_name[id] = "Exp Ring"
			new xp_award = get_cvar_num("diablo_xpbonus")*2
			show_hudmessage (id, "�� ����� item : %s :: ���������� ����� �� %i",player_item_name[id],xp_award)
		}
		case 76:
		{
			player_item_name[id] = "Aegis"
			player_ring[id]=2
			player_b_explode[id] = random_num(120,330)
			player_b_redirect[id] = random_num(10, 100)
			show_hudmessage (id, "�� ����� item : %s :: �� ��������� +5 � ���� � ����������� ����� ��������(���� %i) -%i ����� �� ���",player_item_name[id],player_b_explode[id],player_b_redirect[id])
		}
		case 77:
		{
			player_item_name[id] = "Polished Wand"
			player_b_blind[id] = random_num(1,5)
			player_b_heal[id] =  random_num(1,15)
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/%i �������� �����, ��� E ����� ���������� ���������� �����",player_item_name[id],player_b_blind[id])
		}
		case 78:
		{
			player_item_name[id] = "Heavenly Stone"
			player_b_grenade[id] = random_num(1,3)
			set_user_maxspeed(id, get_user_maxspeed(id)+get_user_maxspeed(id)/4)
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/%i ��������� ����� HE ������� � ������� ���",player_item_name[id],player_b_grenade[id])
		}
		case 79:
		{
			player_item_name[id] = "Festering Essence of Destruction"
			player_b_respawn[id] = 2
			player_b_sniper[id] = 1
			player_b_grenade[id] = 3
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/2 ����������, ���� 1/1 ��������� ����� �� ������,���� 1/3 ����� � HE",player_item_name[id])
		}
		case 80:
		{
			player_item_name[id] = "Vampire Gloves"
			player_b_vampire[id] = random_num(5,15)
			show_hudmessage(id, "�� ����� item : %s :: ���������� %i �� ������ ��������� �� �����,�� �������� +30hp",player_item_name[id],player_b_vampire[id])
		}
		case 81:
		{
			player_item_name[id] = "Super Mario"
			player_b_jumpx[id] = 10
			player_b_fireball[id] = 5
			show_hudmessage (id, "�� ����� item : %s :: �� ������ ������� 10 ������� � ������ � ������� �� 5 �����",player_item_name[id],player_b_jumpx[id], player_b_fireball[id])
		}
		case 85:
		{
			player_item_name[id] = "Centurion"
			player_b_damage[id] = 20
			player_b_redirect[id] = 40
			set_user_gravity(id,3.0)
			show_hudmessage (id, "�� ����� item : %s :: +20 � ����� � ���������� ����� �� 40",player_item_name[id],player_b_damage[id],player_b_redirect[id])
		}
		case 86:
		{
			player_item_name[id] = "RedBull"
			player_b_jumpx[id] = 8
			show_hudmessage(id, "�� ����� item : %s :: �� ������ ������� 8 ������� � �������",player_item_name[id],player_b_sniper[id])	
		}
		case 87:
		{
			player_item_name[id] = "Dr House"
			player_b_heal[id] = random_num(45,65)
			show_hudmessage(id, "�� ����� item : %s :: ��������������� %i hp ������ 5 ������. ����� � ����� ���������� ������� ����� %i",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 88:
		{
			player_item_name[id] = "Own Invisible"
			player_b_inv[id] = 8
			player_b_reduceH[id] = 55
			if (is_user_alive(id)) set_user_health(id,45)
			show_hudmessage(id, "�� ����� item : %s :: �� ����� ��������,�� � ��� 45 HP.",player_item_name[id])	
		}
		case 89:
		{
			player_item_name[id] = "Mega Invisible"
			player_b_reduceH[id] = 90
			player_b_inv[id] = 1	
			item_durability[id] = 50
			
			if (is_user_alive(id)) set_user_health(id,10)		
			show_hudmessage(id, "�� ����� item : %s :: � ��� 10 ������,����������� 1/255",player_item_name[id])	
		}
		case 90:
		{
			player_item_name[id] = "Bul'Kathos Shoes"
			player_b_jumpx[id] = 8
			set_user_gravity(id, 400.0)
			show_hudmessage(id, "�� ����� item : %s :: �� ������ ������� 8 ������� � ������� � � ��� ������� ����������",player_item_name[id],player_b_sniper[id])	
		}
		case 91:
		{
			player_item_name[id] = "Karik's Ring"
			player_b_redirect[id] = random_num(15,50)
			player_b_damage[id] = random_num(15,50)
			player_b_blind[id] = random_num(3,4)
			player_ultra_armor[id]=random_num(15,50)
			player_ultra_armor_left[id]=player_ultra_armor[id]
			show_hudmessage(id, "�� ����� item : %s :: Item ��������� ������,��� ����� ��� �� ������ ��� ��������� ��������",player_item_name[id])		
		}
		case 92:
		{
			player_item_name[id] = "Purse Thief"
			player_b_money[id] = random_num(1,16000)
			show_hudmessage(id, "�� ����� item : %s :: ��������� %i ����� � ������ ������. ����������� ����� ����������.",player_item_name[id],player_b_money[id]+player_intelligence[id]*50)
		}
		case 93:
		{
			player_item_name[id] = "Vampiric Blood"
			player_b_vampire[id] = random_num(15,20)
			show_hudmessage(id, "�� ����� item : %s :: ����������� %i hp � ����������",player_item_name[id],player_b_vampire[id])	
		}
		case 94:
		{
			player_item_name[id] = "Revival Ring"
			player_b_respawn[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: 1/%i ���� �� �����������",player_item_name[id],player_b_respawn[id])	
		}
		case 95:
		{
			player_item_name[id] = "Demon Assassin"
			player_b_heal[id] = random_num(30,55)
			player_b_damage[id] = 50
			show_hudmessage(id, "�� ����� item : %s :: ��������������� %i hp ������ 5 ������. ����� � ����� ���������� ������� ����� %i. +50 � �����",player_item_name[id],player_b_heal[id],player_b_heal[id])	
		}
		case 96:
		{
			player_item_name[id] = "Mystiqe"
			changeskin(id,0)
			player_b_grenade[id] = random_num(1,2)
			show_hudmessage (id, "�� ����� item : %s :: �� ��������� ��� ���������.���� 1/%i ��������� ����� � ������� HE",player_item_name[id],player_b_grenade[id])
		}
		case 97:
		{
			player_item_name[id] = "Apocalypse Anihilation"
			player_b_damage[id] = 100
			player_b_silent[id] = 1
			item_durability[id] = 100
			show_hudmessage (id, "�� ����� item : %s :: �� �� ������ %i ����� � ������� ��������.��������� ���.",player_item_name[id],player_b_damage[id],player_b_silent[id])
		}
		case 98:
		{
			player_item_name[id] = "Inferno"
			player_b_redirect[id] = 10
			player_b_damage[id] = 10
			player_b_respawn[id] = 2
			show_hudmessage (id, "�� ����� item : %s :: +10 � �����. -10 ����� �� ���. ���� 1/2 ����������.",player_item_name[id])
		}
		case 99:
		{
			player_item_name[id] = "Hellspawn"
			player_b_grenade[id] = 5
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "�� ����� item : %s :: ���� 1/5 ����� � �� �������.+%i � �����������",player_item_name[id],255-player_b_inv[id])
		}
		case 100:
		{
			player_item_name[id] = "Shako"
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(70,110)
			show_hudmessage (id, "�� ����� item : %s :: +25����� || +%i � �����������",player_item_name[id],255-player_b_inv[id])
		}
		case 101:
		{
			player_item_name[id] = "Annihilus"
			player_b_damage[id] = 15
			player_b_vampire[id] = 50
			show_hudmessage (id, "�� ����� item : %s :: +15 � �����. ���������� 50hp � ������� ��������",player_item_name[id])
		}
		case 102:
		{
			player_item_name[id] = "Blizzard's Mystery"
			player_b_damage[id] = 25
			player_b_vampire[id] = 25
			item_durability[id] = 100
			show_hudmessage (id, "�� ����� item : %s :: +25 � �����. ���������� 25 HP � ������� ��������",player_item_name[id])
		}
		case 103:
		{
			player_item_name[id] = "Mara's Kaleidoscope"
			player_b_damage[id] = 25
			player_b_inv[id] = random_num(190,200)
			show_hudmessage (id, "�� ����� item : %s :: +25 � �����. +%i � �����������",player_item_name[id],255-player_b_inv[id])
		}
		case 104:
		{
			player_item_name[id] = "M4A1 Special"
			item_durability[id] = 100
			player_b_m4master[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � M4A1",player_item_name[id],player_b_m4master[id])
		}
		case 105:
		{
			player_item_name[id] = "AK47 Special"
			item_durability[id] = 100
			player_b_akmaster[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � AK47",player_item_name[id],player_b_akmaster[id])
		}
		case 106:
		{
			player_item_name[id] = "AWP Special"
			item_durability[id] = 100
			player_b_awpmaster[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � AWP",player_item_name[id],player_b_awpmaster[id])
		}
		case 107:
		{
			player_item_name[id] = "Deagle Special"
			item_durability[id] = 100
			player_b_dglmaster[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � Deagle",player_item_name[id],player_b_dglmaster[id])
		}
		case 108:
		{
			player_item_name[id] = "M3 Special"
			item_durability[id] = 100
			player_b_m3master[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � M3",player_item_name[id],player_b_m3master[id])
		}
		case 109:
		{
			player_item_name[id] = "Full Special"
			item_durability[id] = 100
			player_b_m3master[id] = random_num(1,8)
			player_b_dglmaster[id] = random_num(1,8)
			player_b_awpmaster[id] = random_num(1,8)
			player_b_akmaster[id] = random_num(1,8)
			player_b_m4master[id] = random_num(1,8)
			player_b_grenade[id] = random_num(1,8)
			player_b_sniper[id] = random_num(1,8)
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� ����� � M3,1/%i � Deagle,1/%i � AWP,1/%i � AK47,1/%i � M4A1,1/%i � HE,1/%i � ������",player_item_name[id],player_b_m3master[id],player_b_dglmaster[id],player_b_awpmaster[id],player_b_akmaster[id],player_b_m4master[id],player_b_grenade[id],player_b_sniper[id])
		}
		case 110:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 111:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 112:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 113:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 114:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		
		case 115:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 116:
		{
			player_item_name[id] = "Diablo Shoes"
			player_b_antyarchy[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� �� Arch angel", player_item_name[id], player_b_antyarchy[id])
		}
		case 117:
		{
			player_item_name[id] = "Minesweeper Vigilance"
			player_b_antymeek[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� Meekstone", player_item_name[id], player_b_antymeek[id])
		}
		case 118:
		{
			player_item_name[id] = "Anti Explosion"
			player_b_antyorb[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ��������� �� ������ ����� ��������", player_item_name[id], player_b_antyorb[id])
		}
		case 119:
		{
			player_item_name[id] = "Anti HellFlare"
			player_b_antyfs[id] = 1
			show_hudmessage(id, "�� ����� item : %s :: ���� 1/%i ������ �� ����", player_item_name[id], player_b_antyfs[id])
		}
		case 120:
		{
			player_item_name[id] = "Gheed's Fortune"
			player_b_godmode[id] = random_num(4,10)
			show_hudmessage(id, "�� ����� item : %s :: �� ����������� ���������� �� %i ������.", player_item_name[id], player_b_godmode[id])
		}
		case 121:
		{
			player_item_name[id] = "Winter Totem"
			player_b_zamroztotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ����� � ����� ���������� �������������� �����",player_item_name[id])	
		}
		case 122:
		{
			player_item_name[id] = "Cash Totem"
			player_b_kasatotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ��� E ����� ���������� ����� ������� ��� ��� � ����� ������� ������.",player_item_name[id])	
		}
		case 123:
		{
			player_item_name[id] = "Thief Totem"
			player_b_kasaqtotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ��� E ����� ���������� ����� ������� ����������� ������� �����.",player_item_name[id])	
		}
		case 124:
		{
			player_item_name[id] = "Weapon Totem"
			player_b_wywaltotem[id] = random_num(250,400)
			show_hudmessage(id, "�� ����� item : %s :: ��� E ����� ���������� ����� ������� ����������� ������ ����������.",player_item_name[id])	
		}
		case 125:
		{
			player_item_name[id] = "Flash Totem"
			player_b_fleshujtotem[id] = random_num(250,400)
			show_hudmessage(id, "��� E ����� ���������� ����� ������� ��������� ����������.",player_item_name[id])	
		}

	}
	player_item_id[id] = item
	BoostRing(id)
}
public StworzRakiete(id)
{
	if (!ilosc_rakiet_gracza[id] && is_user_alive(id))
	{
		client_print(id, print_center, "� ��� ����������� ������!");
		return PLUGIN_CONTINUE;
	}
	
	if(poprzednia_rakieta_gracza[id] + 3.0 > get_gametime())
	{
		client_print(id, print_center, "������ ����� ������������ ������ 3 �������!");
		return PLUGIN_CONTINUE;
	}
	
	if (is_user_alive(id))
	{	
		if(player_intelligence[id] < 1)
			client_print(id, print_center, "����� ������� ������ ��������� ���������!");
			
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
			continue;
		ExecuteHam(Ham_TakeDamage, pid, ent, attacker, 50.0+float(player_intelligence[attacker])/2 , 1);
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
				client_print(id, print_chat, "[�������] � ��� ����������� �������.")
				statusMsg(id, "[�������] %d �� %d ������.", gHooksUsed[id], get_pcvar_num(pMaxHooks))
				
				return PLUGIN_HANDLED
			}
			else 
			{
				gHooksUsed[id]++
				statusMsg(id, "[�������] %d �� %d ������", gHooksUsed[id], get_pcvar_num(pMaxHooks))
			}
		}
		new Float:fDelay = get_pcvar_float(pRndStartDelay)
		if (fDelay > 0 && !rndStarted)
			client_print(id, print_chat, "[�������] �� �� ������ ������������ ������� ��������� %0.0f ������ ��� ����� ����������", fDelay)
			
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
					emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hitbod1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
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
						emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hitbod1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
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
				emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
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
			emit_sound(ptr, CHAN_STATIC, "weapons/xbow_hit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		
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
		client_print(id, print_chat, "�� ���� ������� �������")
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
		console_print(id, "[�������] ����� ��� ��������")
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
		
		console_print(id, "[�������] %s ������� ������ � �������", szName)
	}
	else
		console_print(id, "[�������] � %s ��� ���� �������", szName)
	
	return PLUGIN_HANDLED
}

public take_hook(id, level, cid)
{
	if (!cmd_access(id ,level, cid, 1))
		return PLUGIN_HANDLED
	
	if (!get_pcvar_num(pAdmin))
	{
		console_print(id, "[�������] ����� ������ ��������")
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
		
		console_print(id, "[�������] �� ������� � %s ������ � �������", szName)
	}
	else
		console_print(id, "[�������] � %s ��� ������� � �������", szName)
	
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
public itminfo(id,cel){  // po najechaniu na item pokazuje co to za item :D 
        static clas[32];
        pev(cel,pev_classname,clas,31);
        
        if (!equali(clas,"przedmiot")) return PLUGIN_CONTINUE
        set_hudmessage(255, 170, 0, 0.3, 0.56, 0, 6.0, 0.1)
        show_hudmessage(id, "��� Item: %s ",item_name[cel])
        
        return PLUGIN_CONTINUE
}

public create_itm(id,id_item,name_item[128]){ 
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
    if(!player_item_id[id] && pev(id,pev_button)& IN_DUCK){ // jesli dotykamy kucamy i nie mamy itemu to go dostajemy (podnoszenie itemu - dotkniecie i duck)
        award_item(id,item_info[ent])
        engfunc(EngFunc_RemoveEntity,ent);
    }
    return FMRES_IGNORED; 
}
public TTWin() {
        new play[32], nr, id;
        get_players(play, nr, "h");
        for(new i=0; i<nr; i++) {
                id = play[i];
                if(is_user_connected(id) && cs_get_user_team(id) == CS_TEAM_T) {
                        new dziel = is_user_alive(id) ? 1 : 2;
                        Give_Xp(id, get_cvar_num("diablo_xpbonus3")/dziel);
                        ColorChat(id, GREEN, "���������^x03 *%i*^x01 ����� �� ������ ����� ������� � ������", get_cvar_num("diablo_xpbonus3")/dziel);
                }
        }
}

public CTWin() {
        new play[32], nr, id;
        get_players(play, nr, "h");
        for(new i=0; i<nr; i++) {
                id = play[i];
                if(is_user_connected(id) && cs_get_user_team(id) == CS_TEAM_CT) {
                        new dziel = is_user_alive(id) ? 1 : 2;
                        Give_Xp(id, get_cvar_num("diablo_xpbonus3")/dziel);
                        ColorChat(id, GREEN, "���������^x03 *%i*^x01 ����� �� ������ ����� ������� � ������", get_cvar_num("diablo_xpbonus3")/dziel);
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
public item_ulecz(id)
{
        if (used_item[id])
        {
                hudmsg(id,2.0,"������� ����� 1 ��� �� �����!")
                return PLUGIN_CONTINUE  
        }
        new m_healthf = race_heal[player_class[id]]+player_strength[id]*2
	new CurHealthf = get_user_health(id)
	new NewHealthf = (CurHealthf+50<m_healthf)? CurHealthf+50:m_healthf
        set_user_health(id, NewHealthf)
        
        used_item[id] = true    
        return PLUGIN_CONTINUE
        
}
public check_palek(id)
{
        if (player_class[id] == Paladin && is_user_alive(id))
        { 
                c_ulecz[id] = true;
                item_ulecz(id)
        }
        return PLUGIN_HANDLED
}
public player_Think(id){
        if(!is_user_alive(id) || !niewidzialnosc_kucanie[id]){
                return HAM_IGNORED;
        }
        new button = get_user_button(id);
        new oldbutton = get_user_oldbutton(id);
        if(button&IN_DUCK && !(oldbutton&IN_DUCK)){
                        set_user_rendering(id,kRenderFxNone,255,255,255,kRenderTransAlpha,50)
        }
        else if(!(button&IN_DUCK) && oldbutton&IN_DUCK){
                        set_user_rendering(id,kRenderFxNone,255,255,255,kRenderTransAlpha,255)
        }
        return HAM_HANDLED;
}
public lustrzanypocisk(this, idinflictor, idattacker, Float:damage, damagebits)
{
        if(damagebits&(1<<1) && lustrzany_pocisk[this] > 0)
        {
                SetHamParamEntity(1, idattacker);
                SetHamParamEntity(2,this );
                SetHamParamEntity(3,this );
                lustrzany_pocisk[this]--;
                return HAM_HANDLED;
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
                if (player_class[id] != Kernel) continue;
                
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
ColorChat(id, GREEN, "�������: ^x04%i ^x01- � ��� ���� ^x03(%d/%d)^x01 �����", player_lvl[id], player_xp[id], LevelXP[player_lvl[id]])
ColorChat(id, GREEN, "�� ���������� ������ ^x04%d^x01 �����", LevelXP[player_lvl[id]]-player_xp[id])
}
public radar_scan() {
        for(new id=1; id<=MAX; id++) {
                if(!is_user_alive(id) || !player_b_radar[id]) continue;

                for(new i=1; i<=MAX; i++) {
                        if(!is_user_alive(i) || id == i || get_user_team(id) == get_user_team(i)) continue;

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
public niesmiertelnoscon(id) {
        if(used_item[id]) {
                hudmsg(id, 2.0, "���������� ����� ������������ ���� ��� �� �����!");
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

public niesmiertelnoscoff(id) {
        id-=TASK_GOD;

        if(is_user_connected(id)) {
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
		hudmsg(id,2.0,"����� ����� ������������ 1 ��� �� �����!")
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
			
			if (is_user_alive(pid)){
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

public off_zamroz(pid){
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
                client_print(id, print_console, "������ %s ����� item %d",szName, iItem); 
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
		hudmsg(id,2.0,"����� ����� ������������ 1 ��� �� �����!")
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
		hudmsg(id,2.0,"����� ����� ������������ 1 ��� �� �����!")
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
		hudmsg(id,2.0,"����� ����� ������������ 1 ��� �� �����!")
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
		hudmsg(id,2.0,"����� ����� ������������ 1 ��� �� �����!")
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
				client_cmd(pid, "pluginflash")
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
	new mana1=menu_create("������� ����","mana1a");
	
	menu_additem(mana1,"\y������");//item=0
	menu_additem(mana1,"\y��������");//item=1
	menu_additem(mana1,"\y������");//item=2
	
	menu_display(id, mana1,0);
	return PLUGIN_HANDLED;
}
public mana1a(id, menu, item){
	switch(item){
		case 0:
		{
			mana2(id)
		}
		case 1:
		{
			mana3(id)
		}
		case 2:
		{
			mana4(id)
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
public mana2(id){
	new mana2=menu_create("������� ������","mana2a");
	
	menu_additem(mana2,"\y M4A1 + ������� \d[10 ����]")
	menu_additem(mana2,"\y AK47 + ������� \d[7 ����]")
	menu_additem(mana2,"\y AWP + ������� \d[10 ����]")
	menu_additem(mana2,"\y Famas + ������� \d[5 ����]")
	menu_additem(mana2,"\y Galil + ������� \d[5 ����]")
	menu_additem(mana2,"\y M249 + ������� \d[13 ����]")
	menu_additem(mana2,"\y Mp5 + ������� \d[4 ����]")
	menu_additem(mana2,"\y Scout + ������� \d[6 ����]")
	menu_additem(mana2,"\y M3 Pompa + ������� \d[7 ����]")
	menu_additem(mana2,"\y XM1014 Pompa + ������� \d[7 ����]")
	menu_additem(mana2,"\y P90 + ������� \d[4 ����]")
	menu_additem(mana2,"\y Deagle + ������� \d[2 ����]")
	menu_additem(mana2,"\y Aug + ������� \d[8 ����]")
	menu_additem(mana2,"\y SG552 + ������� \d[8 ����]")
	menu_additem(mana2,"\y Nightvision \d[5 ����]")
	menu_setprop(mana2,MPROP_EXIT,MEXIT_ALL)
	menu_setprop(mana2,MPROP_EXITNAME,"�����")
	menu_setprop(mana2,MPROP_NEXTNAME,"�����")
	menu_setprop(mana2,MPROP_BACKNAME,"�����")
	
	menu_display(id, mana2,0);
	return PLUGIN_HANDLED;
}
public mana2a(id, menu, item){
	switch(item){
		case 0:
		{
			new koszt = 10;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_ak47")
			cs_set_user_bpammo(id, CSW_AK47, 90)
			}
		}
		case 2:{
			new koszt = 10;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_awp")
			cs_set_user_bpammo(id, CSW_AWP, 30)
			}
		}
		case 3:{
			new koszt = 5;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_famas")
			cs_set_user_bpammo(id, CSW_FAMAS, 90)
			}
		}
		case 4:{
			new koszt = 5;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_gali")
			cs_set_user_bpammo(id, CSW_GALI, 90)
			}
		}
		case 5:{
			new koszt = 13;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_m249")
			cs_set_user_bpammo(id, CSW_M249, 200)
			}
		}
		case 6:{
			new koszt = 4;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_mp5navy")
			cs_set_user_bpammo(id, CSW_MP5NAVY, 120)
			}
		}
		case 7:{
			new koszt = 6;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_scout")
			cs_set_user_bpammo(id, CSW_SCOUT, 90)
			}
		}
		case 8:{
			new koszt = 7;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_m3")
			cs_set_user_bpammo(id, CSW_M3, 32)
			}
		}
		case 9:{
			new koszt = 7;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_xm1014")
			cs_set_user_bpammo(id, CSW_XM1014, 32)
			}
		}
		case 10:{
			new koszt = 4;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_p90")
			cs_set_user_bpammo(id, CSW_P90, 100)
			}
		}
		case 11:{
			new koszt = 2;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_deagle")
			cs_set_user_bpammo(id, CSW_DEAGLE, 35)
			}
		}
		case 12:{
			new koszt = 8;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_aug")
			cs_set_user_bpammo(id, CSW_AUG, 90)
			}
		}
		case 13:{
			new koszt = 8;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			fm_give_item(id,"weapon_sg552")
			cs_set_user_bpammo(id, CSW_SG550, 90)
			}
		}
		case 14:{
			new koszt = 5;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
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
public mana3(id){
	new mana3=menu_create("������� Item","mana3a");
	
	menu_additem(mana3,"\y Vampyric Scepter \d[10 ����]")
	menu_additem(mana3,"\y Small bronze bag \d[40 ����]")
	menu_additem(mana3,"\y Medium silver bag \d[50 ����]")
	menu_additem(mana3,"\y Large gold bag \d[60 ����]")
	menu_additem(mana3,"\y Small angel wings \d[100 ����]")
	menu_additem(mana3,"\y Arch angel wings \d[130 ����]")
	menu_additem(mana3,"\y Firerope \d[40 ����]")
	menu_additem(mana3,"\y Fire Amulet \d[60 ����]")
	menu_additem(mana3,"\y Stalkers ring \d[140 ����]")
	menu_additem(mana3,"\y Gold statue \d[25 ����]")
	menu_additem(mana3,"\y Daylight Diamond \d[40 ����]")
	menu_additem(mana3,"\y Blood Diamond \d[60 ����]")
	menu_additem(mana3,"\y Wheel of Fortune \d[30 ����]")
	menu_additem(mana3,"\y Sword of the sun \d[40 ����]")
	menu_additem(mana3,"\y Fireshield \d[85 ����]")
	menu_additem(mana3,"\y Stealth Shoes \d[10 ����]")
	menu_additem(mana3,"\y Meekstone \d[70 ����]")
	menu_additem(mana3,"\y Godly Armor \d[50 ����]")
	menu_additem(mana3,"\y Knife Ruby \d[25 ����]")
	menu_additem(mana3,"\y Sword \d[45 ����]")
	menu_additem(mana3,"\y Scout Extender \d[70 ����]")
	menu_additem(mana3,"\y Scout Amplifier \d[100 ����]")
	menu_additem(mana3,"\y Iron Spikes \d[50 ����]")
	menu_additem(mana3,"\y Paladin ring \d[60 ����]")
	menu_additem(mana3,"\y Monk ring \d[80 ����]")
	menu_additem(mana3,"\y Flashbang necklace \d[30 ����]")
	menu_additem(mana3,"\y Khalim Eye \d[100 ����]")
	menu_additem(mana3,"\y Hydra Blade \d[80 ����]")
	menu_additem(mana3,"\y Exp Ring \d[70 ����]")
	menu_additem(mana3,"\y Aegis \d[90 ����]")
	menu_additem(mana3,"\y Heavenly Stone \d[70 ����]")
	menu_additem(mana3,"\y Festering Essence of Destruction \d[140 ����]")
	menu_additem(mana3,"\y Centurion \d[170 many]","32")
	menu_additem(mana3,"\y Dr House \d[100 many]","33")
	menu_additem(mana3,"\y Own Invisible \d[300 ����]")
	menu_additem(mana3,"\y Mega Invisible \d[300 ����]")
	menu_additem(mana3,"\y Bul'Kathos Shoes \d[30 ����]")
	menu_additem(mana3,"\y Karik's Ring \d[220 ����]")
	menu_additem(mana3,"\y Purse Thief \d[150 ����]")
	menu_additem(mana3,"\y Revival Ring \d[80 ����]")
	menu_additem(mana3,"\y Demon Assassin \d[170 many]","41")
	menu_additem(mana3,"\y Mystiqe \d[100 many]","42")
	menu_additem(mana3,"\y Apocalypse Anihilation \d[240 many]","43")
	menu_additem(mana3,"\y M4A1 Special \d[150 ����]")
	menu_additem(mana3,"\y Ak47 Special \d[150 ����]")
	menu_additem(mana3,"\y AWP Special \d[130 ����]")
	menu_additem(mana3,"\y Deagle Special \d[140 ����]")
	menu_additem(mana3,"\y M3 Special \d[145 ����]")
	menu_additem(mana3,"\y Full Special \d[210 ����]")
	menu_additem(mana3,"\y Hellspawn \d[50 ����]")
	menu_additem(mana3,"\y Gheed's Fortune \d[148 ����]")
	menu_additem(mana3,"\y Winter Totem \d[30 ����]")
	menu_additem(mana3,"\y Cash Totem \d[40 ����]")
	menu_additem(mana3,"\y Thief Totem \d[50 ����]")
	menu_additem(mana3,"\y Weapon Totem \d[80 ����]")
	menu_additem(mana3,"\y Flash Totem \d[80 ����]")
	menu_setprop(mana3,MPROP_EXIT,MEXIT_ALL)
	menu_setprop(mana3,MPROP_EXITNAME,"�����")
	menu_setprop(mana3,MPROP_NEXTNAME,"�����")
	menu_setprop(mana3,MPROP_BACKNAME,"�����")
	
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
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
public mana4(id){
	new mana4=menu_create("������","mana4a");
	
	menu_additem(mana4,"\y ��������� item \d[10 ����]")
	menu_additem(mana4,"\y �������� item \d[20 ����]")
	menu_setprop(mana4,MPROP_EXIT,MEXIT_ALL)
	menu_setprop(mana4,MPROP_EXITNAME,"�����")
	menu_setprop(mana4,MPROP_NEXTNAME,"�����")
	menu_setprop(mana4,MPROP_BACKNAME,"�����")
	
	menu_display(id, mana4,0);
	return PLUGIN_HANDLED;
}
public mana4a(id, menu, item){
	switch(item){
		case 0:
		{
			new koszt = 10;
			if (mana_gracza[id]<koszt && player_item_id[id]>0)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ���� ��� � ��� ��� ���� item");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			award_item(id,0)
			}
		}
		case 1:{
			new koszt = 20;
			if (mana_gracza[id]<koszt)
			{
				ColorChat(id,GREEN,"[�������]^x01 �� ������� ����.");
				return PLUGIN_CONTINUE;
			}
			if (mana_gracza[id]>=koszt)
			{
			mana_gracza[id] -= koszt;
			upgrade_item(id)
			}
		}
	}
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}
public hook_team_select(id,key){
	if((key==0)&&(player!=0)){
		engclient_cmd(id,"chooseteam")
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
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
	bossPower=max(3000,min(9000,str_to_num(arg)))
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
	show_hudmessage(0,"The enemy is strong!")
}
public cmdBlyskawica(id){
    if(!is_user_alive(id)) return PLUGIN_HANDLED;
    if(!ilosc_blyskawic[id]) {
          client_print(id,print_chat,"� ��� ��� ������");
          return PLUGIN_HANDLED;
    }
    if(poprzednia_blyskawica[id]+2.0>get_gametime()) {
          client_print(id,print_chat,"�� ������ ������������ ������ ������ 5 ������.");
          return PLUGIN_HANDLED;
    }
    poprzednia_blyskawica[id]=floatround(get_gametime());
    ilosc_blyskawic[id]--;
    new ofiara, body;
    get_user_aiming(id, ofiara, body);
    
    if(is_user_alive(ofiara)){
        puscBlyskawice(id, ofiara, 50.0, 0.5);
    }
    return PLUGIN_HANDLED;
}
stock Create_TE_BEAMENTS(startEntity, endEntity, iSprite, startFrame, frameRate, life, width, noise, red, green, blue, alpha, speed){

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

puscBlyskawice(id, ofiara, Float:fObrazenia = 50.0, Float:fCzas = 1.0){
    //Obrazenia
    new ent = create_entity("info_target");
    entity_set_string(ent, EV_SZ_classname, "blyskawica");
    ExecuteHamB(Ham_TakeDamage, ofiara, ent, id, fObrazenia, DMG_SHOCK);
    remove_entity(ent);
    
    //Piorun
    Create_TE_BEAMENTS(id, ofiara, sprite, 0, 10, floatround(fCzas*10), 150, 5, 200, 200, 200, 200, 10);
    
    //Dzwiek
    emit_sound(id, CHAN_WEAPON, gszSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}