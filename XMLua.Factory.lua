local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML and XML:GetMetadata();

if not XML or Metadata.Loaded then return end;

local function __modify(t, k, v)
	local mt = getmetatable(t) or {};
	rawset(mt, k, v)
	return setmetatable(t, mt)
end

local function __get(t)
	return getmetatable(t).__index;
end

local function __proxy(src, dest)
	return __modify(src, '__index', dest)
end

local function __callable(src, func)
	return __modify(src, '__call', func)
end

local function istype(o,t) return type(o) == t end;
local function istable(t)  return istype(t, 'table') end;
local function isempty(t)  return istable(t) and not next(t) end;
local function isfunc(f)   return istype(f, 'function') end;
local function isdef(o)	   return o ~= nil end;

local function strip(msg) return (msg:gsub('^.+%.lua:%d+: ', '')) end;

-------------------------------------------------------
-- Schema generation
-------------------------------------------------------
local Schema, SchemaGen = {Abstract = {}, UI = {}}, {};
local Props = Metadata.Element;
RND = Schema

Props.Get = function(self)
	local name    = rawget(self, Props.Name)
	local props   = rawget(self, Props.Attributes)
	local content = rawget(self, Props.Content)
	return name, props, content;
end;

function SchemaGen:Acquire(name)
	return self[name] or {};
end

function SchemaGen:InitFromProps(props)
	local extensions, insert = props() { extend, insert };
	props.extend, props.insert = nil, nil;
	__proxy(self, CreateFromMixins(props))
	return extensions, insert;
end

function SchemaGen:Inherit(super, schema, prevName)
	local superName, superProps, superContent = Props.Get(super)

	local parentObj = schema[superName];
	local objectProps, parentProps = __get(self), __get(parentObj);
	if isempty(superProps) then
		MergeTable(objectProps, parentProps)
	else
		for k in pairs(superProps) do
			objectProps[k] = parentProps[k];
		end
	end
	if isempty(superContent) then
		MergeTable(self, parentObj)
	else
		for index, elem in ipairs(superContent) do
			SchemaGen.Inherit(self, elem, parentObj, superName)
		end
	end
end

function SchemaGen:SetCallable(func)
	return __callable(self, func)
end

local SchemaResolver = {__call = function(self, parentObj)
	local name, props, content = Props.Get(self)

	local object = SchemaGen.Acquire(parentObj or Schema, name);
	local extensions, call = SchemaGen.InitFromProps(object, props);

	if extensions then
		for i, extension in ipairs(extensions) do
			SchemaGen.Inherit(object, extension, Schema)
		end
	end

	if istable(content) then
		for index, elem in ipairs(content) do
			local child, parentKey = elem(object)
			if parentKey then
				object[parentKey] = child;
			end
		end
	elseif isfunc(content) then
		call = content;
	elseif isdef(content) then
		object = content;
	end

	if call then
		SchemaGen.SetCallable(object, call)
	end

	return object, name;
end};

-------------------------------------------------------
-- Widget factories
-------------------------------------------------------
local Factory = {};

function Factory:Initialize(object, props, tag)
	for key, value in pairs(props) do
		local exec = rawget(self, key)
		if isfunc(exec) then
			exec(self, object, value)
		else --@see Type
			exec = self[key];
			assert(exec, ('Unknown attribute %q.'):format(key))
			exec(self, object, value, key)
		end
	end
	return object;
end

function Factory:Frame(
	parentObj   , -- @param target object to render on
	props       , -- @param <Element properties {...} />
	parentProps , -- @param <Parent properties{...} /> 
	tag         , -- @param <Element />
	parentTag   ) -- @param <Parent />)

	local name, parent, inherits, id, parentKey = props() { name, parent, inherits, id };
	return Factory.Initialize(self, CreateFrame(rawget(tag, Props.Name),
		name,
		parent or parentObj,
		inherits,
		id
	), props, tag)
end

-------------------------------------------------------
-- Methods
-------------------------------------------------------
local Method = {};

function Method:Forward(object)
	return object;
end

function Method:Validate(
	object      , -- @param target object to render on
	props       ) -- @param <Element properties {...} />

	for key, value in pairs(props) do
		exec = self[key];
		assert(exec, ('Unknown attribute %q.'):format(key))
		exec(self, object, value, key)
	end
	return object;
end

function Method:Size(
	object      , -- @param target object to render on
	props       ) -- @param <Element properties {...} />

	local x, y = props() { x, y };
	if (x and y) then
		object:SetSize(x, y)
	elseif (x) then
		object:SetWidth(x)
	elseif (y) then
		object:SetHeight(y)
	end
	return object;
end

function Method:Attribute(
	object      , -- @param target object to render on
	props       ) -- @param <Element properties {...} />

	local name, value = props() { name, value };
	if (props.type) then
		assert(type(value) == props.type, 'Attribute value has invalid type.')
	end
	object:SetAttribute(name, value)
	return object;
end

function Method:KeyValue(
	object      , -- @param target object to render on
	props       ) -- @param <Element properties {...} />

	local key, value = props() { key, value };
	if (props.type) then
		assert(type(value) == props.type, 'Value in key-value pair has invalid type.')
	end
	if (props.keyType) then
		assert(type(key) == props.key, 'Key in key-value pair has invalid type.')
	end
	object[key] = value;
	return object;
end

