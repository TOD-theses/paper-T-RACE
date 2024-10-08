#import "@preview/definitely-not-tuw-thesis:0.1.0": flex-caption
#import "@preview/lovelace:0.3.0": *
#import "utils.typ": *

/*
Checklist:
- [ ] past vs present (in particular experiments)
- [ ] reference after or before dot?
*/

= Introduction

Ethereum is a blockchain that keeps track of a world state and updates this state by executing transactions. The transactions can execute so-called smart contracts, which are programs that are stored on the blockchain. As these programs are nearly Turing-complete, they can have vulnerabilities and become exploited.

This thesis focuses on transaction order dependence (TOD), which is a prerequisite for a kind of attack called front-running. TOD means that the state changes performed by transactions depend on the order in which the transactions are executed. In a front-running attack, an attacker sees that someone is about to perform a transaction and then quickly inserts a transaction before it. Because of TOD, executing the attacker's transaction before the victim's transaction yields different state changes than when execution the victim's transaction first.

This work proposes a method to take a pair of transactions and to simulate the two transactions in both orders. When executing the transactions in both orders, we can compare their behaviors to see if they are TOD and also if it exhibits characteristics of a front-running attack.

We use the state changes of transactions to calculate the world states used for transaction execution. This removes the need to execute intermediary transactions that were originally executed between the two transactions we analyze. Instead, we can use their state changes to maintain the effect they had on the second transaction, while updating the world states according to the different orders.

Moreover, we search the blockchain history for transaction pairs that are potentially TOD. We match transactions that access and modify the same state and define several filters to remove irrelevant transaction pairs. On these transaction pairs, we use our simulation method to check if they are TOD and if they have characteristics of a front-running attack. We check for the characteristics of the ERC-20 multiple withdrawal attack @rahimian_resolving_2019, the TOD properties implemented by Securify @tsankov_securify_2018, and financial gains and losses@zhang_combatting_2023.

We show that our concepts can be implemented with endpoints exposed by an archive node. We neither require custom modifications nor local access to an archive node.

Overall, our main contributions are:

- A method to simulate a pair of transactions in two different orders.
- A precise definition of TOD in the context of blockchain transaction analysis.
- An evaluation of an approximation for TOD.
- A compilation of EVM instructions that can cause TOD.
- A method to mine and filter transaction pairs that are potentially TOD.

== Related works

The studies by #cite(<zhang_combatting_2023>, form: "prose") and #cite(<torres_frontrunner_2021>, form: "prose") both detect and analyze front-running attacks that occurred on the Ethereum blockchain. We discuss potential inaccuracies in their simulation approaches. Contrary to these works, our study focuses on TOD, a prerequisite of front-running. However, we also implement the attack definition by #cite(<zhang_combatting_2023>, form: "prose") to compare our results with theirs.


#cite(<daian_flash_2020>, form: "prose") detect a specific kind of front-running attack by observing transaction executions. They measure so-called arbitrage opportunities, where a single transaction can make net revenue. While this is TOD, as only the first transaction that uses an arbitrage opportunity makes revenue, they do not need to simulate the different transaction orders for their analysis. Similarly, #cite(<wang_impact_2022>, form: "prose") also study a type of front-running attack without simulating different transaction orders.


#cite(<perez_smart_2021>, form: "prose") explicitly analyze transactions for TOD. They do so by recording for each transaction which storage it accessed and modified and then matching transactions where these overlap. Our work discusses the theoretical background of this approach and our method to detect potential TODs works in a similar way as theirs.

Several other works provide frameworks to analyze attack transactions in Ethereum @ferreira_torres_eye_2021@zhang_txspector_2020@wu_time-travel_2022@chen_soda_2020. None of these frameworks supports the simulation of transactions in different orders, therefore we cannot directly use them to detect TOD. Regarding the use of archive nodes, an evaluation by #cite(<wu_time-travel_2022>, form: "prose") states that replaying transactions with them is slow, taking "[...] more than 47 min to replay 100 normal transactions". However, #cite(<ferreira_torres_eye_2021>, form: "prose") show that it is indeed feasible to use archive nodes for attack analysis. We follow this work and use archive nodes to implement our simulation method.

= Background
This chapter provides background knowledge on Ethereum that is helpful for following the remaining paper. We also introduce a notation for these concepts.

== Ethereum
Ethereum is a blockchain that can be characterized as a "transactional singleton machine with shared-state" @wood_ethereum_2024[p.1]. By using a consensus protocol, a decentralized set of nodes agrees on a globally shared state. This state contains two types of accounts: #emph[externally owned accounts] (EOA) and #emph[contract accounts] (also referred to as smart contracts). The shared state is modified by executing #emph[transactions] @tikhomirov_ethereum_2018.

== World State
Similar to @wood_ethereum_2024[p.3], we will refer to the shared state as #emph[world state]. The world state maps each 20-byte address to an account state, containing a #emph[nonce], #emph[balance], #emph[storage] and #emph[code]#footnote[Technically, the account state only contains hashes that identify the storage and code, not the actual storage and code. This distinction is not relevant in this paper, therefore we simply refer to them as storage and code.]. They store the following data @wood_ethereum_2024[p.4]:

- #emph[nonce]: For EOAs, this is the number of transactions submitted
  by this account. For contract accounts, this is the number of
  contracts created by this account.
- #emph[balance]: The value of Wei this account owns, the smallest unit of
  Ether.
- #emph[storage]: The storage allows contract accounts to persist information across transactions. It is a key-value mapping where both, key and value, are 256 bits long. For EOAs, the storage is empty.
- #emph[code]: For contract accounts, the code is a sequence of EVM
  instructions.

We denote the world state as $sigma$ and the value at a specific #emph[state key] $K$ as $sigma(K)$. For the nonce, balance and code the state key denotes the state type and the account's address, written as $sigma(stateKey("nonce", a))$, $sigma(stateKey("balance", a))$ and $sigma(stateKey("code", a))$, respectively. For the value at a storage slot $k$ we use $sigma(stateKey("storage", a, k))$.

== EVM
The Ethereum Virtual Machine (EVM) is used to execute code in Ethereum. It executes instructions that can access and modify the world state. The EVM is Turing-complete, except that it is executed with a limited amount of #emph[gas], and each instruction costs some gas. When it runs out of gas, the execution will halt @wood_ethereum_2024[p.14]. This prevents infinite loops, as their execution exceeds the gas limit.

Most EVM instructions are formally defined in the Yellowpaper @wood_ethereum_2024[p.30-38]. However, the Yellowpaper currently does not include the changes from the Cancun upgrade @noauthor_history_2024, therefore we will also refer to the informal descriptions available on #link("https://www.evm.codes/")[evm.codes] @smlxl_evm_2024.

== Transactions
A transaction can modify the world state by transferring Ether and executing EVM code. It must be signed by the owner of an EOA and contains the following data relevant to our work:

- #emph[sender]: The address of the EOA that signed this transaction.#footnote[The sender is implicitly given through a valid signature and the transaction hash @wood_ethereum_2024[p.25-27]. We are only interested in transactions that are included in the blockchain, thus the signature must be valid, and the transaction’s sender can always be derived.]
- #emph[recipient]: The destination address.
- #emph[value]: The value of Wei that should be transferred from the sender to the recipient.
- #emph[gasLimit]: The maximum amount of gas that can be used for the execution.

If the recipient address is empty, the transaction will create a new contract account. These transactions also include an #emph[init] field that contains the code to initialize the new contract account.

When the recipient address is given and a value is specified, this will be transferred to the recipient. Moreover, if the recipient is a contract account, it also executes the recipient’s code. The transaction can specify a #emph[data] field to pass input data to the code execution @wood_ethereum_2024[p.4-5].

For every transaction, the sender must pay a #emph[transaction fee]. This fee is composed of a #emph[base fee] and a #emph[priority fee]. Every transaction must pay the base fee. The amount of Wei will be withdrawn from the sender and not given to any other account. For the priority fee, the transaction can specify if and how much they are willing to pay. This fee will be taken from the sender and given to the block validator, which is explained in the next section @wood_ethereum_2024[p.8].

We denote a transaction as $T$, sometimes adding a subscript $T_A$ to differentiate it from another transaction $T_B$.

== Blocks
The Ethereum blockchain consists of a sequence of blocks, where each block builds upon the state of the previous block. To achieve consensus about the canonical sequence of blocks in a decentralized network of nodes, Ethereum uses a consensus protocol. In this protocol, validators build and propose blocks to be added to the blockchain @noauthor_gasper_2023. It is the choice of the validator which transactions to include in a block. However, they are incentivized to include transactions that pay high transaction fees, as they receive the fee @wood_ethereum_2024[p.8].

Each block consists of a block header and a sequence of transactions that are executed in this block.

== Transaction submission
This section discusses how a transaction signed by an EOA ends up being included in the blockchain.

Traditionally, the signed transaction is broadcasted to the network of nodes, which temporarily store them in a #emph[mempool], a collection of pending transactions. The current block validator then picks transactions from the mempool and includes them in the next block. With this submission method, the pending transactions in the mempool are publicly known to the nodes in the network, even before being included in the blockchain. This time window will be important for our discussion on front-running, as it gives nodes time to react to a transaction before it becomes part of the blockchain @eskandari_sok_2020.

A different approach, the Proposer-Builder Separation (PBS), has gained more popularity recently. Here, we separate the task of collecting transactions and building blocks with them from the task of proposing them as a validator. A user submits their signed transaction or transaction bundle to a block builder. The block builder has a private mempool and uses it to create profitable blocks. Finally, the validator picks one of the created blocks and adds it to the blockchain @heimbach_ethereums_2023.

== Transaction execution
In Ethereum, transaction execution is deterministic @wood_ethereum_2024[p.9]. Transactions can access the world state and their block environment, therefore their execution can depend on these values. After executing a transaction, the world state is updated accordingly.

#let changesEqual = sym.tilde.op
#let changesDiffer = sym.tilde.not


We denote a transaction execution as $sigma ->^T sigma'$, implicitly letting the block environment correspond to the transaction’s block. Furthermore, we denote the state change by a transaction $T$ as $Delta_T$, with $pre(Delta_T) = sigma$ being the world state before execution and $post(Delta_T) = sigma'$ the world state after the execution of $T$.

For two state changes $Delta_T_A$ and $Delta_T_B$, we say that they are equivalent, $Delta_T_A changesEqual Delta_T_B$, if the relative change of the values is equal. Formally, let $Delta_T_A changesEqual Delta_T_B$ be true if and only if:

$
  forall K: post(Delta_T_A)(K) - pre(Delta_T_A)(K) = post(Delta_T_B)(K) - pre(Delta_T_B)(K)
$

We extend this equivalence definition to sequences of state changes by summing up the differences of the state changes on both sides. We define that two sequences of state changes $angle.l Delta_T_A_0, ..., Delta_T_A_n angle.r$ and $angle.l Delta_T_B_0, ..., Delta_T_B_m angle.r$ are equivalent if:

$
  forall K: sum_(i=0)^n post(Delta_T_A_i)(K) - pre(Delta_T_A_i)(K) = sum_(j=0)^m post(Delta_T_B_j)(
    K
  ) - pre(Delta_T_B_j)(K)
$

For example, if both $Delta_T_A$ and $Delta_T_B$ increase the balance at address $a$ by 10 Wei and make no other state changes, then $Delta_T_A changesEqual Delta_T_B$. If one of them had modified it by e.g. 15 Wei or 0 Wei, or additionally modified some storage slot, we would have $Delta_T_A changesDiffer Delta_T_B$.

We define $sigma + Delta_T$ to be equal to the state $sigma$, except that every state that was changed by the execution of $T$ is overwritten with the value in $post(Delta_T)$. Similarly, $sigma - Delta_T$ is equal to the state $sigma$, except that every state that was changed by the execution of $T$ is overwritten with the value in $pre(Delta_T)$. Formally, these definitions are as follows:

$ changedKeys(Delta_T) colon.eq {K \| pre(Delta_T)(K) != post(Delta_T) (K)} $

$
  (sigma + Delta_T) (
    K
  ) & colon.eq cases(
    post(Delta_T) (K) & "if"  K in changedKeys(Delta_T),
    sigma (K) & "otherwise"
  )\
  (sigma - Delta_T) (
    K
  ) & colon.eq cases(
    pre(Delta_T) (K) & "if" K in changedKeys(Delta_T),
    sigma (K) & "otherwise"
  )
$

For instance, if transaction $T$ changed the storage slot 1234 at address 0xabcd from 0 to 100, then we have $changedKeys(Delta_T) = {stateKey("storage", "0xabcd", "1234")}$. Further, we have $(sigma + Delta_T)(stateKey("storage", "0xabcd", 1234)) = 100$ and $(sigma - Delta_T)(stateKey("storage", "0xabcd", 1234)) = 0$. For all other storage slots $k$ we have $(sigma + Delta_T) (stateKey("storage", a, k)) = sigma(stateKey("storage", a, k)) = (sigma - Delta_T)(stateKey("storage", a, k))$.

== Nodes
A node consists of an #emph[execution client] and a #emph[consensus client]. The execution client keeps track of the world state and the mempool and executes transactions. The consensus client takes part in the consensus protocol. For this work, we will use an #emph[archive node], which is a node that allows reproducing the state and transactions at any block @noauthor_nodes_2024.

== RPC
Execution clients implement the Ethereum JSON-RPC specification @noauthor_ethereum_2024. This API gives remote access to an execution client, for instance, to inspect the current block number with `eth_blockNumber` or to execute a transaction without committing the state via `eth_call`. In addition to the standardized RPC methods, we will also make use of methods in the debug namespace, such as `debug_traceBlockByNumber`. While this namespace is not standardized, several execution clients implement these additional methods @noauthor_go-ethereum_2024@noauthor_rpc_2024@noauthor_reth_2024.

== Tokens

In Ethereum, tokens are assets managed by contract accounts @chen_tokenscope_2019. The contract account stores which address holds how many tokens. There are several token standards that a contract account can implement, allowing standardized methods to interact with the token. For instance, the ERC-20 standard defines a `transfer` method, which allows the holder of a token to transfer the token to someone else @vogelsteller_erc-20_nodate.

= Transaction order dependency
In this chapter we discuss our definitions of transaction order simulations and transaction order dependency (TOD). We first introduce the idea of TOD with a preliminary definition and then show several shortcomings of this simple definition. Based on these insights, we construct precise definitions of TOD and our transaction order simulation.

== Approaching TOD
Intuitively, a pair of transactions $(T_A , T_B)$ is transaction order dependent (TOD), if the result of sequentially executing the transactions depends on the order of their execution. As a preliminary TOD definition we use the following:

$
  sigma ->^(T_A) sigma_1 ->^(T_B) sigma' \
  sigma ->^(T_B) sigma_2 ->^(T_A) sigma'' \
  sigma' != sigma''
$

