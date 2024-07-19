#import "@local/unofficial-tu-wien-thesis:0.0.1": thesis, front-matter, main-matter, back-matter, use-flex-caption

#show: thesis.with(
  title: (
    en: "An ode for Lord Ipsum",
    de: "Eine Ode an Lord Ipsum",
  ),
  subtitle: (:),
  lang: "en",
  author: (name: "Lord Ipsus", student-number: 11223344),
  advisor: (
    name: "Darth Ipsus",
    pre-title: "Univ.Prof.Dr.",
    post-title: none,
  ),
  assitants: ((name: "Ipsinator", pre-title: "Sir"),),
  curriculum: "Software Engineering & Internet Computing",
  keywords: ("Pizza"),
  date: datetime.today(),
)

#show: use-flex-caption
#show: front-matter

// set the default "supplement" for all "algorithm" figures. The supplement is shown when referencing it (e.g. @my-alg)
#show figure.where(kind: "algorithm"): set figure(supplement: "Algorithm")

#include "front-matter.typ"
#outline()

#show: main-matter

#include "main.typ"

#show: back-matter

#outline(title: "List of Figures", target: figure.where(kind: image))
#outline(title: "List of Tables", target: figure.where(kind: table))
#outline(title: "List of Algorithms", target: figure.where(kind: "algorithm"))

#bibliography("refs.bib")

#include "appendix.typ"