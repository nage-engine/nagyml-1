import yaml/serialization
import options, strformat, strutils, sequtils, tables, sugar

type
  TextMode* = enum
    dialogue, action

  Text* = object
    text*: string
    mode* {.defaultVal: dialogue.}: TextMode

proc parse*(text: string, variables: Option[Table[string, string]]): string =
  if variables.isNone:
    return text
  let segments = text.split("<").map(s => s.split(">")).concat()
  if segments.len == 1:
    return segments[0]
  for index, segment in segments:
    if index mod 2 != 0:
      result.add(variables.get.getOrDefault(segment, "UNDEFINED"))
    else:
      result.add(segment)

proc display*(text: Text, variables: Option[Table[string, string]]): string =
  let parsed = text.text.parse(variables)
  result = case text.mode:
    of dialogue:
      fmt("\"{parsed}\"")
    of action:
      parsed

proc display*(lines: seq[Text], variables: Option[Table[string, string]]): string =
  var dlg = none(bool)
  for index, line in lines:
    if dlg.isSome:
      if dlg.get and line.mode != dialogue:
        result.add("\n")
    result.add(line.display(variables))
    if index + 1 != lines.len:
      result.add("\n")
    dlg = some(line.mode == dialogue)