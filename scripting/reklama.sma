/*
	Plugin: 'Reklama'

	Plugin author: http://t.me/blacksignature / https://dev-cs.ru/members/1111/

	Plugin thread: https://dev-cs.ru/resources/435/

	Description:
		This plugin allows you to:
			* Advertise - display predefined chat messages to all with a specified frequency.
			* Autorespond - reply to certain player chat messages with predefined chat messages.

		Supported features:
			* ML keys and wildcard patterns (see 'Setup' section in plugin thread)
			* Colored messages
			* Mode-based (by cvar value) message output
			* Random start position
			* Random delay between message output
			* Multiple messages at once (multi-output)
			* Sounds
			* 'On-the-fly' Config reloading
			* Players can disable messages for themselves

	Credits:
		* wopox1337 -> https://dev-cs.ru/members/4/
		* fantom -> https://dev-cs.ru/members/16/
		* Thx to all who helps me with ideas and bugreports

	Requirements:
		* Amx Mod X 1.9 - build 5241, or higher

	How to use:
		1) Install this plugin
		2) Tweak 'reklama.ini' config
		3) Run plugin
		4) Visit 'configs/plugins' to tweak config
		5) Change map to reload config
		6) Enjoy!

		NOTE: It's recomended to place this plugin in 'plugins.ini' above your chat manager

	Change history:
		29.03.2018:
			* Initial public release
		06.04.2018:
			Added:
				* Cvar 'reklama_freq'
			Removed:
				* Command 'reklama_mode'
				* Initialization delay
			Fixed:
				* Minor bugfixes
		29.11.2018:
			Added:
				* Cvar 'reklama_for_all'
				* Cvar 'reklama_mode'
				* Ability to disable messages ('say /reklama')
				* Option 'CHAT_PREFIX'
			Changed:
				* Config structure -> added argument 'mode'
		29.11.2018 v2:
			Added:
				* Autoresponder
		30.11.2018:
			Added:
				* Option 'CMD_BLOCK_AUTORESPOND'
				* Option 'RANDOM_FREQ'
				* Option 'USE_SOUND'
			Changed:
				* client_cmd() -> SendAudio()
				* Sound 'ambience/warn1' replaced with 'buttons/button2'
			Removed;
				* Option 'USE_PRECACHE'
		30.11.2018 v2:
			Fixed:
				* Critical bugfix. Thx zhorzh78 [ https://dev-cs.ru/members/326/ ]
		09.07.2019:
			Added:
				* Wildcard patterns support
				* ML-keys support for config messages
			Changed:
				* Divider '|' for autoresponder pattern, with you can set multiple patterns for one message
				* Config format -> added argument 'compare'
				* Changed config description
				* Config description moved to separate file
				* Dictionary was updated (only key 'REKLAMA_KEY_1')
			Removed:
				* Old AMXX versions support. From now plugin requires AMXX 190+
		16.03.2020:
			Fixed:
				* Autoresponder compatibility with various chat managers based on 'say' hooking
		20.05.2020:
			Fixed:
				* Error prevention, if last row refers to next non-existent row (multi-row messages)
				* Handling situation, when all rows are 'autorespond only'
		30.05.2025:
			* Added:
				* Ability to set autoconfig filename (value for AUTO_CFG)
				* Ability to define hud messages (type 4 and 5; read reklama_syntax_EN.txt)
					* Added cvar reklama_hud_settings
			* Changed:
				* client_authorized() -> client_putinserver()
				* Remove unnesesary stocks and publics
				* Minor logic improvements
			* Fixed:
				* Wrong applied cvar values from autocfg due to setting task in plugin_cfg()
		31.05.2025:
			* Added:
				* Separate cvar reklama_for_all_hud for hud messages
			* Changed:
				* Cvar reklama_for_all renamed to reklama_for_all_chat so now we got two separate cvars for two types of messages
		01.06.2025:
			* Fix reklama_hud_settings cvar description
*/

new const PLUGIN_DATE[] = "01.06.2025"

/* ---------------------- SETTINGS START ---------------------- */

// Create cvar config in 'amxmodx/configs/plugins', and execute it?
// Value is the name of the config without .cfg extention.
// Leave it as "" to use default naming (will be "plugin-%plugin_name%.cfg")
#define AUTO_CFG ""

// Hide messages that triggers autoresponder?
// NOTE: It's recomended to place plugin in 'plugins.ini' above your chat manager
#define BLOCK_TRIGGER_MSG

// Allow players to disable messages?
#define CMD_NAME "say /reklama"

