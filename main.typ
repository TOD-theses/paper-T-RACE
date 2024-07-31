#import "@preview/definitely-not-tuw-thesis:0.1.0": flex-caption
#import "@preview/lovelace:0.3.0": *
#import "utils.typ": *

= Introduction
TBD.

#figure(caption: flex-caption([Overview#todo[Create an overview chart similar to this one]], [WIP overview chart]))[
  #image("graphics/components.png")
]

== Contributions
- Precise definition of TOD in the context of blockchain transaction
  analysis.
- Theoretical discussion of TOD, including compilation of instructions
  that can cause TOD.
- Methodology to mine potential TOD transaction pairs using only the RPC
  interface of an archive node, rather than requiring local access to
  it.

= Background
This chapter gives background knowledge on Ethereum, that is helpful to follow the remaining paper. We also introduce a notation for these concepts.

== Ethereum
Ethereum is a blockchain, that can be characterized as a \"transactional singleton machine with shared-state\". @wood_ethereum_2024[p.1] By using a consensus protocol, a decentralized set of nodes agrees on a globally shared state. This state contains two types of accounts: #emph[externally owned accounts] (EOA) and #emph[contract accounts] (also referred to as smart contracts). The shared state is modified by executing #emph[transactions]. @tikhomirov_ethereum_2018

== World State
Similar to @wood_ethereum_2024[p.3], we will refer to the shared state as #emph[world state]. The world state maps each 20 byte address to an account state, containing a #emph[nonce], #emph[balance], #emph[storage] and #emph[code]#footnote[Technically, the account state only contains hashes that identify the storage and code, not the actual storage and code. This distinction is not relevant in this paper, therefore we simply refer to them as nonce and code.]. They store following data @wood_ethereum_2024[p.4]:

- #emph[nonce]: For EOAs, this is the number of transactions submitted
  by this account. For contract accounts, this is the number of
  contracts created by this account.
- #emph[balance]: The value of Wei this account owns, a smaller unit of
  Ether.
- #emph[storage]: The storage allows contract accounts to persistently
  store information across transactions. It is a key-value mapping where
  both, key and value, are 256 bytes long. For EOAs, this is empty.
- #emph[code]: For contract accounts, the code is a sequence of EVM
  instructions.

We denote the world state as $sigma$, the account state of an address $a$ as $sigma (a)$ and the nonce, balance, storage and code as $sigma (a)_n$, $sigma (a)_b$, $sigma (a)_s$ and $sigma (a)_c$ respectively. For the value at a storage slot $k$ we write $sigma (a)_s [k]$. We will also use an alternative notation $sigma (K)$, where we combine the identifiers of a state value to a single state key $K$, which simplifies further definitions. We have the following equalities between the two notations:

$
  sigma(a)_n &= sigma(("'nonce'", a)) \
  sigma(a)_b & = sigma(("'balance'", a)) \
  sigma(a)_c & = sigma(("'code'", a)) \
  sigma(a)_s[k] & = sigma(("'storage'", a, k))
$

== EVM
The Ethereum Virtual Machine (EVM) is used to execute code in Ethereum. It executes instructions, that can access and modify the world state. The EVM is Turing-complete, except that it is executed with a limited amount of #emph[gas] and each instruction costs some gas. When it runs out of gas, the execution will halt. @wood_ethereum_2024[p.14] For instance, this prevents execution of infinite loops, as it would use infinitely much gas and thus exceed the gas limit.

Most EVM instructions are formally defined in the Yellowpaper. @wood_ethereum_2024[p.30-38] However, the Yellowpaper currently does not include the changes from the Cancun upgrade @noauthor_history_2024, therefore we will also refer to the informal descriptions available on #link("https://www.evm.codes/")[evm.codes]. @smlxl_evm_2024

== Transactions
A transaction can modify the world state by transferring Ether and executing EVM code. It must be signed by the owner of an EOA and contains following data relevant to our work:

- #emph[sender]: The address of the EOA that signed this transaction.#footnote[The sender is implicitly given through a valid signature and the transaction hash. @wood_ethereum_2024[p.25-27] We are only interested in transactions that are included in the blockchain, thus the signature must be valid and the transaction’s sender can always be derived.]
- #emph[recipient]: The destination address.
- #emph[value]: The value of Wei that should be transferred from the
  sender to the recipient.
- #emph[gasLimit]: The maximum number of gas, that can be used for the
  execution.

If the recipient address is empty, the transaction will create a new contract account. These transactions also include an #emph[init] field, that contains the code to initialize the new contract account.

When the recipient address is given and a value is specified, this will be transferred to the recipient. Moreover, if the recipient is a contract account, it also executes the recipient’s code. The transaction can specify a #emph[data] field to pass input data to the code execution. @wood_ethereum_2024[p.4-5]

For every transaction the sender must pay a #emph[transaction fee]. This is composed of a #emph[base fee] and a #emph[priority fee]. Every transaction must pay the base fee. The amount of Wei will be reduced from the sender and not given to any other account. For the priority fee, the transaction can specify if, and how much they are willing to pay. This fee will be taken from the sender and given to the block validator, which is explained in the next section. @wood_ethereum_2024[p.8]

We denote a transaction as $T$, sometimes adding a subscript $T_A$ to differentiate from another transaction $T_B$.

== Blocks
The Ethereum blockchain consists of a sequence of blocks, where each block builds upon the state of the previous block. To achieve consensus about the canonical sequence of blocks in a decentralized network of nodes, Ethereum uses a consensus protocol. In this protocol, validators build and propose blocks to be added to the blockchain. @noauthor_gasper_2023 It is the choice of the validator, which transactions to include in a block, however they are incentivized to include transactions that pay high transaction fees, as they receive the fee. @wood_ethereum_2024[p.8]

Each block consists of a block header and a sequence of transactions. We denote the nth block of the blockchain as $B_n$ and the sequence of transactions it includes as $T (B_n) = (T_1 , T_2 , dots.h , T_m)$.

== Transaction submission
This section discusses, how a transaction signed by an EOA ends up being included in the blockchain.

Traditionally, the signed transaction is broadcasted to the network of nodes, which temporarily store them in a #emph[mempool], a collection of pending transactions. The current block validator then picks transactions from the mempool and includes them in the next block. With this submission method, the pending transactions in the mempool are publicly known to the nodes in the network, even before being included in the blockchain. This time window will be important for our discussion on frontrunning, as it gives nodes time to react on a transaction before it becomes part of the blockchain. @eskandari_sok_2020

A different approach, the Proposer-Builder Separation (PBS) has become more popularity recently: Here, we separate the task of collecting transactions and building blocks with them from the task of proposing them as a validator. A user submits their signed transaction or transaction bundle to a block builder. The block builder has a private mempool and uses it to create profitable blocks. Finally, the validator picks one of the created blocks and adds it to the blockchain. @heimbach_ethereums_2023

== Transaction execution
In Ethereum, transaction execution is deterministic. @wood_ethereum_2024[p.9] Transactions can access the world state and their block environment, therefore their execution can depend on these values. After executing a transaction, the world state is updated accordingly.

We denote a transaction execution as $sigma arrow.r^T sigma prime$, implicitly letting the block environment correspond to the transaction’s block. Furthermore, we denote the state change by a transaction $T$ as $Delta_T$, with $pre(Delta_T) = sigma$ being the world state before execution and $post(Delta sigma_T) = sigma prime$ the world state after the execution of $T$.

#change[$Delta_T$ definition is now about relative changes.]

