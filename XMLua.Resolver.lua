local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML and XML:GetMetadata();

if not XML or Metadata.Loaded then return end;

-------------------------------------------------------
-- Generated schema and pretty printing
-------------------------------------------------------
local Schema = Metadata.Schema.UI;
local Props  = Metadata.Element;
local Assert = Metadata.Assert;
local Trace  = Metadata.StartTrace;

-------------------------------------------------------
-- Interface resolver
-------------------------------------------------------
XML:SetResolver({__call = function(
	self        , -- @param <Element />
	targetObj   , -- @param object on which rendering should occur
	parentProps , -- @param enveloping props
	parentTag   , -- @param enveloping tag
	this        ) -- @param renderer to be used to render the element

	if not this then Trace() end;
	local name, props, content = Props.Get(self)

	local render = (this or Schema)[name]; -- TODO: handle calling xml on existing objects
	Assert(render, ('Element %s not recognized in %s.'):format(name, parentName or 'root'), self) -- TODO: parentName

	local isOK, object = pcall(
		render      , -- @param rendering function
		-- schema   , -- @param implicit schema object
		targetObj   , -- @param target object to render on
		props       , -- @param <Element properties {...} />
		self        , -- @param <Element />
		parentProps , -- @param <Parent properties{...} /> 
		parentTag   , -- @param <Parent />
		this        ) -- @param parent renderer

	Assert(isOK, object, self)

	if (object and type(content) == 'table') then
		for index, elem in ipairs(content) do
			local isOK, result = pcall(elem, object, props, self, render)
			Assert(isOK, result, self)
		end
	end

	return object;
end})

-------------------------------------------------------
Metadata.Loaded  = true;
Metadata.Factory = nil;
-------------------------------------------------------