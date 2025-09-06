// feather ignore all

/// @param {String} toml
/// 	@return {Any}
function TabTomlParse(_str) {
	var _parser = new __TabTomlParser(_str);
	_parser.DoUpate();
	return _parser.__root;
}

enum __TabTomlType {
	KEY,
	KEY_TARGET_CHANGE,
	VALUE_STRING,
	VALUE_DATETIME,
	VALUE_INTEGER,
	VALUE_FLOAT,
	VALUE_BOOLEAN,
	VALUE_UNIQUE,
	ARRAY,
	TABLE,
	TABLE_EXT,
	ARRAY_TABLE,
	ARRAY_TABLE_EXT,
	EOF
}

/// @ignore
function __TabTomlParser(_str) constructor {
	__lexer = new __TabTomlLexer(_str);
	__root = {};
	__tableRoot = __root;
	__target = __root;

	static Error = function(_str) {
		show_error(_str + $" At {__lexer.GetRow()} - {__lexer.GetColumn()}.", true);
	}
	
	static DoUpate = function() {
		try {
			while(!__lexer.EOF()) {
				ParseEntry();			
			}
		} finally {
			__lexer.CleanUp();
		}
	}

	static ParseEntry = function() {
		var _token = __lexer.Next();
		switch(_token) {
			case __TabTomlType.KEY:
				var _key = __lexer.GetValue();
				__lexer.Next();
				if (is_array(__target)) {
					var _struct = {};
					array_push(__target, _struct);
					__target = _struct;
				}
				__target[$ _key] = ParseExpression();
			break;
			case __TabTomlType.ARRAY_TABLE:
				var _key = __lexer.GetValue();
				__target = __root;
				
				if (string_pos(".", _key) > 0) {
					var _keys = string_split(_key, ".", true);
					var _i = 0;
					var _keyTarget = array_shift(_keys);
					__target[$ _keyTarget] ??= {};
					__target = __target[$ _keyTarget];
 					if (is_array(__target)) {
						Error($"Array with the name \"{_keyTarget}\" already exists! Cannot redefine as an Array Table!");
						return;
					}
					repeat(array_length(_keys)) {
						if (!is_undefined(__target[$ _keys[_i]])) && (!is_array(__target[$ _keys[_i]])) {
							Error($"Table with the name \"{_keys[_i]}\" already exists! Cannot redefine as an Array Table!");
							return;
						}
						__target[$ _keys[_i]] ??= [];
						__target = __target[$ _keys[_i]];
						++_i;
					}
				} else {
					if (!is_undefined(__target[$ _key])) && (!is_array(__target[$ _key])) {
						Error($"Table with the name \"{_key}\" already exists! Cannot redefine as an Array Table!");
						return;
					}
					__target[$ _key] ??= [];
					__target = __target[$ _key];
				}
				
				__tableRoot = __target;
			break;
			case __TabTomlType.TABLE:
				var _key = __lexer.GetValue();
				__target = __root;
				if (string_pos(".", _key) > 0) {
					var _keys = string_split(_key, ".", true);
					var _i = 0;
					var _keyTarget = array_shift(_keys);
					__target[$ _keyTarget] ??= {};
					__target = __target[$ _keyTarget];
					if (is_array(__target)) {
						Error($"Array with the name \"{_keyTarget}\" already exists! Cannot redefine as a table!");
						return;
					}
					repeat(array_length(_keys)) {
						__target[$ _keys[_i]] ??= {};
						__target = __target[$ _keys[_i]];
						++_i;
					}
				} else {
					if (is_array(__target[$ _key])) {
						Error($"Array with the name \"{_key}\" already exists! Cannot redefine as a table!");
						return;
					}
					__target[$ _key] ??= {};
					__target = __target[$ _key];
				}
				
				__tableRoot = __target;
			break;
			case __TabTomlType.KEY_TARGET_CHANGE:
				var _keys = string_split(__lexer.GetValue(), ".", true);
				var _keyTarget = array_shift(_keys);
				var _i = 0;
				__target = __tableRoot;
				__target[$ _keyTarget] ??= {};
				__target = __target[$ _keyTarget];
				repeat(array_length(_keys)-1) {
					__target[$ _keys[_i]] ??= {};
					__target = __target[$ _keys[_i]];
					++_i;
				}
				
				if (array_length(_keys) > 0) _keyTarget = _keys[_i];
				__lexer.Next();
				if (is_array(__target)) {
					var _struct = {};
					array_push(__target, _struct);
					__target = _struct;
				}
				__target[$ _keyTarget] = ParseExpression();
			break;	
		}
	}

	static ParseExpression = function() {
		var _token = __lexer.Peek();
		var _value = __lexer.GetValue();
		switch(_token) {
			case __TabTomlType.VALUE_STRING:
				return _value;
			case __TabTomlType.VALUE_INTEGER:
				return int64(_value);
			case __TabTomlType.VALUE_FLOAT:
				return real(_value);
			case __TabTomlType.VALUE_DATETIME:
				return __TabTomlParseRfc3339(_value);
			case __TabTomlType.VALUE_UNIQUE:
			// Return AS is.
				return _value;
		}
	}
}

