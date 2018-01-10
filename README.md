# Lua semantics in K Framework

## Requirements
* K Framework 4.0+
* Node.js 8+ with npm

## Usage
* Before running any Lua programs, install the Node.js dependencies using `npm install`.
* `kompile lua.k`
* `krun <program>.lua`

## Testing
Tests used are from the Lua 5.3 set of [lua-TestMore](https://github.com/fperrad/lua-TestMore). You can run the entire suite automatically with `run-tests.sh`, but `string.match` and related functions are not yet implemented, so the output must be manually interpreted.