So, starting from an initial state, when we execute first $T_A$ and then $T_B$ it will result in a different state, than when we execute $T_B$ and afterwards $T_A$.

We will refer to the execution order $T_A -> T_B$, the one that occurred on the blockchain, as the #emph[normal] execution order, and $T_B -> T_A$ as the #emph[reverse] execution order.

== Motivating examples

We provide two examples to illustrate how TOD can be exploited.

=== Password leaking <sec:password-leaking>

The first example is an attack from a dataset by @torres_frontrunner_2021#footnote[The attacker transaction is #link("https://etherscan.io/tx/0x15c0d7252fa93c781c966a98ab46a1c8c086ca2a0da7eb0a7a06c522818757da")[0x15c0d7252fa93c781c966a98ab46a1c8c086ca2a0da7eb0a7a06c522818757da], and the victim transaction is #link("https://etherscan.io/tx/0x282e4de019b59a50b89c1fdc2e70c4bbd45a7ad7f7a1a6d4807a587b5fcdcdf6")[0x282e4de019b59a50b89c1fdc2e70c4bbd45a7ad7f7a1a6d4807a587b5fcdcdf6].]. A simplified version of the vulnerable contract with added comments is presented below. It allows depositing some Ether and locking it with a password, and then anyone with the password can withdraw this Ether.

#figure(
  kind: "code",
  supplement: "Contract",
  caption: flex-caption(
    [The `PasswordEscrow` contract. This is a simplified version with added comments, based on the source code from Etherscan @etherscan_ethereum_nodate.],
    [The `PasswordEscrow` contract.],
  ),
)[
  ```solidity
  contract PasswordEscrow {
    struct Transfer {
      address from;
      uint256 amount;
    }

    mapping(bytes32 => Transfer) private transferToPassword;

    function deposit(bytes32 _password) public payable {
      // REMARK: this stores an entry for the password and saves the amount of Ether
      // that was sent along the transaction
      bytes32 pass = sha3(_password);
      transferToPassword[pass] = Transfer(msg.sender, msg.value);
    }

    function getTransfer(bytes32 _password) public payable {
      // REMARK: this verifies that an entry for the password exists
      // and gets the amount of Ether that was deposited for the password
      require(
        transferToPassword[sha3(_password)].amount > 0
      );
      bytes32 pass = sha3(_password);
      uint256 amount = transferToPassword[pass].amount;

      transferToPassword[pass].amount = 0;

      // REMARK: this transfers the Ether to the account that transaction's sender
      msg.sender.transfer(amount);
    }
  }
  ```
] <contract:password-escrew>

The victim previously interacted with the contract to deposit some Ether and lock it with a password. For the sake of the argument, we ignore that the password is already public at this step. This could be fixed, e.g. by directly submitting `sha3(password)` rather than the password itself, without resolving the TOD issue we discuss here.

Later, the victim tried to withdraw this Ether by creating a transaction that calls `getTransfer` with the password. However, in the time between the transaction submission and its inclusion in a block, an attacker saw this transaction and determined that they can perform the Ether withdrawal themselves. They copied the transaction data, including the password, and submitted their own transaction with a higher gas price than the victim's. The attacker's transaction ended up being executed first and withdrew all the Ether.

If we map this attack to our preliminary TOD definition above, the first transaction that executes will withdraw the Ether and thus increase the sender's balance. If the attacker's transaction executes first, we end up in a state where the attacker has more balance than if the victim's transaction is executed first. Therefore, $sigma' != sigma''$.

=== ERC-20 multiple withdrawal <sec:erc-20-multiple-withdrawal>

As a second example, we explain the ERC-20 multiple withdrawal attack @rahimian_resolving_2019. Contracts that implement the ERC-20 token standard must include an `approve` method @vogelsteller_erc-20_nodate. This method takes as parameters a `spender` and a `value` and allows the `spender` to spend `<value>` tokens from your account. For instance, when some account $a$ calls `approve(b, 0x1234)`, then `b` can transfer `0x1234` tokens from $a$ to any other account. If the `approve` method is called another time, the currently approved value is overwritten with the new value, regardless of the previous value.

We illustrate that approvals and the spending of approved tokens can be TOD in @tab:erc20-multiple-withdrawal-example. In the benign scenario, $b$ spends one token and remains with two tokens that are still approved. However, in the attack scenario, $b$ spends one token and only afterwards $a$ approves $b$ to spend three tokens. Therefore, $b$ remains with three tokens approved tokens instead of two. As such, changing the order of the second and third transaction results in different states, hence they are TOD.

From the perspective of $a$, they only wanted to allow $b$ to use three tokens. However, when $b$ reacts to a pending approval by executing a `transferFrom` before the approval is included in a block, then $b$ is able to use more than three tokens in total. This happened in the attack scenario, where the `transferFrom` is executed before the second `approve` got included in a block.

#figure(
  grid(
    columns: 2,
    gutter: 1em,
    [*Benign scenario*], [*Attack scenario*],
    table(
      columns: 2,
      align: (left, center),
      table.header([Action], [Approved tokens]),
      [`approve(b, 1)`], [1],
      [`approve(b, 3)`], [3],
      [`transferFrom(a, b, 1)`], [2],
    ),
    table(
      columns: 2,
      align: (left, center),
      table.header([Action], [Approved tokens]),
      [`approve(b, 1)`], [1],
      [`transferFrom(a, b, 1)`], [0],
      [`approve(b, 3)`], [3],
    ),
  ),
  caption: flex-caption(
    [Benign and attack scenario for ERC-20 approvals.],
    [Benign and attack scenario for ERC-20 approvals.],
  ),
) <tab:erc20-multiple-withdrawal-example>


== Relation to previous works <sec:tod-relation-previous-works>
This section discusses, how our preliminary TOD definition relates to previous works that detect front-running attacks.

In @torres_frontrunner_2021, the authors do not provide a formal definition of TOD or front-running attacks. Nevertheless, for displacement attacks, they include the following check to detect if two transactions fall into this category:

#quote(block: true)[
  [...] we run in a simulated environment first $T_A$ before $T_V$ and then $T_V$ before $T_A$. We report a finding if the number of executed EVM instructions is different across both runs for $T_A$ and $T_V$, as this means that $T_A$ and $T_V$ influence each other.
]

Similar to our preliminary TOD definition, they execute $T_A$ and $T_V$ in different orders and check if it affects the result. In their case, they only check the number of executed instructions, instead of the resulting state. This check misses attacks where the same instructions are executed, but the operands of instructions in the second transaction change because of the first transaction.

In @zhang_combatting_2023, the authors define an attack as a triple $A = angle.l T_a , T_v , T_a^p angle.r$, where $T_a$ and $T_v$ are similar to $T_A$ and $T_B$ from our definition, and $T_a^p$ is an optional third transaction. They consider the execution orders $T_a -> T_v -> T_a^p$ and $T_v -> T_a -> T_a^p$ and check if the execution order influences financial gains, which we will discuss in more detail in @sec:gain-and-loss-property.

We note that if these two execution orders result in different states, this is not because of the last transaction $T_a^p$, but because of a TOD between $T_a$ and $T_v$. As we always execute $T_a^p$ last, and transaction execution is deterministic, it only gives a different result if the execution of $T_a$ and $T_v$ gave a different result. Therefore, if the execution order results in different financial gains, then $T_a$ and $T_v$ must be TOD.

== Imprecise definitions
Our preliminary definition of TOD, and the related definitions above, are not precise regarding the semantics of a reordering of transactions and their executions. This makes it impossible to apply exactly the same methodology without analyzing the source code related to the papers. We describe three issues where the definition is not precise enough, and show how these are differently interpreted by the two papers.

For the analysis of the tools by @zhang_combatting_2023 and @torres_frontrunner_2021, we will use the current version of the source codes, @zhang_erebus-redgiant_2023 and @torres_frontrunner_2022, respectively.

=== Intermediary transactions
To analyze a TOD $(T_A , T_B)$, we are interested in how $T_A$ affects $T_B$ in the normal order, and how $T_B$ affects $T_A$ in the reverse order. Our preliminary definition does not specify how to handle transactions that occur between $T_A$ and $T_B$, which we will name #emph[intermediary transactions].

Suppose that there is one transaction $T_X$ between $T_A$ and $T_B$: $sigma ->^(T_A) sigma_A ->^(T_X) sigma_(A X) ->^(T_B) sigma_(A X B)$. The execution of $T_B$ may depend on both $T_A$ and $T_X$. When we are interested in the effect of $T_A$ on $T_B$, we need to define what happens with $T_X$.

For executing in the normal order, we have two possibilities:

+ $sigma ->^(T_A) sigma_A ->^(T_X) sigma_(A X) ->^(T_B) sigma_(A X B)$, the same execution as on the blockchain, including the effects of $T_X$.
+ $sigma ->^(T_A) sigma_A ->^(T_B) sigma_(A B)$, leaving out $T_X$ and thus having a normal execution that potentially diverges from the results on the blockchain (as $sigma_(A B)$ may differ from $sigma_(A X B)$).

When executing the reverse order, we have the following choices:

+ $sigma ->^(T_B) sigma_B ->^(T_A) sigma_(B A)$, which ignores $T_X$ and thus may influence the execution of $T_B$.
+ $sigma ->^(T_X) sigma_X ->^(T_B) sigma_(X B) ->^(T_A) sigma_(X B A)$, which executes $T_X$ on $sigma$ rather than $sigma_A$ and now also includes the effects of $T_X$ for executing $T_A$.
+ $sigma ->^(T_B) sigma_B ->^(T_X) sigma_(B X) ->^(T_A) sigma_(B X A)$, which executes $T_X$ after $T_B$ and before $T_A$, thus potentially influencing the execution of both $T_A$ and $T_B$.

All of these scenarios are possible, but none of them provides a clean solution to solely analyze the effect of $T_A$ on $T_B$, as we always may have some indirect effect from the (non-)execution of $T_X$.

In @zhang_combatting_2023, this influence of intermediary transactions is acknowledged as causing a few false positives:

#quote(block: true)[
  In blockchain history, there could be many other transactions between $T_a$, $T_v$, and $T_p^a$. When we change the transaction orders to mimic attack-free scenarios, the relative orders between $T_a$ (or $T_v$) and other transactions are also changed. Financial profits of the attack or victim could be affected by such relative orders. As a result, the financial profits in the attack-free scenario could be incorrectly calculated, and false-positively reported attacks may be induced, but our manual check shows that such cases are rare.
]

Nonetheless, it is not clear, which of the above scenarios they applied for their analysis. The other work, @torres_frontrunner_2021, does not mention this issue of intermediary transactions.

==== Code analysis of @zhang_combatting_2023

In @zhang_combatting_2023, algorithm 1 takes all the executed transactions as its input. These transactions and their results are used in the `searchVictimGivenAttack` method, where `ar` represents the attack transaction with result and `vr` represents the victim transaction with result.

For the normal execution order ($T_a -> T_v$), the authors use `ar` and `vr` and pass them to their `CheckOracle` method, which then compares the resulting states. As `ar` and `vr` are obtained by executing all transactions, they also include the intermediary transactions for these results (similar to our $sigma ->^(T_A) sigma_A ->^(T_X) sigma_(A X) ->^(T_B) sigma_(A X B)$ case).

For the reverse order ($T_v -> T_a$), they take the state before $T_a$, i.e. $sigma$. Then they execute all transactions obtained from the `SlicePrerequisites` method. And finally, they execute $T_v$ and $T_a$.

The `SlicePrerequisites` method uses the `hbGraph`, which is built in `StartSession`. `hbGraph` seems to be a graph where each transaction points to the previous transaction from the same EOA. The `SlicePrerequisites` method uses this graph to obtain all transactions between $T_a$ and $T_v$ that are from the same sender as $T_v$. This interpretation matches the test case "should slide prerequisites correctly" from the source code. As the paper does not mention these prerequisite transactions, we do not know why this subset of intermediary transactions was chosen.

We can conclude that @zhang_combatting_2023 executes all intermediary transactions in the normal order. However, in the reverse order, they only execute intermediary transactions that are also sent by the victim, but do not execute any other intermediary transactions.

==== Code analysis of @torres_frontrunner_2021

In the file `displacement.py`, lines 154-155 replay the normal execution order, and lines 158-159 the reverse execution order. They only execute $T_A$ and $T_V$ (in normal and reverse order), but do not execute any intermediate transactions.

=== Block environments
When we analyze a pair of transactions $(T_A , T_B)$, it may happen that these are not part of the same block. The execution of the transactions may depend on the block environment they are executed in, for instance, if they access the current block number. Thus, executing $T_A$ or $T_B$ in a block environment different from the blockchain may alter their behavior. From our preliminary TOD definition, it is not clear which block environment(s) we use when replaying the transactions in normal and reverse order.

==== Code analysis of @zhang_combatting_2023

In the normal scenario, the block environments used are the same as originally used for the transaction.

For the reverse scenario, the block environment used to execute all transactions is contained in `ar.VmContext` and corresponds to the block environment of $T_a$. Therefore, $T_a$ is executed in the same block environment as on the blockchain, while $T_v$ and the intermediary transactions may be executed in a block environment different from the normal scenario.

==== Code analysis of @torres_frontrunner_2021

In the file `displacement.py` line 151, we see that the emulator uses the same block environment for both transactions. Therefore, at least one of them will be executed in a block environment different from the blockchain. However, it uses the same block environment for both scenarios, thus being consistently different from the execution on the blockchain.

=== Initial state $sigma$
While our preliminary TOD definition specifies that we start with the same $sigma$ in both execution orders, it is up to interpretation which world state $sigma$ actually designates.

==== Code analysis of @zhang_combatting_2023

Both, in the normal and reverse scenario, it uses the state directly before executing $T_a$, including the state changes of previous transactions within the same block. In the reverse scenario, this is the case as it uses `ar.State`.

==== Code analysis of @torres_frontrunner_2021

The emulator is initialized with the block `front_runner["blockNumber"]-1` and no single transactions are executed prior to running the analysis. Therefore, the state cannot include transactions that were executed in the same block before $T_A$.

Similar to the case with the block environment, this could lead to differences between the emulation and the results from the blockchain when $T_A$ or $T_V$ are affected by a previous transaction in the same block.

== TOD simulation <sec:tod-simulation>

To address the issues above, we define a TOD simulation method that explicitly defines the used world states and block environments while also taking intermediary transactions into account:

#definition("Normal and reverse scenarios")[
  Consider a sequence of transactions, with $sigma$ being the world state right before $T_A$ was executed on the blockchain:

  $ sigma ->^(T_A) sigma_A ->^(T_X_1) dots.h ->^(T_X_n) sigma_X_n ->^(T_B) sigma_B $

  Let $Delta_T_A$ and $Delta_T_B$ be the corresponding state changes from executing $T_A$ and $T_B$, and let all transactions be executed in the same block environment as they were executed on the blockchain.

  Let $Delta'_T_B$ be the state change when executing $(sigma_X_n - Delta_T_A) ->^(T_B) sigma'_B$ and $Delta'_T_A$ be the state change when executing $(sigma + Delta'_T_B) ->^(T_A) sigma'_A$.

  We call $Delta_T_A$ and $Delta_T_B$ the state changes from the normal scenario and $Delta'_T_A$ and $Delta'_T_B$ the state changes from the reverse scenario.
]

