require "../../lib/crysterm/src/crysterm"

module Quests
  class App
    include Crysterm

    @main_box : Widget::Box
    @help_box : Widget::Box
    @input_box : Widget::TextBox
    @files_box : Widget::Box
    @current_file : String?
    @selected_quest : Int32
    @selected_file : Int32
    @has_unsaved_changes : Bool
    @confirmation_mode : String?
    @save_as_mode : Bool

    def initialize(daily_mode = false)
      @quests = [] of Quest
      @selected_quest = 0
      @selected_file = 0
      @input_mode = false
      @current_window = :main
      @quest_files = [] of String
      @daily_mode = daily_mode
      @current_file = nil
      @has_unsaved_changes = false
      @confirmation_mode = nil
      @save_as_mode = false

      @screen = Screen.new title: get_window_title, show_fps: nil

    # Main container - Tokyo Night styling
    @main_box = Widget::Box.new(
      parent: @screen,
      top: 0,
      left: 0,
      width: "100%",
      height: "100%-3",
      style: Style.new(
        border: true,
        fg: "#c0caf5",     # Tokyo Night foreground
        bg: "#1a1b26"      # Tokyo Night background
      ),
      content: "",
      align: Tput::AlignFlag::Top | Tput::AlignFlag::Left  # Ensure left alignment
    )

    # Help text - Tokyo Night styling
    @help_box = Widget::Box.new(
      parent: @screen,
      top: "100%-3",
      left: 0,
      width: "100%",
      height: 1,
      content: "j/k/arrows: navigate, a: add quest, d: delete, x: complete, Ctrl+S: save, Tab: files, q: quit",
      style: Style.new(
        fg: "#7aa2f7",     # Tokyo Night blue accent
        bg: "#1a1b26"      # Tokyo Night background
      )
    )

    # Input box (initially hidden) - Tokyo Night styling
    @input_box = Widget::TextBox.new(
      parent: @screen,
      top: "100%-2",
      left: 0,
      width: "100%",
      height: 1,
      style: Style.new(
        fg: "#c0caf5",     # Tokyo Night foreground (light text)
        bg: "#414868"      # Tokyo Night blue-gray for input field
      )
    )
    @input_box.hide

    # Files window (initially hidden) - Tokyo Night styling
    @files_box = Widget::Box.new(
      parent: @screen,
      top: 0,
      left: 0,
      width: "100%",
      height: "100%-3",
      style: Style.new(
        border: true,
        fg: "#c0caf5",     # Tokyo Night foreground
        bg: "#1a1b26"      # Tokyo Night background
      ),
      content: ""
    )
    @files_box.hide

    setup_events
    load_quest_files
    load_initial_quests
    update_display
  end

  private def setup_events
    @screen.on(Event::KeyPress) do |e|
      handle_keypress(e)
    end

    @input_box.on(Event::KeyPress) do |e|
      handle_input_keypress(e)
    end
  end

  private def handle_keypress(e)
    return if @input_mode

    # Handle confirmation mode first
    if @confirmation_mode
      handle_confirmation_keys(e)
      return
    end

    # Global hotkeys
    case e.key
    when Tput::Key::CtrlS
      save_quests
      return
    when Tput::Key::Tab
      toggle_window
      return
    end


    if @current_window == :main
      handle_main_window_keys(e)
    else
      handle_files_window_keys(e)
    end
  end

  private def handle_main_window_keys(e)
    # Reset help text if it shows loading info
    if @help_box.content.includes?("Loaded:")
      update_help_text
    end

    case e.char
    when 'q'
      if @has_unsaved_changes
        @confirmation_mode = "quit"
        @help_box.content = "Unsaved changes! Press 's' to save, 'y' to quit anyway, 'n' to cancel"
        @screen.render
      else
        @screen.destroy
        exit
      end
    when 'j'
      @selected_quest = (@selected_quest + 1) % @quests.size if @quests.size > 0
      update_display
    when 'k'
      @selected_quest = (@selected_quest - 1) % @quests.size if @quests.size > 0
      update_display
    when 'a'
      enter_input_mode
    when 'w'
      enter_save_as_mode
    when 'd'
      if @quests.size > 0
        @quests.delete_at(@selected_quest)
        @selected_quest = @selected_quest - 1 if @selected_quest >= @quests.size
        @has_unsaved_changes = true
        update_window_title
        update_display
      end
    when 'x'
      if @quests.size > 0
        @quests[@selected_quest].completed = !@quests[@selected_quest].completed
        @has_unsaved_changes = true
        update_window_title
        update_display
      end
    end

    # Handle arrow keys
    case e.key
    when Tput::Key::Down
      @selected_quest = (@selected_quest + 1) % @quests.size if @quests.size > 0
      update_display
    when Tput::Key::Up
      @selected_quest = (@selected_quest - 1) % @quests.size if @quests.size > 0
      update_display
    end

    # Reset help text after any key press
    if @help_box.content.includes?("Loaded:")
      update_help_text
    end
  end

  private def handle_files_window_keys(e)
    case e.char
    when 'q'
      @screen.destroy
      exit
    when 'j'
      @selected_file = (@selected_file + 1) % @quest_files.size if @quest_files.size > 0
      update_files_display
    when 'k'
      @selected_file = (@selected_file - 1) % @quest_files.size if @quest_files.size > 0
      update_files_display
    when '\r', '\n' # Enter key
      load_selected_quest_file if @quest_files.size > 0
    end

    # Handle arrow keys
    case e.key
    when Tput::Key::Down
      @selected_file = (@selected_file + 1) % @quest_files.size if @quest_files.size > 0
      update_files_display
    when Tput::Key::Up
      @selected_file = (@selected_file - 1) % @quest_files.size if @quest_files.size > 0
      update_files_display
    when Tput::Key::Enter
      load_selected_quest_file if @quest_files.size > 0
    end
  end

  private def handle_input_keypress(e)
    if e.key == Tput::Key::Enter
      if @save_as_mode
        filename = @input_box.value.strip
        if !filename.empty?
          save_as(filename)
        end
        exit_save_as_mode
      else
        new_quest = @input_box.value.strip
        if !new_quest.empty?
          @quests << Quest.new(new_quest)
          @has_unsaved_changes = true
          update_window_title
        end
        exit_input_mode
        update_display
      end
    elsif e.key == Tput::Key::Escape
      if @save_as_mode
        exit_save_as_mode
      else
        exit_input_mode
      end
    end
  end

  private def enter_input_mode
    @input_mode = true
    @input_box.show
    @input_box.value = ""
    @input_box.focus
    @help_box.content = "Enter new quest (Enter: save, Escape: cancel)"
    @screen.render
  end

  private def exit_input_mode
    @input_mode = false
    @main_box.focus
    @input_box.hide
    update_help_text
    @screen.render
  end

  private def enter_save_as_mode
    @save_as_mode = true
    @input_mode = true
    @input_box.show
    @input_box.value = ""
    @input_box.focus
    @help_box.content = "Save as filename (Enter: save, Escape: cancel)"
    @screen.render
  end

  private def exit_save_as_mode
    @save_as_mode = false
    @input_mode = false
    @main_box.focus
    @input_box.hide
    update_help_text
    @screen.render
  end

  private def save_as(filename : String)
    return if @quests.empty?
    
    # Add .txt extension if not present
    filename = filename.ends_with?(".txt") ? filename : "#{filename}.txt"
    
    File.write(filename, build_quest_file_content)
    @current_file = filename
    @has_unsaved_changes = false
    update_window_title
    
    # Update files list and refresh display
    load_quest_files
    @help_box.content = "Saved as #{filename}"
    @screen.render
    
    # Reset help text after 2 seconds
    spawn do
      sleep 2.seconds
      update_help_text
      @screen.render
    end
  end

  private def save_quests
    return if @quests.empty?

    # Use currently loaded file if available, otherwise use default based on mode
    filename = @current_file || if @daily_mode
      date = Time.local.to_s("%Y-%m-%d")
      "daily-quests-#{date}.txt"
    else
      "quests.txt"
    end

    File.write(filename, build_quest_file_content)
    @current_file = filename  # Update current file reference
    @has_unsaved_changes = false  # Mark as saved
    update_window_title

    # Update files list and refresh display
    load_quest_files
    @help_box.content = "Saved to #{filename}"
    @screen.render

    # Reset help text after 2 seconds
    spawn do
      sleep 2.seconds
      update_help_text
      @screen.render
    end
  end

  private def build_quest_file_content
    content = String.build do |str|
      str << "# Quests saved at #{Time.local}\n\n"
      @quests.each do |quest|
        status = quest.completed ? "[✓]" : "[ ]"
        str << "#{status} #{quest.title}\n"
      end
    end
    content
  end

  private def load_quest_files
    if @daily_mode
      @quest_files = Dir.glob("daily-quests-*.txt").sort.reverse
    else
      # For regular mode, show all quest files: main file, daily files, and legacy files
      files = [] of String
      files << "quests.txt" if File.exists?("quests.txt")
      files.concat(Dir.glob("daily-quests-*.txt").sort.reverse)
      files.concat(Dir.glob("quests-*.txt").sort.reverse)
      @quest_files = files
    end
  end

  private def load_initial_quests
    filename = if @daily_mode
      # Load today's daily quest file if it exists
      date = Time.local.to_s("%Y-%m-%d")
      "daily-quests-#{date}.txt"
    else
      # Load the main quests.txt file
      "quests.txt"
    end

    if File.exists?(filename)
      load_quest_file(filename)
    end
  end

  private def load_quest_file(filename)
    return unless File.exists?(filename)

    content = File.read(filename)
    @quests.clear

    content.each_line do |line|
      line = line.strip
      next if line.empty? || line.starts_with?("#")

      if line.starts_with?("[✓]")
        title = line[4..-1].strip
        @quests << Quest.new(title, completed: true)
      elsif line.starts_with?("[ ]")
        title = line[4..-1].strip
        @quests << Quest.new(title, completed: false)
      end
    end

    @selected_quest = 0
    @current_file = filename  # Track which file is currently loaded
    @has_unsaved_changes = false  # Mark as saved when loading
    update_window_title
  end

  private def toggle_window
    if @current_window == :main
      @current_window = :files
      @main_box.hide
      @files_box.show
      @selected_file = 0
      update_files_display
    else
      @current_window = :main
      @files_box.hide
      @main_box.show
      @selected_quest = [@selected_quest, @quests.size - 1].min if @quests.size > 0
      update_display
    end
    update_help_text
    @screen.render
  end

  private def load_selected_quest_file
    return if @selected_file >= @quest_files.size || @quest_files.empty?

    filename = @quest_files[@selected_file]
    file_index = @selected_file  # Save the file index before switching windows

    if File.exists?(filename)
      load_quest_file(filename)
    else
      @help_box.content = "Error: File #{filename} not found"
    end

    @current_window = :main
    @files_box.hide
    @main_box.show
    update_display

    # Show which file was loaded (don't reset immediately)
    @help_box.content = "Loaded: #{@current_file} [#{file_index + 1}/#{@quest_files.size}] (#{@quests.size} quests) - Press any key to continue"
    @screen.render
  end

  private def update_help_text
    case @current_window
    when :main
      @help_box.content = "j/k/arrows: navigate, a: add quest, d: delete, x: complete, Ctrl+S: save, w: save as, Tab: files, q: quit"
    when :files
      @help_box.content = "j/k/arrows: navigate, Enter: load file, Tab: back to quests, q: quit"
    end
  end

  private def update_files_display
    content = String.build do |str|
      if @quest_files.empty?
        str << "  No quest files found.\n"
        str << "  Save some quests with Ctrl+S to see them here.\n"
      else
        mode_name = @daily_mode ? "Daily Quest Files" : "Quest Files"
        str << "  #{mode_name} (#{@quest_files.size} found):\n\n"
        @quest_files.each_with_index do |file, idx|

          if file == "quests.txt"
            line = "Main Quest File - #{file}"
          elsif match = file.match(/daily-quests-(\d{4}-\d{2}-\d{2})\.txt/)
            date = match[1].gsub("-", "/")
            line = "#{date} - #{file}"
          elsif match = file.match(/quests-(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})\.txt/)
            date = match[1].gsub("-", "/")[0..9] + " " + match[1].gsub("-", ":")[11..-1]
            line = "#{date} - #{file}"
          else
            line = file
          end

          if idx == @selected_file
            # Selected file: arrow indicator
            str << "→ #{line}\n"
          else
            # Regular file: standard spacing
            str << "  #{line}\n"
          end
        end
      end
    end

    @files_box.set_content content
    @screen.render
  end

  private def update_display
    content = String.build do |str|
      @quests.each_with_index do |quest, idx|
        # Create uniform format for all lines - exactly the same structure
        marker = quest.completed ? "[✓]" : "[ ]"
        title = quest.title

        # Simple visual indicators without complex color tags
        if idx == @selected_quest
          # Selected quest: add arrow indicator
          str << "→ #{marker} #{title}\n"
        elsif quest.completed
          # Completed quest: already has checkmark, no extra formatting needed
          str << "  #{marker} #{title}\n"
        else
          # Regular quest: standard formatting
          str << "  #{marker} #{title}\n"
        end
      end

      if @quests.empty?
        mode_text = @daily_mode ? "daily quests" : "quests"
        str << "  No #{mode_text} yet. Press 'a' to begin!\n"
      end
    end

    @main_box.set_content content
    @screen.render
  end

  private def get_window_title
    base_title = @daily_mode ? "Daily Quests" : "Quests"
    if @has_unsaved_changes
      "#{base_title} *"
    else
      base_title
    end
  end

  private def update_window_title
    @screen.title = get_window_title
  end

  private def handle_confirmation_keys(e)
    case @confirmation_mode
    when "quit"
      case e.char
      when 's'
        save_quests
        @screen.destroy
        exit
      when 'y'
        @screen.destroy
        exit
      when 'n'
        @confirmation_mode = nil
        update_help_text
        @screen.render
      end
    end
  end

  def run
    @main_box.focus
    @screen.exec
  end
  end
end

