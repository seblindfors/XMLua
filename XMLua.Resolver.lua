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
-- Error handling
-------------------------------------------------------
local function strip(msg) return (msg:gsub('.+%.lua:%d+: ', '%1', 1)) end; -- TODO

local function ThrowException(message, elem)
	error(('%s\nin tag:\n%s\n'):format(strip(message), tostring(elem)), 6)
end

local function Assert(isOK, message, elem)
	if not isOK then
		ThrowException(message, elem)
	end
end

-------------------------------------------------------
-- Interface resolver
-------------------------------------------------------
XML:SetResolver({__call = function(
	self        , -- @param <Element />
	targetObj   , -- @param object on which rendering should occur
	parentTag   , -- @param enveloping tag
	parentProps , -- @param enveloping props
	renderer    ) -- @param renderer to be used to render the element

	local name, props, content = Props.Get(self)

	local render = (renderer or Schema)[name]; -- TODO: handle calling xml on existing objects
	Assert(render, ('Element %s not recognized in %s.'):format(name, parentName or 'root'), self) -- TODO: parentName

	local isOK, object = pcall(
		render      , -- @param rendering function
		-- schema   , -- @param implicit schema object
		targetObj   , -- @param target object to render on
		props       , -- @param <Element properties {...} />
		self        , -- @param <Element />
		parentProps , -- @param <Parent properties{...} /> 
		parentTag   ) -- @param <Parent />

	Assert(isOK, object, self)

	if (object and type(content) == 'table') then
		for index, elem in ipairs(content) do
			local isOK, result = pcall(elem, object, self, props, render)
			Assert(isOK, result, elem)
		end
	end

	return object;
end})

-------------------------------------------------------
Metadata.Loaded  = true;
Metadata.Factory = nil;
-------------------------------------------------------