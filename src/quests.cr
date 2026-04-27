require "crubbletea"
require "json"
require "option_parser"
require "time"

DATA_DIR  = File.join(ENV["HOME"]? || "/tmp", ".local/share/quests")
DATA_FILE = File.join(DATA_DIR, "data.json")

PRIORITIES = ["high", "medium", "low"]
CATEGORIES = ["work", "personal", "home", "health", "finance", "learning", "errands", "other"]

PRIORITY_COLORS = {
  "high"   => "#FF6B6B",
  "medium" => "#FFD93D",
  "low"    => "#6BCB77",
}

PRIORITY_ICONS = {
  "high"   => "▲",
  "medium" => "●",
  "low"    => "▽",
}

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
  property done : Bool
  property priority : String
  property category : String
  property due : String
  property notes : String
  property created_at : String
  property completed_at : String

  def initialize(@id : Int32 = 0, @title : String = "", @done : Bool = false,
                 @priority : String = "medium", @category : String = "",
                 @due : String = "", @notes : String = "",
                 @created_at : String = Time.local.to_s("%Y-%m-%d %H:%M"),
                 @completed_at : String = "")
  end

  def self.from_json(h : JSON::Any) : Quest
    new(
      id: h["id"]?.try(&.as_i) || 0,
      title: h["title"]?.try(&.as_s) || "",
      done: h["done"]?.try(&.as_bool) || false,
      priority: h["priority"]?.try(&.as_s) || "medium",
      category: h["category"]?.try(&.as_s) || "",
      due: h["due"]?.try(&.as_s) || "",
      notes: h["notes"]?.try(&.as_s) || "",
      created_at: h["created_at"]?.try(&.as_s) || Time.local.to_s("%Y-%m-%d %H:%M"),
      completed_at: h["completed_at"]?.try(&.as_s) || ""
    )
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "id", @id
      json.field "title", @title
      json.field "done", @done
      json.field "priority", @priority
      json.field "category", @category
      json.field "due", @due
      json.field "notes", @notes
      json.field "created_at", @created_at
      json.field "completed_at", @completed_at
    end
  end

  def overdue? : Bool
    return false if @done || @due.empty?
    Time.parse(@due, "%Y-%m-%d", Time::Location.local).date < Time.local.date
  rescue Time::Format::Error
    false
  end

  def due_today? : Bool
    return false if @done || @due.empty?
    Time.parse(@due, "%Y-%m-%d", Time::Location.local).date == Time.local.date
  rescue Time::Format::Error
    false
  end
end

class FilterState
  property priority : String?
  property category : String?
  property status : String?
  property text : String

  def initialize
    @priority = nil
    @category = nil
    @status = nil
    @text = ""
  end

  def active? : Bool
    !@priority.nil? || !@category.nil? || !@status.nil? || !@text.empty?
  end

  def apply(quests : Array(Quest)) : Array(Quest)
    result = quests
    result = result.select { |t| t.priority == @priority } if @priority
    result = result.select { |t| t.category == @category } if @category
    result = result.select(&.done) if @status == "done"
    result = result.select { |t| !t.done } if @status == "pending"
    unless @text.empty?
      q = @text.downcase
      result = result.select { |t| t.title.downcase.includes?(q) }
    end
    result
  end

  def description : String
    parts = [] of String
    parts << "prio:#{@priority}" if @priority
    parts << "cat:#{@category}" if @category
    parts << @status.to_s if @status
    parts << "\"#{@text}\"" unless @text.empty?
    parts.empty? ? "none" : parts.join(", ")
  end
end

struct SaveMsg
  include Crubbletea::Msg
  getter quest : Quest
  def initialize(@quest : Quest); end
end

struct AddFormMsg
  include Crubbletea::Msg
end

struct FilterInputMsg
  include Crubbletea::Msg
end

