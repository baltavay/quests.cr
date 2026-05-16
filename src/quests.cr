require "ori"
require "json"
require "option_parser"
require "time"

DATA_DIR  = File.join(ENV["HOME"]? || "/tmp", ".local/share/quests")
DATA_FILE = File.join(DATA_DIR, "data.json")

module OmarchyTheme
  COLORS_PATH = File.join(ENV["HOME"]? || "/tmp", ".config/omarchy/current/theme/colors.toml")

  FALLBACK = {
    "accent"     => "#7D56F4",
    "foreground" => "#DDD",
    "background" => "#1A1530",
    "color0"     => "#32344a",
    "color1"     => "#FF6B6B",
    "color2"     => "#6BCB77",
    "color3"     => "#FFD93D",
    "color4"     => "#7D56F4",
    "color5"     => "#AD8EE6",
    "color6"     => "#449DAB",
    "color7"     => "#888",
    "color8"     => "#666",
    "color9"     => "#FF7A93",
    "color10"    => "#B9F27C",
    "color11"    => "#FF9E64",
    "color12"    => "#7DA6FF",
    "color13"    => "#BB9AF7",
    "color14"    => "#0DB9D7",
    "color15"    => "#ACB0D0",
    "cursor"     => "#C0CAF5",
    "sel_fg"     => "#FFF",
    "sel_bg"     => "#2A2040",
    "dim_fg"     => "#AAA",
    "mid_fg"     => "#BBB",
  } of String => String

  @@colors = {} of String => String
  @@mtime : Time? = nil

  def self.load : Nil
    @@colors.clear
    if File.exists?(COLORS_PATH)
      File.each_line(COLORS_PATH) do |line|
        if m = line.match(/^(\w+)\s*=\s*"([^"]+)"/)
          @@colors[m[1]] = m[2]
        end
      end
    end
    derive_colors
  end

  def self.reload_if_changed : Bool
    return false unless File.exists?(COLORS_PATH)
    mtime = File.info(COLORS_PATH).modification_time
    return false if mtime == @@mtime
    @@mtime = mtime
    load
    true
  end

  private def self.derive_colors : Nil
    c = @@colors
    {% for key in %w(accent foreground background color0 color1 color2 color3 color4 color5 color6 color7 color8 color9 color10 color11 color12 color13 color14 color15 cursor sel_fg sel_bg dim_fg mid_fg) %}
      c[{{key}}] ||= FALLBACK[{{key}}]
    {% end %}
  end

  def self.get(key : String) : String
    @@colors[key]? || FALLBACK[key]? || "#888"
  end

  def self.accent : String
    get("accent")
  end

  def self.red : String
    get("color1")
  end

  def self.green : String
    get("color2")
  end

  def self.yellow : String
    get("color3")
  end

  def self.fg : String
    get("foreground")
  end

  def self.bg : String
    get("background")
  end

  def self.dim : String
    get("color8")
  end

  def self.subtitle : String
    get("color7")
  end

  def self.sel_bg : String
    get("sel_bg")
  end

  def self.sel_fg : String
    get("sel_fg")
  end

  def self.dim_fg : String
    get("dim_fg")
  end

  def self.mid_fg : String
    get("mid_fg")
  end

  def self.reload! : Nil
    load
  end

  load
end

class Quest
  property id : Int32
  property title : String
  property description : String
  property done : Bool
  property created_at : String

  def initialize(@id : Int32 = 0, @title : String = "", @description : String = "",
                 @done : Bool = false,
                 @created_at : String = Time.local.to_s("%Y-%m-%d %H:%M"))
  end

  def self.from_json(h : JSON::Any) : Quest
    new(
      id: h["id"]?.try(&.as_i) || 0,
      title: h["title"]?.try(&.as_s) || "",
      description: h["description"]?.try(&.as_s) || h["notes"]?.try(&.as_s) || "",
      done: h["done"]?.try(&.as_bool) || false,
      created_at: h["created_at"]?.try(&.as_s) || Time.local.to_s("%Y-%m-%d %H:%M"),
    )
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "id", @id
      json.field "title", @title
      json.field "description", @description
      json.field "done", @done
      json.field "created_at", @created_at
    end
  end
end

