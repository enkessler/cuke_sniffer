require 'spec_helper'
require 'cuke_sniffer/hook'

describe CukeSniffer::Hook do
  after(:each) do
    delete_temp_files
  end

  it "should break down the content of a hook and store it" do
    hook_block = [
        "AfterConfiguration do",
        "1+1",
        "end"
    ]
    hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
    expect(hook.type).to eq "AfterConfiguration"
    expect(hook.code).to eq ["1+1"]
    expect(hook.tags).to be_empty
    expect(hook.location).to eq "location.rb:1"
    expect(hook.parameters).to be_empty
  end

  it "should parse the tag filter of a hook correctly and store it" do
    hook_block = [
        "Before(\"@tag1\", '@tag2,@tag3', '~@tag4') do",
        "end"
    ]
    hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
    expect(hook.type).to eq "Before"
    expect(hook.code).to be_empty
    expect(hook.tags).to eq ["@tag1", "@tag2,@tag3", "~@tag4"]
    expect(hook.location).to eq "location.rb:1"
    expect(hook.parameters).to eq []
  end

  it "should parse the parameters of a hook correctly and store it" do
    hook_block = [
        "Before do |scenario, block|",
        "end"
    ]
    hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
    expect(hook.parameters).to eq ["scenario", "block"]
  end

  describe "#around?" do
    it "returns true when the hook is an Around" do
      hook_block = [
          "Around do |scenario, block|",
          "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.around?).to be true
    end

    it "returns false when the hook is not Around" do
      hook_block = [
          "Before do", "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.around?).to be false
    end
  end

  describe "#calls_block?" do
    it "returns true when the block is called" do
      hook_block = [
          "Around do |scenario, block|",
          "block.call",
          "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.calls_block?).to be true
    end

    it "returns false when the block is not called" do
      hook_block = [
          "Before do", "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.calls_block?).to be false
    end
  end

  describe "#conflicting_tags?" do
    it "returns true when there is a ~@tag1 and @tag appearing" do
      hook_block = [
          "Before('@tag1', '~@tag1') do", "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.conflicting_tags?).to be true
    end

    it "returns false when there is a no tags" do
      hook_block = [
          "Before do", "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.conflicting_tags?).to be false
    end

    it "returns false when all tags are unique" do
      hook_block = [
          "Before('@tag1', '~@tag2') do", "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.conflicting_tags?).to be false
    end
  end

  describe "#rescues?" do
    it "returns true when there is no code for the hook" do
      hook_block = [
          "Before do", "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.rescues?).to be true
    end

    it "returns true when there is code and a begin/rescue block" do
      hook_block = [
          "Before do",
          "begin",
          "something that might throw an exception",
          "rescue Exception => e",
          "do something with the exception",
          "end",
          "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.rescues?).to be_truthy
    end

    it "returns false when there is code and no begin/rescue block" do
      hook_block = [
          "Before do",
          "non rescue block code",
          "end"
      ]
      hook = CukeSniffer::Hook.new("location.rb:1", hook_block)
      expect(hook.rescues?).to be_falsey
    end
  end

end

describe "HookRules" do
  def run_rule_against_hook(hook_block, rule)
    @cli.hooks = [CukeSniffer::Hook.new(@file_name + ":1", hook_block)]
    CukeSniffer::RulesEvaluator.new(@cli, [rule])
  end

  def test_hook_rule(hook_block, symbol, count = 1)
    rule = CukeSniffer::CukeSnifferHelper.build_rule(symbol, RULES[symbol])
    run_rule_against_hook(hook_block, rule)
    rule.phrase.gsub!("{class}", "Hook")
    verify_rule(@cli.hooks.first, rule, count)
  end

  def test_no_hook_rule(hook_block, symbol)
    rule = CukeSniffer::CukeSnifferHelper.build_rule(symbol, RULES[symbol])
    run_rule_against_hook(hook_block, rule)
    rule.phrase.gsub!("{class}", "Hook")
    verify_no_rule(@cli.hooks.first, rule)
  end

  before(:each) do
    @cli = CukeSniffer::CLI.new()
    @file_name = "hooks.rb"
  end

  after(:each) do
    delete_temp_files
  end

  it "should punish Hooks without content" do
    hook_block = [
        "Before do",
        "end"
    ]
    test_hook_rule(hook_block, :empty_hook)
  end

  it "should punish hooks that exist outside of the hooks.rb file" do
    hook_block = [
        "Before do",
        "end"
    ]
    @file_name = "env.rb"
    test_hook_rule(hook_block, :hook_not_in_hooks_file)
  end

  it "should punish Around hooks that do not have 2 parameters. 0 parameters." do
    hook_block = [
        "Around do",
        "end"
    ]
    test_hook_rule(hook_block, :around_hook_without_2_parameters)
  end

  it "should punish Around hooks that do not have 2 parameters. 1 parameter." do
    hook_block = [
        "Around do |a|",
        "end"
    ]
    test_hook_rule(hook_block, :around_hook_without_2_parameters)
  end

  it "should punish Around hooks that do not have 2 parameters. 3 parameters." do
    hook_block = [
        "Around do |a, b, c|",
        "end"
    ]
    test_hook_rule(hook_block, :around_hook_without_2_parameters)
  end

  it "should punish Around hooks that never have a call on their 2nd parameter. The scenario is not called." do
    hook_block = [
        "Around do |scenario, block|",
        "end"
    ]
    test_hook_rule(hook_block, :around_hook_no_block_call)
  end

  it "should punish hooks without a begin/rescue for debugging." do
    hook_block = [
        "Before do",
        "# code",
        "end"
    ]
    test_hook_rule(hook_block, :hook_no_debugging)
  end

  it "should not punish hooks for a begin/rescue for debugging when there is no code." do
    hook_block = [
        "Before do",
        "end"
    ]
    test_no_hook_rule(hook_block, :hook_no_debugging)
  end

  it "should punish hooks that are all comments" do
    hook_block = [
        "Before do",
        "# comment",
        "# comment",
        "end"
    ]
    test_hook_rule(hook_block, :hook_all_comments)
  end

  it "should punish hooks with negated tags on and'd tags" do
    hook_block = [
        "Before('@tag', '~@tag') do",
        "end"
    ]
    test_hook_rule(hook_block, :hook_conflicting_tags)
  end

  it "should punish hooks with negated tags on or'd tags" do
    hook_block = [
        "Before('@tag,~@tag') do",
        "end"
    ]
    test_hook_rule(hook_block, :hook_conflicting_tags)
  end

  it "should punish hooks with duplicate tags" do
    hook_block = [
        "Before('@tag,@tag') do",
        "end"
    ]
    test_hook_rule(hook_block, :hook_duplicate_tags)
  end

end