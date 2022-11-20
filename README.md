# Hexlink Contracts

This is the repo to hold all evm smart contracts for Hexlink, including:

1. The wallet contract implementation
2. The identity oracle implementation
3. The Hexlink name service and deployer implementation

# Commands

```shell
# compile contracts
npx hardhat compile

# run tests
npx hardhat clean

# get metadata of deployed contracts
npx hardhat metadata

# deploy to local
doppler run -- npx hardhat deploy

# deploy to goerli testnet
doppler run -- npx hardhat deploy --network goerli
```

# Etherscan verification

```shell
ndoppler run -- npx hardhat verify --network ropsten DEPLOYED_CONTRACT_ADDRESS $CONSTRUCTOR_PARAMS
```

# Error Code Map

HEXL001: 