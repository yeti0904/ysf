import std.conv;
import std.format;
import std.algorithm;
import core.stdc.stdlib;
import error;
import lexer;

string CleanString(string str) {
	string ret;

	string[char] replace = cast(string[char]) [
		'!': "__bang__",
		'£': "__pound__",
		'$': "__dollar__",
		'%': "__percent__",
		'^': "__caret__",
		'&': "__ampersand__",
		'*': "__star__",
		'(': "__lparen__",
		')': "__rparen__",
		'-': "__dash__",
		'+': "__add__",
		'=': "__equals__",
		'[': "__lsquarebracket__",
		']': "__rsquarebracket__",
		'{': "__lcurlybracket__",
		'}': "__rcurlybracket__",
		':': "__colon__",
		';': "__semicolon__",
		'@': "__at__",
		'#': "__hashtag__",
		'~': "__tilde__",
		'<': "__leftthing__",
		'>': "__rightthing__",
		',': "__comma__",
		'.': "__dot__",
		'/': "__forwardslash__",
		'?': "__questionmark__",
		'|': "__vline__",
		'\\': "__backslash__",
		'¬': "__thing__"
	];

	foreach (ref ch ; str) {
		if (ch in replace) {
			ret ~= replace[ch];
		}
		else {
			ret ~= ch;
		}
	}

	return ret;
}

struct Variable {
	ushort addr;
	size_t size;
}

enum CompilerFeatures {
	FunctionBarriers = 0b00000001
}

class Compiler {
	ubyte            features = 0xFF;
	Lexer            lexer;
	size_t           i;
	bool             inFunction;
	string           lastFunction;
	string[]         lines;
	string[]         functions;
	size_t           statements;
	size_t[]         statementIDs;
	Variable[string] variables;
	ushort           variableAddress;
	string[][]       scopes;

	this() {
		
	}

	string[] CompilePushInt(int push) {
		return [
			"add si, 2",
			format("mov word [si], %d", push)
		];
	}

	string[] CompilePushVariable(string name) {
		return [
			"add si, 2",
			format("mov ax, %s", variables[name].addr),
			"mov [si], ax"
		];
	}

	string[] CompilePushString(string push) {
		string[] ret;

		ret ~= [
			"add si, 2",
			"mov word [si], 0"
		];

		foreach_reverse (ref ch ; push) {
			ret ~= [
				"add si, 2",
				format("mov word [si], %d", ch)
			];
		}

		return ret;
	}

	string[] CompileFunctionStart(string name) {
		string[] ret;

		if (features & CompilerFeatures.FunctionBarriers) {
			ret ~= format("jmp function_%s_end", name.CleanString());
		}

		ret ~= [
			format("function_%s:", name.CleanString())
		];

		return ret;
	}

	string[] CompileFunctionEnd(string name) {
		return [
			"ret",
			format("function_%s_end:", name.CleanString()),
		];
	}

	string[] CompileFunctionCall(string name) {
		return [
			format("call function_%s", name.CleanString())
		];
	}

	string[] CompileIfStart() {
		return [
			"mov ax, [si]",
			"sub si, 2",
			"cmp ax, 0",
			format("je statement_%d_end", statements)
		];
	}

	string[] CompileIfEnd() {
		string[] ret =  [
			format("statement_%d_end:", statementIDs[$ - 1])
		];

		statementIDs = statementIDs.remove(statementIDs.length - 1);

		return ret;
	}

	string[] CompileWhileStart() {
		return [
			format("statement_%d:", statements)
		];
	}

	string[] CompileWhileEnd() {
		string[] ret = [
			"mov ax, [si]",
			"sub si, 2",
			"cmp ax, 0",
			format("jne statement_%d", statementIDs[$ - 1])
		];

		statementIDs = statementIDs.remove(statementIDs.length - 1);

		return ret;
	}

	void Next() {
		++ i;

		if (i >= lexer.tokens.length) {
			assert(0);
		}
	}

