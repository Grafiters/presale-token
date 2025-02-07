require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 97
    },
    mumbai: {
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      accounts: ["371d8f22b9a617c04eef587602c3ddb268e1fbfebe7601e79665d7e5011cf117"]
    },
    ftm: {
      url: "https://rpc.testnet.fantom.network",
      accounts: ["371d8f22b9a617c04eef587602c3ddb268e1fbfebe7601e79665d7e5011cf117", "231cd59441c7ce7c7159ac301f6f60ccae842d3199d091ec7abcbea566179bb1", "f6108fe9db6afb938c84591ab39f70c5d798f09f28f1d15139ed1736b024ff0f"]
    }
  },
  sourcify: {
    enabled: false,
  },
  etherscan: {
    apiKey: {
      ftmTestnet: 'E92YYQT3N2VZ7XNGS8AHVMBPE6DHZ5JM3R',
    },
    disableSourcify: true,
    url: 'https://api-testnet.ftmscan.com/api', // URL API untuk BSC Testnet
    customChains: [
      {
        apiKey: '',
        network: 'ftmTestnet',
        chainId: '4002',
        urls: {
          apiURL: 'https://api-testnet.ftmscan.com/api', // URL API untuk BSC Testnet
          browserURL: 'https://testnet.ftmscan.com', // URL explorer untuk melihat transaksi
        },
      },
    ],
  },
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};
