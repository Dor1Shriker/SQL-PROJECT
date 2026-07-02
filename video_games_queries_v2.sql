
USE video_games
GO


/***********************************************************************************
SQL Final Project - Data Research Analyst
Database: video_games
***********************************************************************************/


/**************************
    Task 1
    Business Questions and Metrics
**************************/

-- Business Question 1: Highest-Grossing Platforms per Genre Globally
-- Which console has the highest sales volume for each game genre across North America, Europe, and Japan?
WITH cte_PlatformGenreSales AS (
    SELECT 
         Genre
        ,Platform
        ,SUM(NA_Sales) AS NA_Total_Sales
        ,SUM(EU_Sales) AS EU_Total_Sales
        ,SUM(JP_Sales) AS JP_Total_Sales
        ,SUM(Global_Sales) AS Global_Total_Sales
        ,ROW_NUMBER() OVER (PARTITION BY Genre ORDER BY SUM(Global_Sales) DESC) AS rn
    FROM video_games
    WHERE Genre IS NOT NULL AND Genre <> 'N/A' AND Genre <> ''
      AND Platform IS NOT NULL AND Platform <> 'N/A' AND Platform <> ''
    GROUP BY Genre, Platform
)
SELECT 
     Genre
    ,Platform
    ,ROUND(NA_Total_Sales, 2) AS NA_Total_Sales
    ,ROUND(EU_Total_Sales, 2) AS EU_Total_Sales
    ,ROUND(JP_Total_Sales, 2) AS JP_Total_Sales
    ,ROUND(Global_Total_Sales, 2) AS Global_Total_Sales
FROM cte_PlatformGenreSales
WHERE rn = 1
ORDER BY Global_Total_Sales DESC;



-- Business Question 2: Genre Trends Over Time
-- Which game genres are growing or shrinking in global sales over the years?
SELECT 
     Genre
    ,CAST(Year_of_Release AS INT) AS Year
    ,ROUND(SUM(Global_Sales), 2) AS Total_Global_Sales
FROM video_games
WHERE Genre IS NOT NULL AND Genre <> 'N/A' AND Genre <> ''
  AND Year_of_Release IS NOT NULL AND Year_of_Release <> 'N/A' AND Year_of_Release <> ''
GROUP BY Genre, CAST(Year_of_Release AS INT)
ORDER BY Genre, Year;


/**************************
    Task 2a
    Games released on 3 or more platforms
**************************/

-- Step 1: filter invalid names
-- Step 2: group by game name
-- Step 3: keep only names with 3 or more distinct platforms
-- Step 4: count the total result

SELECT COUNT(*) AS Games_Count
FROM (
	SELECT Name
	FROM video_games
	WHERE Name IS NOT NULL
	  AND Name <> ''
	GROUP BY Name
	HAVING COUNT(DISTINCT Platform) >= 3
) AS tbl_games_multi_platform


/**************************
    Task 2b
    Peak year per genre by Global Sales
**************************/

-- Step 1: sum global sales per genre per year
-- Step 2: rank years within each genre by total sales descending
-- Step 3: keep only the peak year per genre

WITH cte_GenreSalesByYear AS (
	SELECT
	 Genre
	,CAST(Year_of_Release AS INT) AS Year
	,SUM(Global_Sales) AS Total_Sales
	FROM video_games
	WHERE Genre IS NOT NULL
	  AND Genre <> 'N/A'
	  AND Genre <> ''
	  AND Year_of_Release IS NOT NULL
	  AND Year_of_Release <> 'N/A'
	GROUP BY Genre, CAST(Year_of_Release AS INT)
),
cte_GenrePeakSalesYear AS (
	SELECT
	 Genre
	,Year
	,Total_Sales
	,ROW_NUMBER() OVER (PARTITION BY Genre ORDER BY Total_Sales DESC, Year ASC) AS rn
	FROM cte_GenreSalesByYear
)
SELECT
 Genre
,Year
FROM cte_GenrePeakSalesYear
WHERE rn = 1
ORDER BY Genre;





/**************************
    Task 3
    Weighted Average, Normal Average and Mode of Critic Score per Rating
**************************/

-- Step 1: count frequency of each critic score per rating
-- Step 2: rank scores within each rating by frequency to find the mode
-- Step 3: calculate normal average and weighted average per rating
-- Step 4: join averages with modes and display all tied modes as separate rows

