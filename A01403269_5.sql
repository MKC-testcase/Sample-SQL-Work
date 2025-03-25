/*  By : Marcus Chan
	Std No: A01403269
*/
USE SQLbook;
GO


/*Q1 Determine the campaigns that were active during the a selected year */
DROP FUNCTION IF EXISTS CampaignsDuringYear
GO

CREATE FUNCTION CampaignsDuringYear(
	@year INT
)
RETURNS TABLE
AS
RETURN
(
	SELECT DISTINCT c.CampaignId
	FROM SQLBook.dbo.Campaigns c
	JOIN SQLBook.dbo.Orders o
	ON o.CampaignId = c.CampaignId
	WHERE YEAR(o.OrderDate) = @year
)
GO
SELECT * FROM CampaignsDuringYear(2011) c
ORDER BY c.CampaignId ASC;
GO


/*Q2 Determine the number of subscribers that are within a range of monthly fees */
DROP FUNCTION IF EXISTS SubscribersGivenRangeOfMonthlyFees;
GO

CREATE FUNCTION SubscribersGivenRangeOfMonthlyFees(
	@fee1 FLOAT,
	@fee2 FLOAT
)
RETURNS TABLE
AS
RETURN
(
	SELECT 
		s.SubscriberId,
		s.Market,
		s.MonthlyFee
	FROM SQLbook.dbo.Subscribers s
	WHERE 
		(CASE WHEN @fee1 >= @fee2 THEN @fee1 ELSE @fee2 END) >= s.MonthlyFee AND 
		(CASE WHEN @fee1 >= @fee2 THEN @fee2 ELSE @fee1 END) <= s.MonthlyFee
)
GO
SELECT * FROM SubscribersGivenRangeOfMonthlyFees(24.90, 25)
GO


/*Q3 Determine customers and their locations that purchased a product */
DROP FUNCTION IF EXISTS CustomerAndLocationsByProduct;
GO

CREATE FUNCTION CustomerAndLocationsByProduct(
	@pID INT
)
RETURNS TABLE
AS
RETURN 
(
	SELECT
		c.CustomerId,
		zc.Longitude,
		zc.Latitude
	FROM SQLBook.dbo.Customers c
	JOIN SQLBook.dbo.Orders o
	ON o.CustomerId = c.CustomerId
	JOIN SQLBook.dbo.ZipCensus zc
	ON o.ZipCode = zc.zcta5
	JOIN SQLBook.dbo.OrderLines ol
	ON ol.OrderId = o.OrderId
	JOIN SQLBook.dbo.Products p
	ON p.ProductId = ol.ProductId
	WHERE p.ProductId = @pID
)
GO
SELECT * FROM CustomerAndLocationsByProduct(10001)
GO


/*Q4 Develop a function that shows differences in land area and water area from zip codes */
DROP FUNCTION IF EXISTS LandWaterCountyDifference;
GO

CREATE FUNCTION LandWaterCountyDifference(
	@zipCode1 VARCHAR(5),
	@zipCode2 VARCHAR(5)
)
RETURNS TABLE
AS
RETURN 
(
	WITH countyArea(landArea, waterArea, zipCode) AS(
		SELECT 
			zc.CountyLandAreaMiles [LandArea],
			zc.CountyWaterAreaMiles [WaterArea],
			zc.ZipCode [zipcode]
		FROM SQLBook.dbo.ZipCounty zc
		WHERE zc.ZipCode = @zipCode1 OR zc.ZipCode = @zipCode2
	)
	SELECT
		ca.landArea - (SELECT a.landArea FROM countyArea a WHERE a.zipCode = @zipCode1) [Land Area Difference],
		ca.waterArea - (SELECT a.waterArea FROM countyArea a WHERE a.zipCode = @zipCode1) [Water Area Difference]
	FROM countyArea ca
	WHERE ca.zipCode = @zipCode2
)
GO
SELECT * FROM LandWaterCountyDifference('00780', '00908')
GO


/*Q5 Create a function that distiguishes location of primary heating in a given state */
DROP FUNCTION IF EXISTS HeatingEnergyMapState
GO

CREATE FUNCTION HeatingEnergyMapState(
	@state VARCHAR(2),
	@energy_type NVARCHAR(20)
)
RETURNS TABLE
AS
RETURN
(
	SELECT
		zc.Longitude,
		zc.Latitude,
		CASE
			WHEN LOWER(@energy_type) = 'utility gas' THEN zc.HHFUtilGas
			WHEN LOWER(@energy_type) = 'lp gas' THEN zc.HHFLPGas
			WHEN LOWER(@energy_type) = 'electric' THEN zc.HHFElectric
			WHEN LOWER(@energy_type) = 'kerosene' THEN zc.HHFKerosene
			WHEN LOWER(@energy_type) = 'coal' THEN zc.HHFCoal
			WHEN LOWER(@energy_type) = 'wood' THEN zc.HHFWood
			WHEN LOWER(@energy_type) = 'solar' THEN zc.HHFSolar
			ELSE zc.HHFOther
			END [Heating Number]
	FROM SQLBook.dbo.ZipCensus zc
	WHERE zc.Stab = @state
)
GO
SELECT * FROM HeatingEnergyMapState('CA', 'Electric');
GO


