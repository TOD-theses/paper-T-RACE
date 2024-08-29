#import "utils.typ": *

= Acknowledgements

I want to express gratitude towards all the companions I had so far. Fooling around with siblings, hiking towards wiggly stones, sharing meals in the kitchen with flatmates, enjoying movies together, playing games, learning new languages by doing uni projects or being at random parties. This work would, and should, not exist without these precious moments.
#linebreak()Merci! Mulțumesc! Grazie! Gracias! Teşekkürler! جهانی سپاس! Danke! Thank you!


#v(2em)

I also want to thank Gernot Salzer and Monika di Angelo for their continuous support. With the regular meetings and their inputs and the plentitude of constructive feedback, they helped me a lot to steadily progress and improve this work.

= Kurzfassung

Ethereum speichert einen Zustand ab, der mittels Transaktionen verändert wird. Die Reihenfolge, in der Transaktionen ausgeführt werden, kann einen Einfluss auf diese Zustandsänderungen haben (transaction order dependency; TOD). Man kann analysieren, ob zwei Transaktionen TOD sind, indem man diese in zwei verschiedenen Reihenfolgen ausführt und die Ergebniszustände miteinander vergleicht. Jedoch können Transaktionen, die zwischen den beiden analysierten Transaktionen ausgeführt wurden, diese Analyse beeinflussen. Dies kann eine fokussierte Analyse von zwei Transaktionen auf TOD verhindern.

In dieser Diplomarbeit entwerfen wir eine Methode, um verschiedene Reihenfolgen von Transaktionen zu simulieren und auf TOD zu analysieren. Wir verwenden Zustandsänderungen von Transaktionen, um Zustände zu berechnen, mit denen wir verschiedene Reihenfolgen von Transaktionen simulieren. Diese Berechnungen können Zustandsänderungen von dazwischenliegenden Transaktionen inkludieren, ohne diese während der Simulation ausführen zu müssen. Weiters ermöglicht es, nur jene Änderungen am Zu-#linebreak()stand vorzunehmen, die von den Transaktionen verursacht wurden, die wir analysieren. Wir verwenden diese Simulation zum Feststellen, ob Transaktionen TOD sind und ob sie Eigenschaften eines Angriffes haben.
Außerdem erläutern wir Umstände, in denen es trotz dieser Methodik zu Beeinflussungen der Analyse durch dazwischenliegende Transaktionen kommen kann.

Weiters durchsuchen wir Transaktionen, die in Ethereum ausgeführt wurden, nach Transaktionspaaren, welche potentiell TOD sind. Wir paaren Transaktionen anhand ihrer Zustandsabfragen und -änderungen. Unsere Analyse zeigt, dass nur Änderungen von Kontoständen und Kontospeichern relevant für Angriffe sind, daher verwerfen wir Paare ohne solche Änderungen. Weiters filtern wir Paare, bei welchen potentielle Störfaktoren die Simulation beeinflussen. Schließlich reduzieren wir die Anzahl an Paaren, welche ähnliche Zustandsabfragen und -änderungen haben.

Wir evaluieren unsere Methoden anhand eines existierenden Datensatzes, welcher 5.601 Angriffe aus einer Analyse von 175.552 Transaktionen enthält. Unsere Suche nach potentieller TOD markiert 5.600 Transaktionspaare als potentiell TOD. Nachdem wir diese filtern, verbleiben wir mit 115 Paaren. Wir zeigen, dass diese 115 Paare ähnlich zu 703 der gefilterten Angriffe sind. Weiters evaluieren wir unsere Simulationsmethode an allen 5.601 Angriffen und stellen bei 86% davon TOD fest und bei 81% Angriffseigenschaften. Wir analysieren die Unterschiede zwischen unseren Ergebnissen und dem Angriffsdatensatz, und führen für 60 Angriffe eine manuelle Untersuchung durch.

= Abstract

In Ethereum, the order in which two transactions are executed can influence the changes they perform on the world state. One method to analyze such transaction order dependencies (TOD) is to execute the transactions in two orders and compare their behaviors. However, when simulating a reordering of two transactions, the transactions that occurred between the two transactions can influence the analysis. This influence can prevent an isolated analysis of two transactions.

To address this issue, this thesis proposes a new method to simulate transaction orders to analyze TOD. We use state changes of transactions to compute world states that we use to simulate transaction execution in different orders. This computation removes the need to execute intermediary transactions for the simulation and allows applying only the state changes of the transactions we want to analyze. We then use our simulation method to detect if transactions are TOD and show attack characteristics. We discuss cases where, despite using this method, intermediary transactions can interfere with TOD analysis.

Furthermore, we use state changes to detect transaction pairs on the blockchain that are potentially TOD. We match transactions based on the state they access and modify. By enumerating and analyzing the causes of TOD, we show that only TODs related to the storage and balance of accounts are relevant attack vectors. With this insight, we can remove matches that are irrelevant to an attack analysis. Additionally, we filter out transaction pairs where intermediary transactions may interfere with the TOD simulation. Finally, we also reduce the amount of transaction pairs with similar state accesses and modifications.

For the evaluation, we use a dataset from a previous study as a ground truth, which contains 5,601 attacks obtained from analyzing 175,552 transactions. Our method to detect potential TODs finds 5,600 of the attacks. After applying the filters, only 115 of the attacks remain for further analysis. We show that these are similar to at least 703 of the removed attacks. We apply our simulation method to all 5,601 attacks and verify that 86% of them are TOD and 81% fulfill the attack characteristic used by the ground truth. We analyze the cases where our results differ from the ground truth, including a manual analysis of 60 attacks.