module QuestStore
  extend self

  def load : Array(Quest)
    return [] of Quest unless File.exists?(DATA_FILE)
    JSON.parse(File.read(DATA_FILE)).as_a.map { |h| Quest.from_json(h) }
  rescue JSON::ParseException
    [] of Quest
  end

  def save(quests : Array(Quest))
    Dir.mkdir_p(DATA_DIR)
    File.write(DATA_FILE, JSON.build(2) do |json|
      json.array do
        quests.each { |t| t.to_json(json) }
      end
    end)
  end

  def next_id(quests : Array(Quest)) : Int32
    return 1 if quests.empty?
    quests.map(&.id).max + 1
  end
end

ANSI_RESET = "\e[0m"
ANSI_BOLD  = "\e[1m"
ANSI_DIM   = "\e[2m"
ANSI_STRIKE = "\e[9m"

def ansi_fg(hex : String) : String
  h = hex.delete('#')
  r = h[0, 2].to_i(16)
  g = h[2, 2].to_i(16)
  b = h[4, 2].to_i(16)
  "\e[38;2;#{r};#{g};#{b}m"
end

enum View
  List
  Detail
  Edit
end

class QuestApp < Ori::App
  @quests : Array(Quest)
  @view : View = View::List
  @filter : String = ""
  @filtering : Bool = false
  @edit_quest : Quest?
  @edit_new : Bool = false
  @edit_title : String = ""
  @edit_desc : String = ""
  @edit_desc_row : Int32 = 0
  @edit_desc_col : Int32 = 0
  @filter_input : Ori::InputNode?
  @title_input : Ori::InputNode?
  @desc_area : Ori::AreaNode?
  @quest_list : Ori::List?
  @cursor : Int32 = 0
  @confirm_delete : Bool = false
  @show_help : Bool = false
  @toast_frames : Int32 = 0
  @toast_text : String = ""

  TICK_INTERVAL  = 500.milliseconds
  TOAST_DURATION = 30

  def initialize
    @quests = QuestStore.load
  end

  def on_start : Nil
    start_tick(TICK_INTERVAL) do
      if OmarchyTheme.reload_if_changed
        @toast_frames = TOAST_DURATION
        name_path = File.join(ENV["HOME"]? || "/tmp", ".config/omarchy/current/theme.name")
        name = File.exists?(name_path) ? File.read(name_path).strip : ""
        @toast_text = name.empty? ? "Theme updated" : "Theme: #{name}"
        rebuild
      end
      if @toast_frames > 0
        @toast_frames -= 1
        rebuild if @toast_frames == 0
      end
    end

    Signal::USR1.trap do
      OmarchyTheme.reload!
      @toast_frames = TOAST_DURATION
      name_path = File.join(ENV["HOME"]? || "/tmp", ".config/omarchy/current/theme.name")
      name = File.exists?(name_path) ? File.read(name_path).strip : ""
      @toast_text = name.empty? ? "Theme updated" : "Theme: #{name}"
      rebuild
    end
  end

  def render : Ori::Box
    case @view
    when View::List   then render_list
    when View::Detail then render_detail
    when View::Edit   then render_edit
    else                   render_list
    end
  end

  private def sorted : Array(Quest)
    pending = @quests.reject(&.done).sort_by { |t| -t.id }
    done = @quests.select(&.done).sort_by { |t| t.created_at }.reverse
    result = pending + done
    if @filter != ""
      q = @filter.downcase
      result = result.select { |t| t.title.downcase.includes?(q) || t.description.downcase.includes?(q) }
    end
    result
  end

  private def current_quest : Quest?
    s = sorted
    return nil if s.empty?
    s[Math.min(@cursor, s.size - 1)]
  end

  private def render_list : Ori::Box
    s = sorted
    pending = @quests.count { |t| !t.done }
    done_count = @quests.size - pending

    box height: "100%", direction: :vertical, bg: OmarchyTheme.bg do
      box padding: {1, 2}, direction: :horizontal do
        text "Quests", bold: true, fg: OmarchyTheme.accent
        text " [#{pending} pending, #{done_count} done]", fg: OmarchyTheme.subtitle
        if @filter != "" && !@filtering
          text "  filter: ", fg: OmarchyTheme.dim
          text @filter, fg: OmarchyTheme.yellow
        end
      end

      if s.empty?
        box flex: 1, padding: {0, 2} do
          if @filter != ""
            text "  No matches. Press / to change filter or esc to clear.", fg: OmarchyTheme.dim
          else
            text "  No quests yet. Press 'a' to add one.", fg: OmarchyTheme.dim
          end
        end
      else
        checked = s.map(&.done)
        @quest_list = list(
          items: s.map { |t| Ori::List::Item.new(t.title, t.id.to_s) },
          selected: @cursor,
          checked: checked,
          focusable: true,
          checkable: true,
          selected_fg: OmarchyTheme.bg,
          selected_bg: OmarchyTheme.accent,
          truncate: 40,
          flex: 1,
          on_select: ->(idx : Int32) { @cursor = idx; @view = View::Detail; rebuild },
          on_change: ->(idx : Int32) { @cursor = idx; nil },
        )
      end

      if @toast_frames > 0
        box padding: {0, 2} do
          text @toast_text, fg: OmarchyTheme.accent
        end
      end

      if @filtering
        box padding: {0, 2} do
          @filter_input = input value: @filter,
            placeholder: "type to filter...",
            prefix: "/",
            focusable: true,
            border: :none,
            on_change: ->(v : String) { @filter = v; rebuild }
        end
      end

      box padding: {0, 2} do
        text " a:add  e:edit  d:delete  space:toggle  /:filter  ?:help  q:quit", fg: OmarchyTheme.dim
      end
    end
  end

  private def render_detail : Ori::Box
    quest = current_quest || return render_list
    box height: "100%", padding: 2, direction: :vertical, bg: OmarchyTheme.bg do
      text quest.title, bold: true, fg: OmarchyTheme.accent
      text "─" * 50, fg: OmarchyTheme.dim
      status = quest.done ? "✓ Done" : "○ Pending"
      sfg = quest.done ? OmarchyTheme.green : OmarchyTheme.yellow
      text "#{status}  #{quest.created_at}", fg: sfg
      unless quest.description.empty?
        text ""
        text quest.description, fg: OmarchyTheme.fg
      end
      text ""
      text " e:edit  d:delete  ?:help  esc:back", fg: OmarchyTheme.dim
    end
  end

  private def render_edit : Ori::Box
    header = @edit_new ? "New Quest" : (@edit_quest.try(&.title) || "Edit Quest")
    box height: "100%", padding: 2, direction: :vertical, bg: OmarchyTheme.bg do
      text header, bold: true, fg: OmarchyTheme.accent
      text "─" * 50, fg: OmarchyTheme.dim
      text ""
      text "Title:", fg: OmarchyTheme.subtitle
      @title_input = input value: @edit_title,
        placeholder: "Enter title...",
        focusable: true,
        border: :none,
        on_change: ->(v : String) { @edit_title = v; nil },
        on_submit: ->{ save_edit; nil }
      text ""
      text "Description:", fg: OmarchyTheme.subtitle
      @desc_area = area value: @edit_desc,
        focusable: true,
        height: 5,
        border: :none,
        cursor_row: @edit_desc_row,
        cursor_col: @edit_desc_col,
        on_change: ->(v : String, r : Int32, c : Int32) { @edit_desc = v; @edit_desc_row = r; @edit_desc_col = c; nil }
      text ""
      text " tab:focus  ctrl+s/enter:save  esc:cancel", fg: OmarchyTheme.dim
    end
  end

  private def show_help_dialog : Nil
    show_dialog do
      box padding: 2, direction: :vertical, border: :rounded, border_fg: OmarchyTheme.accent, bg: OmarchyTheme.bg do
        text "Keyboard Shortcuts", bold: true, fg: OmarchyTheme.accent
        text ""
        text "a          Add new quest", fg: OmarchyTheme.fg
        text "e          Edit selected", fg: OmarchyTheme.fg
        text "d          Delete selected", fg: OmarchyTheme.fg
        text "space      Toggle done", fg: OmarchyTheme.fg
        text "enter      View details", fg: OmarchyTheme.fg
        text "/          Filter/search", fg: OmarchyTheme.fg
        text "esc        Clear filter / back", fg: OmarchyTheme.fg
        text "up/down    Navigate", fg: OmarchyTheme.fg
        text "g/G        Jump top/bottom", fg: OmarchyTheme.fg
        text "?          Show help", fg: OmarchyTheme.fg
        text "q          Quit", fg: OmarchyTheme.fg
        text ""
        text "Press any key to close", fg: OmarchyTheme.dim
      end
    end
  end

  def handle_key(key : Ori::Key) : Bool
    if key.ctrl && key.text == "c"
      @running = false
      return false
    end

    if @confirm_delete
      handle_delete_confirm(key)
      return false
    end

    if @show_help
      @show_help = false
      close_dialog
      return false
    end

    handled = case @view
              when View::List   then handle_list(key)
              when View::Detail then handle_detail(key)
              when View::Edit   then handle_edit(key)
              else                   false
              end

    unless handled
      if fm = @focus
        fm.handle_key(key)
        if @filtering
          @filter = @filter_input.try(&.value) || ""
        end
        rebuild
      end
    end

    false
  end

  def on_mouse(mouse : Ori::Mouse) : Bool
    return false unless @view == View::List && !@filtering
    if mouse.wheel? && mouse.button.wheel_up?
      @cursor = {@cursor - 3, 0}.max
      rebuild
      true
    elsif mouse.wheel? && mouse.button.wheel_down?
      s = sorted
      @cursor = {@cursor + 3, {s.size - 1, 0}.max}.min
      rebuild
      true
    else
      false
    end
  end

  private def handle_list(key : Ori::Key) : Bool
    if @filtering
      case
      when key.code.escape?
        @filtering = false
        @filter = ""
        @cursor = 0
        rebuild
        true
      when key.code.enter?
        @filtering = false
        rebuild
        true
      else
        false
      end
    else
      case
      when key.text == "q"
        @running = false
        true
      when key.text == "a"
        start_edit(true)
        true
      when key.text == "e"
        c = current_quest
        return false unless c
        start_edit(false, c)
        true
      when key.text == "d"
        return false unless current_quest
        ask_delete
        true
      when key.text == "?"
        @show_help = true
        show_help_dialog
        true
      when key.text == "/"
        @filtering = true
        rebuild
        true
      when key.code.escape?
        @filter = ""
        @cursor = 0
        rebuild
        true
      when key.code.space?
        c = current_quest
        return false unless c
        c.done = !c.done
        QuestStore.save(@quests)
        rebuild
        true
      else
        false
      end
    end
  end

  private def handle_detail(key : Ori::Key) : Bool
    case
    when key.code.escape? || key.code.enter?
      @view = View::List
      rebuild
      true
    when key.text == "e"
      c = current_quest
      return false unless c
      start_edit(false, c)
      true
    when key.text == "d"
      return false unless current_quest
      ask_delete
      true
    when key.text == "?"
      @show_help = true
      show_help_dialog
      true
    else
      false
    end
  end

  private def handle_edit(key : Ori::Key) : Bool
    case
    when key.code.escape?
      @view = View::List
      rebuild
      true
    when key.ctrl && key.text == "s"
      save_edit
      true
    else
      false
    end
  end

  private def ask_delete : Nil
    c = current_quest
    title = c ? c.title[0...30] : "this item"
    @confirm_delete = true
    show_dialog do
      box padding: 2, direction: :vertical, border: :rounded, border_fg: OmarchyTheme.red, bg: OmarchyTheme.bg do
        text "Delete \"#{title}\"?", bold: true, fg: OmarchyTheme.red
        text ""
        text "y: confirm   n/esc: cancel", fg: OmarchyTheme.dim
      end
    end
  end

  private def handle_delete_confirm(key : Ori::Key) : Nil
    case
    when key.text == "y" || key.code.enter?
      @confirm_delete = false
      close_dialog
      confirm_delete
    when key.text == "n" || key.code.escape?
      @confirm_delete = false
      close_dialog
    end
  end

  private def start_edit(is_new : Bool, quest : Quest = Quest.new)
    @edit_new = is_new
    @edit_quest = is_new ? Quest.new : quest
    @edit_title = @edit_quest.not_nil!.title
    @edit_desc = @edit_quest.not_nil!.description
    @view = View::Edit
    rebuild
  end

  private def save_edit
    title = @edit_title.strip
    desc = @edit_desc.strip
    if @edit_new
      q = @edit_quest || Quest.new
      q.title = title.empty? ? "Untitled" : title
      q.description = desc
      q.id = QuestStore.next_id(@quests)
      q.created_at = Time.local.to_s("%Y-%m-%d %H:%M")
      @quests << q
    else
      q = @edit_quest
      if q && (idx = @quests.index { |x| x.id == q.id })
        q.title = title.empty? ? "Untitled" : title
        q.description = desc
        @quests[idx] = q
      end
    end
    QuestStore.save(@quests)
    @view = View::List
    rebuild
  end

  private def confirm_delete
    if c = current_quest
      @quests.reject! { |t| t.id == c.id }
      QuestStore.save(@quests)
    end
    s = sorted
    @cursor = {@cursor, {s.size - 1, 0}.max}.min
    @view = View::List
    rebuild
  end