// Whether to disable the autoresponder when player personally disable messages
#define CMD_BLOCK_AUTORESPOND

// Prune vault records oldier than this value (in days)
#define OBSOLETE_DAYS 30

// Initialization delay
#define INIT_DELAY 3.5

// Chat prefix
new const CHAT_PREFIX[] = "" // without prefix
//new const CHAT_PREFIX[] = "^4* "
//new const CHAT_PREFIX[] = "^1[^3Инфо^1] "
//new const CHAT_PREFIX[] = "^1[^4Reklama^1] "

// Use prefix for adverts?
//#define SHOW_PREFIX_WITH_ADS

// Random start position. Useful when you have large config.
// NOTE: Don't forget to set type '2' or '3' for those messages, with you do not want to start
//#define RANDOM_START

// Config file name (in 'amxmodx/configs')
new const ADS_FILE_NAME[] = "reklama.ini"

// Lang file name (in 'amxmodx/data/lang')
new const LANG_NAME[] = "reklama.txt"

// Vault name (in 'amxmodx/data/vault')
stock const VAULT_NAME[] = "reklama"

/* --- SOUND SETTINGS --- */

// Sound support ability
#define USE_SOUND

// Sounds
stock const g_szSounds[][] = {
/* 0 */ "buttons/blip1.wav",
/* 1 */ "buttons/blip2.wav",
/* 2 */ "events/tutor_msg.wav",
/* 3 */ "buttons/button2.wav",
/* 4 */ "buttons/bell1.wav",
/* 5 */ "buttons/button3.wav",
/* 6 */ "buttons/button7.wav",
/* 7 */ "buttons/button9.wav",
/* 8 */ "plats/elevbell1.wav",
/* 9 */ "plats/train_use1.wav",
/* 10 */ "x/x_shoot1.wav"
}

/* ---------------------- SETTINGS END ---------------------- */

#include <amxmodx>
#include <amxmisc>
#include <time>

#if defined CMD_NAME
	#include <nvault>
#endif

#define chx charsmax
#define chx_len(%0) charsmax(%0) - iLen

#define CheckPatternBit(%0) (g_eMsgData[MSG_PATTERN_BITSUM] & (1<<%0))
#define SetPatternBit(%0) (g_eMsgData[MSG_PATTERN_BITSUM] |= (1<<%0))

#define MODE_AUTO false
#define MODE_MANUAL true

#define MSG_LEN 191
#define TEMPLATE_LEN 191

new const PLUGIN_PREFIX[] = "[Reklama]"

new const SOUND__BLIP1[] = "sound/buttons/blip1.wav"

const TASKID_TIMER = 1337

enum _:CVAR_ENUM {
	Float:CVAR__FREQ_MIN,
	Float:CVAR__FREQ_MAX,
	CVAR__FOR_ALL_CHAT,
	CVAR__FOR_ALL_HUD,
	CVAR__MODE,
	CVAR__SOUND_FOR_ALL,
	CVAR__HUD_SETTINGS[32]
}

enum _:MSG_STRUCT {
	MSG_BODY[MSG_LEN],
	MSG_COLOR_ID,
	bool:IS_MULTI_MSG,
	MSG_SOUND_ID,
	bool:NOT_FOR_START,
	MSG_TYPE,
	MSG_MODE,
	bool:AUTORESPOND_ONLY,
	bool:MSG_IS_LANG_KEY,
	MSG_PATTERN_BITSUM
}

enum _:AR_STRUCT {
	AR_MODE,
	POINTER,
	TEMPLATE[TEMPLATE_LEN]
}

enum {
	AR_MODE__EX_INSENS,
	AR_MODE__EX_SENS,
	AR_MODE__MATCH_INSENS,
	AR_MODE__MATCH_SENS
}

enum _:PATTERNS_ENUM {
	PATTERN__HOSTNAME,
	PATTERN__MAXPLAYERS,
	PATTERN__NUMPLAYERS,
	PATTERN__SERVER_IP,
	PATTERN__MAPNAME,
	PATTERN__SV_CONTACT,
	PATTERN__TIMELEFT,
	PATTERN__PLAYER_NAME,
	PATTERN__PLAYER_STEAMID,
	PATTERN__PLAYER_IP
}

enum {
	TYPE__CHAT_DEFAULT,
	TYPE__CHAT_WITH_NEXT,
	TYPE__CHAT_WITH_NEXT_NOT_FOR_START,
	TYPE__CHAT_NOT_FOR_START,
	TYPE__HUD,
	TYPE__HUD_NOT_FOR_START
}

