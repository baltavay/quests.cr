require "crubbletea"
require "json"
require "option_parser"
require "time"

DATA_DIR  = File.join(ENV["HOME"]? || "/tmp", ".local/share/quests")
DATA_FILE = File.join(DATA_DIR, "data.json")

struct TickMsg
  include Crubbletea::Msg
end

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

module QuestStore
  extend self

  def load : Array(Quest)
    return [] of Quest unless File.exists?(DATA_FILE)
    raw = JSON.parse(File.read(DATA_FILE)).as_a
    raw.map { |h| Quest.from_json(h) }
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

class FilterState
  property text : String

  def initialize
    @text = ""
  end

  def active? : Bool
    !@text.empty?
  end

  def apply(quests : Array(Quest)) : Array(Quest)
    return quests if @text.empty?
    q = @text.downcase
    quests.select { |t| t.title.downcase.includes?(q) || t.description.downcase.includes?(q) }
  end

  def description : String
    @text.empty? ? "none" : "\"#{@text}\""
  end
end

struct SaveMsg
  include Crubbletea::Msg
  getter quest : Quest
  def initialize(@quest : Quest); end
end

struct BackMsg
  include Crubbletea::Msg
end

struct DeleteMsg
  include Crubbletea::Msg
end

struct HelpMsg
  include Crubbletea::Msg
end

class QuestForm
  getter title_input : Crubbletea::Bubbles::TextInput::Model
  getter desc_input : Crubbletea::Bubbles::TextArea::Model
  property field_index : Int32
  property quest : Quest
  getter is_new : Bool
  getter content_width : Int32
  getter title_line : Int32
  getter desc_line : Int32

  def initialize(@quest : Quest = Quest.new, @is_new : Bool = false, @content_width : Int32 = 60)
    @field_index = 0

    @title_input = Crubbletea::Bubbles::TextInput::Model.new(
      prompt: "", placeholder: "Title", width: @content_width
    )
    @title_input.value = @quest.title

    @desc_input = Crubbletea::Bubbles::TextArea::Model.new(
      placeholder: "Description", width: @content_width, height: 4
    )
    @desc_input.value = @quest.description

    @title_line = 0
    @desc_line = 0
  end

  def field_count : Int32
    2
  end

  def init : Crubbletea::Cmd?
    @title_input.focus
    nil
  end

  def focus_current : Nil
    @title_input.blur
    @desc_input.blur
    case @field_index
    when 0 then @title_input.focus
    when 1 then @desc_input.focus
    end
  end

  def update(msg) : {QuestForm, Crubbletea::Cmd?}
    case msg
    when Crubbletea::KeyPressMsg
      key = msg.key
      case
      when key.to_s == "tab"
        @field_index = (@field_index + 1) % field_count
        focus_current
        return {self, nil}
      when key.to_s == "shift+tab"
        @field_index = (@field_index - 1) % field_count
        focus_current
        return {self, nil}
      when key.to_s == "ctrl+s"
        return {self, -> { SaveMsg.new(build_quest).as(Crubbletea::Msg) }}
      when key.to_s == "enter"
        if @field_index == 0
          return {self, -> { SaveMsg.new(build_quest).as(Crubbletea::Msg) }}
        elsif @field_index == 1
          @desc_input.update(msg)
        end
      when key.code == Crubbletea::Key::Code::Escape
        return {self, -> { BackMsg.new.as(Crubbletea::Msg) }}
      when key.text == "d" && !@title_input.focused? && !@desc_input.focused?
        return {self, -> { DeleteMsg.new.as(Crubbletea::Msg) }}
      when key.text == "?" && !@title_input.focused? && !@desc_input.focused?
        return {self, -> { HelpMsg.new.as(Crubbletea::Msg) }}
      else
        case @field_index
        when 0 then @title_input.update(msg)
        when 1 then @desc_input.update(msg)
        end
      end
    end
    {self, nil}
  end

  def build_quest : Quest
    @quest.title = @title_input.value.strip
    @quest.description = @desc_input.value.strip
    @quest
  end

  def raw_view : String
    accent = Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.accent)
    dim = Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.dim)

    lines = [] of String

    header = @is_new ? "New Quest" : @quest.title
    lines << accent.render(header)
    lines << dim.render("─" * @content_width)

    @title_line = lines.size
    lines << @title_input.view

    lines << ""
    @desc_line = lines.size
    @desc_input.view.split('\n').each do |dl|
      lines << dl
    end

    lines << ""
    lines << dim.render("tab: fields • ^s/↵: save • d: del • esc: back")

    lines.join("\n")
  end

  def view : String
    raw_view
  end

  def box_height : Int32
    raw_view.split('\n').size
  end