end

def run_tui
  QuestApp.run
end

def waybar_output
  quests = QuestStore.load
  pending = quests.count { |t| !t.done }

  if pending == 0
    json = {text: "✓", tooltip: "All done!", class: "done"}
  else
    json = {text: "📋 #{pending}", tooltip: "#{pending} pending tasks", class: "normal"}
  end

  puts json.to_json
end

def quick_add(title : String)
  quests = QuestStore.load
  id = QuestStore.next_id(quests)
  quests << Quest.new(id: id, title: title)
  QuestStore.save(quests)
  puts "Added: #{title} (##{id})"
end

def quick_done(id : Int32)
  quests = QuestStore.load
  found = quests.find { |t| t.id == id }
  unless found
    STDERR.puts "Quest ##{id} not found"
    exit 1
  end
  found.done = !found.done
  QuestStore.save(quests)
  status = found.done ? "completed" : "reopened"
  puts "#{status}: #{found.title} (##{id})"
end

def quick_list
  quests = QuestStore.load
  if quests.empty?
    puts "No quests."
    return
  end

  pending = quests.reject(&.done)
  done = quests.select(&.done)

  unless pending.empty?
    puts "#{ANSI_BOLD}#{ansi_fg(OmarchyTheme.accent)}Pending (#{pending.size})#{ANSI_RESET}"
    pending.each do |t|
      puts "  ○ #{t.title}"
    end
  end

  unless done.empty?
    puts "" if !pending.empty?
    puts "#{ANSI_BOLD}#{ansi_fg(OmarchyTheme.green)}Done (#{done.size})#{ANSI_RESET}"
    done.each do |t|
      puts "  ✓ #{ANSI_DIM}#{ANSI_STRIKE}#{t.title}#{ANSI_RESET}"
    end
  end
