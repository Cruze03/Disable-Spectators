#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_THIRDPERSON 5
#define SPECMODE_FREELOOK 6

bool g_bSpecDisabled[MAXPLAYERS+1], g_bPrint[MAXPLAYERS+1][MAXPLAYERS+1], g_bFound = true;
int g_iClient, g_iCL, g_iTarget, g_iSpecMod;
Handle g_hSpecDisabled;

ConVar g_hForceCamera = null;
int g_iForceCamera = -1;

public Plugin myinfo =  
{ 
	name = "[ANY] Disable Spec | !disablespec", 
	author = "Cruze", 
	description = "Player can chooser whether other player can spec him/her or not.", 
	version = "1.0.0", 
	url = "http://steamcommunity.com/profiles/76561198132924835 | https://github.com/Cruze03" 
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_disablespec", Command_DisableSpec);
	
	HookEvent("round_start", Event_RoundStart);
	
	g_hSpecDisabled = RegClientCookie("Disable_Spec", "Per player disable spec preferrence", CookieAccess_Protected);
	
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i))
	{
		OnClientDisconnect(i);
		OnClientPutInServer(i);
	}
}

public Action Event_RoundStart(Event ev, const char[] name, bool dbc)
{
	for(int client = 0; client < MaxClients; client++)
	{
		for(int i = 0; i < MaxClients; i++)
		{
			g_bPrint[client][i] = false;
			g_bPrint[i][client] = false;
		}
	}
}

public void OnMapStart()
{
	g_hForceCamera = FindConVar("mp_forcecamera");
	if(g_hForceCamera != null)
	{
		HookConVarChange(g_hForceCamera, ConVarChange);
		g_iForceCamera = g_hForceCamera.IntValue;
	}
}

public int ConVarChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	g_iForceCamera = g_hForceCamera.IntValue;
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	if(AreClientCookiesCached(client))
	{
		SetClientCookie(client, g_hSpecDisabled, g_bSpecDisabled[client] ? "1" : "");
	}
}

public void OnClientPutInServer(int client)
{
	g_bSpecDisabled[client] = false;
	
	for(int i = 0; i < MaxClients; i++)
		g_bPrint[client][i] = false;
	
	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}
}

public void OnClientCookiesCached(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	char sValue[8];
	GetClientCookie(client, g_hSpecDisabled, sValue, 8);
	
	g_bSpecDisabled[client] = sValue[0] ? true : false;
}

public Action Command_DisableSpec(int client, int args)
{
	if(!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	if(!AreClientCookiesCached(client))
	{	
		CPrintToChat(g_iClient, "{lightblue}→{default} Your data is not loaded yet. Try again later.", g_iTarget);
		return Plugin_Handled;
	}
	
	g_bSpecDisabled[client] = !g_bSpecDisabled[client];
	
	CPrintToChat(client, "{lightblue}→{default} Players %s{default} spectate you now.", g_bSpecDisabled[client] ? "{lightred}cannot" : "{lime}can");
	
	if(!g_bSpecDisabled[client])
	{
		for(int i = 0; i < MaxClients; i++)
			g_bPrint[i][client] = false;
	}
	return Plugin_Handled;
}

public void OnGameFrame()
{
	for(g_iClient = 1; g_iClient <= MaxClients; g_iClient++)
	{
		if(IsClientInGame(g_iClient) && !IsPlayerAlive(g_iClient))
		{
			g_iSpecMod = GetEntProp(g_iClient, Prop_Send, "m_iObserverMode");
			g_iTarget = GetEntPropEnt(g_iClient, Prop_Send, "m_hObserverTarget");
			if(g_iTarget != -1 && IsClientInGame(g_iTarget) && IsPlayerAlive(g_iTarget))
			{
				if(g_bSpecDisabled[g_iTarget] && (g_iSpecMod == SPECMODE_FIRSTPERSON || g_iSpecMod == SPECMODE_THIRDPERSON) && g_iTarget != g_iClient)
				{
					if(!g_bPrint[g_iClient][g_iTarget])
					{
						PrintHintText(g_iClient, "Player %N has disabled spectate", g_iTarget);
						g_bPrint[g_iClient][g_iTarget] = true;
					}
					
					if(CheckCommandAccess(g_iClient, "sm_disablespec_bypass", ADMFLAG_ROOT))
					{
						return;
					}

					g_bFound = true;
					g_iTarget = FindTargetToSpec(g_iClient, g_iTarget, g_bFound);
					if(g_iTarget != -1)
					{
						/*
						if(!g_bFound)
						{
							PrintHintText(g_iClient, "There are no other player you are allowed to spec.");
						}
						*/
						if(g_bSpecDisabled[g_iTarget] && (g_iSpecMod == SPECMODE_FIRSTPERSON || g_iSpecMod == SPECMODE_THIRDPERSON) && g_iTarget != g_iClient)
						{
							SetEntProp(g_iClient, Prop_Send, "m_iObserverMode", SPECMODE_FREELOOK);
							SetEntProp(g_iClient, Prop_Send, "m_iFOV", 0);
							SetEntPropVector(g_iClient, Prop_Data, "m_vecViewOffset", NULL_VECTOR);
						}
						else
							SetEntPropEnt(g_iClient, Prop_Send, "m_hObserverTarget", g_iTarget);
					}
					else
					{
						SetEntProp(g_iClient, Prop_Send, "m_iObserverMode", SPECMODE_FREELOOK);
						SetEntProp(g_iClient, Prop_Send, "m_iFOV", 0);
						SetEntPropVector(g_iClient, Prop_Data, "m_vecViewOffset", NULL_VECTOR);
					}
				}
			}
		}
	}
}

int FindTargetToSpec(int iClient, int iTarget, bool &bFound = true)
{
	for(g_iCL = iTarget+1; g_iCL <= MaxClients; g_iCL++)
	{
		if(IsClientInGame(g_iCL) && IsPlayerAlive(g_iCL) && OnlyTeam(g_iCL, iClient) && g_iCL != iClient && !g_bSpecDisabled[g_iCL])
		{
			return g_iCL;
		}
	}
	for(g_iCL = 1; g_iCL <= MaxClients; g_iCL++)
	{
		if(g_iCL == iTarget)
		{
			bFound = false;
			return iTarget;
		}
		if(IsClientInGame(g_iCL) && IsPlayerAlive(g_iCL) && OnlyTeam(g_iCL, iClient) && g_iCL != iClient && g_iCL != iTarget && !g_bSpecDisabled[g_iCL])
		{
			return g_iCL;
		}
	}
	bFound = false;
	return -1;
}

bool OnlyTeam(int client, int target)
{
	if(g_iForceCamera == 1)
	{
		return GetClientTeam(client) == GetClientTeam(target);
	}
	return true;
}