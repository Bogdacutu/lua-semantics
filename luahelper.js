
var op = process.argv[2];

if (op == "tonumber") {
  var input = process.argv[3];
  var num = parseFloat(input);
  if (!isNaN(num)) {
    process.stdout.write(num + "");
  }
}
