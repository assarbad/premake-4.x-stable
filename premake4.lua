--[[
        This premake4.lua _requires_ windirstat/premake-stable to work properly.
        If you don't want to use the code-signed build that can be found in the
        ./common/ subfolder, you can build from the WDS-branch over at:

        https://sourceforge.net/projects/windirstat/

        Prebuilt, signed binaries are available from:
          https://github.com/windirstat/premake-stable
          https://sourceforge.net/projects/windirstat/files/premake-stable/
          https://osdn.net/projects/windirstat/storage/historical/premake-stable/
  ]]
local action = _ACTION or ""
if _OPTIONS["publish"] then
    print "INFO: Creating 'Publish' build solution."
    publish = true
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

--[[
    This part of the premake4.lua modifies the core premake4 behavior a little.

    It does the following (in order of appearence below):

    - New option --sdkver to override <WindowsTargetPlatformVersion> on modern VS
    - New option --clang to request ClangCL toolset on modern VS
    - New option --xp to request XP-compatible toolset on modern VS
    - On older premake4 versions it will provide a premake.project.getbasename
      function, furthermore two other functions get patched to make use of it
    - premake.project.getbasename() gets overridden to insert a marker into the
      created file name, based on the chosen action
      Example: foobar.vcxproj becomes foobar.vs2022.vcxproj etc ...
      The purpose of this exercise is to allow for projects/solutions of several
      Visual Studio versions to reside in the same folder
    - Options "dotnet" gets removed
    - The "platform" option has some allowed values removed
    - The "os" option has some allowed values removed
    - The actions are trimmed to what we know can work
]]

