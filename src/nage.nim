import yaml/serialization
import results

import tables, options

import text
import path
import choice
import prompt
import player
import metadata
import game

let loaded = loadGame()

if loaded.isErr:
  echo loaded.error
  quit(0)

var g = loaded.get

proc sigintHandler() {.noconv.} =
  echo "\n"
  g.shutdown(true)

setControlCHook(sigintHandler)

g.begin()