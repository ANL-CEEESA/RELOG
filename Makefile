VERSION := 0.3
JULIA := julia --color=yes --project=.

all: docs

test:
	$(JULIA) -e 'using Pkg; Pkg.test("RELOG")'

docs:
	mkdocs build

docs-push:
	rsync -avP docs/ andromeda:/www/axavier.org/projects/RELOG/$(VERSION)/

.PHONY: docs test
