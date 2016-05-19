--[[
        This premake4.lua _requires_ windirstat/premake-stable to work properly.
        If you don't want to use the code-signed build that can be found in the
        download section of that project, you can build from the WDS-branch at:

        https://bitbucket.org/windirstat/premake-stable
--]]
local action = _ACTION or ""
if _OPTIONS["publish"] then
    print "INFO: Creating 'Publish' build solution."
    publish = true
end
do
	-- This is mainly to support older premake4 builds
	if not premake.project.getbasename then
		print "Magic happens ..."
		-- override the function to establish the behavior we'd get after patching Premake to have premake.project.getbasename
		premake.project.getbasename = function(prjname, pattern)
			return pattern:gsub("%%%%", prjname)
		end
		-- obviously we also need to overwrite the following to generate functioning VS solution files
		premake.vstudio.projectfile = function(prj)
			local pattern
			if prj.language == "C#" then
				pattern = "%%.csproj"
			else
				pattern = iif(_ACTION > "vs2008", "%%.vcxproj", "%%.vcproj")
			end

			local fname = premake.project.getbasename(prj.name, pattern)
			fname = path.join(prj.location, fname)
			return fname
		end
		-- we simply overwrite the original function on older Premake versions
		premake.project.getfilename = function(prj, pattern)
			local fname = premake.project.getbasename(prj.name, pattern)
			fname = path.join(prj.location, fname)
			return path.getrelative(os.getcwd(), fname)
		end
	end
	-- Name the project files after their VS version
	local orig_getbasename = premake.project.getbasename
	premake.project.getbasename = function(prjname, pattern)
		-- The below is used to insert the .vs(8|9|10|11|12|14) into the file names for projects and solutions
		if _ACTION then
			name_map = {vs2005 = "vs8", vs2008 = "vs9", vs2010 = "vs10", vs2012 = "vs11", vs2013 = "vs12", vs2015 = "vs14"}
			if name_map[_ACTION] then
				pattern = pattern:gsub("%%%%", "%%%%." .. name_map[_ACTION])
			else
				pattern = pattern:gsub("%%%%", "%%%%." .. _ACTION)
			end
		end
		return orig_getbasename(prjname, pattern)
	end
	-- Override the object directory paths ... don't make them "unique" inside premake4
	local orig_gettarget = premake.gettarget
	premake.gettarget = function(cfg, direction, pathstyle, namestyle, system)
		local r = orig_gettarget(cfg, direction, pathstyle, namestyle, system)
		if (cfg.objectsdir) and (cfg.objdir) then
			cfg.objectsdir = cfg.objdir
		end
		return r
	end
	-- Silently suppress generation of the .user files ...
	local orig_generate = premake.generate
	premake.generate = function(obj, filename, callback)
		if filename:find('.vcproj.user') or filename:find('.vcxproj.user') then
			return
		end
		orig_generate(obj, filename, callback)
	end
end
local function transformMN(input) -- transform the macro names for older Visual Studio versions
	local new_map   = { vs2002 = 0, vs2003 = 0, vs2005 = 0, vs2008 = 0 }
	local replacements = { Platform = "PlatformName", Configuration = "ConfigurationName" }
	if new_map[action] ~= nil then
		for k,v in pairs(replacements) do
			if input:find(k) then
				input = input:gsub(k, v)
			end
		end
	end
	return input
end
--
-- Define the project. Put the release configuration first so it will be the
-- default when folks build using the makefile. That way they don't have to
-- worry about the /scripts argument and all that.
--

solution "Premake4"
	configurations { "Release", "Debug", "Publish" }
	location ( _OPTIONS["to"] )

	project "Premake4"
		local int_dir   = "intermediate/" .. action .. "_$(" .. transformMN("Platform") .. ")_$(" .. transformMN("Configuration") .. ")"
		uuid        "7F000221-EACC-2F4F-A07F-6A5D34AF10D0"
		targetname  "premake4"
		language    "C"
		kind        "ConsoleApp"
		objdir      (int_dir)
		flags       { "No64BitChecks", "ExtraWarnings", "StaticRuntime" }
		includedirs { "src/host/lua-5.1.4/src" }

		files
		{
			"*.txt", "**.lua",
			"src/**.h", "src/**.c",
			"src/host/scripts.c"
		}

		excludes
		{
			"src/premake.lua",
			"src/host/lua-5.1.4/src/lua.c",
			"src/host/lua-5.1.4/src/luac.c",
			"src/host/lua-5.1.4/src/print.c",
			"src/host/lua-5.1.4/**.lua",
			"src/host/lua-5.1.4/etc/*.c",
			"src/host/hgtip.h",
			"packages/**",
			"samples/**",
			"tests/**",
		}

		configuration "Debug"
			targetdir   "bin/debug"
			defines     "_DEBUG"
			flags       { "Symbols" }

		configuration "Release or Publish"
			targetdir   "bin/release"
			defines     "NDEBUG"
			flags       { "OptimizeSize" }

		configuration "vs*"
			defines     { "_CRT_SECURE_NO_WARNINGS" }

		configuration "vs2005"
			defines     {"_CRT_SECURE_NO_DEPRECATE" }

		configuration "windows"
			links       { "ole32" }
			files       { "src/host/premake4.rc" }

		configuration {"windows", "Publish"}
			postbuildcommands { 'ollisign.cmd -a "$(TargetPath)" "https://bitbucket.org/windirstat/premake-stable" "premake4"' }
			defines     { "HAVE_HGTIP", "PREMAKE_VERSION=4.4-wds"}

		configuration "linux or bsd"
			defines     { "LUA_USE_POSIX", "LUA_USE_DLOPEN" }
			links       { "m" }
			linkoptions { "-rdynamic" }

		configuration "linux"
			links       { "dl" }

		configuration "macosx"
			defines     { "LUA_USE_MACOSX" }
			links       { "CoreServices.framework" }

		configuration { "macosx", "gmake" }
			buildoptions { "-mmacosx-version-min=10.4" }
			linkoptions  { "-mmacosx-version-min=10.4" }

		configuration { "solaris" }
			linkoptions { "-Wl,--export-dynamic" }



--
-- A more thorough cleanup.
--

	if _ACTION == "clean" then
		os.rmdir("bin")
		os.rmdir("build")
	end



--
-- Use the --to=path option to control where the project files get generated. I use
-- this to create project files for each supported toolset, each in their own folder,
-- in preparation for deployment.
--

	newoption {
		trigger = "to",
		value   = "path",
		description = "Set the output location for the generated files"
	}



--
-- Use the embed action to convert all of the Lua scripts into C strings, which
-- can then be built into the executable. Always embed the scripts before creating
-- a release build.
--

	dofile("scripts/embed.lua")

	newaction {
		trigger     = "embed",
		description = "Embed scripts in scripts.c; required before release builds",
		execute     = doembed
	}


--
-- Use the release action to prepare source and binary packages for a new release.
-- This action isn't complete yet; a release still requires some manual work.
--


	dofile("scripts/release.lua")

	newaction {
		trigger     = "release",
		description = "Prepare a new release (incomplete)",
		execute     = dorelease
	}
