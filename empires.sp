#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <scp>

#define MAX_MESSAGE_LENGTH 250
#define VERSION "1.0"

#define IS_CLIENT(%1)   (1 <= %1 <= MaxClients)

#define SOLID_NONE 0
#define FSOLID_NOT_SOLID 0x0004
#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT			( 1<<1 )
#define	HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)

#define MAXUNITS 2048

new Float:g_vEyeAngles[MAXPLAYERS+1][3];
new bool:g_InAttack[MAXPLAYERS+1] = {false,...};
new bool:g_InAttack2[MAXPLAYERS+1] = {false,...};
new bool:g_InUse[MAXPLAYERS+1] = {false,...};
new bool:g_InReload[MAXPLAYERS+1] = {false,...};


new Float:uDestination[MAXUNITS][3];
new bool:uInCombat[MAXUNITS];
new uCurrentTarget[MAXUNITS];
new uType[MAXUNITS];
new uOwner[MAXUNITS];
new uHP[MAXUNITS];

/*
Unit Types:
0 -None
1 -City			(Base)
2 -House		(Gold)
3 -Farm			(Food)
4 -Mine			(Iron)
6 -Mill			(Wood)
7 -Barracks		(Army)
8 -Hospital 	(Heals)
9 -Artillery	(Range Attack)

10 -Basic Unit	()

*/


new Handle:UnitArray[MAXPLAYERS+1];
new bool:g_bFirstLoad = true;

//Player Resources
new pColor[MAXPLAYERS+1] = {0,...};
new pGold[MAXPLAYERS+1];
new pIron[MAXPLAYERS+1];
new pWood[MAXPLAYERS+1];
new pFood[MAXPLAYERS+1];
new pScore[MAXPLAYERS+1]={0,...};

new pCTypes[MAXPLAYERS+1][10];
new pBuildMDL[MAXPLAYERS+1] = {-1,...};
new pBuilding[MAXPLAYERS+1] = {0,...};
new Float:pBuildRot[MAXPLAYERS+1] = {0.0,...};

new const pColors[20][3] = {
	{255,255,255},
	{255,0,0},
	{0,255,0},
	{0,0,255},
	{255,0,255},
	{255,255,0},
	{0,255,255},
	{128,128,128},
	{128,0,0},
	{0,128,0},
	{0,0,128},
	{128,0,128},
	{128,128,0},
	{0,128,128},
	{255,0,128},
	{255,128,0},
	{0,255,128},
	{128,0,255},
	{128,255,0},
	{0,128,255}};
	
new const String:sBuildings[10][] = {
	"None",
	"City",
	"House",
	"Farm",
	"Mine",
	"Mill",
	"Wall",
	"Barracks",
	"Hospital",
	"Artillery"};
	
new const String:sBuildMDLs[10][] = {
	"models/props_c17/consolebox03a.mdl",
	"models/props_skybox/skybox_carrier.mdl",
	"models/props_skybox/farm_house.mdl",
	"models/props_skybox/farm_barn.mdl",
	"models/props_junk/rock001a.mdl",
	"models/props_lab/jar01b.mdl",
	"models/props_granary/hay_bale_round_skybox.mdl",
	"models/egypt/tent/tent_skybox.mdl",
	"models/props_c17/consolebox03a.mdl",
	"models/props_c17/consolebox03a.mdl"};

new const Float:fBuildScale[10] = {
	1.0, //None
	0.2, //City
	0.5, //House
	0.3, //Farm
	1.0, //Mine
	1.0, //Mill
	1.5, //Wall
	1.5, //Barracks
	1.0,
	1.0};
new const iBuildAlpha[10] = {
	255,
	255,
	100,
	100,
	100,
	100,
	100,
	100,
	100,
	100};

new const iBuildCost[10][4] = {
	// G/I/W/F
	{0,0,0,0}, //None
	{25,200,100,100}, //City
	{25,25,20,50}, //House
	{20,15,10,15}, //Farm
	{10,10,10,10}, //Mine
	{10,20,30,20}, //Mill
	{10,20,50,10}, //Wall
	{50,50,40,50}, //Barracks
	{30,0,0,100}, // Hospital
	{100,300,250,200}}; //Artillery
	
/*



Unit:
	-Index
	-Type
	-Destination
	

Player Resources:

	Gold: 0
	Food: 150
	Iron: 75
	Wood: 100
	
	Cities
	Mines
	Farms
	
	Ranged
	Soldiers
	
Good (Small) Props:
Small Tree: models/harvest/tree/tree_medium_skybox.mdl
Small RockHill Thing 1: models/props_swamp/rootstump01.mdl
Small RockHill Thing 2: models/props_swamp/rootstump02.mdl
Console box: models/props_c17/consolebox03a.mdl
Jar: models/props_lab/jar01b.mdl
Small Circle Light: models/props_2fort/groundlight001.mdl

Padlock: models/props_farm/padlock.mdl - Wall
Small Rock: models\props_junk\rock001a.mdl - Mines
Camp: models/egypt/tent/tent_skybox.mdl - Barracks
models\props_skybox\farm_house.mdl - no collision (could be city)
models\props_skybox\farm_barn.mdl  - nocoll (could be farm)

Units:
models/weapons/w_models/w_stickybomb2.mdl   - No Spikes
models/weapons/w_models/w_stickybomb_d.mdl  - Less Spikes
models/weapons/w_models/w_stickybomb.mdl    - Regular
models/weapons/w_models/w_stickybomb3.mdl   - Ton of spikes.


models\player\gibs\gibs_balloon.mdl - Balloon Dog!
models\player\gibs\gibs_duck.mdl - Ducky!

Spider: models/props_halloween/smlprop_spider.mdl (no Collision)
*/

