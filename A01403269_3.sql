/* By: Marcus Chan */
/* Std No. A01403269 */

USE SQLBook;
GO


/*Q1: which gender is the highest spender per household*/
WITH GenderSpenderCTE(gen, tot, rank_num) AS (
	SELECT 
		c.Gender,
		SUM(o.TotalPrice),
		RANK() OVER (PARTITION BY c.HouseholdId ORDER BY SUM(o.TotalPrice))
	FROM SQLBook.dbo.Customers c
	INNER JOIN SQLBook.dbo.Orders o
	ON o.CustomerId = c.CustomerId
	GROUP BY c.Gender, c.HouseholdId
)
SELECT 
	gen [Gender],
	AVG(tot) [Average Total Spent],
	FORMAT(VAR(tot), 'N2') [Variance Total Spent],
	FORMAT(STDEV(tot), 'N2') [Standard Deviation Total Spent]
FROM GenderSpenderCTE
WHERE rank_num = 1
GROUP BY gen;


/*Q2: Track the change in orders on different holidays*/
WITH HolidayTypeCTE (holiday, dat, sumnum, futsumnum) AS (
	SELECT
		c.HolidayType,
		c.[Date],
		SUM(o.TotalPrice) [Current Holiday Revenue],
		LEAD(SUM(o.TotalPrice)) OVER (PARTITION BY c.HolidayType ORDER BY c.[Date] ASC) [Previous Holiday Revenue]
	FROM SQLBook.dbo.Calendar c
	INNER JOIN SQLBook.dbo.Orders o
	ON o.OrderDate=c.[Date]
	WHERE c.HolidayType IS NOT NULL
	GROUP BY c.HolidayType, c.[Date]
)
SELECT holiday [HolidayType], dat [Date], futsumnum - sumnum [Change in Revenue]
FROM HolidayTypeCTE;


/*Q3: Find the Max of Males/Females over the age of 65 of each state*/
DECLARE @state CHAR(2);
DECLARE @malePop INT;
DECLARE @femalePop INT;
DECLARE @maleRank INT;
DECLARE @femaleRank INT;
DECLARE @tempF INT;
DECLARE @tmp_table TABLE(
	[state] char(2),
	[gender] char(1),
	[population] INT
);
DECLARE cursor_val CURSOR FOR
SELECT 
	zc.stab,
	zc.Over65Males,
	zc.Over65Females,
	DENSE_RANK() OVER (PARTITION BY zc.stab ORDER BY zc.Over65Males DESC),
	DENSE_RANK() OVER (PARTITION BY zc.stab ORDER BY zc.Over65Females DESC)
FROM SQLBook.dbo.ZipCensus zc;

OPEN cursor_val;
FETCH NEXT FROM cursor_val INTO @state, @malePop, @femalePop, @maleRank, @femaleRank;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF(@maleRank = 1) INSERT INTO @tmp_table VALUES (@state, 'M', @malePop);
	IF(@femaleRank = 1) INSERT INTO @tmp_table VALUES (@state, 'F', @femalePop);
	FETCH NEXT FROM cursor_val INTO @state, @malePop, @femalePop, @maleRank, @femaleRank;
END

CLOSE cursor_val;
DEALLOCATE cursor_val

SELECT * FROM
@tmp_table;


/*Q4: Find the SUM, AVG, VAR, STDEV for the number of households with income less than 50,000$ for each state*/
with income50([state], families) AS (
	SELECT
		zc.stab,
		zc.FamHHInc35 + zc.FamHHInc25 + zc.FamHHInc15 +zc.FamHHInc10 + zc.FamHHInc0 
	FROM SQLBook.dbo.ZipCensus zc
)
SELECT
	DISTINCT([state]),
	SUM(families) OVER (PARTITION BY [state]) [Sum of Lower Income Families],
	AVG(families) OVER (PARTITION BY [state]) [Average of Lower Income Families],
	VAR(families) OVER (PARTITION BY [state]) [Variance of Lower Income Families],
	STDEV(families) OVER (PARTITION BY [state]) [Standard Deviation of Lower Income Families]
FROM income50;


/*Q5: Find the county with the median land of counties in each state*/
WITH distinctCountyLand ([State], countyName, CountyLandAreaMiles) AS (
	SELECT DISTINCT
		zco.[State],
		zco.CountyName,
		zco.CountyLandAreaMiles
	FROM SQLBook.dbo.ZipCounty zco
)
SELECT 
	zc.[State],
	FORMAT(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY SUM(zc.CountyLandAreaMiles)) OVER(PARTITION BY zc.State), 'N2') [Median Land Area of County]
FROM distinctCountyLand zc
WHERE zc.State IS NOT NULL
GROUP BY zc.[State];


/*Q6: Find average median for the county population of the states*/
WITH distinctCountyPop ([State], countyName, CountyPop) AS (
	SELECT DISTINCT
		zco.[State],
		zco.CountyName,
		zco.CountyPop
	FROM SQLBook.dbo.ZipCounty zco
)
SELECT 
	zc.[State],
	FORMAT(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY AVG(zc.CountyPop)) OVER(PARTITION BY zc.State), 'N2') [Median Population of County]