The normal scenario represents the order $T_A -> T_B$. The state changes $Delta_T_A$ and $Delta_T_B$ are equal to the ones observed on the blockchain, as we execute the transactions in their original block environment and with their original prestate.

The reverse scenario models the order $T_B -> T_A$, where $T_B$ occurs before $T_A$. Therefore, we execute $T_B$ on a state that does not contain the changes of $T_A$. We do so by taking the world state exactly before executing $T_B$, namely $sigma_X_n$, and then removing the state changes of $T_A$ by computing $sigma_X_n - Delta_T_A$. Executing $T_B$ on $sigma_X_n - Delta_T_A$ gives us the state change $Delta'_T_B$. To model the execution of $T_A$ after $T_B$, we take the state $sigma$ on which $T_A$ was originally executed and add the state changes $Delta'_T_B$.

/*
Additionally, for the special case that $T_A$ and $T_B$ do not have intermediary transactions, we can compute the states we would get from the preliminary definition using the normal and reverse scenarios:

#proposition[
  Consider a sequence of transactions, with $sigma$ being the world state right before $T_A$ and the following two execution orders:

  $
    sigma ->^(T_A) sigma_1 ->^(T_B) sigma'\
    sigma ->^(T_B) sigma_2 ->^(T_A) sigma''
  $

  When $Delta_T_A$, $Delta_T_B$, $Delta'_T_A$ and $Delta'_T_B$ are the corresponding state changes of the normal and reverse order, we must have $sigma' = sigma + Delta_T_A + Delta_T_B$ and $sigma'' = sigma + Delta'_T_B + Delta'_T_A$.
]
#proof[
For the normal scenario our definition uses the original prestates, therefore we use $sigma$ for $T_A$ and $sigma_1$ for $T_B$. Because we use the same prestates as for $sigma ->^(T_A) sigma_1 ->^(T_B) -> sigma'$, we end up with the same poststates, therefore $sigma' = sigma + Delta_T_A + Delta_T_B$. For the reverse scenario, we also compute the same prestates as $sigma ->^(T_B) sigma_2 ->^(T_A) sigma''$ and therefore get the same result. To execute $T_B$ in the reverse scenario, we compute $sigma_1 - Delta_T_A = (sigma + Delta_T_A) - Delta_T_A = sigma$. We then execute $T_A$ on $sigma + Delta'_T_B = sigma_2$ and therefore end up with $sigma'' = sigma + Delta'_T_B + Delta'_T_A$.
]
*/

== TOD definition <sec:tod-definition>

Based on the definition of normal and reverse scenarios, we define TOD as follows:

#definition("TOD")[
  Let $T_A$ and $T_B$ be two transactions with the corresponding state changes $Delta_T_A$ and $Delta_T_B$ from the normal scenario and $Delta'_T_A$ and $Delta'_T_B$ from the reverse scenario.

  We say that $(T_A, T_B)$ is TOD if and only if $angle.l Delta_T_A, Delta_T_B angle.r changesDiffer angle.l Delta'_T_A, Delta'_T_B angle.r$.
]

Consider the example of the ERC-20 multiple withdrawal from @sec:erc-20-multiple-withdrawal, with $T_A$ being the attacker transaction that calls `transferFrom(a, b, 1)` and $T_B$ being the victim transaction that calls `approve(b, 3)`. In the normal scenario, we have shown that the attacker remains with three approved tokens, while in the reverse scenario, only two tokens would remain. Intuitively, this satisfies $angle.l Delta_T_A, Delta_T_B angle.r changesDiffer angle.l Delta'_T_A, Delta'_T_B angle.r$, as the change approved tokens differs between the normal and the reverse scenario.

More formally, let $K$ be the state key that tracks how many tokens are approved by $a$ for $b$. Initially, one token is approved, therefore $sigma(K) = 1$. When executing $T_A$ in the normal scenario, where the attacker spends the one approved token, this changes to $sigma(K) = 0$. Therefore, we have a change of $post(Delta_T_A)(K) - pre(Delta_T_A)(K) = -1$. We then continue to execute $T_B$ in the normal scenario, which sets $sigma(K) = 3$, therefore $post(Delta_T_B)(K) - pre(Delta_T_B)(K) = 3$. When we add up these two state changes, we get an overall state change of $2$ for the state at key $K$. However, doing the same calculations for the reverse scenario results in an overall state change of $1$ for $K$, as $T_B$ first increases it by two and $T_A$ then reduces it by one. As the overall changes differ between the normal and reverse scenario, we have $angle.l Delta_T_A, Delta_T_B angle.r changesDiffer angle.l Delta'_T_A, Delta'_T_B angle.r$ and $(T_A, T_B)$ is TOD.

Similarly, for the password leaking example in @sec:password-leaking we showed that the execution order determines who can withdraw the stored Ether. If the attacker's transaction is executed first, they withdraw the Ether. If it is executed second, the attacker does not withdraw any Ether. Therefore, the change at the state key $K = stateKey("balance", italic("attacker"))$ depends on the transaction order, and thus, the transactions are TOD.

== TOD approximation <sec:tod-approximation>

This paper focuses on detecting TOD attacks, in which the attacker inserts a transaction prior to some transaction $T$. We assume that the first transaction tries to influence the second transaction, which implies that in every TOD attack, the state changes of $T_B$ should be dependent on the transaction order. We use this assumption to define an approximation of TOD:

#definition("Approximately TOD")[
  Let $T_A$ and $T_B$ be transactions with the state changes $Delta_T_B$ for the normal scenario and $Delta'_T_B$ for the reverse scenario.

  We say that $(T_A, T_B)$ is approximately TOD if and only if $Delta_T_B changesDiffer Delta'_T_B$.
]

In principle, the assumption that an attack influences the transaction it front-runs need not hold. For example, suppose a transaction $T$ leaks a password that can be used to withdraw Ether, but at the same time, $T$ locks the contract that contains this Ether. An attacker may use the password to withdraw the Ether without necessarily influencing the execution of $T$ but it needs need to front-run $T$ because of the contract locking.

== Definition strengths <sec:definition-strengths>

=== Performance

To check if two transactions, $T_A$ and $T_B$, are TOD, we need the initial world state $sigma$, and the state changes from $T_A$, $T_B$ and the intermediary transactions $T_(X_n)$. With the state changes we can compute $sigma_(X_n) - Delta_(T_A) = sigma + Delta_(T_A) + (sum_(i = 0)^n Delta_(T_(X_i))) - Delta_(T_A)$ and then execute $T_B$ on this state. With the recorded state changes, $Delta'_T_B$, we can compute $sigma + Delta'_T_B$ and execute $T_A$ on this state. As such, we need one transaction execution to check for the TOD approximation and two transaction executions to check for TOD. Despite including the effect of arbitrarily many intermediary transactions, we do not need to execute them to check for TOD.

When we want to check $n$ transactions for TOD, there are $frac(n^2 - n, 2)$ possible transaction pairs. Thus, if we want to test each pair for TOD we end up with a total of $frac(n^2 - n, 2)$ transaction executions for the approximation and $n^2 - n$ executions for the exact TOD check. Similar to @torres_frontrunner_2021 and @zhang_combatting_2023, we can filter irrelevant transaction pairs to reduce the search space.

Depending on the available world states and state changes, the exact number of required transaction executions and the method to compute world states may differ. For instance, the archive nodes Erigon 2 and Reth currently only store state changes for each block, but not on a transaction level @noauthor_erigon_2023@noauthor_reth_2024-1. We show the state calculations under such constraints in @sec:tod-detection. Other systems, such as EthScope @wu_time-travel_2022, and Erigon 3 @rebuffo_erigon_2024, store changes for every transaction. However, EthScope is not publicly available anymore and Erigon 3 is still in development.

=== Similarity to blockchain executions

With our definition, the state changes $Delta_T_A$ and $Delta_T_B$ from the normal execution are equivalent to the state changes that happened on the blockchain. Also, the reverse order is closely related to the state from the blockchain, as we start with the world states before $T_A$ and $T_B$ and only change state keys that were modified by $T_A$ and $T_B$, thus only the state keys relevant for TOD simulation. Furthermore, we prevent the effects of block environment changes by using the same environments as on the blockchain.

This contrasts with other implementations, where transactions are executed in different block environments than originally, a different world state is used for the first transaction or the effect of intermediary transactions is ignored. All three cases can alter the execution of $T_A$ and $T_B$, such that the result is not closely related to the blockchain.

== Definition weaknesses
<sec:weaknesses>

=== Approximation focuses on effect on $T_B$ <sec:weakness-focus-on-tb>

In some cases, the transaction order can affect the execution of the individual transactions, but does not affect the overall result of executing both transactions. The approximation does not consider the execution of $T_A$ after $T_B$ in the reverse order, which could lead to incorrect TOD classification.

For example, consider the case where both $T_A$ and $T_B$ multiply a value in a storage slot by 5. If the storage slot initially has the value 1, then executing both $T_A$ and $T_B$ will result in 25, regardless of the order. However, the state changes $Delta_T_B$ and $Delta'_T_B$ are different, as for one scenario, the value changes from 1 to 5 and for the other from 5 to 25. Therefore, this would be classified as approximately TOD.

Note that the approximation is robust against the cases, where the absolute values differ, but the change is constant. For instance, if both $T_A$ and $T_B$ would increase the storage slot by 5 rather than multiplying it, the state changes $Delta_T_B$ and $Delta'_T_B$ would be from 1 to 6 and from 6 to 11. As our definition for state change equivalence uses the difference between the state before and after execution, we would compare the change $6 - 1 = 5$ against $11 - 6 = 5$, thus $Delta_T_B changesEqual Delta'_T_B$.

=== Indirect dependencies <sec:weakness-indirect-dependencies>

An intuitive interpretation of our TOD definition is that we compare $T_A -> T_X_i -> T_B$ with $T_X_i -> T_B -> T_A$, i.e. reckon what happens if $T_A$ is not executed first but last. However, the definition we provide does not perfectly match this concept, because it does not consider interactions between $T_A$ and the intermediary transactions $T_(X_i)$. In the intuitive model, not executing $T_A$ before the intermediary transactions may influence them and thus indirectly change the behavior of $T_B$. Then, we do not know if $T_A$ directly influences $T_B$, or only through some interplay with intermediary transactions. Similarly, when executing $T_A$ last, we do not know if $T_A$ behaves differently this is because of an interaction with $T_B$ or an intermediary transaction.

Therefore, our exclusion of interactions between $T_A$ and $T_(X_i)$ may be desirable to focus only on interactions between $T_A$ and $T_B$, however it can cause divergences between our analysis results and what would have happened on the blockchain.

As an example, consider the three transactions $T_A$, $T_X$ and $T_B$:

+ $T_A$: sender $a$ transfers 5 Ether to address $x$.
+ $T_X$: sender $x$ transfers 5 Ether to address $b$.
+ $T_B$: sender $b$ transfers 5 Ether to address $y$.

When executing these transactions in the normal order, and $a$ initially has 5 Ether and the others have 0, then all of these transactions succeed. If we remove $T_A$ and only execute $T_X$ and $T_B$, then firstly $T_X$ would fail, as $x$ did not get the 5 Ether from $a$, and consequently, also $T_B$ fails.

However, when using our TOD definition and computing $(sigma_(X_n) - Delta_(T_A))$, we would only modify the balances for $a$ and $x$, but not for $b$, because $b$ is not modified in $Delta_(T_A)$. Thus, $T_B$ would still succeed in the reverse order according to our definition, but would fail in practice due to the indirect effect. This shows, how the concept of removing $T_A$ does not map exactly to our TOD definition.

In this example, we had a TOD for $(T_A , T_X)$ and $(T_X , T_B)$. However, we can also have an indirect dependency between $T_A$ and $T_B$ without a TOD for $(T_X , T_B)$. For instance, if $T_X$ and $T_B$ would be TOD, but $T_A$ caused $T_X$ to fail. When inspecting the normal order, $T_X$ failed, so there is no TOD between $T_X$ and $T_B$. However, when executing the reverse order without $T_A$, then $T_X$ would succeed and could influence $T_B$.

== State collisions

We denote the state accesses by a transaction $T$ as a set of state keys $R_T = { K_1 , dots.h , K_n }$ and the state modifications as $W_T = { K_1 , dots.h , K_m }$.

Inspired by the definition of a transaction race in @ma_transracer_2023, we define the state collisions of two transactions as:

$
  colls(T_A , T_B) = (W_(T_A) sect R_(T_B)) union (W_(T_A) sect W_(T_B))
$

For instance, if transaction $T_A$ modifies the balance of some address $a$, and $T_B$ accesses this balance, we have $colls(T_A, T_B) = ({ stateKey("balance", a) } sect {stateKey("balance", a)}) union ({stateKey("balance", a)} sect emptyset) = {stateKey("balance", a)}$.

With $W_(T_A) sect R_(T_B)$ we include write-read collisions, where $T_A$ modifies some state key and $T_B$ accesses the same state key. With $W_(T_A) sect W_(T_B)$ we include write-write collisions, where both transactions write to the same state location, for instance by writing to the same storage. Following the assumption of the TOD approximation, we do not include $R_(T_A) sect W_(T_B)$, as in this case $T_A$ does not influence the execution of $T_B$.

== TOD candidates
We will refer to a transaction pair $(T_A , T_B)$, where $T_A$ was executed before $T_B$ and $colls(T_A , T_B) != nothing$ as a TOD candidate.

A TOD candidate is not necessarily TOD or approximately TOD. For instance, consider the case that $T_B$ only reads the value that $T_A$ wrote but never uses it for any computation. This would be a TOD candidate, as they have a collision, however the result of executing $T_B$ is not influenced by this collision.

If $(T_A , T_B)$ is approximately TOD, then $(T_A , T_B)$ must also be a TOD candidate. We can only have $Delta_T_B changesDiffer Delta'_T_B$ if the state keys that $T_B$ accesses or modifies differ between the normal and reverse scenarios. As the only difference between the scenarios is the removal of $Delta_T_A$ in the reverse scenario, the differences of the state keys must come from $Delta_T_A$. Therefore, $T_A$ also modifies these state keys, and we have $(W_T_A sect R_T_B) union (W_T_A sect W_T_B) != nothing$. This is equivalent to $colls(T_A, T_B) != nothing$, showing that $(T_A, T_B)$ must be a TOD candidate.

Therefore, the set of all approximately TOD transaction pairs is a subset of all TOD candidates.

