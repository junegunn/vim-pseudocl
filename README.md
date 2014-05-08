vim-pseudocl: Pseudo-command-line interface
===========================================

vim-pseudocl implements a command-line interface that mimics the native Vim
command-line. It enables writing advanced command-line features with its
callback functions.

Usage
-----

`pseudocl#start` function will start the pseudo-command-line. It returns
user-typed string or throws 'exit' on escape key or on interrupt.

```vim
try
  let got = pseudocl#start(options)
catch 'exit'
  call pseudocl#render#clear()
  echon 'No input'
endtry
```

The following table summarizes the dictionary parameter to `pseudocl#start`
function.

| Option name    | Type    | Default                | Description                                                 |
| -------------- | ------  | ---------------------- | ----------------------------------------------------------- |
| prompt         | String  | `':'`                  | Command-line prompt in string                               |
| prompt         | List    | `['None', ':']`        | Sequence of highlight group and string pairs                |
| highlight      | String  | `None`                 | Highlight group for command-line                            |
| input          | String  | `''`                   | Initial input string                                        |
| on_change      | Funcref | `pseudocl#nop`         | Callback function invoked on change (new, old, cursor)      |
| on_unknown_key | Funcref | `pseudocl#nop`         | Callback function invoked on unknown key (key, str, cursor) |
| renderer       | Funcref | `pseudocl#render#echo` | Command-line renderer (prompt, line, cursor)                |
| remap          | Dict    | `{}`                   | Remap keys                                                  |
| map            | Boolean | `1`                    | To use command-line maps or not                             |
| history        | List    | `[]`                   | Command-line history                                        |
| words          | List    | `[]`                   | Words for tab completion                                    |

API
---

### Main

- `pseudocl#start()`

### Render

- `pseudocl#render#echo()`
    - `pseudocl#render#echo_prompt()`
    - `pseudocl#render#echo_line()`
- `pseudocl#render#clear()`

### Complete

- `pseudocl#complete#extract_words()`

License
-------

MIT

