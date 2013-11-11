module CukeSniffer

  # Author::    Robert Cochran  (mailto:cochrarj@miamioh.edu)
  # Copyright:: Copyright (C) 2013 Robert Cochran
  # License::   Distributes under the MIT License
  # This class is a representation of the cucumber objects
  # Background, Scenario, Scenario Outline
  #
  # Extends CukeSniffer::FeatureRulesEvaluator
  class Scenario < FeatureRuleTarget

    xml_accessor :start_line
    xml_accessor :steps, :as => [], :in => "steps"
    xml_accessor :examples_table, :as => [], :in => "examples"

    # int: Line on which the scenario begins
    attr_accessor :start_line

    # string: The type of scenario
    # Background, Scenario, Scenario Outline
    attr_accessor :type

    # string array: List of each step call in a scenario
    attr_accessor :steps

    # string array: List of each comment line before a scenario
    attr_accessor :comments

    # hash: Keeps each location and content of an inline table
    # * Key: Step string the inline table is attached to
    # * Value: Array of all of the lines in the table
    attr_accessor :inline_tables

    # string array: List of each example row in a scenario outline
    attr_accessor :examples_table

    # Location must be in the format of "file_path\file_name.rb:line_number"
    # Scenario must be a string array containing everything from the first tag to the last example table
    # where applicable.
    def initialize(location, scenario)
      super(location)
      @start_line = location.match(/:(?<line>\d*)$/)[:line].to_i
      @steps = []
      @inline_tables = {}
      @examples_table = []
      split_scenario(scenario)
    end

    def ==(comparison_object) # :nodoc:
      super(comparison_object) &&
      comparison_object.steps == steps &&
      comparison_object.examples_table == examples_table
    end

    def get_step_order
      order = []
      @steps.each do |line|
        next if is_comment?(line)
        match = line.match(STEP_REGEX)
        order << match[:style] unless match.nil?
      end
      order
    end

    def syntax_error?
      !!@syntax_error
    end

    private

    def split_scenario(source_lines)
      # Sometimes the lines come in with separators and sometimes they don't
      source_lines = source_lines.collect { |line| line.chomp }

      begin
        scenario = CucumberAnalytics::Scenario.new(source_lines.join("\n"))

        # todo - Refactor this once cucumber_analytics is updated
        case scenario.raw_element['keyword']
          when 'Scenario Outline'
            scenario = CucumberAnalytics::Outline.new(source_lines.join("\n"))
          when 'Background'
            scenario = CucumberAnalytics::Background.new(source_lines.join("\n"))
        end


        @type = scenario.raw_element['keyword']
        @comments = scenario.raw_element['comments'].collect { |comment| comment['value'] } if scenario.raw_element['comments']
        @tags = scenario.tags unless scenario.is_a?(CucumberAnalytics::Background)

        @name = scenario.name
        @name += ' ' + scenario.description.join(' ') unless scenario.description.empty?


        scenario.steps.each do |step|
          @steps += step.raw_element['comments'].collect { |comment| comment['value'] } if step.raw_element['comments']

          # This can be done more simply if whitespace retention is not required.
          @steps << source_lines[step.source_line - 2]

          if step.block.is_a?(CucumberAnalytics::Table)
            @inline_tables[@steps.last] = step.block.contents.collect { |table_row| '|' + table_row.join('|') + '|' }
          end
        end
        @steps.delete_if { |step| step !~ STEP_REGEX }


        if scenario.is_a?(CucumberAnalytics::Outline)
          scenario.examples.count.times do |example_count|
            example = scenario.examples[example_count]

            example.row_elements.count.times do |row_count|
              next if row_count == 0 && example_count != 0

              example_row = example.row_elements[row_count]

              @examples_table += example_row.raw_element['comments'].collect { |comment| comment['value'] } if example_row.raw_element['comments']

              # This can be done more simply if whitespace retention is not required.
              @examples_table << source_lines[example_row.source_line - 2]
            end
          end

          @examples_table.flatten!
          @examples_table.delete_if { |row| row !~ EXAMPLE_ROW_REGEX }
        end

      rescue Gherkin::Parser::ParseError
        @syntax_error = true
      end

    end
  end
end
