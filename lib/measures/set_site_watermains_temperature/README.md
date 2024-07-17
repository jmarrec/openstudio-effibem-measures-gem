

###### (Automatically generated documentation)

# Set Site Water Mains Temperature

## Description

Set the Site:WaterMainsTemperature object to have:
- Calculation Method: 'Correlation' or 'Schedule'

If Schedule:
- user-supplied schedule

If 'Correlation':
- Annual Average Outdoor Air Temperature (C): user-supplied
- Maximum Difference in Monthly Average Outdoor Air Temperature (C): user-supplied

There is an Excel spreadsheet in the 'resources' folder to help in caculating the correlation coefficients.

## Modeler Description

For the 'Correlation' options, it's easy to calculate those using the .stat file that comes with EPW files.

Default values for Correlation are for New York City - JFK Airport.

See Engineering Reference Guide, Water Systems - Water Mains Temperature for more info
Correlation is based on Craig Christensen and Jay Burch and is described in Hendron et al (2004)
http://bigladdersoftware.com/epx/docs/9-0/engineering-reference/water-systems.html#water-mains-temperatures

## Measure Type

ModelMeasure

## Taxonomy



## Arguments


### Calculation Method



* **Name:** calculation_method
* **Type:** Choice

* **Required:** true
* **Model Dependent:** false

* **Choice Display Names:** ["CorrelationFromWeatherFile", "Schedule", "Correlation"]


### Temperature Schedule Name

Only Schedule Ruleset of Schedule Type Limits 'Temperature' will be listed. Only applies if 'Schedule' is selected above.

* **Name:** temp_sch
* **Type:** Choice

* **Required:** false
* **Model Dependent:** true


### Annual Average Outdoor Air Temperature

Only used if 'Correlation' is selected above. This is drybulb, easily calculated from .STAT file

* **Name:** avg_oa_temp
* **Type:** Double
* **Units:** C
* **Required:** false
* **Model Dependent:** false


### Maximum Difference in Monthly Average Outdoor Air Temperature



* **Name:** max_diff_monthly_oa_temp
* **Type:** Double
* **Units:** C
* **Required:** false
* **Model Dependent:** false






