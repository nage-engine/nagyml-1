type
  Metadata = object
    name: string
    authors: seq[string]
    version: string
    background {.defaultVal: none(string).}: Option[string]
    entry: Path

proc display(metadata: Metadata): string =
  let authors = metadata.authors.join(", ")
  echo fmt"{metadata.name} {metadata.version} by {authors}"
  if metadata.background.isSome:
    echo "\n" & metadata.background.get