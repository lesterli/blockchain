# Substrate

Substrate是什么？

Substrate 是一个区块链平台，具有完全通用的状态转换功能(State Transition Function, STF)，和模块化组件，实现了共识，网络和配置。除此之外，它有底层数据结构的标准和约定，特别是运行时模块库(Substrate Runtime Module Library, SRML)。从而使得快速开发一条区块链成为现实。

本质上，Substrate是三种技术的结合：WebAssembly，Libp2p和GRANSPA共识。

它既是用于构建新区块链的库/框架，也是一个区块链客户端的关键骨架，能够与任何基于Substrate的链同步。

它有三个特性：

* 通用的状态转换功能
* 与生俱来的轻客户端功能
* 快速块生成，自适应且最终确定性的共识算法

> GRANDPA (GHOST-based Recursive ANcestor Deriving Prefix Agreement), 基于GHOST的递归祖先导出前缀协议。

## 总体设计

Substrate框架分为：

* Substrate Core：共识，P2P，交易池，RPC
* Runtime：虚拟机等，需要对运行结果进行共识的功能组件应该归属于Runtime

Substrate将区块链系统做了模块化，提供框架功能，由于抽象出Runtime，实现了**区块链系统升级**功能。

### 核心数据类型

Substrate的底层核心有几种数据类型：

* Hash，哈希
* BlockNumber
* DigestItem
* Digest
* Header
* Extrinsic
* Block

```Rust
Header := Parent + ExtrinsicsRoot + StorageRoot + Digest
Block := Header + Extrinsics + Justifications
```

每一个数据类型，都对应定义在`/core/src-primitives/src/traits.rs`中的trait。

SRML中提供了每种trait的通用参考实现。

### Extrinsics外部性

Substrate 中的 Extrinsics 是指来自“外部世界”的信息，它包含在链的块中。熟悉比特币或以太坊的话，这意味着交易。但事实上在 Substrate 中，外部性分为两大类，其中只有一类是交易。另一个被称为 inherents 固有性。

这两者之间的区别在于交易是在网络上被签名和广播，并且本身可以被认为是有用的。
与此同时，固有性不会在网络上传递，也不会签名。它们代表**描述运行时环境的数据**，但不要求任何东西来证明它，例如签名。相反，它们被认为是“真实的”，仅仅是因为有足够多的验证者已经同意它们是合理的。

举一个例子，有固有的时间戳，它设置块的当前时间戳。这不是Substrate的固定部分，但是作为Substrate Runtime Module Library的一部分，可以根据需要使用。没有签名可以从根本上证明一个块在给定时间以与签名可以“证明”花费某些特定资金的愿望完全相同的方式创作。相反，每个验证器的业务是确保他们在同意候选块有效之前将时间戳设置为合理的值。

内置的Extrinsics：Substrate运行时模块库中，包括有时间戳和slashing（削减）两个内置的外部性功能。

### 运行时和API

Substrate链都具有运行时。运行时是WebAssembly “blob”，其中包含许多入口点。作为底层Substrate规范的一部分，需要一些入口点。其他仅仅是约定，并且要求Substrate客户端的默认实现能够创建块。

如果要使用 Substrate 开发链，则需要实现`Core`trait，它生成一个API，其中包含与运行时交互所需的最少功能。Substrate 提供了一个名为`impl_runtime_apis!`的特殊宏，用来实现运行时API traits，所有实现需要在一次`impl_runtime_apis!`宏调用中完成。所有参数和返回值都需要实现`parity-codec`，以便可编码和解码。

以下是Polkadot PoC-3中API实现的一小部分：

```Rust
impl_runtime_apis! {
	impl client_api::Core<Block> for Runtime {
		fn version() -> RuntimeVersion {
			VERSION
		}

		fn execute_block(block: Block) {
			Executive::execute_block(block)
		}

		fn initialize_block(header: <Block as BlockT>::Header) {
			Executive::initialize_block(&header)
		}
	}
	// ---snip---
}
```

### 区块authoring逻辑

“authoring”是比特币中所谓“mining”的更通用术语。

在Substrate中，区块链同步和块生成（authoring）之间存在一个主要区别。

第一种情况可称为“完整节点”（或“轻节点” - Substrate支持两者）：块生成必然需要同步节点，因此所有块生成客户端必须能够同步。然而，反之则不然。

在块生成节点中，但不在“同步节点”中的，三个主要功能是：交易队列逻辑，固有交易知识和BFT共识逻辑。

BFT共识逻辑是作为Substrate的核心元素提供的，可以忽略，因为它只在SDK下的`authorities()`API条目中公开。

Substrate中的交易队列逻辑被设计为尽可能通用，允许运行时通过`initialize_block`和`apply_extrinsic`调用来表示哪些交易适合包含在块中。但是优先级和替换策略等更细微的方面目前必须“硬编码”，作为区块链authoring代码的一部分。Substrate的交易队列参考实现应该足以用于初始链实现。

固有外部知识在某种程度上是通用的，并且按照惯例，外部函数的实际构造被委托给运行时中的“软代码”。如果链中需要额外的外部信息，则需要更改块生成逻辑以将其提供到运行时，并且运行时的`intrinsic_extrinsics`调用将需要使用此额外信息以构造任何其他外部交易包含在块中。

## 项目结构

