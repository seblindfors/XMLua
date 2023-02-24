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
	for name, method in pairs(haystack or getmetatable(object).__index) do
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
	local func = assert(FindMethod(method, Schema[object:GetObjectType()]),
		('Could not find target method for %q.'):format(method))
	return func(object, ...)
end

local function SetObjectProps(objType, object, props)
	local index = getmetatable(object).__index;
	local map = Schema[objType];
	for key, val in pairs(props) do
		local func = FindMethod(key, map, index);
		if not func then
			print(('Missing prop handler for %s: %s'):format(objType, key))
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
	local offX, offY = props() {x, y};
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

-------------------------------------------------------
-- Factory
-------------------------------------------------------
local function CreateObjectFrame(objType, props, object)
	return SetObjectProps(objType, CreateFrame(objType,
		props.name,
		props.parent or object,
		props.inherits,
		props.id
	), props);
end

local function CreateLayoutFrame(objType, props, object, parentProps)
	return SetObjectProps(objType, CallMethodOnObject(object, 'Create' .. objType,
		props.name,
		parentProps.level,
		props.inherits,
		props.textureSubLevel
	), props)
end

-------------------------------------------------------
-- Types
-------------------------------------------------------
local function LayoutFrame(props, object, tag, parentProps)
	local objType = rawget(tag, Props.Name)
	return CreateLayoutFrame(objType, props, object, parentProps)
end

local function Reference(query)
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

local function TextureType(props, object, tag, parentProps)
	local objType = rawget(tag, Props.Name)
	local frame = CreateLayoutFrame('Texture', props, object, parentProps)
	CallMethodOnObject(object, 'Set'..objType, frame)
	return frame;
end