// Global Variables
new g_bloodModel[5];
new countdown = 0;
//new g_sprayModel;

public Plugin:myinfo = {
	name = "Empires",
	author = "Mitch",
	description = "Strategy Game for tf2",
	version = VERSION,
	url = "SnBx.info"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_cp", Command_CMD1);
	RegConsoleCmd("sm_cp2", Command_CMD2);
	RegConsoleCmd("sm_cp3", Command_CMD3);
	//AddCommandListener(Command_LAW, "+lookatweapon");
	//AddCommandListener(Command_USE, "+use");
	//LoadTranslations("common.phrases");
	HookEvent("player_spawn", Event_Spawn);
	CreateTimer(0.1, Update_HUD, _, TIMER_REPEAT);
	CreateTimer(1.0, TimerIncome, _, TIMER_REPEAT);
	
	for(new x = 1; x <= MaxClients; x++)
		if(IsClientInGame(x))
			DefaultPlayer(x);
}
DefaultPlayer(client)
{
	InitPlayerColor(client);
	pGold[client] = iBuildCost[1][0]+1;
	pIron[client] = iBuildCost[1][1]+1;
	pWood[client] = iBuildCost[1][2]+1;
	pFood[client] = iBuildCost[1][3]+1;
}
public Action:Update_HUD(Handle:timer)
{
	for(new x = 1; x <= MaxClients; x++)
	{
		if(!IsClientInGame(x))
		 continue;
		
		SetHudTextParams(0.005, 0.84, 0.1, pColors[pColor[x]][0], pColors[pColor[x]][1], pColors[pColor[x]][2], 255, 1,0.0, 0.1, 0.0);
		ShowHudText(x, 1, "Units:	%i", GetArraySize(UnitArray[x]));
	}
}
public Action:TimerIncome(Handle:timer)
{
	new String:sFormat[128];
	switch(countdown)
	{
		case 8: Format(sFormat, sizeof(sFormat), "[||||||||]");
		case 7: Format(sFormat, sizeof(sFormat), "[|||||||  ]");
		case 6: Format(sFormat, sizeof(sFormat), "[||||||    ]");
		case 5: Format(sFormat, sizeof(sFormat), "[|||||      ]");
		case 4: Format(sFormat, sizeof(sFormat), "[||||        ]");
		case 3: Format(sFormat, sizeof(sFormat), "[|||          ]");
		case 2: Format(sFormat, sizeof(sFormat), "[||            ]");
		case 1: Format(sFormat, sizeof(sFormat), "[|              ]");
		case 0: Format(sFormat, sizeof(sFormat), "[                ]");
	}
	if(countdown == 0)
	{
		countdown = 8;
		for(new x = 1; x <= MaxClients; x++)
		{
			if(!IsClientInGame(x))
			 continue;
			
			//Gold
			pGold[x] += pCTypes[x][1]+pCTypes[x][2];
			
			//Iron
			pIron[x] += pCTypes[x][1]+pCTypes[x][4];
			
			//Wood
			pWood[x] += pCTypes[x][1]+pCTypes[x][6];
			
			//Food
			pFood[x] += pCTypes[x][1]+pCTypes[x][3];
			
			pScore[x] = RoundToNearest(float(pGold[x]+pIron[x]+pWood[x]+pFood[x])/4.0);
			//SetEntProp(x, Prop_Send, "m_iFrags", );
		}
	}
	else countdown--;
	for(new x = 1; x <= MaxClients; x++)
	{
		if(!IsClientInGame(x))
		 continue;
		SetHudTextParams(0.0, 0.81, 1.0, 128, 64, 255, 255, 0, 0.0, 0.0, 0.0);
		ShowHudText(x, 0, sFormat);
		
		//Gold
		SetHudTextParams(0.01, 0.87, 1.0, 255, 255, 100, 255, 0, 0.0, 0.0, 0.0);
		ShowHudText(x, 2, "Gold:	%d (+%i)", pGold[x], pCTypes[x][1]+pCTypes[x][2]);
		
		//Iron
		SetHudTextParams(0.015, 0.90, 1.0, 128, 128, 100, 255, 0, 0.0, 0.0, 0.0);
		ShowHudText(x, 3, "Iron:	%d (+%i)", pIron[x], pCTypes[x][1]+pCTypes[x][4]);
		
		//Wood
		SetHudTextParams(0.0, 0.93, 1.0, 180, 100, 64, 255, 0, 0.0, 0.0, 0.0);
		ShowHudText(x, 4, "Wood:	%d (+%i)", pWood[x], pCTypes[x][1]+pCTypes[x][6]);
		
		//Food
		SetHudTextParams(0.005, 0.97, 1.0, 128, 255, 128, 255, 0, 0.0, 0.0, 0.0);
		ShowHudText(x, 5, "Food:	%d (+%i)", pFood[x], pCTypes[x][1]+pCTypes[x][3]);
	}
}
/*
pCTypes
Unit Types:
0 -None
1 -City			(Base)
2 -House		(Gold)
3 -Farm			(Food)
4 -Mine			(Iron)
6 -Mill			(Wood)
7 -Barracks		(Army)
8 -Hospital 	(Heals)
9 -Artillery	(Range Attack)

10 -Basic Unit	()

*/
public OnMapStart()
{
	g_bloodModel[0] = PrecacheModel("decal/blood1.vmt", true);
	g_bloodModel[1] = PrecacheModel("decal/blood2.vmt", true);
	g_bloodModel[2] = PrecacheModel("decal/blood3.vmt", true);
	g_bloodModel[3] = PrecacheModel("decal/blood4.vmt", true);
	g_bloodModel[4] = PrecacheModel("decal/blood5.vmt", true);
	PrecacheSound("buttons/button8.wav", true);
	PrecacheSound("buttons/button9.wav", true);
    //g_sprayModel = PrecacheModel("sprites/bloodspray.vmt", true);
}
public OnConfigsExecuted()
{
	if(g_bFirstLoad)
	{
		g_bFirstLoad = false;
		for(new i = 0; i <= MaxClients; i++)
			if(UnitArray[i] == INVALID_HANDLE)
				UnitArray[i] = CreateArray();
	}
}
public OnPluginEnd()
{
	for(new x = 0; x <= MaxClients; x++)
	{
		new _iSize = GetArraySize(UnitArray[x]);
		for(new i = 0; i < _iSize; i++)
		{
			new entity = GetArrayCell(UnitArray[x], i);
			if(IsValidEntity(entity))
			{
				AcceptEntityInput(entity, "Kill");
				//RemoveFromArray(UnitArray[x], entity);
			}
		}
	}
}


