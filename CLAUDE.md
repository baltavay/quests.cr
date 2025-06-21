# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Crystal language shard called `quests` that provides a terminal-based quest management application with Tokyo Night color scheme. It supports both regular quest tracking and daily quest mode. It's structured as a proper Crystal shard with a clean module hierarchy, comprehensive documentation, and tests.

**Main entry points**: 
- CLI: `src/cli.cr` - Command line interface
- Library: `src/quests.cr` - Main module for library usage

## Architecture

- **Modern terminal UI**: Built using Crysterm library for proper curses-like functionality
- **Proper shard structure**: Organized as `Quests` module with sub-classes
- **CLI + Library**: Can be used as both standalone application and library dependency
- **Unicode support**: Full UTF-8 support including Russian and other international characters
- **Comprehensive testing**: Full spec coverage with examples

## Module Structure

```
src/
├── cli.cr              # CLI entry point
├── quests.cr           # Main module file
└── quests/
    ├── version.cr      # Version constant
    ├── quest.cr        # Quest class
    └── app.cr          # Terminal application
```

## Development Commands

### Build and Run
```bash
shards build
./bin/quests          # Regular mode
./bin/quests --daily  # Daily quests mode
```

### Run directly
```bash
crystal run src/cli.cr
crystal run src/cli.cr -- --daily  # Daily mode
```


### Run tests
```bash
crystal spec
```

### Dependencies
```bash
shards install
```

## Dependencies

The project includes several Crystal libraries in the `lib/` directory:
- **crysterm**: Terminal UI framework (comprehensive TUI library)
- **tput**: Terminal capabilities
- **term-screen**: Screen management
- **event_handler**: Event handling system
- **unibilium**: Terminal information library

## Navigation Controls

- `j/k` or `↑/↓ arrows`: Navigate up/down through quests
- `a`: Add new quest
- `d`: Delete selected quest  
- `x`: Mark quest as completed/incomplete
- `Ctrl+S`: Save current quests to timestamped file
- `Tab`: Switch between quest list and saved files view
- `Enter`: Save quest (when adding) / Load selected file (in files view)
- `Escape`: Cancel when adding new quest
- `q`: Quit application

## Features

- **Quest Management**: Add, delete, and toggle completion status of quests
- **Visual Indicators**: Uses checkmark (✓) for completed quests, color highlighting for selection
- **Tokyo Night Theme**: Consistent color scheme with blue accents, green for completed items, purple for selected items, no visual distortion
- **Daily Quests Mode**: Date-based quest tracking with `--daily` flag
- **Smart File Handling**: Saves to `quests.txt` (regular) or `daily-quests-YYYY-MM-DD.txt` (daily)
- **File Browser**: Switch between different saved quest files with Tab
- **International Support**: Full Unicode support for quest titles in any language
- **Context-Sensitive UI**: Help text and colors change based on current mode and window
- **Dual Window System**: Main quest view and file browser view