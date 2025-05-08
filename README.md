## Bifrost Tokens

Bifrost ERC20 Tokens: Real's cross-chain erc20 Bridge using LayerZero

#### Vault

The Vault locks tokens on the source chain and sends a message to the token controller on the destination chain to mint corresponding tokens.

#### Controller

The Controller manages the minting and burning of tokens on the destination chain.

## Usage

To effectively use Bifrost, follow these steps:

Add Trusted Remote Address: Configure trusted addresses for both the Vault and Controller corresponding to the respective chain IDs.

Whitelist Token Addresses: Ensure that the source token (srcToken) and destination token (dstToken) addresses are whitelisted in the Vault.

Configure L2 Token Address: Whitelist the Layer 2 (L2) token address in the Controller.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/DeployVault.s.sol:DeployVault --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
