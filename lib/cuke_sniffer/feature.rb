module CukeSniffer

  # Author::    Robert Cochran  (mailto:cochrarj@miamioh.edu)
  # Copyright:: Copyright (C) 2013 Robert Cochran
  # License::   Distributes under the MIT License
  # Handles feature files and disassembles and evaluates
  # its components.
  # Extends CukeSniffer::FeatureRulesEvaluator
  class Feature < FeatureRuleTarget

    xml_accessor :scenarios, :as => [CukeSniffer::FeatureRuleTarget], :in => "scenarios"

    SCENARIO_TITLE_REGEX = /#{COMMENT_REGEX}#{SCENARIO_TITLE_STYLES}(?<name>.*)/ # :nodoc:

    # Scenario: The background of a Feature, created as a Scenario object
    attr_accessor :background

    # Scenario array: A list of all scenarios contained in a feature file
    attr_accessor :scenarios

    # int: Total score from all of the scenarios contained in the feature
    attr_accessor :scenarios_score

    # int: Total score of the feature and its scenarios
    attr_accessor :total_score

    # String array: A list of all the lines in a feature file
    attr_accessor :feature_lines

    # string array: List of each comment line before a feature
    attr_accessor :comments

    # file_name must be in the format of "file_path\file_name.feature"
    def initialize(file_name)
      super(file_name)
      @scenarios = []
      @scenarios_score = 0
      @total_score = 0
      @feature_lines = IO.readlines(file_name)
      split_feature(file_name, feature_lines) unless @feature_lines == []
    end

    def ==(comparison_object) # :nodoc:
      super(comparison_object) &&
          comparison_object.scenarios == scenarios
    end

    def update_score
      @scenarios_score += @background.score unless @background.nil?
      @scenarios.each { |scenario| @scenarios_score += scenario.score }
      @total_score = @scenarios_score + @score
    end

    private

    def split_feature(file_name, feature_lines)
      ca_feature = CucumberAnalytics::Feature.new(feature_lines.join)

      @comments = ca_feature.raw_element['comments'].collect { |comment| comment['value'] } if ca_feature.raw_element['comments']
      @tags = ca_feature.tags

      @name = ca_feature.name
      @name += ' ' + ca_feature.description.join(' ') unless ca_feature.description.empty?


      scenarios = ca_feature.has_background? ? [ca_feature.background] + ca_feature.tests : ca_feature.tests

      scenarios.each do |test_element|
        start_index = determine_test_start_line(test_element) - 1
        end_index = determine_test_end_line(test_element) - 1

        test_lines = feature_lines[start_index..end_index]

        add_scenario_to_feature(test_lines, "#{file_name}:#{test_element.source_line}")
      end
    end

    def add_scenario_to_feature(code_block, index_of_title)
      scenario = CukeSniffer::Scenario.new(index_of_title, code_block)
      if scenario.type == "Background"
        @background = scenario
      else
        @scenarios << scenario
      end
    end

    def determine_test_start_line(test_element)
      # todo - add test cases around these
      case
        when test_element.raw_element['comments']
          test_element.raw_element['comments'].first['line']
        when test_element.respond_to?(:tags) && test_element.tags.any?
          test_element.tag_elements.first.source_line
        else
          test_element.source_line
      end
    end

    def determine_test_end_line(test_element)
      # todo - add test cases around these
      case
        when test_element.respond_to?(:examples)
          test_element.examples.last.row_elements.last.source_line
        when test_element.steps.any?
          if test_element.steps.last.block.nil?
            test_element.steps.last.source_line
          else
            test_element.steps.last.raw_element['rows'].last['line']
          end
        when test_element.description.any?
          test_element.source_line + test_element.description.split("\n").count
        else
          test_element.source_line
      end
    end

  end
end
