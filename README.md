# The Aori Smart Contract

![.](assets/aori.svg)

Aori is a high-performance orderbook protocol for high-frequency trading on-chain and facilitating OTC settlement. A part of our protocol is our on-chain settlement contract used to settle [Seaport](https://docs.opensea.io/reference/seaport-overview) orders that were matched via Aori's off-chain orderbook. The surrounding logic can be found within the single file `AoriProtocol.sol`.

This repo is released under the [MIT License](LICENSE).

You can read more about the protocol in our litepaper [here](https://aori-io.notion.site/Aori-A-Litepaper-62f809b5c25c4798ad2c1d48d883e7bd?pvs=4).

---

If you have any further questions, refer to [the technical documentation](https://www.aori.io/developers). Alternatively, please reach out to us [on Discord](https://discord.gg/K37wkh2ZfR) or [on Twitter](https://twitter.com/aori_io).

## Deployments
| Network | Deployment Address |
| ------- | ------------------ |
| `Mainnet (1)` | [0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4](https://etherscan.io/address/0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4) |
| `Goerli (5)` | [0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4](https://goerli.etherscan.io/address/0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4) |
| `Polygon (137)` | [0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4](https://polygonscan.com/address/0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4) |
| `Avalanche (43114)` | [0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4](https://snowtrace.io/address/0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4) |
| `Sepolia(11155111)` | [0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4](https://sepolia.etherscan.io/address/0xEF3137050f3a49ECAe2D2Bae0154B895310D9Dc4) |

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test --fork-url https://rpc.ankr.com/eth --via-ir
```

You can also test using the `make` command which will run the above command.

### Contract deployment

Please create a `.env` file before deployment. An example can be found in `.env.example`.

#### Dryrun

```
forge script script/Deploy.s.sol:DeployScript --fork-url https://rpc.ankr.com/eth_goerli --via-ir
```
You can also do a dry fun by using the `make test-deploy` command which will run the above command.

### Live

```
forge script script/Deploy.s.sol -f [network] --verify --broadcast
```