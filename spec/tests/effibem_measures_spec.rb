# *******************************************************************************
# Copyright (c) 2017-2024 Julien Marrec and EffiBEM
# *******************************************************************************

require_relative '../spec_helper'

RSpec.describe OpenStudio::EffibemMeasures do
  it 'has a version number' do
    expect(OpenStudio::EffibemMeasures::VERSION).not_to be nil
  end

  it 'has a measures directory' do
    instance = OpenStudio::EffibemMeasures::EffibemMeasures.new
    expect(File.exist?(instance.measures_dir)).to be true
  end
end
