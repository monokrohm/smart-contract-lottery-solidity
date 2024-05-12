## Quickstart

```
git clone https://github.com/monokrohm/fund-me-solidity.git
cd foundry-fund-me-f23
forge build
```

### Start a Local Node

```shell
$ make anvil
```

### Deploy

Defaults to local node

```shell
$ make deploy
```

## Tests

```shell
$ forge test
```

or

```shell
$ forge test --fork-url $SEPOLIA_RPC_URL
```

## Deploy to a Testnet or Mainnet

1. Setup environment variables

Set `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables.

2. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH

3. Deploy

```shell
$ make deploy ARGS="--network sepolia"
```

This will setup a ChainlinkVRF Subscription. If you already have one, update it in the `scripts/HelperConfig.s.sol` file. It will also automatically add your contract as a consumer.

3. Register a Chainlink Automation Upkeep

Go to [automation.chain.link](https://automation.chain.link/new) and register a new upkeep. Choose `Custom logic` as the trigger mechanism for automation.

## Foundry Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

<b></b>  
Simulate Sepolia chain using anvil

```shell
$ forge test --fork-url $SEPOLIA_URL

$ forge test --mt <function> -vvvvv --fork-url <rpc_url>
```

### Coverage

See how much of the contract is being tested

```shell
$ forge coverage --fork-url/--rpc-url <rpc_url>
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Chisel

<u>Solidity in terminal</u>

```shell
$ chisel
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/DeployFundMe.s.sol --rpc-url <rpc_url> --private-key <your_private_key> --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Scripts

Run scripts after deploying to a testnet or local net

```shell
$ cast send <FUNDME_CONTRACT_ADDRESS> "fund()" --value 0.1ether --private-key <PRIVATE_KEY>
```

<b></b>  
Run a specific contract in a script

```shell
$ forge script script/Interactions.s.sol:FundFundMe --rpc-url <rpc_url>  --private-key <your_private_key>  --broadcast
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