public Action:Command_CMD1(client, args) {
	CreateUnit(client);
	return Plugin_Handled;
}
public Action:Command_CMD2(client, args) {
	CreateUnitHostile(client);
	return Plugin_Handled;
}
public Action:Command_CMD3(client, args) {

}
public OnClientPutInServer(client)
{
	DefaultPlayer(client);
}
InitPlayerColor(client)
{
	pColor[client] = -1;
	new bool:found = false;
	new rnd = -1;
	while(pColor[client] == -1)
	{
		rnd = GetRandomInt(0,19);
		found = false;
		for(new x = 1; x <= MaxClients; x++)
			if(x != client) 
				if(pColor[x] == rnd)
					found = true;
		if(!found)
			pColor[client] = rnd;
	}
}
public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	/*for(new s = 0; s < 6; s++)
		if(s!=2)
			TF2_RemoveWeaponSlot(client, s);*/
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", 3600000.0 + GetGameTime());
	SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_HEALTH);
}
public Action:OnPlayerRunCmd(client, &iButtons, &iImpulse, Float:fVel[3], Float:fAng[3], &iWeapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) {
	g_vEyeAngles[client] = fAng;
	if (IS_CLIENT(client) && IsPlayerAlive(client)) {
		if(IsProp(pBuildMDL[client]))
		{
			if(pBuilding[client] == 0)
			{
				AcceptEntityInput(pBuildMDL[client], "Kill");
			}
			new Float:fPos[3],Float:fAng2[3];
			TraceEye(client, fPos);
			fPos[0] = (float(RoundToNearest(fPos[0]/16.0))*16.0);
			fPos[1] = (float(RoundToNearest(fPos[1]/16.0))*16.0);
			fPos[2] = 0.0;
			fAng2[1] = pBuildRot[client];
			TeleportEntity(pBuildMDL[client], fPos, fAng2, NULL_VECTOR);
		}
		if(!g_InAttack[client] && iButtons & IN_ATTACK)
		{
			g_InAttack[client] = true;
			new _iSize = GetArraySize(UnitArray[client]);
			for(new i = 0; i < _iSize; i++)
			{
				new entity = GetArrayCell(UnitArray[client], i);
				if(IsValidEntity(entity))
				{
					if(uType[entity] >= 10)
					{
						if(!uInCombat[entity])
						{
							TraceEye(client, uDestination[entity]);
							AcceptEntityInput(entity, "Wake");
							AcceptEntityInput(entity, "EnableMotion");
						}
					}
				}
			}
		}
		else if(g_InAttack[client] && !(iButtons & IN_ATTACK))
		{
			g_InAttack[client] = false;
		}
		if(!g_InAttack2[client] && iButtons & IN_ATTACK2)
		{
			g_InAttack2[client] = true;
			new _iSize = GetArraySize(UnitArray[0]);
			for(new i = 0; i < _iSize; i++)
			{
				new entity = GetArrayCell(UnitArray[0], i);
				if(IsValidEntity(entity))
				{
					if(!uInCombat[entity])
					{
						TraceEye(client, uDestination[entity]);
						AcceptEntityInput(entity, "Wake");
						AcceptEntityInput(entity, "EnableMotion");
						SetEntityRenderMode(entity, RENDER_NORMAL);
					}
				}
			}
		}
		else if(g_InAttack2[client] && !(iButtons & IN_ATTACK))
		{
			g_InAttack2[client] = false;
		}
		//Reload
		if(!g_InReload[client] && iButtons & IN_RELOAD)
		{
			g_InReload[client] = true;
			SendEmpireMenu(client);
		}
		else if(g_InReload[client] && !(iButtons & IN_RELOAD))
		{
			g_InReload[client] = false;
		}
	}
	return Plugin_Continue;
}
SendEmpireMenu(client)
{
	if(!IsValidClient(client)) return;
	pBuilding[client] = 0;
	decl String:g_sDisplay[128];
	new Handle:menu = CreateMenu(Menu_Main, MENU_ACTIONS_DEFAULT);
	Format(g_sDisplay, sizeof(g_sDisplay), "Empires : %s\n (G/I/W/F)", VERSION);
	SetMenuTitle(menu, g_sDisplay);
	
	if(pCTypes[client][1] == 0)
	{
		AddMenuItem(menu, "city", "City (25/200/100/100)");
	}
	else
	{
		AddMenuItem(menu, "house", 	"House  +G (25/25/20/50)");
		AddMenuItem(menu, "mine", 	"Mine   +I (10/10/10/10)");
		AddMenuItem(menu, "mill", 	"Mill   +W (10/20/30/20)");
		AddMenuItem(menu, "farm", 	"Farm   +F (20/15/10/15)");
		AddMenuItem(menu, "wall", 	"Wall      (10/20/50/10)");
		AddMenuItem(menu, "camp", 	"Barracks  (50/50/40/50)");
		AddMenuItem(menu, "heal", 	"Hospital  (30/0/0/100)");
		AddMenuItem(menu, "range", 	"Artillery (100/300/250/200)");
	}
	
	SetMenuPagination(menu, MENU_NO_PAGINATION);
	SetMenuExitButton(menu, true);
	DisplayMenuAtItem(menu, client, 0, MENU_TIME_FOREVER);
}