enum { // values for channel arg, from cvar 'reklama_hud_settings'
	CHANNEL__DHUD = -1,
	CHANNEL__AUTOSELECT = 0
}

new const PATTERNS[PATTERNS_ENUM][] = {
	"#hostname#",
	"#maxplayers#",
	"#numplayers#",
	"#server_ip#",
	"#mapname#",
	"#contact#",
	"#timeleft#",
	"#name#",
	"#steamid#",
	"#ip#"
}

new g_eCvar[CVAR_ENUM]
new Array:g_aMsgArray
new Array:g_aAuReArray
new g_eMsgData[MSG_STRUCT]
new g_AuReData[AR_STRUCT]
new g_iTotalMsgCount
new g_iAuReCount
new	g_iCurPos
new g_iFirstSkipPos
new g_szFilePath[PLATFORM_MAX_PATH]
new g_szBuffer[MAX_AUTHID_LENGTH] // don't decrease it's size!
new g_szMsg[MSG_LEN]
new g_iAutoMsgCount

stock g_bDisabled[MAX_PLAYERS + 1]
stock g_hVault = INVALID_HANDLE
stock g_iMsgIdSendAudio

public plugin_precache() {
	register_plugin("Reklama", PLUGIN_DATE, "mx?!")

	register_clcmd("say", "hook_Say")
	register_clcmd("say_team", "hook_Say")

#if defined CMD_NAME
	register_clcmd(CMD_NAME, "clcmd_ToggleState")
#endif

#if defined USE_SOUND
	for(new i; i < sizeof(g_szSounds); i++) {
		precache_sound(g_szSounds[i])
	}
#endif
}

public plugin_init() {
	register_dictionary(LANG_NAME)

	/* --- */

	func_RegCvars()

	/* --- */

#if defined USE_SOUND
	g_iMsgIdSendAudio = get_user_msgid("SendAudio")
#endif
}

public plugin_cfg() {
	g_aAuReArray = ArrayCreate(AR_STRUCT, 1)
	g_aMsgArray = ArrayCreate(MSG_STRUCT)

	/* --- */

	set_task(INIT_DELAY, "task_Init")

	/* --- */

#if defined CMD_NAME
	g_hVault = nvault_open(VAULT_NAME)

	#if defined OBSOLETE_DAYS
	if(g_hVault != INVALID_HANDLE) {
		nvault_prune(g_hVault, 0, get_systime() - (OBSOLETE_DAYS * SECONDS_IN_DAY))
	}
	#endif
#endif
}

public task_Init() {
	func_LoadMessages(MODE_AUTO)
	
	/* --- */

	// Status: Total message count, current position
	register_srvcmd("reklama_status", "srvcmd_CmdShowStatus")
	// Print specified message (example: reklama_show 5)
	register_srvcmd("reklama_show", "srvcmd_CmdShowCustomMessage")
	// Reload messages config
	register_srvcmd("reklama_reload", "srvcmd_CmdReloadFile")
}

