/**
 * \file   os_getversioninfo.c
 * \brief  Retrieve operating system version information.
 * \author Copyright (c) 2011-2012 Jason Perkins and the Premake project
 */

#include "premake.h"
#include <stdlib.h>

struct OsVersionInfo
{
	int majorversion;
	int minorversion;
	int revision;
	const char* description;
	int isalloc;
};

static void getversion(struct OsVersionInfo* info);


int os_getversion(lua_State* L)
{
	struct OsVersionInfo info = {0};
	getversion(&info);

	lua_newtable(L);

	lua_pushstring(L, "majorversion");
	lua_pushnumber(L, info.majorversion);
	lua_settable(L, -3);

	lua_pushstring(L, "minorversion");
	lua_pushnumber(L, info.minorversion);
	lua_settable(L, -3);

	lua_pushstring(L, "revision");
	lua_pushnumber(L, info.revision);
	lua_settable(L, -3);

	lua_pushstring(L, "description");
	lua_pushstring(L, info.description);
	lua_settable(L, -3);

	if (info.isalloc) {
		free((void*)info.description);
	}

	return 1;
}

/*************************************************************/

#if defined(PLATFORM_WINDOWS)

#if !defined(VER_SUITE_WH_SERVER)
#define VER_SUITE_WH_SERVER   (0x00008000)
#endif

#ifndef SM_SERVERR2
#	define SM_SERVERR2 89
#endif

SYSTEM_INFO getsysteminfo()
{
	static SYSTEM_INFO systemInfo;
	HMODULE hKrnl32 = GetModuleHandle(TEXT("kernel32"));
	memset(&systemInfo, 0, sizeof(systemInfo));
	if (hKrnl32)
	{
		typedef void (WINAPI* GetNativeSystemInfoSig)(LPSYSTEM_INFO);
		GetNativeSystemInfoSig nativeSystemInfo = (GetNativeSystemInfoSig)GetProcAddress(hKrnl32, "GetNativeSystemInfo");

		if (nativeSystemInfo)
			nativeSystemInfo(&systemInfo);
		else
			GetSystemInfo(&systemInfo);
	}
	return systemInfo;
}

#ifndef NT_SUCCESS
#   define NT_SUCCESS(x) ((x) >= 0)
#endif

OSVERSIONINFOEXW const * GetOSVersionInfo()
{
	static OSVERSIONINFOEXW* posvix = NULL;
	if (!posvix)
	{
		static OSVERSIONINFOEXW osvix = { sizeof(OSVERSIONINFOEXW), 0, 0, 0, 0,{ 0 } }; // not an error, this has to be the W variety!
		static LONG(WINAPI * RtlGetVersion)(OSVERSIONINFOEXW*) = NULL;
		static HMODULE hNtDll = NULL;
		hNtDll = GetModuleHandle(TEXT("ntdll.dll"));
		if (hNtDll)
		{
			*(FARPROC*)&RtlGetVersion = GetProcAddress(hNtDll, "RtlGetVersion");
			if (NULL != RtlGetVersion)
			{
				if (NT_SUCCESS(RtlGetVersion(&osvix)))
				{
					posvix = &osvix;
				}
			}
		}
	}
	return posvix;
}

