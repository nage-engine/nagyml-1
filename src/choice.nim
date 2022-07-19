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
    input* {.defaultVal: none(Input).}: Option[Input]
    jump* {.defaultVal: none(Path).}: Option[Path]
    display* {.defaultVal: true.}: bool
    notes* {.defaultVal: none(Notes).}: Option[Notes]
    ending* {.defaultVal: none(string).}: Option[string]

func isInput(choices: seq[Choice]): bool =
  result = choices.len == 1 and choices[0].input.isSome

proc display*(choices: seq[Choice], variables: Option[Table[string, string]]): tuple[input: bool, text: Option[string]] =
  if choices.isInput:
    return (true, choices[0].input.get.text.map(s => s.parse(variables) & ":"))
  let strings = choices
    .filter(c => c.response.isSome)
    .map(c => c.response.get.display(variables))
  result.text = some("")
  for index, choice in strings:
    result.text.get.add(fmt"{index + 1}) {choice}")
    if index + 1 != strings.len:
      result.text.get.add("\n")

proc applyVariable*(choice: Choice, variables: var Option[Table[string, string]], line: string) =
  if variables.isNone:
    variables = some(initTable[string, string]())
  variables.get[choice.input.get.variable] = line