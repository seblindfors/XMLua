local XML = LibStub and LibStub('XMLua') or XMLua;
-------------------------------------------------------
-- Mappings
-------------------------------------------------------
local Resolver, Props = {}, XML:GetMetadata().Element;
local Schema, Renderer, ScriptBindingType;
-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local function ThrowError(message, elem)
	-- TODO: limit output length, it gets ridiculously detailed
	error(('%s\nin tag:\n%s\n'):format(message:gsub('^.+XMLuaParser.lua:%d+: ', ''), tostring(elem)), 4)
end

local function FindMethod(key, map, haystack)
	if map[key] then return map[key] end;
	local needle = key:lower():gsub('^set', '');
	for name, method in pairs(haystack) do
		if (not name:match('^Get') and name:gsub('^Set', ''):lower() == needle) then
			map[key] = method;
			print(('Mapping %s for %s'):format(key, name))
			return method;
		end
	end
end

local function CallMethodOnObject(object, method, ...)
	assert(object, 'Missing target widget.')
	assert(method, 'Missing target method.')
	local func = assert(FindMethod(method, Schema[object:GetObjectType()], getmetatable(object).__index),
		('Could not find target method for %q.'):format(method))
	return func(object, ...)
end

local function SetObjectProps(name, object, props)
	local index = getmetatable(object).__index;
	local map = Schema[name];
	for key, val in pairs(props) do
		local func = FindMethod(key, map, index);
		if not func then
			print(('Missing prop handler for %s: %s'):format(name, key))
		end
		if func then
			func(object, val)
		end
	end
	return object, props.parentKey;
end

local function CreateObjectFrame(objType, props, object)
	return SetObjectProps(objType, CreateFrame(objType,
		props.name,
		props.parent or object,
		props.inherits,
		props.id
	), props);
end

local function GetObjectRelative(object, query)
	if C_Widget.IsWidget(query) then return query end;
	if (type(query) ~= 'string') then return end;
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

local function SetObjectScript(scriptType, props, object, tag)
	local func = rawget(tag, Props.Content) or rawget(object, props.method) or _G[props['function']];
	local set  = (props.intrinsicOrder == nil and object.SetScript or object.HookScript)
	set(object, scriptType, func, ScriptBindingType[props.intrinsicOrder])
	if (scriptType == 'OnLoad') then
		func(object)
	end
end

local function Dimension(props, object, tag)
	return C_Widget.IsWidget(object) and {
		target = object;
		method = rawget(tag, Props.Name)
	} or {
		target = object.target;
		method = object.method .. rawget(tag, Props.Name);
	};
end

local function __(_, object)
	return object; -- returns the current object, essentially skip
end

-------------------------------------------------------
-- Schema
-------------------------------------------------------
Schema = setmetatable({
	Shared = {
		name = nop;
		inherits = nop;
		parentKey = nop;
		mixin = Mixin;
	};
}, {
	__index = function(self, key)
		return rawget(rawset(self, key, setmetatable({}, {__index = self.Shared})), key)
	end;
});

