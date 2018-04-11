.PHONY: abi clean compile flat flat_os flat_apps test coverage

abi: clean compile
	node ./abi.js

clean:
	rm -rf build/
	rm -rf flat/
	rm -rf tmp/

compile:
	node_modules/.bin/truffle compile

coverage:
	node_modules/.bin/solidity-coverage

flat: clean flat_os flat_apps

flat_os:
	rm -rf tmp/
	mkdir tmp
	mkdir -p flat

	cp contracts/*.sol tmp/
	cp contracts/lib/* tmp/
	cp contracts/registry/functions/*.sol tmp/
	cp contracts/registry/functions/init/* tmp/
	cp contracts/registry/*.sol tmp/
	cp contracts/core/* tmp/

	sed -i '' -e "s/\(import \)\(.*\)\/\(.*\).sol/import '.\/\3.sol/g" tmp/*
	node_modules/.bin/truffle-flattener tmp/* | sed "1s/.*/pragma solidity ^0.4.21;/" > flat/auth-os.sol

flat_apps:
	rm -rf tmp/
	mkdir tmp
	mkdir -p flat

	cp contracts/core/* tmp/

	cp contracts/applications/crowdsale/DutchCrowdsale/functions/crowdsale/* tmp/
	cp contracts/applications/crowdsale/DutchCrowdsale/functions/init/* tmp/
	cp contracts/applications/crowdsale/DutchCrowdsale/functions/token/* tmp/
	cp contracts/applications/crowdsale/MintedCappedCrowdsale/functions/crowdsale/* tmp/
	cp contracts/applications/crowdsale/MintedCappedCrowdsale/functions/init/* tmp/
	cp contracts/applications/crowdsale/MintedCappedCrowdsale/functions/token/* tmp/
	cp contracts/applications/crowdsale/*.sol tmp/

	cp contracts/applications/token/StandardToken/functions/*.sol tmp/
	cp contracts/applications/token/StandardToken/functions/init/* tmp/
	cp contracts/applications/token/*.sol tmp/

	sed -i '' -e "s/\(import \)\(.*\)\/\(.*\).sol/import '.\/\3.sol/g" tmp/*
	node_modules/.bin/truffle-flattener tmp/* | sed "1s/.*/pragma solidity ^0.4.21;/" > flat/apps.sol

test:
	node_modules/.bin/truffle test
