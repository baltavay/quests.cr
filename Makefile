# Makefile for quests.cr
# A terminal-based quest management application

BINARY_NAME = quests
BINARY_PATH = ./bin/$(BINARY_NAME)
INSTALL_DIR = /usr/local/bin
CRYSTAL_FLAGS = --release

.PHONY: all build install uninstall clean test deps check-deps setup-ubuntu setup-fedora setup-arch setup-macos help

all: build

# Build the application
build:
	@echo "Building $(BINARY_NAME)..."
	shards build $(CRYSTAL_FLAGS)

# Check system dependencies
check-deps:
	@echo "Checking dependencies..."
	@command -v crystal >/dev/null || (echo "❌ Crystal not found. Install from: https://crystal-lang.org/install/" && exit 1)
	@echo "✅ Crystal found: $$(crystal --version)"
	@pkg-config --exists unibilium 2>/dev/null || (echo "❌ libunibilium-dev not found" && echo "Install with: sudo apt-get install libunibilium-dev (Ubuntu/Debian)" && exit 1)
	@pkg-config --exists readline 2>/dev/null || (echo "❌ libreadline-dev not found" && echo "Install with: sudo apt-get install libreadline-dev (Ubuntu/Debian)" && exit 1)
	@echo "✅ All system dependencies found"

# Install Crystal dependencies
deps: check-deps
	@echo "Installing Crystal dependencies..."
	shards install

# Quick setup for common platforms
setup-ubuntu:
	sudo apt-get update
	sudo apt-get install -y libunibilium-dev libreadline-dev
	curl -fsSL https://crystal-lang.org/install.sh | sudo bash
	shards install

setup-fedora:
	sudo dnf install -y unibilium-devel readline-devel crystal
	shards install

setup-arch:
	sudo pacman -S --noconfirm unibilium readline crystal
	shards install

setup-macos:
	brew install unibilium readline crystal
	shards install

# Run tests
test:
	@echo "Running tests..."
	crystal spec

# Install to system
install: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_DIR)..."
	@sudo cp $(BINARY_PATH) $(INSTALL_DIR)/$(BINARY_NAME)
	@sudo chmod +x $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "$(BINARY_NAME) has been installed to $(INSTALL_DIR)"
	@echo "You can now run '$(BINARY_NAME)' from anywhere"

# Uninstall from system
uninstall:
	@echo "Removing $(BINARY_NAME) from $(INSTALL_DIR)..."
	@sudo rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "$(BINARY_NAME) has been uninstalled"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf bin/
	@rm -rf lib/

# Show help
help:
	@echo "Available targets:"
	@echo "  build        - Build the application"
	@echo "  deps         - Install Crystal dependencies (after system deps)"
	@echo "  check-deps   - Check if all dependencies are installed"
	@echo "  test         - Run tests"
	@echo "  install      - Install to system (requires sudo)"
	@echo "  uninstall    - Remove from system (requires sudo)"
	@echo "  clean        - Clean build artifacts"
	@echo ""
	@echo "Platform-specific setup (installs everything):"
	@echo "  setup-ubuntu - Install all dependencies on Ubuntu/Debian"
	@echo "  setup-fedora - Install all dependencies on Fedora"
	@echo "  setup-arch   - Install all dependencies on Arch Linux"
	@echo "  setup-macos  - Install all dependencies on macOS"
	@echo ""
	@echo "Quick start:"
	@echo "  make setup-ubuntu && make build && make install"