import yaml/serialization
import options

type
  Path* = object
    file* {.defaultVal: none(string).}: Option[string]
    prompt*: string