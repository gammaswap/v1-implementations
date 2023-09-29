<p align="center"><a href="https://gammaswap.com" target="_blank" rel="noopener noreferrer"><img width="100" src="https://app.gammaswap.com/logo.svg" alt="Gammaswap logo"></a></p>

<p align="center">
  <a href="https://github.com/gammaswap/v1-implementations/actions/workflows/main.yml">
    <img src="https://github.com/gammaswap/v1-implementations/actions/workflows/main.yml/badge.svg?branch=main" alt="Compile/Test/Publish">
  </a>
</p>

<h1 align="center">V1-Implementations</h1>

## Description
This is the repository for the implementation smart contracts of the GammaSwap V1 protocol.

This repository contains concrete implementations of GammaPools and their strategies using the abstract contracts from v1-core

The current implementation contracts in existence are for UniswapV2 and forks of UniswapV2.

The CPMMMath contract can be used as a library to calculate quantities to trade in GammaPool to rebalance a position's collateral for UniswapV2 and its forks

## Steps to Run GammaSwap Tests Locally

All tests are found in v1-liquidator repository. If you add new tests here, to run them do the following

1. Run `yarn` to install GammaSwap dependencies
2. Run `yarn test` to run hardhat tests
3. Run `yarn fuzz` to run foundry tests (Need foundry binaries installed locally)

To deploy contracts to local live network use v1-deployment repository

### Note
To install foundry locally go to [getfoundry.sh](https://getfoundry.sh/)

## Solidity Versions
Code is tested with solidity version 0.8.19.

Concrete and abstract contracts support only solidity version 0.8.19.

Interfaces support solidity version 0.8.0 and up.

## Publishing NPM Packages

To publish an npm package follow the following steps

1. Bump the package.json version to the next level (either major, minor, or patch version)
2. commit to the main branch adding 'publish package' in the comment section of the commit (e.g. when merging a pull request)

### Rules for updating package.json version

1. If change does not break interface, then it's a patch version update
2. If change breaks interface, then it's a minor version update
3. If change is for a new product release to public, it's a major version update
