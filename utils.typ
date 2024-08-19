#import "@preview/dashy-todo:0.0.1": todo
#import "@preview/fletcher:0.5.1" as fletcher: diagram, node, edge
#import "@preview/ctheorems:1.1.2": *

#let theorem = thmbox("theorem", "Theorem")
#let definition = thmbox("definition", "Definition", inset: (x: 1.2em, top: 1em))
#let proof = thmproof("proof", "Proof")
#let proposition = thmbox("proposition", "Proposition")

// some shortcuts
#let pre = "prestate"
#let post = "poststate"
#let colls = "collisions"
#let changedKeys = "changed_keys"
#let stateKey(type, ..args) = [(‘#type’, #args.pos().join(","))]