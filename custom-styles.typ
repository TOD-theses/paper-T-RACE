#import "@preview/ctheorems:1.1.2": *

#let custom-styles = rest => {
  set table(inset: 6pt, stroke: 0.4pt)
  show table.cell.where(y: 0): strong
  show: thmrules.with(qed-symbol: $square$)

  rest
}