function FileToString(_path) {
	var _buff = undefined;
	try {
		_buff = buffer_load(_path);
		return buffer_read(_buff, buffer_text);
	} finally {
		if (buffer_exists(_buff)) buffer_delete(_buff);
	}
}

try {
	show_debug_message(TabTomlParse("0key = \"foo\""));
} catch(_ex) {
	show_debug_message(_ex.message);
}

try {
	show_debug_message(TabTomlParse("3.14159 = \"pi\""));
} catch(_ex) {
	show_debug_message(_ex.message);
}

try {
	show_debug_message(TabTomlParse("[[test]]\nrawr = 42\n[test]\nfoo = \"bar\""));
} catch(_ex) {
	show_debug_message(_ex.message);
}

try {
	show_debug_message(TabTomlParse(@'
	[[fruits]]
name = "apple"

[[fruits.varieties]]
name = "red delicious"

# INVALID: This table conflicts with the previous array of tables
[fruits.varieties]
name = "granny smith"


	'));
} catch(_ex) {
	show_debug_message(_ex.message);
}

var _file = file_find_first("test_cases\\*", fa_none);
while(_file != "") {
	var _t = get_timer();
	var _data = TabTomlParse(FileToString("test_cases\\" + _file));
	show_debug_message($"Time to load: {(get_timer() - _t) / 1000}ms")
	struct_foreach(_data, function(_name, _value) {
		show_debug_message($"{_name} - {_value}");
	});
	show_debug_message("\n===\n");
	_file = file_find_next();
}
file_find_close();

game_end();