void getversion(struct OsVersionInfo* info)
{
	static OSVERSIONINFOEXW const* posvix = NULL;
	static struct OsVersionInfo s_info;
	s_info.majorversion = 0;
	s_info.minorversion = 0;
	s_info.revision = 0;
	s_info.description = "Windows";

	if (!posvix)
	{
		posvix = GetOSVersionInfo();
		if (posvix)
		{
			s_info.majorversion = posvix->dwMajorVersion;
			s_info.minorversion = posvix->dwMinorVersion;
			s_info.revision = posvix->wServicePackMajor;
			switch (posvix->dwMajorVersion)
			{
			case 5:
				switch (posvix->dwMinorVersion)
				{
				case 0:
					s_info.description = "Windows 2000";
					break;
				case 1:
					s_info.description = "Windows XP";
					break;
				case 2:
					if (posvix->wProductType == VER_NT_WORKSTATION)
						s_info.description = "Windows XP x64";
					else
						if (posvix->wSuiteMask == VER_SUITE_WH_SERVER)
							s_info.description = "Windows Home Server";
						else
						{
							if (GetSystemMetrics(SM_SERVERR2) == 0)
								s_info.description = "Windows Server 2003";
							else
								s_info.description = "Windows Server 2003 R2";
						}
					break;
				default:
					s_info.description = "Windows [5.x]";
					break;
				}
				break;
			case 6:
				switch (posvix->dwMinorVersion)
				{
				case 0:
					if (posvix->wProductType == VER_NT_WORKSTATION)
						s_info.description = "Windows Vista";
					else
						s_info.description = "Windows Server 2008";
					break;
				case 1:
					if (posvix->wProductType == VER_NT_WORKSTATION)
						s_info.description = "Windows 7";
					else
						s_info.description = "Windows Server 2008 R2";
					break;
				case 2:
					if (posvix->wProductType == VER_NT_WORKSTATION)
						s_info.description = "Windows 8";
					else
						s_info.description = "Windows Server 2012";
					break;
				case 3:
					if (posvix->wProductType == VER_NT_WORKSTATION)
						s_info.description = "Windows 8.1";
					else
						s_info.description = "Windows Server 2012 R2";
					break;
				default:
					s_info.description = "Windows [6.x]";
					break;
				}
				break;
			case 10:
				switch (posvix->dwMinorVersion)
				{
				case 0:
					if (posvix->wProductType == VER_NT_WORKSTATION)
						s_info.description = "Windows 10";
					else
						s_info.description = "Windows Server 2016/2019";
					break;
				default:
					s_info.description = "Windows [10.x]";
					break;
				}
				break;
			}
		}
	}

	memmove(info, &s_info, sizeof(struct OsVersionInfo));
}

/*************************************************************/

#elif defined(PLATFORM_MACOSX)

#include <CoreServices/CoreServices.h>

void getversion(struct OsVersionInfo* info)
{
	SInt32 majorversion, minorversion, bugfix;
	Gestalt(gestaltSystemVersionMajor, &majorversion);
	Gestalt(gestaltSystemVersionMinor, &minorversion);
	Gestalt(gestaltSystemVersionBugFix, &bugfix);

	info->majorversion = majorversion;
	info->minorversion = minorversion;
	info->revision = bugfix;

	info->description = "Mac OS X";
	if (info->majorversion == 10)
	{
		switch (info->minorversion)
		{
		case 4:
			info->description = "Mac OS X Tiger";
			break;
		case 5:
			info->description = "Mac OS X Leopard";
			break;
		case 6:
			info->description = "Mac OS X Snow Leopard";
			break;
		case 7:
			info->description = "Mac OS X Lion";
			break;
		}
	}
}

/*************************************************************/

#elif defined(PLATFORM_BSD) || defined(PLATFORM_LINUX) || defined(PLATFORM_SOLARIS)

#include <string.h>
#include <sys/utsname.h>

void getversion(struct OsVersionInfo* info)
{
	struct utsname u;
	char* ver;

	info->majorversion = 0;
	info->minorversion = 0;
	info->revision = 0;

	if (uname(&u))
	{
		// error
		info->description = PLATFORM_STRING;
		return;
	}

#if __GLIBC__
	// When using glibc, info->description gets set to u.sysname,
	// but it isn't passed out of this function, so we need to copy 
	// the string.
	info->description = malloc(strlen(u.sysname) + 1);
	strcpy((char*)info->description, u.sysname);
	info->isalloc = 1;
#else
	info->description = u.sysname;
#endif

	if ((ver = strtok(u.release, ".-")) != NULL)
	{
		info->majorversion = atoi(ver);
		// continue parsing from the previous position
		if ((ver = strtok(NULL, ".-")) != NULL)
		{
			info->minorversion = atoi(ver);
			if ((ver = strtok(NULL, ".-")) != NULL)
				info->revision = atoi(ver);
		}
	}
}

/*************************************************************/

#else

void getversion(struct OsVersionInfo* info)
{
	info->majorversion = 0;
	info->minorversion = 0;
	info->revision = 0;
	info->description = PLATFORM_STRING;
}

#endif

