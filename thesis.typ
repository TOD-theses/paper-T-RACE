#import "@local/unofficial-tu-wien-thesis:0.0.1": *
#import "custom-styles.typ": custom-styles
#import "@local/dashy-todo:0.0.1": todo

#show: thesis.with(
  title: (
    en: "T-RACE: Tracing race condition attacks between Ethereum transactions.",
    de: "T-RACE: Eine Analyse von race condition Angriffen bei Ethereum Transaktionen",
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

#show: main-matter-styles
#show: page-header-styles

#include "main.typ"

#show: back-matter-styles
#set page(header: none)

#outline(title: "List of Figures", target: figure.where(kind: image))
#outline(title: "List of Tables", target: figure.where(kind: table))

#todo[For Evolution paper: why page 41-42?]

#bibliography("refs.bib")

#show: appendix-styles

#include "appendix.typ"