-- Which room types are most popular and profitable?

SELECT 
    city,
    country_name,
    room_type,
    COUNT(*) as total_listings,
    ROUND(AVG(price_total)::numeric, 2) as avg_price,
    ROUND(MIN(price_total)::numeric, 2) as min_price,
    ROUND(MAX(price_total)::numeric, 2) as max_price,
    ROUND(AVG(guest_satisfaction_score)::numeric, 1) as avg_satisfaction,
    ROUND(AVG(num_bedrooms)::numeric, 1) as avg_bedrooms,
    SUM(CASE WHEN is_superhost = 1 THEN 1 ELSE 0 END) as superhost_count,
    ROUND((SUM(CASE WHEN is_superhost = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100)::numeric, 1) as superhost_pct
FROM vw_room_complete
GROUP BY city, country_name, room_type
HAVING COUNT(*) > 5
ORDER BY city, total_listings DESC;


-- Best value individual listings
SELECT 
    room_id,
    city,
    country_name,
    district,
    room_type,
    num_bedrooms,
    ROUND(price_total::numeric, 2) as price,
    ROUND(guest_satisfaction_score::numeric, 1) as satisfaction,
    ROUND(cleanliness_score::numeric, 1) as cleanliness,
    ROUND(distance_city_center::numeric, 2) as distance_km,
    is_superhost,
    ROUND(safety_index::numeric, 1) as safety,
    ROUND((guest_satisfaction_score / price_total * 10)::numeric, 2) as value_score
FROM vw_room_complete
WHERE guest_satisfaction_score >= 80
  AND price_total > 0
ORDER BY value_score DESC
LIMIT 10;

-- Do superhosts charge more? Is it worth it?
WITH superhost_comparison AS (
    SELECT 
        city,
        country_name,
        -- Superhost metrics
        AVG(CASE WHEN is_superhost = 1 THEN price_total END) as superhost_price,
        AVG(CASE WHEN is_superhost = 1 THEN guest_satisfaction_score END) as superhost_satisfaction,
        COUNT(CASE WHEN is_superhost = 1 THEN 1 END) as superhost_count,
        -- Regular host metrics
        AVG(CASE WHEN is_superhost = 0 THEN price_total END) as regular_price,
        AVG(CASE WHEN is_superhost = 0 THEN guest_satisfaction_score END) as regular_satisfaction,
        COUNT(CASE WHEN is_superhost = 0 THEN 1 END) as regular_count
    FROM vw_room_complete
    GROUP BY city, country_name
)

SELECT 
    city,
    country_name,
    ROUND(superhost_price::numeric, 2) as superhost_avg_price,
    ROUND(regular_price::numeric, 2) as regular_avg_price,
    ROUND((superhost_price - regular_price)::numeric, 2) as price_difference,
    ROUND(((superhost_price - regular_price) / regular_price * 100)::numeric, 1) as price_premium_pct,
    ROUND(superhost_satisfaction::numeric, 1) as superhost_rating,
    ROUND(regular_satisfaction::numeric, 1) as regular_rating,
    ROUND((superhost_satisfaction - regular_satisfaction)::numeric, 1) as rating_difference,
    superhost_count,
    regular_count
FROM superhost_comparison
WHERE superhost_count > 0 AND regular_count > 0
ORDER BY price_premium_pct DESC;

-- Does safety affect pricing?
SELECT 
    city,
    country_name,
    CASE 
        WHEN safety_index >= 70 THEN 'Very Safe'
        WHEN safety_index >= 50 THEN 'Moderately Safe'
        ELSE 'Less Safe'
    END as safety_category,
    ROUND(safety_index::numeric, 1) as safety_index,
    ROUND(crime_index::numeric, 1) as crime_index,
    ROUND(avg_price::numeric, 2) as avg_price,
    ROUND(avg_satisfaction::numeric, 1) as avg_satisfaction,
    total_listings
FROM mv_city_stats
ORDER BY safety_index DESC;


-- Best location convenience for the price
SELECT 
    room_id,
    city,
    country_name,
    district,
    ROUND(price_total::numeric, 2) as price,
    ROUND(distance_city_center::numeric, 2) as distance_center_km,
    ROUND(distance_metro::numeric, 2) as distance_metro_km,
    ROUND(guest_satisfaction_score::numeric, 1) as satisfaction,
    ROUND((100 / (distance_city_center + distance_metro + 1) / price_total * 1000)::numeric, 2) as convenience_value_score
FROM vw_room_complete
WHERE distance_city_center > 0
  AND distance_metro > 0
  AND price_total > 0
ORDER BY convenience_value_score DESC
LIMIT 20;