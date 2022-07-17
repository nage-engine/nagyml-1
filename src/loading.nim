import yaml/serialization, streams
import results

import tables, os, options, strformat

const PROMPTS_DIR*: string = "prompts"
const GAME_DATA*: string = "nage.yml"
const PLAYER_DATA*: string = "data.yml"

proc loadObject*[T](path: string): Result[T, string] =
  var file = newFileStream(path)
  if file == nil:
    return err(fmt"'{path}' doesn't exist!")
  try:
    var parsed: T
    load(file, parsed)
    result = ok(parsed)
    file.close
  except:
    result = err(fmt"Error while loading '{path}': {getCurrentExceptionMsg()}")