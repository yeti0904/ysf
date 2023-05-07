import std.conv;
import std.format;
import std.algorithm;
import core.stdc.stdlib;
import error;
import lexer;

enum CompilerFeatures {
	FunctionBarriers = 0b00000001
}

class Compiler {
	ubyte    features = 0xFF;
	Lexer    lexer;
	size_t   i;
	bool     inFunction;
	string   lastFunction;
	string[] lines;
	string[] functions;
	size_t   statements;
	size_t[] statementIDs;

	this() {
		
	}

	string[] CompilePushInt(int push) {
		return [
			"add si, 2",
			format("mov word [si], %d", push)
		];
	}

	string[] CompilePushString(string push) {
		string[] ret;

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
			ret ~= format("jmp function_%s_end", name);
		}

		ret ~= [
			format("function_%s:", name)
		];

		return ret;
	}

	string[] CompileFunctionEnd(string name) {
		return [
			"ret",
			format("function_%s_end:", name),
		];
	}

	string[] CompileFunctionCall(string name) {
		return [
			format("call function_%s", name)
		];
	}

	string[] CompileIfStart() {
		return [
			"mov ax, [si]",
			"sub si, 2",
			"cmp ax, 1",
			format("jne statement_%d_end", statements)
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
			"cmp ax, 1",
			format("je statement_%d", statementIDs[$ - 1])
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

	void Compile() {
		inFunction = false;
		lines      = [];
		functions  = [];

		lines ~= [
			"bits 16",
			"org 0x0100",
			"cpu 586",
			"mov si, 0x8000"
		];
	
		for (i = 0; i < lexer.tokens.length; ++ i) {
			switch (lexer.tokens[i].type) {
				case TokenType.Integer: {
					lines ~= CompilePushInt(parse!int(lexer.tokens[i].contents));
					break;
				}
				case TokenType.String: {
					lines ~= CompilePushString(lexer.tokens[i].contents);
					break;
				}
				case TokenType.Asm: {
					lines ~= lexer.tokens[i].contents;
					break;
				}
				case TokenType.Word: {
					switch (lexer.tokens[i].contents) {
						case "function": {
							assert(!inFunction);
						
							Next();
							
							assert(lexer.tokens[i].type == TokenType.Word);
							
							lines ~= CompileFunctionStart(lexer.tokens[i].contents);

							inFunction    = true;
							lastFunction  = lexer.tokens[i].contents;
							functions    ~= lexer.tokens[i].contents;
							break;
						}
						case "endf": {
							assert(inFunction);

							lines ~= CompileFunctionEnd(lastFunction);

							inFunction = false;
							break;
						}
						case "if": {
							++ statements;
							statementIDs ~= statements;

							lines ~= CompileIfStart();
							break;
						}
						case "endif": {
							assert(statementIDs.length > 0);

							lines ~= CompileIfEnd();
							break;
						}
						case "while": {
							++ statements;
							statementIDs ~= statements;

							lines ~= CompileWhileStart();
							break;
						}
						case "endwhile": {
							assert(statementIDs.length > 0);

							lines ~= CompileWhileEnd();
							break;
						}
						case "return": {
							lines ~= "ret";
							break;
						}
						default: {
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
	}
}
