# TabTomlParser
A Toml parser for GameMaker. https://toml.io/en/

This covers the full range of the spec and has been tested roughly based on the examples given from the spec sheet. 
## Main caveats

### Empty key names
As GameMaker does not support empty key names in structs, any keys with an empty key name will be instead set as `$$__INTENTIONAL_NULL_KEY__$$`.