For two state changes $Delta_T_A$ and $Delta_T_B$, we say that $Delta_T_A = Delta_T_B$ if the relative change of the values is equal. Formally, let $Delta_T_A = Delta_T_B$ be true if and only if:

$
  forall K: post(Delta_T_A)(K) - pre(Delta_T_A)(K) &= post(Delta_T_B)(K) - pre(Delta_T_B)(K)
$

For example, if both $Delta_T_A$ and $Delta_T_B$ increase the balance at address $a$ by 10 Wei and make no other state changes, then $Delta_T_A = Delta_T_B$. If one of them would have modified it by e.g. 15 Wei or 0 Wei, or additionally modified some storage slot, we would have $Delta_T_A != Delta_T_B$.

We define $sigma + Delta_T$ to be equal to the state $sigma$, except that every state that was changed by the execution of $T$ is overwritten with the value in $post(Delta_T)$. Similarly, $sigma - Delta_T$ is equal to the state $sigma$, except that every state that was changed by the execution of $T$ is overwritten with the value in $pre(Delta_T)$. Formally, these definitions are as follows:

$ changedKeys(Delta) colon.eq {K \| pre(Delta)(K) != post(Delta) (K)} $

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

For instance, if transaction $T$ changed the storage slot 1234 at address 0xabcd from 0 to 100, then $(sigma + Delta_T) ("0xabcd")_s [1234] = 100$ and $(sigma - Delta_T) ("0xabcd")_s [1234] = 0$. For all other storage slots we have $(sigma + Delta_T) (a)_s [k] = sigma (a)_s [k] = (sigma - Delta_T) (a)_s [k]$.

== Nodes
A node consists of an #emph[execution client] and a #emph[consensus client]. The execution client keeps track of the world state and the mempool and executes transactions. The consensus client takes part in the consensus protocol. For this work, we will use an #emph[archive node], which is a node that allows to reproduce the state and transactions at any block. @noauthor_nodes_2024

== RPC
Execution clients implement the Ethereum JSON-RPC specification. @noauthor_ethereum_2024 This API gives remote access to an execution client, for instance to inspect the current block number with `eth_blockNumber` or to execute a transaction without committing the state via `eth_call`. In addition to the standardized RPC methods, we will also make use of methods in the debug namespace, such as `debug_traceBlockByNumber`. While this namespace is not standardized, several execution clients implement these additional methods @noauthor_go-ethereum_2024@noauthor_rpc_2024@noauthor_reth_2024.

= Transaction order dependency
In this chapter we discuss our definition of transaction order dependency (TOD) and various properties that come with it. We first lay out the idea of TOD with a basic definition and then show several shortcomings of this simple definition. Based on these insights, we construct a more precise definition that we will use for our analysis.

== Approaching TOD
Intuitively, a pair of transactions $(T_A , T_B)$ is transaction order dependent (TOD), if the original execution order leads to a different result than a reordered execution order. In formal terms, we write this as following:

$
  sigma arrow.r^(T_A) sigma_1 arrow.r^(T_B) sigma prime \
  sigma arrow.r^(T_B) sigma_2 arrow.r^(T_A) sigma prime prime \
  sigma prime != sigma prime prime
$

So, starting from an initial state, when we execute first $T_A$ and then $T_B$ it will result in a different state, than when executing $T_B$ and afterwards $T_A$.

We will refer to the execution order $T_A arrow.r T_B$, the one that occurred on the blockchain, as the #emph[normal] execution order, and $T_B arrow.r T_A$ as the #emph[reversed] execution order.

== Motivating examples
TBD.

#todo("Add a motivating example for write-read TOD (e.g.  TOD-recipient) and for write-write TOD (e.g. ERC-20 approval).")

== Relation to previous works
In @torres_frontrunner_2021 the authors do not provide a formal definition of TOD. However, for displacement attacks, they include the following check to detect if two transactions fall into this category:

#quote(block: true)[
  \[...\] we run in a simulated environment first $T_A$ before $T_V$ and then $T_V$ before $T_A$. We report a finding if the number of executed EVM instructions is different across both runs for $T_A$ and $T_V$, as this means that $T_A$ and $T_V$ influence each other.
]

Similar to our intuitive TOD definition, they execute $T_A$ and $T_V$ in different orders and check if it affects the result. In their case, they only check the number of executed instruction, instead of the resulting state. This would miss attacks where the same instructions were executed, but the operands for these instructions in the second transaction changed because of the first transaction.

In @zhang_combatting_2023, they define an attack as a triple $A = angle.l T_a , T_v , T_a^p angle.r$, where $T_a$ and $T_v$ are similar to the $T_A$ and $T_B$ from our definition, and $T_a^p$ is an optional third transaction. They consider the execution orders $T_a arrow.r T_v arrow.r T_a^p$ and $T_v arrow.r T_a arrow.r T_a^p$. They monitor the transactions to check if the execution order impacts financial gains, which we will discuss later in more detail.#todo[Reference frontrunning section]

We note that if these two execution orders result in different states, this is not because of the last transaction $T_a^p$, but because of a TOD between $T_a$ and $T_v$. As we always execute $T_a^p$ last, and transaction execution is deterministic, it only gives a different result if the execution of $T_a$ and $T_v$ gave a different result. Therefore, if the execution order results in different financial gains, then $T_a$ and $T_v$ must be TOD.

== Imprecise definitions
Our intuitive definition of TOD, and the related definitions shown above, are not precise on the semantics of a reordering of transactions and their executions. These make it impossible to apply exactly the same methodology without analyzing the source code related to the papers. We detect three issues, where the definition is not precise enough and show how these were differently interpreted by the two papers.

For the analysis of the tools by @zhang_combatting_2023 and @torres_frontrunner_2021, we will use the current version of the source codes, @zhang_erebus-redgiant_2023 and @torres_frontrunner_2022 respectively.

=== Intermediary transactions
To analyze the TOD $(T_A , T_B)$, we are interested in how $T_A$ affected $T_B$. Our intuitive definition did not specify how to handle transactions that occurred between $T_A$ and $T_B$, which we will name #emph[intermediary transactions].

For instance, let us assume that there was one transaction $T_X$ in between $T_A$ and $T_B$: $sigma arrow.r^(T_A) sigma_A arrow.r^(T_X) sigma_(A X) arrow.r^(T_B) sigma_(A X B)$. The execution of $T_B$ clearly could depend on both, $T_A$ and $T_X$. When we are interested in the impact of $T_A$ on $T_B$, we need to define what happens with $T_X$.

For executing the normal order, we would have two possibilities:

+ $sigma arrow.r^(T_A) sigma_A arrow.r^(T_X) sigma_(A X) arrow.r^(T_B) sigma_(A X B)$, the same execution as on the blockchain, including the effects of $T_X$.

+ $sigma arrow.r^(T_A) sigma_A arrow.r^(T_B) sigma_(A B)$, leaving out $T_X$ and thus having a normal execution that potentially diverges from the results on the blockchain (as $sigma_(A B)$ may differ to $sigma_(A X B)$).

When executing the reverse order, we could make following choices:

+ $sigma arrow.r^(T_B) sigma_B arrow.r^(T_A) sigma_(B A)$, which ignores $T_X$ and thus may impact the execution of $T_B$.

+ $sigma arrow.r^(T_X) sigma_X arrow.r^(T_B) sigma_(X B) arrow.r^(T_A) sigma_(X B A)$, which executes $T_X$ on $sigma$ rather than $sigma_A$ and now also includes the effects of $T_X$ for executing $T_A$.