	void ClearScope() {
		string[] thisScope = scopes[$ - 1]; // 190

		foreach (ref variable ; thisScope) {
			variableAddress -= variables[variable].size;
			variables.remove(variable);
		}

		scopes = scopes.remove(scopes.length - 1);
	}

	void AddScope() {
		scopes ~= [];
	}

	void Compile() {
		inFunction      = false;
		lines           = [];
		functions       = [];
		variableAddress = 0x0FFF;

		bool nextLocal = false;

		lines ~= [
			"bits 16",
			"org 0x0100",
			"cpu 586",
			"mov si, 0x8000"
		];
	
		for (i = 0; i < lexer.tokens.length; ++ i) {
			switch (lexer.tokens[i].type) {
				case TokenType.Integer: {
					nextLocal = false;
					
					lines ~= CompilePushInt(parse!int(lexer.tokens[i].contents));
					break;
				}
				case TokenType.String: {
					nextLocal = false;
					
					lines ~= CompilePushString(lexer.tokens[i].contents);
					break;
				}
				case TokenType.Asm: {
					nextLocal = false;
					
					lines ~= lexer.tokens[i].contents;
					break;
				}
				case TokenType.Word: {
					switch (lexer.tokens[i].contents) {
						case "function": {
							nextLocal = false;
							
							assert(!inFunction);
						
							Next();
							
							assert(lexer.tokens[i].type == TokenType.Word);
							
							lines ~= CompileFunctionStart(lexer.tokens[i].contents);

							inFunction    = true;
							lastFunction  = lexer.tokens[i].contents;
							functions    ~= lexer.tokens[i].contents;

							//AddScope();
							break;
						}
						case "endf": {
							nextLocal = false;
							
							assert(inFunction);

							lines ~= CompileFunctionEnd(lastFunction);

							inFunction = false;

							//ClearScope(); // 268
							break;
						}
						case "if": {
							nextLocal = false;
							
							++ statements;
							statementIDs ~= statements;

							lines ~= CompileIfStart();
							break;
						}
						case "endif": {
							nextLocal = false;
							
							assert(statementIDs.length > 0);

							lines ~= CompileIfEnd();
							break;
						}
						case "while": {
							nextLocal = false;
							
							++ statements;
							statementIDs ~= statements;

							lines ~= CompileWhileStart();
							break;
						}
						case "endwhile": {
							nextLocal = false;
							
							assert(statementIDs.length > 0);

							lines ~= CompileWhileEnd();
							break;
						}
						case "return": {
							nextLocal = false;
							
							lines ~= "ret";
							break;
						}
						case "local": {
							nextLocal = true;
							break;
						}
						case "variable": {
							Next();

							assert(lexer.tokens[i].type == TokenType.Word);

							string variable = lexer.tokens[i].contents;

							variables[variable]  = Variable(variableAddress, 2);
							variableAddress += 2;

							if (nextLocal) {
								scopes[$ - 1] ~= variable;
								nextLocal      = false;
							}
							break;
						}
						case "array": {
							Next();
							assert(lexer.tokens[i].type == TokenType.Integer);
							ushort elements = lexer.tokens[i].contents.parse!ushort();

							Next();
							assert(lexer.tokens[i].type == TokenType.Word);
							string variable = lexer.tokens[i].contents;

							variables[variable] = Variable(
								variableAddress, cast(ushort) (elements * 2)
							);

							if (nextLocal) {
								scopes[$ - 1] ~= variable;
								nextLocal      = false;
							}
							break;
						}
						default: {
							if (lexer.tokens[i].contents in variables) {
								lines ~= CompilePushVariable(lexer.tokens[i].contents);
								break;
							}
						
							if (!functions.canFind(lexer.tokens[i].contents)) {
								ErrorUndefinedFunction(lexer.tokens[i]);
								exit(1);
							}

							lines ~= CompileFunctionCall(lexer.tokens[i].contents);
							break;
						}
					}
					break;
				}
				default: assert(0);
			}
		}

		foreach (ref line ; lines) {
			if (line[$ - 1] != ':') {
				line = "    " ~ line;
			}
		}
	}
}
