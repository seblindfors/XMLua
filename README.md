# XMLua

## Create standalone element
```lua
local elem = XML.Element .id 'root' .value (2) .enabled (true);
```
`print(elem)` or `tostring(elem)` has the following output:
```xml
<Element id="root" value="2" enabled="true" />
```

## Create document
```lua
-- @param noGlobals:  forbid global lookups in factory, default false
-- @param stackLevel: local stack level, default 2
-- @return XMLDoc(s): objects which will convert to XML when printed

local doc = XML(noGlobals, stackLevel) { elem, elem, ... }
```

## Example
```lua
local paragraph = XML.p .style 'color:red' 'This is a paragraph';
local doc = XML() {
    html .lang 'en' {
        head {
            meta .charset 'utf-8';
            meta .name 'description' .content 'This is a description';
            title ('Document title');
        };
        body {
            h1 ['data-parent'] 'root' ('This is a header');
            paragraph;
        };
    };
};
```
`tostring(doc)` outputs the following:
```xml
<html lang="en">
    <head>
        <meta charset="utf-8"/>
        <meta name="description" content="This is a description"/>
        <title>Document title</title>
    </head>
    <body>
        <h1 data-parent="root">This is a header</h1>
        <p style="color:red">This is a paragraph</p>
    </body>
</html>
```