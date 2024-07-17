# *******************************************************************************
# Copyright (c) 2017-2024 Julien Marrec and EffiBEM
# *******************************************************************************

require_relative 'subfolder/subresource.rb'

def make_arguments
  puts "Hello from resources/"
  return make_arguments_from_subfolder()
end