All of these scenarios are possible, but none of them provides a clean solution to solely analyze the impact of $T_A$ on $T_B$, as we always could have some indirect impact from the (non-)execution of $T_X$.

In @zhang_combatting_2023, this impact of the intermediary transactions is acknowledged and caused a few false positives:

#quote(block: true)[
  In blockchain history, there could be many other transactions between $T_a$, $T_v$, and $T_p^a$. When we change the transaction orders to mimic attack-free scenarios, the relative orders between $T_a$ (or $T_v$) and other transactions are also changed. Financial profits of the attack or victim could be affected by such relative orders. As a result, the financial profits in the attack-free scenario could be incorrectly calculated, and false-positively reported attacks may be induced, but our manual check shows that such cases are rare.
]

Nonetheless, it is not clear, which of the above scenarios they applied for their analysis. The other work, @torres_frontrunner_2021, does not mention this issue at all.

==== Code analysis of @zhang_combatting_2023

As shown in their algorithm 1, they take as input all the executed transactions. They use these transactions and their results in the `searchVictimGivenAttack` method, where `ar` represents the attack transaction and result and `vr` represents the victim transaction and result.

For the normal execution order ($T_a arrow.r T_v$), they simply use `ar` and `vr` and pass them to their `CheckOracle` method which then compares the resulting states. As `ar` and `vr` are obtained by executing all transactions, they also include the intermediary transactions for these results (similar to our $sigma arrow.r^(T_A) sigma_A arrow.r^(T_X) sigma_(A X) arrow.r^(T_B) sigma_(A X B)$ case).

For the reverse order ($T_v arrow.r T_a$), they take the state before $T_a$, i.e. $sigma$. Then they execute all transactions obtained from the `SlicePrerequisites` method. And finally they execute $T_v$ and $T_a$.

The `SlicePrerequisites` method uses the `hbGraph` built in `StartSession`, which seems to be a graph where each transaction points to the previous transaction from the same EOA. From this graph, it takes all transactions between $T_a$ and $T_v$, that are from the same sender as $T_v$. This interpretation matches the test case \"should slide prerequisites correctly\" from the source code. As the paper does not mention these prerequisite transactions, we do not know why this subset of intermediary transactions was chosen.

We can conclude, that @zhang_combatting_2023 executes all intermediary transactions for the normal order. However, for the reverse order, they only execute intermediary transactions that are also sent by the victim, but do not execute any other intermediary transactions.

==== Code analysis of @torres_frontrunner_2021

In the file `displacement.py`, they replay the normal execution order at the lines 154-155, and the reverse execution order at the lines 158-159. They only execute $T_A$ and $T_V$ (in normal and reverse order), but do not execute any intermediate transactions.

=== Block environments
When we analyze a pair of transactions $(T_A , T_B)$, it can be, that these are not part of the same block. The execution of these transactions can depend on the block environment they are executed in, for instance if they access the current block number. Thus, executing $T_A$ or $T_B$ in a different block environment than on the blockchain may alter their behaviour. From our intuitive TOD definition, it is not clear which block environment(s) we use when replaying the transactions in normal and reverse order.

==== Code analysis of @zhang_combatting_2023

The block environment used to execute all transactions is contained in `ar.VmContext` and as such corresponds to the block environment of $T_a$. This means $T_a$ is executed in the same block environment as on the blockchain, while $T_v$ and the intermediary transactions may be executed in a different block environment.

==== Code analysis of @torres_frontrunner_2021

In the file `displacement.py` line 151, we see that the emulator uses the same block environment for both transactions. Therefore, at least one of them will be executed in a different block environment than on the blockchain.

=== Initial state $sigma$
While our preliminary TOD definition specifies that we start with the same $sigma$ in both execution orders, it is up to interpretation which world state $sigma$ is.

==== Code analysis of @zhang_combatting_2023

The initial state used to execute the first transaction is `ar.State`, which corresponds to the state directly before executing $T_a$. This includes all previous transactions of the same block.

==== Code analysis of @torres_frontrunner_2021

The emulator is initialized with the block `front_runner["blockNumber"]-1` and no single transactions are executed prior to running the analysis. Therefore, the state cannot include transactions that were executed in the same block before $T_A$.

Similar to the case with the block environment, this could lead to differences between the emulation and the results from the blockchain, when $T_A$ or $T_V$ are impacted by a previous transaction in the same block.

== TOD definition <sec:tod-definition>

To address the issues above, we will provide a more precise definition for TOD, that tries to be as close to the execution that happened on the blockchain, while also minimizing the impact of intermediary transactions on the analysis results.

#definition("TOD")[
  Consider a sequence of transactions, with $sigma$ being the world state right before $T_A$ was executed on the blockchain:

  $ sigma arrow.r^(T_A) sigma_A arrow.r^(T_(X_1)) dots.h arrow.r^(T_(X_n)) sigma_(X_n) arrow.r^(T_B) sigma_B $

  Let $Delta_(T_A)$ and $Delta_(T_B)$ be the corresponding state changes from executing $T_A$ and $T_B$, and let all transactions be executed in the same block environment as they were executed on the blockchain.

  We say, that $(T_A , T_B)$ is TOD if and only if executing $(sigma_(X_n) - Delta_(T_A)) arrow.r^(T_B) sigma_B prime$ produces a state change $Delta_(T_B prime)$ with $Delta_(T_B) != Delta_(T_B prime)$.
]

Intuitively, we take the world state exactly before $T_B$ was executed, namely $sigma_(X_n)$. We then record the state changes $Delta_(T_B)$ from executing $T_B$ directly on $sigma_(X_n)$, the same way it was executed on the blockchain. Then we simulate what would have happened if $T_A$ was not executed before $T_B$ by removing its state changes and executing $T_B$ on $sigma_(X_n) - Delta_(T_A)$. If we observe different state changes for $T_B$ when executed with and without the changes of $T_A$, then we know that $T_A$ has an impact on $T_B$ and conclude TOD between $T_A$ and $T_B$. If there are no differences between $Delta_(T_B)$ and $Delta_(T_B prime)$, then $T_B$ behaves the same regardless of $T_A$ and there is no TOD.

We chose to compare the two executions on the state changes $Delta_(T_B) != Delta_(T_B prime)$, rather than on the resulting states $sigma_B != sigma_B prime$, to detect a wider range of TODs. Comparing on $sigma_B != sigma_B prime$ would be sufficient to detect #emph[write-read] TODs, where the first transaction writes some state and the second transaction accesses this state and outputs a different result because of this. However, we are also interested in #emph[write-write] TODs, where $T_A$ writes some state and $T_B$ overwrites the same state with a different value, thus hiding the change by $T_A$.

For example, let $T_A$ write the value '1111' to some storage, s.t. we have $sigma_(X_n) (a)_s [k] = "'1111'"$, and $T_B$ write '2222' to the same storage, s.t. we have $sigma_B (a)_s [k] = "'2222'"$. When executing $T_B$ last, the world state would have '2222' at this storage slot, and when executing $T_A$ last, it would be '1111'. Therefore, the resulting world state is dependent on the order of $T_A$ and $T_B$. With our check of $Delta_T_B != Delta_(T_B prime)$ we include this scenario, because $Delta_T_B$ has a relative state change of $(2222 - 1111)$ for this storage slot, while $Delta_(T_B prime)$ has a relative state change of $(2222 - 0000)$, assuming it was '0000' before executing $T_A$.

