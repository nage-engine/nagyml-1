import yaml/serialization
import options, strformat

type
  TextMode* = enum
    dialogue, action

  Text* = object
    text*: string
    mode* {.defaultVal: dialogue.}: TextMode

proc display*(text: Text): string =
  result = case text.mode:
    of dialogue:
      fmt("\"{text.text}\"")
    of action:
      text.text

proc display*(lines: seq[Text]): string =
  var dlg = none(bool)
  for index, line in lines:
    if dlg.isSome:
      if dlg.get and line.mode != dialogue:
        result.add("\n")
    result.add(line.display())
    if index + 1 != lines.len:
      result.add("\n")
    dlg = some(line.mode == dialogue)