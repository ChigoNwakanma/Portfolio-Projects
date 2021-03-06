/* 

COVID-19 EXPLORATORY ANALYSIS

Skills used: Joins, CTE's, Windows Functions, Aggregate Functions, Creating Views

The original data spreadsheet was split and saved as 2 different sheets; covid_deaths & covid_vax

Source: https://ourworldindata.org/covid-deaths

*/


-- Checking to see that all the columns were uploaded correctly
SELECT * 
FROM `portfolio1-337505.covid_data.covid_deaths`
ORDER BY 3, 4

-- Pulling the main columns that will be used for analysis
SELECT 
  Location, date, total_cases, new_cases, total_deaths, population
FROM `portfolio1-337505.covid_data.covid_deaths`
ORDER BY 1, 2

-- Exploring the likelihood of dying if you contract COVID in a specific country
-- Looking at Total cases vs total deaths
SELECT 
  Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS Death_percentage
FROM `portfolio1-337505.covid_data.covid_deaths`
WHERE location = "Canada" 
AND ((total_deaths/total_cases)*100) > 2.0 AND date BETWEEN '2021-01-01' and '2022-01-01' --this line adds more filters by date and death %
ORDER BY 1, 2

-- Looking at the Total cases vs the population for CANADA
-- this shows what %age of population got COVID as the days progress
SELECT 
  Location, date, total_cases, population, (total_cases/population)*100 AS Case_percentage
FROM `portfolio1-337505.covid_data.covid_deaths`
WHERE location = "Canada" 
ORDER BY 1, 2

-- Looking at countries with highest infection rates compared to population
SELECT 
  Location, population, MAX(total_cases) AS Highest_infection_count, MAX((total_cases/population))*100 AS Percent_population_infected
FROM `portfolio1-337505.covid_data.covid_deaths`
GROUP BY 1, 2
ORDER BY Percent_population_infected desc 

-- Showing the countries with the highest mortality rates, grouped by location
SELECT
  Location, MAX(total_deaths) AS Highest_death_count, MAX((total_deaths/population))*100 AS Percent_mortality
FROM `portfolio1-337505.covid_data.covid_deaths`
WHERE continent IS NOT NULL --eliminates rows in the LOCATION column that contain Continents
GROUP BY 1         
ORDER BY Highest_death_count desc

-- Grouping death counts by continents
SELECT
  continent, MAX(total_deaths) AS Highest_death_count, MAX((total_deaths/population))*100 AS Percent_mortality
FROM `portfolio1-337505.covid_data.covid_deaths`
WHERE continent IS NOT NULL
GROUP BY 1         
ORDER BY Percent_mortality desc

-- Now going back to the infection counts to compare by continent
 SELECT
   continent, MAX(total_cases) AS Highest_infection_count, MAX((total_cases/population))*100 AS Percent_population_infected
FROM `portfolio1-337505.covid_data.covid_deaths`
WHERE continent IS NOT NULL
GROUP BY 1
ORDER BY Percent_population_infected desc

 -- INSIGHT: When looking at the death counts by continents, Africa ranks 5th, which makes sense because the infection count ranks 5th as well
 -- but when we compare the death and infection counts WRT population, things look a bit different. Ordering by "Percent_mortality" and "percent_population_infected" 
 -- will show that Africa ranks 2nd in infection rates by population and 6th(lowest) in Percent_mortality



-- EXPLORING FROM A GLOBAL VIEWPOINT
-- Looking at Death % on each recorded date(excluding days with 0 cases to avoid division error)
-- we can observe that the death percentage rises gradually up until mid-april 2020, then begins to drop.
-- some outliers occur in feb 2020 with some dates having over 20% death %

SELECT 
  date, SUM(new_cases) as TotalCases, SUM(new_deaths) as TotalDeaths, (SUM(new_deaths)/SUM(new_cases)) *100 AS Deathpercentage
FROM `portfolio1-337505.covid_data.covid_deaths`
WHERE location IS NOT NULL AND new_cases != 0
GROUP BY date
ORDER BY 1, 2


-- Looking at the Global death percentage as of the last recorded date in the dataset
SELECT 
  SUM(new_cases) AS TotalCases, SUM(new_deaths) as TotalDeaths, (SUM(new_deaths)/SUM(new_cases)) *100 AS Deathpercentage
FROM `portfolio1-337505.covid_data.covid_deaths`
WHERE location IS NOT NULL AND new_cases != 0
ORDER BY 1, 2


-- NOW JOINING BOTH THE DEATHS AND VAX TABLES TO SEE THE EFFECT OF THE VACCINATIONS

SELECT *
FROM `portfolio1-337505.covid_data.covid_deaths` AS Deaths
JOIN `portfolio1-337505.covid_data.covid_vax` AS Vax
  ON Deaths.location = Vax.Location 
  AND Deaths.date = Vax.date

-- looking at the daily no. of vaccinations for each location 
SELECT
  Deaths.continent, Deaths.location, Deaths.date, Deaths.population, Vax.new_vaccinations, 
FROM `portfolio1-337505.covid_data.covid_deaths` AS Deaths
JOIN `portfolio1-337505.covid_data.covid_vax` AS Vax
  ON Deaths.location = Vax.Location 
  AND Deaths.date = Vax.date