FROM distinctCountyPop zc
WHERE zc.State IS NOT NULL
GROUP BY zc.[State];


/*Q7: Population with cumulative percentage of Florida */
WITH distinctCountyPop ([State], countyName, countyPop) AS (
	SELECT DISTINCT
		zco.[State],
		zco.CountyName,
		zco.CountyPop
	FROM SQLBook.dbo.ZipCounty zco
)
SELECT 
	dcp.[State],
	dcp.CountyName,
	dcp.countyPop,
	PERCENT_RANK() OVER (PARTITION BY dcp.[State] ORDER BY dcp.countyPop) as [State Scale]
FROM distinctCountyPop dcp
WHERE dcp.[State] IS NOT NULL
GROUP BY dcp.[State], dcp.CountyName, dcp.countyPop
HAVING dcp.[State]='FL';


/*Q8: Compare Sales of a Campaign with Cumalative distribution with the date of the sales */
WITH campaignCTE(cam, dat, totprc) AS (
	SELECT
		c.CampaignId,
		o.OrderDate,
		o.TotalPrice
	FROM SQLBook.dbo.Campaigns c
	JOIN SQLBook.dbo.Orders o 
	ON c.CampaignId=o.CampaignId
	WHERE c.CampaignId = 2002 OR c.CampaignId = 2008 OR c.CampaignId = 2012
)
SELECT 
	cam,
	dat [Date],
	SUM(totprc) OVER (PARTITION BY cam ORDER BY dat) AS [Campaign Revenue]
FROM campaignCTE;


/*Q9: Find the changes to in monthly fees and the tenure of the customers from 2000 - 2006*/
DECLARE @channel VARCHAR(6);
DECLARE @start_date INT;
DECLARE @month_fee FLOAT;
DECLARE @tenure FLOAT;
DECLARE @prevChannel VARCHAR(6) = NULL;

DECLARE @rslt_table TABLE(
	[Channel] VARCHAR(6),
	[Start Date] INT,
	[Total Monthly Fee] FLOAT,
	[Average Tenure] FLOAT
);

DECLARE cursor_values CURSOR FOR
SELECT 
	sc.Channel,
	YEAR(sc.StartDate), 
	SUM(sc.MonthlyFee), 
	AVG(sc.Tenure)
FROM SQLBook.dbo.Subscribers sc
WHERE sc.IsActive = 0
GROUP BY sc.Channel, YEAR(sc.StartDate)
ORDER BY sc.Channel ASC, YEAR(sc.StartDate) ASC;

OPEN cursor_values;
FETCH NEXT FROM cursor_values INTO @channel, @start_date, @month_fee, @tenure;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF (@start_date > 1999 AND @start_date < 2007) INSERT INTO @rslt_table VALUES (@channel, @start_date, @month_fee, @tenure);
		
	FETCH NEXT FROM cursor_values INTO @channel, @start_date, @month_fee, @tenure;
END

CLOSE cursor_values;
DEALLOCATE cursor_values;

SELECT *
FROM @rslt_table;


/*Q10: Track yearly changes in the number of people subscribed and average monthly pricing */
DECLARE @start_date_count INT;
DECLARE @year INT;
DECLARE @rollover INT =0;
DECLARE @stop_date_count INT;
DECLARE @filter_stop_date INT;
DECLARE @sc_people INT;

DECLARE @fnl_table TABLE (
	[Year] INT,
	[Monthly Fees] FLOAT,
	[Number of Subscribers] INT
);

DECLARE cursor_value CURSOR FOR
SELECT
	a.[start_date],
	a.[count_start_date],
	b.[count_stop_date],
	a.monthly_fee
FROM (
	SELECT
		YEAR(sc.StartDate) [start_date],
		COUNT(YEAR(sc.StartDate)) [count_start_date],
		SUM(sc.MonthlyFee) [monthly_fee]
	FROM SQLBook.dbo.Subscribers sc
	GROUP BY YEAR(sc.StartDate)
) a
LEFT JOIN (SELECT 
	YEAR(sc.StopDate) [stop_date],
	COUNT(YEAR(sc.StopDate)) [count_stop_date]
	FROM SQLBook.dbo.Subscribers sc
	GROUP BY YEAR(sc.StopDate)) b
ON b.[stop_date]= a.[start_date]
ORDER BY a.[start_date]

open cursor_value;
FETCH NEXT FROM cursor_value INTO @year, @start_date_count, @stop_date_count, @month_fee;

WHILE @@FETCH_STATUS = 0
BEGIN
	IF (@stop_date_count IS NULL) SET @stop_date_count = 0
	SET @rollover = @rollover + @start_date_count - @stop_date_count
	INSERT INTO @fnl_table VALUES (@year, @month_fee,  @rollover)
	FETCH NEXT FROM cursor_value INTO @year, @start_date_count, @stop_date_count, @month_fee;
END

CLOSE cursor_value;
DEALLOCATE cursor_value;

SELECT *
FROM @fnl_table