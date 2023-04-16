local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML and XML:GetMetadata();

if not XML or Metadata.Loaded then return end;

-------------------------------------------------------
-- Common helpers
-------------------------------------------------------
local function __modify(t, k, v)
	local mt = getmetatable(t) or {};
	rawset(mt, k, v)
	return setmetatable(t, mt)
end

local function __get(t, k)
	return getmetatable(t)[k or '__index'];
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
-- Closure helpers
-------------------------------------------------------
local AND, OR; do
	local function __AND__(calls, self, object, ...)
		for _, call in ipairs(calls) do
			object = call(self, object, ...)
		end
		return object;
	end

	local function __OR__(calls, self, object, ...)
		local errors, isOK, result = {};
		for _, call in ipairs(calls) do 
			isOK, result = pcall(call, self, object, ...)
			if isOK then return result end;
			tinsert(errors, strip(result))
		end
		tinsert(errors, 1, 'Multiple tests failed:')
		error(table.concat(errors, '\n- ') .. '\n')
	end

	function AND (...) return GenerateClosure(__AND__, {...}) end;
	function OR  (...) return GenerateClosure(__OR__,  {...}) end;
end

-------------------------------------------------------
-- Schema generation
-------------------------------------------------------
local Schema, SchemaGen = {Abstract = {}, UI = {}}, {};
local Props = Metadata.Element;
RND = Schema

function Props:Get()
	local name    = rawget(self, Props.Name)
	local props   = rawget(self, Props.Attributes)
	local content = rawget(self, Props.Content)
	return name, props, content;
end

function SchemaGen:Acquire(name)
	return self[name] or {};
end

function SchemaGen:InitFromProps(props)
	local extensions, insert, implement = props() { extend, insert, implement };
	props.extend, props.insert, props.implement = nil, nil, nil;
	return extensions, insert, implement;
end

function SchemaGen:Extend(super, callables, schema)
	local superName, superProps, superContent = Props.Get(super)

	local parentObj = schema[superName];
	local objectProps, parentProps = __get(self), __get(parentObj);
	local parentCall = __get(parentObj, '__call');

	if isfunc(parentCall) then
		tinsert(callables, parentCall)
	end
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
			SchemaGen.Extend(self, elem, callables, parentObj)
		end
	end
end

function SchemaGen:Implement(super, callables, schema)
	local superName, superProps, superContent = Props.Get(super)
	local parentObj = schema[superName];

	if isempty(superContent) then
		tinsert(callables, __get(parentObj, '__call'))
		return __proxy(self, parentObj)
	end
	return SchemaGen.Implement(self, superContent[1], callables, parentObj)
end

local SchemaResolver = {__call = function(self, parentObj)
	local name, props, content = Props.Get(self)

	local object = SchemaGen.Acquire(parentObj or Schema, name);
	local extensions, call, implement = SchemaGen.InitFromProps(object, props);

	local callables = {};
	if implement then
		SchemaGen.Implement(object, implement, callables, Schema)
	else
		__proxy(object, CreateFromMixins(props))
		if extensions then
			for i, extension in ipairs(extensions) do
				SchemaGen.Extend(object, extension, callables, Schema)
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
	end

	if next(callables) then
		tinsert(callables, call)
		__callable(object, AND(unpack(callables)))
	elseif call then
		__callable(object, call)
	end

	return object, name;
end};

-------------------------------------------------------
-- Widget factories
-------------------------------------------------------
local Factory = {};

function Factory:Initialize(object, props)
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
	tag         , -- @param <Element />
	parentProps , -- @param <Parent properties{...} /> 
	parentTag   ) -- @param <Parent />)

	local name, parent, inherits, id = props() { name, parent, inherits, id };
	return Factory.Initialize(self, CreateFrame(rawget(tag, Props.Name),
		name,
		parent or parentObj,
		inherits,
		id
	), props, tag)
end

function Factory:Texture(
	parentObj   , -- @param target object to render on
	props       , -- @param <Element properties {...} />
	tag         , -- @param <Element />
	parentProps , -- @param <Parent properties{...} /> 
	parentTag   ) -- @param <Parent />)

	local name, parent, inherits, id = props()
		{ name, parent, inherits, id };
	local level, textureSubLevel = parentProps()
		{ level, textureSubLevel };

	local texture = parentObj:CreateTexture(name, level, inherits, textureSubLevel)
	local atlas, useAtlasSize, file, hWrapMode, vWrapMode, filterMode = props()
		{ atlas, useAtlasSize, file, hWrapMode, vWrapMode, filterMode };

	if file then
		texture:SetTexture(file, hWrapMode, vWrapMode, filterMode)
	end

	if atlas then
		texture:SetAtlas(atlas, useAtlasSize, filterMode)
	end

	return Factory.Initialize(self, texture, props)
end

function Factory:AnimationGroup(
	parentObj   , -- @param target object to render on
	props       , -- @param <Element properties {...} />
	tag         , -- @param <Element />
	parentProps , -- @param <Parent properties{...} /> 
	parentTag   ) -- @param <Parent />)

	local name, inherits = props()
		{ name, inherits };

	local animGroup = parentObj:CreateAnimationGroup(name, inherits)
	return Factory.Initialize(self, animGroup, props)
end
-------------------------------------------------------
-- Methods
-------------------------------------------------------
local Method = {};

