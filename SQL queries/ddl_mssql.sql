-- CREATE TABLE STATEMENTS

-- Country table 
CREATE TABLE country (
    country_id INT PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    country_code VARCHAR(10) NOT NULL
);

-- State table 
CREATE TABLE state (
    state_id INT PRIMARY KEY,
    state VARCHAR(100) NOT NULL
);

-- City table 
CREATE TABLE city (
    city_id INT PRIMARY KEY,
    city VARCHAR(100) NOT NULL
);

-- District table 
CREATE TABLE district (
    district_id INT PRIMARY KEY,
    district VARCHAR(100) NOT NULL
);

-- Room table 
CREATE TABLE room (
    room_id INT PRIMARY KEY,
    distance_city_center FLOAT,
    distance_metro FLOAT,
    num_bedrooms INT,
    max_guests INT
);

-- City metrics table
CREATE TABLE city_metrics (
    city_metrics_id INT PRIMARY KEY,
    city_id INT NOT NULL,
    attraction_index FLOAT,
    attraction_index_norm FLOAT,
    restaurant_index FLOAT,
    restaurant_index_norm FLOAT,
    crime_index FLOAT,
    safety_index FLOAT,
    monthly_avg_net_salary FLOAT,
    meal_inexpensive_restaurant FLOAT,
    taxi_price_per_km FLOAT,
    monthly_basic_utilities FLOAT,
    monthly_rent_1br_city_center FLOAT,
    monthly_rent_1br_outside_center FLOAT,
    monthly_rent_3br_city_center FLOAT,
    monthly_rent_3br_outside_center FLOAT
);

-- Location table
CREATE TABLE location (
    location_id INT PRIMARY KEY,
    room_id INT NOT NULL,
    city_id INT NOT NULL,
    state_id INT NOT NULL,
    district_id INT NOT NULL,
    country_id INT NOT NULL,
    longitude FLOAT,
    latitude FLOAT
);

-- Room list table
CREATE TABLE room_list (
    room_list_id INT PRIMARY KEY,
    room_id INT NOT NULL,
    day_type VARCHAR(50),
    guest_satisfaction_score FLOAT,
    price_total FLOAT,
    is_shared_room TINYINT,
    is_superhost TINYINT,
    is_multi_listing TINYINT,
    is_business_listing TINYINT,
    cleanliness_score FLOAT,
    room_type VARCHAR(50)
);

--  ADD FOREIGN KEY CONSTRAINTS

-- City metrics foreign keys
ALTER TABLE city_metrics
ADD CONSTRAINT fk_city_metrics_city
FOREIGN KEY (city_id) REFERENCES city(city_id);

-- Location foreign keys
ALTER TABLE location
ADD CONSTRAINT fk_location_room
FOREIGN KEY (room_id) REFERENCES room(room_id);

ALTER TABLE location
ADD CONSTRAINT fk_location_city
FOREIGN KEY (city_id) REFERENCES city(city_id);

ALTER TABLE location
ADD CONSTRAINT fk_location_state
FOREIGN KEY (state_id) REFERENCES state(state_id);

ALTER TABLE location
ADD CONSTRAINT fk_location_district
FOREIGN KEY (district_id) REFERENCES district(district_id);

ALTER TABLE location
ADD CONSTRAINT fk_location_country
FOREIGN KEY (country_id) REFERENCES country(country_id);

-- Room list foreign keys
ALTER TABLE room_list
ADD CONSTRAINT fk_room_list_room
FOREIGN KEY (room_id) REFERENCES room(room_id);