local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML and XML:GetMetadata();

if not XML or Metadata.Loaded then return end;
local Abstract, UI = XML:SetResolver(Metadata.Factory.Resolver)(Metadata.Factory) {
	Abstract {
		-----------------------------------------------
		Enum {
		-----------------------------------------------
			FRAMEPOINT {
				TOPLEFT     (1);
				TOPRIGHT    (2);
				BOTTOMLEFT  (3);
				BOTTOMRIGHT (4);
				TOP         (5);
				BOTTOM      (6);
				LEFT        (7);
				RIGHT       (8);
				CENTER      (9);
			};
			FRAMESTRATA {
				PARENT      (1);
				BACKGROUND  (2);
				LOW         (3);
				MEDIUM      (4);
				HIGH        (5);
				DIALOG      (6);
				FULLSCREEN  (7);
				FULLSCREEN_DIALOG (8);
				TOOLTIP     (9);
			};
			DRAWLAYER {
				BACKGROUND  (1);
				BORDER      (2);
				ARTWORK     (3);
				OVERLAY     (4);
				HIGHLIGHT   (5);
			};
		};

		-----------------------------------------------
		Object
		-----------------------------------------------
		. parentKey   ( AND(OR(Type.Number, Type.String), Eval.Setter) )
		. parentArray ( Eval.ParentArray );

		-----------------------------------------------
		Resizing
		-----------------------------------------------
		. scale ( AND(Type.Number, Eval.Setter) )
		{
			-------------------------------------------
			Anchors
			-------------------------------------------
			. insert( Method.Forward )
			{
				---------------------------------------
				Anchor
				---------------------------------------
				. point         ( AND(Type.Enum.FRAMEPOINT, Type.String) )
				. relativeKey   ( Type.String  )
				. relativeTo    ( OR(Type.String, Type.Widget) )
				. relativePoint ( AND(Type.Enum.FRAMEPOINT, Type.String) )
				. x             ( Type.Number  )
				. y             ( Type.Number  )
				. insert        ( AND(Method.Validate, Method.Point) )
				{
					-----------------------------------
					Offset
					-----------------------------------
					. x      ( Type.Number )
					. y      ( Type.Number )
					. insert ( Method.Validate )
					{
						-------------------------------
						AbsDimension ( Method.Validate )
						-------------------------------
						. x ( Type.Number )
						. y ( Type.Number );
					};
				};
			};
			-------------------------------------------
			Size
			-------------------------------------------
			. x      ( Type.Number )
			. y      ( Type.Number )
			. insert ( Method.Size )
			{
				---------------------------------------
				AbsDimension ( Method.Size )
				---------------------------------------
				. x ( Type.Number )
				. y ( Type.Number );
			};
		};

		-----------------------------------------------
		ScriptRegion
		-----------------------------------------------
		{
			-------------------------------------------
			Scripts
			-------------------------------------------
			. resolver(function() end)
			{
				OnLoad ( function(object, props, ...) end );
			};
		};

		-----------------------------------------------
		LayoutFrame
		-----------------------------------------------
		. extend {
			Abstract {
				Object       {};
				Resizing     {};
				ScriptRegion {};
			};
		}
		. alpha              ( AND(Type.Number, Eval.Setter) )
		. enableMouse        ( AND(Type.Bool, Eval.Togglable) )
		. enableMouseClicks  ( AND(Type.Bool, Eval.SetMouseClickEnabled) )
		. enableMouseMotion  ( AND(Type.Bool, Eval.SetMouseMotionEnabled) )
		. hidden             ( AND(Type.Bool, Eval(function(object, hide) object:SetShown(not hide) end)) )
		. inherits           ( Type.String      )
		. mixin              ( Type.Table       )
		. name               ( Type.String      )
		. parent             ( AND(OR(Type.String, Type.Frame), Eval.Setter) )
		. passThroughButtons ( Eval.Setter      )
		. secureMixin        ( Type.Protected   )
		. secureReferenceKey ( Type.Protected   )
		. setAllPoints       ( AND(OR(Type.Bool, Type.String, Type.Widget), Eval.Togglable) )
		. virtual            ( TypeError('Cannot create virtual frames in Lua.') )
		{	
			-------------------------------------------
			KeyValues
			-------------------------------------------
			. insert ( Method.Forward )
			{
				---------------------------------------
				KeyValue ( AND(Method.Validate, Method.KeyValue) )
				---------------------------------------
				. key        ( OR(Type.String, Type.Number) )
				. keyType    ( Type.String )
				. type       ( Type.String )
				. value      ( Type.Any    );
			};
		};

		-----------------------------------------------
		TextureBase
		-----------------------------------------------
		. extend   { Abstract { LayoutFrame {} } }
		{
			Color (function(object, props) end);
		};
	};

	UI {
		-----------------------------------------------
		Frame
		-----------------------------------------------
		. extend                 { Abstract { LayoutFrame {} } }
		. insert                 ( Factory.Frame   )
		. clampedToScreen        ( Eval.Setter     )
		. clipChildren           ( Eval.SetClipsChildren )
		. depth                  ( Type.Deprecated )
		. dontSavePosition       ( Eval.Setter     )
		. enableKeyboard         ( Eval.Togglable  )
		. fixedFrameLevel        ( Eval.Setter     )
		. fixedFrameStrata       ( Eval.Setter     )
		. flattenRenderLayers    ( Eval.SetFlattensRenderLayers )
		. frameBuffer            ( Eval.SetIsFrameBuffer )
		. frameLevel             ( Eval.Setter     )
		. frameStrata            ( AND(Type.Enum.FRAMESTRATA, Eval.Setter) )
		. hyperlinksEnabled      ( Eval.Setter     )
		. id                     ( Eval.Setter     )
		. ignoreParentAlpha      ( Eval.Setter     )
		. ignoreParentScale      ( Eval.Setter     )
		. intrinsic              ( TypeError('Cannot create intrinsic frames in Lua.') )
		. jumpNavigateEnabled    ( Type.Deprecated )
		. jumpNavigateStart      ( Type.Deprecated )
		. movable                ( Eval.Setter     )
		. propagateHyperlinksToParent ( Type.Unsupported )
		. propagateKeyboardInput ( Eval.Setter     )
		. protected              ( Type.Protected  )
		. registerForDrag        ( Eval.Togglable  )
		. resizable              ( Eval.Setter     )
		. toplevel               ( Eval.Setter     )
		. useParentLevel ( Eval(function(object, enabled)
			if not enabled then return end;
			object:SetFrameLevel(object:GetParent():GetFrameLevel())
		end) )
		{
			Frames {}; -- TODO: test
			-------------------------------------------
			Attributes
			-------------------------------------------
			. insert ( Method.Forward )
			{
				---------------------------------------
				Attribute ( AND(Method.Validate, Method.Attribute) )
				---------------------------------------
				. name   ( OR(Type.String, Type.Number) )
				. type   ( Type.String )
				. value  ( Type.Any    );
			};
			-------------------------------------------
			Animations
			-------------------------------------------
			{
				AnimationGroup
				. insert(function(object, props, ...)

				end) {
					--Animations here
				};
			};
			-------------------------------------------
			HitRectInsets (function(object, props) end);
			-------------------------------------------
			Layers
			-------------------------------------------
			{
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
}
-------------------------------------------------------
-- Create abstract schema
-------------------------------------------------------
Abstract();
-------------------------------------------------------
-- Create UI schema
-------------------------------------------------------
UI();