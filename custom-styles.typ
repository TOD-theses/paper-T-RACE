#let custom-styles = rest => {
  set table(inset: 6pt, stroke: 0.4pt)
  show table.cell.where(y: 0): strong

  rest
}