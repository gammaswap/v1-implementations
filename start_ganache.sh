#!/bin/bash

ganache -l 0x1fffffffffffff -p 7545 -e 10000 --chain.allowUnlimitedContractSize --wallet.accountKeysPath keys.txt -m 'sentence tuna hundred'
