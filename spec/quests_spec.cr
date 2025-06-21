require "./spec_helper"

describe Quests do
  it "has a version number" do
    Quests::VERSION.should_not be_nil
    Quests::VERSION.should eq("0.1.0")
  end

  describe "module structure" do
    it "defines Quest class" do
      Quests::Quest.should_not be_nil
    end

    it "defines App class" do
      Quests::App.should_not be_nil
    end
  end
end