In the case that $(T_A, T_B)$ is TOD but not approximately TOD, the pair $(T_A, T_B)$ need not be a TOD candidate. By the definitions of TOD and approximately TOD, we have $angle.l Delta_T_A, Delta_T_B angle.r changesDiffer angle.l Delta'_T_A, Delta'_T_B angle.r$ and $Delta_T_B changesEqual Delta'_T_B$, which implies that $Delta_T_A changesDiffer Delta'_T_A$ must hold. Similar to the previous argument, $Delta_T_A changesDiffer Delta'_T_A$ implies $(R_T_A sect W_T_B) union (W_T_A sect W_T_B) != nothing$. However, in this case we cannot conclude $colls(T_A, T_B) != nothing$, because we excluded $R_T_A sect W_T_A$ from our collision definition.

As such, the definition of TOD candidates aligns with the approximation of TOD, but not necessarily the exact TOD definition.

== Causes of state collisions
This section discusses what can cause two transactions $T_A$ and $T_B$ to have state collisions. To do so, we show the ways a transaction can access and modify the world state.

=== Causes with code execution
When the recipient of a transaction is a contract account, it will execute the recipient’s code. The code execution can access and modify the state through several instructions. By inspecting the EVM instruction definitions @wood_ethereum_2024[p.30-38]@smlxl_evm_2024, we compiled a list of instructions that can access and modify the world state.

In @tab:state_reading_instructions, we see the instructions that can access the world state. For most, the reason of the access is clear, for instance `BALANCE` needs to access the balance of the target address. Less obvious is the nonce access of several instructions, which is because the EVM uses the nonce (among other things) to check if an account already exists @wood_ethereum_2024[p.4]. For `CALL`, `CALLCODE` and `SELFDESTRUCT`, this is used to calculate the gas costs @wood_ethereum_2024[p.37-38]. For `CREATE` and `CREATE2`, this is used to prevent creating an account at an already active address @wood_ethereum_2024[p.11]#footnote[In the Yellowpaper, the check for the existence of the recipient for `CALL`, `CALLCODE` and `SELFDESTRUCT` is done via the `DEAD` function. For `CREATE` and `CREATE2`, this is done in the condition (113) named `F`.].

In @tab:state_writing_instructions, we see instructions that can modify the world state.

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    table.header([Instruction], [Storage], [Balance], [Code], [Nonce]),
    table.hline(),
    [`SLOAD`], [$checkmark$], [], [], [],
    [`BALANCE`], [], [$checkmark$], [], [],
    [`SELFBALANCE`], [], [$checkmark$], [], [],
    [`CODESIZE`], [], [], [$checkmark$], [],
    [`CODECOPY`], [], [], [$checkmark$], [],
    [`EXTCODECOPY`], [], [], [$checkmark$], [],
    [`EXTCODESIZE`], [], [], [$checkmark$], [],
    [`EXTCODEHASH`], [], [], [$checkmark$], [],
    [`CALL`], [], [$checkmark$], [$checkmark$], [$checkmark$],
    [`CALLCODE`], [], [$checkmark$], [$checkmark$], [$checkmark$],
    [`STATICCALL`], [], [], [$checkmark$], [],
    [`DELEGATECALL`], [], [], [$checkmark$], [],
    [`CREATE`], [], [$checkmark$], [$checkmark$], [$checkmark$],
    [`CREATE2`], [], [$checkmark$], [$checkmark$], [$checkmark$],
    [`SELFDESTRUCT`], [], [$checkmark$], [$checkmark$], [$checkmark$],
  ),
  caption: flex-caption(
    [Instructions that access state. A checkmark indicates,
      that the execution of this instruction can depend on this state type.],
    [State accessing instructions],
  ),
  kind: table,
)<tab:state_reading_instructions>

#figure(
  table(
    columns: 5,
    align: (left, center, center, center, center),
    table.header([Instruction], [Storage], [Balance], [Code], [Nonce]),
    table.hline(),
    [`SSTORE`], [$checkmark$], [], [], [],
    [`CALL`], [], [$checkmark$], [], [],
    [`CALLCODE`], [], [$checkmark$], [], [],
    [`CREATE`], [], [$checkmark$], [$checkmark$], [$checkmark$],
    [`CREATE2`], [], [$checkmark$], [$checkmark$], [$checkmark$],
    [`SELFDESTRUCT`], [$checkmark$], [$checkmark$], [$checkmark$], [$checkmark$],
  ),
  caption: flex-caption(
    [Instructions that modify state. A checkmark indicates,
      that the execution of this instruction can modify this state type.],
    [State modifying instructions],
  ),
  kind: table,
) <tab:state_writing_instructions>

=== Causes without code execution
Some state accesses and modifications are inherent to transaction execution. To pay the transaction fees, the sender's balance is accessed and modified. When a transaction transfers some Wei from the sender to the recipient, it also modifies the recipient’s balance. To check if the recipient is a contract account, the transaction also needs to access the code of the recipient. Finally, it also verifies the sender’s nonce and increments it by one @wood_ethereum_2024[p.9].

=== Relevant collisions for attacks
<sec:relevant-collisions>

The previous sections list possible ways to access and modify the world state. Many previous works have focused on storage and balance collisions, however they did not discuss if or why code and nonce collisions are not important @tsankov_securify_2018@wang_etherfuzz_2022@kolluri_exploiting_2019@luu_making_2016@munir_todler_2023. Here, we argue, why only storage and balance collisions are relevant for TOD attacks and code and nonce collisions can be neglected.

Following the assumption we made in @sec:tod-approximation, in a TOD attack an attacker influences the execution of some transaction $T_B$, by placing a transaction $T_A$ before it. To have some effect, there must be a write-write or write-read collisions between $T_A$ and $T_B$. Therefore, our scenario is that we start from some (victim) transaction $T_B$ and try to create impactful collisions with a new transaction $T_A$.

Let us first focus on the instructions that could modify the codes and nonces that $T_B$ accesses or modifies. As we see in @tab:state_writing_instructions, these are `SELFDESTRUCT`, `CREATE` and `CREATE2`. Since the EIP-6780 update @ballet_eip-6780_2023, `SELFDESTRUCT` only destroys a contract if the contract was created in the same transaction. Therefore, `SELFDESTRUCT` can only modify a code and nonce within the same transaction, but cannot be used to attack an already submitted transaction $T_B$. The instructions to create a new contract, `CREATE` and `CREATE2`, both fail when there is already a contract at the target address @wood_ethereum_2024[p.11]. Therefore, we can only modify the code if the contract previously did not exist. In the case that $T_B$ interacts with some address $a$ that contains no code, the attacker needs `CREATE` or `CREATE2` to create a contract at the address $a$ to force a collision. This is not possible for arbitrary addresses, as the address computation uses the sender's address as an input to a hash function in both cases @wood_ethereum_2024[p.11]. A similar argument can be made about contract creation directly via the transaction and some init code.

Apart from instructions, the nonces of an EOA can also be increased by transactions themselves. $T_B$ could make a `CALL` or `CALLCODE` to the address of an EOA and transfer some Ether. The gas costs for these instructions depend on whether the recipient account already exists or has to be newly created. As such, if $T_B$ makes a `CALL` or `CALLCODE` to a non-existent account, then an attacker could create this account in $T_A$ to reduce the gas costs of the transfer by $T_B$. We do not consider this an attack, as it only reduces the gas costs for $T_B$, which likely has no adverse effects.

Therefore, the remaining attack vectors are `SSTORE`, which can modify the storage of an account, and Ether transfers of `CALL`, `CALLCODE`, `SELFDESTRUCT`, which modify the balance of an account.

== Everything is TOD
Our definition of TOD is very broad and marks many transaction pairs as TOD. For instance, if a transaction $T_B$ uses some storage value for a calculation, then the execution likely depends on the transaction that previously has set this storage value. Similarly, when someone wants to transfer Ether, they can only do so when they first received that Ether. Thus, they are dependent on some transaction that gave them this Ether previously.

#proposition[For every transaction $T_B$ after the London upgrade#footnote[We reference the London upgrade here, as this introduced the base fee for transactions.], there exists a transaction $T_A$ such that $(T_A , T_B)$ is TOD.]
#proof[
  Consider an arbitrary transaction $T_B$ with the sender being some address $italic("sender")$. The sender must pay some upfront cost $v_0 > 0$, because they must pay a base fee @wood_ethereum_2024[p.8-9]. Therefore, we must have $sigma(stateKey("balance", italic("sender"))) gt.eq v_0$. This requires that a previous transaction $T_A$ increased the balance of $italic("sender")$ to be high enough to pay the upfront cost, i.e. $pre(Delta_(T_A))(stateKey("balance", italic("sender"))) < v_0$ and $post(Delta_(T_A))(stateKey("balance", italic("sender"))) gt.eq v_0$.#footnote[For block validators, their balance could have also increased from staking rewards, rather than a previous transaction. However, this would require that a previous transaction gave them enough Ether for staking in the first place. @noauthor_proof--stake_nodate]

  When we calculate $sigma - Delta_(T_A)$ for our TOD definition, we would set the balance of $italic("sender")$ to $pre(Delta_(T_A))(("balance", italic("sender"))) < v_0$ and then execute $T_B$ based on this state. In this case, $T_B$ would be invalid, as the $italic("sender")$ would not have enough Ether to cover the upfront cost.
]

Given this property, it is clear that TOD alone is not a useful attack indicator, since every transaction would be considered as having been attacked. In @sec:tod-attack-characteristics, we discuss more restrictive definitions.

= TOD candidate mining <cha:mining>
In this chapter, we discuss how we search for potential TODs in the Ethereum blockchain. We use the RPC from an archive node to obtain transactions and their state accesses and modifications. Then we search for collisions between these transactions to find TOD candidates. Lastly, we filter out TOD candidates that are not relevant to our analysis.

== TOD candidate finding
We make use of the RPC method `debug_traceBlockByNumber`, which allows for replaying all transactions of a block the same way they were originally executed. With the `prestateTracer` config, this method also outputs, which part of the state has been accessed, and using the `diffMode` config, also which part of the state has been modified#footnote[When running the prestateTracer in diffMode, several fields are only implicit in the response. We need to make these fields explicit for further analysis. Refer to the documentation or the source code for further details.].

By inspecting the source code of the tracers for Reth @paradigm_revm-inspectors_2024 and the results of the RPC call, we found out that for every touched account, it always includes the account’s balance, nonce and code in the prestate. For instance, even when only the balance was accessed, it will also include the nonce in the prestate#footnote[I opened a #link("https://github.com/ethereum/go-ethereum/pull/30081")[pull request] to clarify this behavior and now this is also reflected in the documentation@noauthor_go-ethereum_2024-1.]. Therefore, we do not know precisely which part of the state has been accessed, which can be a source of false positives for collisions.

We store all the accesses and modifications in a database and then query for accesses and writes that have the same state key. As in our definition of collisions, we only match state keys where the first transaction modifies the state. We then use the transactions that cause these collisions as a preliminary set of TOD candidates.

== TOD candidate filtering
Many of the TOD candidates from the previous section are not relevant for our further analysis. To prevent unnecessary computation and distortion of our results, we define which TOD candidates are not relevant and then filter them out.

A summary of the filters is given in @tab:tod_candidate_filters with detailed explanations in the following sections. The filters are executed in the order as presented in the table and always operate on the output of the previous filter. The only exception is the "Same-value collision" filter, which is directly incorporated into the initial collisions query for performance reasons.

The "Block windows", "Same senders" and "Recipient Ether transfer" filters have already been used in @zhang_combatting_2023. The filters "Nonce and code collision" and "Indirect dependency" follow directly from our discussion above. Furthermore, we also applied an iterative approach, where we searched for TOD candidates in a sample block range and manually analyzed whether some of these TOD candidates may be filtered. This approach led us to the "Same-value collisions" and the "Block validators" filter.

#figure(
  table(
    columns: 2,
    align: (left, left),
    table.header([Filter name], [Description of filter criteria]),
    table.hline(),
    [Same-value collision], [Drop collision if $T_A$ writes a different value than the value accessed or overwritten by $T_B$.],
    [Block windows], [Drop candidate if $T_A$ and $T_B$ are 25 or more blocks apart.],
    [Block validators], [Drop collisions on the block validator’s balance.],
    [Nonce and code collision], [Drop nonce and code collisions.],
    [Indirect dependency], [Drop candidates $(T_A, T_B)$ with an indirect dependency, e.g. when candidates $(T_A , T_X )$ and $(T_X , T_B)$ exist.],
    [Same senders], [Drop candidate if $T_A$ and $T_B$ are from the same sender.],
    [Recipient Ether transfer], [Drop candidate if $T_B$ does not execute code.],
  ),
  caption: flex-caption(
    [TOD candidate filters sorted by usage order. When a filter describes the removal of collisions, the TOD candidates will be updated accordingly.],
    [TOD candidate filters],
  ),
  kind: table,
) <tab:tod_candidate_filters>

=== Filters

==== Same-value collisions
When we have many transactions that modify the same state, e.g. the balance of the same account, they will all have a write-write conflict with each other. The number of TOD candidates grows quadratic with the number of transactions modifying the same state. For instance, if 100 transactions modify the balance of address $a$, the first transaction has a write-write conflict with all other 99 transactions, the second transaction with the remaining 98 transactions, etc., leading to a total of $frac(n^2 - n, 2) = 4,950$ TOD candidates.

To reduce this growth of TOD candidates, we additionally require for a collision that $T_A$ writes exactly the value that is read or overwritten by $T_B$. Formally, the following condition must hold to pass this filter:

$
  forall K in colls(T_A , T_B) :
  post(Delta_(T_A)) (K) = pre(Delta_(T_B)) (K)
$

With the example of 100 transactions modifying the balance of address $a$, when the first transaction sets the balance to 1234, it only has a write-write conflict with transactions where the balance of $a$ is exactly 1234 before the execution. If all transactions write different balances, this will reduce the amount of TOD candidates to $n - 1 = 99$.

Apart from the performance benefit, this filter also removes many TOD candidates that are potentially indirectly dependent. For instance, let us assume that we removed the TOD candidate $(T_A , T_B)$. By definition of this filter, there must be some key $K$ with $post(Delta_(T_A)) (K) != pre(Delta_(T_B)) (K)$, thus some transaction $T_X$ must have modified the state at $K$ between $T_A$ and $T_B$. Therefore, we also have a collision (and TOD candidate) between $T_A$ and $T_X$, and between $T_X$ and $T_B$. This is a potential indirect dependency, which may lead to unexpected results, as argued in @sec:weakness-indirect-dependencies.

==== Block windows

According to a study of 24 million transactions from 2019 @zhang_evaluation_2021, the maximum observed time it took for a pending transaction to be included in a block was below 200 seconds. Therefore, when a transaction $T_B$ is submitted, and someone instantly attacks it by creating a new transaction $T_A$, the inclusion of them in the blockchain differs by at most 200 seconds. We currently add a new block to the blockchain every 12 seconds according to Etherscan @etherscan_ethereum_2024, thus $T_A$ and $T_B$ are at most $200 / 12 approx 17$ blocks apart from each other. As the study is already five years old, we use a block window of 25 blocks instead to account for a potential increase in latency since then.

