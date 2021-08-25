require 'json'

def make_arguments_from_subfolder
  puts "Hello from resources/subfolder"

  args = OpenStudio::Measure::OSArgumentVector.new

  arguments_hash = JSON.parse(File.read("#{File.dirname(__FILE__)}/../data/arguments.json"))

  arguments_hash.each do |arg_name, options|
    arg = OpenStudio::Measure::OSArgument.makeStringArgument(arg_name, true)
    arg.setDisplayName(options['display_name'])
    arg.setDescription(options['description'])
    args << arg
  end
  return args
end

