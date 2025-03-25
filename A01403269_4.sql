/* By: Marcus Chan */
/* Std ID : A10403269 */

/*Q1: Track the number of spannish speakers based on the distance from the border of mexico latitude wise*/
DECLARE @MexicanBorderLAT FLOAT = 32.71833333;
DECLARE @SRID INT = 4326;

DECLARE @UniqueCounties TABLE(
	long FLOAT,
	lat FLOAT,
	span INT,
	CNAME NVARCHAR(60)
);
DECLARE @Distances TABLE(
	lat FLOAT,
	point GEOGRAPHY,
	border GEOGRAPHY,
	span INT
);
INSERT INTO @UniqueCounties
	SELECT DISTINCT
	zc.Longitude, 
	zc.Latitude, 
	zc.Spanish,
	zc.County
	FROM SQLBook.dbo.ZipCensus zc;

INSERT INTO @Distances
	SELECT 
		u.lat,
		GEOGRAPHY::Point(u.lat, u.long, @SRID),
		GEOGRAPHY::Point(@MexicanBorderLAT, u.long, @SRID),
		u.span
	FROM @UniqueCounties u;

SELECT 
	FORMAT(d.lat, 'N2') Lat,
	SUM(d.span) [Spannish Speakers],
	FORMAT(AVG(point.STDistance(border)/1000), 'N2') [Border Distance, km]
FROM @Distances d
GROUP BY FORMAT(d.lat, 'N2')
ORDER BY FORMAT(d.lat, 'N2') ASC;


/*Q2: Find the locations of where number of orders greater than 50*/
WITH zipCodeOrders(zip, numOrders) AS (
	SELECT
		o.ZipCode,
		COUNT(*)
	FROM SQLBook.dbo.Orders o
	GROUP BY o.ZipCode
)
SELECT 
	zc.Longitude,
	zc.Latitude
FROM zipCodeOrders z
JOIN SQLBook.dbo.ZipCensus zc
ON z.zip = zc.zcta5
WHERE z.numOrders > 50;


/*Q3:find the greatest population densities of each state */
WITH countyPop([state], county, pop, long, lat, row_num) AS (
	SELECT
		zc.Stab,
		zc.County,
		zipc.CountyPop,
		AVG(zc.Longitude),
		AVG(zc.Latitude),
		ROW_NUMBER () OVER (PARTITION BY zc.Stab ORDER BY zipc.CountyPop DESC)
	FROM SQLBook.dbo.ZipCensus zc
	JOIN SQLBook.dbo.ZipCounty zipc
	ON zipc.ZipCode = zc.zcta5
	GROUP BY zc.Stab, zc.County, zipc.CountyPop
)
SELECT 
	c.long,
	c.lat,
	c.pop,
	c.county
FROM countyPop c
WHERE c.row_num = 1


/*Q4: find the locations of orders that came from within the state of Washington State */
DECLARE @washingtonSouth FLOAT = 45.55;
DECLARE @washingtonEast FLOAT = -116.9166;
DECLARE @washingtonNorth FLOAT = 49;
DECLARE @washingtonWest FLOAT = -124.7666;

SELECT
	o.ZipCode [ZipCode],
	zc.Longitude, 
	zc.Latitude,
	COUNT(*) [Number of Orders]
FROM SQLbook.dbo.Orders o
INNER JOIN SQLbook.dbo.ZipCensus zc
ON zc.zcta5 = o.ZipCode
WHERE (zc.Latitude > @washingtonSouth AND zc.Latitude < @washingtonNorth) AND zc.Longitude < @washingtonEast AND zc.Longitude > @washingtonWest
GROUP BY o.ZipCode, zc.Longitude, zc.Latitude;


/*Q5: find the degrees of solar power in the states of callifornia */
-- we will separate the degrees of solar power by
WITH solarPower(long, lat, solar) AS(
	SELECT
		FORMAT(zc.Longitude, 'N2'),
		FORMAT(zc.Latitude , 'N2'),
		SUM(zc.HHFSolar)
	FROM SQLbook.dbo.ZipCensus zc
	WHERE zc.HHFSolar <> 0 AND zc.Stab = 'CA'
	GROUP BY FORMAT(zc.Longitude, 'N2'), FORMAT(zc.Latitude , 'N2')
)
SELECT
	s.long,
	IIF(s.solar < 10, CAST(s.lat AS FLOAT), 0) AS [Low Power],
	IIF(s.solar >= 10 AND s.solar<35, CAST(s.lat AS FLOAT), 0) AS [Moderate Power],
	IIF(s.solar >= 35, CAST(s.lat AS FLOAT), 0) AS [High Power]