public Menu_Main(Handle:main, MenuAction:action, client, param2)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(main);
		case MenuAction_Cancel:
			pBuilding[client] = 0;
		case MenuAction_Select:
		{
			new String:info[32];
			GetMenuItem(main, param2, info, sizeof(info));
			new build = 0;
			if (StrEqual(info,"city"))
				build = 1;
			else if (StrEqual(info,"house"))
				build = 2;
			else if (StrEqual(info,"farm"))
				build = 3;
			else if (StrEqual(info,"mine"))
				build = 4;
			else if (StrEqual(info,"mill"))
				build = 5;
			else if (StrEqual(info,"wall"))
				build = 6;
			else if (StrEqual(info,"camp"))
				build = 7;
			else if (StrEqual(info,"heal"))
				build = 8;
			else if (StrEqual(info,"range"))
				build = 9;
			
			new Resources[4];
			
			Resources[0] = pGold[client]-iBuildCost[build][0]; //Gold
			Resources[1] = pIron[client]-iBuildCost[build][1]; //Iron
			Resources[2] = pWood[client]-iBuildCost[build][2]; //Wood
			Resources[3] = pFood[client]-iBuildCost[build][3]; //Food
			
			new String:sNeeded[128];
			new bool:CanBuild = true;
			if(Resources[0] < 0) {Format(sNeeded, sizeof(sNeeded), "\x07ffff64%i Gold", 0-Resources[0]); CanBuild = false;}
			if(Resources[1] < 0) {Format(sNeeded, sizeof(sNeeded), "%s\x07ffffff%s\x07808064%i Iron", sNeeded, (CanBuild) ? "" : ", ", 0-Resources[1]); CanBuild = false;}
			if(Resources[2] < 0) {Format(sNeeded, sizeof(sNeeded), "%s\x07ffffff%s\x07b46440%i Wood", sNeeded, (CanBuild) ? "" : ", ", 0-Resources[2]); CanBuild = false;}
			if(Resources[3] < 0) {Format(sNeeded, sizeof(sNeeded), "%s\x07ffffff%s\x0780ff80%i Food", sNeeded, (CanBuild) ? "" : ", ", 0-Resources[3]); CanBuild = false;}
			
			if(CanBuild)
			{
				Information(client, "\x01\x0700AAFF Building %s...", sBuildings[build] );
				pBuilding[client] = build;
				MenuBuild(client);
			}
			else
			{
				Warning(client, "\x01\x07ff0000 Need more resources!\n : %s", sNeeded);
				SendEmpireMenu(client);
			}
		}
	}
	return;
}

MenuBuild(client)
{
	if(!IsValidClient(client)) return;
	
	if(!IsProp(pBuildMDL[client]))
	{
		new Ent = CreateEntityByName("prop_dynamic_override");
		PrecacheModel(sBuildMDLs[pBuilding[client]]);
		DispatchKeyValue(Ent, "targetname","tempbuild");
		DispatchKeyValue(Ent, "model", sBuildMDLs[pBuilding[client]]);
		DispatchKeyValue(Ent, "disablereceiveshadows", "1");
		DispatchKeyValue(Ent, "disableshadows", "1");
		DispatchKeyValue(Ent, "solid", "0");
		DispatchSpawn(Ent);
		
		if(fBuildScale[pBuilding[client]] != 1.0) SetEntPropFloat(Ent, Prop_Send, "m_flModelScale", fBuildScale[pBuilding[client]]);
	
		pBuildMDL[client] = Ent;
		SetEntityRenderMode(Ent, RENDER_TRANSADD);
		//SetEntityRenderColor(Ent, pColors[pColor[client]][0], pColors[pColor[client]][1], pColors[pColor[client]][2], 100);
		SetEntityRenderColor(Ent, pColors[pColor[client]][0], pColors[pColor[client]][1], pColors[pColor[client]][2], iBuildAlpha[pBuilding[client]]);
	}
	
	decl String:g_sDisplay[128];
	new Handle:menu = CreateMenu(Menu_Build, MENU_ACTIONS_DEFAULT);
	Format(g_sDisplay, sizeof(g_sDisplay), "Empires : %s\n Building %s", VERSION, sBuildings[pBuilding[client]]);
	SetMenuTitle(menu, g_sDisplay);
	
	AddMenuItem(menu, "build", "Place Building");
	AddMenuItem(menu, "rotate", "Rotate");
	
	SetMenuPagination(menu, MENU_NO_PAGINATION);
	SetMenuExitButton(menu, true);
	DisplayMenuAtItem(menu, client, 0, MENU_TIME_FOREVER);
}