Thus, we filter out all TOD candidates, where $T_A$ is in a block that is 25 or more blocks away from the block of $T_B$.

==== Block validators

In Ethereum, each transaction must pay a transaction fee to the block validator and thus modifies the block validator’s balance. This makes each transaction pair in a block a TOD candidate, as they all modify the balance of the block validator’s address.

We exclude TOD candidates, where the only collision is the balance of any block validator.

==== Nonce and code collisions

We showed in @sec:relevant-collisions that nonce and code collisions are not relevant for TOD attacks. Therefore, we ignore collisions of this state type.

==== Indirect dependency

As argued in @sec:weakness-indirect-dependencies, indirect dependencies can cause unexpected results in our analysis, therefore we will filter TOD candidates that have an indirect dependency. We will only consider the case, where the indirect dependency is already visible in the normal order and accept that we may miss indirect dependencies. Alternatively, we could also remove a TOD candidate $(T_A , T_B)$ when we there exists a TOD candidate $(T_A , T_X)$ for some intermediary transaction $T_X$, however this would remove many more TOD candidates.

We already have a model of all direct (potential) dependencies with the TOD candidates. We can build a transaction dependency graph $G = (V , E)$ with $V$ being all transactions and $E = { (T_A , T_B) divides (T_A , T_B) in "TOD candidates" }$. We then filter out all TOD candidates $(T_A , T_B)$ where there exists a path $T_A , T_(X_1) , dots.h , T_(X_n) , T_B$ with at least one intermediary node $T_(X_i)$.

@fig:tod_candidate_dependency shows an example dependency graph, where transaction $A$ influences both $X$ and $B$ and $B$ is influenced by all other transactions. We filter out the candidate $(A , B)$ as there is a path $A -> X -> B$, but keep $(X , B)$ and $(C , B)$.

#figure(
  [
    #text(size: 0.8em)[
      #diagram(
        node-stroke: .1em,
        mark-scale: 100%,
        edge-stroke: 0.08em,
        node((3, 0), `A`, radius: 1.2em),
        edge("-|>"),
        node((2, 2), `X`, radius: 1.2em),
        edge("-|>"),
        node((4, 3), `B`, radius: 1.2em),
        edge((3, 0), (4, 3), "--|>"),
        edge("<|-"),
        node((5, 1), `C`, radius: 1.2em),
      )
    ]
  ],
  caption: flex-caption(
    [ Indirect dependency graph. An arrow from x to y indicates that y depends on x. A dashed arrow indicates an indirect dependency. ],
    [Indirect dependency graph],
  ),
)
<fig:tod_candidate_dependency>

==== Same sender

If the sender of both transactions is the same, the victim would attack themselves.

To remove these TOD candidates, we use the `eth_getBlockByNumber` RPC method and compare the sender fields for $T_A$ and $T_B$.

==== Recipient Ether transfer

If a transaction sends Ether without executing code, it only depends on the balance of the EOA that signed the transaction. Other entities can only increase the balance of this EOA, which has no adverse effects on the transaction.

Thus, we exclude TOD candidates, where $T_B$ has no code access.

== Experiment
In this section, we discuss the results of applying the TOD candidate mining methodology to a randomly sampled sequence of 100 blocks, different from the block range we used for the filters' development. Refer to @cha:reproducibility for the experiment setup.

We mined the blocks from block 19,830,547 up to block 19,830,647, containing a total of 16,799 transactions.

=== Performance
The mining process took a total of 502 seconds, with 311 seconds used to fetch the data via RPC calls and store it in the database, 6 seconds used to query the collisions in the database, 17 seconds for filtering the TOD candidates and 168 seconds for preparing statistics. If we consider the running time as the total time excluding the statistics preparation, we analyzed an average of 0.30 blocks per second.

We also see that 93% of the running time was spent fetching the data via the RPC calls and storing it locally. This could be parallelized to significantly speed up the process.

=== Filters
In @tab:experiment_filters, we see the number of TOD candidates before and after each filter, showing how many candidates were filtered at each stage. This shows the importance of filtering as we reduce the number of TOD candidates to analyze from more than 60 million to only 8,127.

Note that this does not directly imply that "Same-value collision" filters out more TOD candidates than "Block windows", as they operate on different sets of TOD candidates. Even if "Block windows" filtered out every TOD candidate, this would be less than "Same-value collision" did, because of the order of filter application.

#figure(
  table(
    columns: 3,
    align: (left, right, right),
    table.header([Filter name], [TOD candidates after filtering], [Filtered TOD candidates]),
    table.hline(),
    [(unfiltered)], [(lower bound) 63,178,557], [],
    [Same-value collision], [56,663], [(lower bound) 63,121,894],
    [Block windows], [53,184], [3,479],
    [Block validators], [39,899], [13,285],
    [Nonce collision], [23,284], [16,615],
    [Code collision], [23,265], [19],
    [Indirect dependency], [16,235], [7,030],
    [Same senders], [9,940], [6,295],
    [Recipient Ether transfer], [8,127], [1,813],
  ),
  caption: flex-caption(
    [This table shows the application of all filters used to reduce the number of TOD candidates. Filters were applied from top to bottom. Each row shows how many TOD candidates remained and were filtered. The unfiltered value is a lower bound, as we only calculated this number afterwards, and the calculation does not include write-write collisions.],
    [TOD candidate filters evaluation],
  ),
  kind: table,
)
<tab:experiment_filters>

=== Transactions
After applying the filters, 7,864 transactions are part of at least one TOD candidate. This amounts to 46.8% of all transactions marked as potentially TOD with some other transaction. Only 2,381 of these transactions are part of exactly one TOD candidate. At the other end, there exists one transaction that is part of 22 TOD candidates.

=== Block distance
In @fig:tod_block_dist, we see that most TOD candidates are within the same block. Moreover, the further two transactions are apart, the less likely we are to include them as a TOD candidate. A reason for this may be that having many intermediary transactions makes it more likely to be filtered by our "Indirect dependency" filter. Nonetheless, we can conclude that when using our filters, the block window can be reduced even further without missing many TOD candidates.

#figure(
  image("charts/tod_candidates_block_dist.png", width: 80%),
  caption: flex-caption(
    [
      The histogram and the empirical cumulative distribution function (eCDF) of the block distance for TOD candidates. The blue bars show how many TOD candidates have been found, where $T_A$ and $T_B$ are $n$ blocks apart. The orange line shows the percentage of TOD candidates that are at most $n$ blocks apart.
    ],
    [Block distances of TOD candidates],
  ),
)
<fig:tod_block_dist>

=== Collisions
After applying our filters, we have 8,818 storage collisions and 5,654 balance collisions remaining. When we analyze how often each account is part of a collision, we see that collisions are concentrated around a small set of accounts. For instance, the five accounts with the most collisions#footnote[All of them are token accounts:
#link("https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")[WETH],
#link("https://etherscan.io/address/0x97a9a15168c22b3c137e6381037e1499c8ad0978")[DOP],
#link("https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7")[USDT],
#link("https://etherscan.io/address/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")[USDC]
and
#link("https://etherscan.io/address/0xf938346d7117534222b48d09325a6b8162b3a9e7")[CHOPPY]]
contribute 43.0% of all collisions. In total, the collisions occur in only 1,472 different account states.

@fig:collisions_address_limit depicts how many collisions we get when we only consider the first $n$ collisions for each address. If we set the limit to one collision per address, we end up with 1,472 collisions, which is exactly the number of unique addresses where collisions happened. When we keep 10 collisions per address, we get 3,964 collisions. This criterion already reduces the number of collisions by 73%, while still retaining a sample of 10 collisions for each address.

This paper tires to obtain a diverse set of attacks. With such a strong imbalance towards a few contracts, it will take a long time to analyze TOD candidates related to these frequent addresses, and the attacks are likely related and do not cover a wide range of attack types. To prevent this, we define additional deduplication filters in @sec:deduplication.

#figure(
  image("charts/collisions_limited_per_address.png", width: 80%),
  caption: flex-caption(
    [
      The chart shows how many collisions we have when we limit the number of collisions we include per address. For instance, if we only included 10 collisions for each address we would end up with about 4,000 collisions.
    ],
    [Limit for collisions per address],
  ),
)
<fig:collisions_address_limit>

== Deduplication <sec:deduplication>

To reduce the prevalence of specific contracts among the TOD candidates, we randomly pick 10 collisions of each contract and drop the rest. We apply three mechanisms to group similar contracts:

Firstly, we group the collisions by the address where they happened and randomly select 10 collisions from each group. For instance, if many transactions access the balance and code of the same address, we would only retain 10 of these accesses.

Secondly, we also group collisions at different addresses if the addresses share exactly the same code. To do so, we group the collisions by the code hash and sample 10 collisions per code hash.

Finally, instead of matching for exactly the same code, we also group similar codes together. We use the grouping mechanism from @di_angelo_bytecode_2024, where the authors compute a "skeleton" for each code by removing the metadata and the values for `PUSH` instructions. They have shown that codes with the same skeleton mostly yield the same vulnerability detection results. Therefore, we only keep 10 collisions per code skeleton.

=== Results

We ran the same experiment as in the previous section, but now with the additional deduplication filters. In @tab:experiment_deduplication, we see that from the initial 8,127 TOD candidates, only 2,320 remain after removing duplicates. Most TOD candidates are already removed by limiting the amount of collisions per address and the other group limits reduce it further.

#figure(
  table(
    columns: 3,
    align: (left, right, right),
    table.header([Filter name], [TOD candidates after filtering], [Filtered TOD candidates]),
    table.hline(),
    [(previous filters)], [8,127], [],
    [Limited collisions per address], [2,645], [5,482],
    [Limited collisions per code hash], [2,435], [210],
    [Limited collisions per skeleton], [2,320], [115],
  ),
  caption: flex-caption(
    [This table shows the application of the deduplication filters. We start with the TOD candidates from @tab:experiment_filters and then apply each deduplication filter.],
    [TOD candidate deduplication evaluation],
  ),
  kind: table,
)
<tab:experiment_deduplication>

= TOD detection <sec:tod-detection>

After mining a list of TOD candidates, we now check which of them are actually TOD. We first execute $T_A$ and $T_B$ according to the normal and reverse scenario defined in @sec:tod-simulation. Then we compare the state changes of the scenarios to apply the definitions for TOD and approximately TOD.

== Transaction execution via RPC <sec:transaction-execution-rpc>

Let $(T_A, T_B)$ be our TOD candidate. We split the block containing $T_B$ into three sections:

$ sigma ->^(T_X_0) dots ->^(T_X_n) sigma_X_n ->^(T_B) sigma_T_B ->^(T_Y_0) dots ->^(T_Y_m) sigma_B $

In the normal scenario, we want to execute $T_B$ on $sigma_X_n$ and in the reverse scenario on $sigma_X_n - Delta_T_A$. We use the `debug_traceCall` RPC method for these transaction executions. As parameters, it takes the transaction data, a block number that specifies the block environment and the initial world state, and state overrides that allow us to customize specific parts of the world state. Per default, the method uses the world state #emph[after] executing all transactions in this block, i.e. $sigma_B$. Therefore, we use the state overrides parameter to get from $sigma_B$ to $sigma_X_n$ and $sigma_X_n - Delta_T_A$.

For the normal scenario, we want to execute $T_B$ on $sigma_X_n$. Conceptually, we start from $sigma_B$ and then undo all transaction changes after $T_X_n$ in reverse order, to reach $sigma_X_n$. We do this with the state overrides $sum_(i=m)^0(-Delta_T_Y_i) - Delta_T_B$. For the reverse scenario, we also subtract $Delta_T_A$ from the state overrides, thus simulating how $T_B$ behaves without the changes from $T_A$, giving us the state change $Delta'_T_B$.

To execute $T_A$ in the normal scenario we use the same method as for $T_B$, except that we apply it on the block of $T_A$. For the reverse scenario, we take the state overrides from the normal scenario and add $Delta'_T_B$ to it, simulating how $T_A$ behaves after executing $T_B$. This yields the state changes $Delta'_T_A$.

== Execution inaccuracy <sec:execution-inaccuracy>

While manually testing this method, we found that using `debug_traceCall` with state overrides can lead to incorrect gas cost calculations with Erigon#footnote[See https://github.com/erigontech/erigon/issues/11254.]. To account for these inaccuracies, we compare the state changes from the normal execution via `debug_traceCall` with the state changes from `debug_traceBlockByNumber`. As we do not provide state overrides to `debug_traceBlockByNumber`, this method should yield the correct state changes, and we can detect differences to our simulation.

If the state changes of a transaction only differ in the balances of the senders and the block validators, we keep TOD candidates containing this transaction. Such differences are to be expected when gas costs vary, as the gas costs affect the priority fee sent from the transaction sender to the block validator. However, if there are other differences, we exclude the transaction from further analysis, as the simulation does not reflect the actual behavior in such cases.

A drawback of this inaccuracy is that we do not detect Ether flows between the senders of $T_A$ and $T_B$ that are TOD. For instance, if the sender of $T_A$ sends one Ether to the sender of $T_B$ in the normal scenario, but two Ether in the reverse scenario, then $(T_A, T_B)$ is TOD. However, our analysis would assume that the Ether changes are due to incorrect gas cost calculations and exclude the TOD candidate from further analysis.

== TOD assessment

We use the state changes $Delta_T_A$ and $Delta_T_B$ from the normal scenario and $Delta'_T_A$ and $Delta'_T_B$ from the reverse scenario to check for TOD. For the approximation, we test $Delta_T_B changesDiffer Delta'_T_B$ and for the exact definition we test $angle.l Delta_T_A, Delta_T_B angle.r changesDiffer angle.l Delta'_T_A, Delta'_T_B angle.r$.

@alg:tod-assessment shows, how we perform these state change comparisons. The changed keys, prestates and poststates are obtained from the RPC calls. The black lines show the calculation for the approximation and the blue lines the modifications for the exact definition. For each state key, we compute the change for this key in the normal scenario ($d_1$), and the change in the reverse scenario ($d_2$). If the changes differ between the scenarios, we have a TOD.

#figure(
  kind: "algorithm",
  caption: flex-caption(
    [TOD assessment],
    [TOD assessment],
  ),
  pseudocode-list(hooks: 0.5em)[
    + *for* $K in changedKeys(Delta_T_B) union changedKeys(Delta'_T_B)$
    + #hide[*for* $K$] #text(fill: blue)[$union changedKeys(Delta_T_A) union changedKeys(Delta'_T_A)$]
      + $d_1 = post(Delta_T_B)(K) - pre(Delta_T_B)(K)$
      + $d_2 = post(Delta'_T_B)(K) - pre(Delta'_T_B)(K)$
      + #text(fill: blue)[$d_1 = d_1 + post(Delta_T_A)(K) - pre(Delta_T_A)(K)$]
      + #text(fill: blue)[$d_2 = d_2 + post(Delta'_T_A)(K) - pre(Delta'_T_A)(K)$]
      + *if* $d_1 != d_2$
        + *return* \<TOD\>
    + *return* \<not TOD\>
  ],
) <alg:tod-assessment>

