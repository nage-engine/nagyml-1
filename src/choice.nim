import yaml/serialization

import options, strformat, sequtils, sugar, tables

import text
import path

type
  NoteApplication* = object
    name*: string
    take* {.defaultVal: false.}: bool

  NoteRequirement* = object
    name*: string
    has* {.defaultVal: true.}: bool

  Notes* = object
    apply* {.defaultVal: none(seq[NoteApplication]).}: Option[seq[NoteApplication]]
    require* {.defaultVal: none(seq[NoteRequirement]).}: Option[seq[NoteRequirement]]
    once* {.defaultVal: none(string)}: Option[string]

  Input* = object
    text* {.defaultVal: none(string).}: Option[string]
    variable*: string

  Choice* = object
    response* {.defaultVal: none(Text).}: Option[Text]
    tag* {.defaultVal: none(string).}: Option[string]
    input* {.defaultVal: none(Input).}: Option[Input]
    jump* {.defaultVal: none(Path).}: Option[Path]
    display* {.defaultVal: true.}: bool
    lock* {.defaultVal: none(bool).}: Option[bool]
    notes* {.defaultVal: none(Notes).}: Option[Notes]
    variables* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]
    ending* {.defaultVal: none(string).}: Option[string]

func isInput*(choices: seq[Choice]): bool =
  result = choices.len == 1 and choices[0].input.isSome

func isRedirect*(choices: seq[Choice]): bool =
  result = choices.len == 1 and choices[0].response.isNone and choices[0].input.isNone

func getJumps*(choices: seq[Choice], file: string, prompt: string, external: bool): seq[int] =
  for index, choice in choices:
    if choice.jump.isSome:
      if choice.jump.get.matches(file, prompt, external):
        result.add(index)

proc displayResponse*(choice: Choice, variables: Option[Table[string, string]]): string =
  if choice.tag.isSome:
    result.add(fmt"[{choice.tag.get}] ")
  result.add(choice.response.get.display(variables))

func display*(choices: seq[Choice], variables: Option[Table[string, string]]): tuple[input: bool, text: Option[string]] =
  if choices.isInput:
    return (true, choices[0].input.get.text.map(s => s.parse(variables) & ":"))
  let strings = choices
    .filter(c => c.response.isSome)
    .map(c => c.displayResponse(variables))
  result.text = some("")
  for index, choice in strings:
    result.text.get.add(fmt"{index + 1}) {choice}")
    if index + 1 != strings.len:
      result.text.get.add("\n")

proc applyVariables*(choice: Choice, variables: var Option[Table[string, string]], line: Option[string]) =
  if variables.isNone:
    variables = some(initTable[string, string]())
  if line.isSome:
    variables.get[choice.input.get.variable] = line.get
  if choice.variables.isSome:
    for key, value in choice.variables.get:
      variables.get[key] = value