public Menu_Build(Handle:main, MenuAction:action, client, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			//PrintToChatAll("%i closed menu", client);
			//pBuilding[client] = 0;
			CloseHandle(main);
		}
		case MenuAction_Cancel:
			pBuilding[client] = 0;
		case MenuAction_Select:
		{
			new String:info[32];
			GetMenuItem(main, param2, info, sizeof(info));
			if(StrEqual(info,"build"))
			{
				//Build(client, pBuilding[client]);
				new Float:fPos[3];
				GetEntPropVector(pBuildMDL[client], Prop_Send, "m_vecOrigin", fPos);
				
				if(fPos[2] > 4.0)
				{
					Warning(client, "\x01\x07ff0000Must place building on solid ground!");
					MenuBuild(client);
				}
				else if(IsAreaFilled(fPos))
				{
					Warning(client, "\x01\x07ff0000Could not place building!");
					MenuBuild(client);
				}
				else
				{
					CreateBuilding(client, pBuilding[client], fPos);
					pBuilding[client] = 0;
				}
			}
			else if (StrEqual(info,"rotate"))
			{
				pBuildRot[client] += 90.0;
				if(pBuildRot[client] == 360.0) pBuildRot[client] = 0.0;
				MenuBuild(client);
			}
		}
	}
	return;
}

