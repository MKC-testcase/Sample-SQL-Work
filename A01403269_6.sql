USE SQLBook;
GO

/*Q1: Find the probability that an order is created on a day that is not a holiday or weekend */
WITH TotalOrders(num) AS (
	SELECT COUNT(*)
	FROM SQLBook.dbo.Orders o
)

SELECT
	CAST(COUNT(*) AS FLOAT)/CAST((SELECT * FROM TotalOrders) AS FLOAT) [Not Holiday or Weekend],
	1.0 - CAST(COUNT(*) AS FLOAT)/CAST((SELECT * FROM TotalOrders) AS FLOAT) [Holiday or Weekend]
FROM SQLBook.dbo.Orders o
JOIN SQLBOok.dbo.Calendar c
ON c.[Date] = o.OrderDate
WHERE c.HolidayName IS NULL AND c.DOW != 'Sat' AND c.DOW != 'Sun';

/*Q2: Find the odds that the a payment for an order by different payment types*/
SELECT
	o.PaymentType,
	CAST(COUNT(*) AS FLOAT)/CAST((SELECT COUNT(*) FROM SQLBook.dbo.Orders) AS FLOAT) [Payment Chance]
FROM SQLBook.dbo.Orders o
GROUP BY o.PaymentType;

/*Q3: Find the odds a product group is ordered in the month of december*/
WITH MonthlyProducts(num) AS(
	SELECT COUNT(*)
	FROM SQLBook.dbo.Orders o
	JOIN SQLBook.dbo.OrderLines ol
	ON ol.OrderId = o.OrderId
	WHERE MONTH(o.OrderDate) = 12
)

SELECT 
	p.GroupName,
	CAST(COUNT(*) AS FLOAT)/ CAST((SELECT * FROM MonthlyProducts) AS FLOAT) [Percent Group Order in December]
FROM SQLBook.dbo.Orders o
JOIN SQLBook.dbo.OrderLines ol
ON ol.OrderId = o.OrderId
JOIN SQLBook.dbo.Products p 
ON p.ProductId = ol.ProductId
WHERE MONTH(o.OrderDate) = 12
GROUP BY p.GroupName;

/*Q4: Find the odds a product group is ordered at any given time*/
WITH productAmounts(productGroup, num) AS (
	SELECT
		p.GroupName,
		SUM(ol.NumUnits) 
	FROM SQLBook.dbo.Products p
	JOIN SQLBook.dbo.Orderlines ol
	ON ol.ProductId = p.ProductId
	GROUP BY p.GroupName
)
SELECT 
	pA.productGroup,
	CAST(pA.num AS FLOAT)/CAST((
								SELECT SUM(ol.NumUnits) FROM SQLBook.dbo.OrderLines ol
									)AS FLOAT) [Percent Group Order]
FROM productAmounts pA

/*Q5: Determine the probability that the a male ordered a product */
SELECT
	CAST(COUNT(*) AS FLOAT)/CAST((SELECT COUNT(*) FROM SQLBook.dbo.Customers) AS FLOAT) [Male Chance],
	1- CAST(COUNT(*) AS FLOAT)/CAST((SELECT COUNT(*) FROM SQLBook.dbo.Customers) AS FLOAT) [Other]
FROM SQLBook.dbo.Customers c
WHERE c.Gender = 'M'


/*Q6: Find the odds that a subscriber is from gothan city */
SELECT
	CAST(COUNT(*) AS FLOAT)/ CAST((SELECT COUNT(*) FROM SQLBook.dbo.Subscribers) AS FLOAT) [Gotham Chance],
	1 - CAST(COUNT(*) AS FLOAT)/ CAST((SELECT COUNT(*) FROM SQLBook.dbo.Subscribers) AS FLOAT) [Not Gotham Chance]
FROM SQLBook.dbo.Subscribers s
WHERE s.Market = 'Gotham';

/*Q7: What is the probability of them using a Debit Card (DB) as opposed to Credit cards? */
WITH TotalCards(num) AS (
	SELECT
		COUNT(*)
	FROM SQLBook.dbo.Orders o
)
SELECT
	CAST(COUNT(*) AS FLOAT)/ CAST((SELECT * FROM TotalCards) AS FLOAT) [Debit Chances],
	1 - CAST(COUNT(*) AS FLOAT)/ CAST((SELECT * FROM TotalCards) AS FLOAT) [Credit Cards]
FROM SQLBook.dbo.Orders o
WHERE o.PaymentType = 'DB';

/*Q8 Find the odds that a campaign is held in the fall */
WITH NumCampaignsInFall(num) AS (
	SELECT
		COUNT(DISTINCT o.CampaignId)
	FROM SQLBook.dbo.Orders o
	WHERE MONTH(o.OrderDate) >=9 AND MONTH(o.OrderDate) <= 11
)

SELECT
	CAST((SELECT * FROM NumCampaignsInFall) AS FLOAT) / CAST(COUNT(DISTINCT o.CampaignId) AS FLOAT) [Fall Orders], 
	1 - CAST((SELECT * FROM NumCampaignsInFall) AS FLOAT) / CAST(COUNT(DISTINCT o.CampaignId) AS FLOAT) [Not in Fall Orders]
FROM SQLBook.dbo.Orders o;

/*Q9: Determine the odds a order comes from a city that starts with the letter N */
WITH NCity(num) AS (
	SELECT 
		COUNT(*)
	FROM SQLBook.dbo.Orders o
	WHERE Left(o.City, 1) = 'N'
)
SELECT
	CAST((SELECT * FROM NCity) AS FLOAT)/CAST(COUNT(*) AS FLOAT) [N Cities],
	1- CAST((SELECT * FROM NCity) AS FLOAT)/CAST(COUNT(*) AS FLOAT) [Other Cities]
FROM SQLBook.dbo.Orders o;

/*Q10: Find the odds that a order came from each state */
WITH TotalStateOrders(num) AS (
	SELECT 
		COUNT(*)
	FROM SQLBook.dbo.Orders o
)
SELECT
	o.[State],
	CAST(COUNT(*) AS FLOAT) / CAST((SELECT * FROM TotalStateOrders) AS FLOAT)*100 [Order Chance Percent]
FROM SQLBook.dbo.Orders o 
GROUP BY o.[State];