/*
========================================================================
Documentation File for Airbnb-like Dataset
Description:
This file contains views, queries, and analytical operations on the 
room_list, room, city, and city_metrics tables. 
Comments explain the purpose and functionality of each query.
========================================================================
*/

-- ========================================================
-- 1. VIEWS
-- ========================================================

-- View: Prices and satisfaction for rooms
CREATE VIEW dbo.view_price_satisfaction
WITH SCHEMABINDING
AS
SELECT
    rl.room_id,
    rl.price_total,
    rl.guest_satisfaction_score,
    rl.cleanliness_score,
    rl.room_type,
    rl.is_superhost
FROM dbo.room_list AS rl;
GO

-- Test view
SELECT * FROM dbo.view_price_satisfaction;
GO




-- View: Listing types and attributes
CREATE VIEW dbo.view_listing_profile
AS
SELECT
    rl.room_id,
    rl.room_type,
    rl.is_superhost,
    rl.is_shared_room,
    rl.is_business_listing,
    rl.day_type
FROM dbo.room_list AS rl;
GO

-- Test view
SELECT * FROM dbo.view_listing_profile;
GO


-- ========================================================
-- 2. AGGREGATION & GROUPING
-- ========================================================



-- Purpose: Calculate the median price by room type and number of bedrooms Explanation: (postive corr)

WITH MedianCalculation AS (
    SELECT
        rl.room_type,
        r.num_bedrooms,
        PERCENTILE_CONT(0.5)  
            WITHIN GROUP (ORDER BY rl.price_total) 
            OVER (PARTITION BY rl.room_type, r.num_bedrooms) AS median_price
    FROM dbo.room_list rl
    INNER JOIN dbo.room r
        ON rl.room_id = r.room_id
)
SELECT DISTINCT
    room_type,
    num_bedrooms,
    median_price
FROM MedianCalculation
ORDER BY median_price DESC;
GO



--Purpose: Count listings by host type and business listing:  (most of flats are not for business)

SELECT
    is_superhost,
    is_business_listing,
    COUNT(*) AS Total
FROM dbo.view_listing_profile
GROUP BY is_superhost, is_business_listing;
GO



-- ========================================================
-- 3. CORRELATION ANALYSIS
-- ========================================================

/* 
Purpose: Compute correlation between cleanliness_score and guest_satisfaction_score  
(most important relation )
*/
SELECT  
    CORR(CAST(cleanliness_score AS FLOAT), CAST(guest_satisfaction_score AS FLOAT)) AS correlation_coefficient
FROM dbo.room_list
WHERE cleanliness_score IS NOT NULL
  AND guest_satisfaction_score IS NOT NULL;
GO


--(Optional)
/*
 SELECT 
     (SUM(CAST(cleanliness_score AS FLOAT) * CAST(guest_satisfaction_score AS FLOAT)) * 1.0 / COUNT(*)  
      - (SUM(CAST(cleanliness_score AS FLOAT)) * 1.0 / COUNT(*))  
        * (SUM(CAST(guest_satisfaction_score AS FLOAT)) * 1.0 / COUNT(*))) 
     / 
     (SQRT(SUM(POWER(CAST(cleanliness_score AS FLOAT), 2)) * 1.0 / COUNT(*)  
           - POWER(SUM(CAST(cleanliness_score AS FLOAT)) * 1.0 / COUNT(*), 2)) 
      * SQRT(SUM(POWER(CAST(guest_satisfaction_score AS FLOAT), 2)) * 1.0 / COUNT(*)  
             - POWER(SUM(CAST(guest_satisfaction_score AS FLOAT)) * 1.0 / COUNT(*), 2))) 
     AS correlation_coefficient 
 FROM dbo.room_list
 WHERE cleanliness_score IS NOT NULL
   AND guest_satisfaction_score IS NOT NULL;
 GO
 */

-- ========================================================
-- 4. CITY-LEVEL AGGREGATION
-- ========================================================

/*
Purpose: Top 30 cities with (low) average price, (high) satisfaction,(high) safety, and (low) crime metrics
(I recommend these cities for you)
*/
SELECT TOP 30
    c.city,
    COUNT(*) AS Listings,
    AVG(CAST(rl.price_total AS FLOAT)) AS AvgPrice,
    AVG(CAST(rl.guest_satisfaction_score AS FLOAT)) AS AvgSatisfaction,
    AVG(CAST(cm.safety_index AS FLOAT)) AS AvgSafety,
    AVG(CAST(cm.crime_index AS FLOAT)) AS AvgCrime
FROM dbo.room_list rl
JOIN dbo.location loc ON loc.room_id = rl.room_id
JOIN dbo.city c ON c.city_id = loc.city_id
LEFT JOIN dbo.city_metrics cm ON cm.city_id = loc.city_id
GROUP BY c.city
HAVING COUNT(*) >= 30
ORDER BY AvgSatisfaction DESC, AvgPrice ASC;
GO

-- ========================================================
-- 5. DISTANCE ANALYSIS
-- ========================================================

/*
Purpose: Group listings by distance from city center
*/
SELECT 
    CASE 
        WHEN r.distance_city_center < 1 THEN '<1 km'
        WHEN r.distance_city_center < 3 THEN '1-3 km'
        WHEN r.distance_city_center < 5 THEN '3-5 km'
        ELSE '5+ km'
    END AS CenterDistanceBucket,
    COUNT(*) AS Listings,
    AVG(CAST(rl.price_total AS FLOAT)) AS AvgPrice,
    AVG(CAST(rl.guest_satisfaction_score AS FLOAT)) AS AvgSatisfaction
FROM dbo.room_list rl
JOIN dbo.room r ON r.room_id = rl.room_id
GROUP BY 
    CASE 
        WHEN r.distance_city_center < 1 THEN '<1 km'
        WHEN r.distance_city_center < 3 THEN '1-3 km'
        WHEN r.distance_city_center < 5 THEN '3-5 km'
        ELSE '5+ km'
    END
ORDER BY AvgPrice DESC;
GO