CreateBuilding(client, build, Float:fPos[3])
{
	new Ent = CreateEntityByName("prop_physics_override");
	PrecacheModel("models/props_c17/consolebox03a.mdl");
	DispatchKeyValue(Ent, "targetname","building");
	DispatchKeyValue(Ent, "model", "models/props_c17/consolebox03a.mdl");
	
	DispatchKeyValue(Ent, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent, "disableshadows", "1");
	DispatchKeyValue(Ent, "solid", "6");
	DispatchSpawn(Ent);
	SetEntityMoveType(Ent, MOVETYPE_VPHYSICS);
	SetEntProp(Ent, Prop_Data, "m_CollisionGroup", 11);
	
	AcceptEntityInput(Ent, "Sleep");
	AcceptEntityInput(Ent, "DisableMotion");
	
	SetEntityRenderColor(Ent, 0, 0, 0, 0);
	SetEntityRenderMode(Ent, RENDER_NONE);
	
	new Ent2 = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(Ent2, "model", sBuildMDLs[build]);
	DispatchKeyValue(Ent2, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent2, "disableshadows", "1");
	DispatchKeyValue(Ent2, "solid", "0");
	DispatchSpawn(Ent2);
	
	if(fBuildScale[build] != 1.0) SetEntPropFloat(Ent2, Prop_Send, "m_flModelScale", fBuildScale[pBuilding[client]]);
	SetVariantString("!activator");
	AcceptEntityInput(Ent2, "SetParent", Ent, Ent2, 0);
	
	//SetEntityRenderMode(Ent2, RENDER_GLOW);
	SetEntityRenderColor(Ent2, pColors[pColor[client]][0], pColors[pColor[client]][1], pColors[pColor[client]][2], 255);
	
	TeleportEntity(Ent, fPos, NULL_VECTOR,NULL_VECTOR);
	
	new Float:fRot[3];
	fRot[1] = pBuildRot[client];
	TeleportEntity(Ent, NULL_VECTOR, fRot, NULL_VECTOR);
	
	SetEntProp(Ent, Prop_Send, "m_hOwnerEntity", client);
	uOwner[Ent] = client;
	PushArrayCell(UnitArray[client], Ent);
	
	uHP[Ent] = 255;
	uDestination[Ent][0] = 0.0;
	uDestination[Ent][1] = 0.0;
	uDestination[Ent][2] = 0.0;
	uInCombat[Ent] = false;
	uCurrentTarget[Ent] = -1;
	uType[Ent] = build;
	pCTypes[client][build]++;
	
	HookSingleEntityOutput(Ent, "OnUser2", BuildThink);
	
	SetVariantString("OnUser1 !self:FireUser2::0.1:-1");
	AcceptEntityInput(Ent, "AddOutput");
	
	AcceptEntityInput(Ent, "FireUser1");
}
//This is just a test unit!
CreateUnit(client)
{
	new Float:fPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
	fPos[2] += 12.0;
	new Ent = CreateEntityByName("prop_physics_override");
	PrecacheModel("models/gibs/hgibs.mdl");
	DispatchKeyValue(Ent, "targetname","unit");
	DispatchKeyValue(Ent, "model", "models/gibs/hgibs.mdl");
	DispatchKeyValue(Ent, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent, "disableshadows", "1");
	DispatchKeyValue(Ent, "solid", "6");
	SetEntityMoveType(Ent, MOVETYPE_VPHYSICS);
	DispatchSpawn(Ent);
	
	SetEntityRenderMode(Ent, RENDER_GLOW);
	SetEntityRenderColor(Ent, pColors[pColor[client]][0], pColors[pColor[client]][1], pColors[pColor[client]][2], 100);
	
	new Ent2 = CreateEntityByName("prop_dynamic_override");
	PrecacheModel("models/props_halloween/smlprop_spider.mdl");
	DispatchKeyValue(Ent2, "model", "models/props_halloween/smlprop_spider.mdl");
	DispatchKeyValue(Ent2, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent2, "disableshadows", "1");
	DispatchKeyValue(Ent2, "solid", "0");
	DispatchSpawn(Ent2);
	
	
	//SetEntProp(Ent2, Prop_Send, "m_bShouldGlow", 1);
	//SetEntProp(Ent2, Prop_Send, "m_clrGlow", ( (0 & 0xFF) << 16)|( (0 & 0xFF) << 8 )|( (255	& 0xFF) << 0 ));
	
	SetVariantString("!activator");
	AcceptEntityInput(Ent2, "SetParent", Ent, Ent2, 0);
	SetEntProp(Ent, Prop_Data, "m_CollisionGroup", 11);
	TeleportEntity(Ent, fPos, g_vEyeAngles[client], NULL_VECTOR);
	//AcceptEntityInput(Ent, "EnableMotion");
	//AcceptEntityInput(Ent, "Wake");
	AcceptEntityInput(Ent, "Sleep");
	SetEntProp(Ent, Prop_Send, "m_hOwnerEntity", client);
	uOwner[Ent] = client;
	PushArrayCell(UnitArray[client], Ent);
	
	//SetEntProp(Ent, Prop_Data, "m_iHealth", 255);
	
	uHP[Ent] = 255;
	uDestination[Ent][0] = 0.0;
	uDestination[Ent][1] = 0.0;
	uDestination[Ent][2] = 0.0;
	uInCombat[Ent] = false;
	uCurrentTarget[Ent] = -1;
	uType[Ent] = 10;
	
	HookSingleEntityOutput(Ent, "OnUser2", UnitThink);
	
	SetVariantString("OnUser1 !self:FireUser2::0.1:-1");
	AcceptEntityInput(Ent, "AddOutput");
	
	AcceptEntityInput(Ent, "FireUser1");
	
	SDKHook(Ent, SDKHook_StartTouchPost, OnStartTouchPost);
	
}
CreateUnitHostile(client)
{
	
	Information(client, "\x01\x0700AAFFSpawning Unit \x07666666(Hostile)");
	
	new Float:fPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
	fPos[2] += 10.0;
	
	new Ent = CreateEntityByName("prop_physics_override");
	if(!IsValidEntity(Ent))
	{
		Warning(client, "\x01\x07FF0000Could Not Create Unit \x07666666(Base Prop)");
		return;
	}
	
	PrecacheModel("models/gibs/hgibs.mdl");
	DispatchKeyValue(Ent, "targetname","unit");
	DispatchKeyValue(Ent, "model", "models/gibs/hgibs.mdl");
	DispatchKeyValue(Ent, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent, "disableshadows", "1");
	DispatchKeyValue(Ent, "solid", "6");
	if(!DispatchSpawn(Ent))
	{
		Warning(client, "\x01\x07FF0000Could Not Create Unit \x07666666(Base Prop (Spawn))");
		return;
	}
	SetEntityMoveType(Ent, MOVETYPE_VPHYSICS);
	SetEntProp(Ent, Prop_Data, "m_CollisionGroup", 11);
	
	SetEntityRenderMode(Ent, RENDER_NORMAL);
	//SetEntityRenderColor(Ent, 0, 0, 0, 64);
	
	new Ent2 = CreateEntityByName("prop_dynamic_override");
	if(!IsValidEntity(Ent2))
	{
		Warning(client, "\x01\x07FF0000Could Not Create Unit \x07666666(Effect Prop)");
		return;
	}
	PrecacheModel("models/props_halloween/smlprop_spider.mdl");
	DispatchKeyValue(Ent2, "model", "models/props_halloween/smlprop_spider.mdl");
	DispatchKeyValue(Ent2, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent2, "disableshadows", "1");
	DispatchKeyValue(Ent2, "solid", "0");
	DispatchSpawn(Ent2);
	SetEntProp(Ent2, Prop_Data, "m_CollisionGroup", 11);
	SetVariantString("!activator");
	AcceptEntityInput(Ent2, "SetParent", Ent, Ent2, 0);
	
	TeleportEntity(Ent, fPos, g_vEyeAngles[client], NULL_VECTOR);
	//AcceptEntityInput(Ent, "EnableMotion");
	//AcceptEntityInput(Ent, "Wake");
	AcceptEntityInput(Ent, "Sleep");
	SetEntProp(Ent, Prop_Send, "m_hOwnerEntity", -1);
	uOwner[Ent]=0;
	//Player Color
	
	PushArrayCell(UnitArray[0], Ent);
	
	
	Information(client, "\x01\x0700AAFFUnit#%i: %i \x07666666(Hostile)", FindValueInArray(UnitArray[0], Ent), Ent);
	//SetEntProp(Ent, Prop_Data, "m_iHealth", 255);
	
	uHP[Ent] = 255;
	uDestination[Ent][0] = 0.0;
	uDestination[Ent][1] = 0.0;
	uDestination[Ent][2] = 0.0;
	uInCombat[Ent] = false;
	uCurrentTarget[Ent] = -1;
	uType[Ent] = 10;
	
	HookSingleEntityOutput(Ent, "OnUser2", UnitThink);
	
	SetVariantString("OnUser1 !self:FireUser2::0.1:-1");
	AcceptEntityInput(Ent, "AddOutput");
	
	AcceptEntityInput(Ent, "FireUser1");
	
	SDKHook(Ent, SDKHook_StartTouchPost, OnStartTouchPost);
}
public UnitThink(const String:output[], caller, activator, Float:delay)
{
	if(uHP[caller] < 35)
	{
		new index = FindValueInArray(UnitArray[uOwner[caller]], caller);
		if(index > -1)
			RemoveFromArray(UnitArray[uOwner[caller]], index);
		UnhookSingleEntityOutput(caller, "OnUser2", UnitThink);
		AcceptEntityInput(caller, "Kill");
		return;
	}
	if(uInCombat[caller])
	{
		new target = uCurrentTarget[caller];
		if(IsValidEntity(target))
		{
			decl Float:unitpos[3];
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", unitpos);
			unitpos[0]+=362.0;
			unitpos[2]+=4.0;
			//TE_SetupSmoke(unitpos, g_bloodModel[GetRandomInt(0,4)], 5.0, 5);
			uHP[target] -= 2;
			if(GetRandomInt(0,2)==0)
			{
				new iClr[4];
				iClr[0] = pColors[pColor[uOwner[target]]][0];
				iClr[1] = pColors[pColor[uOwner[target]]][1];
				iClr[2] = pColors[pColor[uOwner[target]]][2];
				iClr[3] = 255;
				TE_SetupBloodSprite(unitpos, Float:{-90.0,0.0,0.0}, iClr, GetRandomInt(1,5), g_bloodModel[GetRandomInt(0,4)], g_bloodModel[GetRandomInt(0,4)]);
				TE_SendToAll();
			}
		}
		else
		{
			uCurrentTarget[caller] = -1;
			AcceptEntityInput(caller, "EnableMotion");
			uInCombat[caller] = false;
		}
	}
	else
	{
	// Check to see if should move.
		if(!((uDestination[caller][0] == 0.0) && (uDestination[caller][1] == 0.0) && (uDestination[caller][2] == 0.0)))
		{
			//PrintToServer("%i moving...", caller);
			decl Float:angle[3], Float:unitpos[3], Float:vec[3];
			GetEntPropVector(caller, Prop_Send, "m_vecOrigin", unitpos);
			
			MakeVectorFromPoints(uDestination[caller], unitpos, vec);
			GetVectorAngles(vec, angle);
			angle[0] *= -1.0;
			angle[1] += 180.0;
			
			if(GetVectorDistance(unitpos, uDestination[caller]) <= 12.0)
			{
				uDestination[caller] = Float:{0.0,0.0,0.0};
				AcceptEntityInput(caller, "Sleep");
				AcceptEntityInput(caller, "DisableMotion");
			}
			
			TeleportEntity(caller, NULL_VECTOR, angle, NULL_VECTOR);
			
			if(IsOnGround(caller, 8.0))
			{
				decl Float:vecForce[3];
				GetAngleVectors(angle, vecForce, NULL_VECTOR, NULL_VECTOR);
				vecForce[0] *= 50.0;
				vecForce[1] *= 50.0;
				vecForce[2] = (vecForce[2]*50.0)+1;
				TeleportEntity(caller, NULL_VECTOR, NULL_VECTOR, vecForce);
			}
		}
	}
	AcceptEntityInput(caller, "FireUser1");
	
}
public BuildThink(const String:output[], caller, activator, Float:delay)
{
	if(uHP[caller] < 10)
	{
		new index = FindValueInArray(UnitArray[uOwner[caller]], caller);
		if(index > -1)
			RemoveFromArray(UnitArray[uOwner[caller]], index);
		UnhookSingleEntityOutput(caller, "OnUser2", UnitThink);
		
		pCTypes[uOwner[caller]][uType[caller]]--;
		
		AcceptEntityInput(caller, "Kill");
		
	}
	else AcceptEntityInput(caller, "FireUser1");
}
public OnStartTouchPost(entity, other) 
{
	// detonate if the missile hits something solid.
	//if ((GetEntProp(other, Prop_Data, "m_nSolidType") != SOLID_NONE) && (!(GetEntProp(other, Prop_Data, "m_usSolidFlags") & FSOLID_NOT_SOLID)))
	
	if(uType[other] > 0)
	{
		//if(uType[other] != 10) PrintToServer("%i : %i", entity, uType[other]);
		if(!uInCombat[entity])
		{
			if(uOwner[entity] != uOwner[other])
			{
				uInCombat[entity] = true;
				decl Float:angle[3], Float:unitpos[3], Float:unitpos2[3], Float:vec[3];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", unitpos);
				GetEntPropVector(other, Prop_Send, "m_vecOrigin", unitpos2);
				MakeVectorFromPoints(unitpos2, unitpos, vec);
				GetVectorAngles(vec, angle);
				angle[0] *= -1.0;
				angle[1] += 180.0;
				TeleportEntity(entity, NULL_VECTOR, angle, NULL_VECTOR);
				uCurrentTarget[entity] = other;
				AcceptEntityInput(entity, "Sleep");
				AcceptEntityInput(entity, "DisableMotion");
			}
			else if(uType[other] == 10)
			{
				if((uDestination[other][0] == 0.0) && (uDestination[other][1] == 0.0) && (uDestination[other][2] == 0.0))
				{
					uDestination[entity] = Float:{0.0,0.0,0.0};
					AcceptEntityInput(entity, "Sleep");
					AcceptEntityInput(entity, "DisableMotion");
				}
			}
		}
	}
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[]) {
	Format(name, MAXLENGTH_NAME, "\x07%06X%s",( (pColors[pColor[author]][0] & 0xFF) << 16)|( (pColors[pColor[author]][1] & 0xFF) << 8 )|( (pColors[pColor[author]][2] & 0xFF) << 0 ), name); // team color by default!
	return Plugin_Changed;
}
public bool:IsAreaFilled(Float:fPos[3])
{
	decl Float:vEnd[3];
	fPos[2] += 2.0;
	vEnd = fPos;
	vEnd[2] += 2.0;
	TR_TraceRayFilter(fPos, vEnd, MASK_ALL, RayType_EndPoint, Filter_NoPlayersA);
	return TR_DidHit(INVALID_HANDLE);
}
public bool:Filter_NoPlayersA(entity, mask)
{
	return (entity > MaxClients)||(entity == 0);
}
public bool:IsOnGround(ent, Float:units)
{
	decl Float:vEnd[3], Float:vOrigin[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vOrigin);
	TR_TraceRayFilter(vOrigin, Float:{90.0,0.0,0.0}, MASK_SHOT, RayType_Infinite, Filter_NoPlayers2, ent);
	if(TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(vEnd, INVALID_HANDLE);
		if(GetVectorDistance(vEnd, vOrigin) <= units)
			return true;
		return false;
	}
	return false;
}
public bool:Filter_NoPlayers2(entity, mask, any:data)
{
	return (entity > MaxClients) && (entity != data);
}

