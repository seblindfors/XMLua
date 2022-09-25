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

local function SetObjectScript(scriptType, props, object, tag)
	local func = rawget(tag, Props.Content) or rawget(object, props.method) or _G[props['function']];
	local set  = (props.intrinsicOrder == nil and object.SetScript or object.HookScript)
	set(object, scriptType, func, ScriptBindingType[props.intrinsicOrder])
	return func;
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

local function SetPoint(func, props, object, tag)
	local relative = GetObjectRelative(object, props.relativeTo or props.relativeKey);
	local relativePoint = props.relativePoint;
	local offX, offY = props.x, props.y;
	if (not offX and not offY) then
		local children = rawget(tag, Props.Content)
		local offset = children and children[1];
		if (offset) then
			offX, offY = rawget(offset, Props.Attributes)() {x, y};
		end
	end
	offX, offY = offX or 0, offY or 0;
	if relativePoint then
		return func(object, props.point, relative, relativePoint, offX, offY)
	elseif relative then
		return func(object, props.point, relative, offX, offY)
	end
	return func(object, props.point, offX, offY)
end

local function CreateObjectFrame(objType, props, object)
	return SetObjectProps(objType, CreateFrame(objType,
		props.name,
		props.parent or object,
		props.inherits,
		props.id
	), props);
end

local function CreateLayoutFrame(props, object, tag, parentProps)
	local objType = rawget(tag, Props.Name)
	return SetObjectProps(objType, CallMethodOnObject(object, 'Create' .. objType,
		props.name,
		parentProps.level,
		props.inherits,
		props.textureSubLevel
	), props)
end

local function EvaluateString(query)
	return assert(loadstring(('return %s'):format(query)))()
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

