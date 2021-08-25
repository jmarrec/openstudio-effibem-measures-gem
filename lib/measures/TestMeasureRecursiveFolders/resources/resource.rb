require_relative 'subfolder/subresource.rb'

def make_arguments
  puts "Hello from resources/"
  return make_arguments_from_subfolder()
end

