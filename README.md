# Data Aggregator Contracts for Collecting Allow Lists and Weights

👋 Welcome to the Data Aggregator Contracts repository! This project provides example Solidity contracts that demonstrate the aggregation of allow lists and weights from multiple sources. These contracts are designed to simplify the process of collecting and processing data from various sources and sending them as a single argument to a project contract.

## Features

✅ **Allow List Aggregation:** The `AllowlistDataSourceAggregator` contract showcases how to aggregate allow lists from multiple data sources. It verifies if an address is allowed by iterating through the data sources and checking each individual allow list.

✅ **Weight Aggregation:** The `DataWeightAggregator` contract demonstrates how to aggregate weights from multiple data sources. It calculates the average weight modifier using weighted arithmetic mean and adjusts the weight accordingly.

## Getting Started
1. Clone this repository: `git clone <repository-url>`
2. Navigate to the cloned directory: `cd data-aggregator-contracts`
3. Install Forge with `curl -L https://foundry.paradigm.xyz | bash`. If you already have Foundry installed, run `foundryup` to update to the latest version. More detailed instructions can be found in the [Foundry Book](https://book.getfoundry.sh/getting-started/installation).
4. Follow the instructions in the [Yarn Docs](https://classic.yarnpkg.com/en/docs/install). People tend to use the latest version of Yarn 1 (not Yarn 2+).
5. Deploy the contracts to your preferred Ethereum development network.
6. Interact with the deployed contracts by calling their functions.

## Contributing

👍 Contributions are welcome! If you have any ideas, suggestions, or improvements, please open an issue or submit a pull request. Let's make this project even better together!

## License

This project is licensed under the [MIT License](LICENSE).
