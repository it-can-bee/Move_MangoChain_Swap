//mycoin Move
module mango_swap::mycoin {
    use std::option;
    use mgo::coin::{Self, Coin, TreasuryCap};
    use mgo::transfer;
    use mgo::tx_context::{Self, TxContext};
    use mgo::object::{Self, UID};
    use mgo::url::{Self, Url};



    struct MYCOIN has drop {}

    struct CoinMetadata has store {
        name: vector<u8>,
        symbol: vector<u8>,
        description: vector<u8>,
        icon_url: option::Option<Url>,
    }

    struct TreasuryCapHolder has key, store {
        id: UID,
        treasury_cap: TreasuryCap<MYCOIN>,
        metadata: CoinMetadata,
    }

    /*===============Coin=======================*/
    fun init(witness: MYCOIN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency
            (
                witness,
                6,
                b"OPCoin",
                b"OPCoin",
                b"Mango L2 coin",
                option::none(),
                // option::some(url::new_unsafe(string::utf8(b"https://mycoin.com/logo.png"))),
                ctx
            );

        let coin_metadata = CoinMetadata {
            name: b"Jeffy",
            symbol: b"Jeffy",
            description: b"Mango Coin desscription",
            icon_url: option::none(),
            // icon_url: option::some(url::new_unsafe(string::utf8(b"https://mycoin.com/logo.png"))),

        };

        transfer::public_freeze_object(metadata);
        let treasury_cap_holder = TreasuryCapHolder {
            id: object::new(ctx),
            treasury_cap,
            metadata: coin_metadata,
        };
        transfer::public_transfer(treasury_cap_holder, tx_context::sender(ctx))
    }

    public entry fun mint(
        treasury_cap_holder: &mut TreasuryCapHolder,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        coin::mint_and_transfer(&mut treasury_cap_holder.treasury_cap, amount, recipient, ctx)
    }

    public entry fun burnAllCoin
    (
        treasury_cap_holder: &mut TreasuryCapHolder,
        coin: Coin<MYCOIN>
    )
    {
        coin::burn(&mut treasury_cap_holder.treasury_cap, coin);
    }

    public entry fun burnByNumber
    (
        treasury_cap_holder: &mut TreasuryCapHolder,
         coins: &mut Coin<MYCOIN>,
         amount: u64,
         ctx: &mut TxContext
    )
    {
        let coins_to_burn = coin::take(coin::balance_mut(coins), amount, ctx);
        let treasury_cap = &mut treasury_cap_holder.treasury_cap;
        coin::burn(treasury_cap, coins_to_burn);
    }
    /*===============Update CoinMetadata=======================*/
    /// 更新`CoinMetadata`里coin name
    public entry fun update_name(
        treasury_cap_holder: &mut TreasuryCapHolder,  name: vector<u8>
    ) {
        treasury_cap_holder.metadata.name = name;
    }

    /// 更新`CoinMetadata`里coin的符号
    public entry fun update_symbol(
        treasury_cap_holder: &mut TreasuryCapHolder, symbol: vector<u8>
    ) {
        treasury_cap_holder.metadata.symbol = symbol;
    }

    /// 更新`CoinMetadata`里coin的描述
    public entry fun update_description(
        treasury_cap_holder: &mut TreasuryCapHolder, description: vector<u8>
    ) {
        treasury_cap_holder.metadata.description = description;
    }

    /// 更新 `CoinMetadata`URL
    public entry fun update_icon_url(
        treasury_cap_holder: &mut TreasuryCapHolder, new_url_bytes: vector<u8>
    ) {
        let new_url_string = std::ascii::string(new_url_bytes);
        let new_url = url::new_unsafe(new_url_string);
        treasury_cap_holder.metadata.icon_url = std::option::some(new_url);
    }

    /*===============Get CoinMetadata=======================*/
    public fun get_name(treasury_cap_holder: &mut TreasuryCapHolder): &vector<u8> {
        &treasury_cap_holder.metadata.name
    }

    public fun get_symbol(treasury_cap_holder: &mut TreasuryCapHolder): &vector<u8> {
        &treasury_cap_holder.metadata.symbol
    }

    public fun get_description(treasury_cap_holder: &mut TreasuryCapHolder): &vector<u8> {
        &treasury_cap_holder.metadata.description
    }

    public fun get_icon_url(treasury_cap_holder: &mut TreasuryCapHolder): &option::Option<Url> {
        &treasury_cap_holder.metadata.icon_url
    }

}