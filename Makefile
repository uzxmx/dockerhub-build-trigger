rootdir := $(shell pwd)

src_files := $(shell find . -name "*.go")

bin/utils: $(src_files)
	go build -o bin/utils

build: bin/utils

.PHONY: build

check_new_versions: build
	PATH=$(rootdir)/bin:$$PATH ./scripts/check_new_versions.sh

.PHONY: check_new_versions

create_repositories: build
	PATH=$(rootdir)/bin:$$PATH ./scripts/create_repositories.sh

.PHONY: create_repositories

clean:
	rm bin/utils

.PHONY: clean