/// @ignore
function __TabTomlLexer(_str) constructor {
	__size = string_byte_length(_str);
	__buff = buffer_create(__size, buffer_fixed, 1);
	buffer_poke(__buff, 0, buffer_text, _str);

	__peekType = undefined;
	__peekTarget = undefined;
	__peekValue = undefined;
	__charCode = undefined;
	__charCodePrevious = undefined;
	__newLineDetected = false;
	__column = 1;
	__row = 0;

	static CleanUp = function() {
		buffer_delete(__buff);
	}

	static Next = function() {
		__peekType = undefined;
		__peekValue = undefined;
		__newLineDetected = false;
		SkipWhiteSpace();
		if (EOF()) return __TabTomlType.EOF;
		
		var _str = "";
		var _charCode = __charCode;
		switch(_charCode) {
			case ord("["):
				__peekType = __TabTomlType.TABLE;
				NextCharCode();
				if (CurrentCharCode() == ord("[")) {
					__peekType = __TabTomlType.ARRAY_TABLE;
					NextCharCode();
				}
 				if (CurrentCharCode() == ord("\"")) || (CurrentCharCode() == ord("'")) {
					//__peekType = (__peekType == __TabTomlType.ARRAY_TABLE) ? __TabTomlType.ARRAY_TABLE_EXT: __TabTomlType.TABLE_EXT;
					GetKeyFromBuffer(CurrentCharCode());
				} else {
					GetKeyAsTable();
				}
				
				if (__peekType == __TabTomlType.ARRAY_TABLE) {
					if (CurrentCharCode() != ord("]")) {
						Error($"Array Table not closed properly!");
						return;
					}
					NextCharCode();
				}
			break;
			
			// Value of some kind
			case ord("="): 
				SkipWhiteSpace();
				
				__RetrieveValue();
			break;
			// Assume key
			default:
				__peekType = __TabTomlType.KEY;
				// Fast path
				if (CurrentCharCode() == ord("\"")) || (CurrentCharCode() == ord("'")) {
					GetKeyFromBuffer(CurrentCharCode());
				} else {
					GetKey();
				}
			break;
		}
		//_str += chr(_charCode);

		return __peekType;
	}

	static GetKey = function() {
		var _charCode = CurrentCharCode();
		var _str = "";
		var _isNumericKey = false;
		if (CharCodeIsNumerical(_charCode)) {
			_isNumericKey = true;
		}
	
		while(!__IsSpaceOrTab((_charCode))) {
			if (__IsWhiteSpace(_charCode)) {
				Error($"Cannot end on a newline! Expected \"{_str} = EXPRESSION\", got \"{_str}\"");
				return;
			}
	
			if (!CharCodeIsAlphabetical(_charCode) && !CharCodeIsNumerical(_charCode) && (_charCode != ord("-")) && (_charCode != ord("_")) && (_charCode != ord("."))) {
				Error($"Cannot use \"{chr(_charCode)}\" as apart of key name! Expected \"A-Za-z0-9_-\"");
				return;
			}

			if (_isNumericKey && !CharCodeIsNumerical(_charCode)) {
				Error($"Cannot use \"{chr(_charCode)}\" as apart of ASCII digit key! Expected 0-9!");
				return;
			}

			if (_charCode == ord(".")) {
				__peekType = __TabTomlType.KEY_TARGET_CHANGE;
			}
			_str += chr(_charCode);
			_charCode = NextCharCode();
		}

		__peekValue = _str;
	}

	static GetKeyAsTable = function() {
		var _charCode = CurrentCharCode();
		var _str = "";
		var _isNumericKey = false;
		if (CharCodeIsNumerical(_charCode)) {
			_isNumericKey = true;
		}
	
		while(_charCode != ord("]")) {
			if (!CharCodeIsAlphabetical(_charCode) && !CharCodeIsNumerical(_charCode) && (_charCode != ord("-")) && (_charCode != ord(" ")) && (_charCode != ord("_")) && (_charCode != ord("."))) {
				Error($"Cannot use {chr(_charCode)} as apart of key name! Expected \"A-Za-z0-9_-\", got \"{_str}\"");
				return;
			}

			if (_isNumericKey && !CharCodeIsNumerical(_charCode)) {
				Error($"Cannot use {chr(_charCode)} as apart of ASCII digit key! Expected 0-9!");
				return;
			}
			_str += chr(_charCode);
			_charCode = NextCharCode();
		}

		__peekValue = string_replace_all(_str, " ", "");
	}

	static GetKeyFromBuffer = function(_endString = ord("\"")) {
		var _pos = buffer_tell(__buff);
		var _charCode = NextCharCode();
		while(!EOF() && (_charCode != _endString))  {
			_charCode = NextCharCode();
		}

		if (buffer_tell(__buff) == _pos+1) {
			__peekValue = "$$__INTENTIONAL_NULL_KEY__$$";
			return;
		}
              
		__peekValue = __BufferToString(_pos, buffer_tell(__buff)-_pos-1);
	}

	static __BufferToString = function(_pos = buffer_tell(__buff), _length = 1) {
		static __buffStr = buffer_create(1, buffer_grow, 1);
		try {
			buffer_copy(__buff, _pos, _length, __buffStr, 0);
			buffer_seek(__buffStr, buffer_seek_start, _length);
			buffer_write(__buffStr, buffer_u8, 0); // NULL
			buffer_seek(__buffStr, buffer_seek_start, 0);
			return buffer_read(__buffStr, buffer_text);
		} finally {
			buffer_resize(__buffStr, 1);
		}
	}

	static __IsSpaceOrTab = function(_charCode) {
		 return (_charCode == ord(" ") || _charCode == ord("		"));
	}

	static __IsNewLine = function(_charCode) {
		return (_charCode == ord("\n") || _charCode == ord("\r"));
	}

	static __IsWhiteSpace = function(_charCode = CurrentCharCode()) {
		return __IsSpaceOrTab(_charCode) || __IsNewLine(_charCode) || EOF();
	}

	static __RetrieveValue = function() {
		var _charCode = CurrentCharCode();

		if (_charCode == ord("\"") || _charCode == ord("'")) {
			__peekType = __TabTomlType.VALUE_STRING;
			if (NextCharCode() == ord("\"")) {
				if (NextCharCode() == ord("\"")) {
					// We are doing a multiline basic string
					NextCharCode();
					GetStringBasicMultiline();
				}
			} else if (_charCode == ord("'")) {
				buffer_seek(__buff, buffer_seek_relative, -1)
				if (NextCharCode() == ord("'")) {
					if (NextCharCode() == ord("'")) {
						NextCharCode();
						GetStringLiteralMultiline();
					}
				} else {
					GetStringLiteral();
				}
			} else { // Assume normal string
				GetStringBasic();
			}
		} else if (CharCodeIsNumerical(_charCode) || _charCode == ord("+") || _charCode == ord("-")) {
			GetNumeric();
		} else if (_charCode == ord("[")) { 
			// Making an array
			GetArray();
		} else if (_charCode = ord("{")) {
			GetTable();
		} else {
			GetGeneric();
		}
	}

	static GetTable = function() {
		var _table = {};
		var _firstIteration = false;
		while(!EOF()) {
			SkipWhiteSpace();
			if (CurrentCharCode() == ord("}")) break;
			if (!_firstIteration) {GetKey(); _firstIteration = true;} else {Next();}
			var _key = GetValue();
			Next();
			_table[$ _key] = __ResolveValue(Peek(), GetValue());
		}
		__peekType = __TabTomlType.VALUE_UNIQUE;
		__peekValue = _table;
	}

	static __ResolveValue = function(_type, _value) {
		switch(_type) {
			case __TabTomlType.VALUE_STRING:
				return _value;
			case __TabTomlType.VALUE_INTEGER:
				return int64(_value);
			case __TabTomlType.VALUE_FLOAT:
				return real(_value);
			case __TabTomlType.VALUE_DATETIME:
				return __TabTomlParseRfc3339(_value);
			case __TabTomlType.VALUE_UNIQUE:
				return _value;
		}
	}

	static GetArray = function() {
		
		var _array = [];
		__peekValue = undefined;
		NextCharCode();
		while(CurrentCharCode() != ord("]")) {
			if (__IsWhiteSpace(CurrentCharCode())) {
				SkipWhiteSpace();
			}
			if (CurrentCharCode() == ord("]")) break;
			if (PreviousCharCode() == ord("{") ||CurrentCharCode() == ord(",") || CurrentCharCode() == ord("\"") || CurrentCharCode() == ord("'")) {
				// CORRECT
				buffer_seek(__buff, buffer_seek_relative, -1);
				NextCharCode();
			}
			__RetrieveValue()
			array_push(_array, __ResolveValue(Peek(), GetValue()));
			NextCharCode();
			if (CurrentCharCode() == ord(",")) {
				NextCharCode();
			}
		}
		if (!EOF()) NextCharCode();

		__peekType = __TabTomlType.VALUE_UNIQUE;
		__peekValue = _array;
	}

	static GetGeneric = function() {
		var _pos = buffer_tell(__buff)-1;
		while(!__IsWhiteSpace(CurrentCharCode())) {
			NextCharCode();
		}
		var _str = string_trim(__BufferToString(_pos, buffer_tell(__buff)-_pos));
		switch(_str) {
			case "inf":
				__peekType = __TabTomlType.VALUE_UNIQUE;
				__peekValue = infinity;
			break;
			case "nan":
				__peekType = __TabTomlType.VALUE_UNIQUE;
				__peekValue = NaN;
			break;
			case "true":
				__peekType = __TabTomlType.VALUE_UNIQUE;
				__peekValue = true;
			break;
			case "false":
				__peekType = __TabTomlType.VALUE_UNIQUE;
				__peekValue = false;
			break;
			default:
				Error($"Unexpected {_str}!");
			return;
		}
	}

	static GetNumeric = function() {
		var _sign = "+";
		var _isFloat = false;
		var _isExponent = false;
		var _isTimestamp = false;
		var _pos = buffer_tell(__buff)-1;
		__peekType = __TabTomlType.VALUE_INTEGER;

		// Handle exotic numbers first
		switch(NextCharCode()) {
			case ord("x"): // Hex
				NextCharCode();
				_pos = buffer_tell(__buff)-1;
				while(!__IsWhiteSpace(CurrentCharCode())) {
					NextCharCode();
				}
				
				__peekValue = string(__HexToDec(string_replace_all(__BufferToString(_pos, buffer_tell(__buff)-_pos-1), "_", "")));
			return;
			case ord("o"): // Octal
				NextCharCode();
				_pos = buffer_tell(__buff)-1;
				while(!__IsWhiteSpace(CurrentCharCode())) {
					NextCharCode();
				}
				
				__peekValue = string(__OctToDec(__BufferToString(_pos, buffer_tell(__buff)-_pos-1)));
			break;
			case ord("b"): // Binary
				NextCharCode();
				_pos = buffer_tell(__buff)-1;
				while(!__IsWhiteSpace(CurrentCharCode())) {
					NextCharCode();
				}
				
				__peekValue = string(__BinToDec(__BufferToString(_pos, buffer_tell(__buff)-_pos-1)));
			break;
			default:
				// Reverse
				buffer_seek(__buff, buffer_seek_relative, -2);
				NextCharCode();
			break;
		}

		if (CurrentCharCode() == ord("+") || CurrentCharCode() == ord("-")) {
			_sign = chr(CurrentCharCode());
			NextCharCode();
		}
		_pos = buffer_tell(__buff)-1;

		// Possibly inf or nan
		if (CurrentCharCode() == ord("i") || CurrentCharCode() == ord("n")) {
				while(!__IsWhiteSpace(CurrentCharCode())) {
					NextCharCode();
				}
				var _str = string_trim(__BufferToString(_pos, buffer_tell(__buff)-_pos));
				switch(_str) {
					case "inf":
						__peekType = __TabTomlType.VALUE_UNIQUE;
						__peekValue = _sign == "-" ? -infinity : infinity;
					break;
					case "nan":
						__peekType = __TabTomlType.VALUE_UNIQUE;
						__peekValue = _sign == "-" ? -NaN : NaN;
					break;
					default:
						Error($"Invalid string found in numeric parser! Got {_str}!");
						return;
					break;
				}
			return;
		}

		// Integer handling
		while(true) {
			if (__IsWhiteSpace()) {
				if !CharCodeIsNumerical(buffer_peek(__buff, buffer_tell(__buff), buffer_u8)) {
					break;
				}
			}

			if (EOF()) break;

			if ((CurrentCharCode() == ord("e") || CurrentCharCode() == ord("E") || CurrentCharCode() == ord("+") || CurrentCharCode() == ord("-")) || CurrentCharCode() == ord(":")) {
				if (_isExponent) {
					Error($"Invalid \"{chr(CurrentCharCode())}\"! Exponent cannot contain more than one \".\"!");
					return;
				}
				
				if ((CurrentCharCode() == ord("E") || CurrentCharCode() == ord("e"))) {
					_isExponent = true;
					NextCharCode();
					if (CurrentCharCode() == ord("+") && CurrentCharCode() == ord("-")) {
						NextCharCode();
					}
				} else if (CharCodeIsNumerical(PreviousCharCode())) {
					_isTimestamp = true;
				}
			}

			if (!CharCodeIsNumerical(CurrentCharCode())) {
				if (CurrentCharCode() != ord("_") && CurrentCharCode() != ord(".")) {
					if (CurrentCharCode() != ord("e") && CurrentCharCode() != ord("E") && CurrentCharCode() != ord("+") && CurrentCharCode() != ord("-") && CurrentCharCode() != ord(":")) {
						if ((CurrentCharCode() == ord(",") || CurrentCharCode() == ord("]")) && __IsWhiteSpace(buffer_peek(__buff, buffer_tell(__buff), buffer_u8))) {
							buffer_seek(__buff, buffer_seek_relative, -1);
							break;
						}

						if (!_isTimestamp) { 
							Error($"Cannot use {chr(CurrentCharCode())} as integer!")
							return;
						}
					}
				}

				if (CurrentCharCode() == ord(".")) {
					if (_isFloat) {
						Error($"Invalid \"{chr(CurrentCharCode())}\"! Float cannot contain more than one \".\"!");
						return;
					}
					
					_isFloat = true;
				} 

				
			}
			//show_debug_message(chr(CurrentCharCode()));
			NextCharCode();
		}
		if (!EOF() && !__IsNewLine(NextCharCode())) {
			buffer_seek(__buff, buffer_seek_relative, -1);
		}
		var _peekedNum = string_trim(string_replace_all(__BufferToString(_pos, buffer_tell(__buff)-_pos), "_", ""));
		__peekValue = (_isTimestamp ? "" : _sign) + (_peekedNum != "" ? _peekedNum : __peekValue);
		__peekType = (_isFloat || _isExponent) ? __TabTomlType.VALUE_FLOAT : __TabTomlType.VALUE_INTEGER;
		if (_isTimestamp) {
			__peekType = __TabTomlType.VALUE_DATETIME;
		}
	}

	static GetStringLiteral = function() {
		var _pos = buffer_tell(__buff)-1;
		while(CurrentCharCode() != ord("'")) {
			if (__IsNewLine(CurrentCharCode())) {
				Error("Cannot do a newline without making the string into a multiline!");
				break;
			}
			NextCharCode();
		}

		__peekValue = __BufferToString(_pos, buffer_tell(__buff)-_pos-1);
	}

	static GetStringLiteralMultiline = function() {
		var _pos = buffer_tell(__buff)-1;
		if (CurrentCharCode() == ord("\r")) || (CurrentCharCode() == ord("\n")) {
			if (CurrentCharCode() == ord("\r")) {
				NextCharCode();
			}
			if (CurrentCharCode() == ord("\n")) {
				_pos = buffer_tell(__buff);
				NextCharCode();
			}
		}
		__peekValue = "";
		while(!EOF()) {
			if (CurrentCharCode() == ord("'")) {
				var _charCode = NextCharCode(); 
				if (_charCode == ord("'") && NextCharCode() == ord("'")) {
					if ((!EOF()) && NextCharCode() != ord("'")) {
						// We don't have an extra single quote somewhere
						buffer_seek(__buff, buffer_seek_relative, -1);
					} 
					// Three quotes, we can leave!
					break;
				} else if (_charCode == ord("'")) {
					while(CurrentCharCode() != ord("'")) {
						NextCharCode();
					}
					__peekValue += __BufferToString(_pos, buffer_tell(__buff)-_pos-2);
					buffer_seek(__buff, buffer_seek_relative, -1);
					_pos = buffer_tell(__buff)-1;
				}
			} 

			NextCharCode();
		}

		__peekValue += __BufferToString(_pos, buffer_tell(__buff)-_pos-3);
	}

	static GetStringBasicMultiline = function() {
		var _pos = buffer_tell(__buff)-1;
		if (CurrentCharCode() == ord("\r")) || (CurrentCharCode() == ord("\n")) {
			if (CurrentCharCode() == ord("\r")) {
				NextCharCode();
			}
			if (CurrentCharCode() == ord("\n")) {
				_pos = buffer_tell(__buff);
				NextCharCode();
			}
		}
		__peekValue = "";
		// Basic
		while(!EOF()) {
			if (CurrentCharCode() == ord("\"")) {
				var _charCode = NextCharCode(); 
				if (_charCode == ord("\"") && NextCharCode() == ord("\"")) {
					// Three quotes, we can leave!
					break;
				} else if (_charCode == ord("\"")) {
					while(CurrentCharCode() != ord("\"")) {
						NextCharCode();
					}
					__peekValue += __BufferToString(_pos, buffer_tell(__buff)-_pos-2);
					buffer_seek(__buff, buffer_seek_relative, -1);
					_pos = buffer_tell(__buff)-1;
				} else {
					while(CurrentCharCode() != ord("\"")) {
						NextCharCode();
					}
					__peekValue += __BufferToString(_pos, buffer_tell(__buff)-_pos-1);
					_pos = buffer_tell(__buff)-1;
				}
			} else {
				if (CurrentCharCode() == ord("\\")) {
					if (__peekValue == "") {
						__peekValue += string_trim_end(__BufferToString(_pos, buffer_tell(__buff)-_pos-1));
						if (_pos+1 != buffer_tell(__buff)) {
							__peekValue += "\n";
						}
					} else {
						__peekValue += string_trim_end(__BufferToString(_pos, buffer_tell(__buff)-_pos-1));
						__peekValue += "\n";
					}
					
					NextCharCode();
					SkipWhiteSpace(true);
					_pos = buffer_tell(__buff)-1;
					continue;
				} 
			} 
			NextCharCode();
		}
		__peekValue += __BufferToString(_pos, buffer_tell(__buff)-_pos-3);
	}

	static GetStringBasic = function() {
		var _pos = buffer_tell(__buff)-1;
		var _str = "";
		// Basic
		while(CurrentCharCode() != ord("\"")) {
			if (CurrentCharCode() == "\\") {
				_str += __BufferToString(_pos, buffer_tell(__buff)-_pos-1);
				var _charcode = NextCharCode(); 
				switch(_charCode) {
					case ord("t"):
						_str += "\t";
					break;
					case ord("b"):
						_str += "\b";
					break;
					case ord("n"):
						_str += "\n";
					break;
					case ord("f"):
						_str += "\f";
					break;
					case ord("r"):
						_str += "\r";
					break;
					case ord("u"):
					case ord("\\"):
						_str += "\\";
					break;
					case ord("\""):
						_str += "\"";
					break;
					case ord("U"):
						var _num = "";
						while (!__IsSpaceOrTab(_charCode)) {
							if  CharCodeIsNumerical(_charCode) || 
								CharCodeIsAlphabetical(_charCode) {
								_num += chr(_charCode);
								_charCode = NextCharCode();
							}
							_str += string(__HexToDec(_num));
							break;
						}
					break;
					default:
						Error("");
					return;
				}	 

				_pos = buffer_tell(__buff)-1;
			} else {
				if (__IsNewLine(CurrentCharCode())) {
					Error("Cannot do a newline without making the string into a multiline!");
					break;
				}
			} 	 

			NextCharCode();
		}  	 
		_str += __BufferToString(_pos, buffer_tell(__buff)-_pos-1);
		__peekValue = _str;
	}    

	static CharCodeIsAlphabetical = function(_charCode = CurrentCharCode()) {
		return (_charCode >= 0x41 && _charCode <= 0x5A) || 
				(_charCode >= 0x61 && _charCode <= 0x7A);
	} 

	static CharCodeIsNumerical = function(_charCode = CurrentCharCode()) {
		return (_charCode >= 0x30 && _charCode <= 0x39);
	}

	static NextCharCode = function() {
		++__row;
		__charCodePrevious = __charCode;
		__charCode = buffer_read(__buff, buffer_u8);
		if (__IsNewLine(__charCode)) {
			if (__charCode != ord("\n")) {
				__IncremmentColumn();
			}
		}
		return __charCode;
	}

	static PreviousCharCode = function() {
		return __charCodePrevious;
	}

	static CurrentCharCode = function() {
		return __charCode;
	}

	static EOF = function() {
		return buffer_tell(__buff) >= __size;
	}

	static GetValue = function() {
		return __peekValue;
	}

	static __HexToDec = function(_str) {
		static _ctx = {
			char: 0,
		};
		_ctx.char = 0;
		
		static _callback = method(_ctx, function(_char, _pos) {
			static _hex = "0123456789ABCDEF";
			char = char << 4 | (string_pos(_char, _hex) - 1);
		});
		string_foreach(string_upper(_str), _callback);
		return _ctx.char;
	}

	static __OctToDec = function(_str) {
		static _ctx = {
			char: 0,
		};
		_ctx.char = 0;
		
		static _callback = method(_ctx, function(_char, _pos) {
			static _dig = "01234567";
			char = char << 3 | (string_pos(_char, _dig) - 1);
		});
		string_foreach(string_upper(_str), _callback);
		return _ctx.char;
	}

	static __BinToDec = function(_str) {
		static _ctx = {
			char: 0,
		};
		_ctx.char = 0;
		
		static _callback = method(_ctx, function(_char, _pos) {
			char = char << 1; 
			if (_char == "1") char |= 1;
		});
		string_foreach(string_upper(_str), _callback);
		return _ctx.char;
	}
	
	static SkipWhiteSpace = function(_skipComment = false) {
		var _breakOut = false;
		var _prevCharCode = __charCodePrevious;
		while (!EOF()) {
			var _charCode = NextCharCode();
			switch(_charCode) {
				case ord("#"):
					if (_skipComment) {
						_breakOut = true;
						break;
					}
					while(_charCode != ord("\n") && !EOF()) {
						_charCode = NextCharCode();
					}
					__newLineDetected = true;
				break;
				case ord("\r"):
				case ord("\n"):
					__newLineDetected = true;
				break;
				
				case ord(" "):
				case ord("	"):

				break;
				default:
					_breakOut = true;
				break;
			}

			if (_breakOut) {
				break;
			}	
		}
		__charCodePrevious= _prevCharCode;
	}

	static Peek = function() {
		__peekType ??= Next();
		return __peekType;
	}

	static __IncremmentColumn = function() {
		__column++; 
		__row = 0;
	}

	static GetColumn = function() {
		return __column;
	}

	static GetRow = function() {
		return __row;
	}

	static Error = function(_str) {
		show_error(_str + $" At {__row} - {__column}.", true);
	}
}

