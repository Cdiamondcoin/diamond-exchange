## Compile current cotracts

After cloning contracts from git issue:

``` bash
git submodule update --init --remote --recursive
dapp --use solc:0.5.11 build
```

## Verify contract code

### Flatten contract to upload code etherscan

```bash
hevm flatten --source-file src/Cdc.sol --json-file out/Cdc.sol.json > Cdc-flatt.sol
```

### Get compiller version (set on upload time)

```bash
solc --version
```

## Solc versioning

### Build app with selected compiler version

```bash
dapp --use solc:0.5.11 build
```

### Install another solc version

Just use non existing version in contract project path

```bash
dapp --use solc:0.5.11 test
```

## How to create keystore file from private key

### Prerequisities

`pip install eth-account`

### Code

```python
import json
from eth_account import Account

enc = Account.encrypt('YOUR PRIVATE KEY', 'YOUR PASSWORD')

with open('/Users/vgaicuks/code/cdc-token/rinkeby.keystore', 'w') as f:
    f.write(json.dumps(enc))

```

# Deploy to rinkeby testnet

1. setup .env file
2. setup ETH_FROM and ETH_PASSWORD
3. ``. bin/deploy-rinkeby``
4. deploy Dpass
    1. ``. bin/deploy-rinkeby``
    2. ``. bin/verify-rinkeby``
5. setup deployed contracs addresses
6. ``. bin/setup-asm-rinkeby``