public TraceToEntity(client)
{
	new Float:vecClientEyePos[3], Float:vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos);
	GetClientEyeAngles(client, vecClientEyeAng);    

	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_SHOT, RayType_Infinite, TraceASDF, client);
	//PrintToChat(client, "%d", TR_GetEntityIndex());
	if (TR_DidHit())
	{
		new Float:fPos[3];
		TR_GetEndPosition(fPos);
		return TR_GetEntityIndex();
	}
	return -1;
}
public bool:TraceASDF(entity, mask, any:data)
{
	return (data != entity);// && entity != PlyrProp[data][Glow] && entity != PlyrProp[data][Static] && entity != PlyrProp[data][StaticProp] && entity != PlyrProp[data][PageL] && entity != PlyrProp[data][PageG]);
}
stock TraceEye(client, Float:pos[3])
{
	decl Float:vAngles[3], Float:vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, Filter_NoPlayers);
	if(TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(pos, INVALID_HANDLE);
		return true;
	}
	return false;
}
public bool:Filter_NoPlayers(entity, mask)
{
	return entity > MaxClients;
}

stock bool:IsUnit(Ent)
{
	if(Ent != -1)
	{
		if(IsValidEdict(Ent) && IsValidEntity(Ent) && IsEntNetworkable(Ent))
		{
			decl String:ClassName[255];
			//GetEdictClassname(Ent, ClassName, 255);
			GetEntPropString(Ent, Prop_Data, "m_iName", ClassName, sizeof(ClassName));
			if(StrEqual(ClassName, "unit"))
			{
				return (true);
			}
		}
	}
	return (false);
}

