JULIA := julia --color=yes --project=@.
SRC_FILES := $(wildcard src/*.jl test/*.jl)

VERSION_MAJOR := 0
VERSION_MINOR := 3
VERSION_PATCH := 0

VERSION_SHORT := $(VERSION_MAJOR).$(VERSION_MINOR)

all: docs test

build/sysimage.so: src/sysimage.jl Project.toml Manifest.toml
	$(JULIA) src/sysimage.jl

build/test.log: $(SRC_FILES) build/sysimage.so
	@echo Running tests...
	cd test; $(JULIA) --sysimage ../build/sysimage.so runtests.jl | tee ../build/test.log

clean:
	rm -rf build/*

docs:
	mkdocs build -d ../docs/$(VERSION_SHORT)/

test: build/test.log

test-watch:
	bash -c "while true; do make test --quiet; sleep 1; done"

.PHONY: docs test
