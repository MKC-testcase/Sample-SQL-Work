/* By: Marcus Chan
   Std ID: A01403269
*/
USE [SQLBook];
GO

/*1. Average number of orders per customer */
with CustomerOrders AS (
	SELECT CustomerId, SUM(TotalPrice) as [num]
	FROM [SQLBook].[dbo].[Orders]
	GROUP BY CustomerId
)
SELECT AVG(num) as [Average Price of Orders]
FROM CustomerOrders;


/*2. Top 10 most successful campaigns */
WITH TopCampaigns AS (
	SELECT CampaignId, SUM(TotalPrice) as [Campaign Effects]
	FROM [SQLBook].[dbo].[Orders]
	GROUP BY CampaignId
)
SELECT TOP 10 c.CampaignName, c.Channel, c.Discount, tc.[Campaign Effects]
FROM TopCampaigns tc
INNER JOIN Campaigns c
ON tc.CampaignId=c.CampaignId
ORDER BY tc.[Campaign Effects] DESC;


/*3. Get the products are being ordered the least that are not zero and their stock */
WITH WorstProducts AS (
	SELECT p.[Name], ol.TotalPrice, ol.NumUnits, p.IsInStock
	FROM [SQLBook].[dbo].Products p
	LEFT JOIN OrderLines ol ON ol.ProductId=p.ProductId
	WHERE ol.NumUnits > 0
)
SELECT TOP 20 [Name], [TotalPrice] [Total Revenue], NumUnits [Number of Units Sold], IsInStock [Units Stocked]
FROM WorstProducts wp
ORDER BY [Number of Units Sold];


/*4. Determining the most popular Payment Type and the total payments for campaigns that have a discount */
WITH PopularPayment (paytype, num) AS (
	SELECT o.PaymentType, COUNT(*)
	FROM [SQLBook].[dbo].[Orders] o
	LEFT JOIN [SQLBook].[dbo].[Campaigns] c
	ON c.CampaignId=o.CampaignId
	WHERE c.Discount IS NOT NULL AND o.PaymentType IS NOT NULL
	GROUP BY o.PaymentType
)
SELECT paytype [Payment Type], num [Number of Payments]
FROM PopularPayment
ORDER BY num DESC;


/*5. Determine top 20 products sold the most based on having free shipping*/
WITH BestFreeShippedProduct (pID, numProducts) AS (
	SELECT p.ProductId, COUNT(*)
	FROM [SQLBook].[dbo].[Campaigns] c
	INNER JOIN [SQLBook].[dbo].[Orders] o ON o.CampaignId=c.CampaignId
	INNER JOIN [SQLBook].[dbo].[OrderLines] ol ON o.OrderId=ol.OrderId
	INNER JOIN [SQLBook].[dbo].[Products] p ON ol.ProductId=p.ProductId
	GROUP BY c.CampaignId, p.ProductId, c.FreeShppingFlag
	HAVING c.FreeShppingFlag='Y'
)
SELECT TOP 20 pID [Product ID], numProducts [Number of Products Sold]
FROM BestFreeShippedProduct
ORDER BY [Number of Products Sold] DESC;


/*6. Compare populations of commuters methods of transportation */
WITH ToWork ([state], Carpool, [Public], Walk, Other) AS (
	SELECT zc.[Stab], zc.Carpool, zc.PublicTrans, zc.WalkToWork, zc.OtherCommute
	FROM [SQLBook].[dbo].[ZipCensus] zc
)
SELECT 
	IIF(GROUPING([state])=1, 'Total', [state]) AS [state],
	SUM(Carpool) [Sum of Carpool], SUM([Public]) [Sum of Public Transport], SUM(Walk) [Sum of Walk to Work], SUM(Other) [Sum of Other]
FROM ToWork
GROUP BY ROLLUP ([state]);


/*7. Figuring which states that has more people with bachelors degrees*/
DECLARE @Bachelors TABLE ([state] VARCHAR(2), [numBach] INT);

