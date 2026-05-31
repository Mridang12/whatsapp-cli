SWIFT ?= swift
ARGS ?=

.PHONY: build test clean wmsg

wmsg:
	$(SWIFT) run wmsg $(ARGS)

build:
	$(SWIFT) build -c release --product wmsg
	mkdir -p bin
	cp .build/release/wmsg bin/wmsg

test:
	$(SWIFT) test

clean:
	rm -rf .build bin

