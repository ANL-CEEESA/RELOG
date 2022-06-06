JULIA := julia --color=yes --project=@.
SRC_FILES := $(wildcard src/*.jl test/*.jl)
VERSION := 0.5

all: docs test

build/sysimage.so: src/sysimage.jl Project.toml Manifest.toml
	mkdir -p build
	$(JULIA) src/sysimage.jl

build/test.log: $(SRC_FILES) build/sysimage.so
	cd test; $(JULIA) --sysimage ../build/sysimage.so runtests.jl

clean:
	rm -rf build/*

docs:
	mkdocs build -d ../docs/$(VERSION)/

docker-build:
	docker build --tag relog:0.6 .

format:
	julia -e 'using JuliaFormatter; format(["src", "test"], verbose=true);'

test: build/test.log

test-watch:
	bash -c "while true; do make test --quiet; sleep 1; done"

.PHONY: docs test