local function RenderOnParent(_, object)
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
	Anchors = RenderOnParent;
	---------------------------------------------------
		Anchor = function(props, object, tag)
			return SetPoint(object.SetPoint, props, object, tag)
		end;
	---------------------------------------------------
	Animations = RenderOnParent;
	---------------------------------------------------
		AnimationGroup = function(props, object)
			return SetObjectProps('AnimationGroup', object:CreateAnimationGroup(
				props.name
			), props)
		end;
	-------------------------------------------------------
	Attributes = RenderOnParent;
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
	Frames = RenderOnParent;
	-------------------------------------------------------
	HitRectInsets = function(props, object)
		return object:SetHitRectInsets(props() {left, right, top, bottom})
	end;
	-------------------------------------------------------
	Layers = RenderOnParent;
	-------------------------------------------------------
		Layer = RenderOnParent;
		---------------------------------------------------
			Color = function(props, object)
				local color = _G[props.color] or props.color or CreateColor(props() {r, g, b, a})
				assert(color:GetRGB())
				if C_Widget.IsWidget(object) then
					return (object.SetColorTexture or object.SetTextColor)(object, color:GetRGBA())
				end
				return CallMethodOnObject(object.target, object.method .. 'Color', color:GetRGBA())
			end;
			-----------------------------------------------
			FontString = CreateLayoutFrame;
			-----------------------------------------------
			Line = CreateLayoutFrame;
			-----------------------------------------------
				StartAnchor = function(props, object, tag)
					return SetPoint(object.SetStartPoint, props, object, tag)
				end;
				-------------------------------------------
				EndAnchor = function(props, object, tag)
					return SetPoint(object.SetEndPoint, props, object, tag)
				end;
			-----------------------------------------------
			MaskTexture = CreateLayoutFrame;
			-----------------------------------------------
				MaskedTextures = RenderOnParent;
				-------------------------------------------
					MaskedTexture = function(props, object)
						local childKey, target = props() {childKey, target};
						if not C_Widget.IsWidget(target) then
							target = assert(childKey and assert(object:GetParent()[childKey],
								'Child key does not exist on parent.')
								or EvaluateString(target),
								'Target mask texture does not exist.'
							);
						end
						return target:AddMaskTexture(object)
					end;
			-----------------------------------------------
			Texture = CreateLayoutFrame;
			-----------------------------------------------
			Shadow = Dimension;
			-----------------------------------------------
			Offset = function(props, object, tag)
				if (props.x or props.y) then
					return Renderer.AbsDimension(props, object)
				end
				return Dimension(props, object, tag)
			end;
	-------------------------------------------------------
	KeyValues = RenderOnParent;
	-------------------------------------------------------
		KeyValue = function(props, object)
			assert(type(props.key) ~= nil, 'Key is nil in key-value pair.')
			assert(type(props.value) ~= nil, 'Value is nil in key-value pair.')
			local key, value;
			if (props.keyType == 'global') then
				key = EvaluateString(props.key);
			else
				key = props.key;
			end
			if (props.type == 'global') then
				value = EvaluateString(props.value);
			else
				value = props.value;
			end
			object[key] = value;
			assert(object[key] ~= nil, ('Failed to set key-value pair: [%q] = %q'):format(tostring(key), tostring(value)))
		end;
	-------------------------------------------------------
	ResizeBounds = RenderOnParent;
	-------------------------------------------------------
		minResize = Dimension;
		maxResize = Dimension;
	-------------------------------------------------------
	Scripts = RenderOnParent;
	-------------------------------------------------------
		OnLoad = function(props, object, tag)
			SetObjectScript('OnLoad', props, object, tag)(object)
		end;
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
	-------------------------------------------------------
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

	<xs:element name="Animations" substitutionGroup="LayoutField"

	<xs:element name="Translation" type="TranslationType" substitutionGroup="Animation"
	<xs:element name="LineTranslation" type="LineTranslationType" substitutionGroup="Animation"
	<xs:element name="Rotation" type="RotationType" substitutionGroup="Animation"
	<xs:element name="Scale" type="ScaleType" substitutionGroup="Animation"
	<xs:element name="LineScale" type="LineScaleType" substitutionGroup="Animation"
	<xs:element name="Alpha" type="AlphaType" substitutionGroup="Animation"
	<xs:element name="Path" type="PathType" substitutionGroup="Animation"
	<xs:element name="FlipBook" type="FlipBookType" substitutionGroup="Animation"
	<xs:element name="TextureCoordTranslation" type="TextureCoordTranslationType" substitutionGroup="Animation"

	<xs:element name="Frames" substitutionGroup="FrameField"

	<xs:element name="UnitPositionFrame" type="UnitPositionFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="Button" type="ButtonType" substitutionGroup="ui:FrameRef"/
	<xs:element name="CheckButton" type="CheckButtonType" substitutionGroup="ui:FrameRef"/
	<xs:element name="StatusBar" type="StatusBarType" substitutionGroup="ui:FrameRef"/
	<xs:element name="Slider" type="SliderType" substitutionGroup="ui:FrameRef"/
	<xs:element name="EditBox" type="EditBoxType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ColorSelect" type="ui:ColorSelectType" substitutionGroup="ui:FrameRef"/
	<xs:element name="Model" type="ModelType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ModelFFX" type="ModelType" substitutionGroup="ui:FrameRef"/
	<xs:element name="SimpleHTML" type="ui:SimpleHTMLType" substitutionGroup="ui:FrameRef"/
	<xs:element name="MessageFrame" type="MessageFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ScrollingMessageFrame" type="ScrollingMessageFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ScrollFrame" type="ScrollFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="MovieFrame" type="MovieFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="WorldFrame" type="WorldFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="GameTooltip" type="GameTooltipType" substitutionGroup="ui:FrameRef"/
	<xs:element name="Cooldown" type="CooldownType" substitutionGroup="ui:FrameRef"/
	<xs:element name="QuestPOIFrame" type="QuestPOIFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ArchaeologyDigSiteFrame" type="ArchaeologyDigSiteFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ScenarioPOIFrame" type="ScenarioPOIFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="Minimap" type="MinimapType" substitutionGroup="ui:FrameRef"/
	<xs:element name="PlayerModel" type="PlayerModelType" substitutionGroup="ui:FrameRef"/
	<xs:element name="DressUpModel" type="DressUpModelType" substitutionGroup="ui:FrameRef"/
	<xs:element name="TabardModel" type="TabardModelType" substitutionGroup="ui:FrameRef"/
	<xs:element name="CinematicModel" type="CinematicModelType" substitutionGroup="ui:FrameRef"/
	<xs:element name="UiCamera" type="UiCameraType" substitutionGroup="ui:FrameRef"/
	<xs:element name="TaxiRouteFrame" type="TaxiRouteFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="Browser" type="BrowserType" substitutionGroup="ui:FrameRef"/
	<xs:element name="Checkout" type="CheckoutType" substitutionGroup="ui:FrameRef"/
	<xs:element name="FogOfWarFrame" type="FogOfWarFrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ModelScene" type="ModelSceneType" substitutionGroup="ui:FrameRef"/
	<xs:element name="OffScreenFrame" type="FrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ContainedAlertFrame" type="ButtonType" substitutionGroup="ui:FrameRef"/
	<xs:element name="DropDownToggleButton" type="ButtonType" substitutionGroup="ui:FrameRef"/
	<xs:element name="EventEditBox" type="EditBoxType" substitutionGroup="ui:FrameRef"/
	<xs:element name="EventFrame" type="FrameType" substitutionGroup="ui:FrameRef"/
	<xs:element name="EventButton" type="ButtonType" substitutionGroup="ui:FrameRef"/
	<xs:element name="ItemButton" type="ButtonType" substitutionGroup="ui:FrameRef"/
	<xs:element name="TestFrame" type="FrameType" substitutionGroup="ui:FrameRef"/
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
