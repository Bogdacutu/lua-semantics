#!/bin/bash -ex
kompile -v --debug lua.k
for test in tests/*.lua; do
	krun -v --debug "$test"
done
