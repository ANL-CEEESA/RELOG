JULIA := julia --color=yes --project=@.
SRC_FILES := $(wildcard src/*.jl test/*.jl)
VERSION := 0.3

all: docs test

build/sysimage.so: src/sysimage.jl Project.toml Manifest.toml
	$(JULIA) src/sysimage.jl

build/test.log: $(SRC_FILES) build/sysimage.so
	@echo Running tests...
	cd test; $(JULIA) --sysimage ../build/sysimage.so runtests.jl | tee ../build/test.log

clean:
	rm -rf build/*

docs:
	mkdocs build

docs-push:
	rsync -avP docs/ isoron@axavier.org:/www/axavier.org/projects/RELOG/$(VERSION)/

test: build/test.log

test-watch:
	bash -c "while true; do make test --quiet; sleep 1; done"

.PHONY: docs test