-------------------------------------------------------
-- Renderer
-------------------------------------------------------
Renderer = setmetatable({
	---------------------------------------------------
	AbsDimension = function(props, targetProps)
		return CallMethodOnObject(targetProps.target, targetProps.method, props() {x, y} )
	end;
	---------------------------------------------------
	Anchors = __;
	---------------------------------------------------
		Anchor = function(props, object)
			local relative = GetObjectRelative(object, props.relativeTo or props.relativeKey);
			local relativePoint = props.relativePoint;
			local x, y = props.x or 0, props.y or 0;
			if relativePoint then
				return object:SetPoint(props.point, relative, relativePoint, x, y)
			elseif relative then
				return object:SetPoint(props.point, relative, x, y)
			end
			return object:SetPoint(props.point, x, y)
		end;
	---------------------------------------------------
	Animations = __;
	---------------------------------------------------
		AnimationGroup = function(props, object)
			return SetObjectProps('AnimationGroup', object:CreateAnimationGroup(
				props.name
			), props)
		end;
	-------------------------------------------------------
	Attributes = __;
	-------------------------------------------------------
		Attribute = function(props, object)
			local name, value = props() {name, value};
			assert(type(name) ~= nil, 'Attribute name is nil.')
			assert(type(value) ~= nil, 'Attribute value is nil.')
			if (props.type) then
				assert(type(value) == props.type, 'Attribute has invalid type.')
			end
			return object:SetAttribute(name, value)
		end;
	-------------------------------------------------------
	Frames = __;
	-------------------------------------------------------
	Layers = __;
	-------------------------------------------------------
		Layer = __;
		---------------------------------------------------
			FontString = function(props, object, _, parentProps)
				return SetObjectProps('FontString', object:CreateFontString(
					props.name,
					parentProps.level,
					props.inherits
				), props)
			end;
			Texture = function(props, object, _, parentProps)
				return SetObjectProps('Texture', object:CreateTexture(
					props.name,
					parentProps.level,
					props.inherits,
					parentProps.textureSubLevel
				), props)
			end;
			Color = function(props, object, tag)
				local color = _G[props.color] or props.color or CreateColor(props() {r, g, b, a})
				assert(color:GetRGB())
				if C_Widget.IsWidget(object) then
					return (object.SetColorTexture or object.SetTextColor)(object, color:GetRGBA())
				end
				return CallMethodOnObject(object.target, object.method .. 'Color', color:GetRGBA())
			end;
			Shadow = Dimension;
			Offset = Dimension;
	-------------------------------------------------------
	KeyValues = __;
	-------------------------------------------------------
		KeyValue = function(props, object)
			assert(type(props.key) ~= nil, 'Key is nil in key-value pair.')
			assert(type(props.value) ~= nil, 'Value is nil in key-value pair.')
			local key, value;
			if (props.keyType == 'global') then
				key = _G[props.key];
			else
				key = props.key;
			end
			if (props.type == 'global') then
				value = _G[props.value];
			else
				value = props.value;
			end
			object[key] = value;
			assert(object[key] ~= nil, ('Failed to set key-value pair: [%q] = %q'):format(tostring(key), tostring(value)))
		end;
	-------------------------------------------------------
	ResizeBounds = __;
	-------------------------------------------------------
		minResize = Dimension;
		maxResize = Dimension;
	-------------------------------------------------------
	Scripts = __;
	-------------------------------------------------------
	Size = function(props, object, tag)
		local x, y = props() {x, y};
		if (x and y) then
			return object:SetSize(x, y)
		elseif (x) then
			return object:SetWidth(x)
		elseif (y) then
			return object:SetHeight(y)
		end
		return Dimension(props, object, tag)
	end;
	---------------------------------------------------
}, {
	__index = function(self, objType)
		return rawget(rawset(self, objType, (objType:match('^On%w+') or objType:match('^P%w+Click$')) and
			GenerateClosure(SetObjectScript, objType) or
			GenerateClosure(CreateObjectFrame, objType)
		), objType)
	end
})

--[[ 
	-- TODO: map all

	<xs:element name="HitRectInsets" type="Inset" substitutionGroup="FrameField"
	<xs:element name="Layers" substitutionGroup="FrameField"
	<xs:element name="Frames" substitutionGroup="FrameField"

	<xs:element name="Anchors" substitutionGroup="LayoutField"
	<xs:element name="Scripts" type="ScriptsType" substitutionGroup="LayoutField"
	<xs:element name="Animations" substitutionGroup="LayoutField"
]]

-------------------------------------------------------
-- Resolver
-------------------------------------------------------
function Resolver:__call(...)
	local name    = rawget(self, Props.Name)
	local props   = rawget(self, Props.Attributes)
	local content = rawget(self, Props.Content)

	local object, parentKey = Renderer[name](props, ...)
	if (object and type(content) == 'table') then
		for index, elem in ipairs(content) do
			local isOK, result, childKey = pcall(elem, object, elem, props, name)
			if not isOK then
				ThrowError(result, elem)
			end
			if childKey then
				rawset(object, childKey, result)
			end
		end
	end

	--print('Test:', rawget(self, Props.Name))
	return object, parentKey;
end

XML:SetResolver(Resolver)

-------------------------------------------------------
-- Misc
-------------------------------------------------------
ScriptBindingType = setmetatable({
	precall  = LE_SCRIPT_BINDING_TYPE_INTRINSIC_PRECALL;
	postcall = LE_SCRIPT_BINDING_TYPE_INTRINSIC_POSTCALL;
}, {__index = function() return LE_SCRIPT_BINDING_TYPE_EXTRINSIC end})