INSERT INTO @Bachelors
	SELECT zc.Stab, zc.Bachelors
	FROM [SQLBook].[dbo].ZipCensus zc

SELECT 
	[state],
	SUM(numBach) [Number of Bachelors]
FROM @Bachelors
GROUP BY [state]
ORDER BY [Number of Bachelors] DESC


/*8. born in the current states vs immigrant vs different state for top 5 most populous states*/
DECLARE @WhereBorn TABLE ([state] VARCHAR(2), BornAbroad INT, BornInState INT, BornDiffState INT);

INSERT INTO  @WhereBorn
	SELECT zc.Stab, SUM(zc.BornAbroad), SUM(zc.BornInCurrState), SUM(zc.BornInDiffState)
	FROM [SQLBook].[dbo].ZipCensus zc
	GROUP BY zc.Stab

SELECT 
	[state],
	BornAbroad,
	BornInState,
	BornDiffState
FROM @WhereBorn
WHERE [state] IN (SELECT TOP 5 tp.[Stab]
				  FROM (SELECT zc.[Stab], SUM(zc.TotPop) [TotPop]
						FROM [SQLBook].[dbo].ZipCensus zc
						GROUP BY zc.Stab) tp
				  ORDER BY tp.TotPop);


/*9. Spanish Speakers based on latitude of state*/
DECLARE @SpanishSpeaking TABLE ([state] VARCHAR(2), latitude FLOAT, spanish INT)

INSERT INTO @SpanishSpeaking
	SELECT zc.Stab, zc.Latitude, zc.Spanish
	FROM [SQLBook].[dbo].[ZipCensus] zc

SELECT [state], ROUND(AVG(latitude),2) [Average Latitude], SUM(spanish) [Spanish Speakers]
FROM @SpanishSpeaking
GROUP BY [state]
ORDER BY [Average Latitude] ASC;
GO


/*10. Housing vs Renting populations more densely populated areas */
DROP TABLE IF EXISTS #HouseRent;
GO
CREATE TABLE #HouseRent([state] VARCHAR(2), totalRental INT, totalOwners INT);

INSERT INTO #HouseRent
	SELECT Stab, SUM(TotalRentalUnits) [SumRent], SUM(TotalOwnerUnits) [SumOwn]
	FROM [SQLBook].[dbo].ZipCensus
	GROUP BY ROLLUP(Stab)

SELECT [state] [States], totalRental - totalOwners [Rent to Owner Difference]
FROM #HouseRent;
GO


/*11. Counties with more electric house heating(counting solar as well) in New York State*/
DROP TABLE IF EXISTS #ElectricState;
GO
CREATE TABLE #ElectricState([state] VARCHAR(2), county NVARCHAR(20), electric INT, solar INT)

INSERT INTO #ElectricState
	SELECT zc.Stab, zc.County, SUM(zc.HHFElectric), SUM(zc.HHFSolar)
	FROM [SQLBook].[dbo].[ZipCensus] zc
	GROUP BY zc.Stab, zc.County
	HAVING zc.Stab='NY'

SELECT county, electric + solar [Electric Heating Units]
FROM #ElectricState
ORDER BY [Electric Heating Units] DESC;
GO


/*12. Find the state with the most military and which state contribute the most to it */
DROP TABLE IF EXISTS #MilitaryRecru;
GO
CREATE TABLE #MilitaryRecru([state] VARCHAR(2), milit INT, pop INT)

INSERT INTO #MilitaryRecru
	SELECT zc.Stab, SUM(zc.Military), SUM(zc.TotPop)
	FROM [SQLBook].[dbo].[ZipCensus] zc
	GROUP BY zc.Stab

SELECT TOP 10 zc.County, zc.Military
FROM [SQLBook].[dbo].[ZipCensus] zc
WHERE zc.Stab= (SELECT TOP 1 [state]
				FROM #MilitaryRecru
				ORDER BY milit)
ORDER BY zc.Military DESC