Our definition does not include #emph[read-write] TODs, i.e. we do not check whether executing $T_B$ before $T_A$ would have an impact on $T_A$. We focus on detecting TOD attacks, in which the attacker tries to insert a transaction prior to some transaction $T$ and impact the behaviour of $T$ with this. Therefore, we assume that the first transaction tries to impact the second transaction, and ignore the other way round.

=== Definition strengths <sec:definition-strengths>

==== Performance

To check if two transactions $T_A$ and $T_B$ are TOD, we need the initial world state $sigma$ and the state changes from $T_A$, $T_B$ and the intermediary transactions $T_(X_n)$. With the state changes we can compute $sigma_(X_n) - Delta_(T_A) = sigma + Delta_(T_A) + (sum_(i = 0)^(i = n) Delta_(T_(X_i))) - Delta_(T_A)$ and then execute $T_B$ on this state. Using state changes allows us to check if $T_A$ and $T_B$ are TOD with only one transaction execution, despite including the effects of arbitrary many intermediary transactions.

If we want to check n transactions for TOD, we could execute all n transactions to obtain their state changes. There are $frac(n^2 - n, 2)$ transaction pairs, thus if we wanted to test each pair for TOD we would end up with a total of $n + frac(n^2 - n, 2) = frac(n^2 + n, 2)$ transaction executions. Similar to @torres_frontrunner_2021 and @zhang_combatting_2023, we can filter irrelevant transactions pairs to drastically reduce the search space.

==== Similarity to blockchain executions

With our definition, the state change $Delta_(T_B)$ from the normal execution is equivalent to the state change that happened on the blockchain. Also, the reversed order is closely related to the state from the blockchain, as we start with $sigma_(X_n)$ and only modify the relevant parts for our analysis. Furthermore, we prevent effects from block environment changes by using the same one as on the blockchain.

This contrasts other implementations, where transactions are executed in different block environments than originally, are executed based on a different starting state or ignore the impact of intermediary transactions. All three cases can alter the execution of $T_A$ and $T_B$, such that the result is not closely related to the blockchain anymore.

=== Definition weaknesses
<sec:weaknesses>

#change[Added focus on impact on $T_B$ section]

==== Focus on impact on $T_B$ <sec:weakness-focus-on-tb>

In some cases, the transaction order can impact the execution of the individual transactions, but does not affect the overall result of executing both transactions. Our definition does not consider the execution of $T_A$ after $T_B$ in the reverse order, which could lead to incorrect TOD classification.

For example, consider the case where both $T_A$ and $T_B$ multiply a value in a storage slot by 5. If the storage slot initially has the value 1, then executing both $T_A$ and $T_B$ will result in 25, regardless of the order. However, the state changes $Delta_T_B$ and $Delta_(T_B prime)$ are different, as for one scenario the value changes from 1 to 5 and for the other from 5 to 25. Therefore, this would be classified as TOD by our definition.

Note, that our definition is robust against the cases, where the absolute values differ, but the change is constant. For instance, if both $T_A$ and $T_B$ would increase the storage slot by 5 rather than multiplying it, the state changes $Delta_T_B$ and $Delta_(T_B prime)$ would be from 1 to 6 and from 6 to 11. As our definition for state changes equality uses the difference between the state before and after execution, we would compare the change $6 - 1 = 5$ against $11 - 6 = 5$, thus considering $Delta_T_B = Delta_(T_B prime)$.

==== Indirect dependencies

#change[Rephrasing of this paragraph]

An intuitive interpretation of our definition would be, that we compare $T_A arrow.r T_(X_i) arrow.r T_B$ with $T_(X_i) arrow.r T_B$, i.e. reckon what would have happened if $T_A$ was not executed. However, the definition we provide does not perfectly match this concept, because it does not consider interactions between $T_A$ and the intermediary transactions $T_(X_i)$. In the intuitive model, removal of $T_A$ could also impact the intermediary transactions and thus indirectly change the behaviour of $T_B$. Then we would not know if $T_A$ directly impacted $T_B$, or only through some interplay with intermediary transactions. Therefore, our exclusion of interactions between $T_A$ and $T_(X_i)$ may be desirable, however it can lead to unexpected results if one is not aware of this.

As an example, consider the three transactions $T_A$, $T_X$ and $T_B$:

+ $T_A$: sender $a$ transfers 5 Ether to address $x$.
+ $T_X$: sender $x$ transfers 5 Ether to address $b$.
+ $T_B$: sender $b$ transfers 5 Ether to address $y$.

When executing these transactions in the normal order, and $a$ initially has 5 Ether and the others have 0, then all of these transactions would succeed. If we remove $T_A$ and only execute $T_X$ and $T_B$, then firstly $T_X$ would fail, as $x$ did not get the 5 Ether from $a$, and consequently also $T_B$ fails.

However, when using our TOD definition and computing $(sigma_(X_n) - Delta_(T_A))$, we would only modify the balances for $a$ and $x$, but not for $b$, because $b$ is not modified in $Delta_(T_A)$. Thus, $T_B$ would still succeed in the reverse order according to our definition, but would fail in practice due to the indirect effect. This shows, how the concept of removing $T_A$ does not map exactly to our TOD definition.

In this example, we had a TOD for $(T_A , T_X)$ and $(T_X , T_B)$. However, we can also have an indirect dependency between $T_A$ and $T_B$ without a TOD for $(T_X , T_B)$. For instance, if $T_X$ and $T_B$ would be TOD, but $T_A$ caused $T_X$ to fail. When inspecting the normal order, $T_X$ failed, so there is no TOD between $T_X$ and $T_B$. However, when executing the reverse order without $T_A$, then $T_X$ would succeed and could impact $T_B$.

== State collisions
We denote state accesses by a transaction $T$ as a set of state keys $R_T = { K_1 , dots.h , K_n }$ and state modifications as $W_T = { K_1 , dots.h , K_m }$.

We define the state collisions of two transactions as:

$ colls(T_A , T_B) = (W_(T_A) sect R_(T_B)) union (W_(T_A) sect W_(T_B)) $

For instance, if transaction $T_A$ modifies the balance of some address $a$, and $T_B$ accesses this balance, we have $colls(T_A, T_B) = ({ ('"balance"', a) } sect {('"balance"', a)}) union ({('"balance"', a)} sect emptyset) = {('"balance"', a)}$.

With $W_(T_A) sect R_(T_B)$ we include write-read collisions, where $T_A$ modifies some state and $T_B$ accesses the same state. With $W_(T_A) sect W_(T_B)$ we include write-write collisions, where both transactions write to the same state location, for instance to the same storage slot. We do not include $R_(T_A) sect W_(T_B)$, as we also did not include read-write TOD in our TOD definition.

== TOD candidates
We will refer to a transaction pair $(T_A , T_B)$, where $T_A$ was executed before $T_B$ and $colls(T_A , T_B) != nothing$ as a TOD candidate.

A TOD candidate is not necessarily TOD, for instance consider the case that $T_B$ only reads the value that $T_A$ wrote but never uses it for any computation. This would be a TOD candidate, as they have a collision, however the result of executing $T_B$ is not impacted by this collision.

Conversely, if $(T_A , T_B)$ is TOD, then $(T_A , T_B)$ must also a TOD candidate. For a write-write TOD, this is the case, because both $T_A$ and $T_B$ write to the same state, therefore we have $W_(T_A) sect W_(T_B) != nothing$. If we have a write-read TOD, then $T_B$ reads some state that $T_A$ wrote, hence $W_(T_A) sect R_(T_B) != nothing$.

