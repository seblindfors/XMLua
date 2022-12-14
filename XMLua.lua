---------------------------------------------------------------
-- XMLua
---------------------------------------------------------------
-- 
-- Author:  Sebastian Lindfors (Munk / MunkDev)
-- Website: https://github.com/seblindfors/XMLua
-- Licence: GPL version 2 (General Public License)
--
---------------------------------------------------------------

local XML;

if LibStub then
	XML = LibStub:NewLibrary('XMLua', 1)
	if not XML then return end;
else
	XML = {}; _G.XMLua = XML;
end

-------------------------------------------------------
-- Tag handling
-------------------------------------------------------
local TAG = {
	ATTRIBUTE  = '%s %s=%q';
	BALANCED   = '%b<>';
	BEGIN      = '<%s';
	CLOSING    = '^</';
	ENCLOSED   = '/>$';
	END_EMPTY  = '%s/>';
	END_PROPS  = '%s>%s</%s>';
	INDENT_TAG = '%s%s%s%s%s';
	INDENT_TXT = '%s%s%s';
	NONE       = '';
	OPENING    = '^<[^/]';
	PARSED     = '%s%s%s';
	WS_AFTER   = '%s+$';
	WS_BEFORE  = '^%s+';
};

local function gettext(str, start, stop)
	return str:sub(start, stop)
		:gsub(TAG.BALANCED,  TAG.NONE)
		:gsub(TAG.WS_BEFORE, TAG.NONE)
		:gsub(TAG.WS_AFTER,  TAG.NONE)
end

local function findtag(str, start)      return str:find(TAG.BALANCED, start) end;
local function gettag(str, start, stop) return str:sub(start, stop), stop + 1 end;

local function isstring(obj) return type(obj) == 'string' and obj:len() > 0 end;
local function istable(obj)  return type(obj) == 'table' end;

-------------------------------------------------------
-- Indentation handling
-------------------------------------------------------
local INDENT_LEVEL   = 4;
local INDENT_TOKEN   = ' ';
local INDENT_NEWLINE = '\n';

local function indent(text, tag, innerText, depth)
	local inner = isstring(innerText) and TAG.INDENT_TXT:format(
		INDENT_NEWLINE,
		INDENT_TOKEN:rep((depth + 1) * INDENT_LEVEL),
		innerText:gsub(INDENT_NEWLINE,
			INDENT_NEWLINE .. INDENT_TOKEN:rep((depth) * INDENT_LEVEL)
		)
	) or TAG.NONE;

	return TAG.INDENT_TAG:format(
		text,
		tag,
		inner,
		INDENT_NEWLINE,
		INDENT_TOKEN:rep(depth * INDENT_LEVEL)
	);
end

-------------------------------------------------------
-- Element prototype
-------------------------------------------------------
local Element, Props = {}, {
	Name             = '__name';
	Attributes       = '__attrs';
	Content          = '__content';
	CurrentAttribute = '__curr';
};

function Element:__index(key)
	rawset(self, Props.CurrentAttribute, tostring(key));
	return self;
end

function Element:__call(...)
	local attrs     = rawget(self, Props.Attributes);
	local attribute = rawget(self, Props.CurrentAttribute);

	if attribute then
		attrs[attribute] = ...;
		rawset(self, Props.CurrentAttribute, nil);
	else
		rawset(self, Props.Content, ...);
	end

	return self;
end

function Element:__tostring()
	local content = rawget(self, Props.Content) or TAG.NONE;

	if istable(content) then
		local children = {};

		for index, child in ipairs(content) do
			children[index] = tostring(child)
		end

		content = table.concat(children, TAG.NONE)
	end

	local name = rawget(self, Props.Name)
	local tag = TAG.BEGIN:format(name);

	for attrname, attrvalue in pairs(rawget(self, Props.Attributes)) do
		tag = TAG.ATTRIBUTE:format(tag, attrname, tostring(attrvalue));
	end

	if isstring(content) then
		local parsed, depth = TAG.NONE, 1;
		local prev, isPrevClosingTag = TAG.NONE;
		local i, j, k, this, innerText;

		while true do
			i, j = findtag(content, j)
			if not i then break end;
			
			innerText = k and gettext(content, k, j)
			this, k = gettag(content, i, j)

			local isClosingTag  = this:match(TAG.CLOSING)

			if not isPrevClosingTag and not prev:match(TAG.ENCLOSED) and prev:match(TAG.OPENING) then
				depth = depth + 1;
			end
			if isClosingTag then
				depth = depth - 1;
			end

			parsed = indent(parsed, prev, innerText, depth)
			prev, isPrevClosingTag = this, isClosingTag;
		end

		parsed = prev:len() == 0 and content or parsed .. prev .. INDENT_NEWLINE;

		return TAG.END_PROPS:format(tag, parsed, name)
	end
	return TAG.END_EMPTY:format(tag)
