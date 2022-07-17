import yaml/serialization
import results

import tables, options, strformat

import text
import choice

type Prompt* = object
  prompt* {.defaultVal: none(seq[Text]).}: Option[seq[Text]]
  choices*: seq[Choice]

proc validateChoices*(prompt: Prompt, file: string, prompts: Table[string, Table[string, Prompt]]): Result[void, tuple[choice: int, reason: string]] =
  for index, choice in prompt.choices:
    if choice.jump.isNone and not choice.ending.isSome:
      return err((index, "Empty jump section in non-ending path"))
    if choice.jump.isSome:
      if choice.jump.get.file.isSome:
        if not prompts.contains(choice.jump.get.file.get):
          return err((index, fmt"Jump-file '{choice.jump.get.file.get}' does not exist"))
      elif not prompts.getOrDefault(file).contains(choice.jump.get.prompt):
        return err((index, fmt"Jump-prompt '{choice.jump.get.prompt}' does not exist locally in '{file}'"))
      if prompt.choices.len > 1 and choice.response.isNone:
        return err((index, "Empty response when multiple choices are present"))
  return ok()