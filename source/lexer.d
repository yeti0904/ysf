import std.file;
import std.path;
import std.stdio;
import std.string;
import error;

enum TokenType {
	None,
	Integer,
	Char,
	String,
	Word,
	Asm
}

struct Token {
	TokenType type;
	string    contents;
	string    file;
	size_t    line;
	size_t    col;
}

class Lexer {
	Token[] tokens;
	size_t  line;
	size_t  col;
	string  reading;
	string  file;
	bool    success;

	void AddToken(TokenType type, string contents) {
		tokens  ~= Token(type, contents, file, line, col);
		reading  = "";
	}

	void Lex(string code) {
		tokens = [];

		success = true;
		
		bool inString;
		bool inAsm;
		bool inInclude;

		for (size_t i = 0; i < code.length; ++ i) {
			if (code[i] == '\n') {
				++ line;
				col = 0;
			}
			else {
				++ col;
			}
		
			switch (code[i]) {
				case '(': {
					while ((code[i] != ')') && (i < code.length)) {
						++ i;

						if (code[i] == '\n') {
							++ line;
							col = 0;
						}
						else {
							++ col;
						}
					}
					break;
				}
				case '\'': {
					++ i;
					++ col;

					assert(code[i] != '\'');

					char ch = code[i];

					++ i;
					++ col;

					assert(code[i] == '\'');

					AddToken(TokenType.Char, [ch]);
					break;
				}
				case '\n':
				case '\t':
				case ' ': {
					if (reading == "") {
						break;
					}
					
					if (inString) {
						goto default;
					}

					if (inInclude) {
						string path = dirName(file) ~ '/' ~ reading;
						
						writefln("Including %s", path);

						if (!path.exists()) {
							ErrorNonExistentFile(
								file, line, col, path
							);
							
							success   = false;
							inInclude = false;
							reading   = "";
							break;
						}

						auto lexer = new Lexer();
						lexer.file = path;
						lexer.Lex(path.readText());

						tokens ~= lexer.tokens;

						if (!lexer.success) {
							success = false;
						}

						inInclude = false;
						reading   = "";

						break;
					}

					if (inAsm && code[i] == '\n') {
						AddToken(TokenType.Asm, reading);
						inAsm = false;
						break;
					}

					if (inAsm) {
						goto default;
					}
				
					if (reading == "asm") {
						inAsm   = true;
						reading = "";
						break;
					}

					if (reading == "include") {
						inInclude = true;
						reading   = "";
						break;
					}

					if (reading.isNumeric()) {
						AddToken(TokenType.Integer, reading);
					}
					else {
						AddToken(TokenType.Word, reading);
					}
					break;
				}
				case '"': {
					inString = !inString;

					if (!inString) {
						AddToken(TokenType.String, reading);
					}
					break;
				}
				default: {
					reading ~= code[i];
				}
			}
		}
	}
}
