#import "@preview/ctheorems:1.1.2": *

#let page-header-styles = rest => {
  // Add current chapter to page header
  set page(header: context {
    let current-page = counter(page).get()

    let all-headings = query(heading.where(level: 1, numbering: "1.1.1.a"))
    let is-new-chapter = all-headings.any(m => counter(page).at(m.location()) == current-page)
    if is-new-chapter {
      return
    }


    let previous-headings = query(selector(heading.where(level: 1)).before(here())).filter(h => h.numbering != none)

    if previous-headings.len() == 0 {
      return
    }
    let heading-title = previous-headings.last().body

    [#str(previous-headings.len()). #h(1em) #smallcaps(heading-title)]
    line(length: 100%)
  })

  rest
}

#let custom-styles = rest => {
  show quote.where(block: true): set quote(quotes: true)
  set table(inset: 6pt, stroke: 0.4pt)
  show table.cell.where(y: 0): strong
  show: thmrules.with(qed-symbol: $square$)
  show raw.where(block: true): set par(justify: false)
  set page(margin: (top: 4cm, bottom: 10em, left: 3cm, right: 3cm))
  set text(size: 12pt)

  show: page-header-styles

  rest
}