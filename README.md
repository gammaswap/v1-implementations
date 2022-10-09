<p align="center"><a href="https://gammaswap.com" target="_blank" rel="noopener noreferrer"><img width="100" src="https://gammaswap.com/assets/images/image02.svg" alt="Gammaswap logo"></a></p>

<p align="center">
  <a href="https://github.com/gammaswap/v1-strategies/actions/workflows/main.yml"><img src="https://github.com/gammaswap/v1-strategies/actions/workflows/main.yml/badge.svg?branch=main" alt="Compile/Test">
</p>

# Steps to Run GammaSwap Tests Locally

1. Run ```npm install``` to install dependencies including hardhat.
2. Optional: copy [.env.example](.env.example) to .env. Fill details as needed.
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