Therefore, the set of all TOD transaction pairs is a subset of all TOD candidates.

== Causes of state collisions
This section discusses, what can cause two transactions $T_A$ and $T_B$ to have state collisions. To do so, we show the ways a transaction can access and modify the world state.

=== Causes with code execution
When the recipient of a transaction is a contract account, it will execute the recipient’s code. The code execution can access and modify the state through several instructions. By inspecting the EVM instruction definitions @wood_ethereum_2024[p.30-38]@smlxl_evm_2024, we compiled a list of instructions that can access and modify the world state.

In @tab:state_reading_instructions we see the instructions, that can access the world state. For most, the reason of the access is clear, for instance `BALANCE` needs to access the balance of the target address. Less obvious is the nonce access of several instructions, which is because the EVM uses the nonce (among other things) to check if an account already exists@wood_ethereum_2024[p.4]. For `CALL`, `CALLCODE` and `SELFDESTRUCT`, this is used to calculate the gas costs. @wood_ethereum_2024[p.37-38] For `CREATE` and `CREATE2`, this is used to prevent creating an account at an already active address @wood_ethereum_2024[p.11]#footnote[In the Yellowpaper, the check for the existence of the recipient for `CALL`, `CALLCODE` and `SELFDESTRUCT` is done via the `DEAD` function. For `CREATE` and `CREATE2`, this is done in the `F` condition at equation (113).].

In @tab:state_writing_instructions we see instructions that can modify the world state.

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
Some state accesses and modifications are inherent to transaction execution. To pay for the transaction fees, the balance of the sender is accessed and modified. When a transaction transfers some Wei from the sender to the recipient, it also modifies the recipient’s balance. To check if the recipient is a contract account, the transaction also needs to access the code of the recipient. And finally, it also verifies the sender’s nonce and increments it by one. @wood_ethereum_2024[p.9]

=== Relevant collisions for attacks
<sec:relevant-collisions>

The previous sections list possible ways to access and modify the world state. Many previous works have focused on storage and balance collisions, however they did not discuss if or why code and nonce collisions are not important. @wang_etherfuzz_2022@kolluri_exploiting_2019@li_finding_2019@luu_making_2016@tsankov_securify_2018@munir_todler_2023 Here, we try to argue, why only storage and balance collisions are relevant for TOD attacks and code and nonce collisions can be neglected.

The idea of an TOD attack is, that an attacker impacts the execution of some transaction $T_B$, by placing a transaction $T_A$ before it. To have some impact, there must be a write-write or write-read collisions between $T_A$ and $T_B$. Therefore, our scenario is that we start from some (vicim) transaction $T_B$ and try to create impactful collisions with a new transaction $T_A$. We assume some set $A$ to be the set of codes and nonces that $T_B$ accesses and writes.

#change[Updated following 2 paragraphs to hopefully be easier to follow]

Let us first focus on the instructions, that could modify the accessed codes and nonces in $A$, namely `SELFDESTRUCT`, `CREATE` and `CREATE2`. Since the EIP-6780 update@ballet_eip-6780_2023, `SELFDESTRUCT` only destroys a contract if the contract was created in the same transaction. Therefore, `SELFDESTRUCT` can only modify a code and nonce within the same transaction, but cannot be used to attack an already submitted transaction $T_B$. The instructions to create a new contract, `CREATE` and `CREATE2`, both fail when there is already a contract at the target address. @wood_ethereum_2024[p.11] Therefore, we can only modify the code if the contract previously did not exist. In the case, that $T_B$ interacted with some address $a$ that contains no code, the attacker would need `CREATE` or `CREATE2` to create a contract at the address $a$ to have a collision. This is not possible for arbitrary addresses, as the address computation uses the sender's address as an input to a hash function in both cases.@wood_ethereum_2024[p.11] A similar argument can be made about contract creation directly via the transaction and some init code.

Apart from instructions, the nonces of an EOA can also be increased by transactions themselves. $T_B$ could make a `CALL` or `CALLCODE` to the address of an EOA and transfer some Ether. The gas costs for these instructions depends on whether the recipient account already exists or has to be newly created. As such, if $T_B$ makes a `CALL` or `CALLCODE` to a non-existent account, then an attacker could create this account in $T_A$ to reduce the gas costs of the transfer by $T_B$. We do not consider this an attack, as it only reduces the gas costs by $T_B$ which likely has no adverse affects.

Therefore, the remaining attack vectors are `SSTORE`, to modify the storage of an account, and `CALL`, `CALLCODE`, `SELFDESTRUCT` and Ether transfer transactions, to modify the balance of an account.

== Everything is TOD
Our definition of TOD is very broad and marks many transaction pairs as TOD. For instance, if a transaction $T_B$ uses some storage value for a calculation, then the execution likely depends on the transaction that previously has set this storage value. Similarly, when someone wants to transfer Ether, they can only do so when they first received that Ether. Thus, they are dependent on some transaction that gave them this Ether previously.

#theorem[For every transaction $T_B$ after the London upgrade#footnote[We reference the London upgrade here, as this introduced the base fee for transactions.], there exists a transaction $T_A$ such that $(T_A , T_B)$ is TOD.]
#proof[
  Consider an arbitrary transaction $T_B$ with the sender being some address $italic("sender")$. The sender must pay some upfront cost $v_0 > 0$, because they must pay a base fee. @wood_ethereum_2024[p.8-9]. Therefore, we must have $sigma(italic("sender"))_b gt.eq v_0$. This requires, that a previous transaction $T_A$ increased the balance of $italic("sender")$ to be high enough to pay the upfront cost, i.e. $pre(Delta_(T_A)) (italic("sender"))_b < v_0$ and $post(Delta_(T_A)) (italic("sender"))_b gt.eq v_0$.#footnote[For block validators, their balance could have also increased from staking rewards, rather than a previous transaction. However, this would require that a previous transaction gave them enough Ether for staking in the first place. @noauthor_proof--stake_nodate]

  When we calculate $sigma - Delta_(T_A)$ for our TOD definition, we would set the balance of $italic("sender")$ to $pre(Delta_(T_A)) (italic("sender"))_b < v_0$ and then execute $T_B$ based on this state. In this case, $T_B$ would be invalid, as the $italic("sender")$ would not have enough Ether to cover the upfront cost.
]

#todo[Reference frontrunning section]
Given this property, it is clear that TOD alone is not a useful attack indicator, else we would say that every transaction has been attacked. In the following, we provide some more restrictive definitions.

= TOD candidate mining <cha:mining>
In this chapter, we discuss how we search for potential TODs in the Ethereum blockchain. We use the RPC from an archive node to obtain transactions and their state accesses and modifications. Then we search for collisions between these transactions to find TOD candidates. Lastly, we filter out TOD candidates, that are not relevant to our analysis.

== TOD candidate finding
We make use of the RPC method `debug_traceBlockByNumber`, which allows replaying all transactions of a block the same way they were originally executed. With the `prestateTracer` config, this method also outputs, which state has been accessed, and using the `diffMode` config, also which state has been modified#footnote[When running the prestateTracer in diffMode, several fields are only implicit in the response. We need to make these fields explicit for further analysis. Refer to the documentation or the source code for further details.].

