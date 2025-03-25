/*By: Marcus Chan */
/*Std ID: A01403269 */

/* Naive Bayes Model for group product of a state and their method of payment for the chance of moderate purchase*/
-- overall I think this model might be too granular for Naive Bayes to work
-- moderate purchase is anything greater than 10 dollars
-- First dimension is State
WITH dim1 AS (
	SELECT 
		o.[State],
		AVG(IIF(o.TotalPrice > 10.0, 1.0, 0)) p
	FROM SQLBook.dbo.Orders o
	WHERE YEAR(o.OrderDate) = 2011 AND o.[State] IS NOT NULL
	GROUP BY o.[State]
),
-- Second Dimension is the Payment Type
dim2 AS (
	SELECT 
		o.PaymentType,
		AVG(IIF(o.TotalPrice > 10.0, 1.0, 0)) p
	FROM SQLBook.dbo.Orders o
	WHERE YEAR(o.OrderDate) = 2011 AND o.[State] IS NOT NULL
	GROUP BY o.PaymentType
),
-- Third Dimension is the product group name
dim3 AS (
	SELECT
		p.GroupName,
		AVG(IIF(o.TotalPrice > 10.0, 1.0, 0)) p
	FROM SQLBook.dbo.Orders o
	JOIN SQLBook.dbo.OrderLines ol
	ON ol.OrderId = o.OrderId
	JOIN SQLBook.dbo.Products p 
	ON p.ProductId = ol.ProductId
	WHERE YEAR(o.OrderDate) = 2011 AND o.[State] IS NOT NULL
	GROUP BY p.GroupName
),
overall AS (
	SELECT
		AVG(IIF(o.TotalPrice > 10.0, 1.0, 0)) p
	FROM SQLBook.dbo.Orders o
	WHERE YEAR(o.OrderDate) = 2011 AND o.[State] IS NOT NULL
),
actual AS (
	SELECT 
		o.[State],
		o.PaymentType,
		p.GroupName,
		AVG(IIF(o.TotalPrice > 10.0, 1.0, 0)) p
	FROM SQLBook.dbo.Orders o
	JOIN SQLBook.dbo.OrderLines ol
	ON ol.OrderId = o.OrderId
	JOIN SQLBook.dbo.Products p
	ON p.ProductId = ol.ProductId
	WHERE YEAR(o.OrderDate) = 2011 AND o.[State] IS NOT NULL
	GROUP BY o.[State], o.PaymentType, p.GroupName
)
SELECT
	dims.[State],
	[State Probability],
	PaymentType,
	[Payment Type Probability],
	GroupName [Product Group Name],
	[Product GroupName Probability],
	[Predicted Probability],
	[Actual Probability]
FROM (
	SELECT
		dim1.[State],
		dim1.p [State Probability],
		dim2.PaymentType,
		dim2.p [Payment Type Probability],
		dim3.GroupName,
		dim3.p [Product GroupName Probability],
		POWER(overall.p, -1) * dim1.p * dim2.p * dim3.p [Predicted Probability],
		actual.p [Actual Probability]
	FROM dim1
	CROSS JOIN dim2
	CROSS JOIN dim3
	CROSS JOIN overall
	JOIN actual
	ON dim1.[State] = actual.[State] 
	AND dim2.PaymentType = actual.PaymentType
	AND dim3.GroupName = actual.GroupName
) dims
ORDER BY dims.[State], dims.PaymentType, dims.GroupName


/* Lookup Model TOP Payment option for a city for a YEAR*/
DROP FUNCTION IF EXISTS A01403269_FavoriteCityPayment_Model
GO
CREATE FUNCTION A01403269_FavoriteCityPayment_Model 
(
	@PaymentYear VARCHAR(4)
)
RETURNS TABLE
AS
RETURN
(
	-- Take a sample and filter SQLBook.dbo.Orders to correct year
	WITH TakeSample AS(
		SELECT 
			*,
			ROW_NUMBER() OVER (ORDER BY o.[OrderId]) [RowNum]
		FROM SQLBook.dbo.Orders o
		WHERE YEAR(o.OrderDate) = @PaymentYear
	),
	-- Count the number Orders given the city and payment type
	CityPayment (city, paytype, paynum, rownum) AS (
		SELECT
			o.City,
			o.PaymentType,
			COUNT(*) [Payment Number],
			ROW_NUMBER() OVER (PARTITION BY o.City ORDER BY COUNT(*) DESC) [Order]
		FROM TakeSample o
		WHERE o.RowNum %100 <= 80
		GROUP BY o.City, o.PaymentType
	),
	-- Create a table to allow me to sum the total rows of the table
	InterTable AS (
		SELECT 
			*
		FROM CityPayment cp
		WHERE cp.rownum = 1
	)
	-- Passing through table with total of the cities preferred card
	SELECT 
		*,
		(SELECT SUM(paynum) FROM InterTable) [Total]
	FROM InterTable IT
)
GO

