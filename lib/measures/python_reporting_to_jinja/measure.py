# *******************************************************************************
# Copyright (c) 2017-2024 Julien Marrec and EffiBEM
# *******************************************************************************

from pathlib import Path

import jinja2
import openstudio


class PythonReportingToJinja(openstudio.measure.ReportingMeasure):
    """A ReportingMeasure Using Jinja2."""

    RESOURCES_DIR = Path(__file__).parent / "resources"

    def name(self):
        """Returns the human readable name.

        Measure name should be the title case of the class name.
        The measure name is the first contact a user has with the measure;
        it is also shared throughout the measure workflow, visible in the OpenStudio Application,
        PAT, Server Management Consoles, and in output reports.
        As such, measure names should clearly describe the measure's function,
        while remaining general in nature
        """
        return "Python Reporting to Jinja Measure"

    def description(self):
        """Human readable description.

        The measure description is intended for a general audience and should not assume
        that the reader is familiar with the design and construction practices suggested by the measure.
        """
        return "python_reporting_measure"

    def modeler_description(self):
        """Human readable description of modeling approach.

        The modeler description is intended for the energy modeler using the measure.
        It should explain the measure's intent, and include any requirements about
        how the baseline model must be set up, major assumptions made by the measure,
        and relevant citations or references to applicable modeling resources
        """
        return "Tests loading sql and co"

    def arguments(self, model: openstudio.model.Model):
        """Prepares user arguments for the measure.

        Measure arguments define which -- if any -- input parameters the user may set before running the measure.
        """
        args = openstudio.measure.OSArgumentVector()

        report_drybulb_temp = openstudio.measure.OSArgument.makeBoolArgument("report_drybulb_temp", True)
        report_drybulb_temp.setDisplayName("Add output variables for Drybulb Temperature")
        report_drybulb_temp.setDescription("Will add drybulb temp and report min/mix value in html.")
        report_drybulb_temp.setValue(True)
        args.append(report_drybulb_temp)

        return args

    def outputs(self):
        """Define the outputs that the measure will create."""
        outs = openstudio.measure.OSOutputVector()

        # this measure does not produce machine readable outputs with registerValue, return an empty list

        return outs

    def energyPlusOutputRequests(
        self, runner: openstudio.measure.OSRunner, user_arguments: openstudio.measure.OSArgumentMap
    ):
        """Returns a vector of IdfObject's to request EnergyPlus objects needed by the run method."""
        super().energyPlusOutputRequests(runner, user_arguments)  # Do **NOT** remove this line

        result = openstudio.IdfObjectVector()

        # To use the built-in error checking we need the model...
        # get the last model and sql file
        model = runner.lastOpenStudioModel()
        if not model.is_initialized():
            runner.registerError("Cannot find last model.")
            return False

        model = model.get()

        # use the built-in error checking
        if not runner.validateUserArguments(self.arguments(model), user_arguments):
            return False

        if runner.getBoolArgumentValue("report_drybulb_temp", user_arguments):
            request = openstudio.IdfObject.load(
                "Output:Variable, , Site Outdoor Air Drybulb Temperature, Hourly;"
            ).get()
            result.append(request)

        return result

    def run(
        self,
        runner: openstudio.measure.OSRunner,
        user_arguments: openstudio.measure.OSArgumentMap,
    ):
        """Defines what happens when the measure is run."""
        super().run(runner, user_arguments)

        # get the last model and sql file
        model = runner.lastOpenStudioModel()
        if not model.is_initialized():
            runner.registerError("Cannot find last model.")
            return False
        model = model.get()

        # use the built-in error checking (need model)
        if not runner.validateUserArguments(self.arguments(model), user_arguments):
            return False

        # get measure arguments
        report_drybulb_temp = runner.getBoolArgumentValue("report_drybulb_temp", user_arguments)

        # load sql file
        sql_file = runner.lastEnergyPlusSqlFile()
        if not sql_file.is_initialized():
            runner.registerError("Cannot find last sql file.")
            return False

        sql_file = sql_file.get()
        model.setSqlFile(sql_file)

        date_lines_str = None
        min_drybulb = None
        max_drybulb = None

        if report_drybulb_temp:
            # get the weather file run period (as opposed to design day run period)
            ann_env_pd = None
            for env_pd in sql_file.availableEnvPeriods():
                env_type = sql_file.environmentType(env_pd)
                if not env_type.is_initialized():
                    continue
                if env_type.get() == openstudio.EnvironmentType("WeatherRunPeriod"):
                    ann_env_pd = env_pd
                    break
            if ann_env_pd is None:
                runner.registerWarning("No annual environment period found.")
            else:
                # get desired variable
                key_value = "Environment"
                time_step = "Hourly"  # "Zone Timestep", "Hourly", "HVAC System Timestep"
                variable_name = "Site Outdoor Air Drybulb Temperature"

                # key value would go at the end if we used it.
                output_timeseries = sql_file.timeSeries(ann_env_pd, time_step, variable_name, key_value)
                if not output_timeseries.is_initialized():
                    runner.registerWarning("Timeseries not found.")
                else:
                    runner.registerInfo("Found timeseries.")

                    output_timeseries = output_timeseries.get()
                    values = output_timeseries.values()
                    vals = [values[i] for i in range(values.size())]
                    times = output_timeseries.dateTimes()
                    min_drybulb = min(vals)
                    max_drybulb = max(vals)

                    data_lines = []

                    def format_dt(dt):
                        d = dt.date()
                        t = dt.time()
                        # return datetime.datetime(d.year(), d.monthOfYear().value(), d.dayOfMonth(), t.hours(), t.minutes(), t.seconds(), tzinfo=datetime.timezone.utc)
                        return f"new Date({d.year()}, {d.monthOfYear().value()}, {d.dayOfMonth()}, {t.hours()}, {t.minutes()}, {t.seconds()})"

                    for i, v in enumerate(vals):
                        data_lines.append(f"{{date: {format_dt(times[i])}, value: {v}}}")
                    date_lines_str = ",\n        ".join(data_lines)

        env = jinja2.Environment(loader=jinja2.FileSystemLoader(self.RESOURCES_DIR))
        template = env.get_template("report.html.jinja")
        context = {
            "measure_name": self.name(),
            "building_name": model.getBuilding().nameString(),
            "building_floor_area": model.getBuilding().floorArea(),
            "net_site_energy": sql_file.netSiteEnergy().get(),
            "report_drybulb_temp": report_drybulb_temp,
            "min_drybulb": min_drybulb,
            "max_drybulb": max_drybulb,
            "date_lines_str": date_lines_str,
        }
        out_html_str = template.render(context)

        # write html file: any file named 'report*.*' in the current working directory
        # will be copied to the ./reports/ folder as 'reports/<measure_class_name>_<filename>.html'
        html_out_path = Path("./report.html").absolute()
        html_out_path.write_text(out_html_str)

        # Close the sql file
        sql_file.close()

        return True


# register the measure to be used by the application
PythonReportingToJinja().registerWithApplication()
