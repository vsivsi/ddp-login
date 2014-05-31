TESTS = test/index.coffee

test:
	@./node_modules/mocha/bin/mocha --compilers coffee:coffee-script/register --reporter list $(TESTFLAGS) $(TESTS)

.PHONY: test