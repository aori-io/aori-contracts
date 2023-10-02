# [Order]: Aori's Settlement Layer

Aori is a high-performance orderbook protocol for high-frequency trading on-chain and facilitating OTC settlement. [Order] is our on-chain protocol used to settle [Seaport](https://docs.opensea.io/reference/seaport-overview) orders that were matched via Aori's off-chain orderbook. The surrounding logic can be found within `OrderProtocol.sol`.

This repo is released under the [MIT License](LICENSE).

---

If you have any further questions, refer to [the technical documentation](https://www.aori.io/developers). Alternatively, please reach out to us [on Discord](https://discord.gg/K37wkh2ZfR) or [on Twitter](https://twitter.com/aori_io).

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
forge test
```

### Contract deployment

Please create a `.env` file before deployment. An example can be found in `.env.example`.

#### Dryrun

```
forge script script/Deploy.s.sol -f [network]
```

### Live

```
forge script script/Deploy.s.sol -f [network] --verify --broadcast
```