local function ComplexType(_, object)
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
	Anchors = ComplexType;
	---------------------------------------------------
		Anchor = function(props, object, tag)
			return SetPoint(object.SetPoint, props, object, tag)
		end;
	---------------------------------------------------
	Animations = ComplexType;
	---------------------------------------------------
		AnimationGroup = function(props, object)
			return SetObjectProps('AnimationGroup', object:CreateAnimationGroup(
				props.name
			), props)
		end;
	-------------------------------------------------------
	Attributes = ComplexType;
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
	Frames = ComplexType;
	-------------------------------------------------------
	HitRectInsets = function(props, object)
		return object:SetHitRectInsets(props() {left, right, top, bottom})
	end;
	-------------------------------------------------------
	Layers = ComplexType;
	-------------------------------------------------------
		Layer = ComplexType;
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
			FontString = LayoutFrame;
			-----------------------------------------------
			Line = LayoutFrame;
			-----------------------------------------------
				StartAnchor = function(props, object, tag)
					return SetPoint(object.SetStartPoint, props, object, tag)
				end;
				-------------------------------------------
				EndAnchor = function(props, object, tag)
					return SetPoint(object.SetEndPoint, props, object, tag)
				end;
			-----------------------------------------------
			MaskTexture = LayoutFrame;
			-----------------------------------------------
				MaskedTextures = ComplexType;
				-------------------------------------------
					MaskedTexture = function(props, object)
						local childKey, target = props() {childKey, target};
						if not C_Widget.IsWidget(target) then
							target = assert(childKey and assert(object:GetParent()[childKey],
								'Child key does not exist on parent.')
								or Reference(target),
								'Target mask texture does not exist.'
							);
						end
						return target:AddMaskTexture(object)
					end;
			-----------------------------------------------
			Texture = LayoutFrame;
			-----------------------------------------------
				DisabledTexture = TextureType;
				HighlightTexture = TextureType;
				NormalTexture = TextureType;
				PushedTexture = TextureType;
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
	KeyValues = ComplexType;
	-------------------------------------------------------
		KeyValue = function(props, object)
			assert(type(props.key) ~= nil, 'Key is nil in key-value pair.')
			assert(type(props.value) ~= nil, 'Value is nil in key-value pair.')
			local key, value;
			if (props.keyType == 'global') then
				key = Reference(props.key);
			else
				key = props.key;
			end
			if (props.type == 'global') then
				value = Reference(props.value);
			else
				value = props.value;
			end
			object[key] = value;
			assert(object[key] ~= nil, ('Failed to set key-value pair: [%q] = %q'):format(tostring(key), tostring(value)))
		end;
	-------------------------------------------------------
	ResizeBounds = ComplexType;
	-------------------------------------------------------
		minResize = Dimension;
		maxResize = Dimension;
	-------------------------------------------------------
	Scripts = ComplexType;
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

	<xs:element name="Actor" type="ModelSceneActorType" substitutionGroup="UiField"/>
	<xs:element name="AnimationGroup" type="AnimationGroupType" substitutionGroup="UiField"/>
	<xs:element name="Attribute" type="AttributeType"/>
	<xs:element name="Attributes" type="AttributesType" substitutionGroup="FrameField"/>
	<xs:element name="BarColor" type="ui:ColorType" substitutionGroup="StatusBarField"/>
	<xs:element name="ControlPoints" type="ControlPointsType"/>
	<xs:element name="Font" type="FontType"/>
	<xs:element name="FontFamily" type="FontFamilyType" substitutionGroup="UiField"/>
	<xs:element name="FontHeight" type="Value"/>
	<xs:element name="FontHeight" type="Value"/>
	<xs:element name="FontStringHeader1" type="ui:FontStringType"/>
	<xs:element name="FontStringHeader2" type="ui:FontStringType"/>
	<xs:element name="FontStringHeader3" type="ui:FontStringType"/>
	<xs:element name="Frame" type="FrameType" substitutionGroup="FrameRef"/>
	<xs:element name="Gradient" type="GradientType" substitutionGroup="TextureField"/>
	<xs:element name="KeyValue" type="KeyValueType"/>
	<xs:element name="KeyValues" type="KeyValuesType"/>
	<xs:element name="LayoutFrame" type="LayoutFrameType"/
	<xs:element name="Member" type="FontMemberType"/>
	<xs:element name="Offset" type="Dimension"/>
	<xs:element name="Origin" type="AnimOriginType"/>
	<xs:element name="Rect" type="RectType"/>
	<xs:element name="ScopedModifier" type="ScopedModifierType" minOccurs="0" maxOccurs="unbounded"/>
	<xs:element name="Scripts" type="ActorScriptsType" minOccurs="0" maxOccurs="unbounded"/>
	<xs:element name="Scripts" type="AnimGroupScriptsType"/>
	<xs:element name="Scripts" type="AnimScriptsType"/>
	<xs:element name="Shadow" type="ShadowType"/>
	<xs:element name="TextInsets" type="Inset"/>
	<xs:element name="ViewInsets" type="Inset"/>

	<xs:element name="KeyValues" type="KeyValuesType" substitutionGroup="LayoutField"/>
	<xs:element name="Scripts" type="ScriptsType" substitutionGroup="LayoutField"/>

	<xs:element name="AnimationRef" abstract="true" substitutionGroup="UiField"/>
	<xs:element name="ButtonField" abstract="true"/>
	<xs:element name="CheckButtonField" abstract="true"/>
	<xs:element name="FrameField" abstract="true"/>
	<xs:element name="FrameRef" abstract="true" type="FrameRefType" substitutionGroup="LayoutFrameRef"/>
	<xs:element name="LayoutField" abstract="true"/>
	<xs:element name="LayoutFrameRef" abstract="true" type="LayoutFrameRefType" substitutionGroup="UiField"/>
	<xs:element name="ScrollFrameField" abstract="true"/>
	<xs:element name="StatusBarField" abstract="true"/>
	<xs:element name="TextureField" abstract="true"/>
	<xs:element name="UiField" abstract="true"/>

	<xs:element name="FontString" type="FontStringType" substitutionGroup="LayoutFrameRef"/>
	<xs:element name="Line" type="LineType" substitutionGroup="LayoutFrameRef"/>

	<xs:element name="BarTexture" type="TextureType" substitutionGroup="StatusBarField"/>
	<xs:element name="BlingTexture" type="TextureType"/>
	<xs:element name="CheckedTexture" type="TextureType" substitutionGroup="CheckButtonField"/>
	<xs:element name="ColorValueTexture" type="TextureType"/>
	<xs:element name="ColorValueThumbTexture" type="TextureType"/>
	<xs:element name="ColorWheelTexture" type="TextureType"/>
	<xs:element name="ColorWheelThumbTexture" type="TextureType"/>
	<xs:element name="DisabledCheckedTexture" type="TextureType" substitutionGroup="CheckButtonField"/>
	<xs:element name="EdgeTexture" type="TextureType"/>
	<xs:element name="SwipeTexture" type="TextureType"/>
	<xs:element name="Texture" type="TextureType" substitutionGroup="LayoutFrameRef"/>
	<xs:element name="ThumbTexture" type="TextureType"/>

	<xs:element name="Alpha" type="AlphaType" substitutionGroup="AnimationRef"/>
	<xs:element name="Animation" type="AnimationType" substitutionGroup="AnimationRef"/>
	<xs:element name="FlipBook" type="FlipBookType" substitutionGroup="AnimationRef"/>
	<xs:element name="LineScale" type="LineScaleType" substitutionGroup="AnimationRef"/>
	<xs:element name="LineTranslation" type="LineTranslationType" substitutionGroup="AnimationRef"/>
	<xs:element name="Path" type="PathType" substitutionGroup="AnimationRef"/>
	<xs:element name="Rotation" type="RotationType" substitutionGroup="AnimationRef"/>
	<xs:element name="Scale" type="ScaleType" substitutionGroup="AnimationRef"/>
	<xs:element name="TextureCoordTranslation" type="TextureCoordTranslationType" substitutionGroup="AnimationRef"/>
	<xs:element name="Translation" type="TranslationType" substitutionGroup="AnimationRef"/>

	<xs:element name="ButtonText" type="FontStringType" substitutionGroup="ButtonField"/>
	<xs:element name="DisabledFont" type="ButtonStyleType" substitutionGroup="ButtonField"/>
	<xs:element name="HighlightFont" type="ButtonStyleType" substitutionGroup="ButtonField"/>
	<xs:element name="NormalFont" type="ButtonStyleType" substitutionGroup="ButtonField"/>
	<xs:element name="PushedTextOffset" type="Dimension" substitutionGroup="ButtonField"/>

	<xs:element name="Color" type="ColorType" substitutionGroup="TextureField"/>
	<xs:element name="Color" type="ColorType"/>
	<xs:element name="FogColor" type="ColorType"/>
	<xs:element name="HighlightColor" type="ColorType"/>
	<xs:element name="MaxColor" type="ColorType"/>
	<xs:element name="MinColor" type="ColorType"/>
	<xs:element name="DisabledColor" type="ColorType" substitutionGroup="ButtonField"/>
	<xs:element name="HighlightColor" type="ColorType" substitutionGroup="ButtonField"/>
	<xs:element name="NormalColor" type="ColorType" substitutionGroup="ButtonField"/>

	<xs:element name="ArchaeologyDigSiteFrame" type="ArchaeologyDigSiteFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="Browser" type="BrowserType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="Button" type="ButtonType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="CheckButton" type="CheckButtonType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="Checkout" type="CheckoutType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="CinematicModel" type="CinematicModelType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ColorSelect" type="ui:ColorSelectType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ContainedAlertFrame" type="ButtonType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="Cooldown" type="CooldownType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="DressUpModel" type="DressUpModelType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="DropDownToggleButton" type="ButtonType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="EditBox" type="EditBoxType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="EventButton" type="ButtonType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="EventEditBox" type="EditBoxType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="EventFrame" type="FrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="FogOfWarFrame" type="FogOfWarFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="GameTooltip" type="GameTooltipType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ItemButton" type="ButtonType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="MessageFrame" type="MessageFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="Minimap" type="MinimapType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="Model" type="ModelType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ModelFFX" type="ModelType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ModelScene" type="ModelSceneType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="MovieFrame" type="MovieFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="OffScreenFrame" type="FrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="PlayerModel" type="PlayerModelType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="QuestPOIFrame" type="QuestPOIFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ScenarioPOIFrame" type="ScenarioPOIFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ScrollFrame" type="ScrollFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="ScrollingMessageFrame" type="ScrollingMessageFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="SimpleHTML" type="ui:SimpleHTMLType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="Slider" type="SliderType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="StatusBar" type="StatusBarType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="TabardModel" type="TabardModelType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="TaxiRouteFrame" type="TaxiRouteFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="TestFrame" type="FrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="UiCamera" type="UiCameraType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="UnitPositionFrame" type="UnitPositionFrameType" substitutionGroup="ui:FrameRef"/>
	<xs:element name="WorldFrame" type="WorldFrameType" substitutionGroup="ui:FrameRef"/>
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
