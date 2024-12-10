module nftauction::NFT {
    use sui::event;
    use sui::transfer;
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    // ======== Events ========

    /// Emitted when a new NFT is minted
    public struct NFTMinted has copy, drop {
        nft_id: ID,
        name: String,
        description: String
    }

    /// Emitted when an NFT is burned (destroyed)
    public struct NFTBurned has copy, drop {
        nft_id: ID,
        name: String
    }

    /// Emitted when an NFT is transferred to a new owner
    public struct NFTTransferred has copy, drop {
        nft_id: ID,
        to: address
    }

    /// The main NFT struct representing the CHAOS NFT
    /// Contains metadata and ownership information
    public struct CHOASNFT has key, store {
        id: UID,
        name: String,
        description: String,
        image: Url,
        created_at: u64
    }



    /// Creates a new NFT
    /// Can only be called by the auction module
    /// @param nft_name - The name of the NFT
    /// @param nft_description - The description of the NFT
    /// @param nft_image - The URL of the NFT image
    /// @param ctx - The transaction context
    /// @return CHOASNFT - The newly created NFT
    public(package) fun private_mint( 
        nft_name: vector<u8>, 
        nft_description: vector<u8>, 
        nft_image: vector<u8>,
        ctx: &mut TxContext
    ): CHOASNFT {
        let nft = CHOASNFT {
            id: object::new(ctx),
            name: string::utf8(nft_name),
            description: string::utf8(nft_description),
            image: url::new_unsafe_from_bytes(nft_image),
            created_at: tx_context::epoch(ctx)
        };

        event::emit(NFTMinted {
            nft_id: object::uid_to_inner(&nft.id),
            name: nft.name,
            description: nft.description
        });

        nft
    }
    
    /// Transfers an NFT to a new owner
    /// @param nft - The NFT to transfer
    /// @param recipient - The address of the recipient
    public fun transfer_nft(nft: CHOASNFT, recipient: address) {
        let nft_id = object::uid_to_inner(&nft.id);

        event::emit(NFTTransferred {
            nft_id,
            to: recipient
        });

        transfer::public_transfer(nft, recipient);
    }
    
    /// Burns (destroys) an NFT
    /// Can only be called by the auction module
    /// Used when an auction ends with no bids
    /// @param nft - The NFT to burn
    public(package) fun burn(nft: CHOASNFT) {
        let nft_id = object::uid_to_inner(&nft.id);
        let name = nft.name;
        
        event::emit(NFTBurned {
            nft_id,
            name
        });

        let CHOASNFT {
            id,
            name: _,
            description: _,
            image: _,
            created_at: _
        } = nft;
        object::delete(id);
    }

    // ======== Getter Functions ========

    /// Returns the name of the NFT
    public fun name(nft: &CHOASNFT): String { nft.name }

    /// Returns the description of the NFT
    public fun description(nft: &CHOASNFT): String { nft.description }

    /// Returns the image URL of the NFT
    public fun image(nft: &CHOASNFT): Url { nft.image }

    /// Returns the creation timestamp of the NFT
    public fun created_at(nft: &CHOASNFT): u64 { nft.created_at }

    /// Returns the ID of the NFT
    public fun id(nft: &CHOASNFT): ID { object::uid_to_inner(&nft.id) }
}