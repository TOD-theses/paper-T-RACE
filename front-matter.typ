#import "utils.typ": *

= Danksagung

TBD.

= Acknowledgements

TBD.

= Kurzfassung

TBD.

= Abstract

In Ethereum, the order in which two transactions are executed can influence the changes they perform on the world state. One method to analyze such transaction order dependencies (TOD) is to execute the transactions in both orders and compare their behaviours. However, when simulating a reordering of two transactions, the transactions that occurred between the two transactions can influence the analysis. This can prevent an isolated analysis of two transactions.

To address this issue, this thesis proposes a new method to simulate transaction orders for TOD. We use state changes of transactions to compute world states that resemble different transaction orders. This removes the need to execute intermediary transactions for the simulation and allows to apply only the state changes of the transactions we want to analyze. Furthermore, we use state changes to detect potential TODs in the Ethereum blockchain and define several filters to reduce the search space.

We evaluate these methods with an analysis of {n}#todo[Finish this sentence] transactions. We find {n} potential TODs of which {n} are reported as TOD using our simulation. We further use the simulation to detect several attack properties and compare it with previous works...
