/**
 * Created by danielalcarraz on 5/19/22.
 */
const ethers = require('ethers');
const { mnemonic } = require('./secrets.json');
let mnemonicWallet = ethers.Wallet.fromMnemonic(mnemonic);
console.log(mnemonicWallet.privateKey);