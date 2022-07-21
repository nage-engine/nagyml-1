import yaml/serialization
import options, strformat, strutils, tables

import path

type Metadata* = object
  name*: string
  authors*: seq[string]
  version*: string
  background* {.defaultVal: none(string).}: Option[string]
  entry*: Path
  notes* {.defaultVal: none(seq[string]).}: Option[seq[string]]
  variables* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]
  save* {.defaultVal: true.}: bool
  debug* {.defaultVal: false.}: bool

proc display*(metadata: Metadata): string =
  let authors = metadata.authors.join(", ")
  echo fmt"{metadata.name} {metadata.version} by {authors}"
  if metadata.background.isSome:
    echo "\n" & metadata.background.get