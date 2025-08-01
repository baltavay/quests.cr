# Quests 🗡️

A terminal-based quest management application built with Crystal and Crysterm.

[![Crystal CI](https://github.com/baltavay/quests.cr/workflows/Crystal%20CI/badge.svg)](https://github.com/baltavay/quests.cr/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✨ **Terminal UI** - Built with Crysterm with modern color scheme
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

![Quests Terminal UI](assets/images/screenshot.png)

## Installation

### From Source

#### Quick Install (Recommended)

For Ubuntu/Debian:
```bash
git clone https://github.com/baltavay/quests.cr
cd quests.cr
make setup-ubuntu && make build && make install
```

For other platforms:
```bash
git clone https://github.com/baltavay/quests.cr
cd quests.cr
# Choose your platform
make setup-fedora   # Fedora/RHEL
make setup-arch     # Arch Linux  
make setup-macos    # macOS
# Then build and install
make build && make install
```

#### Manual Install

1. Clone the repository:
```bash
git clone https://github.com/baltavay/quests.cr
cd quests.cr
```

2. Install system dependencies:
```bash
# Ubuntu/Debian
sudo apt-get install libunibilium-dev libreadline-dev

# Fedora
sudo dnf install unibilium-devel readline-devel

# Arch Linux
sudo pacman -S unibilium readline

# macOS
brew install unibilium readline
```

3. Install Crystal (if not already installed):
```bash
# See https://crystal-lang.org/install/ for your platform
```

4. Install Crystal dependencies:
```bash
make deps
```

5. Build the application:
```bash
make build
```

6. Install globally (optional):
```bash
make install
```

### As a Dependency

Add this to your application's `shard.yml`:

```yaml
dependencies:
  quests:
    github: baltavay/quests.cr
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
git clone https://github.com/baltavay/quests.cr
cd quests.cr
make deps
```

### Running Tests

```bash
make test
```

### Building

```bash
make build
```

### System Installation

Install globally to `/usr/local/bin`:

```bash
make install
```

Remove from system:

```bash
make uninstall
```

### Code Quality

```bash
# Format code
crystal tool format

# Lint code
ameba
```

### Makefile Commands

The project includes a Makefile with helpful commands:

```bash
make build        # Build the application
make deps         # Install Crystal dependencies (after system deps)
make check-deps   # Check if all dependencies are installed
make test         # Run tests
make install      # Install to system (requires sudo)
make uninstall    # Remove from system (requires sudo)
make clean        # Clean build artifacts

# Platform-specific setup (installs everything):
make setup-ubuntu # Install all dependencies on Ubuntu/Debian
make setup-fedora # Install all dependencies on Fedora
make setup-arch   # Install all dependencies on Arch Linux
make setup-macos  # Install all dependencies on macOS

make help         # Show all available commands
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

1. Fork it (<https://github.com/baltavay/quests.cr/fork>)
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

### Completed ✅
- [x] Terminal UI with modern color scheme
- [x] Unicode support for international characters  
- [x] Quest management (add, complete, delete)
- [x] Daily quests mode with date-based files
- [x] File browser and switching between quest files
- [x] Save As functionality
- [x] Unsaved changes tracking with visual indicators
- [x] Save prompts when quitting with unsaved work

### Planned 🚀
- [ ] Quest categories and tags
- [ ] Due dates and priorities
- [ ] Search and filtering within quests
- [ ] Import/export functionality (JSON/CSV)
- [ ] Multiple quest lists/projects
- [ ] Configuration file support
- [ ] Themes and color customization
- [ ] Quest templates and recurring tasks
- [ ] Statistics and progress tracking
- [ ] Keyboard shortcuts customization

---

Made with ❤️ and Crystal