-- Creating a second function for the Scoring
DROP FUNCTION IF EXISTS A01403269_FavoriteCityPayment_Score 
GO
CREATE FUNCTION A01403269_FavoriteCityPayment_Score 
(
	@PaymentYear VARCHAR(4)
)
RETURNS TABLE
AS
RETURN
(
	-- Take a sample and filter SQLBook.dbo.Orders to correct year
	WITH TakeSample AS(
		SELECT 
			*,
			ROW_NUMBER() OVER (ORDER BY o.[OrderId]) [RowNum]
		FROM SQLBook.dbo.Orders o
		WHERE YEAR(o.OrderDate) = @PaymentYear
	),
	-- Count the number Orders given the city and payment type
	CityPayment (city, paytype, paynum, rownum) AS (
		SELECT
			o.City,
			o.PaymentType,
			COUNT(*) [Payment Number],
			ROW_NUMBER() OVER (PARTITION BY o.City ORDER BY COUNT(*) DESC) [Order]
		FROM TakeSample o
		WHERE o.RowNum %100 > 80
		GROUP BY o.City, o.PaymentType
	),
	-- Create a table to allow me to sum the total rows of the table
	InterTable AS (
		SELECT 
			*
		FROM CityPayment cp
		WHERE cp.rownum = 1
	)
	-- Passing through table with total of the cities preferred card
	SELECT 
		*,
		(SELECT SUM(paynum) FROM InterTable) [Total]
	FROM InterTable IT
)
GO
-- Compute the sums based on of the paynum columns for the Score
WITH interScore AS (
	SELECT
		fun2.paytype,
		SUM(fun2.paynum) [Number of Cities],
		MAX(fun2.Total) [Score Total]
	FROM A01403269_FavoriteCityPayment_Score('2010') fun2
	GROUP BY fun2.paytype
),
-- Compute the sums based on of the paynum columns for the Model
interModel AS (
	SELECT 
		fun.paytype,
		SUM(fun.paynum) [Number of Cities],
		(SUM(fun.paynum) * 1.0 )/ (MAX(fun.Total)* 1.0) [Percentage]
	FROM A01403269_FavoriteCityPayment_Model('2010') fun
	GROUP BY fun.paytype
)

-- Displaying the results of the model
SELECT 
	iM.paytype,
	iM.[Number of Cities],
	CONCAT(iM.[Percentage], '%'),
	iM.[Percentage] * iSC.[Score Total] [Model Numbers],
	iSC.[Number of Cities] [Score Numbers]
FROM interModel iM
JOIN interScore iSC
ON iSC.paytype = iM.paytype
GO

/* Campaign Signature - I think this is what the signature part is like.*/
DROP FUNCTION IF EXISTS A01403269_CampaignSignature;
GO
CREATE FUNCTION A01403269_CampaignSignature(
	@CutOffDate DATE
)
RETURNS TABLE
AS
RETURN (
	SELECT 
		o.CampaignId,
		SUM(TotalPrice) [Campaign Revenue],
		SUM(NumUnits) [Units Sold],
		MIN([Duration]) [Campaign Duration],
		MIN([Last]) [Last Campaign Day],
		MIN(@CutOffDate) [Cut Off Date]
	FROM SQlBook.dbo.Orders o
	JOIN 
		(
		-- finding the campaign duration and last day
			SELECT 
				c.CampaignId,
				DATEDIFF(DAY, MIN(o.OrderDate), MAX(o.OrderDate)) [Duration],
				MAX(o.OrderDate) [Last]
			FROM SQLBook.dbo.Campaigns c
			JOIN SQLBook.dbo.Orders o
			ON c.CampaignId = o.CampaignId
			GROUP BY c.CampaignId
		) minmax
		 ON o.CampaignId = minmax.CampaignId
	-- cut off after last day
	WHERE CAST(minmax.[Last] AS DATE) < @CutOffDate
	GROUP BY o.CampaignId
)
GO
-- showing the signature
SELECT * FROM A01403269_CampaignSignature('2015-01-01') ORDER BY CampaignId;