end

module Styles
  def self.title : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.accent)
  end

  def self.subtitle : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.subtitle)
  end

  def self.dim : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.dim)
  end

  def self.label : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.subtitle).width(14).bold(true)
  end

  def self.value : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.fg)
  end

  def self.status_bar : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.background(OmarchyTheme.bg).foreground(OmarchyTheme.dim_fg).padding(0, 1)
  end

  def self.form_box : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new
      .border(Crubbletea::Lipgloss::Border.rounded)
      .border_foreground(OmarchyTheme.accent).padding(1, 2)
  end

  def self.check_done : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.green)
  end

  def self.check_open : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.subtitle)
  end

  def self.title_done : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.dim).strikethrough(true)
  end

  def self.title_sel : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.bg).bold(true)
  end

  def self.title_norm : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.fg)
  end

  def self.sel_bg : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.background(OmarchyTheme.accent)
  end

  def self.status_done : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.green)
  end

  def self.status_open : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.yellow)
  end

  def self.desc_val : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.mid_fg)
  end

  def self.help_key : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.yellow).width(16)
  end

  def self.help_desc : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.fg)
  end

  def self.help_box : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new
      .border(Crubbletea::Lipgloss::Border.rounded)
      .border_foreground(OmarchyTheme.accent).padding(1, 3).background(OmarchyTheme.bg)
  end

  def self.delete_label : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.red)
  end

  def self.border : Crubbletea::Lipgloss::Style
    Crubbletea::Lipgloss::Style.new
      .border(Crubbletea::Lipgloss::Border.rounded)
      .border_foreground(OmarchyTheme.accent)
  end
end

enum AppMode
  Main
  Detail
  Edit
  Add
  Delete
  Filter
  Help
end