public hook_Say(pPlayer) {
#if defined CMD_BLOCK_AUTORESPOND
	if(!g_iAuReCount || g_bDisabled[pPlayer]) {
#else
	if(!g_iAuReCount) {
#endif
		return PLUGIN_CONTINUE
	}

	new szMessage[MSG_LEN]

	read_args(szMessage, chx(szMessage))
	remove_quotes(szMessage)
	trim(szMessage)

	for(new i; i < g_iAuReCount; i++) {
		ArrayGetArray(g_aAuReArray, i, g_AuReData)

		switch(g_AuReData[AR_MODE]) {
			case AR_MODE__EX_INSENS: {
				if(containi(szMessage, g_AuReData[TEMPLATE]) == -1) {
					continue
				}
			}
			case AR_MODE__EX_SENS: {
				if(contain(szMessage, g_AuReData[TEMPLATE]) == -1) {
					continue
				}
			}
			case AR_MODE__MATCH_INSENS: {
				new iPos = containi(szMessage, g_AuReData[TEMPLATE])

				if(iPos == -1) {
					continue
				}

				if(iPos && szMessage[iPos - 1] != ' ') {
					continue
				}

				iPos = strlen(g_AuReData[TEMPLATE]) + iPos // calculate end pos of pattern

				if(szMessage[iPos] && szMessage[iPos] != ' ') {
					continue
				}
			}
			case AR_MODE__MATCH_SENS: {
				new iPos = contain(szMessage, g_AuReData[TEMPLATE])

				if(iPos == -1) {
					continue
				}

				if(iPos && szMessage[iPos - 1] != ' ') {
					continue
				}

				iPos = strlen(g_AuReData[TEMPLATE]) + iPos // calculate end pos of pattern

				if(szMessage[iPos] && szMessage[iPos] != ' ') {
					continue
				}
			}
		}

		ArrayGetArray(g_aMsgArray, g_AuReData[POINTER], g_eMsgData)

		if(g_eMsgData[MSG_MODE] && g_eCvar[CVAR__MODE] != g_eMsgData[MSG_MODE]) {
			return PLUGIN_CONTINUE
		}

		func_ShowToSingle(pPlayer)

		while(g_eMsgData[IS_MULTI_MSG] && ++g_AuReData[POINTER] < g_iTotalMsgCount) {
			ArrayGetArray(g_aMsgArray, g_AuReData[POINTER], g_eMsgData)
			func_ShowToSingle(pPlayer)
		}

	#if defined BLOCK_TRIGGER_MSG
		return PLUGIN_HANDLED
	#else
		return PLUGIN_CONTINUE
	#endif
	}

	return PLUGIN_CONTINUE
}

func_ShowToSingle(pPlayer) {
	if(g_eMsgData[MSG_IS_LANG_KEY]) {
		func_ReplaceML(pPlayer)
		func_ReplacePatterns(pPlayer)
	}
	else {
		copy(g_szMsg, chx(g_szMsg), g_eMsgData[MSG_BODY])

		if(g_eMsgData[MSG_PATTERN_BITSUM]) {
			func_ReplacePatterns(pPlayer)
		}
	}
	
	switch(g_eMsgData[MSG_TYPE]) {
		case TYPE__HUD, TYPE__HUD_NOT_FOR_START: {
			new iColor[3], Float:fPos[2], Float:fDuration, iChannel
			GetHudSettings(iColor, fPos, fDuration, iChannel)
			
			if(iChannel) {
				set_hudmessage(iColor[0], iColor[1], iColor[2], fPos[0], fPos[1], 0, 0.0, fDuration, 0.1, 0.1, iChannel)
				show_hudmessage(pPlayer, g_szMsg)
			}
			else {
				set_dhudmessage(iColor[0], iColor[1], iColor[2], fPos[0], fPos[1], 0, 0.0, fDuration, 0.1, 0.1)
				show_dhudmessage(pPlayer, g_szMsg)
			}
		}
		default: {
		#if defined SHOW_PREFIX_WITH_ADS
			client_print_color(pPlayer, g_eMsgData[MSG_COLOR_ID], "%s^1%s", CHAT_PREFIX, g_szMsg)
		#else
			client_print_color(pPlayer, g_eMsgData[MSG_COLOR_ID], "^1%s", g_szMsg)
		#endif
		}
	}

#if defined USE_SOUND
	if(g_eMsgData[MSG_SOUND_ID] != -1) {
		SendAudio(pPlayer, g_szSounds[ g_eMsgData[MSG_SOUND_ID] ])
	}
#endif
}

GetHudSettings(iColor[3], Float:fPos[2], &Float:fDuration, &iChannel) {
	new szColor[3][6], szPos[2][6], szDuration[6], szChannel[6]

	parse( g_eCvar[CVAR__HUD_SETTINGS],
		szColor[0], chx(szColor[]),
		szColor[1], chx(szColor[]),
		szColor[2], chx(szColor[]),
		szPos[0], chx(szPos[]),
		szPos[1], chx(szPos[]),
		szDuration, chx(szDuration),
		szChannel, chx(szChannel)
	);

	for(new i; i < 3; i++) {
		iColor[i] = str_to_num(szColor[i])
	}

	fPos[0] = str_to_float(szPos[0])
	fPos[1] = str_to_float(szPos[1])

	fDuration = str_to_float(szDuration)
	iChannel = str_to_num(szChannel)

	switch(iChannel) {
		case CHANNEL__DHUD: {
			iChannel = 0
		}
		case CHANNEL__AUTOSELECT: {
			iChannel = -1
		}
	}
}

#if defined CMD_NAME
	public clcmd_ToggleState(pPlayer) {
		g_bDisabled[pPlayer] = !g_bDisabled[pPlayer]
	#if defined USE_SOUND
		SendAudio(pPlayer, SOUND__BLIP1)
	#endif

		client_print_color( pPlayer, print_team_red, "%s^1%L %s%L", CHAT_PREFIX, pPlayer, "REKLAMA_STATE",
			g_bDisabled[pPlayer] ? "^3" : "^4", pPlayer, g_bDisabled[pPlayer] ? "REKLAMA_OFF" : "REKLAMA_ON" );

		if(g_hVault == INVALID_HANDLE) {
			return PLUGIN_HANDLED
		}

		get_user_authid(pPlayer, g_szBuffer, chx(g_szBuffer))

		if(g_bDisabled[pPlayer]) {
			nvault_set(g_hVault, g_szBuffer, "1")
		}
		else {
			nvault_remove(g_hVault, g_szBuffer)
		}

		return PLUGIN_HANDLED
	}
#endif

func_LoadMessages(bool:bMode) {
	if(bMode == MODE_AUTO) {
		new iLen = get_localinfo("amxx_configsdir", g_szFilePath, chx(g_szFilePath))
		formatex(g_szFilePath[iLen], chx_len(g_szFilePath), "/%s", ADS_FILE_NAME)
	}

	new hFile = fopen(g_szFilePath, "r")

	if(!hFile) {
		set_fail_state("Can't %s '%s' !", file_exists(g_szFilePath) ? "read" : "find", ADS_FILE_NAME)
		return
	}

	new szString[MSG_LEN * 2], szMode[3], szType[3], szSound[3],
		szColor[2], szAuRe[2], szAuReMode[2], szTemplate[TEMPLATE_LEN];

	while(!feof(hFile))	{
		fgets(hFile, szString, chx(szString))

		if(!isdigit(szString[0])) {
			continue
		}

		g_AuReData[TEMPLATE][0] = EOS

		parse( szString, szMode, chx(szMode), szType, chx(szType), szSound, chx(szSound), szColor, chx(szColor),
			szAuRe, chx(szAuRe), szAuReMode, chx(szAuReMode), g_AuReData[TEMPLATE], TEMPLATE_LEN - 1, g_eMsgData[MSG_BODY], MSG_LEN - 1 );

		if(g_AuReData[TEMPLATE][0]) {
			g_AuReData[AR_MODE] = str_to_num(szAuReMode)
			g_AuReData[POINTER] = g_iTotalMsgCount

			if(contain(g_AuReData[TEMPLATE], "|") != -1) {
				copy(szTemplate, chx(szTemplate), g_AuReData[TEMPLATE])

				while(strtok2(szTemplate, g_AuReData[TEMPLATE], TEMPLATE_LEN - 1, szTemplate, chx(szTemplate), .token = '|', .trim = 0) != -1) {
					ArrayPushArray(g_aAuReArray, g_AuReData)
					g_iAuReCount++
				}

				// Push remaining part (after last iteration) too
				ArrayPushArray(g_aAuReArray, g_AuReData)
				g_iAuReCount++
			}
			else {
				ArrayPushArray(g_aAuReArray, g_AuReData)
				g_iAuReCount++
			}
		}

		if(equal(g_eMsgData[MSG_BODY], "REKLAMA_KEY", 11)) {
			g_eMsgData[MSG_IS_LANG_KEY] = true
			g_eMsgData[MSG_PATTERN_BITSUM] = -1 // (1<<0) .. (1<<31)
		}
		else {
			g_eMsgData[MSG_IS_LANG_KEY] = false

			replace_string(g_eMsgData[MSG_BODY], MSG_LEN - 1, "!n", "^1")
			replace_string(g_eMsgData[MSG_BODY], MSG_LEN - 1, "!t", "^3")
			replace_string(g_eMsgData[MSG_BODY], MSG_LEN - 1, "!g", "^4")

			g_eMsgData[MSG_PATTERN_BITSUM] = 0
			func_FindPatterns()
		}

		g_eMsgData[MSG_MODE] = str_to_num(szMode)
		g_eMsgData[MSG_TYPE] = str_to_num(szType)

	#if defined RANDOM_START
		switch(g_eMsgData[MSG_TYPE]) {
			case 0: {
				g_eMsgData[IS_MULTI_MSG] = false
				g_eMsgData[NOT_FOR_START] = false
			}
			case 1: {
				g_eMsgData[IS_MULTI_MSG] = true
				g_eMsgData[NOT_FOR_START] = false
			}
			case 2: {
				g_eMsgData[IS_MULTI_MSG] = true
				g_eMsgData[NOT_FOR_START] = true
			}
			case 3: {
				g_eMsgData[IS_MULTI_MSG] = false
				g_eMsgData[NOT_FOR_START] = true
			}
			case 4: {
				g_eMsgData[IS_MULTI_MSG] = false
				g_eMsgData[NOT_FOR_START] = false
			}
			case 5: {
				g_eMsgData[IS_MULTI_MSG] = false
				g_eMsgData[NOT_FOR_START] = true
			}
		}
	#else
		g_eMsgData[IS_MULTI_MSG] = (g_eMsgData[MSG_TYPE] == 1 || g_eMsgData[MSG_TYPE] == 2) ? true : false
	#endif

		g_eMsgData[MSG_SOUND_ID] = str_to_num(szSound) - 1

		switch(szColor[0]) {
			case 'W': g_eMsgData[MSG_COLOR_ID] = print_team_grey
			case 'R': g_eMsgData[MSG_COLOR_ID] = print_team_red
			case 'B': g_eMsgData[MSG_COLOR_ID] = print_team_blue
			default: g_eMsgData[MSG_COLOR_ID] = print_team_default
		}

		g_eMsgData[AUTORESPOND_ONLY] = (szAuRe[0] == '0') ? false : true

		if(!g_eMsgData[AUTORESPOND_ONLY]) {
			g_iAutoMsgCount++
		}

		ArrayPushArray(g_aMsgArray, g_eMsgData)
		g_iTotalMsgCount++
	}

	fclose(hFile)

	if(g_iAutoMsgCount) {
	#if defined RANDOM_START
		new iTryCount

		while(g_iTotalMsgCount) {
			if(++iTryCount == g_iTotalMsgCount) { // wrong cfg, or just bad luck?
				g_iCurPos = 0
				break
			}

			g_iCurPos = random_num(0, g_iTotalMsgCount - 1)
			ArrayGetArray(g_aMsgArray, g_iCurPos, g_eMsgData)

			if(g_eMsgData[NOT_FOR_START]) {
				continue
			}

			break
		}
	#endif
		SetTask()
	}

	if(bMode == MODE_AUTO) {
		server_print("%s %i messages to show", PLUGIN_PREFIX, g_iTotalMsgCount)
	}
}

public func_PrintMessage(iTaskID) {
	if(g_iCurPos == g_iTotalMsgCount) {
		g_iCurPos = 0
	}

	ArrayGetArray(g_aMsgArray, g_iCurPos++, g_eMsgData)

	if(g_eMsgData[AUTORESPOND_ONLY] && iTaskID) {
		func_PrintMessage(iTaskID)
		return
	}

	// Protection against infinite recursion
	if(g_eCvar[CVAR__MODE] && g_eMsgData[MSG_MODE] && g_eMsgData[MSG_MODE] != g_eCvar[CVAR__MODE] && iTaskID) {
		if(!g_iFirstSkipPos) {
			g_iFirstSkipPos = g_iCurPos
		}
		else if(g_iFirstSkipPos == g_iCurPos) {
			g_iFirstSkipPos = 0
			SetTask()
			return
		}

		func_PrintMessage(iTaskID)
		return
	}

	g_iFirstSkipPos = 0

	new pPlayers[MAX_PLAYERS], iPlCount, pPlayer

	get_players_ex(pPlayers, iPlCount, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV)

	if(!g_eMsgData[MSG_IS_LANG_KEY] && !g_eMsgData[MSG_PATTERN_BITSUM]) {
		copy(g_szMsg, chx(g_szMsg), g_eMsgData[MSG_BODY])
	}
	
	new iColor[3], Float:fPos[2], Float:fDuration, iChannel
	
	switch(g_eMsgData[MSG_TYPE]) {
		case TYPE__HUD, TYPE__HUD_NOT_FOR_START: {
			GetHudSettings(iColor, fPos, fDuration, iChannel)
		}
	}

	for(new i; i < iPlCount; i++) {
		pPlayer = pPlayers[i]

	#if defined CMD_NAME
		if(g_bDisabled[pPlayer]) {
			continue
		}
	#endif

	if(g_eMsgData[MSG_IS_LANG_KEY]) {
		func_ReplaceML(pPlayer)
		func_ReplacePatterns(pPlayer)
	}
	else if(g_eMsgData[MSG_PATTERN_BITSUM]) {
		copy(g_szMsg, chx(g_szMsg), g_eMsgData[MSG_BODY])
		func_ReplacePatterns(pPlayer)
	}

	switch(g_eMsgData[MSG_TYPE]) {
		case TYPE__HUD, TYPE__HUD_NOT_FOR_START: {
			if(!g_eCvar[CVAR__FOR_ALL_HUD] && is_user_alive(pPlayer)) {
				continue
			}
		
			if(iChannel) {
				set_hudmessage(iColor[0], iColor[1], iColor[2], fPos[0], fPos[1], 0, 0.0, fDuration, 0.1, 0.1, iChannel)
				show_hudmessage(pPlayer, g_szMsg)
			}
			else {
				set_dhudmessage(iColor[0], iColor[1], iColor[2], fPos[0], fPos[1], 0, 0.0, fDuration, 0.1, 0.1)
				show_dhudmessage(pPlayer, g_szMsg)
			}
		}
		default: {
			if(!g_eCvar[CVAR__FOR_ALL_CHAT] && is_user_alive(pPlayer)) {
				continue
			}
		
		#if defined SHOW_PREFIX_WITH_ADS
			client_print_color(pPlayer, g_eMsgData[MSG_COLOR_ID], "%s^1%s", CHAT_PREFIX, g_szMsg)
		#else
			client_print_color(pPlayer, g_eMsgData[MSG_COLOR_ID], "^1%s", g_szMsg)
		#endif
		}
	}

	#if defined USE_SOUND
		if(g_eMsgData[MSG_SOUND_ID] != -1) {
			if(!g_eCvar[CVAR__SOUND_FOR_ALL] && is_user_alive(pPlayer)) {
				continue
			}

			SendAudio(pPlayer, g_szSounds[ g_eMsgData[MSG_SOUND_ID] ])
		}
	#endif
	}

	if(g_eMsgData[IS_MULTI_MSG] && g_iCurPos < g_iTotalMsgCount) {
		func_PrintMessage(iTaskID)
		return
	}

	SetTask()
}

SetTask() {
	if(g_iAutoMsgCount) {
		set_task(random_float(g_eCvar[CVAR__FREQ_MIN], g_eCvar[CVAR__FREQ_MAX]), "func_PrintMessage", TASKID_TIMER)
	}
}

public srvcmd_CmdShowStatus() {
	server_print("%s Total messages: %i | Last printed: #%i", PLUGIN_PREFIX, g_iTotalMsgCount, g_iCurPos)
	return PLUGIN_HANDLED
}

public srvcmd_CmdShowCustomMessage() {
	new iMsgID = read_argv_int(1)

	if(!(g_iTotalMsgCount + 1 > iMsgID > 0)) { /* if(1 > iMsgID || iMsgID > g_iTotalMsgCount) */
		server_print("%s Error! Wrong message ID #%i (Total: %i)", PLUGIN_PREFIX, iMsgID, g_iTotalMsgCount)
	}
	else {
		remove_task(TASKID_TIMER)
		g_iCurPos = iMsgID - 1
		func_PrintMessage(0)
		server_print("%s Message #%i (Total: %i) printed!", PLUGIN_PREFIX, iMsgID, g_iTotalMsgCount)
	}

	return PLUGIN_HANDLED
}

public srvcmd_CmdReloadFile() {
	remove_task(TASKID_TIMER)
	ArrayClear(g_aMsgArray)
	ArrayClear(g_aAuReArray)
	g_iAuReCount = 0
	new iOldTotalMsgCount = g_iTotalMsgCount
	g_iTotalMsgCount = 0
	g_iAutoMsgCount = 0
	g_iCurPos = 0
	g_iFirstSkipPos = 0
	func_LoadMessages(MODE_MANUAL)
	server_print("%s Message count before/after reading: %i/%i", PLUGIN_PREFIX, iOldTotalMsgCount, g_iTotalMsgCount)

	return PLUGIN_HANDLED
}

func_ReplacePatterns(pPlayer) {
	if(CheckPatternBit(PATTERN__HOSTNAME)) {
		get_user_name(0, g_szBuffer, chx(g_szBuffer))
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__HOSTNAME], g_szBuffer)
	}

	if(CheckPatternBit(PATTERN__MAXPLAYERS)) {
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__MAXPLAYERS], fmt("%i", MaxClients))
	}

	if(CheckPatternBit(PATTERN__NUMPLAYERS)) {
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__NUMPLAYERS], fmt("%i", get_playersnum()))
	}

	if(CheckPatternBit(PATTERN__SERVER_IP)) {
		get_user_ip(0, g_szBuffer, chx(g_szBuffer), .without_port = 0)
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__SERVER_IP], g_szBuffer)
	}

	if(CheckPatternBit(PATTERN__MAPNAME)) {
		get_mapname(g_szBuffer, chx(g_szBuffer))
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__MAPNAME], g_szBuffer)
	}

	if(CheckPatternBit(PATTERN__SV_CONTACT)) {
		get_cvar_string("sv_contact", g_szBuffer, chx(g_szBuffer))
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__SV_CONTACT], g_szBuffer)
	}

	if(CheckPatternBit(PATTERN__TIMELEFT)) {
		new iTimeleft = get_timeleft()

		replace_stringex( g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__TIMELEFT],
			fmt("%02d:%02d", iTimeleft / SECONDS_IN_MINUTE, iTimeleft % SECONDS_IN_MINUTE) );
	}

	if(CheckPatternBit(PATTERN__PLAYER_NAME)) {
		get_user_name(pPlayer, g_szBuffer, chx(g_szBuffer))
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__PLAYER_NAME], g_szBuffer)
	}

	if(CheckPatternBit(PATTERN__PLAYER_STEAMID)) {
		get_user_authid(pPlayer, g_szBuffer, chx(g_szBuffer))
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__PLAYER_STEAMID], g_szBuffer)
	}

	if(CheckPatternBit(PATTERN__PLAYER_IP)) {
		get_user_ip(pPlayer, g_szBuffer, chx(g_szBuffer), .without_port = 1)
		replace_stringex(g_szMsg, chx(g_szMsg), PATTERNS[PATTERN__PLAYER_IP], g_szBuffer)
	}
}

