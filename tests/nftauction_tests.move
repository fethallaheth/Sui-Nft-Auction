module nftauction::nftauction_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use nftauction::nftauction::{Self, Auction, AuthorityCap};

    // Test constants
    const ADMIN: address = @0xAD;
    const BIDDER1: address = @0xB1;
    const BIDDER2: address = @0xB2;
    
    const MINUTE_MS: u64 = 60 * 1000;
    const HOUR_MS: u64 = 60 * MINUTE_MS;
    const DAY_MS: u64 = 24 * HOUR_MS;

    const INITIAL_BID: u64 = 1_000_000; // 1 SUI
    const HIGHER_BID: u64 = 2_000_000; // 2 SUI

    fun setup_test(test: &mut Scenario) {
        next_tx(test, ADMIN); {
            // Initialize clock for testing
            clock::create_for_testing(ctx(test));
        };
    }

    #[test]
    fun test_init_and_create_auction() {
        let scenario = test::begin(@0x1);
        setup_test(&mut scenario);
        
        // Test initialization
        next_tx(&mut scenario, ADMIN); {
            nftauction::init(ctx(&mut scenario));
        };

        // Test auction creation
        next_tx(&mut scenario, ADMIN); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let cap = test::take_from_sender<AuthorityCap>(&scenario);
            
            nftauction::startAuction(
                &cap,
                DAY_MS, // 1 day duration
                &clock,
                ctx(&mut scenario)
            );

            test::return_to_sender(&scenario, cap);
            clock::destroy_for_testing(clock);
        };

        test::end(scenario);
    }

    #[test]
    fun test_successful_bid() {
        let scenario = test::begin(@0x1);
        setup_test(&mut scenario);
        
        // Initialize
        next_tx(&mut scenario, ADMIN); {
            nftauction::init(ctx(&mut scenario));
        };

        // Create auction
        next_tx(&mut scenario, ADMIN); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let cap = test::take_from_sender<AuthorityCap>(&scenario);
            
            nftauction::startAuction(
                &cap,
                DAY_MS,
                &clock,
                ctx(&mut scenario)
            );

            test::return_to_sender(&scenario, cap);
            clock::destroy_for_testing(clock);
        };

        // Place first bid
        next_tx(&mut scenario, BIDDER1); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let auction = test::take_shared<Auction>(&scenario);
            let payment = coin::mint_for_testing<SUI>(INITIAL_BID, ctx(&mut scenario));

            nftauction::bid(
                &mut auction,
                payment,
                &clock,
                ctx(&mut scenario)
            );

            test::return_shared(auction);
            clock::destroy_for_testing(clock);
        };

        test::end(scenario);
    }

    #[test]
    fun test_auction_end_with_winner() {
        let scenario = test::begin(@0x1);
        setup_test(&mut scenario);
        
        // Initialize and create auction
        next_tx(&mut scenario, ADMIN); {
            nftauction::init(ctx(&mut scenario));
        };

        // Create auction
        next_tx(&mut scenario, ADMIN); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let cap = test::take_from_sender<AuthorityCap>(&scenario);
            
            nftauction::startAuction(
                &cap,
                DAY_MS,
                &clock,
                ctx(&mut scenario)
            );

            test::return_to_sender(&scenario, cap);
            clock::destroy_for_testing(clock);
        };

        // Place bid
        next_tx(&mut scenario, BIDDER1); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let auction = test::take_shared<Auction>(&scenario);
            let payment = coin::mint_for_testing<SUI>(INITIAL_BID, ctx(&mut scenario));

            nftauction::bid(
                &mut auction,
                payment,
                &clock,
                ctx(&mut scenario)
            );

            test::return_shared(auction);
            clock::destroy_for_testing(clock);
        };

        // End auction
        next_tx(&mut scenario, ADMIN); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            clock::set_for_testing(&mut clock, DAY_MS + 1); // Set time after auction end
            
            let auction = test::take_shared<Auction>(&scenario);
            
            nftauction::endAuction(
                &mut auction,
                &clock,
                ctx(&mut scenario)
            );

            test::return_shared(auction);
            clock::destroy_for_testing(clock);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = nftauction::nftauction::EBidTooLow)]
    fun test_bid_too_low() {
        let scenario = test::begin(@0x1);
        setup_test(&mut scenario);
        
        // Initialize and create auction
        next_tx(&mut scenario, ADMIN); {
            nftauction::init(ctx(&mut scenario));
        };

        // Create auction
        next_tx(&mut scenario, ADMIN); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let cap = test::take_from_sender<AuthorityCap>(&scenario);
            
            nftauction::startAuction(
                &cap,
                DAY_MS,
                &clock,
                ctx(&mut scenario)
            );

            test::return_to_sender(&scenario, cap);
            clock::destroy_for_testing(clock);
        };

        // Try to place bid that's too low
        next_tx(&mut scenario, BIDDER1); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let auction = test::take_shared<Auction>(&scenario);
            let payment = coin::mint_for_testing<SUI>(100_000, ctx(&mut scenario)); // Too low bid

            nftauction::bid(
                &mut auction,
                payment,
                &clock,
                ctx(&mut scenario)
            );

            test::return_shared(auction);
            clock::destroy_for_testing(clock);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = nftauction::nftauction::EAuctionEnded)]
    fun test_bid_after_end() {
        let scenario = test::begin(@0x1);
        setup_test(&mut scenario);
        
        // Initialize and create auction
        next_tx(&mut scenario, ADMIN); {
            nftauction::init(ctx(&mut scenario));
        };

        // Create auction
        next_tx(&mut scenario, ADMIN); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            let cap = test::take_from_sender<AuthorityCap>(&scenario);
            
            nftauction::startAuction(
                &cap,
                DAY_MS,
                &clock,
                ctx(&mut scenario)
            );

            test::return_to_sender(&scenario, cap);
            clock::destroy_for_testing(clock);
        };

        // Try to bid after auction end
        next_tx(&mut scenario, BIDDER1); {
            let clock = clock::create_for_testing(ctx(&mut scenario));
            clock::set_for_testing(&mut clock, DAY_MS + 1); // Set time after auction end
            
            let auction = test::take_shared<Auction>(&scenario);
            let payment = coin::mint_for_testing<SUI>(INITIAL_BID, ctx(&mut scenario));

            nftauction::bid(
                &mut auction,
                payment,
                &clock,
                ctx(&mut scenario)
            );

            test::return_shared(auction);
            clock::destroy_for_testing(clock);
        };

        test::end(scenario);
    }
}
