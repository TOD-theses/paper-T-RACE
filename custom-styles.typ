#import "@preview/ctheorems:1.1.2": *

#let custom-styles = rest => {
  show quote.where(block: true): set quote(quotes: true)
  set table(inset: 6pt, stroke: 0.4pt)
  show table.cell.where(y: 0): strong
  show: thmrules.with(qed-symbol: $square$)
  show raw.where(block: true): set par(justify: false)
  set page(margin: (top: 4cm, bottom: 10em, left: 3cm, right: 3cm))

  rest
}