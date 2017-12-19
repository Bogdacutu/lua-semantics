var fs = require("fs");
var luaparse = require("luaparse");
var spawnSync = require("child_process").spawnSync;
var tmp = require("tmp");

function unicodeEscape(str) {
	return str.replace(/[\s\S]/g, function(character) {
		var escape = character.charCodeAt().toString(16),
		    longhand = escape.length > 2;
		return '\\' + (longhand ? 'u' : 'x') + ('0000' + escape).slice(longhand ? -4 : -2);
	});
}

var path = process.argv[2];
var source = fs.readFileSync(path).toString("utf8");
if (source[0] == "#") {
	source = source.substring(source.indexOf("\n") + 1);
}
var parser = luaparse.parse(source, {
	comments: false,
	luaVersion: "5.3",
	extendedIdentifiers: true,
	wait: true
});

var prevToken;
var token = parser.lex();
var script = "";
while (token.type != luaparse.tokenTypes.EOF) {
	if (token.type == luaparse.tokenTypes.Punctuator && token.value == "//") {
		var prevTokenStr = source.substring(prevToken.range[0], prevToken.range[1]);
		if (prevToken.type == luaparse.tokenTypes.NumericLiteral && prevTokenStr.indexOf(".") < 0 && prevTokenStr.indexOf("e") < 0) {
			script += "i/ /";
		} else {
			script += "/ /";
		}
	} else if (token.type == luaparse.tokenTypes.StringLiteral) {
		script += "\"" + unicodeEscape(token.value) + "\"";
	} else if (token.type == luaparse.tokenTypes.NilLiteral) {
		script += "nil";
	} else {
		script += token.value;
	}
	script += " ";

	prevToken = token;
	token = parser.lex();
}

var tmpsrc = tmp.fileSync({ keep: false });
fs.writeFileSync(tmpsrc.name, script);
var child = spawnSync("kast", [tmpsrc.name]);
process.stdout.write(child.stdout);
process.stderr.write(child.stderr);