class App
  include Crubbletea::Model
  include Crubbletea::Bubbles::Help::KeyMap

  @quests : Array(Quest)
  @cursor : Int32
  @mode : AppMode
  @form : QuestForm?
  @filter : FilterState
  @width : Int32
  @height : Int32
  @filter_input : Crubbletea::Bubbles::TextInput::Model
  @scroll_offset : Int32
  @cache_ft : Array(Quest)?
  @cache_valid : Bool
  @dirty : Bool
  @view_cache : String
  @list_content_w : Int32
  @prev_mode : AppMode

  def initialize
    @quests = QuestStore.load
    @cursor = 0
    @mode = AppMode::Main
    @prev_mode = AppMode::Main
    @form = nil
    @filter = FilterState.new
    @width = 80
    @height = 24
    @filter_input = Crubbletea::Bubbles::TextInput::Model.new(
      placeholder: "type to filter...", width: 30
    )
    @scroll_offset = 0
    @cache_ft = nil
    @cache_valid = false
    @dirty = true
    @view_cache = ""
    @list_content_w = 0
    @toast_frames = 0
    @toast_text = ""
  end

  def invalidate_cache
    @cache_valid = false
    @dirty = true
  end

  def mark_dirty
    @dirty = true
  end

  HELP_BINDINGS = [
    Crubbletea::Bubbles::Key.new_binding("a", help_key: "a", help_desc: "add"),
    Crubbletea::Bubbles::Key.new_binding("e", help_key: "e", help_desc: "edit"),
    Crubbletea::Bubbles::Key.new_binding("d", help_key: "d", help_desc: "delete"),
    Crubbletea::Bubbles::Key.new_binding(" ", help_key: "space", help_desc: "toggle"),
    Crubbletea::Bubbles::Key.new_binding("enter", help_key: "↵", help_desc: "details"),
    Crubbletea::Bubbles::Key.new_binding("/", help_key: "/", help_desc: "filter"),
    Crubbletea::Bubbles::Key.new_binding("esc", help_key: "esc", help_desc: "clear filter"),
    Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "help"),
    Crubbletea::Bubbles::Key.new_binding("q", help_key: "q", help_desc: "quit"),
  ]

  HELP_BINDINGS_DETAIL = [
    Crubbletea::Bubbles::Key.new_binding("e", help_key: "e", help_desc: "edit"),
    Crubbletea::Bubbles::Key.new_binding("d", help_key: "d", help_desc: "delete"),
    Crubbletea::Bubbles::Key.new_binding("esc", help_key: "esc", help_desc: "back"),
    Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "help"),
  ]

  HELP_FULL = [
    [
      Crubbletea::Bubbles::Key.new_binding("a", help_key: "a", help_desc: "Add new quest"),
      Crubbletea::Bubbles::Key.new_binding("e", help_key: "e", help_desc: "Edit selected quest"),
      Crubbletea::Bubbles::Key.new_binding("d", help_key: "d", help_desc: "Delete selected quest"),
      Crubbletea::Bubbles::Key.new_binding(" ", help_key: "space", help_desc: "Toggle done/pending"),
      Crubbletea::Bubbles::Key.new_binding("enter", help_key: "↵", help_desc: "View quest details"),
      Crubbletea::Bubbles::Key.new_binding("up", "k", help_key: "↑/k", help_desc: "Navigate up"),
      Crubbletea::Bubbles::Key.new_binding("down", "j", help_key: "↓/j", help_desc: "Navigate down"),
      Crubbletea::Bubbles::Key.new_binding("g", help_key: "g", help_desc: "Jump to top"),
      Crubbletea::Bubbles::Key.new_binding("G", help_key: "G", help_desc: "Jump to bottom"),
      Crubbletea::Bubbles::Key.new_binding("pgup", "pgdown", help_key: "PgUp/PgDn", help_desc: "Page up/down"),
      Crubbletea::Bubbles::Key.new_binding("/", help_key: "/", help_desc: "Filter/search"),
      Crubbletea::Bubbles::Key.new_binding("esc", help_key: "esc", help_desc: "Clear filter"),
      Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "Show help"),
      Crubbletea::Bubbles::Key.new_binding("q", "ctrl+c", help_key: "q/Ctrl+C", help_desc: "Quit"),
    ],
  ]

  HELP_FULL_DETAIL = [
    [
      Crubbletea::Bubbles::Key.new_binding("e", help_key: "e", help_desc: "Edit quest"),
      Crubbletea::Bubbles::Key.new_binding("d", help_key: "d", help_desc: "Delete quest"),
      Crubbletea::Bubbles::Key.new_binding("esc", "enter", help_key: "esc/↵", help_desc: "Back to list"),
      Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "Show help"),
    ],
  ]

  HELP_BINDINGS_FORM = [
    Crubbletea::Bubbles::Key.new_binding("tab", help_key: "tab", help_desc: "next field"),
    Crubbletea::Bubbles::Key.new_binding("enter", help_key: "↵", help_desc: "save"),
    Crubbletea::Bubbles::Key.new_binding("d", help_key: "d", help_desc: "delete"),
    Crubbletea::Bubbles::Key.new_binding("esc", help_key: "esc", help_desc: "back"),
    Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "help"),
  ]

  HELP_FULL_FORM = [
    [
      Crubbletea::Bubbles::Key.new_binding("tab", help_key: "tab/⇧+tab", help_desc: "Cycle fields"),
      Crubbletea::Bubbles::Key.new_binding("ctrl+s", "enter", help_key: "^S/↵", help_desc: "Save & back"),
      Crubbletea::Bubbles::Key.new_binding("d", help_key: "d", help_desc: "Delete quest"),
      Crubbletea::Bubbles::Key.new_binding("esc", help_key: "esc", help_desc: "Back to list"),
      Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "Show help"),
    ],
  ]

  def current_help_mode : AppMode
    @mode == AppMode::Help ? @prev_mode : @mode
  end

  def short_help : Array(Crubbletea::Bubbles::Key::Binding)
    m = current_help_mode
    case m
    when AppMode::Edit, AppMode::Add then HELP_BINDINGS_FORM
    when AppMode::Detail then HELP_BINDINGS_DETAIL
    else HELP_BINDINGS
    end
  end

  def full_help : Array(Array(Crubbletea::Bubbles::Key::Binding))
    m = current_help_mode
    case m
    when AppMode::Edit, AppMode::Add then HELP_FULL_FORM
    when AppMode::Detail then HELP_FULL_DETAIL
    else HELP_FULL
    end
  end

  def help_model(box_w : Int32) : Crubbletea::Bubbles::Help::HelpModel
    Crubbletea::Bubbles::Help::HelpModel.new(
      show_all: true,
      width: box_w,
      styles: Crubbletea::Bubbles::Help::Styles.new(
        full_key: Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.yellow).width(12),
        full_desc: Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.fg),
      ),
    )
  end

  def short_help_model : Crubbletea::Bubbles::Help::HelpModel
    Crubbletea::Bubbles::Help::HelpModel.new(
      show_all: false,
      width: @width,
      styles: Crubbletea::Bubbles::Help::Styles.new(
        short_key: Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.dim_fg).inline(true),
        short_desc: Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.subtitle).inline(true),
      ),
    )
  end

  def filtered_quests : Array(Quest)
    return @cache_ft.not_nil! if @cache_valid
    @cache_valid = true
    pending = @quests.reject(&.done).sort_by { |t| -t.id }
    done = @quests.select(&.done).sort_by { |t| t.created_at }.reverse
    @cache_ft = @filter.active? ? @filter.apply(pending + done) : pending + done
  end

  def current_quest : Quest?
    ft = filtered_quests
    return nil if ft.empty?
    ft[Math.min(@cursor, ft.size - 1)]
  end

  def save
    QuestStore.save(@quests)
    invalidate_cache
  end

  TICK_INTERVAL = 500.milliseconds
  TOAST_DURATION = 90
  @toast_frames : Int32
  @toast_text : String

  def init : Crubbletea::Cmd?
    schedule_tick
  end

  def schedule_tick : Crubbletea::Cmd?
    Crubbletea.every(TICK_INTERVAL) { TickMsg.new.as(Crubbletea::Msg) }
  end

  def update(msg) : {App, Crubbletea::Cmd?}
    result = case msg
    when SaveMsg
      handle_save(msg)
    when BackMsg
      @mode = AppMode::Main; @form = nil; mark_dirty; {self, nil}
    when DeleteMsg
      return {self, nil} unless current_quest; @mode = AppMode::Delete; mark_dirty; {self, nil}
    when HelpMsg
      @prev_mode = @mode; @mode = AppMode::Help; mark_dirty; {self, nil}
    when Crubbletea::WindowSizeMsg
      @width = msg.width; @height = msg.height; mark_dirty; {self, nil}
    when TickMsg
      if OmarchyTheme.reload_if_changed
        mark_dirty
        @toast_frames = TOAST_DURATION
        name_path = File.join(ENV["HOME"]? || "/tmp", ".config/omarchy/current/theme.name")
        name = File.exists?(name_path) ? File.read(name_path).strip : ""
        @toast_text = name.empty? ? "Theme updated" : "Theme: #{name}"
      end
      @toast_frames -= 1 if @toast_frames > 0
      {self, nil}
    else
      handle_msg(msg)
    end
    app, cmd = result
    tick = schedule_tick
    final_cmd = cmd ? Crubbletea.batch([cmd, tick]) : tick
    {app, final_cmd}
  end

  def handle_msg(msg) : {App, Crubbletea::Cmd?}
    if @mode == AppMode::Help
      if msg.is_a?(Crubbletea::KeyPressMsg)
        @mode = @prev_mode
        mark_dirty
      end
      return {self, nil}
    end

    if @mode == AppMode::Detail
      return handle_detail_keys(msg)
    end

    if @mode == AppMode::Edit || @mode == AppMode::Add
      return handle_form(msg)
    end

    if @mode == AppMode::Filter
      return handle_filter_input(msg)
    end

    case msg
    when Crubbletea::KeyPressMsg
      return @mode == AppMode::Delete ? handle_delete_confirm(msg) : handle_main_keys(msg)
    end

    {self, nil}
  end

  def handle_main_keys(msg : Crubbletea::KeyPressMsg) : {App, Crubbletea::Cmd?}
    key = msg.key
    case
    when key.code == Crubbletea::Key::Code::Escape
      if @filter.active?
        @filter = FilterState.new; @cursor = 0; @scroll_offset = 0; invalidate_cache
      end
    when key.text == "q", key.to_s == "ctrl+c"
      return {self, Crubbletea.quit}
    when key.code == Crubbletea::Key::Code::Up, key.text == "k"
      @cursor = {@cursor - 1, 0}.max; adjust_scroll; mark_dirty
    when key.code == Crubbletea::Key::Code::Down, key.text == "j"
      @cursor = {@cursor + 1, {filtered_quests.size - 1, 0}.max}.min; adjust_scroll; mark_dirty
    when key.code == Crubbletea::Key::Code::Home, key.text == "g"
      @cursor = 0; @scroll_offset = 0; mark_dirty
    when key.code == Crubbletea::Key::Code::End, key.text == "G"
      @cursor = {filtered_quests.size - 1, 0}.max; adjust_scroll; mark_dirty
    when key.code == Crubbletea::Key::Code::PgUp, key.to_s == "ctrl+b"
      @cursor = {@cursor - list_height, 0}.max; adjust_scroll; mark_dirty
    when key.code == Crubbletea::Key::Code::PgDown, key.to_s == "ctrl+f"
      @cursor = {@cursor + list_height, {filtered_quests.size - 1, 0}.max}.min; adjust_scroll; mark_dirty
    when key.text == "a"
      @mode = AppMode::Add; @form = QuestForm.new(is_new: true, content_width: {@width, 40}.max); @form.not_nil!.init; mark_dirty; return {self, nil}
    when key.text == "e"
      quest = current_quest; return {self, nil} unless quest
      @mode = AppMode::Edit; @form = QuestForm.new(quest, content_width: {@width, 40}.max); @form.not_nil!.init; mark_dirty; return {self, nil}
    when key.text == "d"
      return {self, nil} unless current_quest; @mode = AppMode::Delete; mark_dirty
    when key.code == Crubbletea::Key::Code::Space
      quest = current_quest; return {self, nil} unless quest
      quest.done = !quest.done
      save; invalidate_cache
    when key.text == "/"
      @mode = AppMode::Filter; @filter_input = Crubbletea::Bubbles::TextInput::Model.new(
        placeholder: "type to filter...", width: 30
      )
      @filter_input.focus; mark_dirty; return {self, nil}
    when key.text == "?"
      @prev_mode = @mode; @mode = AppMode::Help; mark_dirty
    when key.code == Crubbletea::Key::Code::Enter
      quest = current_quest; return {self, nil} unless quest
      @mode = AppMode::Detail; mark_dirty; return {self, nil}
    end
    {self, nil}
  end

  def handle_detail_keys(msg) : {App, Crubbletea::Cmd?}
    if msg.is_a?(Crubbletea::KeyPressMsg)
      case
      when msg.key.code == Crubbletea::Key::Code::Escape,
           msg.key.code == Crubbletea::Key::Code::Enter,
           msg.key.text == "q"
        @mode = AppMode::Main; mark_dirty; return {self, nil}
      when msg.key.text == "e"
        quest = current_quest; return {self, nil} unless quest
        @mode = AppMode::Edit; @form = QuestForm.new(quest, content_width: {@width, 40}.max); @form.not_nil!.init; mark_dirty; return {self, nil}
      when msg.key.text == "d"
        return {self, nil} unless current_quest; @mode = AppMode::Delete; mark_dirty
      when msg.key.text == "?"
        @prev_mode = @mode; @mode = AppMode::Help; mark_dirty
      end
    end
    {self, nil}
  end

  def handle_form(msg) : {App, Crubbletea::Cmd?}
    form = @form.not_nil!
    form, cmd = form.update(msg)
    @form = form
    mark_dirty
    {self, cmd}
  end

  def handle_save(msg : SaveMsg) : {App, Crubbletea::Cmd?}
    quest = msg.quest
    if quest.id == 0
      quest.id = QuestStore.next_id(@quests)
      quest.created_at = Time.local.to_s("%Y-%m-%d %H:%M")
      @quests << quest
    else
      idx = @quests.index { |t| t.id == quest.id }
      @quests[idx] = quest if idx
    end
    save; @mode = AppMode::Main; @form = nil; mark_dirty
    {self, nil}
  end

  def handle_filter_input(msg) : {App, Crubbletea::Cmd?}
    if msg.is_a?(Crubbletea::KeyPressMsg)
      case
      when msg.key.code == Crubbletea::Key::Code::Escape
        @filter = FilterState.new
        @mode = AppMode::Main; @filter_input.blur
        @cursor = 0; @scroll_offset = 0; invalidate_cache; mark_dirty; return {self, nil}
      when msg.key.code == Crubbletea::Key::Code::Enter
        @filter.text = @filter_input.value; @mode = AppMode::Main; @filter_input.blur
        @cursor = 0; @scroll_offset = 0; invalidate_cache; return {self, nil}
      end
    end
    @filter_input, _ = @filter_input.update(msg)
    @filter.text = @filter_input.value
    @cursor = 0; @scroll_offset = 0; invalidate_cache
    {self, nil}
  end

  def handle_delete_confirm(msg : Crubbletea::KeyPressMsg) : {App, Crubbletea::Cmd?}
    case
    when msg.key.text == "y", msg.key.code == Crubbletea::Key::Code::Enter
      quest = current_quest
      if quest
        @quests.reject! { |t| t.id == quest.id }; save
        @cursor = {@cursor, {filtered_quests.size - 1, 0}.max}.min
      end
      @mode = AppMode::Main
    when msg.key.text == "n", msg.key.code == Crubbletea::Key::Code::Escape
      @mode = AppMode::Main
    end
    mark_dirty
    {self, nil}
  end

  def adjust_scroll
    visible = list_height
    @scroll_offset = @cursor if @cursor < @scroll_offset
    @scroll_offset = @cursor - visible + 1 if @cursor >= @scroll_offset + visible
  end

  def list_height : Int32
    h = @height - 5
    h -= 1 if @toast_frames > 0
    h > 0 ? h : 1
  end

  ANSI_RE = /\e\[[^m]*m/

  def truncate_visible(text : String, max_width : Int32) : String
    return text if max_width < 4
    plain = text.gsub(ANSI_RE, "")
    return text if plain.size <= max_width
    Crubbletea::Lipgloss::ANSI.truncate(text, max_width - 1, "…")
  end

  def view : Crubbletea::View
    v = Crubbletea::View.new
    v.alt_screen = true
    v.background_color = OmarchyTheme.bg
    content = build_view
    v.content = content
    if (@mode == AppMode::Edit || @mode == AppMode::Add) && @form
      cursor = compute_form_cursor
      v.cursor = cursor if cursor
    elsif @mode == AppMode::Filter && @filter_input.focused?
      cx = 9 + @filter_input.cursor_pos
      cy = content.split('\n').size - 1
      v.cursor = Crubbletea::Cursor.new(cx, cy)
    end
    v
  end

  def compute_form_cursor : Crubbletea::Cursor?
    form = @form
    return nil unless form

    col_offset = 0
    row_offset = 0

    case form.field_index
    when 0
      cx = col_offset + form.title_input.visible_cursor_pos
      cy = row_offset + form.title_line
    when 1
      cx = col_offset + form.desc_input.visible_cursor_col
      cy = row_offset + form.desc_line + form.desc_input.visible_cursor_row
    else
      return nil
    end

    Crubbletea::Cursor.new({cx, @width - 2}.min, {cy, @height - 2}.min)
  end

  def build_view : String
    if @mode == AppMode::Edit || @mode == AppMode::Add
      form = @form
      return form ? form.view : ""
    end
    base = Crubbletea::Lipgloss.join_vertical(
            Crubbletea::Lipgloss::Style::Pos::Top,
            [render_list_panel, render_status_bar]
          )
    case @mode
    when AppMode::Detail
      render_detail_view
    when AppMode::Delete
      render_delete_overlay(base)
    when AppMode::Help
      render_help_overlay(base)
    else
      base
    end
  end

  def render_list_panel : String
    w = @width
    h = @height - 2
    @list_content_w = w
    ft = filtered_quests
    pending = ft.count { |t| !t.done }
    header = "#{Styles.title.render("Quests")} #{Styles.subtitle.render("[#{pending} pending, #{ft.size - pending} done]")}"
    if ft.size > list_height
      range = "#{@scroll_offset + 1}-#{@scroll_offset + list_height}"
      header += " #{Styles.dim.render("#{range}/#{ft.size}")}"
    end
    lines = [header]
    if @filter.active?
      filter_label = Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.subtitle).render("Filter:")
      filter_val = Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.fg).render(@filter.text)
      lines << ""
      lines << "#{filter_label} #{filter_val}"
    end
    lines << ""
    if ft.empty?
      lines << Styles.dim.render("No quests yet. Press 'a' to add one.")
      remaining = list_height - lines.size + 2
      remaining.times { lines << "" } if remaining > 0
    else
      end_idx = {@scroll_offset + list_height, ft.size}.min
      (@scroll_offset...end_idx).each { |i| lines << render_quest_line(ft[i], i == @cursor) }
      remaining = list_height - lines.size + 2
      remaining.times { lines << "" } if remaining > 0
    end
    lines.join("\n")
  end

  def render_quest_line(quest : Quest, selected : Bool) : String
    max_w = @list_content_w - 2
    check = (quest.done ? Styles.check_done : Styles.check_open).render(quest.done ? "✓" : "○")
    ts = quest.done ? Styles.title_done : selected ? Styles.title_sel : Styles.title_norm
    title = ts.render(truncate_visible(quest.title, {max_w - 4, 4}.max))
    line = "#{check} #{title}"
    line = truncate_visible(line, max_w)
    selected ? Styles.sel_bg.render(line) : line
  end

  def render_status_bar : String
    w = @width
    left_text = case @mode
                when AppMode::Delete
                  Styles.delete_label.render("CONFIRM DELETE (y/n)")
                when AppMode::Filter
                  "FILTER: #{@filter_input.value}"
                else
                  short_help_model.view(self)
                end
    bar = Styles.status_bar.width(w).render(left_text)
    if @toast_frames > 0
      alpha = @toast_frames.to_f / TOAST_DURATION
      toast_style = Crubbletea::Lipgloss::Style.new
        .foreground(blend_color(OmarchyTheme.accent, OmarchyTheme.bg, alpha))
        .width(w)
        .align(Crubbletea::Lipgloss::Style::Pos::Center)
      bar = toast_style.render(@toast_text) + "\n" + bar
    end
    bar
  end

  def blend_color(fg_hex : String, bg_hex : String, alpha : Float64) : String
    fr, fg_i, fb = hex_to_rgb(fg_hex)
    br, bg_i, bb = hex_to_rgb(bg_hex)
    r = (br + (fr - br) * alpha).to_i.clamp(0, 255)
    g = (bg_i + (fg_i - bg_i) * alpha).to_i.clamp(0, 255)
    b = (bb + (fb - bb) * alpha).to_i.clamp(0, 255)
    "##{r.to_s(16).rjust(2, '0')}#{g.to_s(16).rjust(2, '0')}#{b.to_s(16).rjust(2, '0')}"
  end

  def hex_to_rgb(hex : String) : {Int32, Int32, Int32}
    h = hex.delete('#')
    r = h[0, 2].to_i(16)
    g = h[2, 2].to_i(16)
    b = h[4, 2].to_i(16)
    {r, g, b}
  end

  def render_detail_view : String
    quest = current_quest
    unless quest
      @mode = AppMode::Main; mark_dirty
      return render_list_panel
    end
    accent = Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.accent)
    dim = Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.dim)
    fg = Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.fg)

    lines = [] of String
    lines << accent.render(quest.title)
    lines << dim.render("─" * @width)

    s = quest.done ? Styles.status_done.render("✓ Done") : Styles.status_open.render("○ Pending")
    lines << "#{s}  #{dim.render(quest.created_at)}"

    unless quest.description.empty?
      lines << ""
      wrapped = Crubbletea::Lipgloss::ANSI.wrap(quest.description, @width)
      lines << fg.render(wrapped)
    end

    lines << ""
    lines << dim.render("e: edit • d: delete • esc: back")
    lines.join("\n")
  end

  def render_delete_overlay(base : String) : String
    quest = current_quest
    title = quest ? quest.title : "this item"
    box_style = Styles.border.border_foreground(OmarchyTheme.red).padding(1, 3)
      .width({(@width * 0.5).to_i, 44}.max)
    lines = [
      Styles.delete_label.render("Delete Quest?"),
      "",
      Styles.title_norm.render(title),
      "",
      Styles.dim.render("y: confirm   n/esc: cancel"),
    ]
    box = box_style.render(lines.join("\n"))
    Crubbletea::Lipgloss.place(@width, @height,
      Crubbletea::Lipgloss::Style::Pos::Center,
      Crubbletea::Lipgloss::Style::Pos::Center, box)
  end

  def render_help_overlay(base : String) : String
    w = {(@width * 0.6).to_i, 56}.max
    help_view = help_model(w).view(self)
    lines = [Styles.title.render("Keyboard Shortcuts"), "", help_view, "", Styles.dim.render("Press any key to close")]
    box = Styles.help_box.width(w).render(lines.join("\n"))
    Crubbletea::Lipgloss.place(@width, @height,
      Crubbletea::Lipgloss::Style::Pos::Center,
      Crubbletea::Lipgloss::Style::Pos::Center, box)
  end
end

def run_tui
  Signal::USR1.trap { OmarchyTheme.reload! }
  program = Crubbletea::Program(App).new(App.new)
  program.run
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
  id = quests.empty? ? 1 : (quests.map(&.id).max + 1)
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
    puts Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.accent).render("Pending (#{pending.size})")
    pending.each do |t|
      puts "  ○ #{t.title}"
    end
  end

  unless done.empty?
    puts "" if !pending.empty?
    puts Crubbletea::Lipgloss::Style.new.bold(true).foreground(OmarchyTheme.green).render("Done (#{done.size})")
    done.each do |t|
      puts "  ✓ #{Crubbletea::Lipgloss::Style.new.foreground(OmarchyTheme.dim).strikethrough(true).render(t.title)}"
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
