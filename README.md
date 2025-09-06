# TabTomlParser
A Toml parser for GameMaker. https://toml.io/en/

This covers the full range of the v1.0.0 spec and has been tested roughly based on the examples given from the spec sheet. 
## Main caveats

### Empty quoted key names
As GameMaker does not support empty key names in structs, any keys with an empty key name will be instead set as `$$__INTENTIONAL_NULL_KEY__$$`.

### Datetime
All RFC 3339 date-time support is baked in, and builds upon the `date_*` functionality. Their value type will be numbers.


## Installation
Copy the `TabTomlParse.gml` contents and paste it into an empty script.

## Usage

```gml
var _buff = buffer_load("config.toml");
var _str = buffer_read(_buff, buffer_text);
buffer_delete(_buff);

var _config = TabTomlParse(_str);
// Printing it back out as JSON, since it's a bit easier to read than just a struct literal
show_debug_message(json_strigify(_config, true));
```