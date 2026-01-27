---------------- Unmaterialized View ----------------
-- Complete Room Details
CREATE VIEW vw_room_complete AS
SELECT 
    r.room_id,
    c.city,
    s.state,
    d.district,
    co.country_name,
    co.country_code,
    r.num_bedrooms,
    r.max_guests,
    r.distance_city_center,
    r.distance_metro,
    l.latitude,
    l.longitude,
    rl.room_type,
    rl.day_type,
    rl.price_total,
    rl.guest_satisfaction_score,
    rl.cleanliness_score,
    rl.is_superhost,
    rl.is_shared_room,
    rl.is_multi_listing,
    rl.is_business_listing,
    cm.safety_index,
    cm.crime_index,
    cm.attraction_index,
    cm.restaurant_index,
    cm.monthly_avg_net_salary,
    cm.monthly_rent_1br_city_center,
    cm.meal_inexpensive_restaurant
FROM room r
JOIN location l ON r.room_id = l.room_id
JOIN city c ON l.city_id = c.city_id
JOIN state s ON l.state_id = s.state_id
JOIN district d ON l.district_id = d.district_id
JOIN country co ON l.country_id = co.country_id
JOIN room_list rl ON r.room_id = rl.room_id
JOIN city_metrics cm ON c.city_id = cm.city_id;

--  Premium Listings
CREATE VIEW vw_premium_listings AS
SELECT 
    room_id,
    city,
    country_name,
    room_type,
    price_total,
    guest_satisfaction_score,
    cleanliness_score,
    num_bedrooms,
    distance_city_center,
    is_superhost
FROM vw_room_complete
WHERE guest_satisfaction_score >= 90
  AND cleanliness_score >= 9
  AND is_superhost = 1;

-- Friendly Budget
CREATE VIEW vw_budget_rooms AS
SELECT 
    room_id,
    city,
    country_name,
    room_type,
    price_total,
    guest_satisfaction_score,
    distance_city_center,
    safety_index
FROM vw_room_complete
WHERE price_total < (SELECT AVG(price_total) FROM room_list)
  AND guest_satisfaction_score >= 75
  AND safety_index >= 50;

---------------- Materialized View ----------------
-- City stats
CREATE MATERIALIZED VIEW mv_city_stats AS
SELECT 
    c.city_id,
    c.city,
    co.country_name,
    COUNT(DISTINCT r.room_id) as total_listings,
    AVG(rl.price_total) as avg_price,
    MIN(rl.price_total) as min_price,
    MAX(rl.price_total) as max_price,
    AVG(rl.guest_satisfaction_score) as avg_satisfaction,
    AVG(rl.cleanliness_score) as avg_cleanliness,
    AVG(r.distance_city_center) as avg_distance_to_center,
    SUM(CASE WHEN rl.is_superhost = 1 THEN 1 ELSE 0 END) as superhost_count,
    SUM(CASE WHEN rl.is_superhost = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as superhost_percentage,
    cm.safety_index,
    cm.crime_index,
    cm.attraction_index,
    cm.restaurant_index,
    cm.monthly_rent_1br_city_center as avg_rent,
    CURRENT_TIMESTAMP as last_updated
FROM city c
JOIN country co ON c.city_id = co.country_id
JOIN city_metrics cm ON c.city_id = cm.city_id
JOIN location l ON c.city_id = l.city_id
JOIN room r ON l.room_id = r.room_id
JOIN room_list rl ON r.room_id = rl.room_id
GROUP BY c.city_id, c.city, co.country_name, cm.safety_index, cm.crime_index,
         cm.attraction_index, cm.restaurant_index, cm.monthly_rent_1br_city_center;

-- Refresh the view
REFRESH MATERIALIZED VIEW mv_city_stats;