== Experiment

We checked all 2,320 TOD candidates we found previously for TOD and approximately TOD. We then compare the results of these, to evaluate how well the approximation performs in practice.

=== Results

In @tab:experiment_check_definition, we see the results for both definitions. From the 2,320 TOD candidates we analyzed, slightly more than one third are TOD according to both definitions. For the approximation, 19 TOD candidates cannot be analyzed because of execution inaccuracies. For the exact definition, this number is higher, as we need to execute double the amount of transactions.

With both definitions, for 29% of the TOD candidates, $T_B$ fails because of insufficient funds to cover the transaction fee when it is executed without the state changes by $T_A$. This can happen when $T_A$ transfers Ether to the sender of $T_B$, and $T_B$ has less balance than the transaction fee without this transfer. Furthermore, if the execution of $T_B$ consumes more gas without the changes of $T_A$, it needs to pay a higher transaction fee which can also lead to insufficient funds. In both cases, the existence of $T_A$ enables the execution of $T_B$, therefore we do not consider these to be TOD attacks and ignore them from further analysis.

Finally, one error occurred when analyzing for the TOD approximation which did not occur with the exact definition. However, this error is not reproducible, potentially being a temporary fault with the RPC requests.

#figure(
  table(
    columns: 3,
    align: (left, right, right),
    table.header([Result], [Approximately TOD], [TOD]),
    [TOD], [809], [775],
    [not TOD], [819], [839],
    [inaccurate execution], [19], [34],
    [insufficient Ether], [672], [672],
    [error], [1], [0],
  ),
  caption: flex-caption(
    [The results of analyzing TOD candidates for TOD and the approximation of TOD.],
    [TOD checking with definition comparison.],
  ),
  kind: table,
)
<tab:experiment_check_definition>

=== Analysis of differences <sec:analysis-of-differences>

To understand in which cases the two definitions lead to different results, we manually evaluate the cases where one result was TOD and the other not. To assist the analysis, we let our tool output the relative changes of each transaction in both scenarios. In all the cases, we manually verify that the manual application of @alg:tod-assessment on the relative changes gives the same result as the automatic application, to ensure the algorithm was correctly implemented.

Our analysis shows that 34 TOD candidates have been marked as approximately TOD but not TOD. As such, we have $Delta_T_B changesDiffer Delta'_T_B$ and $angle.l Delta_T_A, Delta_T_B angle.r changesEqual angle.l Delta'_T_A, Delta'_T_B angle.r$. In all these cases, the differences of $T_A$ between the normal and reverse scenario balance out the differences of $T_B$ between the normal and reverse scenario. One example is discussed in detail in @app:analysis-of-definition-differences.

Further 10 TOD candidates are TOD but not approximately TOD, i.e. $angle.l Delta_T_A, Delta_T_B angle.r changesDiffer angle.l Delta'_T_A, Delta'_T_B angle.r$ but $Delta_T_B changesEqual Delta'_T_B$. In these cases, $T_A$ creates different state changes depending on whether it was executed before or after $T_B$, thus being TOD. The execution of $T_B$ is not dependent on the transaction order.

A weakness of this comparison is that we use TOD candidates that are tailored for the TOD approximation and therefore TOD candidates that are TOD may be underrepresented. This could be why we found 34 TOD candidates that are approximately TOD but not TOD, while we only found 10 TOD candidates that are TOD but not approximately TOD.

Nonetheless, of the 1,628 TOD candidates labeled as TOD or not TOD according to our approximation, we obtained the same label with the exact TOD definition for 96.4% of these TOD candidates. In the case that TOD transaction pairs are underrepresented in our sample, this still demonstrates that most candidates labeled as approximately TOD are also TOD.

= TOD attack characteristics <sec:tod-attack-characteristics>

Previously, we noted that the TOD definition is too general to be directly used for attack or vulnerability detection. In this section, we discuss several characteristics of TOD attacks that cover more specific cases than the general TOD definition.

== Attacker gain and victim losses <sec:gain-and-loss-property>

In @sec:tod-relation-previous-works, we already discussed how the definition by #cite(<zhang_combatting_2023>, form: "prose") relates to our preliminary definition of TOD. We now present their definition in more detail.

Their definition considers two transaction orderings: $T_A -> T_B -> T_P$ and $T_B -> T_A -> T_P$. When an attack occurs, $T_A$ and $T_B$ are TOD. The transaction $T_P$ is an optional third transaction, which sometimes is required for the attacker to make financial profits. Our study only considers transaction pairs, therefore we adapt their definition and remove $T_P$ from it.

They define an attack to occur when both of the following properties hold:

+ Attacker Gain: "The attacker obtains financial gain in the attack scenario compared with the attack-free scenario."

+ Victim Loss: "The victim suffers from financial loss in the attack scenario compared with the attack-free scenario."

Their attack scenario corresponds to the normal order and the attack-free scenario to the reverse order.

For financial gains and losses, they consider Ether and ERC-20, ERC-721, ERC-777, and ERC-1155 tokens. As an attacker, they consider either the sender of $T_A$ or the contract that $T_A$ calls. The rationale for using the contract that $T_A$ calls is that it may be designed to conduct attacks and temporarily store the profits (see e.g. @torres_frontrunner_2021 for more details). The victim is the sender of $T_B$.

=== Formalization

The authors of @zhang_combatting_2023 do not provide a precise definition of attacker gain and victim loss, therefore we formalize these definitions. For simplicity, we do not explicitly mention $T_A$ and $T_B$ in all formulas, but assume that we inspect a specific TOD candidate $(T_A, T_B)$ and usages of the normal and reverse scenario refer to these two transactions.

==== Assets

#let assetsNormal = "assets_normal"
#let assets = $"Assets"(T_A, T_B)$
#let assetsReverse = "assets_reverse"

We use $assets$ to denote a set of assets that occur in $T_A$ and $T_B$ in any of the scenarios. As an asset, we consider Ether and the tokens that implement one of the standards ERC-20, ERC-721, ERC-777 or ERC-1155. Let $assetsNormal(C, a) in ZZ$ be the amount of assets $C$ that address $a$ gained or lost by executing both transactions in the normal scenario. Let $assetsReverse(C, a)$ be the counterpart for the reverse scenario.

For example, assume an address $a$ converts 1 Ether to 3,000 #link("https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7")[USDT] tokens in the normal scenario, but in the reverse scenario converts 1 Ether to only 2,500 USDT. The assets that occur are $assets = {"Ether", "USDT"}$. The currency changes are $assetsNormal("Ether", a) = -1$, $assetsNormal("USDT", a) = 3,000$, $assetsReverse("Ether", a) = -1$ and $assetsReverse("USDT", a) = 2,500$.

For Ether, we use the `CALL` and `CALLCODE` instructions to compute which addresses gained and lost Ether in a transaction. We do not include the transaction value, as it stays the same regardless of the transaction order#footnote[In the course of the evaluation, we actually discover that it would make sense to include the transaction value. See @sec:attacker-gain-victim-loss-shortcomings.]. Furthermore, we ignore gas costs because of the inaccuracies described in @sec:execution-inaccuracy.

To track the gains and losses for tokens we use the following standardized events:
- ERC-20: `Transfer(address _from, address _to, uint256 _value)`
- ERC-721: `Transfer(address _from, address _to, uint256 _tokenId)`
- ERC-777: `Minted(address operator, address to, uint256 amount, bytes data, bytes operatorData)`
- ERC-777: `Sent(address operator,address from,address to,uint256 amount,bytes data,bytes operatorData)`
- ERC-777: `Burned(address operator, address from, uint256 amount, bytes data, bytes operatorData)`
- ERC-1155: `TransferSingle(address _operator, address _from, address _to, uint256 _id, uint256 _value)`
- ERC-1155: `TransferBatch(address _operator, address _from, address _to, uint256[] _ids, uint256[] _values)`

We only consider calls and event logs if their call context has not been reverted. In Ethereum, a reverted call context means that all changes except for the gas payment are discarded, therefore reverted calls and logs do not influence the gained or lost assets.

==== Attacker gain and victim loss
#let gain = "Gain"
#let onlyGain = "OnlyGain"
#let loss = "Loss"
#let onlyLoss = "OnlyLoss"
#let attack = "Attack"
#let attacker = "attacker"
#let victim = "victim"
#let sender = "sender"
#let recipient = "recipient"

We use the following predicates to express the existence of some asset gain or loss for an address $a$:

$
  gain(a) &<-> exists C in assets: assetsNormal(C, a) > assetsReverse(C, a)\
  loss(a) &<-> exists C in assets: assetsNormal(C, a) < assetsReverse(C, a)\
$

Continuing the previous example of Ether to USDT token conversion, we would have $gain(a) = top$, as $a$ makes more USDT in the normal scenario than in the reverse scenario, and $loss(a) = bot$, as neither for Ether, nor for USDT $a$ has fewer assets in the normal scenario than in the reverse scenario.

However, we also need to consider the case, where both $gain(a)$ and $loss(a)$ are true. For instance, maybe the attacker gains more USDT tokens but also pays more Ether in the normal scenario. It is not trivial to compare arbitrary assets in Ether, therefore we cannot determine if the lost Ether outweighs the gained tokens. To avoid such cases, we introduce the following two predicates:

$
  onlyGain(a) &<-> gain(a) and not loss(a)\
  onlyLoss(a) &<-> loss(a) and not gain(a)\
$

Note that this only considers assets we explicitly model. In the case that $a$ loses some asset that is not modeled, e.g. a token not implementing any of the above standards, $onlyGain(a)$ can be true despite having losses of an unmodeled asset. This is a limitation when not all relevant assets that occur in $T_A$ and $T_B$ are modeled.

With $onlyGain$ and $onlyLoss$ we define an attack to occur when the attacker has only advantages in the normal scenario compared to the reverse scenario, and the victim has only disadvantages:

$
  attack <-> (&onlyGain(sender(T_A)) or onlyGain(recipient(T_A)))\
  and &onlyLoss(sender(T_B))
$

We note that the definition by @zhang_combatting_2023 is not explicit on how different kinds of assets are compared. As such, our attack formalization may differ from their intention and implementation. This is a best effort to match their implementation and also the definitions of a subsequent @zhang_nyx_2024#footnote[We use the tests in `profit_test.go` @zhang_erebus-redgiant_2023 and Appendix A of @zhang_nyx_2024 to understand the intended definition.].

== Securify TOD properties

The authors of Securify describe three TOD properties @tsankov_securify_2018:

- *TOD Transfer*: "[...] the execution of the Ether transfer depends on transaction ordering".
- *TOD Amount*: "[...] the amount of Ether transferred depends on the transaction ordering".
- *TOD Receiver*: "[...] the recipient of the Ether transfer might change, depending on the transaction ordering".

For Ether transfers, they consider only `CALL` instructions. We also use `CALLCODE` instructions, as these can be used to transfer Ether similar to `CALL`s.

The properties can be applied by comparing the execution of a transaction in the normal scenario with the reverse scenario. We say that a property holds for a transaction pair $(T_A, T_B)$ if it holds for at least one of the transactions $T_A$ and $T_B$, i.e. at least one of the transactions shows attack characteristics.

=== Formalization

#let location = math.italic("Loc")
#let instruction = math.italic("Instruction")
#let inputs = math.italic("Inputs")
#let contextAddr = math.italic("ContextAddress")
#let pc = math.italic("ProgramCounter")

We denote the execution of an instruction as a tuple $(instruction, location, inputs)$. The location $location$ is a tuple $(contextAddr, pc)$, where $contextAddr$ is the address that is used for storage and balance accesses when executing the instruction, and $pc$ is the byte offset of the instruction in the executed code. Finally, $inputs$ is a sequence of stack values passed as arguments to the instruction.

#let normalCalls = $F_N$
#let reverseCalls = $F_R$

Let $normalCalls$ denote the set of `CALL` and `CALLCODE` instruction executions with a positive value (i.e. $inputs[2] > 0$) in the normal scenario and $reverseCalls$ the equivalent for the reverse scenario. We exclude calls that have been reverted. For a call execution $C in normalCalls$, we denote its location with $C_L$, the value it transfers with $C_v$ and the recipient of the transfer with $C_a$.

==== TOD Transfer

If there is a location where the number of `CALL`s differ between the normal and the reverse scenario, we say that TOD Transfer is fulfilled:

$
  "TOD-Transfer" <-> exists l o c: |{C in normalCalls | C_L = l o c}| != |{C in reverseCalls | C_L = l o c}|
$

==== TOD Amount

If there is a location and a value where the number of `CALL`s differ between the normal and the reverse scenario, we say that TOD Amount is fulfilled:

$
  "TOD-Amount" <-> &not"TOD-Transfer"\
  &and exists l o c, v:
  |{C in normalCalls | C_L = l o c and C_v = v}| != |{C in reverseCalls | C_L = l o c and C_v = v}|
$

We exclude cases where TOD Transfer is fulfilled, as TOD Amount would always be fulfilled if TOD Transfer is fulfilled.

// For the case that at maximum one call happens per location, we could directly compare the values used at each call between the normal and reverse scenario. However, with loops, multiple call executions can happen at the same location, which is the reason we choose the definition that compares the number of occurrences.

// For example, consider a case where in the normal scenario we have three `CALL`s at the same location $l$, two with value 5 and one with value 6, but in the reverse scenario we have only one `CALL` with value 5 and one with value 6. For location $l$ and value 5 two `CALL`s exist in the normal scenario, but only one in the reverse scenario, therefore TOD Amount is fulfilled.

==== TOD Receiver

We define TOD Receiver analogously to TOD Amount, except that we use the `address` input instead of the `value`:

$
  "TOD-Receiver" <-> &not"TOD-Transfer"\
  &and exists l o c, a: |{C in normalCalls | C_L = l o c and C_a = a}| != |{
    C in reverseCalls | C_L = l o c and C_a = a
  }|
$

== ERC-20 multiple withdrawal

Finally, we also consider ERC-20 multiple withdrawal attacks, which we already discussed in @sec:erc-20-multiple-withdrawal. The ERC-20 standard defines that the following events must be emitted when an approval takes place and when tokens are transferred @vogelsteller_erc-20_nodate.

#let transfer = `Transfer`
#let approval = `Approval`

- `Approval(address _owner, address _spender, uint256 _value)`
- `Transfer(address _from, address _to, uint256 _value)`

