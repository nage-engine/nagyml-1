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
.help - View this message
.save - Save the player data
.quit - Save and quit the game"""

const COMMAND_HELP_DEBUG: string = COMMAND_HELP & "\n" & """
.prompt <FILE> <NAME> - Display debug info about a prompt
.prompts <FILE> - Display info about all prompts in a file
.files - Display all loaded prompt files
.notes - Display all applied notes
.variables - Display all applied variables and their values"""

const DEBUG_COMMANDS: seq[string] = @[".prompt", ".prompts", ".files", ".notes", ".variables"]
const TABLE_COMMANDS: seq[string] = @[".prompt", ".prompts"]

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

proc checkTableEntry[T](table: Table[string, T], args: seq[string], index: int, id: string): Result[void, string] =
  if args.len < index + 1:
    return err(fmt"Command error: missing {id} name")
  if not table.contains(args[index]):
    return err(fmt"Command error: {id} '{args[index]}' does not exist")
  return ok()

proc displayTableKeys[T](table: Table[string, T], id: string): string =
  let keys = table.keys.toSeq
  result = fmt"{keys.len} {id}(s):"
  result.add("\n" & keys.join(", "))

proc handleCommand(game: Game, command: string): Result[void, string] =
  let args = command.split(" ")[0..^1]
  if args[0] in DEBUG_COMMANDS and not game.metadata.debug:
    return err("Invalid command: debug features are disabled")
  if args[0] in TABLE_COMMANDS:
    ?game.prompts.checkTableEntry(args, 1, "file")
  case args[0]:
    of ".help": echo "\n" & (if game.metadata.debug: COMMAND_HELP_DEBUG else: COMMAND_HELP)
    of ".save": game.player.save(true)
    of ".quit": game.shutdown()
    of ".prompt":
      ?game.prompts.getOrDefault(args[1]).checkTableEntry(args, 2, "prompt")
      echo "\n" & game.prompts.getOrDefault(args[1]).getOrDefault(args[2]).displayPromptDebug(args[1], args[2], game.prompts, game.player)
    of ".prompts":
      echo "\n" & game.prompts.getOrDefault(args[1]).displayTableKeys("prompt")
    of ".files":
      echo "\n" & game.prompts.displayTableKeys("file")
    of ".notes": echo (if game.player.notes.len == 0: "No notes applied" else: game.player.notes.join(", "))
    of ".variables":
      if game.player.variables.isNone:
        echo "No variables applied"
      else:
        echo "\n" & game.player.variables.get.pairs().toSeq.map(p => fmt"{p[0]}: {p[1]}").join("\n")
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
      echo "Invalid input: cannot be blank\n"
      return false
    return true
  var index: int
  try:
    index = parseInt(line)
  except:
    echo "Invalid input: must be a number\n"
    return false
  return true

proc beginPrompt(game: Game, prompt: Prompt, choices: seq[Choice], noise: var Noise): tuple[choice: Choice, line: Option[string]] =
  # Controls the user input loop, even if it's not to pick a choice
  let display = choices.display(game.player.variables)
  if display.text.isSome:
    echo display.text.get & "\n"
  while true:
    let line = game.takeInput(noise)
    if game.validateInput(line, not display.input):
      if display.input:
        let choice = choices[0]
        echo ""
        return (choice, some(line))
      else:
        let index = parseInt(line)
        if index < 1 or index > choices.len:
          echo "Invalid input: choice out of range\n"
          continue
        echo ""
        return (choices[index - 1], none(string))

proc selectChoice(game: Game, display: var bool, noise: var Noise): tuple[choice: Choice, line: Option[string]] =
  let prompt = game.getPrompt(game.player.path)
  if display:
    if prompt.prompt.isSome:
      echo prompt.prompt.get.display(game.player.variables) & "\n"
  else:
    display = true
  # If the only choice has no text or variable input, user input will be skipped (redirect prompt)
  if prompt.choices.isRedirect:
    return (prompt.choices[0], none(string))
  let choices = prompt.choices.filter(c => c.canDisplay(game.player))
  # If there are no valid choices to display, exit the game
  if choices.len == 0:
    echo "You've run out of options! This shouldn't happen - report this to the game's author(s)!"
    game.shutdown(game.metadata.save)
  return game.beginPrompt(prompt, choices, noise)

proc begin*(game: var Game, noise: var Noise) =
  if not game.player.began:
    echo game.metadata.display()
    game.player.began = true
  # Main game loop
  while true:
    # Select a choice from the current prompt
    let (choice, line) = game.selectChoice(game.player.displayNext, noise)
    # If it's an ending, stop the game here
    if choice.ending.isSome:
      echo choice.ending.get.parse(game.player.variables)
      game.shutdown(display=false)
    # Apply any data and jump to the next prompt
    choice.applyNotes(game.player)
    choice.applyVariables(game.player.variables, line)
    choice.jump.get.update(game.player)
    if not choice.display:
      game.player.displayNext = false