class AddForm
  getter title_input : Crubbletea::Bubbles::TextInput::Model
  getter priority_input : Crubbletea::Bubbles::TextInput::Model
  getter category_input : Crubbletea::Bubbles::TextInput::Model
  getter due_input : Crubbletea::Bubbles::TextInput::Model
  getter notes_input : Crubbletea::Bubbles::TextInput::Model
  property field_index : Int32
  property quest : Quest

  FIELDS = 5

  def initialize(@quest : Quest = Quest.new)
    @field_index = 0

    @title_input = Crubbletea::Bubbles::TextInput::Model.new(
      prompt: "", placeholder: "What needs to be done?", width: 300
    )
    @title_input.value = @quest.title

    @priority_input = Crubbletea::Bubbles::TextInput::Model.new(
      prompt: "", placeholder: "high / medium / low", width: 300
    )
    @priority_input.value = @quest.priority

    @category_input = Crubbletea::Bubbles::TextInput::Model.new(
      prompt: "", placeholder: CATEGORIES.join(", "), width: 300
    )
    @category_input.value = @quest.category

    @due_input = Crubbletea::Bubbles::TextInput::Model.new(
      prompt: "", placeholder: "YYYY-MM-DD (or 'tomorrow', 'next week')", width: 300
    )
    @due_input.value = @quest.due

    @notes_input = Crubbletea::Bubbles::TextInput::Model.new(
      prompt: "", placeholder: "Additional notes...", width: 300
    )
    @notes_input.value = @quest.notes
  end

  def init : Crubbletea::Cmd?
    @title_input.focus
    nil
  end

  def focus_current : Nil
    [@title_input, @priority_input, @category_input, @due_input, @notes_input].each_with_index do |inp, i|
      i == @field_index ? inp.focus : inp.blur
    end
  end

  def update(msg) : {AddForm, Crubbletea::Cmd?}
    case msg
    when Crubbletea::KeyPressMsg
      key = msg.key
      case
      when key.to_s == "tab"
        @field_index = (@field_index + 1) % FIELDS
        focus_current
        return {self, nil}
      when key.to_s == "shift+tab"
        @field_index = (@field_index - 1) % FIELDS
        focus_current
        return {self, nil}
      when key.to_s == "enter"
        quest = build_quest
        return {self, ->{ SaveMsg.new(quest).as(Crubbletea::Msg) }}
      when key.code == Crubbletea::Key::Code::Escape
        return {self, ->{ AddFormMsg.new.as(Crubbletea::Msg) }}
      else
        update_current(msg)
      end
    else
      update_current(msg)
    end
    {self, nil}
  end

  private def update_current(msg)
    case @field_index
    when 0 then @title_input.update(msg)
    when 1 then @priority_input.update(msg)
    when 2 then @category_input.update(msg)
    when 3 then @due_input.update(msg)
    when 4 then @notes_input.update(msg)
    end
  end

  def build_quest : Quest
    due_str = @due_input.value.strip
    case due_str.downcase
    when "today"
      due_str = Time.local.to_s("%Y-%m-%d")
    when "tomorrow"
      due_str = (Time.local + 1.day).to_s("%Y-%m-%d")
    when "next week"
      due_str = (Time.local + 7.days).to_s("%Y-%m-%d")
    end

    t = @quest
    t.title = @title_input.value.strip
    prio = @priority_input.value.strip.downcase
    t.priority = PRIORITIES.includes?(prio) ? prio : "medium"
    t.category = @category_input.value.strip
    t.due = due_str
    t.notes = @notes_input.value.strip
    t
  end

  def view : String
    label_style = Crubbletea::Lipgloss::Style.new.bold(true).foreground("#7D56F4").width(14)
    value_style = Crubbletea::Lipgloss::Style.new.foreground("#DDD")
    dim_style = Crubbletea::Lipgloss::Style.new.foreground("#888")
    lines = [] of String
    header = Crubbletea::Lipgloss::Style.new.bold(true).foreground("#7D56F4")
      .render(@quest.id > 0 ? "  Edit Quest" : "  New Quest")
    lines << header
    lines << ""

    field_width = 60
    indent = " " * 14

    {"Title" => @title_input, "Priority" => @priority_input,
     "Category" => @category_input, "Due" => @due_input,
     "Notes" => @notes_input}.each_with_index do |(name, inp), i|
      prefix = i == @field_index ? "▸ " : "  "
      suffix = i == @field_index ? " ◄" : ""
      lbl = label_style.render("#{prefix}#{name}:")
      val = inp.value

      if val.empty?
        lines << "#{lbl}#{inp.view}#{suffix}"
      else
        wrapped = Crubbletea::Lipgloss::ANSI.wrap(val, field_width)
        wrap_lines = wrapped.split('\n')
        wrap_lines.each_with_index do |wl, wi|
          rendered = value_style.render(wl)
          if wi == 0
            lines << "#{lbl}#{rendered}"
          else
            lines << "#{indent}#{rendered}"
          end
        end
      end
    end

    lines << ""
    help_text = dim_style.render("  tab: next • enter: save • esc: cancel")
    lines << help_text
    lines.join("\n")
  end
