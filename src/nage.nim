import yaml/serialization, streams
import results

import tables, os, options, strformat, strutils, sequtils, sugar

include text
include path
include choice
include prompt
include player
include metadata
include game

let loaded = loadGame()

if loaded.isErr:
  echo loaded.error
  quit(0)

var game = loaded.get

proc sigintHandler() {.noconv.} =
  echo "\n"
  game.shutdown(true)

setControlCHook(sigintHandler)

game.begin()