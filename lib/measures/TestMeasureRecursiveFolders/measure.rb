# Copyright (c) 2021 Julien Marrec and EffiBEM
require_relative 'resources/resource'

class TestMeasureRecursiveFolders < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Test Measure Recursive Folders'
  end

  # human readable description
  def description
    return 'A Measure to test whether supporting recursive subfolders works'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This a test measure in relation with https://github.com/NREL/OpenStudio/issues/4156'
  end

  # define the arguments that the user will input
  def arguments(model)

    # This calls resources/resource.rb with calls
    # resources/subfolder/subresource.rb which in turn loads a json
    # from resources/data/arguments.json
    return make_arguments()

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    space_name = runner.getStringArgumentValue('space_name', user_arguments)

    # check the space_name for reasonableness
    if space_name.empty?
      runner.registerError('Empty space name was entered.')
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # add a new space to the model
    new_space = OpenStudio::Model::Space.new(model)
    new_space.setName(space_name)

    # echo the new space's name back to the user
    runner.registerInfo("Space #{new_space.name} was added.")

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true
  end
end

# register the measure to be used by the application
TestMeasureRecursiveFolders.new.registerWithApplication