WITH cte_ScoreFrequencies AS (
	SELECT
	 Rating
	,Critic_Score
	,COUNT(*) AS Frequency
	FROM video_games
	WHERE Critic_Score IS NOT NULL
	  AND Rating IS NOT NULL
	  AND Rating <> ''
	  AND Rating <> 'N/A'
	  AND Critic_Count IS NOT NULL
	  AND Critic_Count > 0
	GROUP BY Rating, Critic_Score
),
cte_ModeRanks AS (
	SELECT
	 Rating
	,Critic_Score AS Mode_Value
	,Frequency
	,DENSE_RANK() OVER (PARTITION BY Rating ORDER BY Frequency DESC) AS rn
	FROM cte_ScoreFrequencies
),
cte_RatingModes AS (
	SELECT Rating, Mode_Value
	FROM cte_ModeRanks
	WHERE rn = 1
),
cte_RatingAverages AS (
	SELECT
	 Rating
	,ROUND(AVG(Critic_Score), 1) AS Normal_Average
	,ROUND(SUM(Critic_Score * Critic_Count) / CAST(SUM(Critic_Count) AS FLOAT), 1) AS Weighted_Average
	FROM video_games
	WHERE Critic_Score IS NOT NULL
	  AND Rating IS NOT NULL
	  AND Rating <> ''
	  AND Rating <> 'N/A'
	  AND Critic_Count IS NOT NULL
	  AND Critic_Count > 0
	GROUP BY Rating
)
SELECT
 A.Rating
,A.Weighted_Average
,A.Normal_Average
,ROUND(M.Mode_Value, 1) AS Mode_Value
FROM cte_RatingAverages A
INNER JOIN cte_RatingModes M ON A.Rating = M.Rating
ORDER BY A.Rating, M.Mode_Value


/**************************
    Task 4
    Data Scaffolding - full year sequence per Genre and Platform
    No CROSS JOIN, No RIGHT JOIN
**************************/

-- Step 1: get all unique Genre + Platform combinations that exist in the data
-- Step 2: pre-clean the sales data by casting year to INT (filter out NULL and N/A years)
-- Step 3: find the global min and max year from the clean data
-- Step 4: build a recursive CTE to generate every year from min to max for each combination
-- Step 5: LEFT JOIN the scaffold with the real sales, fill missing years with 0

WITH cte_UniqueCombos AS (
	SELECT DISTINCT Genre, Platform
	FROM video_games
	WHERE Genre IS NOT NULL
	  AND Genre <> ''
	  AND Genre <> 'N/A'
	  AND Platform IS NOT NULL
	  AND Platform <> ''
	  AND Platform <> 'N/A'
),
cte_CleanSales AS (
	SELECT
	 Genre
	,Platform
	,CAST(Year_of_Release AS INT) AS Year
	,Global_Sales
	FROM video_games
	WHERE Year_of_Release IS NOT NULL
	  AND Year_of_Release <> 'N/A'
	  AND Genre IS NOT NULL
	  AND Genre <> ''
	  AND Genre <> 'N/A'
	  AND Platform IS NOT NULL
	  AND Platform <> ''
	  AND Platform <> 'N/A'
),
cte_GlobalRange AS (
	SELECT
	 MIN(Year) AS MinYear
	,MAX(Year) AS MaxYear
	FROM cte_CleanSales
),
cte_ComboStart AS (
	SELECT
	 C.Genre
	,C.Platform
	,G.MinYear AS YearVal
	,G.MaxYear
	FROM cte_UniqueCombos C
	INNER JOIN cte_GlobalRange G ON G.MinYear IS NOT NULL
),
cte_Scaffold AS (
	SELECT Genre, Platform, YearVal, MaxYear
	FROM cte_ComboStart
	UNION ALL
	SELECT Genre, Platform, YearVal + 1, MaxYear
	FROM cte_Scaffold
	WHERE YearVal < MaxYear
)
SELECT
 S.Genre
,S.Platform
,S.YearVal AS Year
,ISNULL(SUM(VG.Global_Sales), 0) AS Global_Sales
FROM cte_Scaffold S
LEFT JOIN cte_CleanSales VG
	ON  S.Genre    = VG.Genre
	AND S.Platform = VG.Platform
	AND S.YearVal  = VG.Year
GROUP BY S.Genre, S.Platform, S.YearVal
ORDER BY S.Genre, S.Platform, S.YearVal


---הערה
/**************************
    Task 5
    Year over Year (YoY) Growth Analysis per Platform
    No CROSS JOIN, No RIGHT JOIN, No division by zero
**************************/

