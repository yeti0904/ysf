import std.file;
import std.path;
import std.array;
import std.stdio;
import std.format;
import std.process;
import core.stdc.stdlib;
import lexer;
import compiler;

string appHelp = "Usage: yfs (inFile) (options)

Options:
    -o / --out    : set the output binary/asm
    -t / --tokens : print tokens after lexing
    -n / --nasm   : call nasm to assemble the compiled code";

void main(string[] args) {
	string inFile;
	string outFile = "/dev/stdout";
	bool   showTokens;
	bool   callAssembler;
	string assemblerCall;

	if (args.length <= 1) {
		writeln(appHelp);
		return;
	}

	for (size_t i = 1; i < args.length; ++ i) {
		if (args[i][0] == '-') {
			switch (args[i]) {
				case "-o":
				case "--out": {
					++ i;
					outFile = args[i];
					break;
				}
				case "-t":
				case "--tokens": {
					showTokens = true;
					break;
				}
				case "-n":
				case "--nasm": {
					callAssembler = true;
					assemblerCall = "nasm -f bin %s -o %s";
					break;
				}
				default: {
					stderr.writefln("Unknown parameter %s", args[i]);
					exit(1);
				}
			}
		}
		else {
			if (inFile == "") {
				inFile = args[i];
			}
			else {
				stderr.writefln("Input file set twice (tried to set to %s)", args[i]);
				exit(1);
			}
		}
	}

	auto lexer = new Lexer();

	lexer.file = baseName(inFile);

	lexer.Lex(inFile.readText());

	if (showTokens) {
		foreach (i, ref token ; lexer.tokens) {
			writefln("%d: %s", i, token);
		}
	}

	auto compiler = new Compiler();
	compiler.lexer = lexer;
	compiler.Compile();

	if (!lexer.success) {
		return;
	}

	std.file.write(outFile.setExtension("asm"), compiler.lines.join("\n") ~ '\n');
	
	if (callAssembler) {
		string command = format(assemblerCall, outFile.setExtension("asm"), outFile);
		auto status    = executeShell(command);

		writeln(command);
		writeln(status.output);
	}
}
