local XML = XMLua or LibStub and LibStub('XMLua', 1)

local UIParent = UIParent
local onenter = function(self) print('hello world') end
local pclick = function(self) print('postcall click') end

local playerUnitAttribute = XML.Attribute .name 'unit' .value 'player';
local actionButtonType = XML.Attribute .name 'type' .value 'action';
local buttonSize = XML.Size .x(42) .y(42);

local button2 = XML() {
	Button .parentKey 'Button2' .inherits 'SecureActionButtonTemplate, BackdropTemplate' {
		buttonSize;
		Anchors {
			Anchor .point 'LEFT' .relativeKey '$parent.Button1' .relativePoint 'RIGHT' .x (10);
		};
		Attributes {
			Attribute .name 'action' .type 'number' .value (2);
			actionButtonType;
		};
		KeyValues {
			KeyValue .key 'backdropInfo' .value 'BACKDROP_CALLOUT_GLOW_0_20' .type 'global';
		};
		Scripts {
			OnEnter (onenter);
			OnClick .intrinsicOrder 'postcall' (pclick);
			OnLoad .method 'OnBackdropLoaded';
			OnSizeChanged .method 'OnBackdropSizeChanged';
		};
	};
}

test = XML() {
	Frame .name 'CustomActionBarFrame' .inherits 'SecureHandlerBaseTemplate' .parent (UIParent) {
		Size .x (84) .y (42);
		Anchors {
			Anchor .point 'CENTER' .x (0) .y (100);
		};
		Frames {
			Button .parentKey 'Button1' {
				buttonSize;
				Anchors {
					Anchor .point 'LEFT';
				};
				Attributes {
					Attribute .name 'action' .type 'number' .value (1);
					actionButtonType;
					playerUnitAttribute;
				};
				Layers {
					Layer .level 'BACKGROUND' {
						Texture .parentKey 'Icon' .setAllPoints (true) {
							Color .r (0) .g (0) .b(1) .a(0.5);
						};
					};
				};
			};
			button2;
		}
	}
}

--print(test)
print(test())