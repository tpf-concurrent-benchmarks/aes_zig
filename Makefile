SHELL:=/bin/bash

run:
	zig build run

test:
	zig build test --summary all

fmt:
	zig fmt *.zig
	zig fmt **/*.zig