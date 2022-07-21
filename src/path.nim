import yaml/serialization
import options

type Path* = object
  file* {.defaultVal: none(string).}: Option[string]
  prompt*: string

func matches*(path: Path, file: string, prompt: string, external: bool): bool =
  if (external and path.file.isNone) or (path.file.isSome and path.file.get != file):
    return false
  return path.prompt == prompt