tests:
	forge test --fork-url https://rpc.ankr.com/eth --via-ir --match-path test/AoriProtocol.t.sol
test-deploy-sepolia:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://ethereum-sepolia.publicnode.com --via-ir
test-deploy-goerli:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth_goerli --via-ir
test-deploy-mainnet:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth --via-ir
test-deploy-polygon-mainnet:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://polygon.llamarpc.com --via-ir
test-deploy-avalanche:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://avalanche.drpc.org --via-ir