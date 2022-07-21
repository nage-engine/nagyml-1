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

proc shutdown*(game: Game, save: bool = true, display: bool = true) =
  if save:
    game.player.save(display)
  if display:
    echo "Exiting..."
  quit(0)

proc getPrompt(game: Game, path: Path): Prompt =
  let file = (if path.file.isNone: game.player.path.file.get else: path.file.get)
  result = game.prompts.getOrDefault(file).getOrDefault(path.prompt)

proc handleCommand(game: Game, command: string): Result[void, string] =
  case command:
    of ".help": echo "\n" & COMMAND_HELP
    of ".save": game.player.save(true)
    of ".quit": game.shutdown()
    else: return err("Invalid command; use '.help' for a list of commands")
  echo ""
  return ok()

proc takeInput(game: Game, noise: var Noise): string =
  let ok = noise.readLine()
  if not ok:
    echo ""
    game.shutdown(game.metadata.save)
  result = noise.getLine

proc validateInput(game: Game, line: string, isInt: bool): bool =
  if line.startsWith("."):
    let handled = game.handleCommand(line)
    if handled.isErr:
      echo handled.error & "\n"
    return false
  if not isInt:
    if line.isEmptyOrWhitespace:
      echo "Invalid input; cannot be blank\n"
      return false
    return true
  var index: int
  try:
    index = parseInt(line)
  except:
    echo "Invalid input; must be a number\n"
    return false
  return true

proc beginPrompt(game: Game, prompt: Prompt, choices: seq[Choice], noise: var Noise, variables: var Option[Table[string, string]]): Choice =
  # Controls the user input loop, even if it's not to pick a choice
  let display = choices.display(variables)
  if display.text.isSome:
    echo display.text.get & "\n"
  while true:
    let line = game.takeInput(noise)
    if game.validateInput(line, not display.input):
      if display.input:
        let choice = choices[0]
        choice.applyVariable(variables, line)
        echo ""
        return choice
      else:
        let index = parseInt(line)
        if index < 1 or index > choices.len:
          echo "Invalid input; choice out of range\n"
          continue
        echo ""
        return choices[index - 1]

proc selectChoice(game: Game, display: var bool, noise: var Noise, variables: var Option[Table[string, string]]): Choice =
  let prompt = game.getPrompt(game.player.path)
  if display:
    if prompt.prompt.isSome:
      echo prompt.prompt.get.display(variables) & "\n"
  else:
    display = true
  # If the only choice has no text or variable input, user input will be skipped (redirect prompt)
  if prompt.choices.len == 1 and prompt.choices[0].response.isNone and prompt.choices[0].input.isNone:
    return prompt.choices[0]
  let choices = prompt.choices.filter(c => c.canDisplay(game.player))
  # If there are no valid choices to display, exit the game
  if choices.len == 0:
    echo "You've run out of options! This shouldn't happen - report this to the game's author(s)!"
    game.shutdown(game.metadata.save)
  return game.beginPrompt(prompt, choices, noise, variables)

proc begin*(game: var Game, noise: var Noise) =
  if not game.player.began:
    echo game.metadata.display()
    game.player.began = true
  # Main game loop
  while true:
    # Select a choice from the current prompt
    let choice = game.selectChoice(game.player.displayNext, noise, game.player.variables)
    # If it's an ending, stop the game here
    if choice.ending.isSome:
      echo choice.ending.get.parse(game.player.variables)
      game.shutdown(display=false)
    # Apply any notes and jump to the next prompt
    choice.applyNotes(game.player)
    choice.jump.get.update(game.player)
    if not choice.display:
      game.player.displayNext = false