import yaml/serialization, streams
import results

import os, options, strformat, strutils, sequtils, sugar, tables

import path
import choice
import prompt
import metadata
import loading

type Player* = object
  began*: bool
  displayNext*: bool
  path*: Path
  notes*: seq[string]
  variables*: Option[Table[string, string]]

proc canDisplay*(choice: Choice, player: Player): bool =
  if choice.notes.isNone:
    return true
  if choice.notes.get.once.isSome and player.notes.contains(choice.notes.get.once.get):
    return false
  if choice.notes.get.require.isSome:
    for note in choice.notes.get.require.get:
      if (note.name in player.notes) != note.has:
        return false
  return true

func displayPromptDebug*(prompt: Prompt, file: string, name: string, prompts: Table[string, Table[string, Prompt]], player: Player): string =
  result.add(fmt"ID: {file}/{name}")
  result.add("\n" & fmt"Type: {prompt.getType()}")
  result.add("\n\n" & fmt"{prompt.choices.len} choice(s)")
  var accessible: seq[int] = @[]
  for index, choice in prompt.choices:
    if choice.canDisplay(player):
      accessible.add(index)
  let extra = if prompt.choices.len != accessible.len: fmt": {accessible.displayIndices()}" else: ""
  result.add("\n" & fmt"{accessible.len} of them accessible{extra}")
  result.add("\n\n")
  let jumps = prompt.getJumps(file, name, prompts)
  if jumps.len == 0:
    result.add("No prompts jump here!")
  else:
    result.add("Prompts that jump here:")
    result.add("\n" & jumps.map(j => fmt"- {j.name}: {j.choices.displayIndices()}").join("\n"))

proc tryApplyNote(note: string, player: var Player) =
  if not player.notes.contains(note):
    player.notes.add(note)

proc applyNotes*(choice: Choice, player: var Player) =
  if not choice.notes.isNone:
    if not choice.notes.get.once.isNone:
      choice.notes.get.once.get.tryApplyNote(player)
    if not choice.notes.get.apply.isNone:
      for note in choice.notes.get.apply.get:
        if note.take:
          let index = player.notes.find(note.name)
          if index != -1:
            player.notes.delete(index)
        else:
          note.name.tryApplyNote(player)

proc update*(path: Path, player: var Player) =
  if path.file.isSome:
    player.path.file = path.file
  player.path.prompt = path.prompt

proc loadPlayer*(metadata: Metadata): Result[Player, string] =
  var data = newFileStream(PLAYER_DATA)
  if data == nil:
    result = ok(Player(
      began: false,
      displayNext: true,
      path: metadata.entry,
      notes: metadata.notes.get(@[]),
      variables: metadata.variables
    ))
  else:
    result = loadObject[Player](PLAYER_DATA)

proc save*(player: Player, display: bool) =
  if display:
    stdout.write("Saving... ")
  writeFile(PLAYER_DATA, "")
  var data = newFileStream(PLAYER_DATA, fmWrite)
  dump(player, data)
  data.close()
  if display:
    echo fmt"Saved player data to {getCurrentDir()}/{PLAYER_DATA}."