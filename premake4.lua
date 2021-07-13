--[[
		This premake4.lua _requires_ windirstat/premake-stable to work properly.
		If you don't want to use the code-signed build that can be found in the
		download section of that project, you can build from the WDS-branch at:

		https://sourceforge.net/projects/premake4-wds/
--]]
local action = _ACTION or ""
if _OPTIONS["publish"] then
	print "INFO: Creating 'Publish' build solution."
	publish = true
end
do
	-- This is mainly to support older premake4 builds
	if not premake.project.getbasename then
		print "Magic happens for old premake4 versions without premake.project.getbasename() ..."
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
	-- This is mainly to support older premake4 in which CompileAs did not work
	-- for VS2010 and newer
	if not premake.vstudio.vc2010.individualSourceFile or not premake.vstudio.vc200x.individualSourceFile then
		local vc2010 = premake.vstudio.vc2010
		local vc200x = premake.vstudio.vc200x
		local tree = premake.tree
		print "Magic happens for old premake4 versions faulty CompileAs handling for VS2010 and newer ..."
		-- A boilerplate implementation
		vc200x.individualSourceFile = function(prj, depth, fname, node)
			-- handle file configuration stuff. This needs to be cleaned up and simplified.
			-- configurations are cached, so this isn't as bad as it looks
			for _, cfginfo in ipairs(prj.solution.vstudio_configs) do
				if cfginfo.isreal then
					local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)

					local usePCH = (not prj.flags.NoPCH and prj.pchsource == node.cfg.name)
					local isSourceCode = path.iscppfile(fname)
					local needsCompileAs = (path.iscfile(fname) ~= premake.project.iscproject(prj))

					if usePCH or (isSourceCode and needsCompileAs) then
						_p(depth, '<FileConfiguration')
						_p(depth, '\tName="%s"', cfginfo.name)
						_p(depth, '\t>')
						_p(depth, '\t<Tool')
						_p(depth, '\t\tName="%s"', iif(cfg.system == "Xbox360",
														"VCCLX360CompilerTool",
														"VCCLCompilerTool"))
						if needsCompileAs then
							_p(depth, '\t\tCompileAs="%s"', iif(path.iscfile(fname), 1, 2))
						end

						if usePCH then
							if cfg.system == "PS3" then
								local options = table.join(premake.snc.getcflags(cfg),
															premake.snc.getcxxflags(cfg),
															cfg.buildoptions)
								options = table.concat(options, " ");
								options = options .. ' --create_pch="$(IntDir)/$(TargetName).pch"'
								_p(depth, '\t\tAdditionalOptions="%s"', premake.esc(options))
							else
								_p(depth, '\t\tUsePrecompiledHeader="1"')
							end
						end

						_p(depth, '\t/>')
						_p(depth, '</FileConfiguration>')
					end

				end
			end
		end
		vc200x.Files = function(prj)
			local tr = premake.project.buildsourcetree(prj)

			tree.traverse(tr, {
				-- folders are handled at the internal nodes
				onbranchenter = function(node, depth)
					_p(depth, '<Filter')
					_p(depth, '\tName="%s"', node.name)
					_p(depth, '\tFilter=""')
					_p(depth, '\t>')
				end,

				onbranchexit = function(node, depth)
					_p(depth, '</Filter>')
				end,

				-- source files are handled at the leaves
				onleaf = function(node, depth)
					local fname = node.cfg.name

					_p(depth, '<File')
					_p(depth, '\tRelativePath="%s"', path.translate(fname, "\\"))
					_p(depth, '\t>')
					depth = depth + 1

					vc200x.individualSourceFile(prj, depth, fname, node)

					depth = depth - 1
					_p(depth, '</File>')
				end,
			}, false, 2)

		end
		-- A boilerplate implementation
		vc2010.individualSourceFile = function(prj, config_mappings, file)
			local configs = prj.solution.vstudio_configs
			local translatedpath = path.translate(file.name, "\\")
			_p(2,'<ClCompile Include=\"%s\">', translatedpath)
			for _, cfginfo in ipairs(configs) do
				if config_mappings[cfginfo] and translatedpath == config_mappings[cfginfo] then
					_p(3,'<PrecompiledHeader '.. if_config_and_platform() .. '>Create</PrecompiledHeader>', premake.esc(cfginfo.name))
					config_mappings[cfginfo] = nil  --only one source file per pch
				end
			end
			if path.iscfile(file.name) ~= premake.project.iscproject(prj) then
				_p(3,'<CompileAs>%s</CompileAs>', iif(path.iscfile(file.name), 'CompileAsC', 'CompileAsCpp'))
			end
			_p(2,'</ClCompile>')
		end
		-- Overriding the function which calls the above
		vc2010.compilerfilesgroup = function(prj)
			local configs = prj.solution.vstudio_configs
			local files = vc2010.getfilegroup(prj, "ClCompile")
			if #files > 0  then
				local config_mappings = {}
				for _, cfginfo in ipairs(configs) do
					local cfg = premake.getconfig(prj, cfginfo.src_buildcfg, cfginfo.src_platform)
					if cfg.pchheader and cfg.pchsource and not cfg.flags.NoPCH then
						config_mappings[cfginfo] = path.translate(cfg.pchsource, "\\")
					end
				end

				_p(1,'<ItemGroup>')
				for _, file in ipairs(files) do
					vc2010.individualSourceFile(prj, config_mappings, file)
				end
				_p(1,'</ItemGroup>')
			end
		end
	end
	-- Make UUID generation for filters deterministic
	if os.str2uuid ~= nil then
		local vc2010 = premake.vstudio.vc2010
		vc2010.filteridgroup = function(prj)
			local filters = { }
			local filterfound = false

			for file in premake.project.eachfile(prj) do
				-- split the path into its component parts
				local folders = string.explode(file.vpath, "/", true)
				local path = ""
				for i = 1, #folders - 1 do
					-- element is only written if there *are* filters
					if not filterfound then
						filterfound = true
						_p(1,'<ItemGroup>')
					end
					
					path = path .. folders[i]

					-- have I seen this path before?
					if not filters[path] then
						local seed = path .. (prj.uuid or "")
						local deterministic_uuid = os.str2uuid(seed)
						filters[path] = true
						_p(2, '<Filter Include="%s">', path)
						_p(3, '<UniqueIdentifier>{%s}</UniqueIdentifier>', deterministic_uuid)
						_p(2, '</Filter>')
					end

					-- prepare for the next subfolder
					path = path .. "\\"
				end
			end
			
			if filterfound then
				_p(1,'</ItemGroup>')
			end
		end
	end
	-- Name the project files after their VS version
	local orig_getbasename = premake.project.getbasename
	premake.project.getbasename = function(prjname, pattern)
		-- The below is used to insert the .vs(8|9|10|11|12|14|15) into the file names for projects and solutions
		if _ACTION then
			name_map = {vs2002 = "vs7", vs2003 = "vs7_1", vs2005 = "vs8", vs2008 = "vs9", vs2010 = "vs10", vs2012 = "vs11", vs2013 = "vs12", vs2015 = "vs14", vs2017 = "vs15", vs2019 = "vs16"}
			if name_map[_ACTION] then
				pattern = pattern:gsub("%%%%", "%%%%." .. name_map[_ACTION])
			else
				pattern = pattern:gsub("%%%%", "%%%%." .. _ACTION)
			end
		end
		return orig_getbasename(prjname, pattern)
	end
	-- Older versions of Premake4 fail to set the proper entry point, although they could simply let it out entirely ...
	local orig_vc2010_link = premake.vstudio.vc2010.link
	premake.vstudio.vc2010.link = function(cfg)
		if cfg.flags and cfg.flags.Unicode then
			io.capture()
			orig_vc2010_link(cfg)
			local captured = io.endcapture()
			captured = captured:gsub("(<EntryPointSymbol>)(mainCRTStartup)", "%1w%2")
			io.write(captured)
		else
			orig_vc2010_link(cfg)
		end
	end
	local orig_vc200x_VCLinkerTool = premake.vstudio.vc200x.VCLinkerTool
	premake.vstudio.vc200x.VCLinkerTool = function(cfg)
		if cfg.flags and cfg.flags.Unicode then
			io.capture()
			orig_vc200x_VCLinkerTool(cfg)
			local captured = io.endcapture()
			captured = captured:gsub('(EntryPointSymbol=")(mainCRTStartup)', "%1w%2")
			io.write(captured)
		else
			orig_vc200x_VCLinkerTool(cfg)
		end
	end
	premake.vstudio.vc200x.toolmap.VCLinkerTool = premake.vstudio.vc200x.VCLinkerTool
	-- Make sure we can generate XP-compatible projects for newer Visual Studio versions
	local orig_vc2010_configurationPropertyGroup = premake.vstudio.vc2010.configurationPropertyGroup
	premake.vstudio.vc2010.configurationPropertyGroup = function(cfg, cfginfo)
		io.capture()
		orig_vc2010_configurationPropertyGroup(cfg, cfginfo)
		local captured = io.endcapture()
		local toolsets = { vs2012 = "v110", vs2013 = "v120", vs2015 = "v140", vs2017 = "v141" }
		local toolset = toolsets[_ACTION]
		if toolset then
			if _OPTIONS["xp"] then
				toolset = toolset .. "_xp"
				captured = captured:gsub("(</PlatformToolset>)", "_xp%1")
			end
		end
		io.write(captured)
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
	-- We want to output the file with UTF-8 BOM
	local orig_vc2010_header = premake.vstudio.vc2010.header
	premake.vstudio.vc2010.header = function(targets)
		io.capture()
		orig_vc2010_header(targets)
		local captured = io.endcapture()
		io.write("\239\187\191")
		io.write(captured)
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
		defines     { "USE_KECCAK" }

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
			postbuildcommands { 'ollisign.cmd -2 "$(TargetPath)" "https://sourceforge.net/projects/premake4-wds/" "premake4"' }
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
	newoption {
		trigger = "xp",
		description = "Enable XP-compatible build for newer Visual Studio versions."
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
