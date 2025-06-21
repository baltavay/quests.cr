# Quests 🗡️

A terminal-based quest management application built with Crystal and Crysterm.

[![Crystal CI](https://github.com/your-username/quests.cr/workflows/Crystal%20CI/badge.svg)](https://github.com/your-username/quests.cr/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✨ **Terminal UI** - Built with Crysterm using Tokyo Night color scheme
- 🌍 **Unicode Support** - Full support for international characters including Russian, Chinese, etc.
- ⚔️ **Quest Management** - Add, complete, and delete quests with ease
- 🎮 **Flexible Navigation** - Both vim-style (j/k) and arrow key navigation
- 📅 **Daily Quests Mode** - Date-based quest tracking with `--daily` flag
- 💾 **Smart Saving** - Save to `quests.txt` or date-based files with auto-save prompts
- 📝 **Save As** - Save quests to custom filenames with `w` key
- 📁 **File Browser** - Switch between quest files with Tab key
- ⚠️ **Unsaved Changes Tracking** - Visual indicators (*) and save prompts for unsaved work
- 🚀 **Fast & Lightweight** - Written in Crystal for excellent performance

## Screenshots

```
┌────────────────────────────────────────────┐
│[ ] Buy milk                                │
│[✓] Read Crystal docs                       │
│[ ] Learn terminal UI development           │
│[✓] Build awesome quest tracker            │
│                                            │
│  No quests yet. Press 'a' to begin your   │
│  adventure!                                │
└────────────────────────────────────────────┘
j/k/arrows: navigate, a: add quest, d: delete, x: complete, Ctrl+S: save, w: save as, Tab: files, q: quit
```

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/your-username/quests.cr
cd quests.cr
```

2. Install dependencies:
```bash
shards install
```

3. Build the application:
```bash
shards build
```

4. Run:
```bash
./bin/quests
```

### As a Dependency

Add this to your application's `shard.yml`:

```yaml
dependencies:
  quests:
    github: your-username/quests.cr
```

Then run:
```bash
shards install
```

## Usage

### Command Line Interface

```bash
# Run the application (saves to quests.txt)
quests

# Run in daily quests mode (saves to daily-quests-YYYY-MM-DD.txt)
quests --daily

# Show help
quests --help

# Show version
quests --version
```

### Navigation Controls

| Key | Action |
|-----|--------|
| `j` / `↓` | Move down |
| `k` / `↑` | Move up |
| `a` | Add new quest |
| `d` | Delete selected quest |
| `x` | Toggle quest completion |
| `Ctrl+S` | Save quests to file |
| `w` | Save as (save with new filename) |
| `Tab` | Switch between quest list and files |
| `Enter` | Save quest (when adding) / Load file (in files view) |
| `Escape` | Cancel (when adding quest / save as) |
| `q` | Quit application (prompts to save if unsaved changes) |

### File Format

Quests are saved in a simple text format:

```
# Quests saved at 2024-01-15 14:30:25

[ ] Buy groceries
[✓] Learn Crystal programming
[ ] Build quest tracker
[✓] Add file saving feature
```

#### File Naming

- **Regular mode**: `quests.txt` (overwrites each save)
- **Daily mode** (`--daily`): `daily-quests-YYYY-MM-DD.txt` (one file per day)
- **Save As**: Custom filename with `.txt` extension automatically added

#### Unsaved Changes

The application tracks unsaved changes and provides helpful prompts:

- **Visual indicator**: Window title shows `*` when there are unsaved changes (e.g., "Quests *")
- **Save prompt**: When quitting with unsaved changes, you'll get options to:
  - `s` - Save and quit
  - `y` - Quit without saving
  - `n` - Cancel and return to the app
- **Auto-tracking**: Changes are automatically detected when adding, deleting, or completing quests

### As a Library

```crystal
require "quests"

# Create a new quest
quest = Quests::Quest.new("Learn Crystal programming")
puts quest.completed  # => false

# Mark as completed
quest.complete!
puts quest.completed  # => true

# Create and run the app
app = Quests::App.new
app.run
```

## Development

### Prerequisites

- Crystal >= 1.16.3
- Git

### Setup

```bash
git clone https://github.com/your-username/quests.cr
cd quests.cr
shards install
```

### Running Tests

```bash
crystal spec
```

### Building

```bash
shards build
```

### Code Quality

```bash
# Format code
crystal tool format

# Lint code
ameba
```

## API Documentation

### `Quests::Quest`

Represents a single quest item.

#### Methods

- `#initialize(title : String, completed : Bool = false)` - Create a new quest
- `#complete!` - Mark quest as completed
- `#incomplete!` - Mark quest as incomplete  
- `#toggle!` - Toggle completion status
- `#to_s(io)` - String representation

#### Properties

- `title : String` - The quest title/description
- `completed : Bool` - Whether the quest is completed

### `Quests::App`

Main application class providing the terminal interface.

#### Methods

- `#initialize` - Create new app instance with default quests
- `#run` - Start the application main loop

## Contributing

1. Fork it (<https://github.com/your-username/quests.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Write tests for your changes
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request

### Development Guidelines

- Follow Crystal's style guide
- Add tests for new functionality
- Update documentation for API changes
- Ensure all tests pass before submitting PR

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Crysterm](https://github.com/crystallabs/crysterm) - Terminal UI toolkit for Crystal
- Inspired by classic terminal applications and modern quest management tools
- Thanks to the Crystal community for creating an amazing language

## Roadmap

- [ ] Persistent storage (JSON/YAML files)
- [ ] Quest categories and tags
- [ ] Due dates and priorities
- [ ] Import/export functionality
- [ ] Multiple quest lists
- [ ] Search and filtering
- [ ] Configuration file support
- [ ] Themes and customization

---

Made with ❤️ and Crystal