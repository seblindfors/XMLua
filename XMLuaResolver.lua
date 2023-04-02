local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML:GetMetadata();
local Resolver = {};
local Schema = {}; RND = Schema

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


-------------------------------------------------------
local Props = Metadata.Element;

function Resolver:GetElementProps()
	local name    = rawget(self, Props.Name)
	local props   = rawget(self, Props.Attributes)
	local content = rawget(self, Props.Content)
	return name, props, content;
end

function Resolver:Assert(message, elem)
	if not self then
		Resolver.ThrowException(message, elem)
	end
end

function Resolver:ThrowException(elem)
	error(('%s\nin tag:\n%s\n'):format(self:gsub('^.+%.lua:%d+: ', ''), tostring(elem)), 4)
end

local UIResolver = {__call = function(
	self        , -- @param <Element />
	targetObj   , -- @param object on which rendering should occur
	parentTag   , -- @param enveloping tag
	parentProps , -- @param enveloping props
	renderer    ) -- @param renderer to be used to render the element

	local name, props, content = Resolver.GetElementProps(self)

	local render = (renderer or Schema.XSD)[name]; -- TODO: handle calling xml on existing objects
	Resolver.Assert(render, ('Element %s not recognized in %s.'):format(name, parentName or 'root'), self)

	local isOK, object, parentKey = pcall(
		render      , -- @param rendering function
		-- schema   , -- @param implicit schema object
		targetObj   , -- @param target object to render on
		props       , -- @param <Element properties {...} />
		parentProps , -- @param <Parent properties{...} /> 
		self        , -- @param <Element />
		parentTag   ) -- @param <Parent />

	Resolver.Assert(isOK, object, self)

	if (object and istable(content)) then
		for index, elem in ipairs(content) do
			local isOK, result = pcall(elem, object, self, props, render)
			Resolver.Assert(isOK, result, elem)
		end
	end

	return object;
end};

-------------------------------------------------------
local SchemaGen = {};

function SchemaGen:Acquire(name)
	if not self[name] then
		self[name] = {};
	end
	return self[name];
end

function SchemaGen:InitFromProps(props)
	local extensions, insert = props() { extend, insert };
	props.extend, props.insert = nil, nil;
	__proxy(self, CreateFromMixins(props))
	return extensions, insert;
end

function SchemaGen:Inherit(super, schema)
	local superName, superProps, superContent = Resolver.GetElementProps(super)

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
			SchemaGen.Inherit(self, elem, parentObj[(Resolver.GetElementProps(elem))])
		end
	end
end

function SchemaGen:SetCallable(func)
	return __callable(self, func)
end

local SchemaResolver = {__call = function(self, parentObj)
	local name, props, content = Resolver.GetElementProps(self)

	local object = SchemaGen.Acquire(parentObj or Schema, name);
	local extensions, call = SchemaGen.InitFromProps(object, props);

	if extensions then
		for i, extension in ipairs(extensions) do
			SchemaGen.Inherit(object, extension, Schema.XSD)
		end
	end

	if istable(content) then
		for index, elem in ipairs(content) do
			local child = elem(object)
		end
	elseif isfunc(content) then
		call = content;
	end

	if call then
		SchemaGen.SetCallable(object, call)
	end

	return object, name;
end};

-------------------------------------------------------
local Factory = {};

function Factory:Initialize(object, props, tag)
	for key, value in pairs(props) do
		local exec = rawget(self, key)
		if isfunc(exec) then
			exec(object, value)
		else
			exec = self[key];
			assert(exec, ('Unknown attribute %q.'):format(key))
			exec(object, value, key, self)
		end
	end
	return object, props.parentKey;
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
local Method = __callable({}, function(_, ...)
	return GenerateClosure(function(methods, object, ...)
		for _, method in ipairs(methods) do
			object = method(object, ...)
		end
		return object;
	end, {...})
end);

function Method:Forward(object)
	return object;
end

function Method:Validate(object, props, tag)
	for key, value in pairs(props) do
		exec = self[key];
		assert(exec, ('Unknown attribute %q.'):format(key))
		exec(object, value, key, self)
	end
	return object;
end

function Method:Size(
	object      , -- @param target object to render on
	props       ) -- @param <Element properties {...} />
	local x, y = props() {x, y};
	if (x and y) then
		object:SetSize(x, y)
	elseif (x) then
		object:SetWidth(x)
	elseif (y) then
		object:SetHeight(y)
	end
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
		local _, props, content = Resolver.GetElementProps(tag)

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
local TypeError = __callable({
	Assert = function(ass, msg) return (function(...) if not ass(...) then error(msg(...)) end end) end;
	Value  = function(expected) return (function(_, v, _) return istype(v, expected) end) end;
	Key    = function(expected) return (function(_, v, k) return istype(k, expected) end) end;
	Expect = function(expected) return (function(_, v, k) return ('Value for %q: %s expected, got %s.'):format(k, expected, type(v)) end) end;
	Widget = function(_, v)     return C_Widget.IsWidget(v) end;
	Frame  = function(_, v)     return C_Widget.IsFrameWidget(v) end;
},  function(_, message) return (function(_, v, k) error(message:format(k, v)) end) end);

local Type = __callable({
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
}, function(_, ...)
	return GenerateClosure(function(checks, ...)
		local errors = {};
		for _, check in ipairs(checks) do 
			local isOK, error = pcall(check, ...)
			if isOK then return end;
			tinsert(errors, error)
		end
		error(table.concat(errors, '\n'))
	end, {...})
end);

