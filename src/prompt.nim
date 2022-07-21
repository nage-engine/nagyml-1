import yaml/serialization
import results

import tables, options, strformat, strutils, sequtils, sugar

import text
import choice

type Prompt* = object
  prompt* {.defaultVal: none(seq[Text]).}: Option[seq[Text]]
  choices*: seq[Choice]

func validateChoices*(prompt: Prompt, file: string, prompts: Table[string, Table[string, Prompt]]): Result[void, tuple[choice: int, reason: string]] =
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

func getType*(prompt: Prompt): string =
  if prompt.choices.isInput:
    return "INPUT; takes user input and stores to a variable"
  if prompt.choices.isRedirect:
    if prompt.choices[0].ending.isSome:
      return "ENDING; the story is forced to end here"
    return "REDIRECT; immediately jumps to another prompt"
  return "NORMAL; regular prompt-choice model"

func getJumps*(prompt: Prompt, file: string, name: string, prompts: Table[string, Table[string, Prompt]]): seq[tuple[name: string, choices: seq[int]]] =
  for promptFile, localPrompts in prompts:
    for promptName, localPrompt in localPrompts:
      let jumps = localPrompt.choices.getJumps(file, name, file != promptFile)
      if jumps.len != 0:
        result.add((promptFile & "/" & promptName, jumps))

func displayIndices*(choices: seq[int]): string =
  result = choices.map(c => fmt"#{c + 1}").join(", ")