function Method:Forward(
	object      , -- @param target object to render on
	props       , -- @param <Element properties {...} />
	tag         , -- @param <Element />
	parentProps , -- @param <Parent properties{...} /> 
	parentTag   ) -- @param <Parent />

	return object;
end

function Method:Validate(object, props)
	for key, value in pairs(props) do
		exec = self[key];
		assert(exec, ('Unknown attribute %q.'):format(key))
		exec(self, object, value, key)
	end
	return object;
end

function Method:Size(object, props)
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

function Method:Attribute(object, props)
	local name, value = props() { name, value };
	if (props.type) then
		assert(type(value) == props.type, 'Attribute value has invalid type.')
	end
	object:SetAttribute(name, value)
	return object;
end

function Method:KeyValue(object, props)
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

	function Method:Point(object, props, tag)
		local point, relativeKey, relativeTo, relativePoint = props()
			{ point, relativeKey, relativeTo, relativePoint };
		local relative = GetRelative(object, relativeTo or relativeKey)
		local offX, offY = GetOffsets(tag)

		-- convert <.*?Anchor> to equivalent Set.*Point
		local methodName = ('Set%sPoint'):format(Props.Get(tag):gsub('Anchor', ''));
		local func = object[methodName];

		assert(func, ('Method name %q does not exist.'):format(methodName))

		if relativePoint then
			func(object, point, relative, relativePoint, offX, offY)
		elseif relative then
			func(object, point, relative, offX, offY)
		else
			func(object, point, offX, offY)
		end
		return object;
	end
end

do local function GetInsets(name, props, content)
		local left, right, top, bottom = props()
			{ left, right, top, bottom }
		if (left or right or top or bottom) then
			return left or 0, right or 0, top or 0, bottom or 0;
		end

		local child = content and content[1];
		if child then
			return GetInsets(Props.Get(child))
		end
		return 0, 0, 0, 0;
	end

	function Method:Insets(object, props, tag)
		local name, props, content = Props.Get(tag)
		local left, right, top, bottom = GetInsets(name, props, content)

		-- convert <.*?Insets> to equivalent Set.*Insets
		local methodName = ('Set%s'):format(name);
		local func = object[methodName];

		assert(func, ('Method name %q does not exist.'):format(methodName))
		func(object, left, right, top, bottom)
		return object;
	end
end

function Method:TexCoord(object, props)
	local left, right, top, bottom = props()
		{ left, right, top, bottom };

	if left or right or top or bottom then
		object:SetTexCoord(left or 0, right or 1, top or 0, bottom or 1)
		return object;
	end

	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = props()
		{ ULx, ULy, LLx, LLy, URx, URy, LRx, LRy };
	if ULx or ULy or LLx or LLy or URx or URy or LRx or LRy then
		object:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
	end

	return object;
end

function Method:Gradient(object, props, tag)
	local orientation = props() { orientation };
	local minColor, maxColor;

	local _, _, content = Props.Get(tag)
	assert(content, 'Gradient element must have MinColor and MaxColor.')
	for _, child in ipairs(content) do
		local name, props = Props.Get(child)
		local r, g, b, a, color = props()
			{ r, g, b, a, color };
		if istype(color, 'string') then
			color = _G[color];
		end

		if ( name == 'MinColor' ) then
			minColor = color or CreateColor(r, g, b, a)
		elseif (name == 'MaxColor') then
			maxColor = color or CreateColor(r, g, b, a)
		end
	end
	assert(minColor, 'Gradient element must have MinColor.')
	assert(maxColor, 'Gradient element must have MaxColor.')
	if object.SetGradientAlpha then
		local minR, minG, minB, minA = minColor:GetRGBA()
		local maxR, maxG, maxB, maxA = maxColor:GetRGBA()
		object:SetGradientAlpha(orientation, minR, minG, minB, minA or 1, maxR, maxG, maxB, maxA or 1)
	elseif object.SetGradient then
		object:SetGradient(orientation, minColor, maxColor)
	end
	return object;
end

function Method:Color(object, props)
	local r, g, b, a, color = props()
		{ r, g, b, a, color };
	if istype(color, 'string') then
		color = _G[color];
	end
	color = color or CreateColor(r, g, b, a)
	object:SetColorTexture(color:GetRGBA())
	return object;
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
	Bool        = TypeError.Assert(TypeError.Value('boolean'), TypeError.Expect('boolean'));
	Number      = TypeError.Assert(TypeError.Value('number'),  TypeError.Expect('number'));
	String      = TypeError.Assert(TypeError.Value('string'),  TypeError.Expect('string'));
	Table       = TypeError.Assert(TypeError.Value('table'),   TypeError.Expect('table'));
	Widget      = TypeError.Assert(TypeError.Widget,           TypeError.Expect('widget'));
	Frame       = TypeError.Assert(TypeError.Frame,            TypeError.Expect('frame'));
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
local function EvalWrapFunction(func, _, object, ...)
	func(object, ...)
	return object;
end

local function EvalSetAndMap(self, object, value, key, name)
	local method = rawget(object, name)
	if not method then
		method = __get(object)[name];
		assert(method, ('Method name %q derived from %q does not exist.'):format(name, key))
		self[key] = GenerateClosure(EvalWrapFunction, method);
	end
	method(object, value)
	return object;
end

local Eval = __proxy(__callable({
	Call = function(func)
		return GenerateClosure(EvalWrapFunction, func)
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
	AND       = AND;
	OR        = OR;
};

Metadata.Schema = Schema;