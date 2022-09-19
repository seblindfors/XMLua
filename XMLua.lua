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
-- Upvalues
-------------------------------------------------------
local rawset, rawget = rawset, rawget;
local setmetatable, getmetatable = setmetatable, getmetatable;
local setfenv, getfenv = setfenv, getfenv;
local table, select, tostring = table, select, tostring;

-------------------------------------------------------
-- Tag handling
-------------------------------------------------------
local TAG = {
	ATTRIBUTE  = '%s %s=%q';
	BEGIN      = '<%s';
	END_EMPTY  = '%s/>';
	END_PROPS  = '%s>%s%s%s</%s>';
	NONE       = '';
};

local function isstring(obj) return type(obj) == 'string' and obj:len() > 0 end;
local function istable(obj)  return type(obj) == 'table' end;

-------------------------------------------------------
-- Indentation handling
-------------------------------------------------------
local INDENT_LEVEL   = 4;
local INDENT_TOKEN   = ' ';
local INDENT_NEWLINE = '\n';

local function indent(text)
	local inset = INDENT_TOKEN:rep(INDENT_LEVEL);
	return (text):gsub('^', inset):gsub(INDENT_NEWLINE, INDENT_NEWLINE .. inset)
end

-------------------------------------------------------
-- Element prototype
-------------------------------------------------------
local Element, Props = {}, {
	Name             = '__name';
	Attributes       = '__attrs';
	Namespace        = '__attrs';
	Content          = '__content';
	CurrentAttribute = '__curr';
	Debug            = '__debug';
	Print            = tostring;
	PrintNamespace   = tostring;
	GetDebugName     = tostring;
};

function Element:__index(key)
	rawset(self, Props.CurrentAttribute, tostring(key));
	return self;
end

function Element:__call(...)
	local attribute = rawget(self, Props.CurrentAttribute);

	if attribute then
		local arg1 = ...;
		if (arg1 == self) then
			local namespace = rawget(self, Props.Namespace)
			namespace[#namespace + 1] = {attribute, select(2, ...)};
		else
			local attrs = rawget(self, Props.Attributes);
			attrs[attribute] = arg1;
		end
		rawset(self, Props.CurrentAttribute, nil);
	else
		rawset(self, Props.Content, ...);
	end

	return self;
end

function Element:__concat(sibling)
	local content = rawget(self, Props.Content)
	return self;
end

function Element:__tostring()
	local content = rawget(self, Props.Content) or TAG.NONE;

	if istable(content) then
		local children = {};
		for index, child in ipairs(content) do
			children[index] = Props.Print(child)
		end
		content = indent(table.concat(children, INDENT_NEWLINE))
	end

	local name = rawget(self, Props.Name)
	local tag = TAG.BEGIN:format(name);

	local attributes = rawget(self, Props.Attributes);
	for attrname, attrvalue in pairs(attributes) do
		tag = TAG.ATTRIBUTE:format(tag, attrname, Props.Print(attrvalue));
	end

	local namespace = rawget(self, Props.Namespace)
	if (istable(namespace)	 and namespace ~= attributes) then
		tag = tag .. Props.PrintNamespace(namespace)
	end

	if isstring(content) then
		return TAG.END_PROPS:format(tag, INDENT_NEWLINE, content, INDENT_NEWLINE, name)
	end
	return TAG.END_EMPTY:format(tag)
end

-------------------------------------------------------
-- Attributes prototype
-------------------------------------------------------
local Attributes, nilproxy, Modes = {}, newproxy(), {
	Consume   = true;
	Enumerate = false;
};

local function scrub(v, ...)
    if (v == nil) then return end;
    if (v == nilproxy) then v = nil end;
    return v, scrub(...)
end

function Attributes:__index(key)
    if (rawget(self, '__env')) then
    	local default = rawget(self, '__def')
    	if (default ~= nil) then
    		return default;
    	end
        return nilproxy;
    end
end

function Attributes:__call(input, stack)
    local isFetching = istable(input)

    if isFetching then
        setfenv(self.__stack, self.__env)
        self.__env, self.__stack, self.__def = nil;
        return scrub(unpack(input))
    else
    	local stackLevel = stack or 2;
    	local consume    = not not input;

        self.__env   = getfenv(stackLevel)
        self.__stack = stackLevel;
        self.__def   = input;

        if consume then
        	setfenv(stackLevel, setmetatable({}, {__index = function(_, key)
        		local value = self[key];
        		rawset(self, key, nil)
        		return value;
        	end}))
        else
        	setfenv(stackLevel, self)
        end
    end
    return self;
end

-------------------------------------------------------
-- Metadata
-------------------------------------------------------
local Metadata = {
	Tags = TAG;
	Element = Props;
	Attributes = Modes;
	Prototype = {
		Element = Element;
		Attributes = Attributes;
	};
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
local function create(name, debugName)
	return setmetatable({
		[Props.Name]       = name;
		[Props.Debug]      = debugName;
		[Props.Namespace]  = {};
		[Props.Attributes] = setmetatable({}, Attributes);
	}, Element)
end

local function elem(name)
	local debugName = Props.GetDebugName(name)
	return setmetatable({}, {
		__index = function(_, key)
			return create(name, debugName)[key];
		end;
		__call = function(_, ...)
			return create(name, debugName)(...)
		end;
	});
end

-------------------------------------------------------
-- Document factory
-------------------------------------------------------
local isDocument, _G, lookupTable = true, _G;
local function factory(_, key)
	if (lookupTable) then
		local value = lookupTable[key];
		if (value ~= nil) then
			return value;
		end
	end
	return elem(key)
end

local xmlEnv = setmetatable({}, {__index = factory})

setmetatable(XML, {
	__index = factory;
	__call = function(self, input, stackLevel)
		isDocument = not isDocument;
		if isDocument then
			assert(istable(input), 'Expected document (table of elements).')
			setfenv(self.__stack, self.__env)
			self.__env, self.__stack, lookupTable = nil;
			return resolve(unpack(input))
		else
			stackLevel   = stackLevel or 2;
			assert(istable(input) or input == nil, 'Expected environment table (or nil to use global).')
			self.__env   = getfenv(stackLevel)
			self.__stack = stackLevel;
			lookupTable  = istable(input) and input or _G;
			setfenv(stackLevel, xmlEnv)
		end
		return self;
	end;
})

-------------------------------------------------------
-- Object 
-------------------------------------------------------
function XML:GetMetadata()
	return Metadata;
end

function XML:SetResolver(resolver)
	for k, v in pairs(resolver) do
		rawset(Resolver, k, v)
	end
	return self;
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