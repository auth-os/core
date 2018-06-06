.PHONY: abi clean compile flat test coverage

abi: clean compile
	node ./.abi.js

clean:
	rm -rf build/
	rm -rf flat/
	rm -rf tmp/

compile:
	node_modules/.bin/truffle compile

coverage:
	node_modules/.bin/solidity-coverage

flat:
	rm -rf tmp/
	mkdir tmp
	mkdir -p flat

	cp contracts/*.sol tmp/
	cp contracts/lib/* tmp/
	cp contracts/registry/features/*.sol tmp/
	cp contracts/registry/*.sol tmp/
	cp contracts/core/* tmp/

	rm tmp/Migrations.sol

	sed -i '' -e "s/\(import \)\(.*\)\/\(.*\).sol/import '.\/\3.sol/g" tmp/*
	node_modules/.bin/truffle-flattener tmp/* | sed "1s/.*/pragma solidity ^0.4.23;/" > flat/auth-os.sol

test:
	node_modules/.bin/truffle test