func_FindPatterns() {
	for(new i; i < PATTERNS_ENUM; i++) {
		if(contain(g_eMsgData[MSG_BODY], PATTERNS[i]) != -1) {
			SetPatternBit(i)
		}
	}
}

func_ReplaceML(pPlayer) {
	formatex(g_szMsg, chx(g_szMsg), "%L", pPlayer, g_eMsgData[MSG_BODY])
}

public plugin_end() {
	if(g_aMsgArray) {
		ArrayDestroy(g_aMsgArray)
	}

	if(g_aAuReArray) {
		ArrayDestroy(g_aAuReArray)
	}

#if defined CMD_NAME
	if(g_hVault != INVALID_HANDLE) {
		nvault_close(g_hVault)
	}
#endif
}

#if defined CMD_NAME
	public client_putinserver(pPlayer) {
		if(g_hVault == INVALID_HANDLE) {
			g_bDisabled[pPlayer] = false
			return
		}

		get_user_authid(pPlayer, g_szBuffer, chx(g_szBuffer))
		g_bDisabled[pPlayer] = bool:nvault_get(g_hVault, g_szBuffer)

	#if defined OBSOLETE_DAYS
		if(g_bDisabled[pPlayer]) {
			nvault_touch(g_hVault, g_szBuffer)
		}
	#endif
	}
