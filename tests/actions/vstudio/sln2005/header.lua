--
-- tests/actions/vstudio/sln2005/header.lua
-- Validate generation of Visual Studio 2005+ solution header.
-- Copyright (c) 2009-2011 Jason Perkins and the Premake project
--

	T.vstudio_sln2005_header = { }
	local suite = T.vstudio_sln2005_header
	local sln2005 = premake.vstudio.sln2005


--
-- Setup
--

	local sln, prj

	function suite.setup()
		sln = test.createsolution()
	end

	local function prepare()
		premake.bake.buildconfigs()
		sln2005.header()
	end


--
-- Tests
--

	function suite.On2005()
		_ACTION = "vs2005"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 9.00
# Visual Studio 2005
		]]
	end


	function suite.On2008()
		_ACTION = "vs2008"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 10.00
# Visual Studio 2008
		]]
	end


	function suite.On2010()
		_ACTION = "vs2010"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 11.00
# Visual Studio 2010
		]]
	end


	function suite.On2012()
		_ACTION = "vs2012"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio 2012
		]]
	end


	function suite.On2013()
		_ACTION = "vs2013"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio 2013
		]]
--[[
VS 2013 seems to add something like:

VisualStudioVersion = 12.0.31101.0
MinimumVisualStudioVersion = 10.0.40219.1

which don't seem to be mandatory, though.
]]
	end

	function suite.On2015()
		_ACTION = "vs2015"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio 14
		]]
--[[
VS 2015 seems to add something like:

VisualStudioVersion = 14.0.23107.0
MinimumVisualStudioVersion = 10.0.40219.1

which don't seem to be mandatory, though.
]]
	end

	function suite.On2017()
		_ACTION = "vs2017"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio 15
		]]
--[[
VS 2017 seems to add something like:

VisualStudioVersion = 15.0.26228.4
MinimumVisualStudioVersion = 10.0.40219.1

which don't seem to be mandatory, though.
]]
	end

	function suite.On2019()
		_ACTION = "vs2019"
		prepare()
		test.capture [[
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio 16
		]]
--[[
VS 2019 seems to add something like:

VisualStudioVersion = 16.0.29411.108
MinimumVisualStudioVersion = 10.0.40219.1

which don't seem to be mandatory, though.
]]
	end
