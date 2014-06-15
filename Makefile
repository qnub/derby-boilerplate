MOCHA_OPTS= --check-leaks
MOCHA_UI = bdd
REPORTER = spec

ci: install build test

test:
	@NODE_ENV=test ./node_modules/.bin/mocha \
		--reporter $(REPORTER) \
		--ui $(MOCHA_UI) \
		$(MOCHA_OPTS)

build:
	coffeegulp build

install:
	npm install
	./node_modules/.bin/bower install

.PHONY: test install build ci