By inspecting the source code from the tracers for Reth@paradigm_revm-inspectors_2024 and results from the RPC call, we found out, that for every touched account it always includes the account’s balance, nonce and code in the prestate. For instance, even when only the balance was accessed, it will also include the nonce in the prestate#footnote[I opened a #link("https://github.com/ethereum/go-ethereum/pull/30081")[pull request] to clarify this behaviour and now this is also reflected in the documentation@noauthor_go-ethereum_2024-1.]. Therefore, we do not know precisely which state has been accessed, which can be a source of false positives for collisions.

We store all the accesses and modifications in a database and then query for accesses and writes that have the same state key, giving us a list of collisions. We then use these collisions to obtain a preliminary set of TOD candidates.

== TOD candidate filtering
Many of the TOD candidates from the previous section are not relevant for our further analysis. To prevent unnecessary computation and distortion of our results, we define which TOD candidates are not relevant and then filter them out.

A summary of the filters is given in @tab:tod_candidate_filters and more detailed explanations are in the following sections. The filters are executed in the same order as they are presented in the table and always operate on the output from the previous filter. The only exception is the "Same-value collision" filter, which is directly incorporated into the initial collisions query for performance reasons.

The "Block windows", "Same senders" and "Recipient Ether transfer" filters have already been used in @zhang_erebus-redgiant_2023. The filters "Nonce and code collision" and "Indirect dependency" followed directly from our previous theoretical arguments. Further, we also applied an iterative approach, where we searched for TOD candidates in a sample block range and manually analyzed if some of these TOD candidates could be filtered. This led us to the "Same-value collisions" and the "Block validators" filter.

#figure(
  table(
    columns: 2,
    align: (left, left),
    table.header([Filter name], [Description of filter criteria]),
    table.hline(),
    [Same-value collision], [Only take collisions where $T_A$ writes exactly the value, that is read or overwritten by TB.],
    [Block windows], [Drop transactions that are 25 or more blocks apart.],
    [Block validators], [Drop collisions on the block validator’s balance.],
    [Nonce and code collision], [Drop nonce and code collisions.],
    [Indirect dependency], [Drop TOD candidates with an indirect dependency. e.g. if TOD candidates $(T_A , T_X )$ and $(T_X , T_B)$ exist.],
    [Same senders], [Drop if $T_A$ and $T_B$ are from the same sender.],
    [Recipient Ether transfer], [Drop if $T_B$ does not execute code.],
  ),
  caption: flex-caption(
    [TOD candidate filters sorted by usage order. When a filter describes the removal of collisions, the TOD candidates will be updated accordingly.],
    [TOD candidate filters],
  ),
  kind: table,
) <tab:tod_candidate_filters>

=== Filters

==== Same-value collisions
When we have many transactions that modify the same state, e.g. the balance of the same account, they will all have a write-write conflict with each other. The number of TOD candidates grows quadratic with the number of transactions modifying the same state. For instance, if 100 transactions modify the balance of address $a$, the first transaction would have a write-write conflict with all other 99 transactions, the second transaction with the remaining 98 transactions, etc., leading to a total of $frac(n^2 - n, 2) = 4950$ TOD candidates.

To reduce this growth of TOD candidates, we also require for a collision, that $T_A$ writes exactly the value that is read or overwritten by $T_B$. Formally, following must hold to pass this filter:

$
  forall K in colls(T_A , T_B) :
  post(Delta_(T_A)) (K) = pre(Delta_(T_B)) (K)
$

With the example of 100 transactions modifying the balance of address $a$, when the first transaction sets to balance to 1234, it would only have a write-write conflict with transactions where the balance of $a$ was exactly 1234 before the execution. If all transactions wrote different balances, this would reduce the amount of TOD candidates to $n - 1 = 99$.

Apart from the performance benefit, this filter also removes many TOD candidates that are potentially indirect dependent. For instance, let us assume that we removed the TOD candidate $(T_A , T_B)$. By definition of this filter, there must be some key $K$ with $post(Delta_(T_A)) (K) != pre(Delta_(T_B)) (K)$, thus some transaction $T_X$ must have modified the state at $K$ between $T_A$ and $T_B$. Therefore, we would also have a collision (and TOD candidate) between $T_A$ and $T_X$, and between $T_X$ and $T_B$. This would be a potential indirect dependency, which could lead to unexpected results as argued in @sec:weaknesses.

==== Block windows

According to a study of 24 million transactions from 2019 @zhang_evaluation_2021, the maximum observed time it took for a pending transaction to be included in a block, was below 200 seconds. Therefore, when a transaction $T_B$ is submitted, and someone instantly attacks it by creating a new transaction $T_A$, the inclusion of them in the blockchain differs by at most 200 seconds. We currently add a new block to the blockchain every 12 seconds according to Etherscan @etherscan_ethereum_2024, thus $T_A$ and $T_B$ are at most $200 / 12 approx 17$ blocks apart from each other. As the study is already 5 years old, we use a block window of 25 blocks instead, to account for a potential increase in latency since then.

Thus, we filter out all TOD candidates, where $T_A$ is in a block that is 25 or more blocks away from the block of $T_B$.

==== Block validators

In Ethereum, each transaction must pay a transaction fee to the block validator and thus modifies the block validator’s balance. This would qualify each transaction pair in a block as a TOD candidate, as they all modify the balance of the block validator’s address.

We exclude TOD candidates, where the only collision is the balance of any block validator.

==== Nonce and code collisions

We showed in @sec:relevant-collisions, that nonce and code collisions are not relevant for TOD attacks. Therefore, we ignore collisions for this state type.

==== Indirect dependency

As argued in @sec:weaknesses, indirect dependencies can cause unexpected results in our analysis, therefore we will filter TOD candidates that have an indirect dependency. We will only consider the case, where the indirect dependency is already visible in the normal order and accept that we potentially miss some indirect dependencies. Alternatively, we could also remove a TOD candidate $(T_A , T_B)$ when we also have the TOD candidate $(T_A , T_X)$, however this would remove many more TOD candidates.

We already have a model of all direct (potential) dependencies with the TOD candidates. We can build a transaction dependency graph $G = (V , E)$ with $V$ being all transactions and $E = { (T_A , T_B) divides (T_A , T_B) in "TOD candidates" }$. We then filter out all TOD candidates $(T_A , T_B)$ where there exists a path $T_A , T_(X_1) , dots.h , T_(X_n) , T_B$ with at least one intermediary node $T_(X_i)$.

@fig:tod_candidate_dependency shows an example dependency graph, where transaction $A$ influences both $X$ and $B$ and $B$ is influenced by all other transactions. We would filter out the candidate $(A , B)$ as there is a path $A arrow.r X arrow.r B$, but keep $(X , B)$ and $(C , B)$.

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

If the sender of both transactions is the same, the victim would have attacked themselves.

To remove these TOD candidates, we use the `eth_getBlockByNumber` RPC method and compare the sender fields for $T_A$ and $T_B$.

==== Recipient Ether transfer

If a transaction sends Ether without executing code, it only depends on the balance of the EOA that signed the transaction. Other entities can only increase the balance of this EOA, which has no adverse effects on the transaction.

Thus, we can exclude TOD candidates, where $T_B$ has no code access.

== Experiment
In this section, we discuss the results of applying the TOD candidate mining methodology on a randomly sampled sequence of 100 blocks, different to the block range we used for the development of the filters. Refer to @cha:reproducibility for the experiment setup and the reproducible sampling.

We mined the blocks from block 19830547 up to block 19830647, containing a total of 16799 transactions.

=== Performance
The mining process took a total of 502 seconds, with 311 seconds being used to fetch the data via RPC calls and store it in the database, 6 seconds being used to query the collisions in the database, 17 seconds for filtering the TOD candidates and 168 seconds for preparing statistics. If we consider the running time as the total time excluding the statistics preparation, we analyzed an average of 0.30 blocks per second.

