var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "gentle know bundle hub uncover poet crumble teach attitude educate wrestle net";

module.exports = {
  networks: {
    develop: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:9545/", 0, 50);
      },
      network_id: '*',
      gas: 9999999,
      accounts: 30
    },
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*',
      gas: 6721975
    }
  }
};