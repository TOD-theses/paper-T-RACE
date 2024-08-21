#import "utils.typ": colls

= Overview of Generative AI Tools Used

No generative AI tools where used in the process of researching and writing this thesis.

= Case studies

== Analysis of definition differences <app:analysis-of-definition-differences>

Here, we present one example for @sec:analysis-of-differences that is approximately TOD but not TOD.

For the following two transactions:
- $T_A$: `0xa723f53edcae821203572a773b8f1b5cf5c008a734794ee2acae771540363f11`
- $T_B$: `0x5aa39f4ff79f6653fdb0165a92fcb55e024ae8d5b8dba67c0b6e4c153ea4a8d4`

Both transactions changed a specific storage slot. Our tool outputs the following changes:
- $T_B$ (normal): `+0`
- $T_A$ (normal): `+0x1c7400000000000000000000000000000000000000000000000000000000`
- $T_B$ (reverse): `+0x1c7400000000000000000000000000000000000000000000000000000000`
- $T_A$ (reverse): `+0`

We see, that in both scenarios, the value increases by `0x1c7400000000000000000000000000000000000000000000000000000000`, therefore considering both transactions it is not TOD. However, if we only consider $T_B$, we would observe a TOD, as $T_B$ changes the storage slot differently in the scenarios (`+0` vs `+0x1c7400000000000000000000000000000000000000000000000000000000`).

In our manual analysis of all cases, this information is enough to say that the application of our definitions was correct, assuming that the state changes outputted by the tool are correct. To further understand, why such changes occur in practice, we analyzed this transaction pair in more detail.

Using Etherscan, we see that both transactions emit a `UsdPerTokenUpdated` event with the parameters `value: 0x429d069189e0000` and `timestamp: 0x663c689f`. Furthermore, it shows for the storage slot at transaction $T_A$:

- *Before*: `0x663c4c2b00000000000000000000000000000000000000000429d069189e0000`
- *After*: `0x663c689f00000000000000000000000000000000000000000429d069189e0000`

We observe, that the value after $T_A$ is composed of the timestamp and the value of the emitted event. As both transactions emitted the same event with this value and timestamp, it is likely, that both transactions set the value of this storage slot to `0x663c689f00000000000000000000000000000000000000000429d069189e0000`. For $T_A$, this led to a state change of this storage slot. As $T_B$ is executed after $T_A$, the storage slot was already at the target value and no change is recorded for $T_B$. In the reverse scenario, $T_B$ is executed first and therefore we observe a state change here. And similarly for $T_A$ we now record no state change.

The code that updates the storage slot is shown below, located at address `0x8c9b2efb7c64c394119270bfece7f54763b958ad`. In line 5 we see the assignment to the storage slot and in line 9 the logged event. Both transactions have the same values for `update.usdPerToken` and `block.timestamp`, therefore the value assigned to `s_usdPerToken[update.sourceToken]` is the same in both cases.

#[
  #show raw.line: it => {
    [#it.number #it]
  }
  ```sol
  contract PriceRegistry {
    // ...
    function updatePrices(/* ... */) {
      // ...
      s_usdPerToken[update.sourceToken] = Internal.TimestampedPackedUint224({
        value: update.usdPerToken,
        timestamp: uint32(block.timestamp)
      });
      emit UsdPerTokenUpdated(update.sourceToken, update.usdPerToken, block.timestamp);
    }
  }
  ```
]

== Analysis of TOD <app:analysis-TOD>

We analyze one of the cases where a TOD candidate $(T_A, T_B)$ is not TOD according to our definition, but is reported as an attack by @zhang_combatting_2023. The transaction $T_A$ is #link("https://etherscan.io/tx/0x5cf84067556e7db37fd0279ec3bfe227d71758786cb53f1cc24e20f8afd9f8d8")[0x5cf84067556e7db37fd0279ec3bfe227d71758786cb53f1cc24e20f8afd9f8d8] and $T_B$ is #link("https://etherscan.io/tx/0xd24cffe4cd2dd7c89cc7ec3d38f44f4563d184b5fa9a952b46358a8a8e8176cc")[0xd24cffe4cd2dd7c89cc7ec3d38f44f4563d184b5fa9a952b46358a8a8e8176cc].

To evaluate if this TOD candidate is TOD, we start by determining the collisions of $T_A$ and $T_B$. If the execution of $T_A$ influences $T_B$ or vice versa, it must be at a state key that one of them modifies and the other accesses or modifies as well. For this case study, we evaluate $(W_T_A sect R_T_B) union (W_T_A sect W_T_B) union (R_T_A sect W_T_B)$ to obtain the collisions rather than $colls(T_A, T_B)$, as we do not want to rely on the TOD approximation underlying the definition of $colls(T_A, T_B)$.

We use the `debug_traceTransaction` method to obtain the accessed state keys $R_T_A$ and $R_T_B$ (refer to the @sec:data-availability for the data). We then compare these state modifications $W_T_A$ and $W_T_B$ shown on Etherscan and only find a collision at the balance of the #link("https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")[WETH] contract. Therefore, the only way $T_A$ may influence $T_B$, and vice versa, is by modifying and accessing the balance of the WETH contract.

