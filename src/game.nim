import yaml/serialization, streams
import results
import noise

import tables, os, options, strformat, strutils, sequtils, sugar

import text
import path
import choice
import prompt
import player
import metadata
import loading

const COMMAND_HELP: string = """
.help: View this message
.save: Save the player data
.quit: Saves and quits the game"""

type Game = object
  metadata: Metadata
  player: Player
  prompts: Table[string, Table[string, Prompt]]

proc loadGame*(): Result[Game, string] =
  var prompts = initTable[string, Table[string, Prompt]]()
  # Load all prompts
  for file in walkDirRec(PROMPTS_DIR):
    let p = splitFile(file)
    if prompts.contains(p.name):
      return err(fmt"Error while loading prompt files: duplicate name '{p.name}'. Make sure each file name is unique regardless of subdirectory")
    prompts[p.name] = ?loadObject[Table[string, Prompt]](file)
  # Validate all prompts against the whole table
  for file, filePrompts in prompts:
    for name, prompt in filePrompts:
      let res = prompt.validateChoices(file, prompts)
      if res.isErr:
        return err(fmt"Error while validating prompt '{file}/{name}', choice #{res.error.choice + 1}: {res.error.reason}")
  # Load other files
  let metadata = ?loadObject[Metadata](GAME_DATA)
  let player = ?loadPlayer(metadata)
  result = ok(Game(metadata: metadata, player: player, prompts: prompts))

proc shutdown*(game: Game, e: bool) =
  game.player.save(e)
  if e:
    echo "Exiting..."
  quit(0)

proc getPrompt(game: Game, path: Path): Prompt =
  let file = (if path.file.isNone: game.player.path.file.get else: path.file.get)
  result = game.prompts.getOrDefault(file).getOrDefault(path.prompt)

proc handleCommand(game: Game, command: string): Result[void, string] =
  if not command.startsWith("."):
    return err("Invalid input; must be a number")
  case command:
    of ".help": echo "\n" & COMMAND_HELP
    of ".save": game.player.save(true)
    of ".quit": game.shutdown(true)
    else: return err("Invalid command; use '.help' for a list of commands")
  echo ""
  return ok()

proc beginPrompt(game: Game, prompt: Prompt, choices: seq[Choice], noise: var Noise): Choice =
  echo choices.display() & "\n"
  while true:
    let ok = noise.readLine()
    if not ok:
      echo ""
      game.shutdown(true)
    let line = noise.getLine
    var index: int
    try:
      index = parseInt(line)
    except:
      let handled = game.handleCommand(line)
      if handled.isErr:
        echo handled.error & "\n"
      continue
    if index < 1 or index > choices.len:
      echo "Invalid input; choice out of range\n"
      continue
    echo ""
    return choices[index - 1]

proc selectChoice(game: Game, display: var bool, noise: var Noise): Choice =
  let prompt = game.getPrompt(game.player.path)
  if display:
    if prompt.prompt.isSome:
      echo prompt.prompt.get.display() & "\n"
  else:
    display = true
  if prompt.choices.len == 1 and prompt.choices[0].response.isNone:
    return prompt.choices[0]
  let choices = prompt.choices.filter(c => c.canDisplay(game.player))
  if choices.len == 0:
    echo "You've run out of options! This shouldn't happen - report this to the game's author(s)!"
    game.shutdown(true)
  return game.beginPrompt(prompt, choices, noise)

proc begin*(game: var Game, noise: var Noise) =
  if not game.player.began:
    echo game.metadata.display()
    game.player.began = true
  while true:
    let choice = game.selectChoice(game.player.displayNext, noise)
    if choice.ending.isSome:
      echo choice.ending.get
      game.shutdown(false)
    choice.applyNotes(game.player)
    choice.jump.get.update(game.player)
    if not choice.display:
      game.player.displayNext = false