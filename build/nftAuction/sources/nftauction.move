module nftauction::nftauction {
    use sui::clock::{Self, Clock};
    use nftauction::NFT::{Self, CHOASNFT};
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use std::option;
    use sui::event;
    use std::string::String;
    use sui::url::Url;

    // Constants that were removed but are needed
    const MIN_BID_INCREMENT: u64 = 1_000_000; // 1 SUI minimum increment
    const MAX_DURATION: u64 = 2 * 24 * 60 * 60 * 1000; // 2 days in milliseconds

    // ======== Constants ========

    /// Error: Auction has not ended yet
    const EAuctionNotEnded: u64 = 1;
    /// Error: Auction has already ended
    const EAuctionEnded: u64 = 2;
    /// Error: Bid amount is too low
    const EBidTooLow: u64 = 3;
    /// Error: Auction is already settled
    const EAuctionSettled: u64 = 5;
    /// Error: Duration is too short
    const EDurationTooShort: u64 = 6;
    /// Error: Invalid bidder
    const EInvalidBidder: u64 = 7;
    /// Error: Invalid bid amount
    const EInvalidBidAmount: u64 = 8;
    /// Error: No winner for the auction
    const ENoWinner: u64 = 9;
    /// Error: Duration exceeds maximum allowed
    const EDurationTooLong: u64 = 10;
    /// Error: Not authorized to perform this action
    const ENotAuthorized: u64 = 11;

    // ======== Events ========

    /// Emitted when a new auction is created
    public struct AuctionCreated has copy, drop {
        auction_id: ID,
        nft_id: ID,
        creator: address,
        start_time: u64,
        end_time: u64
    }

    /// Emitted when a new bid is placed
    public struct BidPlaced has copy, drop {
        auction_id: ID,
        bidder: address,
        amount: u64,
        previous_bidder: Option<address>,
        previous_amount: u64
    }

    /// Emitted when an auction ends with a winner
    public struct AuctionEnded has copy, drop {
        auction_id: ID,
        winner: address,
        winning_bid: u64,
        nft_id: ID
    }

    /// Emitted when an auction is settled
    public struct AuctionSettled has copy, drop {
        auction_id: ID,
        nft_burned: bool
    }

    // ======== Core Objects ========

    /// The main Auction struct that holds the auction state
    public struct Auction has key {
        id: UID,
        startTime: u64,
        endTime: u64,
        nftid: Option<CHOASNFT>,
        highestBid: Balance<SUI>,
        highestBidder: Option<address>,
        settled: bool,
        creator: address
    }

    /// Capability that controls who can create auctions
    public struct AuthorityCap has key {
        id: UID,
        admin: address
    }

    // ======== Core Functions ========

    /// Initializes the module and creates the authority capability
    fun init(ctx: &mut TxContext) {
        let authority = AuthorityCap {
            id: object::new(ctx),
            admin: tx_context::sender(ctx)
        };
        transfer::transfer(authority, tx_context::sender(ctx));
    }

    /// Creates a new auction
    /// Only callable by authorized addresses with AuthorityCap
    public entry fun startAuction(
        authority: &AuthorityCap,
        duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Only authorized users can create auctions
        assert!(authority.admin == tx_context::sender(ctx), ENotAuthorized);
        
        assert!(duration > 0, EDurationTooShort);
        assert!(duration <= MAX_DURATION, EDurationTooLong);
        
        let current_time = clock::timestamp_ms(clock);
        let endtime = current_time + duration;
        
        let nft = NFT::private_mint(
            b"CHAOSNFT", 
            b"THIS IS AN NFT FOR THE CHAOS AND NO ONE CAN BE CHAOS MAYBE YOU CAN BE FAKE ONE",
            b"https::FAKEIMGE.com", 
            ctx
        );

        let nft_id = NFT::id(&nft);
        
        let auction = Auction {
            id: object::new(ctx),
            startTime: clock::timestamp_ms(clock),
            endTime: endtime,
            nftid: option::some(nft),
            highestBid: balance::zero(),
            highestBidder: option::none(),
            settled: false,
            creator: tx_context::sender(ctx)
        };

        let auction_id = object::uid_to_inner(&auction.id);
        
        event::emit(AuctionCreated {
            auction_id,
            nft_id,
            creator: tx_context::sender(ctx),
            start_time: clock::timestamp_ms(clock),
            end_time: endtime
        });

        transfer::share_object(auction);
    }

    /// Places a bid on an active auction
    public entry fun bid(
        auction: &mut Auction,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!auction.settled, EAuctionSettled);
        assert!(clock::timestamp_ms(clock) > auction.endTime, EAuctionEnded);
        
        let bidder = tx_context::sender(ctx);
        let bid_amount = coin::value(&payment);
        let current_highest = balance::value(&auction.highestBid);
        
        assert!(bid_amount > 0, EInvalidBidAmount);
        assert!(bid_amount >= current_highest + MIN_BID_INCREMENT, EBidTooLow);
        
        if (option::is_some(&auction.highestBidder)) {
            assert!(option::borrow(&auction.highestBidder) != &bidder, EInvalidBidder);
        };

        let previous_bidder = auction.highestBidder;
        let previous_amount = current_highest;

        if (current_highest > 0 && option::is_some(&previous_bidder)) {
            let previous_bid = coin::from_balance(
                balance::withdraw_all(&mut auction.highestBid),
                ctx
            );
            transfer::public_transfer(previous_bid, *option::borrow(&previous_bidder));
        };

        balance::join(&mut auction.highestBid, coin::into_balance(payment));
        auction.highestBidder = option::some(bidder);

        event::emit(BidPlaced {
            auction_id: object::uid_to_inner(&auction.id),
            bidder,
            amount: bid_amount,
            previous_bidder,
            previous_amount
        });
    }

    /// Ends an auction and handles NFT and fund transfers
    public entry fun endAuction(
        auction: &mut Auction, 
        clock: &Clock,
        ctx: &mut TxContext 
    ) {
        // NOTE we can make it callable by anyone if we want but lets keep it for now
        assert!(tx_context::sender(ctx) == auction.creator, ENotAuthorized);
        assert!(clock::timestamp_ms(clock) > auction.endTime, EAuctionNotEnded);
        assert!(!auction.settled, EAuctionSettled);

        auction.settled = true;
        let nft = option::extract(&mut auction.nftid);
        
        if (balance::value(&auction.highestBid) == 0) {
            event::emit(AuctionSettled {
                auction_id: object::uid_to_inner(&auction.id),
                nft_burned: true
            });
            NFT::burn(nft);
        } else {
            assert!(option::is_some(&auction.highestBidder), ENoWinner);
            let winner = option::extract(&mut auction.highestBidder);
            let winning_bid = balance::value(&auction.highestBid);
            
            event::emit(AuctionEnded {
                auction_id: object::uid_to_inner(&auction.id),
                winner,
                winning_bid,
                nft_id: NFT::id(&nft)
            });
            
            NFT::transfer_nft(nft, winner);
            
            let funds = coin::from_balance(
                balance::withdraw_all(&mut auction.highestBid),
                ctx
            );
            transfer::public_transfer(funds, tx_context::sender(ctx));
        }
    }

    // ======== View Functions ========

    /// Returns basic auction information
    public fun get_auction_info(auction: &Auction): (u64, u64, bool) {
        (auction.startTime, auction.endTime, auction.settled)
    }

    /// Returns the current highest bid amount
    public fun get_highest_bid(auction: &Auction): u64 { 
        balance::value(&auction.highestBid) 
    }

    /// Returns the current highest bidder
    public fun get_highest_bidder(auction: &Auction): Option<address> { 
        auction.highestBidder 
    }

    /// Returns the NFT metadata
    public fun get_nft_info(auction: &Auction): (String, String, Url) {
        assert!(option::is_some(&auction.nftid), 0);
        let nft = option::borrow(&auction.nftid);
        (NFT::name(nft), NFT::description(nft), NFT::image(nft))
    }

    /// Checks if the auction is currently active
    public fun is_active(auction: &Auction, clock: &Clock): bool {
        !auction.settled && 
        clock::timestamp_ms(clock) >= auction.startTime && 
        clock::timestamp_ms(clock) < auction.endTime
    }

    /// Checks if the auction has ended
    public fun is_ended(auction: &Auction, clock: &Clock): bool {
        auction.settled || clock::timestamp_ms(clock) > auction.endTime
    }

    /// Checks if the auction is settled
    public fun is_settled(auction: &Auction): bool { 
        auction.settled 
    }

    /// Returns the auction end time
    public fun get_end_time(auction: &Auction): u64 { 
        auction.endTime 
    }

    /// Returns the auction start time
    public fun get_start_time(auction: &Auction): u64 { 
        auction.startTime 
    }
}

