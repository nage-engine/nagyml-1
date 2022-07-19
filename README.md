# nage

**N**ot **A**nother **G**ame **E**ngine

Well actually, it *is* a game engine. I just wanted to start with "N" because this is my first project using Nim.

The concept is heavily inspired by **[jage](https://github.com/acikek/jage)**, a data-driven *RPG* text adventure engine that was way out of its scope.

But I finished it this time! With **nage**, you can make fully data-driven and non-linear text adventure games with only YAML files.

## Creating a Game

A game's entrypoint is `nage.yml` in the working directory. It uses a metadata format with the following fields:

- `name`: The name of the game
- `authors`: A list of author(s) for the game to credit
- `version`: The game's version; doesn't follow any specific format, but SemVer is always good
- `background`: An optional introductory text that the game will display on first launch.
- `entry`: a `Path` object that controls the initial prompt container. A path has a `prompt` field and an optional (but required here) `file` field, but we'll talk more about that later.

Example:

```yml
name: The Wandering Warrior
authors:
  - acikek
version: v0.1.0
background: You are a warrior, wandering.
entry:
  file: main
  prompt: main
```

### Prompts

Each **nage** interaction is controlled by a **Prompt**, an object container that displays a few lines of text before presenting the player with **Choices**. Choices lead back to other prompts (or even the same prompts).

Prompts are not recursive; they don't hold sub-prompts. This allows for non-linear jumps with an added readability boost.

Additionally, all prompt files are located in the `prompts` directory. This can have as many subdirectories as you desire, since this directory is walked through recursively and combines all the filenames to file data in a single table. For this reason, you **cannot have any files with the same name**, regardless of subdirectory.

This is where the `Path` data comes in: the `file` field is the file name, and the `prompt` is the prompt name *in that file*.

Prompts and Choices share a common `Text` object type, which has two fields: `text`, which controls the content of the display, and `mode`, which controls how it's displayed. There are currently only two modes, `action`, which leaves the text as-is, and `dialogue` (default), which surrounds the text in quotes. You can use these together sequentially to break up prompts.

With all that out of the way, we can go over how Prompts and Choices are structured. Prompts have the following fields:

- `prompt`: A list of `Text` objects to display on entering the prompt
  - This is always optional, but should only be left out in case the game ends here.
- `choices`: A list of `Choice` objects

And Choices are much more complex, with the following fields:

- `response`: A single `Text` object, to be displayed alongside a list index
  - This can be optional, but **only** if there aren't any other choices. If left out, will skip any user input and jump straight to the next prompt. Mostly used alongside `display` for *redirect* functionality
- `jump`: A `Path` object that controls which prompt this choice should lead to
  - If the prompt is in the same file, `file` can be ommitted entirely!
  - If the `ending` field is present, this field is optional
  - The prompt validator will catch any mistakes you make, so don't worry about getting it right on the first try
- `display`: Whether to display the next prompt's intro text
- `notes`: A `Notes` object, controlling whether this prompt should be displayed and how it affects the player's state; covered in the [Notes](#Notes) section
- `input`: An `Input` object, controlling optional user input for variables; covered in the [Variables](#Variables) section
- `ending`: All games have to end somewhere! If this field is present, its content will be displayed to the player, and then the game will end (after saving).

Here is an example prompt object (without any notes):

```yml
main:
  prompt:
  - text: What brings you here?
  - text: He beckons you closer.
    mode: action
  choices:
  - response: 
      text: I'm just looking around.
    jump:
      prompt: looking_around
  - response: 
      text: I have work to do.
    jump:
      prompt: work_to_do
  - response:
      text: Run away due to social anxiety
      mode: action
```

### Notes

Notes are mutable state on a player that can be used to conditionally reveal or hide choices. You can add and remove notes, and require notes to be present or not present on a player. They are stored as plaintext strings in a list, so make sure they're unique throughout the game.

Each choice has an optional `notes` field which is a `Notes` object. Those contain the following fields, both optional:

- `require`: A list of `NoteRequirement`s, which have the following fields:
  - `name`: The name of the note, matches exactly
  - `has`: Whether the player should have the note, `true` by default; must match exactly to pass
- `apply`: A list of `NoteApplication`s, which have the following fields:
  - `name`: The name of the note
  - `take`: Whether to take the note from the player, `false` by default (which means it gives the note)
- `once`: A note name. Upon using this choice, the player gains the specified note; however, whenever the player is presented with this choice, and they have this note, the choice will be hidden. This makes it a pick-once choice, and is equivalent to:

```yml
notes:
  require:
  - name: thing
    has: false
  apply:
  - name: thing
```

It's up to you to design the best note approach for your game, but know that you can do some pretty advanced stuff with them!

### Variables

Variables are permanent state, like notes, but for **display purposes only**. They take direct user input and store the result on the player data, with the only validation being the result is not empty. They can be interpolated in any display string except a game's background.

To take user input, create a single-choice prompt with an `input` field instead of `response`. An input object has the following fields:

- `text`: An optional string, **not** a text object, that acts as an additional input prompt. Appends a colon `:` automatically
- `variable`: The name of the variable to store the result in

Here's an example input prompt:

```yml
ask_for_name:
  prompt:
  - text: What should I call you?
  choices:
  - input:
      text: Enter your name
      variable: name
    jump:
      prompt: main
```

To interpolate variables into text strings, simply wrap the variable name (**case sensitive**) in angle brackets (`< >`).

- If no variables exist on the player, **nage** won't bother modifying the text whatsoever.
- If variables exist, but an invalid variable name is provided, the engine will fill it in with `UNDEFINED`.

Variables *are* actually variable; you can overwrite a variable's value at any time. Here's what it could look like when all put together, combined with the previous example:

```yml
main:
  prompt: 
  - text: Greetings, <name>. What brings you here?
  choices:
  - response:
      text: Actually, I go by a different name.
    display: false
    jump:
      prompt: ask_for_name
  - response:
      text: A fight to the death!
    jump: ...
```

### Extra Info

- Player data is stored in a `data.yml` file which is created after you first quit the game. Players shouldn't touch this, but they can if they really want to; the file is just more accessible than conventional games would allow. Players *especially* shouldn't be *encouraged* to modify the state in order to progress, unless your game is super meta or something.
- If a player runs into a situation where no choices are available, that's a bug, and you need to fix it. The game will shut down with a message telling the player to contact the author(s).
- A comprehensive example of a game is located in the aptly-named `game` directory, [found here](https://github.com/acikek/nage/game)! I'm not lying, it's all YAML!