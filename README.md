# dap-debugee-selector

A Neovim plugin that helps you find and select executables for debugging via [nvim-dap](https://github.com/mfussenegger/nvim-dap), with CMake preset support and a persistent argument history.

> **Note:** This plugin is tailored to a specific workflow (CMake / macOS / Linux). Use at your own risk.

---

## Features

- Browse and select executables from a configurable search path
- Argument picker with persistent per-executable history
- CMake preset support (configure and auto-detect the build directory)
- State is persisted per project (working directory) across Neovim sessions
- `checkhealth` support

---

## Requirements

- Neovim ≥ 0.9
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

---

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "your-username/dap-debugee-selector",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "mfussenegger/nvim-dap",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("telescope").load_extension("debugee_selector")
  end,
}
```

---

## Usage

All commands are exposed as Telescope extension exports.

### Select a debuggable executable

Opens a Telescope picker that scans the configured search path for executable files. After selecting an executable, the [argument picker](#argument-picker) opens automatically.

```lua
require("telescope").extensions.debugee_selector.show_debugee_candidates()
```

### Set the search path via CMake preset

Opens a picker listing all available CMake presets. Selecting a preset runs `cmake --preset=<name>`, and the resulting build directory is used as the search path for executables.

```lua
require("telescope").extensions.debugee_selector.selectSearchPathRoot()
```

### Edit debugee arguments (without re-selecting the executable)

Opens the [argument picker](#argument-picker) for the last selected executable.

```lua
require("telescope").extensions.debugee_selector.edit_debugee_args()
```

### Reset the search path

Clears the stored search path root so the next invocation of `show_debugee_candidates` will ask for a new path.

```lua
require("telescope").extensions.debugee_selector.reset_search_path()
```

### Reset debugee arguments

Clears the stored argument string for the current session.

```lua
require("telescope").extensions.debugee_selector.reset_debugee_args()
```

### Get last selected values (e.g. for status lines)

```lua
local ext = require("telescope").extensions.debugee_selector
local program   = ext.get_last_program()       -- full path to the executable
local args      = ext.get_last_debugee_args()  -- argument string
```

---

## Argument Picker

The argument picker shows the full history of previously used argument strings for the selected executable. It works as a combined list + edit field in a single step:

| Key | Action |
|-----|--------|
| `<Up>` / `<Down>` | Navigate history — the selected entry is copied into the prompt |
| Type freely | Edit the argument string directly in the prompt |
| `<Enter>` | Confirm the current prompt text as the argument string |
| `<C-n>` | Clear the prompt to enter a completely new argument string |
| `<C-d>` | Delete the highlighted history entry |
| `<Esc>` | Close without changes |

**History rules:**
- Arguments are stored per executable path.
- Duplicate entries are never added — if the confirmed string already exists in the history it is moved to the top instead.
- Empty strings are not stored.
- History is persisted across Neovim sessions, keyed by the current working directory.

---

## Excluded File Patterns

The executable finder automatically hides files whose paths match any of the following patterns to reduce noise:

- `Frameworks`
- `plugins ` (with trailing space)
- `CMakeFiles`
- `.dylib`
- `jdk/bin`
- `jdk/lib`
- `Resources`

---

## Health Check

Run `:checkhealth dap-debugee-selector` to verify that all dependencies are available.

---

## License

MIT

