JULIA := julia --project=.
SRC_FILES := $(wildcard src/*.jl test/*.jl)
VERSION := dev

all: docs test

build/sysimage.so: src/sysimage.jl Project.toml Manifest.toml
	@$(JULIA) src/sysimage.jl test/runtests.jl

clean:
	rm -rf build/*

docs:
	mkdocs build -d ../docs/$(VERSION)/

format:
	julia -e 'using JuliaFormatter; format(["src", "test"], verbose=true);'

test:
	@$(JULIA) --sysimage build/sysimage.so test/runtests.jl

test-watch:
	bash -c "while true; do make test --quiet; sleep 1; done"

.PHONY: docs test