FROM solarPower s;


/*Q6: excluding outliers find the number of orders from each state */
DECLARE @order_average FLOAT;
DECLARE @order_deviation FLOAT;
DECLARE @orderStates TABLE (
	[state] VARCHAR(2), 
	num_orders FLOAT, 
	long FLOAT, 
	lat FLOAT
)
INSERT INTO @orderStates
	SELECT 
		zc.Stab,
		COUNT(OrderId),
		AVG(zc.Longitude),
		AVG(zc.Latitude)
	FROM SQLBook.dbo.Orders o
	INNER JOIN SQLBook.dbo.ZipCensus zc
	ON zc.zcta5 = o.ZipCode
	GROUP BY zc.Stab;


SELECT
	@order_average = AVG(o.num_orders),
	@order_deviation = STDEV(o.num_orders)
FROM @orderStates o;

SELECT 
	o.long,
	o.lat,
	o.num_orders
FROM @orderStates o
WHERE o.num_orders < @order_average + 2 * @order_deviation AND o.num_orders > @order_average - 2 * @order_deviation;


/*Q7: find the states products have sold more than 500 units */
WITH productZip(pID, numUnit, zCode) AS (
	SELECT
		p.ProductId,
		SUM(ol.NumUnits),
		o.ZipCode
	FROM SQLBook.dbo.Products p
	INNER JOIN SQLBook.dbo.OrderLines ol
	ON p.ProductId = ol.ProductId
	INNER JOIN SQLBook.dbo.Orders o
	ON ol.OrderId = o.OrderId
	GROUP BY p.ProductId, o.ZipCode
)

SELECT
	p.pID,
	zc.Stab,
	SUM(p.numUnit) [Number of Units],
	AVG(zc.Longitude) [Longitude],
	AVG(zc.Latitude) [Latitude],
	CONCAT('<Placemark><name>Product ID ', p.pID, ': Units', SUM(p.numUnit),'</name>',
        '<styleUrl>#icon-1899-0288D1</styleUrl>',
		'<Point><coordinates> ',AVG(zc.Longitude),',',AVG(zc.Latitude),',0 </coordinates>',
        '</Point></Placemark>') [KML]
FROM productZip p
INNER JOIN SQLBook.dbo.ZipCensus zc
ON zc.zcta5 = p.zCode
GROUP BY p.pID, zc.Stab
HAVING SUM(p.numUnit) > 500
ORDER BY SUM(p.numUnit) DESC;


/*Q8: find the locations of workers in the professional industry in texas with KML*/
WITH texasProf(long, lat, prof) AS (
	SELECT 
		FORMAT(zc.Longitude , 'N4'),
		FORMAT(zc.Latitude, 'N4'),
		SUM(zc.Professional)
	FROM SQLBook.dbo.ZipCensus zc
	WHERE zc.Stab = 'TX'
	GROUP BY FORMAT(zc.Longitude , 'N4'), FORMAT(zc.Latitude, 'N4')
	HAVING SUM(zc.Professional) > 10
)
SELECT
	long Longitude,
	lat [Latitude],
	IIF(prof < 100, CAST(lat AS FLOAT), 0) [Low],
	IIF(prof < 700 AND prof >=100, CAST(lat AS FLOAT), 0) [Medium],
	IIF(prof >= 700, CAST(lat AS FLOAT), 0) [High],
	prof [Professional Numbers]
FROM texasProf


/*Q9: Determine the home that might need to be refurbished with houses built before 1950 */
SELECT
	zc.Longitude,
	zc.Latitude,
	zc.Built1940_1949 + zc.BuiltBefore1940 [Old Houses]
FROM SQLBook.dbo.ZipCensus zc
WHERE zc.Stab = 'NV' OR zc.Stab = 'AZ'

/*Q10: Find the location of employees from the production and production control departments */
SELECT
	a.SpatialLocation.Long [Longitude],
	a.SpatialLocation.Lat [Latitude],
	d.GroupName [Department Group]
FROM AdventureWorks2022.HumanResources.Employee e
JOIN AdventureWorks2022.HumanResources.EmployeeDepartmentHistory ed
ON ed.BusinessEntityID=e.BusinessEntityID
JOIN AdventureWorks2022.HumanResources.Department d
ON d.DepartmentID = ed.DepartmentID
JOIN  AdventureWorks2022.Person.BusinessEntityAddress be
ON be.BusinessEntityID = e.BusinessEntityID
JOIN AdventureWorks2022.Person.[Address] a
ON a.AddressID = be.AddressID
WHERE d.GroupName = 'Manufacturing'

--