As a pattern to detect ERC-20 multiple withdrawal attacks we require the following conditions to be true:
+ Executing $T_A$ in the normal scenario must emit an event $transfer(v, a, x)$ at address $t$.
+ Executing $T_B$ in the normal scenario must emit an event $approval(v, a, y)$ at address $t$.
+ Executing $T_B$ in the reverse scenario must emit an event $approval(v, a, y)$ at address $t$.

The variable $a$ represents the attacker address, $v$ the victim address $x$ the transferred value and $y$ the approved value. We require that the events are not reverted.

As shown in @tab:erc20-multiple-withdrawal-example, executions of `transferFrom` and `approve` can be TOD because `approve` overwrites the currently approved value with the newly approved value. While this behavior is standardized in @vogelsteller_erc-20_nodate, other methods may prevent ERC-20 multiple withdrawal attacks by making a relative increase of the approved value rather than overwriting it. To ensure that there is indeed an overwrite, we require that the approval in the normal scenario is equal to the one in the reverse scenario. If there were a relative change of the approval, the approved value $y$ would differ.


== Trace analysis

To check for the TOD characteristics, we use the same approach to compute state overrides for the normal and reverse scenario as in @sec:transaction-execution-rpc. The `debug_traceCall` method allows the definition of a custom tracer in Javascript that can process each execution step. We use this tracer to track `CALL` and `CALLCODE` instructions and token events.

The Javascript tracer is described in @app:javascript-tracer. When executing a transaction, it returns all non-reverted `CALL`, `CALLCODE`, `LOG0`, `LOG1`, `LOG2`, `LOG3` and `LOG4` instructions and their inputs. We parse the call instructions to obtain Ether changes and the log instructions for token changes and ERC-20 `Approval` events. The results are used to check for the previously defined characteristics.

= Evaluation <sec:evaluation>

In this section, we evaluate the methods proposed above. We use a dataset from @zhang_combatting_2023 as a ground truth to evaluate our TOD candidate mining, the TOD detection and the detection of the attacker gain and victim loss characteristic. For the Securify and ERC-20 multiple withdrawal characteristics, we rely solely on a manual evaluation.

The ground truth dataset contains 6,765 attacks in the block range of 11,299,000 to 11,300,000. From these attacks, 5,601 contain no profit transaction, which we excluded from our definition of the attacker gain and victim loss property. The study by @torres_frontrunner_2021 also investigated this block range, and the attacks they found are a subset of the 6,765 attacks @zhang_combatting_2023. Therefore, showing that our method works well for this ground truth indirectly also shows that it works well for the results of @torres_frontrunner_2021.

First, we combine the TOD candidate mining, the TOD detection, and the TOD attack analysis method to analyze this block range. The results are discussed in @sec:overall-evaluation, where we evaluate our method for false positives. Afterwards, we compare the results of each step individually with the ground truth to check for false negatives.

== Evaluation limitations

We note that in our evaluation, we verify the correctness of the normal scenario, however our verification of the reverse scenario is limited as we do not have access to a ground truth for comparison.

For the normal scenario, we can directly compare it with data from the blockchain, as the executions in the normal scenario should equal the executions that happened on the blockchain. We will use Etherscan @etherscan_ethereum_nodate to access this blockchain data.

Contrary, for the reverse scenario, we simulate a transaction order that did not occur on the blockchain. We can verify that our normal and reverse scenarios are suitable for detecting TOD attacks by comparing our results to the ground truth dataset. However, we only have the results given in the dataset and not the exact executions of the reverse scenario. Therefore, when we encounter differences we cannot conduct an in-depth analysis to understand why differences occur between our method and the ground truth. To allow future research making in-depth comparisons we provide traces for all cases that we manually analyze (see @sec:data-availability), which contain each execution step for the normal and reverse scenarios.

We also compare our normal scenario with the reverse scenario and evaluate where these executions differ. We do so in @sec:evaluate-reverse-scenario, where we verify that the first difference between the normal and reverse scenario matches the state calculations we perform according to the definitions of the normal and normal scenario.


== Overall evaluation <sec:overall-evaluation>

We mined TOD candidates in the 1,000 blocks starting at 11,299,000, which resulted in 14,500 TOD candidates. From those, the TOD detection reported 2,959 as TOD. For 280 of these transaction pairs, we found an attacker gain and victim loss.

We compare the TOD candidates, TODs, and TOD attacks we found against the ground truth in @tab:eval-overall. Our mining procedure marks 115 of the attacks in the ground truth as TOD candidates. From the 115 TOD candidates, 95 are detected as TOD, and of those, 85 are marked as an attack.

When mining the TOD candidates we drop 98% of the ground truth attacks. The following steps drop another 26% of the attacks. We evaluate the reasons for this in the following sections, where we evaluate each component individually.

This section focuses on the 195 attacks we found that are not part of the ground truth.

#figure(
  table(
    columns: 4,
    align: (left, right, right, right),
    table.header([In ground truth], [TOD candidate], [TOD], [Attacker gain and victim loss]),
    table.hline(),
    [Yes], [115], [95], [85],
    [No], [14,385], [2,864], [195]
  ),
  caption: flex-caption(
    [Comparison of results with the 5,601 attacks from the ground truth. The first row shows how many of the 5,601 attacks in the ground truth are also found by our analysis at the individual stages. The second row shows the results our method found, which are not in the ground truth.],
    [Comparison of results with the ground truth.],
  ),
  kind: table,
)<tab:eval-overall>

=== Block window filter

#cite(<zhang_combatting_2023>, form: "prose") only consider transactions within block windows of size three. If transactions are three more blocks apart from each other, they are not part of their analysis. We use a block window of size 25, therefore finding more attacks.

Of the 195 attacks we find that are not in the ground truth, only 19 are within a block window of size 3.

=== Manual analysis of attacks

We manually evaluate the 19 attacks to check if the attacker gain and victim loss property holds. We perform the following steps for each attack:

+ We manually parse the execution traces of the normal and reverse scenario for calls and events related to the attacker and victim accounts.
+ We compute the attacker gain and victim loss property based on these calls and events.
+ For the normal scenario, we verify that the calls and logs for the attacker and victim accounts are equal to those that occurred on the blockchain.

In all 19 cases, the manual evaluation shows that the attacker gain and victim loss property holds and that the relevant calls and logs in the normal scenario match those on the blockchain. However, we notice two shortcomings in our definition of the attacker gain and victim loss property.

==== Definition shortcomings <sec:attacker-gain-victim-loss-shortcomings>

Firstly, we argued that the transaction value is independent of the transaction order, because it is part of the transaction itself. However, when a transaction is reverted, the value is not sent to the receiver. Therefore, the transfer of the transaction value may depend on the transaction order. If we considered the transaction value in the calculation, six of the 19 attacks would be false positives.

Secondly, in five cases, we have a loss for the sender of $T_A$ (the attacker's EOA), while we have only gains for the recipient of $T_A$ (considered the attacker's bot in this case). Our definition considers the attacker gain fulfilled for the attacker's bot and ignores the loss of the attacker's EOA. If we considered them together, we may have different results in such cases.

== Evaluation of Securify and ERC-20 multiple withdrawal characteristics

In the overall analysis, we also analyze the 2,959 transaction pairs that are TOD for the Securify and ERC-20 multiple withdrawal characteristics.

We find that 626 transaction pairs fulfill the TOD Transfer characteristic, 244 TOD Amount, and 1 TOD Receiver. Moreover, we have 15 that fulfill our definition of ERC-20 multiple withdrawal. As the ground truth does not cover these characteristics, we manually analyze samples of each.

=== Manual evaluation of TOD Transfer

We take a sample of 20 transaction pairs that fulfill TOD Transfer. Our tool outputs the locations at which there is a different amount of calls in the normal and reverse scenario. For each sample, we verify the first call location it shows for $T_A$ and $T_B$. To do so, we manually check the execution traces of the normal and reverse scenario for this location and extract the relevant calls. We further verify that these calls match the calls in the normal scenario are equal to those on the blockchain.

We find that in all cases, the TOD transfer property holds for $T_B$, and only in one case it holds additionally for $T_A$.

In 9 of the cases, $T_B$ makes a `CALL` in the normal scenario that is reverted in the reverse scenario. As our definition only considers calls that are not reverted, these fulfill TOD Transfer.

In 8 further cases, $T_B$ makes a `CALL` in the normal scenario but makes no `CALL` at this location in the reverse scenario. In the 3 remaining cases, $T_B$ makes a `CALL` in the reverse scenario but makes no `CALL` in the normal scenario at this location.

We also observe that the locations are often the same. For instance, in five of the cases, the location we analyze is the address `0x7a250d5630b4cf539739df2c5dacb4c659f2488d` at program counter `15784`. When inspecting all 626 transaction pairs that fulfill TOD Transfer we find this location 86 times. Considering that we limit similar collisions to a maximum of 10, this implies that different collisions affect the same functionality.

=== Manual evaluation of TOD Amount

We take a sample of 20 transaction pairs that fulfill TOD Amount. Similar to the TOD Transfer evaluation, we manually verify the first location reported by our tool. For TOD Amount, we verify that in both scenarios there exists a call at this location, but with different values.

The evaluation shows that the property holds in all cases for $T_B$, and in 3 cases also for $T_A$. In 12 cases, the amount of Ether sent is increased in the reverse scenario, and in 11 cases, it is decreased.

Again, we observe many calls happening at the same location. Of the 20 call locations we analyze, the location is 16 times at the address `0x7a250d5630b4cf539739df2c5dacb4c659f2488d` at program counter `15784`.


=== Manual evaluation of TOD Receiver

We evaluate the one transaction pair we found for TOD Receiver similar to how we evaluate TOD Amount, except that we now verify whether the receiver of the Ether transfer changed. Our evaluation shows that this is indeed the case. By inspecting the traces, we can see that in the normal scenario the receiver address is loaded from a different storage slot than in the normal scenario, resulting in different recipients of the Ether transfer.

=== Manual evaluation of ERC-20 multiple withdrawal

We evaluate all 15 transaction pairs where our tool reports an ERC-20 multiple withdrawal attack. Our tool outputs pairs of `Transfer` and `Approval` events that should fulfill the definition. For each case, we manually evaluate the first of these pairs by verifying that the `Transfer` event exists in $T_A$ in the normal scenario and the `Approval` event exists in $T_B$ in the normal and reverse scenario. We further verify that the logs in the normal scenario are equal to those on the blockchain.

While we confirm that all of them fulfill the definition we provide for the ERC-20 multiple withdrawal attack, none of them actually is an attack.

==== Definition shortcomings

Firstly, our definition does not require that the `Transfer` and `Approval` events have positive values. In nine cases we find an `Approval` event that approves 0 tokens and in one case we find a transfer of 0 tokens. These should be excluded from the definition.

Moreover, in 14 cases $T_A$ contains an `Approval` event for the tokens that are transferred in $T_A$. As such, $T_A$ does not use any previously approved tokens, but approves the token itself.

== Evaluation of TOD candidate mining

In this section, we analyze why 98% of the attacks in the ground truth are not reported as TOD candidates, and whether the TOD candidate filters work as intended.

We rerun the TOD candidate mining and count the number of attacks from the ground truth that are in the TOD candidates before and after each filter is applied. Therefore, we know how many of the attacks were removed by which filter.

In @tab:eval-mining, we see that most filters do not filter out any attack from the ground truth. However, they still filter out 500,141 other TOD candidates, thus significantly reducing the search space for further analysis without affecting the attacks we can find.

Furthermore, @tab:eval-mining shows that only one attack is filtered because there is no collision between the accessed and modified states of $T_A$ and $T_B$. This TOD candidate is filtered, because the second transaction of the filtered TOD candidate is part of block 11,300,000, which is not part of the blocks we analyze#footnote[In @zhang_combatting_2023, the dataset is described as originating from an analysis of 1,000 blocks. Block 11,300,000 would be the $1,001$-th block, thus we assume an off-by-one error.].

The filters "Same-value collision" and "Indirect dependency" remove 4,275 TOD candidates with potential indirect dependencies. Finally, our deduplication filters remove another 1,210 TOD candidates. In the following subsections, we evaluate whether these filters fulfill their intention.

#figure(
  table(
    columns: 5,
    align: (left, right, right, right, right),
    table.header(
      [Filter name],
      [TOD candidates after filtering],
      [Filtered TOD candidates],
      [Ground truth attacks after filtering],
      [Filtered ground truth attacks],
    ),
    table.hline(),
    [(unfiltered)], [], [], [5,601], [],
    [Collision], [(unknown)], [], [5,600], [1],
    [Same-value collision], [638,313], [(unknown)], [3,537], [2,063],
    [Block windows], [422,384], [215,929], [3,537], [0],
    [Block validators], [288,264], [134,120], [3,537], [0],
    [Nonce collision], [220,687], [67,577], [3,537], [0],
    [Code collision], [220,679], [8], [3,537], [0],
    [Indirect dependency], [161,062], [59,617], [1,325], [2,212],
    [Same senders], [100,690], [60,372], [1,325], [0],
    [Recipient Ether transfer], [78,555], [22,135], [1,325], [0],
    [Limited collisions per address], [17,300], [61,255], [199], [1,126],
    [Limited collisions per code hash], [14,996], [2,304], [123], [76],
    [Limited collisions per skeleton], [14,500], [496], [115], [8],
  ),
  caption: flex-caption(
    [Comparison of all filtered TOD candidates with filtered attacks from the ground truth. Each row shows how many TOD candidate and attacks are filtered by this filter. TOD candidates before filtering for same-value collisions were not compute because of performance limitations.],
    [Comparison of all filtered TOD candidates with filtered attacks from the ground truth],
  ),
  kind: table,
)
<tab:eval-mining>

=== Evaluation of indirect dependency filters

The "Same-value collision" and "Indirect dependency" filters both target TOD candidates with indirect dependencies, as these may lead to unexpected analysis results (see @sec:weakness-indirect-dependencies).

We evaluate, for how many of the removed attack TOD candidates $(T_A, T_B)$, there exists an intermediary transaction $T_X$, such that both $(T_A, T_X)$ and $(T_X, T_B)$ are TOD. In such cases, any reordering that moves $T_A$ after $T_X$ or $T_X$ after $T_B$ may influence how $T_A$ and $T_B$ execute. While our filters also remove indirect dependencies which require more than one intermediary transaction (e.g. $T_A -> T_X_1 -> T_X_2 -> T_B$), we limit our evaluation to only one intermediary transaction for performance reasons.

We rerun the TOD candidate mining until the "Indirect dependency" filter would be executed. For 1,720 of the 4,275 TOD candidates $(T_A, T_B)$ we evaluate, we find another two TOD candidates $(T_A, T_X)$ and $(T_X, T_B)$. These TOD candidates show a potential indirect dependency of $(T_A, T_B)$ with the one intermediary transaction $T_X$. We do not evaluate the remaining 2,555 TOD candidates, which either have an indirect dependency with multiple intermediary transactions, or have an indirect dependency where one of the TOD candidates $(T_A, T_X)$ or $(T_X, T_B)$ has already been filtered.

