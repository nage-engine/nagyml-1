import yaml/serialization
import options

import path
import choice

type
  Player* = object
    began*: bool
    displayNext*: bool
    path*: Path
    notes*: seq[string]

proc canDisplay*(choice: Choice, player: Player): bool =
  if choice.notes.isNone or choice.notes.get.require.isNone:
    return true
  for note in choice.notes.get.require.get:
    if (note.name in player.notes) != note.has:
      return false
  return true

proc applyNotes*(choice: Choice, player: var Player) =
  if not choice.notes.isNone and not choice.notes.get.apply.isNone:
    for note in choice.notes.get.apply.get:
      if note.take:
        let index = player.notes.find(note.name)
        if index != -1:
          player.notes.delete(index)
      else:
        if not player.notes.contains(note.name):
          player.notes.add(note.name)

proc update*(path: Path, player: var Player) =
  if path.file.isSome:
    player.path.file = path.file
  player.path.prompt = path.prompt