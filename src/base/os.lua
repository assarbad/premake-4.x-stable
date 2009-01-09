--
-- os.lua
-- Additions to the OS namespace.
-- Copyright (c) 2002-2008 Jason Perkins and the Premake project
--


--
-- Scan the well-known system locations for a particular library.
--

	function os.findlib(libname)
		local path, formats
		
		-- assemble a search path, depending on the platform
		if os.is("windows") then
			formats = { "%s.dll", "%s" }
			path = os.getenv("PATH")
		else
			if os.is("macosx") then
				formats = { "lib%s.dylib", "%s.dylib" }
				path = os.getenv("DYLD_LIBRARY_PATH")
			else
				formats = { "lib%s.so", "%s.so" }
				path = os.getenv("LD_LIBRARY_PATH") or ""
		
				local f = io.open("/etc/ld.so.conf", "r")
				if f then
					for line in f:lines() do
						path = path .. ":" .. line
					end
					f:close()
				end
			end
			
			table.insert(formats, "%s")	
			path = (path or "") .. ":/lib:/usr/lib:/usr/local/lib"
		end
		
		for _, fmt in ipairs(formats) do
			local name = string.format(fmt, libname)
			local result = os.pathsearch(name, path)
			if result then return result end
		end
	end
	
	
	
--
-- Retrieve the current operating system ID string.
--

	function os.get()
		return _OPTIONS.os or _OS
	end
	

	
--
-- Check the current operating system; may be set with the /os command line flag.
--

	function os.is(id)
		return (os.get():lower() == id:lower())
	end
	
	

--
-- The os.matchdirs() and os.matchfiles() functions
--

	local function domatch(result, mask, wantfiles)
		local basedir = path.getdirectory(mask)
		if (basedir == ".") then basedir = "" end
		
		local m = os.matchstart(mask)
		while (os.matchnext(m)) do
			local fname = os.matchname(m)
			local isfile = os.matchisfile(m)
			if ((wantfiles and isfile) or (not wantfiles and not isfile)) then
				table.insert(result, path.join(basedir, fname))
			end
		end
		os.matchdone(m)

		-- if the mask uses "**", recurse subdirectories
		if (mask:find("**", nil, true)) then
			mask = path.getname(mask)			
			m = os.matchstart(path.join(basedir, "*"))
			while (os.matchnext(m)) do
				local dirname = os.matchname(m)
				local submask = path.join(path.join(basedir, dirname), mask)
				domatch(result, submask, wantfiles)
			end
			os.matchdone(m)
		end
	end
	
	function os.matchdirs(...)
		local result = { }
		for _, mask in ipairs(arg) do
			domatch(result, mask, false)
		end
		return result
	end
	
	function os.matchfiles(...)
		local result = { }
		for _, mask in ipairs(arg) do
			domatch(result, mask, true)
		end
		return result
	end
	
	
	
--
-- An overload of the os.mkdir() function, which will create any missing
-- subdirectories along the path.
--

	local builtin_mkdir = os.mkdir
	function os.mkdir(p)
		local dir = iif(p:startswith("/"), "/", "")
		for part in p:gmatch("[^/]+") do
			dir = dir .. part
			
			if (part ~= "" and not path.isabsolute(part) and not os.isdir(dir)) then
				local ok, err = builtin_mkdir(dir)
				if (not ok) then
					return nil, err
				end
			end
						
			dir = dir .. "/"
		end
		
		return true
	end


--
-- Remove a directory, along with any contained files or subdirectories.
--

	local builtin_rmdir = os.rmdir
	function os.rmdir(p)
		-- recursively remove subdirectories
		local dirs = os.matchdirs(p .. "/*")
		for _, dname in ipairs(dirs) do
			os.rmdir(dname)
		end

		-- remove any files
		local files = os.matchfiles(p .. "/*")
		for _, fname in ipairs(files) do
			os.remove(fname)
		end
				
		-- remove this directory
		builtin_rmdir(p)
	end
	
