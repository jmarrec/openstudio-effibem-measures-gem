# frozen_string_literal: true

# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure'
require 'fileutils'

class ApplyNowReportingMeasureTest < Minitest::Test
  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = ApplyNowReportingMeasure.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
  end

  def test_good_argument_values
    # create an instance of the measure
    measure = ApplyNowReportingMeasure.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    osw.addFilePath(File.absolute_path('generated_files'))
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    model = OpenStudio::Model.exampleModel

    # store the number of spaces in the seed model
    num_spaces_seed = model.getSpaces.size

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    puts File.absolute_path('./reports')
  end
end
