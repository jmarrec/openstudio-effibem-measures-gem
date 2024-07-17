# *******************************************************************************
# Copyright (c) 2017-2024 Julien Marrec and EffiBEM
# *******************************************************************************

require 'openstudio/effibem_measures/version'
require 'openstudio/extension'

module OpenStudio
  module EffibemMeasures
    class EffibemMeasures < OpenStudio::Extension::Extension
      # Override parent class
      def initialize
        super

        @root_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
      end
    end
  end
end
