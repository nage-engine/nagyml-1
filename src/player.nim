import yaml/serialization, streams
import results

import os, options, strformat, strutils, sequtils, sugar, tables

import path
import choice
import prompt
import metadata
import loading

type 
  VariableEntry* = object
    value*: string
    previous*: Option[string]

  HistoryEntry* = object
    display*: bool
    path*: Path
    locked*: Option[bool]
    notes*: Option[seq[NoteApplication]]
    variables*: Option[Table[string, VariableEntry]]

  Player* = object
    began*: bool
    notes*: seq[string]
    variables*: Option[Table[string, string]]
    history*: seq[HistoryEntry]

proc loadPlayer*(metadata: Metadata): Result[Player, string] =
  var data = newFileStream(PLAYER_DATA)
  if data == nil:
    let entry = HistoryEntry(
      display: true,
      path: metadata.entry,
      locked: none(bool),
      notes: none(seq[NoteApplication]),
      variables: none(Table[string, VariableEntry])
    )
    result = ok(Player(
      began: false,
      notes: metadata.notes.get(@[]),
      variables: metadata.variables,
      history: @[entry]
    ))
  else:
    result = loadObject[Player](PLAYER_DATA)
    if result.isOk and result.get.history.len == 0:
      return err("history cannot be empty")

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

proc applyNotes*(notes: seq[NoteApplication], player: var Player, reverse: bool = false) =
  for note in notes:
    if note.take xor reverse:
      let index = player.notes.find(note.name)
      if index != -1:
        player.notes.delete(index)
    else:
      note.name.tryApplyNote(player)

proc applyNotes*(choice: Choice, player: var Player) =
  if choice.notes.isSome:
    if choice.notes.get.once.isSome:
      choice.notes.get.once.get.tryApplyNote(player)
    if choice.notes.get.apply.isSome:
      choice.notes.get.apply.get.applyNotes(player)

proc appendHistory*(choice: Choice, line: Option[string], size: Option[int], player: var Player) =
  let last = player.history[^1]
  let newPath = Path(
    file: some(choice.jump.get.file.get(last.path.file.get)), 
    prompt: choice.jump.get.prompt
  )
  var notes = choice.notes.map(n => n.apply.get(@[])).get(@[])
  if choice.notes.isSome and choice.notes.get.once.isSome:
    notes.add(NoteApplication(name: choice.notes.get.once.get))
  var variables = choice.variables.get(initTable[string, string]())
  if line.isSome:
    variables[choice.input.get.variable] = line.get
  var variableEntries = initTable[string, VariableEntry]()
  for key, value in variables:
    let previous = if player.variables.isSome and player.variables.get.contains(key): 
      some(player.variables.get.getOrDefault(key)) 
    else: 
      none(string)
    variableEntries[key] = VariableEntry(previous: previous, value: value)
  let entry = HistoryEntry(
    display: choice.display, 
    path: newPath,
    locked: choice.lock,
    notes: if notes.len > 0: some(notes) else: none(seq[NoteApplication]),
    variables: if variableEntries.len > 0: some(variableEntries) else: none(Table[string, VariableEntry])
  )
  player.history.add(entry)
  if size.isSome and player.history.len > size.get:
    player.history.delete(0)

proc reverseHistory*(player: var Player) =
  let entry = player.history[^1]
  if entry.notes.isSome:
    entry.notes.get.applyNotes(player, true)
  if entry.variables.isSome:
    for name, variable in entry.variables.get:
      if variable.previous.isSome:
        player.variables.get[name] = variable.previous.get
      else:
        player.variables.get.del(name)
  player.history.delete(player.history.len - 1)

proc save*(player: Player, display: bool) =
  if display:
    stdout.write("Saving... ")
  writeFile(PLAYER_DATA, "")
  var data = newFileStream(PLAYER_DATA, fmWrite)
  dump(player, data)
  data.close()
  if display:
    echo fmt"Saved player data to {getCurrentDir()}/{PLAYER_DATA}."