-- Step 1: pre-clean and cast years (same as Task 4)
-- Step 2: build full year scaffold from 1980 to 2019 per Genre + Platform combination
-- Step 3: sum global sales per Platform and Year across all genres
-- Step 4: use LAG to bring previous year sales alongside current year
-- Step 5: find the first year with actual sales per platform (to exclude year 0 comparisons)
-- Step 6: filter to years after the first sales year AND where previous year sales > 0
-- Step 7: calculate growth rate and rank by highest growth per platform
-- Step 8: return the best growth year per platform, sorted by growth rate descending

WITH cte_UniqueCombos AS (
	SELECT DISTINCT Genre, Platform
	FROM video_games
	WHERE Genre IS NOT NULL
	  AND Genre <> ''
	  AND Genre <> 'N/A'
	  AND Platform IS NOT NULL
	  AND Platform <> ''
	  AND Platform <> 'N/A'
),
cte_CleanSales AS (
	SELECT
	 Genre
	,Platform
	,CAST(Year_of_Release AS INT) AS Year
	,Global_Sales
	FROM video_games
	WHERE Year_of_Release IS NOT NULL
	  AND Year_of_Release <> 'N/A'
	  AND Genre IS NOT NULL
	  AND Genre <> ''
	  AND Genre <> 'N/A'
	  AND Platform IS NOT NULL
	  AND Platform <> ''
	  AND Platform <> 'N/A'
),
cte_GlobalRange AS (
	SELECT
	 MIN(Year) AS MinYear
	,2019      AS MaxYear
	FROM cte_CleanSales
),
cte_ComboStart AS (
	SELECT
	 C.Genre
	,C.Platform
	,G.MinYear AS YearVal
	,G.MaxYear
	FROM cte_UniqueCombos C
	INNER JOIN cte_GlobalRange G ON G.MinYear IS NOT NULL
),
cte_Scaffold AS (
	SELECT Genre, Platform, YearVal, MaxYear
	FROM cte_ComboStart
	UNION ALL
	SELECT Genre, Platform, YearVal + 1, MaxYear
	FROM cte_Scaffold
	WHERE YearVal < MaxYear
),
cte_ScaffoldedSales AS (
	SELECT
	 S.Genre
	,S.Platform
	,S.YearVal AS Year
	,ISNULL(SUM(VG.Global_Sales), 0) AS Global_Sales
	FROM cte_Scaffold S
	LEFT JOIN cte_CleanSales VG
		ON  S.Genre    = VG.Genre
		AND S.Platform = VG.Platform
		AND S.YearVal  = VG.Year
	GROUP BY S.Genre, S.Platform, S.YearVal
),
cte_PlatformYearSales AS (
	SELECT
	 Platform
	,Year
	,SUM(Global_Sales) AS Total_Sales
	FROM cte_ScaffoldedSales
	GROUP BY Platform, Year
),
cte_PlatformYoY AS (
	SELECT
	 Platform
	,Year
	,Total_Sales
	,LAG(Total_Sales, 1, NULL) OVER (PARTITION BY Platform ORDER BY Year) AS Prev_Year_Sales
	FROM cte_PlatformYearSales
),
cte_PlatformMinYear AS (
	SELECT
	 Platform
	,MIN(Year) AS MinYear
	FROM cte_CleanSales
	WHERE Global_Sales > 0
	GROUP BY Platform
),
cte_YoYCalculated AS (
	SELECT
	 Y.Platform
	,Y.Year
	,Y.Total_Sales
	,Y.Prev_Year_Sales
	,(Y.Total_Sales - Y.Prev_Year_Sales) / Y.Prev_Year_Sales AS YoY_Growth
	FROM cte_PlatformYoY Y
	INNER JOIN cte_PlatformMinYear PMY ON Y.Platform = PMY.Platform
	WHERE Y.Year             > PMY.MinYear
	  AND Y.Prev_Year_Sales  > 0
),
cte_RankedYoY AS (
	SELECT
	 Platform
	,Year
	,Total_Sales
	,Prev_Year_Sales
	,YoY_Growth
	,ROW_NUMBER() OVER (PARTITION BY Platform ORDER BY YoY_Growth DESC) AS rn
	FROM cte_YoYCalculated
)
SELECT
 Platform
,Year
,Total_Sales
,Prev_Year_Sales
,ROUND(YoY_Growth, 4) AS Max_YoY_Growth
FROM cte_RankedYoY
WHERE rn = 1
ORDER BY YoY_Growth DESC

