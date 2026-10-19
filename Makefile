.PHONY: build install release
build:
	bash scripts/build.sh
install:
	bash scripts/install.sh
release:
	bash scripts/release.sh $(VERSION)
