import yaml/serialization

import options, strformat, strutils, sequtils, sugar

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

  Choice* = object
    response* {.defaultVal: none(Text).}: Option[Text]
    jump* {.defaultVal: none(Path).}: Option[Path]
    display* {.defaultVal: true.}: bool
    notes* {.defaultVal: none(Notes).}: Option[Notes]
    ending* {.defaultVal: none(string).}: Option[string]

proc display*(choices: seq[Choice]): string =
  let strings = choices
    .filter(c => c.response.isSome)
    .map(c => c.response.get.display())
  for index, choice in strings:
    result.add(fmt"{index + 1}) {choice}")
    if index + 1 != strings.len:
      result.add("\n")