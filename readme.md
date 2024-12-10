# NFT Auction Smart Contract

A decentralized NFT auction system built on the Sui blockchain that enable bid on Nft and the higgestBidder will get the Nft.

## Overview

This project implements a complete NFT auction system with the following features:
- NFT creation and management
- Auction creation with customizable duration
- Bidding mechanism with minimum increments
- Automatic refund of previous bids
- Auction settlement with NFT transfer
- Admin control through AuthorityCap

## Smart Contracts

The project consists of two main modules:

### NFT Module [nft.move](https://github.com/fethallaheth/Sui-Nft-Auction/blob/main/sources/nft.move)
Handles NFT-related functionality:
- NFT creation with metadata
- NFT transfers
- NFT burning
- Event tracking for NFT operations

### Auction Module [nftAuction.move](https://github.com/fethallaheth/Sui-Nft-Auction/blob/main/sources/nftauction.move)
Manages the auction system:
- Auction creation and management
- Bidding mechanism
- Auction settlement
- Event tracking for auction operations

## Key Features

1. **Authorized Auction Creation**
   - Only authorized addresses with AuthorityCap can create auctions
   - Configurable auction duration (up to 2 days)

2. **Bidding System**
   - Minimum bid increment of 1 SUI
   - Automatic refund of previous bids
   - Protection against self-bidding

3. **Auction Settlement**
   - Automatic NFT transfer to winner
   - NFT burning if no bids are placed
   - Fund transfer to auction creator

4. **Event Tracking**
   - AuctionCreated
   - BidPlaced
   - AuctionEnded
   - AuctionSettled

## Building

To build and test the NFT Auction Smart Contract, follow these steps:

1. **Clone the Repository**
   ```bash
   git clone <https://github.com/fethallaheth/Sui-Nft-Auction.git>
   cd nftAuction
   ```

2. **Install Sui CLI**
   Ensure you have the Sui CLI installed. You can install it using Cargo:
   ```bash
   cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui
   ```

3. **Build the Project**
   Use the Sui CLI to build the Move modules:
   ```bash
   sui move build
   ```

4. **Run Tests**
   Execute the tests to ensure everything is working correctly:
   ```bash
   sui move test
   ```

5. **Publish the Contract**
   If you want to deploy the contract on the Sui devnet, use:
   ```bash
   sui client publish --gas-budget 100000000
   ```

### Environment Setup

- **Rust and Cargo**: Ensure you have Rust and Cargo installed on your system.
- **Sui CLI**: Version 1.0.0 or higher is recommended.
- **Sui Wallet**: You will need a Sui wallet with devnet SUI for testing and deployment.



