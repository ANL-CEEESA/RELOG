VERSION := 0.6

clean:
	rm -rfv build Manifest.toml test/Manifest.toml deps/formatter/build deps/formatter/Manifest.toml

docs:
	cd docs; julia --project=. make.jl; cd ..
	rsync -avP --delete-after docs/build/ ../docs/$(VERSION)/
	
format:
	cd deps/formatter; ../../juliaw format.jl

test: test/Manifest.toml
	./juliaw test/runtests.jl

test/Manifest.toml: test/Project.toml
	julia --project=test -e "using Pkg; Pkg.instantiate()"

.PHONY: docs test format
