# Ledger CLI tool



To build the generic CLI tool, you will need NPM installed in your environment. From the root folder of this repo:

```
cd node/cli
npm install
cd build
```

The CLI tool allows you to send two types of commands to the Ledger Nano S device. Please ensure that your device is plugged in and unlocked, with the app to open and on the home screen. For more information about this tool and the options available, it is highly recommended that you review the help guide, available from:
```bash
./cli.js sign --help
```


### getAddress

This is a generic request for the public key derived, given a BIP-32/BIP-44 path. For more information about what value to use, see [SLIP-0044](https://github.com/satoshilabs/slips/blob/master/slip-0044.md).

For most apps, a request for the public key will prompt the user on the Nano S device for confirmation. Please refer to your apps documentation for more information.
```bash
./cli.js getAddress "44'/<slip0044>'"
```

### sign
This command will send a number of transaction formats to the Ledger device for signing. It require the same BIP path as before, and will accept a number of transaction data formats. For example, to use a `json` formatted transaction from a file would look something like:
```bash
./cli.js sign "44'/<slip0044>'" --file --json  path/to/transaction.json
```
