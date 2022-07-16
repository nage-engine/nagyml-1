import yaml/serialization, streams
import results

import tables, os, options, strformat, strutils, sequtils, sugar

import text
import path
import choice
import prompt
import player
import metadata

const PROMPTS_DIR: string = "prompts"
const GAME_DATA: string = "nage.yml"
const PLAYER_DATA: string = "data.yml"

type
  Game = object
    metadata: Metadata
    player: Player
    prompts: Table[string, Table[string, Prompt]]

proc loadObject[T](path: string): Result[T, string] =
  var file = newFileStream(path)
  if file == nil:
    return err(fmt"'{path}' doesn't exist!")
  try:
    var parsed: T
    load(file, parsed)
    result = ok(parsed)
    file.close
  except:
    result = err(fmt"Error while loading '{path}': {getCurrentExceptionMsg()}")

proc loadPlayer(metadata: Metadata): Result[Player, string] =
  var data = newFileStream(PLAYER_DATA)
  if data == nil:
    result = ok(Player(
      began: false,
      displayNext: true,
      path: metadata.entry,
      notes: @[]
    ))
  else:
    result = loadObject[Player](PLAYER_DATA)

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

proc save(player: Player, e: bool) =
  if e:
    stdout.write("Saving... ")
  writeFile(PLAYER_DATA, "")
  var data = newFileStream(PLAYER_DATA, fmWrite)
  dump(player, data)
  data.close()
  if e:
    echo fmt"Saved player data to {getCurrentDir()}/{PLAYER_DATA}."

proc shutdown*(game: Game, e: bool) =
  game.player.save(e)
  if e:
    echo "Exiting..."
  quit(0)

proc getPrompt(game: Game, path: Path): Prompt =
  let file = (if path.file.isNone: game.player.path.file.get else: path.file.get)
  result = game.prompts.getOrDefault(file).getOrDefault(path.prompt)

proc selectChoice(game: Game, display: var bool): Choice =
  let prompt = game.getPrompt(game.player.path)
  if display:
    echo prompt.prompt.display() & "\n"
  else:
    display = true
  if prompt.choices.len == 1 and prompt.choices[0].response.isNone:
    return prompt.choices[0]
  let choices = prompt.choices.filter(c => c.canDisplay(game.player))
  if choices.len == 0:
    echo "You've run out of options! This shouldn't happen - report this to the game's author(s)!"
    game.shutdown(true)
  return prompt.begin(choices)

proc begin*(game: var Game) =
  if not game.player.began:
    echo game.metadata.display()
    game.player.began = true
  while true:
    let choice = game.selectChoice(game.player.displayNext)
    if choice.ending.isSome:
      echo choice.ending.get
      game.shutdown(false)
    choice.applyNotes(game.player)
    choice.jump.get.update(game.player)
    if not choice.display:
      game.player.displayNext = false