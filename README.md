# vim-fold

Crude syntax folding for certain languages.

# Synopsis

This plugin attempts to improve syntax folding for certain languages I use semi-frequently or for languages I feel could benefit from it.

Some of the languages only have crude folding, such as folding on lines ending with a curly brace `{`.

Note that this plugin isn't considered "complete" by any means and contains a number of personal stylistic choices on what to fold and when.

# Prerequisites

You must have `filetype` detection enabled:

```vim
filetype on
```

# Supported Languages

| Language    | `filetype`    |
| ----------- | ------------- |
| Python      | `python`      |
| Java        | `java`        |
| Javascript  | `javascript ` |
| Markdown    | `markdown`    |
| vim         | `vim`         |
| PL/SQL      | `plsql`       |
| Bash        | `sh`          |
| Perl        | `perl`        |
| scarpet     | `scarpet`     |

# Manual Installation

Copy the `fold` directory into your `.vim/pack` directory.

# Usage

This plugin acts on the `FileType` autocommand. If you need to initialize the plugin after loading a file, simply invoke `:setf <yourfiletype>` again.

## Variables

| Variable                | Value  | Description |
| ----------------------- | ------ |----------- |
| `g:vimfold_disable`     | 0 or 1 | If set to anything, disable this plugin entirely |
| `g:vimfold_line_enable` | 0 or 1 | Allow in-file modeline-like configuration (dangerous; see below) |
| `g:vimfold_sec_open`    | string | Section open string; default is `{{{` |
| `g:vimfold_sec_close`   | string | Section close string; default is `}}}` |
| `g:vimfold_mapleader`   | string | Use a specific mapleader instead of the default |

## Fold Options

You can enable these options by calling `VimFold_SetOpt(<option>)`.

| Option        | Result |
| ------------- | ------ |
| `"debug"`     | Enable certain diagnostics |
| `"sections"`  | Include sections when folding (see `g:vimfold_sec_*` above) |
| `"nosync"`    | Disable calling `syn sync fromstart` after folding |

## Modeline-like Behavior

Files are parsed upon loading for lines matching the following:

`<any><space>vim-fold-opt:<space><options>`

`<any><space>vim-fold-opt-set:<space><options>:<any-nocolon>`

With `g:vimfold_line_enable == 1`, the following are also included (dangerous; see *Warnings* below):

`<any><space>vim-fold:<space><pattern>`

`<any><space>vim-fold-set:<space><pattern>:<any-nocolon>`

where

`<any>` is a sequence of zero or more characters,

`<space>` is a sequence of one or more spaces,

`<pattern>` is a sequence of one or more characters,

`<options>` is a sequence of one or more characters,

`<any-nocolon>` is a sequence of one or more characters, excluding the colon `:`.

See the `g:vimfold*_pattern` definitions in `fold.vim`.

# Warnings

As of version 1.10, both `vim-fold:` and `vim-fold-set:` use `execute` and therefore can be used for arbitrary code execution. Do not set `g:vimfold_line_enable` unless you trust every file you edit not to include malicious code.

# Bugs and Other Issues

(1.10) Need to add a help file to the `doc` folder.

(1.10) Handling of `vim-fold:` and `vim-fold-set:` lines should not use `execute`.

