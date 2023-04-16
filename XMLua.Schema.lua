local XML = XMLua or LibStub and LibStub('XMLua', 1)
local Metadata = XML and XML:GetMetadata();

if not XML or Metadata.Loaded then return end;
local Abstract, UI = XML:SetResolver(Metadata.Factory.Resolver)(Metadata.Factory) {
	Abstract {
		Enum
		{
			ALPHAMODE {
				DISABLE              (1);
				BLEND                (2);
				ALPHAKEY             (3);
				ADD                  (4);
				MOD                  (5);
			};
			ANIMLOOPTYPE {
				NONE                 (1);
				REPEAT               (2);
				BOUNCE               (3);
			};
			DRAWLAYER {
				BACKGROUND           (1);
				BORDER               (2);
				ARTWORK              (3);
				OVERLAY              (4);
				HIGHLIGHT            (5);
			};
			FILTERMODE {
				LINEAR               (1);
				TRILINEAR            (2);
				NEAREST              (3);
			};
			FRAMEPOINT {
				TOPLEFT              (1);
				TOPRIGHT             (2);
				BOTTOMLEFT           (3);
				BOTTOMRIGHT (4);
				TOP                  (5);
				BOTTOM               (6);
				LEFT                 (7);
				RIGHT                (8);
				CENTER               (9);
			};
			FRAMESTRATA {
				PARENT               (1);
				BACKGROUND           (2);
				LOW                  (3);
				MEDIUM               (4);
				HIGH                 (5);
				DIALOG               (6);
				FULLSCREEN           (7);
				FULLSCREEN_DIALOG    (8);
				TOOLTIP              (9);
			};
			ORIENTATION {
				HORIZONTAL           (1);
				VERTICAL             (2);
			};
			WRAPMODE {
				CLAMP                (1);
				REPEAT               (2);
				CLAMPTOBLACK         (3);
				CLAMPTOBLACKADDITIVE (4);
				CLAMPTOWHITE         (5);
				MIRROR               (6);
			};
		};


		Object
		. inherits           ( Type.String    )
		. mixin              ( Type.Table     )
		. name               ( Type.String    )
		. secureMixin        ( Type.Protected )
		. secureReferenceKey ( Type.Protected )
		. virtual            ( TypeError('Cannot create virtual objects in Lua.') )
		. parentKey          ( AND(OR(Type.Number, Type.String), Eval.Setter) )
		. parentArray        ( Eval(function(object, key)
			local parent = object:GetParent()
			local parentArray = parent[key];
			if not parentArray then
				parentArray = {};
				parent[key] = parentArray;
			end
			parentArray[#parentArray + 1] = object;
		end) );


		Anchors
		. insert( Method.Forward )
		{
			Anchor
			. insert        ( AND(Method.Validate, Method.Point) )
			. point         ( Type.Enum.FRAMEPOINT )
			. relativeKey   ( Type.String  )
			. relativeTo    ( OR(Type.String, Type.Widget) )
			. relativePoint ( Type.Enum.FRAMEPOINT )
			. x             ( Type.Number  )
			. y             ( Type.Number  )
			{
				Offset
				. x      ( Type.Number )
				. y      ( Type.Number )
				. insert ( Method.Validate )
				{
					AbsDimension ( Method.Validate )
					. x ( Type.Number )
					. y ( Type.Number );
				};
			};
		};


		Insets
		. insert ( OR(Method.Insets, Method.Validate) )
		. bottom ( Type.Number )
		. left   ( Type.Number )
		. right  ( Type.Number )
		. top    ( Type.Number )
		{
			AbsInset ( Method.Validate )
			. bottom ( Type.Number     )
			. left   ( Type.Number     )
			. right  ( Type.Number     )
			. top    ( Type.Number     );
		};


		Color   ( Method.Validate )
		. r     ( Type.Number     )
		. g     ( Type.Number     )
		. b     ( Type.Number     )
		. a     ( Type.Number     )
		. color ( OR(Type.Table, Type.String) );


		TableObject
		{
			KeyValues
			. insert ( Method.Forward )
			{
				KeyValue ( AND(Method.Validate, Method.KeyValue) )
				. key        ( OR(Type.String, Type.Number) )
				. keyType    ( Type.String )
				. type       ( Type.String )
				. value      ( Type.Any    );
			};
		};


		Resizing
		. scale ( AND(Type.Number, Eval.Setter) )
		{
			Anchors
			. implement ( Abstract { Anchors {} } );
			Size
			. insert ( Method.Size )
			. x      ( Type.Number )
			. y      ( Type.Number )
			{
				AbsDimension ( Method.Size )
				. x ( Type.Number )
				. y ( Type.Number );
			};
		};


		ScriptRegion
		{
			Scripts
			. resolver(function() end)
			{
				OnLoad ( function(object, props, ...) end );
			};
		};


		LayoutFrame
		. extend {
			Abstract {
				Object       {};
				Resizing     {};
				ScriptRegion {};
				TableObject  {};
			};
		}
		. alpha              ( AND(Type.Number, Eval.Setter) )
		. enableMouse        ( AND(Type.Bool, Eval.Togglable) )
		. enableMouseClicks  ( AND(Type.Bool, Eval.SetMouseClickEnabled) )
		. enableMouseMotion  ( AND(Type.Bool, Eval.SetMouseMotionEnabled) )
		. hidden             ( AND(Type.Bool, Eval(function(object, hide) object:SetShown(not hide) end)) )
		. ignoreParentAlpha  ( Eval.Setter      )
		. ignoreParentScale  ( Eval.Setter      )
		. parent             ( AND(OR(Type.String, Type.Frame), Eval.Setter) )
		. passThroughButtons ( Eval.Setter      )
		. setAllPoints       ( AND(OR(Type.Bool, Type.String, Type.Widget), Eval.Togglable) );


		TextureBase
		. extend            { Abstract { LayoutFrame {} } }
		. insert            ( Factory.Texture                )
		. alphaMode         ( AND(Type.Enum.ALPHAMODE, Eval.SetBlendMode) )
		. atlas             ( Type.String                    )
		. desaturated       ( Eval.SetDesaturation           )
		. file              ( OR(Type.String, Type.Number)   )
		. filterMode        ( Type.Enum.FILTERMODE           )
		. horizTile         ( AND(Type.Bool, Eval.Setter)    )
		. hWrapMode         ( Type.Enum.WRAPMODE             )
		. mask              ( Eval.Setter                    )
		. noanimalpha       ( Type.Unsupported               )
		. nolazyload        ( Type.Unsupported               )
		. nonBlocking       ( Eval.SetBlockingLoadsRequested )
		. nounload          ( Type.Unsupported               )
		. rotation          ( AND(Type.Number, Eval.Setter)  )
		. snapToPixelGrid   ( AND(Type.Bool, Eval.Setter)    )
		. texelSnappingBias ( AND(Type.Number, Eval.Setter)  )
		. useAtlasSize      ( Type.Bool                      )
		. vertTile          ( AND(Type.Bool, Eval.Setter)    )
		. vWrapMode         ( Type.Enum.WRAPMODE             )
		{
			TexCoords
			. insert ( AND(Method.Validate, Method.TexCoord) )
			. bottom ( Type.Number )
			. left   ( Type.Number )
			. right  ( Type.Number )
			. top    ( Type.Number )
			{
				Rect ( AND(Method.Validate, Method.TexCoord) )
				. ULx ( Type.Number )
				. ULy ( Type.Number )
				. LLx ( Type.Number )
				. LLy ( Type.Number )
				. URx ( Type.Number )
				. URy ( Type.Number )
				. LRx ( Type.Number )
				. LRy ( Type.Number );
			};

			Gradient
			. insert      ( OR(Method.Gradient, Method.Validate) )
			. orientation ( Type.Enum.ORIENTATION )
			{
				MinColor
				. implement ( Abstract { Color {} } );
				MaxColor
				. implement ( Abstract { Color {} } );
			};

			Color ( Method.Color )
			. extend ( Abstract { Color {} } );
		};

		Animation
		. extend {
			Abstract {
				Object       {};
				TableObject  {};
				ScriptRegion {};
			}
		};
	};

	UI {
		Frame
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
			Frames
			. implement   ( UI {} )
			. insert      ( Method.Forward );

			Attributes
			. insert      ( Method.Forward )
			{
				Attribute ( OR(Method.Attribute, Method.Validate) )
				. name    ( OR(Type.String, Type.Number) )
				. type    ( Type.String )
				. value   ( Type.Any    );
			};

			Animations
			. insert      ( Method.Forward )
			{
				AnimationGroup
				. extend {
					Abstract {
						Object       {};
						ScriptRegion {};
					};
				}
				. insert          ( Factory.AnimationGroup )
				. looping         ( AND(Type.Enum.ANIMLOOPTYPE, Eval.Setter) )
				. setToFinalAlpha ( AND(Type.Bool, Eval.Togglable) )
				{--Animations here
				};
			};

			HitRectInsets
			. implement ( Abstract { Insets {} } );

			Layers
			. insert ( Method.Forward )
			{
				Layer
				.insert          ( Method.Forward )
				.level           ( Type.Enum.DRAWLAYER )
				.textureSubLevel ( Type.Number )
				{
					Texture
					. implement ( Abstract { TextureBase {} } );
					--[[FontString .insert(function(object, props, ...) end) {
						Color (function(object, props) end);
						Shadow .insert(function(object, props) end) {

						};
					};]]
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