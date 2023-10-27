tests:
	forge test --fork-url https://rpc.ankr.com/eth --via-ir
test-deploy:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth_goerli --via-ir