We run or TOD detection on the 1,720 $(T_A, T_X)$ TOD candidates and the 1,720 $(T_X, T_B)$ TOD candidates. We find that in 1,319 cases both $(T_A, T_X)$ and $(T_X, T_B)$ being TOD. In 159 cases, at least one analysis failed. In the remaining 242 cases, at least one of the TOD candidates $(T_A, T_X)$ or $(T_X, T_B)$ is confirmed not to be TOD.

In summary, we show that in at least 1,319 of the 4,275 cases where we filtered out a an attack of the ground truth, there exists a transaction that is TOD with both $T_A$ and $T_B$ of this attack and thus potentially interferes with the TOD simulation.

=== Evaluation of duplicate limits

The filters "Limited collisions per address", "Limited collisions per code hash" and "Limited collisions per skeleton" aim to reduce the amount of TOD candidates without reducing the diversity of the attacks we find.

For our evaluation, we do not directly measure the diversity of the attacks. Instead, we evaluate how well the attacks that were not filtered cover the attacks that were filtered. To measure the coverage, we use collisions. We say, that a TOD candidate $(T_A, T_B)$ is covered by a set of TOD candidates ${(T_C_0, T_D_0), ..., (T_C_n, T_D_n)}$ if the following condition holds:

$
  colls(T_A, T_B) subset.eq union.big_(0 <= i <= n) colls(T_C_i, T_D_i)
$

For this analysis, we only consider collisions that remain after applying all previous filters.

From the 1,210 attacks that were removed by duplicate limits, we have 703 that are covered by the remaining attacks. Thus, if we combine the collisions of the 115 remaining attacks, we have the same collisions as if we included these 703 covered attacks. From the 703 covered attacks, we can match at least#footnote[We use a naive algorithm to detect collision coverage, which does not minimize the required attacks for coverage. Thus, the number of attacks covered by a single other attack is a lower bound.] 504 removed attacks $(T_A, T_B)$ with a remaining attack $(T_C, T_D)$, such that $colls(T_A, T_B) subset.eq colls(T_C, T_D)$. Thus, in 504 cases a removed attack is covered by exactly one remaining attack.

We also notice that attacks are concentrated around the same collisions. When we take the top three attacks that were not removed by duplicate limits, we already cover 373 of the 1,210 attacks we removed.

Our calculations of coverages are lower limits, as we only consider the 115 remaining attacks from the ground truth but not the 195 attacks we find that are not in the ground truth. All attacks we find are subject to the duplicate limit, therefore some ground truth attacks may have been removed while keeping an attack not in the ground truth that has similar collisions.

== Evaluation of TOD detection

To evaluate our TOD detection method, we run it on the attacks from the ground truth.

From the 5,601 attacks, our method finds that 4,827 are TOD and 4,857 approximately TOD. We do not manually compare the differences of the TOD detection with the approximation, as we already did so in @sec:tod-detection. However, that for the attacks from the ground truth one can use the TOD approximation without loosing attacks.

There are 774 attacks that our method misses. For 20 of those an error occurred while analyzing for TOD#footnote[18 of the errors are caused by a bug in Erigon, where it reports negative balances for accounts for some transactions (#link("https://github.com/erigontech/erigon/issues/9531")[fixed in v2.60.3]). 2 of them were caused by connection errors.] and for 296 we detected execution inaccuracies (see @sec:execution-inaccuracy) and stopped the analysis.

From the remaining 458 attacks, we find that most have the metadata "out of gas" in the ground truth dataset. Attacks with this "out of gas" label account for 97.6% of the attacks we do not find, while they only account for 19.1% of the 5,601 attacks in the ground truth.

=== Manual evaluation of attacks labeled "out of gas" <sec:evaluation-out-of-gas>

According to the dataset description, this label refers to a #emph[gas estimation griefing attack], which is described in @zhang_combatting_2023. The authors consider such an attack to occur when $T_B$ runs out of gas in the normal scenario but not in the reverse scenario.

We manually inspect a sample of 20 attacks and find that in 12 attacks, $T_B$ is indeed reverted according to Etherscan. In these cases, our simulation method further shows that $T_B$ is reverted in both scenarios. As $T_B$ also revertes in the reverse scenario, these cases are no gas estimation griefing attacks according to our simulation.

In the remaining 8 cases, our method reports no reverts in either scenario. For one case, Etherscan reports that $T_B$ had an internal out of gas error, which was caught without reverting the whole transaction. Therefore, at least the 7 cases where $T_B$ did not revert in the normal scenario are no gas estimation griefing attacks.

As such, it is unclear if this label classifies these attacks as gas estimation griefing attacks. Furthermore, it appears that attacks with this label do not necessarily fulfill the attacker gain and victim loss property. The dataset usually describes the profits of an attacker and losses of a victim in each attack. However, 347 of the 1,043 attacks with the "out of gas" label do not contain a description of the victim losses. However, this description exists for all attacks without the "out of gas" label. In summary, it is unclear how we should interpret these attacks from the ground truth and thus we ignore them from further analysis.

=== Manual evaluation of attacks not labeled "out of gas"

We manually check the remaining 11 attacks that our method does not report as TOD.

We check if these are caused by bugs in the RPC method implementation by rerunning the analysis with a Reth archive node, in addition to the Erigon archive node we use for our experiments. In two cases, using Reth we report them as TOD because of the same balance changes as reported in the ground truth, showing the inaccuracies from @sec:execution-inaccuracy.

Furthermore, we compare the traces of the instruction executions between the scenarios. For 8 attacks, the traces in the normal scenario are equal to those in the reverse scenario, therefeore no write-read or read-write TOD has occurred. By inspecting the state changes in Etherscan, we also rule out write-write TODs, where both transactions write to the same storage slot. As such, these are indeed TOD accocrding to the traces of our simulation.

Finally, for one attack $T_B$ reverts in both scenarios. The ground truth dataset reports token changes in the reverse scenario, therefore our execution must differ from theirs, which we do not further investigate.


== Evaluation of TOD attack analysis

We run our TOD attack analysis on the 5,601 attacks from the ground truth. Our analysis reports an attacker gain and victim loss in 4,524 of the cases. In 19 cases we encountered the same errors as for the TOD checking. In another 152 cases, we detect execution inaccuracies. In the remaining 907 cases, our analysis runs without failures but reports different results than in the ground truth.

From these 907 cases, 850 are labeled as "out of gas" in the ground truth. As discussed in @sec:evaluation-out-of-gas, it seems that these do not necessarily fulfill the attacker gain and victim loss property. Therefore, we do not investigate these cases. We manually evaluate 10 of the 56 cases without the "out of gas" label.

=== Manual evaluation of attacks

==== Evaluation of profit calculations

We verify that the transaction pair does not fulfill the attacker gain and victim loss property according to the execution traces of our normal and reverse scenarios. In each case, we disprove the property by manually parsing the calls and logs and calculating the profits and losses.

In five cases, there is a victim gain according to our traces. In three cases, we calculate an attacker loss. In the two other cases, the traces of the attacker's transaction behave identical in the normal and reverse scenarios. We show that one of these cases is not TOD in @app:analysis-TOD.

==== Evaluation of reverse scenario <sec:evaluate-reverse-scenario>

We further want to verify that our tool correctly executes the reverse scenario.

For each case, we pick one of the transactions. For this transaction, we compare the $n$-th executed instruction of the normal scenario with the $n$-th executed instruction of the reverse scenario. We start with $n = 0$ and continue until we find a difference between the executions. For the comparison, we use the current EVM stack, memory, program counter, gas, and call context depth.

In one case, we do not find any difference, as the transactions are not TOD. In the other nine cases, the first difference is after executing the `SLOAD` instruction, which loads a value from the storage.

When we analyze the execution of the attacker's transaction ($T_A$), we execute it on the states $sigma$ and $sigma + Delta'_T_B$. Because we observer that `SLOAD` returns different values for $sigma$ and $sigma + Delta'_T_B$, the accessed storage slot should be modified by $Delta'_T_B$. We verify that in the normal scenario, the result of the `SLOAD` is equal to the value this storage slot had before executing $T_A$ according to Etherscan. For the reverse scenario, we compare it against the last `SSTORE` of the execution of $T_B$ in the reverse scenario, i.e. the value that $Delta'_T_B$ changes it to.

We approach the verification of the accessed storage values of $T_B$ similarly. For $T_B$ we use the states $sigma_X_n$ for the normal scenario and $sigma_X_n - Delta_T_A$ for the reverse scenario. We compare the result of the `SLOAD` in the normal scenario with the value it had before executing $T_B$ according to Etherscan. For the reverse scenario, we compare it with the value it had before executing $T_A$ according to Etherscan. We notice that in all these cases, $T_A$ wrote a value to this storage slot that is different from the one that $T_B$ reads in the normal scenario. Therefore, there must be intermediary transactions that changed this storage value between $T_A$ and $T_B$, possibly causing an indirect dependency.

In summary, we verify that at least the first difference between the normal and reverse scenarios is in accordance with the definition of the normal and reverse scenarios.

==== Evaluation of indirect dependencies

As our previous evaluation shows, there are several attacks where an intermediary transaction modifies a storage slot that is written by $T_A$ and accessed by $T_B$, potentially creating an indirect dependency. In this section, we additionally evaluate for a specific kind of indirect dependency.

When we simulate an attack $(T_A, T_B)$, we execute $T_B$ in the reverse scenario on the state $sigma_X_n - Delta_T_A$. Therefore, for all state keys $K in changedKeys(Delta_T_A)$ we use the value at $pre(Delta_T_A)(K)$ and for the other state keys $K in.not changedKeys(Delta_T_A)$ we use $sigma_X_n (K)$.

We now consider an intermediary transaction $T_X$ with the state changes $Delta_T_X$, where $changedKeys(Delta_T_X)$ contains some keys that are changed by $T_A$ and also other keys that $T_A$ does not change. When we execute $T_B$ on $sigma_X_n - Delta_T_A$, we only overwrite some of the changes of $T_X$ and keep the other changes. Therefore, $T_B$ executes on a state where state changes of $T_X$ are only partially included.

Our evaluation shows that in 2 of the 10 cases, we can indeed find an intermediary transaction $T_X$, such that at $T_B$ accesses at least one change of $T_X$ that is overwritten by computing $sigma_X_n - Delta_T_A$, and one change of $T_X$ that is not overwritten. Thus, in these cases, $T_B$ uses a possibly incoherent state. We further verify that $(T_A, T_X)$ and $(T_X, T_B)$ are both TOD. However, we do not investigate, how the partial revert of $T_X$ influences the transaction execution.

==== Unmodeled token events

In one case, the attacker's transaction emits a `Deposit` event. This event is not part of the token standards we model in our definition, therefore our profit calculations ignore this event.

This `Deposit` event is emitted by the #link("https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code")[WETH] token when someone converts Ether to WETH tokens. Our analysis only assesses a loss of Ether, but not a gain of WETH tokens. If we modeled the `Deposit` event, we would also mark this transaction pair as an attack.

By inspecting the source code at @zhang_erebus-redgiant_2023, we find that they also detect `Deposit` and `Withdrawal` events when they are emitted by the address of the WETH token.

== Performance evaluation

The evaluation of the 1,000 blocks took a total of 75 minutes, averaging to 4.5 seconds per block.

For the TOD candidate mining, we spent 41 minutes fetching the state changes of the 1,000 blocks and inserting them into a database, another 13 minutes filtering the TOD candidates, and 3 minutes for other tasks.

For the TOD detection and TOD attack analysis, we fetch the state changes and transactions and store them in memory for faster access. Because the state changes are already in our RPC cache, these two steps combined only took 5 minutes.

After fetching the state changes and transactions, we ran the TOD detection and TOD attack analysis using 16 threads, enabling us to make multiple RPC requests in parallel. To check the 14,500 TOD candidates for TOD it took 11 minutes, an average of 44 milliseconds per TOD candidate. The attack analysis of the 2,959 TOD transaction pairs took 4 minutes, averaging to 77 milliseconds per analysis.

Compared with @zhang_combatting_2023, our analysis took 4.5 seconds per block, while they report an average of 7.5 seconds per block. However, we cannot directly compare this, as their hardware specifications differ from our setup and in our case the transaction execution is outsourced to an archive node of which we do not know the hardware specifications. Moreover, @zhang_combatting_2023 only reports an average for their whole analysis, and it is not clear if e.g. the vulnerability localization performed in this work is included in this time measurement.

= Discussion


This thesis proposes a method to simulate transaction order dependencies. We precisely define this simulation process and discuss its advantages and disadvantages. Our evaluation shows that it can be used to detect TOD and several attack characteristics, finding more than 80% of the attacks from a previous work.

Nonetheless, we note that our simulation method and the methods of two related studies have drawbacks that can lead to analysis results that do not match the execution that happened on the blockchain or are distorted by the influence of intermediary transactions. The method by @torres_frontrunner_2021 removes intermediary transactions for the simulation. On the downside, this may create results that differ from the blockchain even in the normal transaction order. On the upside, the different orderings can then be compared without the potential influence of intermediary transactions. The methods by @zhang_combatting_2023 and us produce results that are equal to the blockchain in the normal order, but can suffer influences from intermediary transactions in the reverse order.

We discuss when influences from intermediary transactions can occur with our method, and thus, we are able to avoid such cases. However, future work may continue to reduce the influence of intermediary transactions on TOD simulations or analyze the tradeoffs between existing methods.

= Data availability and reproducibility
<cha:reproducibility>

== Tool

The program used to run the experiments is available at https://github.com/TOD-theses/t_race. It can be run with Python or Docker and requires an archive node that supports the debug namespace, including JS tracing for the attack analysis. Refer to the documentation on the repository for more details on using it.

The TOD candidates deduplication relies on randomness. To allow reproducibility, the program sets a seed for the randomness before executing the randomized deduplication step.

== Data availability <sec:data-availability>

The experiment results and evaluation artifacts produced by this thesis are available at https://github.com/TOD-theses/t_race_results. This includes the outputs of the tool executions, post-processed data and the evaluation samples with corresponding notes.


== Experiment setup

The experiments were performed on Ubuntu 22.04.04, using an AMD Ryzen 5 5500U CPU with 6 cores and 2 threads per core and an SN530 NVMe SSD. We used a 16 GB RAM with an additional 32 GB swap file.

For the RPC requests, we did not use our own archive node, but relied on a free service by @nodies_web3_nodate, which uses Erigon 2.59.3 @noauthor_erigon_2024 according to the `web3_clientVersion` RPC method. In the evaluation, we also refer to the usage of a Reth instance for a few TOD checks. We use a public Reth 1.0.4 instance for this @paradigm_reth_nodate. We used a local cache to prevent repeating slow RPC requests @fuzzland_eth_2024. The cache was initially empty for experiments that measure the running time.
