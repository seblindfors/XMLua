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
		local parsed, prev, depth = TAG.NONE, TAG.NONE, 1;

		local i, j, k, this, innerText;
		while true do
			i, j = findtag(content, j)
			if not i then break end;
			
			innerText = k and gettext(content, k, j)
			this, k = gettag(content, i, j)

			local isClosingTag      = this:match(TAG.CLOSING)
			local isEnclosedTag     = this:match(TAG.ENCLOSED)
			local isOpeningTag      = prev:match(TAG.OPENING) and not isEnclosedTag;
			local isPrevEnclosedTag = prev:match(TAG.ENCLOSED)

			if (isOpeningTag and not isEnclosedTag and not isPrevEnclosedTag) or
				(isEnclosedTag and not isPrevEnclosedTag) then
				depth = depth + 1;
			end
			if isClosingTag then
				depth = depth - 1;
			end

			parsed = indent(parsed, prev, innerText, depth)
			prev = this;
		end

		parsed = prev:len() == 0 and content or parsed .. prev .. INDENT_NEWLINE;

		return TAG.END_PROPS:format(tag, parsed, name)
	end
	return TAG.END_EMPTY:format(tag)
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
		[Props.Attributes] = {};
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
local xmlMT = setmetatable({}, {
	__index = function(self, key)
		print(key)
		return elem(key)
	end;
})

setmetatable(XML, {
	__index = function(self, key)
		return elem(key)
	end;
	__call = function(self, input)
		local isDocument = istable(input)
		local stack = not isDocument and input or 2;

		if isDocument then
			setfenv(self.__stack, self.__env)
			self.__env, self.__stack = nil, nil;
			return resolve(unpack(input))
		else
			self.__env   = getfenv(stack)
			self.__stack = stack;
			setfenv(stack, xmlMT)
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