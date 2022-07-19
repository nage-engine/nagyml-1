import results
import noise

import options

import game

let loaded = loadGame()

if loaded.isErr:
  echo loaded.error
  quit(0)

var g = loaded.get

var n = Noise.init()
n.setPrompt("> ")

g.begin(n)