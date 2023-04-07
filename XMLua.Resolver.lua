local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML and XML:GetMetadata();

if not XML or Metadata.Loaded then return end;

-------------------------------------------------------
-- Generated schema and pretty printing
-------------------------------------------------------
local Schema = Metadata.Schema.UI;
local Props  = Metadata.Element;

Props.Printer = function(value)
	if C_Widget.IsWidget(value) then
		return value:GetDebugName()
	end
	return tostring(value)
end

-------------------------------------------------------
-- Interface resolver
-------------------------------------------------------
local Resolver = {};

function Resolver:Assert(message, elem)
	if not self then
		Resolver.ThrowException(message, elem)
	end
end

function Resolver:ThrowException(elem)
	error(('%s\nin tag:\n%s\n'):format(self, tostring(elem)), 4)
end

local UIResolver = {__call = function(
	self        , -- @param <Element />
	targetObj   , -- @param object on which rendering should occur
	parentTag   , -- @param enveloping tag
	parentProps , -- @param enveloping props
	renderer    ) -- @param renderer to be used to render the element

	local name, props, content = Props.Get(self)

	local render = (renderer or Schema)[name]; -- TODO: handle calling xml on existing objects
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

	if (object and type(content) == 'table') then
		for index, elem in ipairs(content) do
			local isOK, result = pcall(elem, object, self, props, render)
			Resolver.Assert(isOK, result, elem)
		end
	end

	return object;
end};

-------------------------------------------------------
XML:SetResolver(UIResolver)
-------------------------------------------------------
Metadata.Loaded  = true;
Metadata.Factory = nil;
-------------------------------------------------------