end

do_waybar = false
do_count = false

parser = OptionParser.new do |opts|
  opts.banner = "Usage: quests [options] [subcommand] [args]"
  opts.separator ""
  opts.separator "Subcommands:"
  opts.separator "  quests                          Launch TUI (default)"
  opts.separator "  quests add \"Task name\"          Quick add a quest"
  opts.separator "  quests done <id>                Toggle done status"
  opts.separator "  quests list                     List quests in terminal"
  opts.separator ""
  opts.separator "Integration options:"
  opts.on("--waybar", "Output waybar JSON module") { do_waybar = true }
  opts.on("--count", "Output pending count") { do_count = true }
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit
  end
end

begin
  parser.parse
rescue ex : OptionParser::InvalidOption
  STDERR.puts ex.message
  exit 1
end

subcommand = ARGV.shift?

if do_waybar
  waybar_output
elsif do_count
  puts QuestStore.load.count { |t| !t.done }
else
  case subcommand
  when "add"
    arg_title = ARGV.join(" ")
    if arg_title.empty?
      STDERR.puts "Usage: quests add \"Task name\""
      exit 1
    end
    quick_add(arg_title)
  when "done"
    arg_id = ARGV.shift?
    if arg_id.nil?
      STDERR.puts "Usage: quests done <id>"
      exit 1
    end
    quick_done(arg_id.to_i)
  when "list"
    quick_list
  when nil
    run_tui
  else
    STDERR.puts "Unknown subcommand: #{subcommand}"
    STDERR.puts "Run 'quests --help' for usage"
    exit 1
  end
end
