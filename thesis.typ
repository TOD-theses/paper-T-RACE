#import "@preview/definitely-not-tuw-thesis:0.1.0": *
#import "custom-styles.typ": custom-styles

#show: thesis.with(
  font: "TeX Gyre Heros",
  title: (
    en: "Using state changes to detect and simulate transaction order dependency in Ethereum",
    de: "Simulation und Analyse von Transaktionsreihenfolgen in Ethereum",
  ),
  subtitle: (:),
  lang: "en",
  author: (name: "Othmar Lechner", student-number: 11841833),
  advisor: (
    name: "Monika di Angelo",
    pre-title: "Ass.Prof.in Dipl.-Ing.in Mag.a rer.soc.oec. Dr.in techn.",
  ),
  assistants: ((name: "Gernot Salzer", pre-title: "Ao.Univ.Prof. Dr."),),
  curriculum: (en: "Software Engineering & Internet Computing", de: "Software Engineering & Internet Computing"),
  keywords: ("Ethereum", "TOD", "Frontrunning"),
  date: datetime.today(),
)

#show: flex-caption-styles
#show: toc-styles
#show: general-styles
#show: front-matter-styles
#show: custom-styles


#include "front-matter.typ"
#outline()

#show figure.where(kind: "algorithm"): set figure(supplement: "Algorithm")

#show: main-matter-styles
#set heading(numbering: "1.1.1.a")

#include "main.typ"

#show: back-matter-styles
#set page(header: none)

#outline(title: "List of Figures", target: figure.where(kind: image))
#outline(title: "List of Tables", target: figure.where(kind: table))
#outline(title: "List of Algorithms", target: figure.where(kind: "algorithm"))

#bibliography("refs.bib")

#show: appendix-styles

#include "appendix.typ"