We can also see that 93% of the running time was spent fetching the data via the RPC calls and storing it locally. This could be parallelized to significantly speed up the process.

=== Filters
In @tab:experiment_filters we can see the number of TOD candidates before and after each filter, showing how many candidates were filtered at each stage. This shows the importance of filtering, as we reduced the number of TOD candidates to analyze from more than 60 millions to only 8,127.

Note, that this does not directly imply, that "Same-value collision" filters out more TOD candidates than "Block windows", as they operated on different sets of TOD candidates. Even if "Block windows" would filter out every TOD candidate, this would be less than "Same-value collision" did, because of the order of filter application.

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
    [This table shows the application of all filters used to reduce the number of TOD candidates. Filters were applied from top to bottom and each row shows how many TOD candidates remained and were filtered. The unfiltered value is a lower bound, as we only calculated this number afterwards, and the calculation does not include write-write collisions.],
    [TOD candidate filters evaluation],
  ),
  kind: table,
)
<tab:experiment_filters>

=== Transactions
After applying the filters, 7864 transactions are part of at least one TOD candidate. This is, 46.8% of all transactions, that we mark as potentially TOD with some other transaction. Only 2381 of these transactions are part of exactly one TOD candidate. On the other end, there exists one transaction that is part of 22 TOD candidates.

=== Block distance
In @fig:tod_block_dist we can see, that most TOD candidates are within the same block. Moreover, the further two transactions are apart, the less likely we include them as a TOD candidate. A reason for this could be, that having many intermediary transactions makes it more likely to be filtered by our "Indirect dependency" filter. Nonetheless, we can conclude that when using our filters, the block window could be reduced even further without missing many TOD candidates.

#figure(
  image("charts/tod_candidates_block_dist.png", width: 80%),
  caption: flex-caption(
    [
      The histogram and eCDF of the block distance for TOD candidates. The blue bars show how many TOD candidates have been found, where $T_A$ and $T_B$ are n blocks apart. The orange line shows the percentage of TOD candidates, that are at most n blocks apart.
    ],
    [Block distances of TOD candidates],
  ),
)
<fig:tod_block_dist>

=== Collisions
After applying our filters, we have 8818 storage collisions and 5654 balance collisions remaining. When we analyze, how often each account is part of a collision, we see that collisions are highly concentrated around a small set of accounts. For instance, the five accounts with the most collisions#footnote[All of them are token accounts:
#link("https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")[WETH],
#link("https://etherscan.io/address/0x97a9a15168c22b3c137e6381037e1499c8ad0978")[DOP],
#link("https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7")[USDT],
#link("https://etherscan.io/address/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")[USDC]
and
#link("https://etherscan.io/address/0xf938346d7117534222b48d09325a6b8162b3a9e7")[CHOPPY]]
are responsible for 43.0% of all collisions. In total, the collisions occur in only 1472 different account states.

@fig:collisions_address_limit depicts, how many collisions we would get when we only consider the first $n$ collisions for each address. If we set the limit to one collision per address, we would end up with 1472 collisions, which is exactly the number of unique addresses where collisions happened. When we keep 10 collisions per address, we would get 3964 collisions. Such a scenario would already reduce the amount of collisions by 73%, while still retaining a sample of 10 collisions for each address, that could cover different types of TOD attacks.

One goal of this paper is to create a diverse set of attacks for our benchmark. With such a strong imbalance towards a few contracts, it will take a long time to analyze TOD candidates related to these frequent addresses, and the attacks are more likely related and do not cover a wide range of attack types. To prevent this, in @sec:deduplication we define additional deduplication filters.

#figure(
  image("charts/collisions_limited_per_address.png", width: 80%),
  caption: flex-caption(
    [
      The chart shows, how many collisions we have, when we limit the number of collisions we include per address. For instance, if we only include 10 collisions for each address we would end up with about 4000 collisions.
    ],
    [Limit for collisions per address],
  ),
)
<fig:collisions_address_limit>

== Deduplication <sec:deduplication>

#change[Added deduplication section]

To reduce the prevalence of specific contracts in the TOD candidates, we randomly pick 10 collisions of each contract and drop the rest from our analysis. We apply three different mechanisms to group similar contracts:

Firstly, we group the collisions by the address where they happened, and randomly select 10 collisions from each group. For instance, if many transactions access the balance and code of the same address, we would only retain 10 of these accesses.

Secondly, we also group collisions at different addresses if the addresses share exactly the same code. To do so, we group the collisions by the code hash and sample 10 collisions per code hash.

Finally, instead of matching for exactly the same code, we also group similar codes together. We use the grouping mechanism from @diangelo_evolution_2024, where they compute a "skeleton" for each code by removing the metadata and the values for `PUSH` instructions. They have shown, that codes with the same skeleton mostly yield the same vulnerability detection results. Therefore, we only keep 10 collisions per code skeleton.

=== Results

We ran the same experiment as in the previous section, but now with the additional deduplication filters. In @tab:experiment_deduplication, we see that from the initial 8,127 TOD candidates, only 2,320 remained after removing duplicates. Most of the TOD candidates were already removed by limiting the amount of collisions per address and the other group limits reduced it further.

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

= TOD detection

#change[Added TOD detection section + corresponding appendix]

After mining a list of TOD candidates, we now check, which of them are actually TOD.

== Overview

For the normal scenario $T_A -> T_B$, we execute the transactions as they were executed on the blockchain, and record the state changes $Delta_T_A$ and $Delta_T_B$. For the reverse scenario $T_B -> T_A$, we execute $T_B$ as if $T_A$ has not been executed and record the state changes $Delta_(T_B prime)$. Then, according to our definition, the transactions are TOD if and only if $Delta_T_B != Delta_(T_B prime)$.

In order to evaluate the weakness explained in @sec:weakness-focus-on-tb, we also present an adapted TOD definition and analyze where the results of these definitions differ.

== Transaction execution via RPC

Let $(T_A, T_B)$ be our TOD candidate and split the block containing $T_B$ into following three sections:

$ sigma ->^(T_X_0) dots ->^(T_X_n) sigma_X_n ->^(T_B) sigma_T_B ->^(T_Y_0) dots ->^(T_Y_m) sigma_B $

In the normal scenario, we want to execute $T_B$ on $sigma_X_n$ and in the reverse scenario on $sigma_X_n - Delta_T_A$. We use the `debug_traceCall` RPC method for these transaction executions. As parameters, it takes the transaction data, a block number that specifies the block environment and the initial world state, and state overrides, that allow us to customize specify parts of the world state. Per default, the method uses the world state #emph[after] executing all transactions in this block, i.e. $sigma_B$. Therefore, we use the state overrides parameter to get from $sigma_B$ to $sigma_X_n$ and $sigma_X_n - Delta_T_A$.

For the normal scenario, we want to execute $T_B$ on $sigma_X_n$. Conceptually, we start from $sigma_B$ and then undo all transaction changes after $T_X_n$ in reverse order, to reach $sigma_X_n$. We do this with the state overrides $sum_(i=m)^0(-Delta_T_Y_i) - Delta_T_B$. For the reverse scenario, we also subtract $Delta_T_A$ from the state overrides, thus simulating how $T_B$ behaves without the changes from $T_A$.

== Execution inaccuracy <sec:execution-accuracy>

