# Move Swap MangoChain 

## 流动性池
本质是一个智能合约，允许用户在不需要中介或中心化交易所的情况下交易加密货币。


用户可以提供一定比例的两种货币成为流动性提供者，这个比例必须与池子中比例相同，以稳定两种货币的价值，否则可能出现利套利的情况。


流动性提供者将收到 LP 流动性代币，其作用类似于收据证明，只有凭借它才能解除流动性（将自己投入的两种货币取出）。


交易者可以用其中一种货币，在池子当中交换另一种货币。


每一笔交易都将产生手续费，而手续费将按照流动性提供者的贡献大小分配给他们。


## 项目数据结构设计

### LP 权益代币
只是一个凭证，内部并不需要存储什么额外的东西，所以可以当做Coin<T>的一个泛型类型来处理

public是新版本 Sui Move​ 的语法要求，为了以后支持类似private等功能做铺垫
### Pool
池子当中最为关键的当然就是两种货币各自的量，在正常的流动性资金池当中Supply，与用户手中的LP对应的量，成为具体能够兑换多少货币的关键

### Pocket （Wallet）
为了保证用户提供的凭证LP的有效性和真实性，再用一个结构来存储合约给出的凭证相关信息，以ID作为 Key，vector<u64>作为 
Value，来组建一个Table数据结构，其中vector里的第一个值是第一种货币的提供量，第二个值是第二种货币的提供量。
```
public struct Pocket has key {
    id: UID,
    //Table里边其实可以再套一个映射或者集合
    id_to_vec: Table<ID, vector<u64>>,
}
```

## 项目架构设计
### 创建流动性池
```
    public fun new_pool<X, Y>(ctx: &mut TxContext) {
        let new_pool = Pool<X, Y> {
            id: object::new(ctx),
            coin_x: balance::zero(),
            coin_y: balance::zero(),
            lp_supply: balance::create_supply<LP<X, Y>>(LP {})
        };
        transfer::share_object(new_pool);
    }
```
### 添加流动性
```
    public fun add_liquidity<X, Y>
    (
        pool: &mut Pool<X, Y>,
        coin_x: Coin<X>,
        coin_y: Coin<Y>,
        ctx: &mut TxContext
    ): (Coin<LP<X, Y>>, vector<u64>)
    {
        ......
    }
```
### 移除流动性
```
    public fun remove_liquidity<X, Y>
    (
        pool: &mut Pool<X, Y>,
        lp: Coin<LP<X, Y>>,
        vec: vector<u64>,
        ctx: &mut TxContext
    ): (Coin<X>, Coin<Y>)
    {
        ......
    }
```
### Swap
```
    public fun swap_..._into/outto_...<X, Y> {
        let new_pool = Pool<X, Y> {
            id: object::new(ctx),
            coin_x: balance::zero(),
            coin_y: balance::zero(),
            lp_supply: balance::create_supply<LP<X, Y>>(LP {})
        };
        transfer::share_object(new_pool);
    }
```
## Execute
```
//编译
mgo move build
//部署
mgo client publish --gas-budget 1000000000
```
