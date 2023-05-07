import std.stdio;
import core.stdc.stdlib;
import lexer;

void ErrorBegin(string fname, size_t line, size_t col) {
	version (Windows) {
		stderr.writef("%s:%d:%d: error: ", fname, line + 1, col + 1);
	}
	else {
		stderr.writef("\x1b[1m%s:%d:%d: \x1b[31merror:\x1b[0m ", fname, line + 1, col + 1);
	}
}

void ErrorUndefinedFunction(Token token) {
	ErrorBegin(token.file, token.line, token.col);
	stderr.writefln("Undefined function %s", token.contents);
}

void ErrorNonExistentFile(string file, size_t line, size_t col, string path) {
	ErrorBegin(file, line, col);
	stderr.writefln("Non existent file: %s", path);
}
