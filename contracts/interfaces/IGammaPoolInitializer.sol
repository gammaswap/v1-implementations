pragma solidity ^0.8.0;

interface IGammaPoolInitializer {

    struct Parameters {
        uint24 protocol;
        address[] tokens;
        address cfmm;
    }
}
