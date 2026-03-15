# anki-jp

Small shell-first shortcuts for fast Japanese card entry on top of the core `anki` CLI.

This repo provides the study-specific layer that used to live inside the core repo. It now depends on an installed `anki` command.

## Requirements

- `bash`
- installed `anki` core CLI available on `PATH`
- Anki running locally with the AnkiConnect add-on enabled
- optional: `gum` for nicer prompts during `anki-jp init` and missing-field entry

## Install

From this repository:

```sh
./install.sh
```

Make sure `~/.local/bin` is on your `PATH`.

If you want a custom prefix:

```sh
BIN_DIR="$HOME/bin" DATA_DIR="$HOME/.local/share/anki-jp" ./install.sh
```

If you use a custom `DATA_DIR`, also export:

```sh
export ANKI_JP_DATA_DIR="$HOME/.local/share/anki-jp"
```

## Commands

```sh
anki-jp init
anki-jp rtk festival 祭
anki-jp ww まつり 祭り festival
anki-jp wordwrite まつり 祭り festival
```

### `anki-jp init`

Interactive setup for:

- RTK deck and model
- RTK keyword and kanji fields
- WordWrite deck and model
- WordWrite reading, optional definition, and kanji fields

Configuration is stored in:

```text
~/.config/anki-jp/config
```

### `anki-jp rtk`

Adds an RTK note using the configured deck/model/field mapping.

### `anki-jp ww` / `anki-jp wordwrite`

Adds a WordWrite note using the configured deck/model/field mapping.

## Environment

- `ANKI_BIN`: override the `anki` binary path used by `anki-jp`
- `ANKI_JP_CONFIG`: override the config file path
- `ANKI_JP_DATA_DIR`: override where `anki-jp` looks for installed library files
- `ANKI_JP_DISABLE_GUM=1`: force plain shell prompts even if `gum` is installed

## How it integrates with `anki`

`anki-jp` uses the core CLI for all Anki operations:

- `anki deck list`
- `anki model list`
- `anki model fields <model>`
- `anki note add ...`