/// @ignore
function __TabTomlParseRfc3339(_str) {
	var _oldTz = date_get_timezone();
	try {
    	var _len = string_length(_str);
    	var _hasT = string_pos("T", _str) > 0;
    	var _hasSpace = string_pos(" ", _str) > 0;
    	var _tzPos = max(string_pos("Z", _str), max(string_pos("+", _str), string_pos_ext("-", _str, 20)));
    	str = string_trim(_str);
    	
    	// Offset DateTime
    	if ((_hasT || _hasSpace) && _tzPos > 0) {
    	    // Split date and time
    	    var _sep = _hasT ? "T" : " ";
    	    var _parts = string_split(str, _sep);
    	    if (array_length(_parts) != 2) return undefined;
    	
    	    var _datePart = _parts[0];
    	    var _timePart = _parts[1];
    	
    	    // Handle timezone offset
    	    var _offsetSign = 1;
    	    var _offsetHour = 0;
    	    var _offsetMin = 0;
    	
    	    var _zPos = string_pos("Z", _timePart);
    	    if (_zPos > 0) {
    	        _timePart = string_delete(_timePart, _zPos, 1);
    	    } else {
    	        var _signPos = string_pos("+", _timePart);
    	        if (_signPos == 0) _signPos = string_pos("-", _timePart);
    	        if (_signPos > 0) {
    	            if (string_char_at(_timePart, _signPos) == "-") _offsetSign = -1;
    	            offset_hour = real(string_copy(_timePart, _signPos + 1, 2));
    	            offset_min = real(string_copy(_timePart, _signPos + 4, 2));
    	            _timePart = string_copy(_timePart, 1, _signPos - 1);
    	        }
    	    }
    	
    	    var _d = __TabTomlParseRfc3339Date(_datePart);
    	    var _t = __TabTomlParseRfc3339Time(_timePart);
    	
    	    if (is_undefined(_d) || is_undefined(_t)) return 0;
    	
    	    // Create UTC datetime
			date_set_timezone(timezone_utc);
    	    var _dt = date_create_datetime(_d.year, _d.month, _d.day, _t.hour, _t.minute, _t.second + _t.millisecond / 1000);
    	    var _totalOffset = _offsetSign * (_offsetHour * 60 + _offsetMin);
    	    _dt = date_inc_minute(_dt, -_totalOffset); // convert to UTC
    	
    	    return _dt;
    	}
    	
    	// Local DateTime
    	if (_hasT || _hasSpace) {
    	    var _sep = _hasT ? "T" : " ";
    	    var _parts = string_split(str, _sep);
    	    if (array_length(_parts) != 2) return 0;
    	
    	    var _d = __TabTomlParseRfc3339Date(_parts[0]);
    	    var _t = __TabTomlParseRfc3339Time(_parts[1]);
    	
    	    if (is_undefined(_d) || is_undefined(_t)) return 0;
    	
    	    date_set_timezone(timezone_local);
    	    return date_create_datetime(_d.year, _d.month, _d.day, _t.hour, _t.minute, _t.second + _t.millisecond / 1000);
    	}
    	
    	// Local Date
    	if (string_char_at(_str, 5) == "-" && string_char_at(_str, 8) == "-") {
    	    var _d = __TabTomlParseRfc3339Date(_str);
    	    if (is_undefined(_d)) return 0;
    	
    	    date_set_timezone(timezone_local);
    	    return date_create_datetime(_d.year, _d.month, _d.day, 0, 0, 0);
    	}
    	
    	// Local Time 
    	if (string_char_at(_str, 3) == ":" && string_char_at(_str, 6) == ":") {
    	    var _t = __TabTomlParseRfc3339Time(_str);
    	    if (is_undefined(_t)) return 0;
    	
    	    var _today = date_current_datetime();
    	    var _y = date_get_year(_today);
    	    var _m = date_get_month(_today);
    	    var _d = date_get_day(_today);
    	
    	    date_set_timezone(timezone_local);
    	    return date_create_datetime(_y, _m, _d, _t.hour, _t.minute, _t.second + _t.millisecond / 1000);
    	}
    	
    	return 0;
	} finally {
		date_set_timezone(_oldTz);
	}
}

/// @ignore
function __TabTomlParseRfc3339Date(_str) {
    if (string_length(_str) < 10) return undefined;
    return {
        year: real(string_copy(_str, 1, 4)),
        month: real(string_copy(_str, 6, 2)),
        day: real(string_copy(_str, 9, 2))
    };
}

/// @ignore
function __TabTomlParseRfc3339Time(_str) {
    if (string_length(_str) < 8) return undefined;

    var _hour = real(string_copy(_str, 1, 2));
    var _minute = real(string_copy(_str, 4, 2));
    var _second = real(string_copy(_str, 7, 2));
    var _millisecond = 0;

    var _dotPos = string_pos(".", _str);
    if (_dotPos > 0) {
        var _fracStr = string_copy(_str, _dotPos + 1, 6); // up to microseconds
        _millisecond = round(real("0." + _fracStr) * 1000);
    }

    return { 
		hour: _hour, 
		minute: _minute, 
		second: _second, 
		millisecond: _millisecond 
	};
}