do	local function GetRelative(object, query)
		if C_Widget.IsWidget(query) then return query end;
		if not istype(query, 'string') then return end;

		local relative;
		for key in query:gmatch('$?%w+') do
			if (key == '$parent') then
				relative = relative and relative:GetParent() or object:GetParent()
			elseif relative then
				relative = rawget(relative, key)
			else
				relative = rawget(object, key)
			end
		end
		return relative;
	end

	local function GetOffsets(tag)
		local _, props, content = Props.Get(tag)

		local offX, offY = props() { x, y };
		if (offX or offY) then
			return offX or 0, offY or 0;
		end

		local child = content and content[1];
		if child then
			return GetOffsets(child)
		end
		return 0, 0;
	end

	function Method:Point(
		object      , -- @param target object to render on
		props       , -- @param <Element properties {...} />
		parentProps , -- @param <Parent properties{...} /> 
		tag         , -- @param <Element />
		parentTag   ) -- @param <Parent />)

		local point, relativeKey, relativeTo, relativePoint = props()
			{ point, relativeKey, relativeTo, relativePoint };
		local relative = GetRelative(object, relativeTo or relativeKey)
		local offX, offY = GetOffsets(tag)

		if relativePoint then
			object:SetPoint(point, relative, relativePoint, offX, offY)
		elseif relative then
			object:SetPoint(point, relative, offX, offY)
		else
			object:SetPoint(point, offX, offY)
		end
		return object;
	end
end

-------------------------------------------------------
-- Type handling
-------------------------------------------------------
local TypeError = __callable({
	Assert = function(ass, msg) return (function(...) if not ass(...) then error(msg(...)) end; return (select(2, ...)); end) end;
	-- Asserts:
	Value  = function(expected) return (function(_, _, v, _) return istype(v, expected) end) end;
	Key    = function(expected) return (function(_, _, v, k) return istype(k, expected) end) end;
	Enum   = function(table)    return (function(_, _, v, _) return isdef(table[v]) end) end;
	Widget = function(_, _, v)  return C_Widget.IsWidget(v) end;
	Frame  = function(_, _, v)  return C_Widget.IsFrameWidget(v) end;
	-- Messages:
	OneOf  = function(expected) return (function(_, _, v, k) return ('Invalid attribute %q. Value is %q, expected one of:\n[%s]'):format(k, v, table.concat(tInvert(expected), ', ')) end) end;
	Expect = function(expected) return (function(_, _, v, k) return ('Invalid attribute %q (%s expected, got %s)'):format(k, expected, type(v)) end) end;
},  function(_, message) return (function(_, _, v, k) error(message:format(k, v)) end) end);

local Type = {
	Any         = nop;
	Bool        = TypeError.Assert(TypeError.Value('bool'),   TypeError.Expect('boolean'));
	Number      = TypeError.Assert(TypeError.Value('number'), TypeError.Expect('number'));
	String      = TypeError.Assert(TypeError.Value('string'), TypeError.Expect('string'));
	Table       = TypeError.Assert(TypeError.Value('table'),  TypeError.Expect('table'));
	Widget      = TypeError.Assert(TypeError.Widget,          TypeError.Expect('widget'));
	Frame       = TypeError.Assert(TypeError.Frame,           TypeError.Expect('frame'));
	Deprecated  = TypeError('Attribute %q is deprecated.');
	Protected   = TypeError('Attribute %q is protected and cannot be used from insecure code.');
	Unsupported = TypeError('Attribute %q is not supported.');
	Enum        = __proxy({}, function(self, enumType)
		return rawget(rawset(self, enumType, function(...)
			local enum = Schema.Abstract.Enum[enumType];
			return TypeError.Assert(
				TypeError.Enum(enum),
				TypeError.OneOf(enum)
			)(...)
		end), enumType)
	end)
};

-------------------------------------------------------
-- Attribute evaluation
-------------------------------------------------------
local function EvalSetAndMap(self, object, value, key, name)
	local method = rawget(object, name)
	if not method then
		method = __get(object)[name];
		assert(method, ('Method name %q derived from %q does not exist.'):format(name, key))
		self[key] = method;
	end
	method(object, value)
	return object;
end

local Eval = __proxy(__callable({
	Call = function(func)
		return function(_, object, value)
			func(object, value)
			return object;
		end
	end;
	Map = function(methodName)
		return function(self, object, value, key)
			return EvalSetAndMap(self, object, value, key, methodName)
		end
	end;
}, 
	function(self, ...) return self.Call(...) end),
	function(self, ...) return self.Map (...) end);

function Eval:Setter(object, value, key)
	return EvalSetAndMap(self, object, value, key, 'Set' .. key:gsub('^%l', string.upper))
end

function Eval:Togglable(object, value, key)
	return EvalSetAndMap(self, object, value, key, key:gsub('^%l', string.upper))
end

function Eval:ParentArray(object, key)
	local parent = object:GetParent()
	local array = parent[key];
	if not array then
		array = {}; parent[key] = array;
	end
	array[#array + 1] = object;
	return object;
end

-------------------------------------------------------
-- Export metadata
-------------------------------------------------------
Metadata.Factory = {
	Resolver  = SchemaResolver;
	Eval      = Eval;
	Factory   = Factory;
	Method    = Method;
	Type      = Type;
	TypeError = TypeError;
	-- Helpers:
	AND = function(...)
		return GenerateClosure(function(calls, self, object, ...)
			for _, call in ipairs(calls) do
				object = call(self, object, ...)
			end
			return object;
		end, {...})
	end;
	OR = function(...)
		return GenerateClosure(function(calls, self, object, ...)
			local errors, isOK, result = {};
			for _, call in ipairs(calls) do 
				isOK, result = pcall(call, self, object, ...)
				if isOK then return result end;
				tinsert(errors, strip(result))
			end
			tinsert(errors, 1, 'Multiple tests failed:')
			error(table.concat(errors, '\n'))
		end, {...})
	end;
};

Metadata.Schema = Schema;