* `ci` Github运行Substrate的脚本
* `core` Substrate Core，框架的核心，提供链系统基础功能
* `node` Substrate自带的使用实例，调试框架的入口点
* `node-template` 更精简的node
* `scripts` 项目构建脚本
* `srml` Substrate默认提供的Runtime模块，srml，Substrate Runtime Module Library的缩写
* `subkey` 生成公私钥的小工具
* `test-utils` 测试工具集

### `core`目录

共识相关的组件：

* `basic-authorship` 提供共识模块提议者Proposer的构建
* `consensus` -> `aura` 提供了共识算法Aura（Authority-round）实现
* `consensus` -> `babe` 提供了共识算法BABE实现
* `consensus` -> `common` 定义了共识节点所需的一些基础接口
* `consensus` -> `rhd` 提供了共识算法rhd（Rhododendron Round-Based）实现
* `consensus` -> `slots` 基于slots通用的共识实用程序
* `finality-grandpa` 提供区块一致性认证

> BABE, Blind Assignment for Blockchain Extension 

状态相关的组件：

* `state-db` 状态数据库，及**状态裁剪**功能
* `state-machine` 状态机，世界状态的转换
* `trie` MPT，世界状态，只有状态树

Runtime相关的组件：

* `sr-api-macros` 提供Runtime的一些宏
* `sr-io`,`sr-primitives`,`sr-std` 提供兼容std/wasm的库
* `sr-sandbox` 运行wasm执行期的沙盒
* `sr-version` 提供wasm与native执行时版本判定的组件

其余的组件：

* `cli` 命令行输入解析
* `client` 节点存储当前运行节点区块与状态，单例
* `executor` wasm执行构建能力
* `inherents` 内部交易的一些工具
* `keystore` `keyring` 公私钥工具和默认的私钥
* `primitives` 原语定义
* `rpc` `rpc-servers` 原始的rpc接口和websocket功能
* `service` 定义了一些链的数据结构，及各项服务（交易池，P2P，共识）启动的入口
* `transaction-pool` 交易池实现

### `srml`目录

* `assets` 定义类似Token的模块
* `balances` 定义和资金相关的模块
* `aura` `authorship` `grandpa` 反映底层共识信息和设置参数的模块
* `contracts` 合约模块
* `council` `democracy` `treasury` 民主提议，财政等相关的模块
* `example` Runtime模块的编写示例
* `indices` 账户分配唯一的索引和id
* `metadata` 核心组件之一，Runtime模块的描述性定义
* `session` `staking` 定义区块session间隔与权益计算相关的模块
* `sudo` sudo权限，可以指定一个账户执行root交易
* `support` 核心组件之一，提供Runtime模块数据结构的宏定义
* `system` 核心组件之一，提供Runtime模块和区块，交易相关的
* `timestamp` 提供区块时间戳的模块

### `node`目录

`node`是Substrate的一个示例。对于一条链，首先需要编译出Runtime的wasm代码，然后把wasm的执行文件一同编译到node节点，成为Genesis中的数据。

* `cli` node的命令行及Genesis的定义
* `executor` 执行器定义，读取wasm执行文件并引入
* `primitives` node的原语，许多基础类型的定义
* `runtime` 一条链的Runtime，`src` Runtime代码由此编译而来，`wasm` Runtime的wasm执行文件。

## 源码分析

### 共识

Polkadot/Substrate的共识系统。包括以下功能：

* BFT finalisation mechanism，BFT终结机制
* Parachain candidate selection，Parachain候选人选择
* Slashing determination，削减判定
* Syncing，同步

### 共识提议

在`/core/basic-authorship/src/basic-authorship.rs`中，定义了`ProposerFactory`来产生共识提议，其大致步骤：初始化提议，创建提议（处理交易，构建区块）。

内部是实现了在`/core/consensus/common/src/lib.rs`中定义的共识通用trait的方法：

* `Environment`共识实例的环境生产者的`init`方法，实现在特定头初始化提议逻辑
* `Proposer`通用提议者的`propose`方法，实现在特定区块创建评估提议

以及 trait `AuthoringApi`共识的本地客户端抽象的方法`build_block`，实现在特定块的顶部构建一个块。

同时基于`BlockBuilder``core/client/src/block_builder/block_builder.rs`
增加了一个`push_extrinsic`方法，在区块上推送一个外部信息。
该构造区块的工具集，定义的方法还有：`new` `at_block` `push` `bake`。

产生共识提议过程中，主要传入的参数有：

* `inherent_data`，`struct InherentData`，区块的固有数据
* `inherent_digests`，`type DigestFor`，区块固有签名
* `max_duration`，`struct Duration`，提案周期
* `at`，`enum BlockId`，在哪个区块
* `build_ctx`，`trait BlockBuilder`，区块构造工具

**需要一些专业知识**

要对Substrate进行任何重要的定制/调整，您应该熟悉：

* 区块链概念和基本密码学，Header，块，客户端，哈希，交易和签名等术语应该是熟悉的
* Rust语言（尽管最终，我们的目标不是这样）。

## Libp2p

### 功能

* 传输模块
* 不预先分配端口
* 加密通信
* 节点发现和路由

多个项目共享同一个网络协议的优势：libp2p提供了一个replay协议，允许一个节点充当另外两个节点的代理，多个项目使用，可以共享中继节点。

### 中间人攻击

man-in-the-middle attack (MITM) 攻击者秘密


