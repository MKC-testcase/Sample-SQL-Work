/* By: Marcus Chan */
/* Std ID A01403269 */

/*Q1: Sample of  New York Purchases vs All other states */
WITH IdentifyNewYork AS (
	SELECT
		*,
		IIF(o.[State] = 'NY', 0, 1) [New York Identifier]
	FROM SQLBook.dbo.Orders o
),
DividedPurchases AS (
	SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY iny.[New York Identifier] ORDER BY NEWID()) [Row Number]
	FROM IdentifyNewYork  iny
)
SELECT 
	dp.[State],
	dp.TotalPrice
FROM DividedPurchases dp
WHERE [Row Number] <= 200;


/*Q2: Sample for the question does gotham pay a higher monthly fee compared to other cities*/
WITH MinimumFee AS (
	SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY o.[IsGotham] ORDER BY NEWID()) [RowNumber]
	FROM (
		SELECT 
			*,
			IIF(s.Market = 'Gothan', 1, 0) [IsGotham]
		FROM SQLBook.dbo.Subscribers s
	) o
)
SELECT
	mf.StartDate,
	mf.Market,
	mf.MonthlyFee
FROM MinimumFee mf
WHERE mf.RowNumber <= 100;

/*Q3: Sample male and female genders in the workplace and compare their pay*/
WITH GenderPay AS (
	SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY o.Gender, o.JobTitle ORDER BY NEWID()) [RowRank]
	FROM (
		SELECT
			e.JobTitle,
			eh.Rate,
			Gender
		FROM AdventureWorks2022.HumanResources.Employee e
		JOIN AdventureWorks2022.HumanResources.EmployeePayHistory eh
		ON e.BusinessEntityID = eh.BusinessEntityID) o
)
SELECT *
FROM GenderPay gp
WHERE gp.RowRank <= 10

/*Q4: Sample product orders to determine which are the most popular */
SELECT * 
FROM SQLBook.dbo.OrderLines
WHERE (ABS(CAST((BINARY_CHECKSUM(*) * RAND()) AS INT)) % 100) < 5


/*Q5: Take a sample of products that are more than $20 */
SELECT TOP 200
	p.ProductId,
	p.GroupName,
	ol.TotalPrice
FROM SQLBook.dbo.OrderLines ol
JOIN SQLBook.dbo.Products p
ON p.ProductId = ol.ProductId
WHERE ol.TotalPrice >= 20.0
ORDER BY NEWID();

/* Model For Male Purchases 2009 */
/*  SET Target is their total purchases with input fields from accross Customer, Orders, OrderLines, Campaigns, and Products*/
/* Base line */
USE SQLBook;
DECLARE @Average_Male_Fallback FLOAT = (SELECT AVG(ol.TotalPrice) 
								FROM SQLBook.dbo.[OrderLines] ol
								JOIN SQLBook.dbo.[Orders] o
								ON o.OrderId = ol.OrderId
								JOIN SQLBook.dbo.Customers c
								ON c.CustomerId = o.CustomerId
								WHERE c.Gender = 'M' AND YEAR(o.OrderDate) = 2009);
-- Setting up the model and the score set
-- score set is the average totals in 2010
WITH ScoreSet AS (
	SELECT
		c.CustomerId,
		o.[State],
		o.City,
		o.PaymentType,
		p.ProductId,
		ca.CampaignId,
		ol.TotalPrice,
		p.GroupName
	FROM SQLBook.dbo.[OrderLines] ol
	JOIN SQLBook.dbo.[Orders] o
	ON o.OrderId = ol.OrderId
	JOIN SQLBook.dbo.Customers c
	ON c.CustomerId = o.CustomerId
	JOIN SQLBook.dbo.Products p
	ON p.ProductId = ol.ProductId
	JOIN SQLBook.dbo.Campaigns ca
	ON ca.CampaignId = o.CampaignId
	WHERE c.Gender = 'M' AND YEAR(o.OrderDate) = 2010
),
-- model set is the average for customers in 2009
ModelSet AS (
	SELECT
		o.[State],
		o.PaymentType,
		o.City,
		p.GroupName,
		AVG(ol.TotalPrice) [Average Total Price 2009]
	FROM SQLBook.dbo.[OrderLines] ol
	JOIN SQLBook.dbo.[Orders] o
	ON o.OrderId = ol.OrderId
	JOIN SQLBook.dbo.Customers c
	ON c.CustomerId = o.CustomerId
	JOIN SQLBook.dbo.Products p
	ON p.ProductId = ol.ProductId
	JOIN SQLBook.dbo.Campaigns ca
	ON ca.CampaignId = o.CampaignId
	WHERE c.Gender = 'M' AND YEAR(o.OrderDate) = 2009
	GROUP BY o.[State], o.PaymentType, o.City, p.GroupName,
)

SELECT
	b.[Decile],
	AVG(b.[Predicted]) AS [Average Predicted],
	AVG(b.[Actual]) AS [Average Actual]
	FROM (
		SELECT a.*, NTILE(10) OVER (ORDER BY a.[Predicted] DESC) AS [Decile]
		FROM (
				SELECT
					COALESCE(ModelSet.[Average Total Price 2009], @Average_Male_Fallback) AS [Predicted],
					ScoreSet.TotalPrice [Actual]
				FROM ScoreSet LEFT JOIN ModelSet
				ON  ScoreSet.[State] = ModelSet.[State] AND ScoreSet.City = ModelSet.City AND ScoreSet.PaymentType=ModelSet.PaymentType AND ScoreSet.GroupName=ModelSet.GroupName
		) a
	) b
GROUP BY b.[Decile]
ORDER BY b.[Decile]

