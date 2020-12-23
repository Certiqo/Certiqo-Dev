const HDWalletProvider = require('truffle-hdwallet-provider');
var mnemonic = "";

module.exports = {
  networks: {
    ropsten: {
      provider: () => new HDWalletProvider(mnemonic, ''),
      network_id: 3,       
      gas: 4500000,       
      skipDryRun: true
    },
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    }
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.12"
    },
  }
};
