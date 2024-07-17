# Author: Julien Marrec
# email: julien.marrec@gmail.com

# start the measure
class SetSiteWaterMainsTemperature < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Set Site Water Mains Temperature"
  end

  # human readable description
  def description
    return "Set the Site:WaterMainsTemperature object to have:
- Calculation Method: 'Correlation' or 'Schedule'

If Schedule:
- user-supplied schedule

If 'Correlation':
- Annual Average Outdoor Air Temperature (C): user-supplied
- Maximum Difference in Monthly Average Outdoor Air Temperature (C): user-supplied

There is an Excel spreadsheet in the 'resources' folder to help in caculating the correlation coefficients."
  end

  # human readable description of modeling approach
  def modeler_description
    return "For the 'Correlation' options, it's easy to calculate those using the .stat file that comes with EPW files.

Default values for Correlation are for New York City - JFK Airport.

See Engineering Reference Guide, Water Systems - Water Mains Temperature for more info
Correlation is based on Craig Christensen and Jay Burch and is described in Hendron et al (2004)
http://bigladdersoftware.com/epx/docs/9-0/engineering-reference/water-systems.html#water-mains-temperatures"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    chs = OpenStudio::StringVector.new
    chs << "CorrelationFromWeatherFile"
    chs << "Schedule"
    chs << "Correlation"
    calculation_method = OpenStudio::Measure::OSArgument::makeChoiceArgument('calculation_method', chs, true)
    calculation_method.setDisplayName("Calculation Method")
    calculation_method.setDefaultValue("CorrelationFromWeatherFile")
    args << calculation_method

    #populate choice argument for schedules
    schedule_handles = OpenStudio::StringVector.new
    schedule_display_names = OpenStudio::StringVector.new

    #putting schedules and names into hash
    schedule_args = model.getScheduleRulesets
    schedule_args_hash = {}
    schedule_args.each do |schedule_arg|
      # We only want schedules of Unit Type 'Temperature'
      sch_typelimit = schedule_arg.scheduleTypeLimits
      # First, there should be a type limit defined
      if not sch_typelimit.empty?
        sch_typelimit = sch_typelimit.get
        # Wwe check the numeric type to see if it's not empty
        utype = sch_typelimit.unitType
        if not utype.empty?
          if utype.upcase == "TEMPERATURE"
            schedule_args_hash[schedule_arg.name.to_s] = schedule_arg
          end
        end
      end
    end

    #looping through sorted hash of schedules
    schedule_args_hash.sort.map do |key,value|
      #only include if schedule use count > 0
      #if value.directUseCount > 0
      schedule_handles << value.handle.to_s
      schedule_display_names << key
      #end
    end

    # make an argument for schedule
    temp_sch = OpenStudio::Measure::OSArgument::makeChoiceArgument("temp_sch", schedule_handles, schedule_display_names, false, true)
    temp_sch.setDisplayName("Temperature Schedule Name")
    temp_sch.setDescription("Only Schedule Ruleset of Schedule Type Limits 'Temperature' will be listed. Only applies if 'Schedule' is selected above.")
    args << temp_sch


    avg_oa_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('avg_oa_temp', false)
    avg_oa_temp.setDisplayName("Annual Average Outdoor Air Temperature")
    avg_oa_temp.setUnits("C")
    avg_oa_temp.setDescription("Only used if 'Correlation' is selected above. This is drybulb, easily calculated from .STAT file")
    avg_oa_temp.setDefaultValue(12.47)
    args << avg_oa_temp

    max_diff_monthly_oa_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_diff_monthly_oa_temp', false)
    max_diff_monthly_oa_temp.setDisplayName("Maximum Difference in Monthly Average Outdoor Air Temperature")
    max_diff_monthly_oa_temp.setUnits("C")
    avg_oa_temp.setDescription("Only used if 'Correlation' is selected above.")
    max_diff_monthly_oa_temp.setDefaultValue(25.2)
    args << max_diff_monthly_oa_temp

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    calculation_method = runner.getStringArgumentValue("calculation_method",user_arguments)

    # Put mains to the 'Advanced output console'
    puts "\n\n==================== Initial State ====================\n"
    if model.siteWaterMainsTemperature.empty?
      puts "No SetSiteWaterMainsTemperature object in model, using a default of 10C"
    else
      puts model.getSiteWaterMainsTemperature
    end

    mains = model.getSiteWaterMainsTemperature

    if calculation_method == 'CorrelationFromWeatherFile'
      runner.registerInitialCondition("Using 'CorrelationFromWeatherFile', no further inputs needed")
      mains.setCalculationMethod(calculation_method)
      if model.weatherFile.empty?
        runner.registerWarning("You do not seem to have a weather file assigned to your model")
      end
    elsif calculation_method == "Schedule"
      temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("temp_sch",user_arguments,model)
      if temp_sch.empty?
        runner.registerError("If you pick 'Schedule', you MUST provide a schedule!")
        return false
      else
        # If not empty: get object, convert to ScheduleRuleset, and get it
        if not temp_sch.get.to_ScheduleRuleset.empty?
          temp_sch = temp_sch.get.to_ScheduleRuleset.get
        end
        runner.registerInitialCondition("You have chosen to specify an existing schedule: #{temp_sch.name}")

        mains.setCalculationMethod(calculation_method)

        mains.setTemperatureSchedule(temp_sch)

        mains.resetAnnualAverageOutdoorAirTemperature
        mains.resetMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures
      end

    elsif calculation_method == "Correlation"
      avg_oa_temp = runner.getDoubleArgumentValue('avg_oa_temp', user_arguments)
      max_diff_monthly_oa_temp = runner.getDoubleArgumentValue('max_diff_monthly_oa_temp', user_arguments)

      if avg_oa_temp < -30
       runner.registerError("An average outdoor air drybulb temperature this low seems unlikely. You specified #{avg_oa_temp} Celsius")
        return false
      elsif avg_oa_temp > 50
        runner.registerError("An average outdoor air drybulb temperature above 50 Celsius? Are you in hell?. You specified #{avg_oa_temp} Celsius")
        return false
      elsif avg_oa_temp > 35
        runner.registerWarning("An average outdoor air temp above 35 Celsius seems high. Please Verify that #{avg_oa_temp} Celsius is what you want")
      end
      if max_diff_monthly_oa_temp < 0
        runner.registerError("You can't have a maximum differrence in Monthly Average OA Temp of less than 0. You specific #{max_diff_monthly_oa_temp}")
        return false
      elsif
        max_diff_monthly_oa_temp > 60
        runner.registerError("A Maximum Difference in Monthly Average Outdoor Air Temperature above 60 Celsius? Is this Climate Change? You specified #{max_diff_monthly_oa_temp} Celsius")
        return false
      elsif max_diff_monthly_oa_temp > 40
        runner.registerWarning("A Maximum Difference in Monthly Average Outdoor Air Temperature above 40 Celsius seems high. Please Verify that #{max_diff_monthly_oa_temp} Celsius is what you want")
      end

      runner.registerInitialCondition("You have chosen Correlation, with:\n- Annual Average Outdoor Air Temperature: #{avg_oa_temp}\n- Maximum Difference in Monthly Average Outdoor Air Temperature: #{max_diff_monthly_oa_temp}")

      mains.setCalculationMethod(calculation_method)

      mains.resetTemperatureSchedule

      mains.setAnnualAverageOutdoorAirTemperature(avg_oa_temp)
      mains.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(max_diff_monthly_oa_temp)

    else
      runner.registerError("Calculation method can only be 'CorrelationFromWeatherFile', 'Scheduled' or 'Correlation'")
      return false
    end

    puts "\n\n==================== Final State ====================\n"
    puts mains
    runner.registerFinalCondition("Success. Open up the 'Advanced Output' console to see the Site:WaterMainsTemperature object before and after")

    return true

  end

end

# register the measure to be used by the application
SetSiteWaterMainsTemperature.new.registerWithApplication
