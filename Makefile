JULIA := julia --color=yes --project=.

all: docs

docs:
	mkdocs build

docs-push:
	rsync -avP docs/ andromeda:/www/axavier.org/projects/RELOG/

.PHONY: docs
