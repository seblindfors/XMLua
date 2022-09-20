local XML = XMLua or LibStub and LibStub('XMLua', 1)

local UIParent = UIParent
local onenter = function(self) print('hello world') end
local pclick = function(self) print('postcall click') end

local playerUnitAttribute = XML.Attribute .name 'unit' .value 'player';

test = XML() {
	Frame .name 'CustomActionBarFrame' .inherits 'SecureHandlerBaseTemplate' .parent (UIParent) {
		Size .x (100) .y (40);
		Anchors {
			Anchor .point 'CENTER' .x (0) .y (100);
		};
		Frames {
			Button .parentKey 'Button1' .setAllPoints (true) {
				Attributes {
					Attribute .name 'type' .type 'string' .value 'action';
					Attribute .name 'action' .type 'number' .value (1);
					playerUnitAttribute;
				};
				KeyValues {
					KeyValue .key 'backdropBorderColor' .value 'BACKDROP_ACHIEVEMENTS_0_64' .type 'global';
					KeyValue .key 'backdropBorderColorAlpha' .value (0.5) .type 'number';
				}
			};
			Button .parentKey 'Button2' .inherits 'SecureActionButtonTemplate' {
				Size .x (42) .y (42);
				Anchors {
					Anchor .point 'LEFT' .relativeKey '$parent.Button1' .relativePoint 'RIGHT' .x (10);
				};
				Attributes {
					Attribute .name 'type' .type 'string' .value 'action';
					Attribute .name 'action' .type 'number' .value (2);
				};
				Layers {
					Layer .level 'BACKGROUND' {
						Texture .parentKey 'Icon' .setAllPoints (true) {
							Color .r (0) .g (0) .b(1) .a(0.5);
						};
					};
				};
				Scripts {
					OnEnter (onenter);
					OnClick .intrinsicOrder 'postcall' (pclick);
				};
			};
		}
	}
}

--print(test)
print(test())