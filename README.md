# Steps to Run GammaSwap Tests Locally

1. Run ```npm install``` to install dependencies including hardhat.
2. Add secrets.json in the root folder with the following contents:
```
{
  "ALCHEMY_API_KEY": "<get account and key from https://www.alchemy.com/>",
  "GOERLI_ADDRESS": "<your wallet address here>",
  "GOERLI_PRIVATE_KEY": "<your private key here>"
}
```
You only need to fill in your address info.
3. Add .npmrc file in root folder with the following contents:
```
   @gammaswap:registry=https://npm.pkg.github.com/
   //npm.pkg.github.com/:_authToken=<GITHUB_ACCESS_TOKEN>
```
4. Run ```npx hardhat test```

# Steps to Deploy To Contracts To Local Live Network

1. Fill in the details in [scripts/deploy.ts](scripts/deploy.ts) 
from deploying v1-periphery deployPreCore logs.
2. Run ```npx hardhat --network localhost run scripts/deploy.ts``` to deploy.

Don't commit the secrets file.
