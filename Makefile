tests:
	forge test --fork-url https://rpc.ankr.com/eth --via-ir
test-deploy-sepolia:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://ethereum-sepolia.publicnode.com --via-ir
test-deploy-goerli:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth_goerli --via-ir
test-deploy-mainnet:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth --via-ir