/*Q6: Find the top 10 products by group code */
DROP FUNCTION IF EXISTS Top10ProductByGroupCode;
GO

CREATE FUNCTION Top10ProductByGroupCode(
	@group_code NVARCHAR(10)
)
RETURNS TABLE
AS
RETURN
(
	SELECT TOP 10
		p.ProductId,
		SUM(ol.NumUnits) [Number of Products]
	FROM SQLBook.dbo.Products p
	JOIN SQLBook.dbo.OrderLines ol
	ON ol.ProductId = p.ProductId
	WHERE p.GroupName = UPPER(@group_code)
	GROUP BY p.ProductId
)
GO
SELECT * FROM Top10ProductByGroupCode('calendar') c
ORDER BY c.[Number of Products];
GO


/*Q7: Determine holidays and number 1 product sold on that holiday based on a range of dates */
DROP FUNCTION IF EXISTS PopularProductHoliday;
GO

CREATE FUNCTION  PopularProductHoliday(
	@date1 DATE,
	@date2 DATE
)
RETURNS TABLE
AS 
RETURN
(
	WITH productHoliday([date], holiday, pid, num, [rank]) AS (
		SELECT
			c.[Date],
			c.HolidayName,
			p.ProductId,
			SUM(ol.NumUnits) [SUM OF Product],
			ROW_NUMBER() OVER (PARTITION BY c.[Date] ORDER BY SUM(ol.NumUnits) DESC) [RANK]
		FROM SQLBook.dbo.Calendar c
		JOIN SQLBook.dbo.Orders o
		ON o.OrderDate = c.[Date]
		JOIN SQLBook.dbo.OrderLines ol
		ON ol.OrderId = o.OrderId
		JOIN SQLBook.dbo.Products p
		ON p.ProductId = ol.ProductId
		WHERE c.HolidayType IS NOT NULL AND 
			  CAST(c.[Date] AS DATE) > IIF(DATEDIFF(DAY, 2009-1-04, 2009-12-30) < 0, @date1, @date2) AND
			  CAST(c.[Date] AS DATE) < IIF(DATEDIFF(DAY, 2009-1-04, 2009-12-30) > 0, @date1, @date2)
		GROUP BY c.[Date], c.[HolidayName], p.ProductId
	)
	SELECT *
	FROM productHoliday
	WHERE [rank] = 1
)
GO
SELECT * FROM PopularProductHoliday('2009-10-04', '2009-12-30')
ORDER BY [date];
GO


/*Q8: When listing a range of unit prices find the available range of products */
DROP FUNCTION IF EXISTS ProductsOnUnitPrice;
GO

CREATE FUNCTION ProductsOnUnitPrice(
	@unit_price1 FLOAT,
	@unit_price2 FLOAT
)
RETURNS TABLE
AS RETURN
(
	SELECT 
		p.ProductId,
		ol.UnitPrice,
		ol.TotalPrice
	FROM SQLBook.dbo.OrderLines ol
	JOIN SQLBook.dbo.Products p
	ON p.ProductId = ol.ProductId
	WHERE ol.UnitPrice <= IIF(@unit_price1 >= @unit_price2, @unit_price1, @unit_price2) AND
		  ol.UnitPrice >= IIF(@unit_price1 <= @unit_price2, @unit_price1, @unit_price2) 
)
GO
SELECT * FROM ProductsOnUnitPrice(9.00, 11.50)
GO


/*Q9: Count the payment types in a state */
DROP FUNCTION IF EXISTS NumberOfPaymentTypesForStates;
GO

CREATE FUNCTION NumberOfPaymentTypesForStates (
	@state1 VARCHAR(2)
)
RETURNS TABLE
AS 
RETURN
(
	SELECT
		pvt.[State],
		pvt.AE,
		pvt.DB,
		pvt.MV,
		pvt.VI,
		pvt.[??]
	FROM (
		SELECT
			o.[State],
			o.PaymentType
		FROM SQLBook.dbo.Orders o
		WHERE o.[State] = UPPER(@state1)
		) as pay
	PIVOT
	(
		COUNT(PaymentType)
		FOR PaymentType
		IN ([AE],[DB],[MV],[VI],[??])
	) as pvt
)
GO
SELECT * FROM NumberOfPaymentTypesForStates('CA');
GO


/*Q10: Determine the methods people get to work based on state */
DROP FUNCTION IF EXISTS GoingToWorkMethod;
GO

CREATE FUNCTION GoingToWorkMethod(
	@state VARCHAR(2)
)
RETURNS TABLE
AS 
RETURN
(
	SELECT
		zc.ZIPName,
		zc.Commuters,
		zc.DriveAlone,
		zc.Carpool,
		zc.PublicTrans,
		zc.WalkToWork,
		zc.OtherCommute,
		zc.WorkAtHome
	FROM SQLBook.dbo.ZipCensus zc
	WHERE zc.Stab = @state
)
GO
SELECT * FROM GoingToWorkMethod('NV')