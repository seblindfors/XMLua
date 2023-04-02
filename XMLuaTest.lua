local XML = XMLua or LibStub and LibStub('XMLua', 1)

local onenter = function(self) print('hello world') end
local pclick = function(self) print('postcall click') end

local playerUnitAttribute = XML.Attribute .name 'unit' .value 'player';
local actionButtonType = XML.Attribute .name 'type' .value 'action';
local buttonSize = XML.Size .x(42) .y(42);

xmltest = XML() {
	Frame .name 'CustomActionBarFrame' .inherits 'SecureHandlerBaseTemplate' .parent(UIParent) .alpha(0.5) .clipChildren(true) {
		Size .x (84) .y (42);
		Anchors {
			Anchor .point 'CENTER' .relativeTo (UIParent) {
				Offset .x(0) .y(100);
			};
		};
	};
}

print(xmltest())

--[[local button2 = XML() {
	IndexButton .parentKey 'Button2' .inherits 'SecureActionButtonTemplate, BackdropTemplate' {
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
		HighlightTexture .parentKey 'Hilite' .setAllPoints(true) {
			Color .r(1) .g(1) .b(1);
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
			Button .parentKey 'Button1' .inherits 'SecureActionButtonTemplate' {
				buttonSize;
				Anchors {
					Anchor .point 'LEFT' {
						Offset .x(0) .y(0);
					};
				};
				Attributes {
					Attribute .name 'action' .type 'number' .value (1);
					actionButtonType;
					playerUnitAttribute;
				};
				Layers {
					Layer .level 'BACKGROUND' {
						Texture .parentKey 'Icon' .setAllPoints (true) {
							Color .color (RED_FONT_COLOR);
						};
					};
					Layer .level 'ARTWORK' {
						FontString .parentKey 'Name' .inherits 'Game18Font' .wordwrap (true) .justifyH 'LEFT' {
							KeyValues {
								KeyValue .key 'minLineHeight' .value (12) .type 'number';
							};
							Size .x (42) .y (18);
							Anchors {
								Anchor .point 'BOTTOMLEFT';
							};
							Color .r (1) .g (0.914) .b (0.682);
							Shadow {
								Offset {
									AbsDimension .x (1) .y (1);
								};
								Color .r (0) .g (0) .b (0) .a(1);
							};
						};
					};
				};
			};
			button2;
		};
		ResizeBounds {
			minResize {
				AbsDimension .x (42) .y(42);
			};
			maxResize {
				AbsDimension .x (84) .y(84);
			};
		};
	}
}

--print(test)
print(test()) ]]