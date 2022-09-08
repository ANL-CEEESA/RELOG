VERSION := 0.5
PKG := ghcr.io/anl-ceeesa/relog-web

clean:
	rm -rfv build Manifest.toml test/Manifest.toml deps/formatter/build deps/formatter/Manifest.toml

docs:
	cd docs; julia --project=. make.jl; cd ..
	rsync -avP --delete-after docs/build/ ../docs/$(VERSION)/
	
docker-build:
	docker build --tag $(PKG):$(VERSION) .
	docker build --tag $(PKG):latest .

docker-push:
	docker push $(PKG):$(VERSION)
	docker push $(PKG):latest

docker-run:
	docker run -it --rm --name relog --volume $(PWD)/jobs:/app/jobs --publish 8000:8080 $(PKG):$(VERSION)

format:
	cd deps/formatter; ../../juliaw format.jl

test: test/Manifest.toml
	./juliaw test/runtests.jl

test/Manifest.toml: test/Project.toml
	julia --project=test -e "using Pkg; Pkg.instantiate()"

.PHONY: docs test format