end

module Styles
  BORDER       = Crubbletea::Lipgloss::Style.new
    .border(Crubbletea::Lipgloss::Border.rounded)
    .border_foreground("#7D56F4")
  TITLE        = Crubbletea::Lipgloss::Style.new.bold(true).foreground("#7D56F4")
  SUBTITLE     = Crubbletea::Lipgloss::Style.new.foreground("#888")
  DIM          = Crubbletea::Lipgloss::Style.new.foreground("#666")
  LABEL        = Crubbletea::Lipgloss::Style.new.foreground("#888").width(14).bold(true)
  VALUE        = Crubbletea::Lipgloss::Style.new.foreground("#DDD")
  STATUS_BAR   = Crubbletea::Lipgloss::Style.new.background("#1A1530").foreground("#AAA").padding(0, 1)
  FORM_BOX     = Crubbletea::Lipgloss::Style.new
    .border(Crubbletea::Lipgloss::Border.rounded)
    .border_foreground("#7D56F4").padding(1, 2)

  CHECK_DONE   = Crubbletea::Lipgloss::Style.new.foreground("#6BCB77")
  CHECK_OPEN   = Crubbletea::Lipgloss::Style.new.foreground("#888")
  TITLE_DONE   = Crubbletea::Lipgloss::Style.new.foreground("#666").strikethrough(true)
  TITLE_SEL    = Crubbletea::Lipgloss::Style.new.foreground("#FFF").bold(true)
  TITLE_NORM   = Crubbletea::Lipgloss::Style.new.foreground("#DDD")
  PRIO_HIGH    = Crubbletea::Lipgloss::Style.new.foreground("#FF6B6B").bold(true)
  PRIO_MEDIUM  = Crubbletea::Lipgloss::Style.new.foreground("#FFD93D").bold(true)
  PRIO_LOW     = Crubbletea::Lipgloss::Style.new.foreground("#6BCB77").bold(true)
  CATEGORY     = Crubbletea::Lipgloss::Style.new.foreground("#7D56F4")
  DUE_NORM     = Crubbletea::Lipgloss::Style.new.foreground("#888")
  DUE_OVERDUE  = Crubbletea::Lipgloss::Style.new.foreground("#FF6B6B")
  DUE_TODAY    = Crubbletea::Lipgloss::Style.new.foreground("#FFD93D")
  SEL_BG       = Crubbletea::Lipgloss::Style.new.background("#2A2040")
  STATUS_DONE  = Crubbletea::Lipgloss::Style.new.foreground("#6BCB77")
  STATUS_OPEN  = Crubbletea::Lipgloss::Style.new.foreground("#FFD93D")
  NOTES_LABEL  = Crubbletea::Lipgloss::Style.new.foreground("#888").bold(true)
  NOTES_VAL    = Crubbletea::Lipgloss::Style.new.foreground("#BBB")
  HELP_KEY     = Crubbletea::Lipgloss::Style.new.bold(true).foreground("#FFD93D").width(16)
  HELP_DESC    = Crubbletea::Lipgloss::Style.new.foreground("#DDD")
  HELP_BOX     = Crubbletea::Lipgloss::Style.new
    .border(Crubbletea::Lipgloss::Border.rounded)
    .border_foreground("#7D56F4").padding(1, 3).background("#1A1530")
  DELETE_LABEL = Crubbletea::Lipgloss::Style.new.foreground("#FF6B6B")

  PRIO_STYLES  = {
    "high"   => PRIO_HIGH,
    "medium" => PRIO_MEDIUM,
    "low"    => PRIO_LOW,
  } of String => Crubbletea::Lipgloss::Style
end

enum AppMode
  Main
  Add
  Edit
  Delete
  Filter
  Help
end