newoption { trigger = "sdkver", value = "SDKVER", description = "Allows to override SDK version (VS2015 through VS2022)" }
newoption { trigger = "clang", description = "Allows to use clang-cl as compiler and lld-link as linker (VS2019 and VS2022)" }
newoption { trigger = "xp", description = "Allows to use a supported XP toolset for some VS versions" }

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
                        _p(1,"<ItemGroup>")
                    end

                    path = path .. folders[i]

                    -- have I seen this path before?
                    if not filters[path] then
                        local seed = path .. (prj.uuid or "")
                        local deterministic_uuid = os.str2uuid(seed)
                        filters[path] = true
                        _p(2, '<Filter Include="%s">', path)
                        _p(3, "<UniqueIdentifier>{%s}</UniqueIdentifier>", deterministic_uuid)
                        _p(2, "</Filter>")
                    end

                    -- prepare for the next subfolder
                    path = path .. "\\"
                end
            end

            if filterfound then
                _p(1,"</ItemGroup>")
            end
        end
    end
    -- Name the project files after their VS version
    local orig_getbasename = premake.project.getbasename
    premake.project.getbasename = function(prjname, pattern)
        -- The below is used to insert the .vs(8|9|10|11|12|14|15|16|17) into the file names for projects and solutions
        if _ACTION then
            name_map = {vs2005 = "vs8", vs2008 = "vs9", vs2010 = "vs10", vs2012 = "vs11", vs2013 = "vs12", vs2015 = "vs14", vs2017 = "vs15", vs2019 = "vs16", vs2022 = "vs17"}
            if name_map[_ACTION] then
                pattern = pattern:gsub("%%%%", "%%%%." .. name_map[_ACTION])
            else
                pattern = pattern:gsub("%%%%", "%%%%." .. _ACTION)
            end
        end
        return orig_getbasename(prjname, pattern)
    end
    -- Premake4 sets the PDB file name for the compiler's PDB to the default
    -- value used by the linker's PDB. This causes error C1052 on VS2017. Fix it.
    -- But this also fixes up certain other areas of the generated project. The idea
    -- here is to catch the original _p() invocations, evaluate the arguments and
    -- then act based on those, using orig_p() as a standin during a call to the
    -- underlying premake.vs2010_vcxproj() function ;-)
    local orig_premake_vs2010_vcxproj = premake.vs2010_vcxproj
    premake.vs2010_vcxproj = function(prj)
        -- The whole stunt below is necessary in order to modify the resource_compile()
        -- output. Given it's a local function we have to go through hoops.
        local orig_p = _G._p
        local besilent = false
        -- We patch the global _p() function
        _G._p = function(indent, msg, first, ...)
            -- Look for non-empty messages and narrow it down by the indent values
            if msg ~= nil then
                if msg:match("<ProgramDataBaseFileName>[^<]+</ProgramDataBaseFileName>") then
                    return -- we want to suppress these
                end
                if indent == 2 then
                    if msg == '<ClCompile Include=\"%s\">' and first == "delayload-stubs\\ntdll-delayed-stubs.c" then
                        orig_p(indent, msg, first, ...) -- what was originally supposed to be output
                        orig_p(indent+1, "<ExcludedFromBuild>true</ExcludedFromBuild>")
                        return
                    end
                    if msg == "<RootNamespace>%s</RootNamespace>" then
                        local sdkmap = {vs2015 = "8.1", vs2017 = "10.0.17763.0", vs2019 = "10.0", vs2022 = "10.0"}
                        if (not _ACTION) or (not sdkmap[_ACTION]) then -- should not happen, but tread carefully anyway
                            orig_p(indent, msg, first, ...) -- what was originally supposed to be output
                            return
                        end
                        local sdkver = _OPTIONS["sdkver"] or sdkmap[_ACTION]
                        orig_p(indent, msg, first, ...) -- what was originally supposed to be output
                        orig_p(indent, "<WindowsTargetPlatformVersion>%s</WindowsTargetPlatformVersion>", sdkver)
                        return
                    end
                    if msg == "<PlatformToolset>%s</PlatformToolset>" then
                        if (_OPTIONS["clang"] ~= nil) and (_ACTION == "vs2017") then
                            if _OPTIONS["xp"] ~= nil then
                                print "WARNING: The --clang option takes precedence over --xp, therefore picking v141_clang_c2 toolset."
                            end
                            print "WARNING: If you are used to Clang support from VS2019 and newer, be sure to review your choice. It's not the same on older VS versions."
                            orig_p(indent, msg, "v141_clang_c2")
                            return
                        elseif (_OPTIONS["clang"] ~= nil) and (_ACTION >= "vs2019") then
                            if _OPTIONS["xp"] ~= nil then
                                print "WARNING: The --clang option takes precedence over --xp, therefore picking ClangCL toolset."
                            end
                            orig_p(indent, msg, "ClangCL")
                            return
                        elseif _OPTIONS["xp"] ~= nil then
                            local toolsets = { vs2012 = "v110", vs2013 = "v120", vs2015 = "v140", vs2017 = "v141", vs2019 = "v142", vs2022 = "v143" }
                            local toolset = toolsets[_ACTION]
                            if toolset then
                                if _OPTIONS["xp"] and toolset >= "v141" then
                                    toolset = "v141" -- everything falls back to the VS2017 XP toolset for more recent VS
                                end
                                orig_p(indent,"<PlatformToolset>%s_xp</PlatformToolset>", toolset)
                                return
                            end
                        end
                    end
                elseif indent == 3 then
                    -- This is what vanilla VS would output it as, so let's try to align with that
                    if msg == "<PrecompiledHeader></PrecompiledHeader>" then
                        orig_p(indent, "<PrecompiledHeader>")
                        orig_p(indent, "</PrecompiledHeader>")
                        return
                    end
                end
            end
            if not besilent then -- should we be silent (i.e. suppress default output)?
                orig_p(indent, msg, first, ...)
            end
        end
        orig_premake_vs2010_vcxproj(prj)
        _G._p = orig_p -- restore in any case
    end
    -- ... same as above but for VS200x this time
    local function wrap_remove_pdb_attribute(origfunc)
        local fct = function(cfg)
            local old_captured = io.captured -- save io.captured state
            io.capture() -- this sets io.captured = ""
            origfunc(cfg)
            local captured = io.endcapture()
            assert(captured ~= nil)
            captured = captured:gsub('%s+ProgramDataBaseFileName=\"[^"]+\"', "")
            if old_captured ~= nil then
                io.captured = old_captured .. captured -- restore outer captured state, if any
            else
                io.write(captured)
            end
        end
        return fct
    end
    premake.vstudio.vc200x.VCLinkerTool = wrap_remove_pdb_attribute(premake.vstudio.vc200x.VCLinkerTool)
    premake.vstudio.vc200x.toolmap.VCLinkerTool = premake.vstudio.vc200x.VCLinkerTool -- this is important as well
    premake.vstudio.vc200x.VCCLCompilerTool = wrap_remove_pdb_attribute(premake.vstudio.vc200x.VCCLCompilerTool)
    premake.vstudio.vc200x.toolmap.VCCLCompilerTool = premake.vstudio.vc200x.VCCLCompilerTool -- this is important as well
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
        if filename:find(".vcproj.user") or filename:find(".vcxproj.user") then
            return
        end
        orig_generate(obj, filename, callback)
    end
    -- Fix up premake.getlinks() to not do stupid stuff with object files we pass
    local orig_premake_getlinks = premake.getlinks
    premake.getlinks = function(cfg, kind, part)
        local origret = orig_premake_getlinks(cfg, kind, part)
        local ret = {}
        for k,v in ipairs(origret) do
            local dep = v:gsub(".obj.lib", ".obj")
            dep = dep:gsub(".lib.lib", ".lib")
            table.insert(ret, dep)
        end
        return ret
    end

    -- Remove an option altogether or some otherwise accepted values for that option
    local function remove_allowed_optionvalues(option, values_toremove)
        if premake.option.list[option] ~= nil then
            if values_toremove == nil then
                premake.option.list[option] = nil
                return
            end
            if premake.option.list.platform["allowed"] ~= nil then
                local allowed = premake.option.list[option].allowed
                for i = #allowed, 1, -1 do
                    if values_toremove[allowed[i][1]] then
                        table.remove(allowed, i)
                    end
                end
            end
        end
    end

    local function remove_action(action)
        if premake.action.list[action] ~= nil then
            premake.action.list[action] = nil
        end
    end

    -- Remove some unwanted/outdated options
    remove_allowed_optionvalues("dotnet")
    remove_allowed_optionvalues("platform", { universal = 0, universal32 = 0, universal64 = 0, ps3 = 0, xbox360 = 0, })
    remove_allowed_optionvalues("os") -- ... , { bsd = 0, haiku = 0, linux = 0, macosx = 0, solaris = 0, }
    remove_allowed_optionvalues("cc")
    -- ... and actions (mainly because they are untested)
    for k,v in pairs({codeblocks = 0, codelite = 0, xcode3 = 0, xcode4 = 0, vs2002 = 0, vs2003 = 0, }) do -- vs2005 = 0, vs2008 = 0, vs2010 = 0, vs2012 = 0, vs2013 = 0
        remove_action(k)
    end
end
