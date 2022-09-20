local XML = LibStub and LibStub('XMLua') or XMLua;
-------------------------------------------------------
-- Mappings
-------------------------------------------------------
local Resolver, Props = {}, XML:GetMetadata().Element;
local Schema, Renderer, ScriptBindingType;
-------------------------------------------------------
-- Helpers
-------------------------------------------------------
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

local function SetObjectScript(scriptType, props, object, _, tag)
	local func = rawget(tag, Props.Content) or rawget(object, props.method) or _G[props['function']];
	local set  = (props.intrinsicOrder == nil and object.SetScript or object.HookScript)
	set(object, scriptType, func, ScriptBindingType[props.intrinsicOrder])
	if (scriptType == 'OnLoad') then
		func(object)
	end
end

local function ThrowError(message, elem)
	error(('%s\nin tag:\n%s\n'):format(message:gsub('^.+XMLuaParser.lua:%d+: ', ''), tostring(elem)), 4)
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
		Attribute = function(props, object, _, tag)
			assert(type(props.name) ~= nil, 'Attribute name is nil.')
			assert(type(props.value) ~= nil, 'Attribute value is nil.')
			if (props.type) then
				assert(type(props.value) == props.type, 'Attribute has invalid type.')
			end
			return object:SetAttribute(props.name, props.value)
		end;
	-------------------------------------------------------
	Frames = __;
	-------------------------------------------------------
	Layers = __;
	-------------------------------------------------------
		Layer = __;
		---------------------------------------------------
			FontString = function(props, object, parentProps)
				return SetObjectProps('FontString', object:CreateFontString(
					props.name,
					parentProps.level,
					props.inherits
				), props)
			end;
			Texture = function(props, object, parentProps)
				return SetObjectProps('Texture', object:CreateTexture(
					props.name,
					parentProps.level,
					props.inherits,
					parentProps.textureSubLevel
				), props)
			end;
			Color = function(props, object)
				(object.SetColorTexture or object.SetTextColor)(object, props.r, props.g, props.b, props.a)
			end;
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
	Scripts = __;
	-------------------------------------------------------
	Size = function(props, object)
		local x, y = props.x, props.y;
		if (x and y) then
			object:SetSize(x, y)
		elseif (x) then
			object:SetWidth(x)
		elseif (y) then
			object:SetHeight(y)
		end
	end;
	---------------------------------------------------
}, {
	__index = function(self, objType)
		return rawget(rawset(self, objType, (objType:match('^On%w+')) and
			GenerateClosure(SetObjectScript, objType) or
			GenerateClosure(CreateObjectFrame, objType)
		), objType)
	end
})

--[[ 
	-- TODO: map all

	<xs:element name="TitleRegion" type="ui:LayoutFrameType" substitutionGroup="FrameField"
	<xs:element name="ResizeBounds" substitutionGroup="FrameField"
	<xs:element name="HitRectInsets" type="Inset" substitutionGroup="FrameField"
	<xs:element name="Layers" substitutionGroup="FrameField"
	<xs:element name="Attributes" type="AttributesType" substitutionGroup="FrameField"
	<xs:element name="Frames" substitutionGroup="FrameField"

	<xs:element name="Size" type="Dimension" substitutionGroup="LayoutField"
	<xs:element name="Anchors" substitutionGroup="LayoutField"
	<xs:element name="Scripts" type="ScriptsType" substitutionGroup="LayoutField"
	<xs:element name="KeyValues" type="KeyValuesType" substitutionGroup="LayoutField"
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
			local isOK, result, childKey = pcall(elem, object, props, elem)
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
