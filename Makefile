tests:
	forge test --fork-url https://rpc.ankr.com/eth --via-ir --match-path test/AoriProtocol.t.sol

# Mainnet
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
test-deploy-arbitrum:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://arbitrum.llamarpc.com --via-ir
test-deploy-optimism:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://optimism.llamarpc.com --via-ir
test-deploy-base:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://base.drpc.org --via-ir

# Testnets
test-deploy-arbitrum-goerli:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://goerli-rollup.arbitrum.io/rpc --via-ir --legacy
test-deploy-arbitrum-sepolia:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://sepolia-rollup.arbitrum.io/rpc --via-ir
test-deploy-polygon-mumbai:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/polygon_mumbai --via-ir
test-deploy-optimism-goerli:
	forge script script/Deploy.s.sol:DeployScript --fork-url https://optimism-goerli.publicnode.com --via-ir