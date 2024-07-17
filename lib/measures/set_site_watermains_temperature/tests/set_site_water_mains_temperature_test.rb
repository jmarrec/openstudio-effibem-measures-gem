require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require 'pathname'

require_relative '../measure'

class SetSiteWaterMainsTemperatureTest < Minitest::Test
  # Patch to capture if --verbose was passed to minitest so we can call
  # show_output if so, and not do it otherwise
  @@verbose = false

  def self.run(reporter, options = {})
    @@verbose = options.fetch(:verbose, false)

    # Might as well shush some annoying logging message
    logger = OpenStudio::Logger.instance.standardOutLogger
    logger.setChannelRegex('.*(?<!OSRunner)(?<!WorkflowStepResult)$')
    if logger.respond_to?(:useWorkflowGemFormatter)
      OpenStudio::Logger.instance.standardOutLogger.useWorkflowGemFormatter(true)
    end
    super(reporter, options)
  end

  def run_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{__dir__}/output/#{test_name}"
  end

  def apply_measure_to_model(model, args_hash = {}, do_show_output: false, save_model: false, test_name: nil)
    # create an instance of the measure
    measure = SetSiteWaterMainsTemperature.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    # this_dir = Pathname.new(__dir__).expand_path
    # step = OpenStudio::MeasureStep.new(this_dir.parent.to_s)
    # osw.setMeasureSteps("ModelMeasure".to_MeasureType, [step])

    runner = OpenStudio::Measure::OSRunner.new(osw)

    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    if !args_hash.nil? && !args_hash.empty?
      # populate argument with specified hash value if specified
      arguments.each do |arg|
        temp_arg_var = arg.clone
        if args_hash.key?(arg.name)
          assert(temp_arg_var.setValue(args_hash[arg.name]))
        end
        argument_map[arg.name] = temp_arg_var
      end
    end

    # run the measure, in a subdirectory
    if test_name.nil?
      test_name = caller_locations(1, 1)[0].label
    end
    sub_dir = run_dir(test_name)
    FileUtils.rm_f(sub_dir) if File.exist?(sub_dir)
    FileUtils.mkdir_p(sub_dir)

    if save_model || @@verbose
      output_file_path = "#{sub_dir}/initial.osm"
      model.save(output_file_path, true)
    end

    Dir.chdir(sub_dir) do
      measure.run(model, runner, argument_map)
    end

    if do_show_output || @@verbose
      # show the output
      show_output(runner.result)
    end

    if save_model || @@verbose
      output_file_path = "#{sub_dir}/output.osm"
      model.save(output_file_path, true)
    end

    return runner
  end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = SetSiteWaterMainsTemperature.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(4, arguments.size)
    assert_equal("calculation_method", arguments[0].name)
    assert_equal("temp_sch", arguments[1].name)
    assert_equal("avg_oa_temp", arguments[2].name)
    assert_equal("max_diff_monthly_oa_temp", arguments[3].name)
  end

  # When you choose 'schedule', you have to specify a schedule!
  def test_bad_no_schedule
    model = OpenStudio::Model::Model.new

    args_hash = {"calculation_method" => "Schedule"}

    # run the measure
    runner = apply_measure_to_model(model, args_hash)
    result = runner.result

    assert_equal("Fail", result.value.valueName)
  end

  def _test_bad_temps(avg_oa_temp, max_diff_monthly_oa_temp)
    model = OpenStudio::Model::Model.new

    args_hash = {
      "calculation_method" => "Correlation",
      "avg_oa_temp" => avg_oa_temp,
      "max_diff_monthly_oa_temp" => max_diff_monthly_oa_temp,
    }

    runner = apply_measure_to_model(model, args_hash)
    result = runner.result

    assert_equal("Fail", result.value.valueName)
  end

  def test_all_bad_temps

    # In order
    # avg_oa_temp too low, then too high
    # max_diff_monthly_oa_temp below 0
    # max_diff_monthly_oa_temp above 60
    avg_oa_temps = [-35,55,26,26]
    max_diff_monthly_oa_temps = [25, 25, -5, 65]

    avg_oa_temps.each_with_index do |avg_oa_temp, i|
      max_diff_monthly_oa_temp = max_diff_monthly_oa_temps[i]
      puts "============================================================================================================"
      puts "                  Testing with avg_oa_temp = #{avg_oa_temp} and max_diff_monthly_oa_temp = #{max_diff_monthly_oa_temp}"
      puts "============================================================================================================="

      _test_bad_temps(avg_oa_temp, max_diff_monthly_oa_temp)
    end


  end

  def test_good_argument_values
    model = OpenStudio::Model::Model.new
    assert_empty(model.siteWaterMainsTemperature)

    avg_oa_temp = 13.5
    max_diff_monthly_oa_temp = 26.4
    args_hash = {
      "calculation_method" => "Correlation",
      "avg_oa_temp" => avg_oa_temp,
      "max_diff_monthly_oa_temp" => max_diff_monthly_oa_temp,
    }

    runner = apply_measure_to_model(model, args_hash)
    result = runner.result

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)

    refute_empty(model.siteWaterMainsTemperature)
    mains = model.getSiteWaterMainsTemperature
    assert_equal("Correlation", mains.calculationMethod)
    assert_empty(mains.temperatureSchedule)

    refute_empty(mains.annualAverageOutdoorAirTemperature)
    assert_equal(avg_oa_temp, mains.annualAverageOutdoorAirTemperature.get)

    refute_empty(mains.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures)
    assert_equal(max_diff_monthly_oa_temp, mains.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get)
  end

end
