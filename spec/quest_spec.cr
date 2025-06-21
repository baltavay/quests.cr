require "./spec_helper"

describe Quests::Quest do
  describe "#initialize" do
    it "creates a quest with title and default not completed" do
      quest = Quests::Quest.new("Test quest")
      quest.title.should eq("Test quest")
      quest.completed.should be_false
    end

    it "creates a quest with custom completion status" do
      quest = Quests::Quest.new("Completed quest", completed: true)
      quest.title.should eq("Completed quest")
      quest.completed.should be_true
    end
  end

  describe "#complete!" do
    it "marks quest as completed" do
      quest = Quests::Quest.new("Test quest")
      quest.complete!
      quest.completed.should be_true
    end
  end

  describe "#incomplete!" do
    it "marks quest as incomplete" do
      quest = Quests::Quest.new("Test quest", completed: true)
      quest.incomplete!
      quest.completed.should be_false
    end
  end

  describe "#toggle!" do
    it "toggles completion status from false to true" do
      quest = Quests::Quest.new("Test quest")
      quest.toggle!
      quest.completed.should be_true
    end

    it "toggles completion status from true to false" do
      quest = Quests::Quest.new("Test quest", completed: true)
      quest.toggle!
      quest.completed.should be_false
    end
  end

  describe "#to_s" do
    it "displays incomplete quest with empty marker" do
      quest = Quests::Quest.new("Test quest")
      quest.to_s.should eq("[ ] Test quest")
    end

    it "displays completed quest with checkmark marker" do
      quest = Quests::Quest.new("Test quest", completed: true)
      quest.to_s.should eq("[✓] Test quest")
    end
  end

  describe "property access" do
    it "allows reading and writing title" do
      quest = Quests::Quest.new("Original title")
      quest.title = "New title"
      quest.title.should eq("New title")
    end

    it "allows reading and writing completed status" do
      quest = Quests::Quest.new("Test quest")
      quest.completed = true
      quest.completed.should be_true
    end
  end
end