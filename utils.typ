#import "@preview/dashy-todo:0.0.1": todo
#import "@preview/fletcher:0.5.1" as fletcher: diagram, node, edge
#import "@preview/ctheorems:1.1.2": *

#let theorem = thmbox("theorem", "Theorem")
#let definition = thmbox("definition", "Definition", inset: (x: 1.2em, top: 1em))
#let proof = thmproof("proof", "Proof")

#let change(content) = text(fill: blue)[CHANGE: #content]

// some shortcuts
#let pre = math.italic("prestate")
#let post = math.italic("poststate")
#let colls = math.italic("collisions")
#let changedKeys = math.italic("changed_keys")