local function TypeSetAndMap(object, value, key, schema, name)
	local method = rawget(object, name)
	if not method then
		method = __get(object)[name];
		assert(method, ('Method name %q derived from %q does not exist.'):format(name, key))
		schema[key] = method;
	end
	method(object, value)
	return method;
end

function Type.Setter(object, value, key, schema)
	return TypeSetAndMap(object, value, key, schema, 'Set' .. key:gsub('^%l', string.upper))
end

function Type.Togglable(object, value, key, schema)
	return TypeSetAndMap(object, value, key, schema, key:gsub('^%l', string.upper))
end

function Type.MapTo(methodName)
	return function(object, value, key, schema)
		return TypeSetAndMap(object, value, key, schema, methodName)
	end
end

function Type.ParentArray(object, key)
	local parent = object:GetParent()
	local array = parent[key];
	if not array then
		array = {}; parent[key] = array;
	end
	array[#array + 1] = object;
end

-------------------------------------------------------
-- XML Schema definition
-------------------------------------------------------
XML:SetResolver(SchemaResolver)(true) {
	XSD {
		Object
			.parentKey   ( Type.Setter      )
			.parentArray ( Type.ParentArray );

		Resizing
			.scale ( Type.Setter )
			{
				Anchors
					.insert( Method.Forward )
					{
						Anchor
							.point         ( Type.String  )
							.relativeKey   ( Type.String  )
							.relativeTo    ( Type(Type.String, Type.Widget) )
							.relativePoint ( Type.String  )
							.x             ( Type.Number  )
							.y             ( Type.Number  )
							.insert        ( Method(Method.Validate, Method.Point) )
							{
								Offset
									.x  ( Type.Number )
									.y  ( Type.Number )
									.insert ( Method.Validate )
									{
										AbsDimension ( Method.Validate )
											.x ( Type.Number )
											.y ( Type.Number );
									};
							};
					};
				Size
					.x      ( Type.Number )
					.y      ( Type.Number )
					.insert ( Method.Size )
					{
						AbsDimension ( Method.Size )
							.x ( Type.Number )
							.y ( Type.Number );
					};
			};

		ScriptRegion
			{
				Scripts .fallback(function() end) {
					OnLoad (function(object, props, ...) end);
				};
			};

		LayoutFrame
			.extend {
				Object       {};
				Resizing     {};
				ScriptRegion {};
			}
			.alpha              ( Type.Setter      )
			.enableMouse        ( Type.Togglable   )
			.enableMouseClicks  ( Type.MapTo('SetMouseClickEnabled'))
			.enableMouseMotion  ( Type.MapTo('SetMouseMotionEnabled'))
			.hidden             ( function(object, hide) object:SetShown(not hide) end )
			.inherits           ( Type.String      )
			.mixin              ( Type.Table       )
			.name               ( Type.String      )
			.parent             ( Type.Setter      )
			.passThroughButtons ( Type.Setter      )
			.secureMixin        ( Type.Protected   )
			.secureReferenceKey ( Type.Protected   )
			.setAllPoints       ( Type.Togglable   )
			.virtual            ( TypeError('Cannot create virtual frames in Lua.') )
			{	
				KeyValues {
					KeyValue (function(object, props) end);
				};
			};

		TextureBase
			.extend   { LayoutFrame {} } {
				Color (function(object, props) end);
			};

		Frame
			.extend                 { LayoutFrame {} }
			.insert                 ( Factory.Frame   )
			.clampedToScreen        ( Type.Setter     )
			.clipChildren           ( Type.MapTo('SetClipsChildren') )
			.depth                  ( Type.Deprecated )
			.dontSavePosition       ( Type.Setter     )
			.enableKeyboard         ( Type.Togglable  )
			.fixedFrameLevel        ( Type.Setter     )
			.fixedFrameStrata       ( Type.Setter     )
			.flattenRenderLayers    ( Type.MapTo('SetFlattensRenderLayers') )
			.frameBuffer            ( Type.MapTo('SetIsFrameBuffer') )
			.frameLevel             ( Type.Setter     )
			.frameStrata            ( Type.Setter     )
			.hyperlinksEnabled      ( Type.Setter     )
			.id                     ( Type.Setter     )
			.ignoreParentAlpha      ( Type.Setter     )
			.ignoreParentScale      ( Type.Setter     )
			.intrinsic              ( TypeError('Cannot create intrinsic frames in Lua.') )
			.jumpNavigateEnabled    ( Type.Deprecated )
			.jumpNavigateStart      ( Type.Deprecated )
			.movable 		        ( Type.Setter     )
			.propagateHyperlinksToParent ( Type.Unsupported )
			.propagateKeyboardInput ( Type.Setter     )
			.protected              ( Type.Protected  )
			.registerForDrag		( Type.Togglable  )
			.resizable              ( Type.Setter     )
			.toplevel               ( Type.Setter     )
			.useParentLevel (function(object, enabled)
				if not enabled then return end;
				object:SetFrameLevel(object:GetParent():GetFrameLevel())
			end)
			{
				Frames {}; -- TODO: test
				Attributes {
					Attribute (function(object, props)

					end);
				};
				Animations {
					AnimationGroup
					.insert(function(object, props, ...)

					end) {
						--Animations here
					};
				};
				HitRectInsets (function(object, props) end);
				Layers {
					Layer .insert(function(object, props, ...) end) {
						FontString .insert(function(object, props, ...) end) {
							Color (function(object, props) end);
							Shadow .insert(function(object, props) end) {

							};
						};
					};
				};
			};
	};
}();

-------------------------------------------------------
XML:SetResolver(UIResolver)
-------------------------------------------------------