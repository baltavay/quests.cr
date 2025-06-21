require "option_parser"
require "./quests"

# Command line interface for the Quests application
module Quests
  class CLI
    def self.run
      show_help = false
      show_version = false
      daily_mode = false

      parser = OptionParser.new do |parser|
        parser.banner = "Usage: quests [options]"

        parser.on("-h", "--help", "Show help") do
          show_help = true
        end

        parser.on("-v", "--version", "Show version") do
          show_version = true
        end

        parser.on("--daily", "Enable daily quests mode (date-based file naming)") do
          daily_mode = true
        end
      end

      begin
        parser.parse
      rescue ex : OptionParser::InvalidOption
        puts "Error: #{ex.message}"
        puts parser
        exit 1
      end

      if show_help
        puts parser
        exit 0
      end

      if show_version
        puts "Quests v#{VERSION}"
        exit 0
      end

      # Run the main application
      app = App.new(daily_mode: daily_mode)
      app.run
    rescue ex
      puts "Error: #{ex.message}"
      exit 1
    end
  end
end

# Run the CLI if this file is executed directly
Quests::CLI.run if PROGRAM_NAME.includes?("cli") || PROGRAM_NAME.includes?("quests")
