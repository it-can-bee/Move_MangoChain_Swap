module mango_swap::swap {
    use mgo::coin::{Self, Coin};
    use mgo::balance::{Self, Supply, Balance};
    use mgo::object::{Self, UID, ID};
    use mgo::transfer;
    use mgo::tx_context::{TxContext, sender};
    use mgo::table::{Self, Table};
    use mgo::pay;

    use std::vector;

    const ErrZeroAmount: u64 = 1;
    const ErrNotEnoughXInPool: u64 = 2;
    const ErrNotEnoughYInPool: u64 = 3;
    const ErrInvalidVecotrType: u64 = 4;
    const ErrBalanceNotMatch: u64 = 5;
    const ErrNotEnoughBalanceLP: u64 = 6;
    const ErrRemoveFailed: u64 = 7;
    const ErrEmptyLPVector: u64 = 8;

    /*===============Data Structor=======================*/
    struct LP<phantom X, phantom Y> has drop {}

    struct Pool<phantom X, phantom Y> has key {
        id: UID,
        coin_x: Balance<X>,
        coin_y: Balance<Y>,
        lp_supply: Supply<LP<X, Y>>
    }

    struct Pocket has key, store {
        id: UID,
        table: Table<ID, vector<u64>>
    }

    /*===============关联函数=======================*/
    public fun new_pool<X, Y>(ctx: &mut TxContext) {
        let new_pool = Pool<X, Y> {
            id: object::new(ctx),
            coin_x: balance::zero(),
            coin_y: balance::zero(),
            lp_supply: balance::create_supply<LP<X, Y>>(LP {})
        };
        transfer::share_object(new_pool);
    }

    public fun add_liquidity<X, Y>
    (
        pool: &mut Pool<X, Y>,
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
        ctx: &mut TxContext
    ): (Coin<LP<X, Y>>, vector<u64>)
    {
        let coin_x_value = coin::value(&coin_x);
        let coin_y_value = coin::value(&coin_y);
        assert!(coin_x_value > 0 && coin_y_value > 0, ErrZeroAmount);
        coin::put(&mut pool.coin_x, coin_x);
        coin::put(&mut pool.coin_y, coin_y);
        let lp_bal = balance::increase_supply(&mut pool.lp_supply, coin_x_value + coin_y_value);
        let vec_value = vector::empty<u64>();
        vector::push_back(&mut vec_value, coin_x_value);
        vector::push_back(&mut vec_value, coin_y_value);
        (coin::from_balance(lp_bal, ctx), vec_value)
    }

    public fun remove_liquidity<X, Y>
    (
        pool: &mut Pool<X, Y>,
        lp: Coin<LP<X, Y>>,
        vec: vector<u64>,
        ctx: &mut TxContext
    ): (Coin<X>, Coin<Y>)
    {
        assert!(vector::length(&vec) == 2, ErrInvalidVecotrType);
        let lp_balance_value = coin::value(&lp);
        let coin_x_out = *vector::borrow(&vec, 0);
        let coin_y_out = *vector::borrow(&vec, 1);
        assert!(lp_balance_value == coin_x_out + coin_y_out, ErrBalanceNotMatch);
        assert!(balance::value(&pool.coin_x) > coin_x_out, ErrNotEnoughXInPool);
        assert!(balance::value(&pool.coin_y) > coin_y_out, ErrNotEnoughYInPool);
        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp));
        (
            coin::take(&mut pool.coin_x, coin_x_out, ctx),
            coin::take(&mut pool.coin_y, coin_y_out, ctx)
        )
    }

    //方便后续添加功能 只需要在此修改而不是withdraw_out
    public fun withdraw<X, Y>
    (
        pool: &mut Pool<X, Y>,
        lp: &mut Coin<LP<X, Y>>,
        vec: &mut vector<u64>,
        coin_x_out: u64,
        coin_y_out: u64,
        ctx: &mut TxContext
    ): (Coin<X>, Coin<Y>)
    {
        assert!(balance::value(&pool.coin_x) > coin_x_out, ErrNotEnoughXInPool);
        assert!(balance::value(&pool.coin_y) > coin_y_out, ErrNotEnoughYInPool);
        assert!(coin::value(lp) >= coin_x_out + coin_y_out, ErrNotEnoughBalanceLP);
        let coin_x_balance = vector::borrow_mut(vec, 0);
        *coin_x_balance = *coin_x_balance - coin_x_out;
        let coin_y_balance = vector::borrow_mut(vec, 1);
        *coin_y_balance = *coin_y_balance - coin_y_out;
        let lp_split = coin::split(lp, coin_x_out + coin_y_out, ctx);
        balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp_split));
        (
            coin::take(&mut pool.coin_x, coin_x_out, ctx),
            coin::take(&mut pool.coin_y, coin_y_out, ctx)
        )
    }

    public fun swap_X_outto_Y<X, Y>
    (
        pool: &mut Pool<X, Y>,
        paid_in: Coin<X>,
        ctx: &mut TxContext
    ): Coin<Y>
    {
        let paid_value = coin::value(&paid_in);
        coin::put(&mut pool.coin_x, paid_in);
        assert!(paid_value < balance::value(&pool.coin_y), ErrNotEnoughYInPool);
        coin::take(&mut pool.coin_y, paid_value, ctx)
    }

    public fun swap_Y_into_X<X, Y>
    (
        pool: &mut Pool<X, Y>,
        paid_in: Coin<Y>,
        ctx: &mut TxContext
    ): Coin<X>
    {
        let paid_value = coin::value(&paid_in);
        coin::put(&mut pool.coin_y, paid_in);
        assert!(paid_value < balance::value(&pool.coin_x), ErrNotEnoughXInPool);
        coin::take(&mut pool.coin_x, paid_value, ctx)
    }

    public entry fun create_pocket(ctx: &mut TxContext) {
        let pocket = Pocket {
            id: object::new(ctx),
            table: table::new<ID, vector<u64>>(ctx)
        };
        transfer::public_transfer(pocket, sender(ctx));
    }

    public entry fun generate_pool<X, Y>(ctx: &mut TxContext) {
        new_pool<X, Y>(ctx);
    }

    public entry fun deposit_totally<X, Y>
    (
        pool: &mut Pool<X, Y>,
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
        pocket: &mut Pocket,
        ctx: &mut TxContext
    ) {
        let (lp, vec) = add_liquidity(pool, coin_x, coin_y, ctx);
        let lp_id = object::id(&lp);
        table::add(&mut pocket.table, lp_id, vec);
        transfer::public_transfer(lp, sender(ctx));
    }

    public entry fun deposit_partly<X, Y>
    (
        pool: &mut Pool<X, Y>,
        coin_x_vec: vector<Coin<X>>,
        coin_y_vec: vector<Coin<Y>>,
        coin_x_amt: u64,
        coin_y_amt: u64,
        pocket: &mut Pocket,
        ctx: &mut TxContext
    ) {
        let coin_x_new = coin::zero<X>(ctx);
        let coin_y_new = coin::zero<Y>(ctx);
        pay::join_vec(&mut coin_x_new, coin_x_vec);
        pay::join_vec(&mut coin_y_new, coin_y_vec);
        let coin_x_in = coin::split(&mut coin_x_new, coin_x_amt, ctx);
        let coin_y_in = coin::split(&mut coin_y_new, coin_y_amt, ctx);
        let (lp, vec) = add_liquidity(pool, coin_x_in, coin_y_in, ctx);
        let lp_id = object::id(&lp);
        table::add(&mut pocket.table, lp_id, vec);
        transfer::public_transfer(lp, sender(ctx));
        let sender_address = sender(ctx);
        transfer::public_transfer(coin_x_new, sender_address);
        transfer::public_transfer(coin_y_new, sender_address);
    }

    public entry fun remove_liquidity_totally<X, Y>
    (
        pool: &mut Pool<X, Y>,
        lp: Coin<LP<X, Y>>,
        pocket: &mut Pocket,
        ctx: &mut TxContext
    ) {
        let lp_id = object::id(&lp);
        let vec = *table::borrow(&pocket.table, lp_id);
        let (coin_x_out, coin_y_out) = remove_liquidity(pool, lp, vec, ctx);
        assert!(coin::value(&coin_x_out) > 0 && coin::value(&coin_y_out) > 0, ErrRemoveFailed);
        let vec_out = table::remove(&mut pocket.table, lp_id);
        vector::remove(&mut vec_out, 0);
        vector::remove(&mut vec_out, 0);
        let sender_address = sender(ctx);
        transfer::public_transfer(coin_x_out, sender_address);
        transfer::public_transfer(coin_y_out, sender_address);
    }

    // 合并多个流动性提供者 并计算它们对应的X和Y代币的总金额
    public fun join_lp_vec<X, Y>
    (
        lp_vec: vector<Coin<LP<X, Y>>>,
        pocket: &mut Pocket,
        ctx: &mut TxContext
    ): (Coin<LP<X, Y>>, vector<u64>)
    {
        let idx = 0;
        let vec_length = vector::length(&lp_vec);
        assert!(vec_length > 0, ErrEmptyLPVector);
        //两个余额累加器combined_x_amt combined_y_amt
        let (combined_lp, combined_vec, combined_x_amt, combined_y_amt) =
            (coin::zero<LP<X, Y>>(ctx), vector::empty<u64>(), (0 as u64), (0 as u64));
        while (idx < vec_length) {
            //通过LP id找到对应的Table
            let lp_out = vector::pop_back(&mut lp_vec);
            let lp_id = object::id(&lp_out);
            let vec_out = table::remove(&mut pocket.table, lp_id);
            //取出table的值 弹出来放进去累加器
            combined_y_amt = combined_y_amt + vector::pop_back(&mut vec_out);
            combined_x_amt = combined_x_amt + vector::pop_back(&mut vec_out);
            vector::destroy_empty(vec_out);
            //逐步合并所有的LP代币到一个新的Coin对象
            pay::join(&mut combined_lp, lp_out);
            idx = idx + 1;
        };
        vector::destroy_empty(lp_vec);
        //重新将金额押入vector
        vector::push_back(&mut combined_vec, combined_x_amt);
        vector::push_back(&mut combined_vec, combined_y_amt);
        (combined_lp, combined_vec)
    }

    // 用户从流动性池中提取部分流动性 合并多个LP<X,Y>代币，并提取用户指定数量的X和Y代币
    public entry fun withdraw_out<X, Y>
    (
        pool: &mut Pool<X, Y>,
        lp_vec: vector<Coin<LP<X, Y>>>,
        coin_x_amt: u64,
        coin_y_amt: u64,
        pocket: &mut Pocket,
        ctx: &mut TxContext
    ) {
        let (combined_lp, combined_vec) = join_lp_vec(lp_vec, pocket, ctx);
        //从流动性池pool中提取用户指定的X和Y代币数量
        let (withdraw_coin_x, withdraw_coin_y) =
            withdraw(pool, &mut combined_lp, &mut combined_vec, coin_x_amt, coin_y_amt, ctx);
        let combined_lp_id = object::id(&combined_lp);
        //根据k v 将vec存进去table里边
        table::add(&mut pocket.table, combined_lp_id, combined_vec);
        let sender_address = sender(ctx);
        transfer::public_transfer(withdraw_coin_x, sender_address);
        transfer::public_transfer(withdraw_coin_y, sender_address);
        //剩下的lp也要还给调用者
        transfer::public_transfer(combined_lp, sender_address);
    }

    public entry fun swap_X_to_Y<X, Y>
    (
        pool: &mut Pool<X, Y>,
        coin_x_vec: vector<Coin<X>>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // 将coin_x_vec中的所有Coin<X>对象合并到coin_x中
        let coin_x = coin::zero<X>(ctx);
        //用户可能在不同的交易中获得了多个Coin<X>，每个Coin<X>是对象，而且交易的每个Coin<X>金额可能不同
        pay::join_vec<X>(&mut coin_x, coin_x_vec);
        let coin_x_in = coin::split(&mut coin_x, amount, ctx);
        let coin_y_out = swap_X_outto_Y(pool, coin_x_in, ctx);
        let sender_addres = sender(ctx);
        transfer::public_transfer(coin_x, sender_addres);
        transfer::public_transfer(coin_y_out, sender_addres);
    }

    public entry fun swap_y_to_x<X, Y>
    (
        pool: &mut Pool<X, Y>,
        coin_y_vec: vector<Coin<Y>>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coin_y = coin::zero<Y>(ctx);
        pay::join_vec<Y>(&mut coin_y, coin_y_vec);
        let coin_y_in = coin::split(&mut coin_y, amount, ctx);
        let coin_x_out = swap_Y_into_X(pool, coin_y_in, ctx);
        let sender_addres = sender(ctx);
        transfer::public_transfer(coin_x_out, sender_addres);
        transfer::public_transfer(coin_y, sender_addres);
    }
}