In @tab:state_reading_instructions, we see the instructions that can access balances. The instructions `CALL`, `CALLCODE`, `CREATE`, `CREATE2` and `SELFDESTRUCT` access a balance by sending Ether from the caller to the recipient. These instructions can behave differently depending on whether enough Ether is available. This is not the case, because the transactions transfer less than 3 Ether from the WETH account to another account, but the WETH account had more than 6 million Ether at this time according to the `eth_getBalance` RPC method.

The remaining two instructions that can cause TOD when accessing balances are `BALANCE` and `SELFBALANCE`. We manually inspect the execution traces in the normal scenario to see if these instructions are used to access the balance of the WETH contract.

According to our normal scenario traces, $T_A$ has three executions of `SELFBALANCE` and $T_B$ has two executions of `SELFBALANCE`, however none of these are lookup the balance of the WETH contract. The traces also show no occurrence of the `BALANCE` instruction.

We further verify that our normal scenario traces execute the same instructions as on Etherscan. We compare the number of execution steps from our traces, which matches with those shown by Etherscan (15171 and 9164), thus we assume we execute the same instructions as on the blockchain.

In summary, we ruled out that any instruction accesses the balance of the WETH contract. As this is the only state key that one transaction writes and the other reads or writes, $T_A$ and $T_B$, these transactions cannot be TOD.


= Javascript tracer <app:javascript-tracer>

We use the following javascript tracer to extract `CALL` instructions and emitted token events. The `step` function is executed for each instruction. In case a `CALL` or `CALLCODE` instruction is found we append data to `this.calls` and for `LOG0`, `LOG1`, `LOG2`, `LOG3` or `LOG4` instruction is found we append it to `this.logs`.

To detect reverted calls, we check in the `exit` function if an error occurred. As an error reverts the current call context and all of its children, we store a mapping of each call context to its children in `children_of`. When reverting a call context, we can then recursively mark all child contexts as reverted.

The `result` function is called when the tracing has finished. We first check if the overall transaction is reverted. Then we return the calls and logs for which their call context has not been reverted.

```js
{
  calls: [],
  logs: [],
  call_context_stack: [0],
  call_context_counter: 0,
  reverted_call_contexts: [],
  children_of: {},
  location: function(log) {
    return {
        'address': toHex(log.contract.getAddress()),
        'pc': log.getPC(),
    }
  },
  enter: function(callFrame) {
    current_call_context = this.call_context_stack[this.call_context_stack.length - 1]
    this.call_context_counter += 1
    this.call_context_stack.push(this.call_context_counter)
    if (!this.children_of[current_call_context]) {
      this.children_of[current_call_context] = []
    }
    this.children_of[current_call_context].push(this.call_context_counter)
  },
  exit: function(frameResult) {
    context_id = this.call_context_stack.pop(this.call_context_counter)
    error = frameResult.getError()
    if (error) {
      this._revert(context_id)
    }
  },
  _revert: function(id) {
    // revert context and all of its sub contexts
    this.reverted_call_contexts.push(id)
    children = this.children_of[id] || []
    for (child_id of children) {
      this._revert(child_id)
    }
  },
  step: function(log, db) {
    opcode = log.op.toNumber()
    if (opcode == 0xF1 || opcode == 0xF2) {
        this.calls.push({
            'op': opcode,
            'sender': toHex(log.contract.getAddress()),
            'to': toHex(toAddress(log.stack.peek(1).toString(16))),
            'value': log.stack.peek(2).toString(16),
            'location': this.location(log),
            'call_context_id': this.call_context_stack[this.call_context_stack.length - 1],
        })
    }
    else if (opcode >= 0xA0 && opcode <= 0xA4) {
        offset = log.stack.peek(0).valueOf()
        size = log.stack.peek(1).valueOf()
        data = toHex(log.memory.slice(offset, offset + size))
        topics_amount = opcode - 0xA0
        topics = []
        for (i = 0; i < topics_amount; i++) {
            topics.push(log.stack.peek(2 + i).toString(16).padStart(64, "0"))
        }
        this.logs.push({
            'topics': topics,
            'data': data,
            'address': toHex(log.contract.getAddress()),
            'location': this.location(log),
            'call_context_id': this.call_context_stack[this.call_context_stack.length - 1],
        })
    }
  },
  fault: function(log, db) {},
  result: function(ctx, db) {
    if (ctx.error) {
      this._revert(0)
    }
    logs = this.logs.filter(log => !this.reverted_call_contexts.includes(log['call_context_id']))
    calls = this.calls.filter(call => !this.reverted_call_contexts.includes(call['call_context_id']))
    return {
      "gas": ctx.gasUsed,
      "calls": calls,
      "logs": logs,
      "reverted_call_contexts": this.reverted_call_contexts,
    };
  }
}
```