WHERE deaths.continent IS NOT NULL 
AND Vax.location = "Canada"  --this line adds a filter by location(country)
ORDER BY 2, 3 


-- NOW IF WE WANTED A ROLLING COUNT OF THE TOTAL NUMBER OF VACCINATIONS DONE, WE HAVE TO USE A "PARTITION" COMMAND
-- "PARTITION BY" CLAUSE is usually used in conjunction with an aggregate fn to create a new column which makes reference to/is derived from an existing column.
-- so below, we have been able to create a new column  "RollingCount_NewVax", which contains the sum of the previous "Vax.new_vaccinations" rows, GIVEN they belong in the same "location"
-- hence, each time a new location is reached in the order, the count begins from zero and begins to add up for that specific location

SELECT
  Deaths.continent, Deaths.location, Deaths.date, Deaths.population, Vax.new_vaccinations, 
SUM(Vax.new_vaccinations) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location, Deaths.date) AS RollingCount_NewVax
FROM `portfolio1-337505.covid_data.covid_deaths` AS Deaths
JOIN `portfolio1-337505.covid_data.covid_vax` AS Vax
  ON Deaths.location = Vax.Location 
  AND Deaths.date = Vax.date
WHERE deaths.continent IS NOT NULL 
ORDER BY 2, 3 

-- Using the MAX fn with that rolling count, and comparing that to the total population, 
-- we can find how many people are vaccinated in each country as of the latest date recorded
SELECT 
  Deaths.continent, Deaths.location, Deaths.date, Deaths.population, Vax.new_vaccinations, 
  SUM(Vax.new_vaccinations) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location, Deaths.date) AS RollingCount_NewVax,
  (RollingCount_NewVax/population)*100 AS TotalVaxcount  --this will give an error because we can't call an alias column we created, using the SELECT fn.
FROM `portfolio1-337505.covid_data.covid_deaths` AS Deaths
JOIN `portfolio1-337505.covid_data.covid_vax` AS Vax
  ON Deaths.location = Vax.Location 
  AND Deaths.date = Vax.date
WHERE deaths.continent IS NOT NULL 
ORDER BY 2, 3 

-- to solve the above problem, we need to use a CTE (Common Table Expression), using WITH clause
-- few pointers: 
-- we could do this without the MAX aggregate, and just scroll to the bottom of each location group to see the rolling TotalVaxCount
-- but if we go with the MAX agg, remember to remove the date from the selected columns, as it will throw everything off
-- also, get rid of the ORDER BY clause at the end, Not needed

--Now using the WITH clause to make a CTE;

WITH TotalVaxCount 
AS
 (
    SELECT 
      Deaths.continent, Deaths.location, Deaths.date, Deaths.population, Vax.new_vaccinations, 
      SUM(Vax.new_vaccinations) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location, Deaths.date) AS RollingCount_NewVax,
    FROM `portfolio1-337505.covid_data.covid_deaths` AS Deaths
    JOIN `portfolio1-337505.covid_data.covid_vax` AS Vax
      ON Deaths.location = Vax.Location 
      AND Deaths.date = Vax.date
    WHERE deaths.continent IS NOT NULL 

)

SELECT *, (RollingCount_NewVax/population)*100  AS TotalVaxCount
FROM TotalVaxcount


-- CREATING A VIEW
-- this is just like creating a temp table from any segment of your query and storing it.
-- This way, you can open it separately and query it, without affecting the main dataset.
--e.g i've copied and pasted the chunk of code below into a new tab, then "save view"

SELECT 
  Deaths.continent, Deaths.location, Deaths.date, Deaths.population, Vax.new_vaccinations, 
  SUM(Vax.new_vaccinations) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location, Deaths.date) AS RollingCount_NewVax
FROM `portfolio1-337505.covid_data.covid_deaths` AS Deaths
JOIN `portfolio1-337505.covid_data.covid_vax` AS Vax
  ON Deaths.location = Vax.Location 
  AND Deaths.date = Vax.date
WHERE deaths.continent IS NOT NULL 
ORDER BY 2, 3 

-- ANOTHER WAY IS TO JUST USE THE "CREATE VIEW" COMMAND.
-- make sure the file name is written correctly. Below, covid_deaths was replaced with Percent_population_vaccinated, as that is the name intended for the new view

CREATE VIEW `portfolio1-337505.covid_data.Percent_population_vaccinated` AS
 SELECT Deaths.continent, Deaths.location, Deaths.date, Deaths.population, Vax.new_vaccinations, 
SUM(Vax.new_vaccinations) OVER (PARTITION BY Deaths.location ORDER BY Deaths.location, Deaths.date) AS RollingCount_NewVax
 FROM `portfolio1-337505.covid_data.covid_deaths` AS Deaths
 JOIN `portfolio1-337505.covid_data.covid_vax` AS Vax
ON Deaths.location = Vax.Location 
AND Deaths.date = Vax.date
WHERE deaths.continent IS NOT NULL 
ORDER BY 2, 3 

-- now we can query the new views created as below

Select * from `portfolio1-337505.covid_data.RollingCount_sample`

Select * from `portfolio1-337505.covid_data.Percent_population_vaccinated`

-- Knowing this now, you can create different views based on different parts of your query and use those for visualization purposes. 