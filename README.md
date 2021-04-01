# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

1. 1~20 address used as owner(1) airlines(2-5) and oracles(1-20).
> Assumed owner and airlines also has oracles so the same address used for them.
> First airline was register when Contract deployment and it funded when DAPP initialized in contract.js.
> First airline then registered its flights and other airlines(3-5) after funded in DAPP initialized step, other airline did fund after registered.
> Oracles was registered when oracle server initialized.

2. Using dapp
> Select airline, flight and passenger address to simulate passenger buy insurance with constant fee.
> After buy insurance, click `Submit to fetch Oracles to get flight status` repeatly until show `processFlightStatus` event be emit, then can do `Withdraw`. 

## Prerequisites

Install Node.js

Install truffle: ```$ npm install -g truffle```

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`$ npm install` to install dependency:
`$ truffle compile`

## Develop Client

To use the dapp:

`$ truffle migrate`
`$ npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`$ npm run server`
`$ truffle test ./test/oracles.js`

## Test
using a terminal run truffle: `$ truffle develop`
using third terminal run oracle simulator server: `$ npm run server`, then wait until all oracles registered
using the truffle terminal to do the contract test: `$ truffle test ./test/flightSurety.js`
`$ truffle test ./test/oracles.js`

## Deploy

To migrate contracts to Truffle develop:
using a terminal run truffle: `$ truffle develop`
in truffle develop console: `$ migrate`

To build dapp for prod:
`$ npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)