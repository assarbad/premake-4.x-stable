--
-- vs2002_solution.lua
-- Generate a Visual Studio 2002 solution.
-- Copyright (c) 2009 Jason Perkins and the Premake project
--

	function premake.vs2002_solution(sln)
		io.eol = '\r\n'

		-- Precompute Visual Studio configurations
		sln.vstudio_configs = premake.vstudio_buildconfigs(sln)

		_p('Microsoft Visual Studio Solution File, Format Version 7.00')
		
		-- Write out the list of project entries
		for prj in premake.eachproject(sln) do
			local projpath = path.translate(path.getrelative(sln.location, _VS.projectfile(prj)))
			_p('Project("{%s}") = "%s", "%s", "{%s}"', _VS.tool(prj), prj.name, projpath, prj.uuid)
			_p('EndProject')
		end

		_p('Global')
		_p('\tGlobalSection(SolutionConfiguration) = preSolution')
		for i, cfgname in ipairs(sln.configurations) do
			_p('\t\tConfigName.%d = %s', i - 1, cfgname)
		end
		_p('\tEndGlobalSection')

		_p('\tGlobalSection(ProjectDependencies) = postSolution')
		_p('\tEndGlobalSection')
		
		_p('\tGlobalSection(ProjectConfiguration) = postSolution')
		for prj in premake.eachproject(sln) do
			for _, cfgname in ipairs(sln.configurations) do
				_p('\t\t{%s}.%s.ActiveCfg = %s|%s', prj.uuid, cfgname, cfgname, _VS.arch(prj))
				_p('\t\t{%s}.%s.Build.0 = %s|%s', prj.uuid, cfgname, cfgname, _VS.arch(prj))
			end
		end
		_p('\tEndGlobalSection')
		_p('\tGlobalSection(ExtensibilityGlobals) = postSolution')
		_p('\tEndGlobalSection')
		_p('\tGlobalSection(ExtensibilityAddIns) = postSolution')
		_p('\tEndGlobalSection')
		
		_p('EndGlobal')
	end
	