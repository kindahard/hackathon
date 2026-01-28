--CREATE TABLE STATEMENTS

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
    distance_city_center DOUBLE PRECISION,
    distance_metro DOUBLE PRECISION,
    num_bedrooms INT,
    max_guests INT
);

-- City metrics table
CREATE TABLE city_metrics (
    city_metrics_id INT PRIMARY KEY,
    city_id INT NOT NULL,
    attraction_index DOUBLE PRECISION,
    attraction_index_norm DOUBLE PRECISION,
    restaurant_index DOUBLE PRECISION,
    restaurant_index_norm DOUBLE PRECISION,
    crime_index DOUBLE PRECISION,
    safety_index DOUBLE PRECISION,
    monthly_avg_net_salary DOUBLE PRECISION,
    meal_inexpensive_restaurant DOUBLE PRECISION,
    taxi_price_per_km DOUBLE PRECISION,
    monthly_basic_utilities DOUBLE PRECISION,
    monthly_rent_1br_city_center DOUBLE PRECISION,
    monthly_rent_1br_outside_center DOUBLE PRECISION,
    monthly_rent_3br_city_center DOUBLE PRECISION,
    monthly_rent_3br_outside_center DOUBLE PRECISION
);

-- Location table
CREATE TABLE location (
    location_id INT PRIMARY KEY,
    room_id INT NOT NULL,
    city_id INT NOT NULL,
    state_id INT NOT NULL,
    district_id INT NOT NULL,
    country_id INT NOT NULL,
    longitude DOUBLE PRECISION,
    latitude DOUBLE PRECISION
);

-- Room list table
CREATE TABLE room_list (
    room_list_id INT PRIMARY KEY,
    room_id INT NOT NULL,
    day_type VARCHAR(50),
    guest_satisfaction_score DOUBLE PRECISION,
    price_total DOUBLE PRECISION,
    is_shared_room SMALLINT,
    is_superhost SMALLINT,
    is_multi_listing SMALLINT,
    is_business_listing SMALLINT,
    cleanliness_score DOUBLE PRECISION,
    room_type VARCHAR(50)
);

--ADD FOREIGN KEY CONSTRAINTS

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