end

-------------------------------------------------------
-- Attributes prototype
-------------------------------------------------------
local Attributes, nilproxy = {}, newproxy();

local function scrub(v, ...)
    if (v == nil) then return end;
    if (v == nilproxy) then v = nil end;
    return v, scrub(...)
end

function Attributes:__index(key)
    if (rawget(self, '__env')) then
        return nilproxy;
    end
end

function Attributes:__call(input, stack)
    local isFetching = istable(input)
    local stackLevel = stack or 2;

    if isFetching then
        setfenv(self.__stack, self.__env)
        self.__env, self.__stack = nil;
        return scrub(unpack(input))
    else
        self.__env   = getfenv(stackLevel)
        self.__stack = stackLevel;
        setfenv(stackLevel, self)
    end
    return self;
end

-------------------------------------------------------
-- Metadata
-------------------------------------------------------
local Metadata = {
	Tags = TAG;
	Element = Props;
};

-------------------------------------------------------
-- Resolver
-------------------------------------------------------
local Resolver = {__tostring = Element.__tostring};

local function resolve(self, ...)
	if not istable(self) then
		return self;
	end
	local content = rawget(self, Props.Content)
	if istable(content) then
		rawset(self, Props.Content, {resolve(unpack(content))})
	end
	return getmetatable(self) and setmetatable(self, Resolver) or self, resolve(...);
end

-------------------------------------------------------
-- Element factory
-------------------------------------------------------
local function create(name)
	return setmetatable({
		[Props.Name]       = name;
		[Props.Attributes] = setmetatable({}, Attributes);
	}, Element)
end

local function elem(name)
	return setmetatable({}, {
		__index = function(_, key)
			return create(name)[key];
		end;
		__call = function(_, ...)
			return create(name)(...)
		end;
	});
end

-------------------------------------------------------
-- Document factory
-------------------------------------------------------
local _G, useGlobals = _G;
local function factory(_, key)
	if (useGlobals) then
		local value = _G[key];
		if (value ~= nil) then
			return value;
		end
	end
	return elem(key)
end

local xmlEnv = setmetatable({}, {__index = factory})

setmetatable(XML, {
	__index = factory;
	__call = function(self, input, stack)
		local isDocument = istable(input)
		local stackLevel = stack or 2;

		if isDocument then
			setfenv(self.__stack, self.__env)
			self.__env, self.__stack, useGlobals = nil;
			return resolve(unpack(input))
		else
			self.__env   = getfenv(stackLevel)
			self.__stack = stackLevel;
			useGlobals   = not input;
			setfenv(stackLevel, xmlEnv)
		end
		return self;
	end;
})

-------------------------------------------------------
-- Object 
-------------------------------------------------------
function XML:GetElementPrototype()
	return Element;
end

function XML:GetMetadata()
	return Metadata;
end

function XML:SetResolver(resolver)
	for k, v in pairs(resolver) do
		rawset(Resolver, k, v)
	end
end

function XML:SetIndentationLevel(level)
	assert(tonumber(level), 'Indentation level must be a number.')
	INDENT_LEVEL = tonumber(level);
end

function XML:SetIndentationToken(token)
	assert(tostring(token) == token, 'Indentation token must be a string.')
	INDENT_TOKEN = token;
end

function XML:SetIndentationNewline(token)
	assert(tostring(token) == token, 'Indentation newline token must be a string.')
	INDENT_NEWLINE = token;
end