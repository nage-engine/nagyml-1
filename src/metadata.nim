import yaml/serialization
import options, strformat, strutils, tables

import path

type
  HistoryConfig* = object
    locked* {.defaultVal: false.}: bool
    size* {.defaultVal: some(5).}: Option[int]

  Metadata* = object
    name*: string
    authors*: seq[string]
    version*: string
    background* {.defaultVal: none(string).}: Option[string]
    entry*: Path
    notes* {.defaultVal: none(seq[string]).}: Option[seq[string]]
    variables* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]
    save* {.defaultVal: true.}: bool
    debug* {.defaultVal: false.}: bool
    history* {.defaultVal: HistoryConfig(locked: false, size: some(5)).}: HistoryConfig

proc display*(metadata: Metadata): string =
  let authors = metadata.authors.join(", ")
  echo fmt"{metadata.name} {metadata.version} by {authors}"
  if metadata.background.isSome:
    echo "\n" & metadata.background.get