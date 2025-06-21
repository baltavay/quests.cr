module Quests
  # Represents a single quest item
  #
  # A quest has a title and a completion status. It can be marked as completed
  # or incomplete, and provides a simple data structure for quest management.
  #
  # ## Example
  #
  # ```
  # quest = Quests::Quest.new("Learn Crystal programming")
  # quest.completed # => false
  # quest.complete!
  # quest.completed # => true
  # ```
  class Quest
    # The title/description of the quest
    property title : String
    
    # Whether the quest is completed
    property completed : Bool

    # Create a new quest
    #
    # - *title* - The quest title/description
    # - *completed* - Whether the quest starts as completed (default: false)
    def initialize(@title : String, @completed : Bool = false)
    end

    # Mark the quest as completed
    def complete!
      @completed = true
    end

    # Mark the quest as incomplete
    def incomplete!
      @completed = false
    end

    # Toggle the completion status
    def toggle!
      @completed = !@completed
    end

    # Returns a string representation of the quest
    def to_s(io)
      marker = @completed ? "✓" : " "
      io << "[#{marker}] #{@title}"
    end
  end
end