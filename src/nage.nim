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

let prompt = Styler.init("> ")
n.setPrompt(prompt)
#proc sigintHandler() {.noconv.} =
#  echo "\n"
#  g.shutdown(true)

#setControlCHook(sigintHandler)

g.begin(n)