class App
  include Crubbletea::Model
  include Crubbletea::Bubbles::Help::KeyMap

  PRIO_ORDER = {"high" => 0, "medium" => 1, "low" => 2}

  @quests : Array(Quest)
  @cursor : Int32
  @mode : AppMode
  @form : AddForm?
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

  def initialize
    @quests = QuestStore.load
    @cursor = 0
    @mode = AppMode::Main
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
    Crubbletea::Bubbles::Key.new_binding("/", help_key: "/", help_desc: "filter"),
    Crubbletea::Bubbles::Key.new_binding("x", help_key: "x", help_desc: "clear filter"),
    Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "help"),
    Crubbletea::Bubbles::Key.new_binding("q", help_key: "q", help_desc: "quit"),
  ]

  HELP_FULL = [
    [
      Crubbletea::Bubbles::Key.new_binding("a", help_key: "a", help_desc: "Add new quest"),
      Crubbletea::Bubbles::Key.new_binding("e", help_key: "e", help_desc: "Edit selected quest"),
      Crubbletea::Bubbles::Key.new_binding("d", help_key: "d", help_desc: "Delete selected quest"),
      Crubbletea::Bubbles::Key.new_binding(" ", help_key: "space", help_desc: "Toggle done/pending"),
      Crubbletea::Bubbles::Key.new_binding("up", "k", help_key: "↑/k", help_desc: "Navigate up"),
      Crubbletea::Bubbles::Key.new_binding("down", "j", help_key: "↓/j", help_desc: "Navigate down"),
      Crubbletea::Bubbles::Key.new_binding("g", help_key: "g", help_desc: "Jump to top"),
      Crubbletea::Bubbles::Key.new_binding("G", help_key: "G", help_desc: "Jump to bottom"),
      Crubbletea::Bubbles::Key.new_binding("pgup", "pgdown", help_key: "PgUp/PgDn", help_desc: "Page up/down"),
      Crubbletea::Bubbles::Key.new_binding("/", help_key: "/", help_desc: "Filter/search"),
      Crubbletea::Bubbles::Key.new_binding("x", help_key: "x", help_desc: "Clear filter"),
      Crubbletea::Bubbles::Key.new_binding("?", help_key: "?", help_desc: "Show help"),
      Crubbletea::Bubbles::Key.new_binding("q", "ctrl+c", help_key: "q/Ctrl+C", help_desc: "Quit"),
    ],
  ]

  def short_help : Array(Crubbletea::Bubbles::Key::Binding)
    HELP_BINDINGS
  end

  def full_help : Array(Array(Crubbletea::Bubbles::Key::Binding))
    HELP_FULL
  end

  def help_model(box_w : Int32) : Crubbletea::Bubbles::Help::HelpModel
    Crubbletea::Bubbles::Help::HelpModel.new(
      show_all: true,
      width: box_w,
      styles: Crubbletea::Bubbles::Help::Styles.new(
        full_key: Crubbletea::Lipgloss::Style.new.bold(true).foreground("#FFD93D").width(12),
        full_desc: Crubbletea::Lipgloss::Style.new.foreground("#DDD"),
      ),
    )
  end

  def short_help_model : Crubbletea::Bubbles::Help::HelpModel
    Crubbletea::Bubbles::Help::HelpModel.new(
      show_all: false,
      width: @width,
      styles: Crubbletea::Bubbles::Help::Styles.new(
        short_key: Crubbletea::Lipgloss::Style.new.foreground("#AAA").inline(true),
        short_desc: Crubbletea::Lipgloss::Style.new.foreground("#888").inline(true),
      ),
    )
  end

  def filtered_quests : Array(Quest)
    return @cache_ft.not_nil! if @cache_valid
    @cache_valid = true
    pending = @quests.reject(&.done).sort_by { |t|
      "#{PRIO_ORDER[t.priority]? || 1}-#{t.due.empty? ? "9999" : t.due}"
    }
    done = @quests.select(&.done).sort_by { |t| t.completed_at }.reverse
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

  def init : Crubbletea::Cmd?
    nil
  end

  def update(msg) : {App, Crubbletea::Cmd?}
    case msg
    when SaveMsg
      return handle_save(msg)
    when Crubbletea::WindowSizeMsg
      @width = msg.width
      @height = msg.height
      mark_dirty
      return {self, nil}
    end

    if @mode == AppMode::Help
      if msg.is_a?(Crubbletea::KeyPressMsg)
        @mode = AppMode::Main
        mark_dirty
      end
      return {self, nil}
    end

    if @mode == AppMode::Add || @mode == AppMode::Edit
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
      @mode = AppMode::Add; @form = AddForm.new; @form.not_nil!.init; mark_dirty; return {self, nil}
    when key.text == "e"
      quest = current_quest; return {self, nil} unless quest
      @mode = AppMode::Edit; @form = AddForm.new(quest); @form.not_nil!.init; mark_dirty; return {self, nil}
    when key.text == "d"
      return {self, nil} unless current_quest; @mode = AppMode::Delete; mark_dirty
    when key.code == Crubbletea::Key::Code::Space
      quest = current_quest; return {self, nil} unless quest
      quest.done = !quest.done
      quest.completed_at = quest.done ? Time.local.to_s("%Y-%m-%d %H:%M") : ""
      save; invalidate_cache
    when key.text == "/"
      @mode = AppMode::Filter; @filter_input = Crubbletea::Bubbles::TextInput::Model.new(
        placeholder: "type to filter...", width: 30
      )
      @filter_input.focus; mark_dirty; return {self, nil}
    when key.text == "x"
      @filter = FilterState.new; @cursor = 0; @scroll_offset = 0; invalidate_cache
    when key.text == "?"
      @mode = AppMode::Help; mark_dirty
    end
    {self, nil}
  end

  def handle_form(msg) : {App, Crubbletea::Cmd?}
    if msg.is_a?(Crubbletea::KeyPressMsg) && msg.key.code == Crubbletea::Key::Code::Escape
      @mode = AppMode::Main; @form = nil; mark_dirty; return {self, nil}
    end
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
        @mode = AppMode::Main; @filter_input.blur; mark_dirty; return {self, nil}
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
    @height - 7 > 0 ? @height - 7 : 1
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
    v.mouse_mode = Crubbletea::MouseMode::CellMotion
    v.content = build_view
    if (@mode == AppMode::Add || @mode == AppMode::Edit) && @form
      cursor = compute_form_cursor
      v.cursor = cursor if cursor
    elsif @mode == AppMode::Filter && @filter_input.focused?
      cx = 9 + @filter_input.cursor_pos
      v.cursor = Crubbletea::Cursor.new(cx, @height - 3)
    end
    v
  end

  def compute_form_cursor : Crubbletea::Cursor?
    form = @form
    return nil unless form

    form_view_str = form.view
    form_lines = form_view_str.split('\n')
    box_w = {@width - 4, 80}.min
    box_content_h = form_lines.size
    box_h = box_content_h + 2 + 2
    start_x = (@width - box_w) // 2
    start_y = (@height - box_h) // 2
    start_y = {start_y, 0}.max

    label_w = 14
    field_w = box_w - 6 - label_w
    field_w = {field_w, 1}.max

    inputs = [form.title_input, form.priority_input, form.category_input, form.due_input, form.notes_input]
    row_offset = 2
    target_col = 0_i32

    inputs.each_with_index do |inp, fi|
      rows = compute_wrapped_rows(inp.value, field_w)
      if fi == form.field_index
        cp = inp.cursor_pos
        val = inp.value
        if val.empty?
          target_col = label_w
        else
          wline, wcol = simulate_wrap_cursor(val, cp, field_w)
          row_offset += wline
          target_col = label_w + wcol
        end
        break
      end
      row_offset += rows
    end

    screen_x = start_x + 3 + target_col
    screen_y = start_y + 1 + 1 + row_offset

    screen_x = {screen_x, @width - 2}.min
    screen_y = {screen_y, @height - 2}.min

    Crubbletea::Cursor.new(screen_x, screen_y)
  end

  def compute_wrapped_rows(val : String, field_w : Int32) : Int32
    return 1 if val.empty?
    wrapped = Crubbletea::Lipgloss::ANSI.wrap(val, field_w)
    {wrapped.split('\n').size, 1}.max
  end

  def simulate_wrap_cursor(val : String, cursor_pos : Int32, width : Int32) : {Int32, Int32}
    return {0, 0} if val.empty? || cursor_pos <= 0
    words = val.split(' ')
    wrap_line = 0
    col_in_line = 0
    orig_pos = 0
    line_w = 0

    words.each_with_index do |word, i|
      if i > 0
        if line_w + 1 + {word.size, width}.min > width
          wrap_line += 1
          col_in_line = 0
          line_w = 0
        else
          return {wrap_line, col_in_line} if orig_pos >= cursor_pos
          col_in_line += 1
          line_w += 1
        end
        orig_pos += 1
        return {wrap_line, col_in_line} if orig_pos >= cursor_pos
      end

      if word.size <= width
        word.size.times do
          return {wrap_line, col_in_line} if orig_pos >= cursor_pos
          orig_pos += 1
          col_in_line += 1
          line_w += 1
        end
      else
        word.each_char do
          if line_w >= width
            wrap_line += 1
            col_in_line = 0
            line_w = 0
          end
          return {wrap_line, col_in_line} if orig_pos >= cursor_pos
          orig_pos += 1
          col_in_line += 1
          line_w += 1
        end
      end
    end

    {wrap_line, col_in_line}
  end

  def build_view : String
    if @mode == AppMode::Add || @mode == AppMode::Edit
      return render_form_overlay
    end
    left = render_list_panel
    right = render_detail_panel
    joined = Crubbletea::Lipgloss.join_horizontal(
      Crubbletea::Lipgloss::Style::Pos::Top, [left, right]
    )
    base = Crubbletea::Lipgloss.join_vertical(
      Crubbletea::Lipgloss::Style::Pos::Top, [joined, render_status_bar]
    )
    case @mode
    when AppMode::Delete
      render_delete_overlay(base)
    when AppMode::Help
      render_help_overlay(base)
    else
      base
    end
  end

  def panel_widths : {Int32, Int32}
    usable = @width - 1
    half = usable // 2
    {half, half}
  end

  def render_list_panel : String
    w = panel_widths[0]
    h = @height - 3
    @list_content_w = w
    ft = filtered_quests
    pending = ft.count { |t| !t.done }
    header = "#{Styles::TITLE.render("Quests")} #{Styles::SUBTITLE.render("[#{pending} pending, #{ft.size - pending} done]")}"
    if ft.size > list_height
      range = "#{@scroll_offset + 1}-{@scroll_offset + list_height}"
      header += " #{Styles::DIM.render("#{range}/#{ft.size}")}"
    end
    lines = [header, ""]
    if ft.empty?
      lines << Styles::DIM.render("  No quests yet. Press 'a' to add one.")
      (h - 4).times { lines << "" }
    else
      end_idx = {@scroll_offset + list_height, ft.size}.min
      (@scroll_offset...end_idx).each { |i| lines << render_quest_line(ft[i], i == @cursor) }
      remaining = list_height - lines.size + 2
      remaining.times { lines << "" } if remaining > 0
    end
    Styles::BORDER.width(w).height(h).render(lines.join("\n"))
  end

  def render_quest_line(quest : Quest, selected : Bool) : String
    max_w = @list_content_w - 4
    check = (quest.done ? Styles::CHECK_DONE : Styles::CHECK_OPEN).render(quest.done ? "✓" : "○")
    ts = quest.done ? Styles::TITLE_DONE : selected ? Styles::TITLE_SEL : Styles::TITLE_NORM
    title = ts.render(truncate_visible(quest.title, {max_w - 10, 4}.max))
    extras = [] of String
    extras << Styles::CATEGORY.render("##{quest.category}") unless quest.category.empty?
    extras << (Styles::PRIO_STYLES[quest.priority]? || Styles::PRIO_MEDIUM)
      .render(PRIORITY_ICONS[quest.priority]? || "●")
    unless quest.due.empty?
      ds = quest.overdue? ? Styles::DUE_OVERDUE : quest.due_today? ? Styles::DUE_TODAY : Styles::DUE_NORM
      extras << ds.render("⏰#{quest.due}")
    end
    line = "#{selected ? "▸ " : "  "}#{check} #{title} #{extras.join(" ")}"
    line = truncate_visible(line, max_w)
    selected ? Styles::SEL_BG.render(line) : line
  end

  def render_detail_panel : String
    w = panel_widths[1]
    h = @height - 3
    cw = w - 2
    quest = current_quest
    unless quest
      return Styles::BORDER.width(w).height(h)
        .render(Styles::DIM.render("Select a quest to view details"))
    end
    title_text = Crubbletea::Lipgloss::ANSI.wrap(quest.title, cw)
    lines = title_text.split('\n').map { |l| Styles::TITLE.render(l) }
    lines << ""
    s_done = quest.done ? Styles::STATUS_DONE.render("✓ Done") : Styles::STATUS_OPEN.render("○ Pending")
    s_prio = (Styles::PRIO_STYLES[quest.priority]? || Styles::PRIO_MEDIUM)
      .render(quest.priority.capitalize)
    s_cat = quest.category.empty? ? Styles::SUBTITLE.render("(none)") :
      Styles::CATEGORY.render(truncate_visible(quest.category, cw - 16))
    s_due = if quest.due.empty?
              Styles::SUBTITLE.render("(none)")
            elsif quest.overdue?
              Styles::DUE_OVERDUE.render(truncate_visible("#{quest.due} (OVERDUE!)", cw - 16))
            elsif quest.due_today?
              Styles::DUE_TODAY.render(truncate_visible("#{quest.due} (TODAY)", cw - 16))
            else
              Styles::DUE_NORM.render(quest.due)
            end
    lines << "#{Styles::LABEL.render("Status:")} #{s_done}"
    lines << "#{Styles::LABEL.render("Priority:")} #{s_prio}"
    lines << "#{Styles::LABEL.render("Category:")} #{s_cat}"
    lines << "#{Styles::LABEL.render("Due:")} #{s_due}"
    lines << "#{Styles::LABEL.render("Created:")} #{Styles::VALUE.render(quest.created_at)}"
    lines << "#{Styles::LABEL.render("Completed:")} #{quest.completed_at.empty? ? Styles::SUBTITLE.render("-") : Styles::VALUE.render(quest.completed_at)}"
    unless quest.notes.empty?
      lines << ""
      lines << Styles::NOTES_LABEL.render("Notes:")
      wrapped_notes = Crubbletea::Lipgloss::ANSI.wrap(quest.notes, cw)
      lines << Styles::NOTES_VAL.render(truncate_visible(wrapped_notes, cw * 5))
    end
    Styles::BORDER.width(w).height(h).render(lines.join("\n"))
  end

  def render_status_bar : String
    w = @width - 1
    left_text = case @mode
                when AppMode::Delete
                  Styles::DELETE_LABEL.render("CONFIRM DELETE (y/n)")
                when AppMode::Filter
                  "FILTER: #{@filter_input.value}"
                else
                  filter_desc = @filter.active? ? " [#{@filter.description}]" : ""
                  short_help_model.view(self) + filter_desc
                end
    Styles::STATUS_BAR.width(w).render(left_text)
  end

  def render_delete_overlay(base : String) : String
    quest = current_quest
    title = quest ? quest.title : "this item"
    box_style = Styles::BORDER.border_foreground("#FF6B6B").padding(1, 3)
      .width({(@width * 0.5).to_i, 44}.max)
    lines = [
      Styles::DELETE_LABEL.render("Delete Quest?"),
      "",
      Styles::TITLE_NORM.render(title),
      "",
      Styles::DIM.render("y: confirm   n/esc: cancel"),
    ]
    box = box_style.render(lines.join("\n"))
    Crubbletea::Lipgloss.place(@width, @height,
      Crubbletea::Lipgloss::Style::Pos::Center,
      Crubbletea::Lipgloss::Style::Pos::Center, box)
  end

  def render_form_overlay : String
    form = @form
    box = Styles::FORM_BOX.width({@width - 4, 80}.min)
      .render(form ? form.view : "")
    Crubbletea::Lipgloss.place(@width, @height,
      Crubbletea::Lipgloss::Style::Pos::Center,
      Crubbletea::Lipgloss::Style::Pos::Center, box)
  end

  def render_help_overlay(base : String) : String
    w = {(@width * 0.6).to_i, 56}.max
    help_view = help_model(w).view(self)
    lines = [Styles::TITLE.render("Keyboard Shortcuts"), "", help_view, "", Styles::DIM.render("Press any key to close")]
    box = Styles::HELP_BOX.width(w).render(lines.join("\n"))
    Crubbletea::Lipgloss.place(@width, @height,
      Crubbletea::Lipgloss::Style::Pos::Center,
      Crubbletea::Lipgloss::Style::Pos::Center, box)
  end

end

def run_tui
  program = Crubbletea::Program(App).new(App.new)
  program.run
end

def waybar_output
  quests = QuestStore.load
  pending = quests.count { |t| !t.done }
  overdue = quests.count { |t|
    next false if t.done || t.due.empty?
    t.overdue?
  }
  today = quests.count { |t|
    next false if t.done || t.due.empty?
    t.due_today?
  }

  if pending == 0
    json = {text: "✓", tooltip: "All done!", class: "done"}
  elsif overdue > 0
    json = {text: "⚠ #{pending}", tooltip: "#{overdue} overdue, #{today} due today, #{pending} total pending", class: "overdue"}
  elsif today > 0
    json = {text: "📋 #{pending}", tooltip: "#{today} due today, #{pending} total pending", class: "today"}
  else
    json = {text: "📋 #{pending}", tooltip: "#{pending} pending tasks", class: "normal"}
  end

  puts json.to_json
end

def notify_overdue
  quests = QuestStore.load
  overdue = quests.select { |t|
    next false if t.done || t.due.empty?
    t.overdue?
  }
  today = quests.select { |t|
    next false if t.done || t.due.empty?
    t.due_today?
  }
  return if overdue.empty? && today.empty?

  msgs = [] of String
  unless overdue.empty?
    msgs << "Overdue:"
    overdue.first(5).each { |t| msgs << "  ▸ #{t.title} (#{t.due})" }
    msgs << "  ... and #{overdue.size - 5} more" if overdue.size > 5
  end
  unless today.empty?
    msgs << "Due today:"
    today.first(5).each { |t| msgs << "  ▸ #{t.title}" }
    msgs << "  ... and #{today.size - 5} more" if today.size > 5
  end

  Process.run("notify-send", ["-i", "alarm", "Quest Reminder", msgs.join("\n")])
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
  found.completed_at = found.done ? Time.local.to_s("%Y-%m-%d %H:%M") : ""
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
    puts Crubbletea::Lipgloss::Style.new.bold(true).foreground("#7D56F4").render("Pending (#{pending.size})")
    pending.each do |t|
      icon = PRIORITY_ICONS[t.priority]? || "●"
      color = PRIORITY_COLORS[t.priority]? || "#888"
      due_str = t.due.empty? ? "" : " ⏰#{t.due}"
      cat_str = t.category.empty? ? "" : " ##{t.category}"
      line = "  ○ #{Crubbletea::Lipgloss::Style.new.foreground(color).render(icon)} #{t.title}#{cat_str}#{due_str}"
      puts line
    end
  end

  unless done.empty?
    puts "" if !pending.empty?
    puts Crubbletea::Lipgloss::Style.new.bold(true).foreground("#6BCB77").render("Done (#{done.size})")
    done.each do |t|
      puts "  ✓ #{Crubbletea::Lipgloss::Style.new.foreground("#666").strikethrough(true).render(t.title)}"
    end
  end
end

do_waybar = false
do_notify = false
do_count = false

parser = OptionParser.new do |opts|
  opts.banner = "Usage: quest [options] [subcommand] [args]"
  opts.separator ""
  opts.separator "Subcommands:"
  opts.separator "  quest                          Launch TUI (default)"
  opts.separator "  quest add \"Task name\"          Quick add a quest"
  opts.separator "  quest done <id>                Toggle done status"
  opts.separator "  quest list                     List quests in terminal"
  opts.separator ""
  opts.separator "Integration options:"
  opts.on("--waybar", "Output waybar JSON module") { do_waybar = true }
  opts.on("--notify", "Send desktop notification for overdue/today") { do_notify = true }
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
elsif do_count && do_notify
  quests = QuestStore.load
  pending = quests.count { |t| !t.done }
  notify_overdue
  puts pending
elsif do_count
  puts QuestStore.load.count { |t| !t.done }
elsif do_notify
  notify_overdue
else
  case subcommand
  when "add"
    arg_title = ARGV.join(" ")
    if arg_title.empty?
      STDERR.puts "Usage: quest add \"Task name\""
      exit 1
    end
    quick_add(arg_title)
  when "done"
    arg_id = ARGV.shift?
    if arg_id.nil?
      STDERR.puts "Usage: quest done <id>"
      exit 1
    end
    quick_done(arg_id.to_i)
  when "list"
    quick_list
  when nil
    run_tui
  else
    STDERR.puts "Unknown subcommand: #{subcommand}"
    STDERR.puts "Run 'quest --help' for usage"
    exit 1
  end
end