stock bool:IsProp(Ent)
{
	if(Ent != -1)
	{
		if(IsValidEdict(Ent) && IsValidEntity(Ent) && IsEntNetworkable(Ent))
		{
			decl String:ClassName[255];
			GetEdictClassname(Ent, ClassName, 255);
			if(StrEqual(ClassName, "prop_dynamic") || StrEqual(ClassName, "prop_physics"))
			{
				return (true);
			}
		}
	}
	return (false);
}
stock bool:IsValidClient( client ) 
{
    if((1<=client<= MaxClients ) && IsClientInGame(client)) 
        return true;
    return false; 
}

public Information(client, const String:format[], any:...)
{
	EmitSoundToClient(client,"buttons/button9.wav");
	decl String:buffer2[MAX_MESSAGE_LENGTH];
	VFormat(buffer2, sizeof(buffer2), format, 3);
	new Handle:bf = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	BfWriteByte(bf, -1);
	BfWriteByte(bf, true);
	BfWriteString(bf, buffer2);
	EndMessage();
}

public Warning(client, const String:format[], any:...)
{
	EmitSoundToClient(client,"buttons/button8.wav");
	decl String:buffer2[MAX_MESSAGE_LENGTH];
	VFormat(buffer2, sizeof(buffer2), format, 3);
	new Handle:bf = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	BfWriteByte(bf, -1);
	BfWriteByte(bf, true);
	BfWriteString(bf, buffer2);
	EndMessage();
}