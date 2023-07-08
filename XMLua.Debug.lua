local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML and XML:GetMetadata();

if not XML or Metadata.Loaded then return end;
local Props, tostring, pairs = Metadata.Element, tostring, pairs;
-------------------------------------------------------
-- Debug cache
-------------------------------------------------------
local Cache = setmetatable({
	timeUpdated = 0;
}, {__index = {
	['table'] = {};
	--['string'] = {};
	['userdata'] = {};
	['function'] = {};
}})

do
	local function getSeparationCount(str)
		return (select(2, gsub(str, '%.', '.')))
	end

	local baseCacheFunction = {__call = function(self, k, v, prefix)
		if not (self[v]) then
			self[v] = prefix and prefix .. '.' .. tostring(k) or tostring(k)
		end
	end};

	setmetatable(Cache.table, {__call = function(self, k, v, prefix)
		if not (self[v]) then
			local name = prefix and prefix .. '.' .. tostring(k) or tostring(k)
			self[v] = name;
			for sK, sV in pairs(v) do
				local cache = Cache[type(sV)]
				if cache then
					cache(sK, sV, name)
				end
			end
			return
		end
		if prefix and getSeparationCount(prefix) < getSeparationCount(self[v]) then
			self[v] = prefix .. '.' .. tostring(k)
		end
	end})

	--[[setmetatable(Cache.string, {__call = function(self, k, v, prefix)
		if prefix then return end;
		if not (self[v]) then
			self[v] = prefix and prefix .. '.' .. tostring(k) or tostring(k)
		end
	end})]]

	setmetatable(Cache.userdata, baseCacheFunction)
	setmetatable(Cache['function'], baseCacheFunction)

	function Cache:Update()
		local newUpdate = GetTime()
		if newUpdate <= self.timeUpdated then return end;
		print('caching...')
		for k, v in pairs(getfenv(0)) do
			local cache = self[type(v)]
			if cache then
				cache(k, v)
			end
		end
		self.timeUpdated = newUpdate;
		C_Timer.After(0, function()
			print('wiping...')
			self:Wipe()
		end)
	end

	function Cache:Wipe()
		for _, cache in pairs(getmetatable(self).__index) do
			wipe(cache)
		end
		collectgarbage()
	end
end

-------------------------------------------------------
-- Printers
-------------------------------------------------------
Props.Print = function(value)
	if C_Widget.IsWidget(value) then
		return value:GetDebugName()
	elseif not tostring(value):match('%b<>') then
		local typeCache = Cache[type(value)]
		if typeCache then
			Cache:Update()
			local name = typeCache[value];
			if name then
				return name, true;
			end
		end
	end
	return tostring(value)
end

Props.GetDebugName = function()
	-- returns the file and line number where the element was created
	return debugstack(3, 1, 1):gsub('^%[[^@]+@([^"]+)"]:(%d+):.*', '%1:%2')
end

do
	local PrintTypes = {
		boolean = function(value) return ORANGE_FONT_COLOR:WrapTextInColorCode(tostring(value)) end;
		number  = function(value) return ORANGE_FONT_COLOR:WrapTextInColorCode(tostring(value)) end;
		string  = function(value) return LIGHTBLUE_FONT_COLOR:WrapTextInColorCode(('%q'):format(value)) end;
	};

	local function printValue(value)
		local printValue, isCached = Props.Print(value)
		if isCached then
			return printValue
		end
		local printer = PrintTypes[type(value)];
		if printer then
			return printer(value)
		end
		return printValue
	end
	local function printNamespace(_, entry)
		local method = entry[1];
		local values = {};
		for i=2, #entry do
			values[#values + 1] = printValue(entry[i])
		end
		return ('  :%s(%s)'):format(
			BLUE_FONT_COLOR:WrapTextInColorCode(method),
			WHITE_FONT_COLOR:WrapTextInColorCode(table.concat(values, ', '))
		)
	end
	Props.PrintNamespace = function(namespace)
		if next(namespace) then
			local output = {};
			for _, entry in ipairs(namespace) do
				output[#output + 1] = printNamespace(_, entry)
			end
			return '\n' .. table.concat(output, '\n') .. '\n'
		end
		return '';
	end
end

-------------------------------------------------------
-- Error handling
-------------------------------------------------------
do 
	local MSG_STACK_TRACE  = 'Stack trace:';
	local FORMAT_ERROR_OUT = '%s%s\n[%d]:@%s:\n%s\n';
	local FORMAT_ERROR_SRC = '%s\n\n%s\n\n'..MSG_STACK_TRACE..'\n';
	local GSUB_REMOVE_LINE = '.+%.lua:%d+: ';
	local GSUB_REMOVE_TAGS = '%b<>';
	local GSUB_REMOVE_TEXT = '^[^\n]+';

	local function strip(msg) return msg:gsub(GSUB_REMOVE_LINE, '') end;
	local function trace(msg) return msg
		:gsub(GSUB_REMOVE_TEXT, '')
		:gsub(MSG_STACK_TRACE, '')
		:gsub(GSUB_REMOVE_TAGS, '')
		:gsub('%b||r', '')
		:gsub('%-', '')
		:trim()
	end

	local traceLevel, traceSource, traceElem = 0, '';

	local function ThrowException(message, elem) traceLevel = traceLevel + 1;
		local originTrace = rawget(elem, Props.Debug)
		local elementText = tostring(elem)
		local cleanedMsg  = strip(message)
		local stackTrace  = trace(cleanedMsg, traceElem)

		-- TODO: cleanup
		if ( traceLevel == 1 ) then
			traceElem   = '(%s+'..elementText:gsub('\n', '\n%%s+')..')';
			traceSource = FORMAT_ERROR_SRC:format(
				cleanedMsg,
				elementText
			);
		else
			-- TODO: doesn't work with printed namespaces
			local innerElem = elementText:match(traceElem)
			if innerElem then
				local wrapLength, indentation = 0, innerElem:match('^%s+');
				for line in innerElem:gmatch('[^\n]+') do
					wrapLength = max(wrapLength, line:len())
				end
				local wrapper = indentation .. ('-'):rep(wrapLength);
				elementText = elementText:gsub(traceElem, ('%s%s%s'):format(
					wrapper,
					RED_FONT_COLOR:WrapTextInColorCode('%1'),
					wrapper
				));
			end
		end

		local msg = FORMAT_ERROR_OUT:format(
			traceSource,
			stackTrace,
			traceLevel,
			originTrace,
			elementText
		)
		if (msg:len() > 2000) then
			msg = msg:sub(1, 2000) .. '...'
		end
		error(msg, 5)
	end

	Metadata.Assert = function(isOK, message, elem)
		if not isOK then
			ThrowException(message, elem)
		end
	end

	Metadata.StartTrace = function()
		traceLevel, traceSource = 0, nil;
	end;
end