# Copyright (c) 2021 EffiBEM and Julien Marrec

require 'erb'
require 'json'

# start the measure
class ApplyNowReportingMeasure < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Apply Now Reporting Measure'
  end

  # human readable description
  def description
    return 'An example of how you can create something similar to a ReportingMeasure (that will create an HTML file) but is actually a ModelMeasure you can run in "Apply Now"'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'The main gist is to figure out how to correctly write to the reports/ directory'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Produce some output for the ERB template
    @sections = []

    @space_to_thermal_zone_section = {}
    @sections << @space_to_thermal_zone_section
    @space_to_thermal_zone_section[:title] = "Mapping Spaces to ThermalZones"
    space_tz_tables = []
    @space_to_thermal_zone_section[:tables] = space_tz_tables
    space_tz_table = {}
    space_tz_table[:title] = 'Space to Thermal Zones'
    columns = ['Space', 'Zone']
    space_tz_table[:header] = columns
    space_tz_table[:data] = []
    model.getSpaces.each do |s|
      tz = 'None'
      if !s.thermalZone.empty?
        tz = s.thermalZone.get.nameString
      end
      space_tz_table[:data] << [s.nameString, tz]
    end
    space_tz_tables << space_tz_table

    @space_lpd_section = {}
    @sections << @space_lpd_section
    @space_lpd_section[:title] = "Spaces LPD"
    lpd_tables = []
    @space_lpd_section[:tables] = lpd_tables
    lpd_table = {}
    lpd_table[:title] = 'Space to Thermal Zones'
    columns = ['Space', 'LPD']
    lpd_table[:header] = columns
    lpd_table[:units] = ['', 'W/m2']
    lpd_table[:chart_type] = 'vertical_grouped_bar'
    lpd_table[:chart] = []
    lpd_table[:data] = []
    lpd_table[:chart_attributes] = { label_x: 'Space Name', value: 'LPD (W/m2' }
    model.getSpaces.each do |s|
      lpd_table[:data] << [s.nameString, s.lightingPowerPerFloorArea]
      lpd_table[:chart] << JSON.generate(label_x: s.nameString, value: s.lightingPowerPerFloorArea)
    end
    lpd_tables << lpd_table


    # read in template
    template_name = "report.html.erb"
    html_in_path = "#{File.dirname(__FILE__)}/resources/#{template_name}"
    html_in = File.open(html_in_path, 'r') { |f| f.read }

    # configure template with variable values
    # And enable trim mode
    renderer = ERB.new(html_in, nil, '-')
    html_out = renderer.result(binding)
    runner.registerWarning(@sections.to_s)
    # either /tmp/osmodel-1622719126-1/ApplyMeasureNow
    # or ./<model_companion_dir>/
    rootDir = runner.workflow.absoluteRootDir.to_s

    html_out_path = 'report.html'
    if (File.basename(rootDir) == 'ApplyMeasureNow')
      html_out_path = File.absolute_path(
        File.join(rootDir, '..', 'resources', 'reports', html_out_path))
    else
      html_out_path = File.absolute_path(
        File.join(rootDir, 'reports', html_out_path))
    end
    outDir = File.dirname(html_out_path)
    if !File.exists?(outDir)
      FileUtils.mkdir_p(outDir)
    end

    runner.registerWarning("File.dirname(__FILE__)=#{File.dirname(__FILE__)}")
    runner.registerWarning("html_out_path=#{html_out_path}")
    runner.registerWarning("File.realpath('./')=#{File.realpath('./')}")
    runner.registerWarning("File.absolute_path('.')=#{File.absolute_path('.')}")
    runner.registerWarning("runner.workflow.absoluteRootDir=#{runner.workflow.absoluteRootDir}")
    runner.registerWarning("runner.workflow.filePaths=#{runner.workflow.filePaths.map{|p| p.to_s}}")

    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    # report final condition of model
    runner.registerFinalCondition("Saved HTML to #{html_out_path}.")

    return true
  end
end

# register the measure to be used by the application
ApplyNowReportingMeasure.new.registerWithApplication