#endif

func_RegCvars() {
	bind_pcvar_float( create_cvar( "reklama_freq_min", "60",
		.description = "Minimal interval between automatic messages" ),
		g_eCvar[CVAR__FREQ_MIN]	);

	bind_pcvar_float( create_cvar( "reklama_freq_max", "60",
		.description = "Maximal interval between automatic messages" ),
		g_eCvar[CVAR__FREQ_MAX] );

	bind_pcvar_num( create_cvar( "reklama_for_all_chat", "1",
		.description = "If 0, alive players will not see the automatic CHAT messages" ),
		g_eCvar[CVAR__FOR_ALL_CHAT] );

	bind_pcvar_num( create_cvar( "reklama_for_all_hud", "1",
		.description = "If 0, alive players will not see the automatic HUD messages" ),
		g_eCvar[CVAR__FOR_ALL_HUD] );

	bind_pcvar_num( create_cvar( "reklama_mode", "0",
		.description = "Display mode:^n\
		0 - Display all messages^n\
		1 - Only those that have 'mode 0' or those that correspond to the current value of this cvar" ),
		g_eCvar[CVAR__MODE] );

	bind_pcvar_num( create_cvar( "reklama_sound_for_all", "1",
		.description = "Sound mode:^n\
		0 - Play only for dead players (autorespond sounds will be played anyway)^n\
		1 - Play sounds for all players" ),
		g_eCvar[CVAR__SOUND_FOR_ALL] );
		
	bind_pcvar_string( create_cvar( "reklama_hud_settings", "0 255 0 -1.0 0.7 3.5 0",
		.description = "HUD settings ( https://dev-cs.ru/hud/index.html ):^n\
		R G B X Y DURATION CHANNEL(1-4, 0 to autoselect, -1 to use DHUD)" ),
		g_eCvar[CVAR__HUD_SETTINGS], chx(g_eCvar[CVAR__HUD_SETTINGS] ) );

#if defined AUTO_CFG
	AutoExecConfig(.name = AUTO_CFG)
#endif
}

SendAudio(pPlayer, const szSample[]) {
	message_begin(MSG_ONE_UNRELIABLE, g_iMsgIdSendAudio, .player = pPlayer)
	write_byte(pPlayer)
	write_string(szSample)
	write_short(PITCH_NORM)
	message_end()
}