While manually testing this method, we found that using `debug_traceCall` with state overrides can lead to incorrect gas cost calculations with Erigon#footnote[See https://github.com/erigontech/erigon/issues/11254.]. To account for these inaccuracies, we compare the state changes from the normal execution via `debug_traceCall` with the state changes from `debug_traceBlockByNumber`. As we do not provide state overrides to `debug_traceBlockByNumber`, this method should yield the correct state changes and we can detect differences to our simulation.

When comparing the state changes of a transaction, and they only differ in the balances of the sender and the block validator, we keep it as a TOD candidate. Such differences are expected when gas costs vary, as the gas costs impact the priority fee sent from the transaction sender to the block validator. If there are other differences, we exclude the TOD candidate from our further analysis, as the simulation does not reflect the real behaviour in such cases.

== TOD assessment

=== Original definition

Recalling our TOD definition from @sec:tod-definition, we say that $(T_A , T_B)$ is TOD if and only if executing $(sigma_(X_n) - Delta_(T_A)) arrow.r^(T_B) sigma_B prime$ produces a state change $Delta_(T_B prime)$ with $Delta_(T_B) != Delta_(T_B prime)$. In other words, we compare the state changes by $T_B$ in the normal scenario with the state changes in the reverse scenario.

=== Adapted definition

We want to evaluate, how much impact the weakness described in @sec:weakness-focus-on-tb has in practice. The weakness is, that we only compare the state changes of $T_B$ in both scenarios. Therefore, in the adapted definition we compare the state changes of both $T_A$ and $T_B$ in the normal scenario against the state changes of $T_A$ and $T_B$ in the reverse scenario.

To get the state changes of $T_A$ in the reverse scenario, we execute $T_A$ on $sigma + Delta_(T_B prime)$, simulating $T_A$ after $T_B$.

=== State changes comparison

@alg:tod-assessment shows how we check for TOD given the state changes. The black lines show the calculation for the original definition and the blue lines the modifications for the adapted definition. For each state key, we compute the change for this key in the normal scenario ($d_1$), and the change in the reverse scenario ($d_2$). If the changes differ between the scenarios, we have a TOD.

#figure(
  kind: "algorithm",
  caption: flex-caption(
    [TOD assessment],
    [TOD assessment],
  ),
  pseudocode-list(hooks: 0.5em)[
    + *for* $K in changedKeys(Delta_T_B) union changedKeys(Delta_(T_B prime))$
    + #hide[*for* $K$] #text(fill: blue)[$union changedKeys(Delta_T_A) union changedKeys(Delta_(T_A prime))$]
      + $d_1 = post(Delta_T_B)(K) - pre(Delta_T_B)(K)$
      + $d_2 = post(Delta_(T_B prime))(K) - pre(Delta_(T_B prime))(K)$
      + #text(fill: blue)[$d_1 = d_1 + post(Delta_T_A)(K) - pre(Delta_T_A)(K)$]
      + #text(fill: blue)[$d_2 = d_2 + post(Delta_(T_A prime))(K) - pre(Delta_(T_A prime))(K)$]
      + *if* $d_1 != d_2$
        + *return* \<TOD\>
    + *return* \<not TOD\>
  ],
) <alg:tod-assessment>

== Experiment

We go through all 2,320 TOD candidates we found previously and check them for the original and the adapted TOD definitions.

=== Results

In @tab:experiment_check_definition we see the results for both definitions. From the 2,320 TOD candidates we analyzed, slightly more than one third are TOD according to both definitions. For the original definition, 19 TOD candidates could not be analyzed because of execution inaccuracies. For the adapted definition, this number is higher, as we need to execute double the amount of transactions.

With both definitions, for 29% of the TOD candidates, $T_B$ fails because of insufficient funds to cover the transaction fee when it is executed without the state changes by $T_A$. This can happen when $T_A$ transfers Ether to the sender of $T_B$, and $T_B$ has less balance than the transaction fee without this transfer. Furthermore, if the execution of $T_B$ consumes more gas without the changes of $T_A$, it needs to pay a higher transaction fee which can also lead to insufficient funds. In both cases, the existence of $T_A$ enables the execution of $T_B$, therefore we do not consider these to be TOD attacks and ignore them from further analysis.

Finally, one error occurred with the original definition which did not occur for the other definition. However, this error was not reproducible, potentially being a temporary fault with the RPC requests.

#figure(
  table(
    columns: 3,
    align: (left, right, right),
    table.header([Result], [Original definition], [Adapted definition]),
    [TOD], [809], [775],
    [not TOD], [819], [839],
    [inaccurate execution], [19], [34],
    [insufficient ether], [672], [672],
    [error], [1], [0],
  ),
  caption: flex-caption(
    [The results from analyzing TOD candidates for the original TOD definition and the adapted TOD definition.],
    [TOD checking with definition comparison],
  ),
  kind: table,
)
<tab:experiment_check_definition>

=== Analysis of differences <sec:analysis-of-differences>

To understand, in which cases the two definitions lead to different results, we manually evaluated the cases where one result was TOD and the other not TOD. To assist the analysis, we let our tool output the relative changes of each transaction in both scenarios. In all of the cases, we manually verify that the manual application of @alg:tod-assessment on the relative changes gives the same result as the automatic application, to ensure the algorithm was correctly implemented.

Our analysis shows, that 34 TOD candidates have been marked as TOD if we only consider changes by $T_B$, while they are not TOD if we consider changes of both transactions. In all of these cases, the differences of $T_A$ between the normal and reverse scenario balance out the differences of $T_B$ between the normal and reverse scenario. One example is discussed in detail in @app:analysis-of-definition-differences.

Further 10 TOD candidates are not TOD considering only the changes by $T_B$, but are TOD if we also consider $T_A$. In these cases, $T_A$ creates different state changes depending on whether it was executed before or after $T_B$, thus being TOD. The execution of $T_B$ is not impacted by the transaction order.

In total, from the 1628 TOD candidates labelled as TOD or not TOD using our original definition, we obtained the same label with the adapted definition for 96.4% of these TOD candidates. This demonstrates that the theoretical weakness from @sec:weakness-focus-on-tb has practical impacts, but also that simulating $T_A$ in the reverse scenario can be omitted in a tradeoff for some accuracy.


= Trace analysis
TBD.

= Evaluation

@zhang_combatting_2023 and @torres_frontrunner_2021 have both analyzed the blocks 11,299,000-11,300,000. We can check if:
- TOD candidates would be found (or at which stage they are filtered)
- TOD check marks them as TOD (prerequisite for @zhang_combatting_2023, also very likely for @torres_frontrunner_2022)
- Trace analysis labels them similar to @zhang_combatting_2023
- Manual check of sample for each other label we set (checking the traces if they match the definition we gave for the labels)

= Tool benchmarking
TBD.
== Systematic Literature Review
== Result

= Data availability
TBD.

= Reproducibility
<cha:reproducibility>
== Tool
TBD.

== Randomness
TBD.

== Experiment setup
The experiments were performed on Ubuntu 22.04.04, using an AMD Ryzen 5 5500U CPU with 6 cores and 2 threads per core and a SN530 NVMe SSD. We used a 16 GB RAM with an additional 16 GB swap file.

For the RPC requests we used a public endpoint@noauthor_pokt_2024, which uses Erigon@noauthor_rpc_2024 according to the `web3_clientVersion` RPC method. We used a local cache to prevent repeating slow RPC requests. @fuzzland_eth_2024 Unless otherwise noted, the cache was initially empty for experiments that measure the running time.