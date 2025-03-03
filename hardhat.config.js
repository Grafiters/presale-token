require('@nomiclabs/hardhat-waffle')

module.exports = {
  solidity: {
    compilers: [
      { version: '0.8.22' }
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  sourcify: {
    enabled: false,
  },
  etherscan: {
    disableSourcify: true,
    url: 'https://testnet.bscscan.com', // URL API untuk BSC Testnet
    customChains: [
      {
        apiKey: '',
        network: 'tbnb',
        chainId: '97',
        urls: {
          apiURL: 'https://testnet.bscscan.com/api', // URL API untuk BSC Testnet
          browserURL: 'https://testnet.bscscan.com', // URL explorer untuk melihat transaksi
        },
      },
    ],
  },
  networks: {
    tbeone: {
      url: 'https://rpc.beonescan.com',
      chainId: 223344,
      gasPrice: 3000000000,
      accounts: ['a96a6a0be55bcb6ea77fdf2da4c9c34fd88e28b67d849c07458c975fb9bb73a5']
    }, 
    tbnb: {
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      chainId: 97,
      gasPrice: 3000000000,
      accounts: ['9aca4cf105f87ee5ad3c972fcd24f464826e6e957b96944c46ae65a22ec72357']
    },
  }
};
// 0x5921D07D07DeC2aFFaB5468BB7216643dc175A66