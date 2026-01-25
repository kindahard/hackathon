# Day One Data – Airbnb City Listings

## 1. Files in this folder

The folder contains Airbnb listing data for multiple European cities. For each city there are **two files**: one for weekday stays and one for weekend stays.

Cities (each has `_weekdays` and `_weekends` CSV files):
- `amsterdam`
- `athens`
- `barcelona`
- `berlin`
- `budapest`
- `lisbon`
- `london`
- `paris`
- `rome`
- `vienna`

Each CSV has the **same schema** described below.

> Note: The first column in the raw CSV files is an unnamed index (0, 1, 2, …). It is not a feature of the dataset and can be safely dropped after loading.


## 2. Column descriptions and types (common to all files)

Column name	Type	Description
`realSum`	Numeric (float)	Total price of the stay for the listing (sum over all nights in the period represented by the row).
`room_type`	Categorical (string)	Type of accommodation, e.g. `Entire home/apt`, `Private room`, `Shared room`.
`room_shared`	Boolean	`True` if the room/space is shared with other guests; otherwise `False`.
`room_private`	Boolean	`True` if the guest has a private room/space; otherwise `False`.
`person_capacity`	Numeric (integer)	Maximum number of guests the listing can accommodate.
`host_is_superhost`	Boolean	`True` if the host is a Superhost, otherwise `False`.
`multi`	Boolean	Indicates if the host has multiple listings / the listing is part of a multi‑listing portfolio.
`biz`	Boolean	Indicates if the listing is flagged as a business‑ready / business‑oriented property.
`cleanliness_rating`	Numeric (float)	Average cleanliness rating given by guests.
`guest_satisfaction_overall`	Numeric (integer)	Overall guest satisfaction score (review rating) for the listing.
`bedrooms`	Numeric (integer)	Number of bedrooms in the listing.
`dist`	Numeric (float)	Distance from the city centre. (Unit not explicitly documented; appears to be in kilometres.)
`metro_dist`	Numeric (float)	Distance to the nearest metro/rapid‑transit station.
`attr_index`	Numeric (float)	Attraction index for the listing’s location – higher values mean better access to tourist attractions / points of interest.
`attr_index_norm`	Numeric (float)	Normalised version of `attr_index` (roughly scaled into a 0–1 or similar range across each city).
`rest_index`	Numeric (float)	Restaurant / nightlife index for the location – higher values mean better access to restaurants and bars.
`rest_index_norm`	Numeric (float)	Normalised version of `rest_index` (roughly scaled into a 0–1 or similar range across each city).
`lng`	Numeric (float)	Longitude of the listing.
`lat`	Numeric (float)	Latitude of the listing.


## 3. Structure of the data

- **Granularity:** Each row represents a listing in a given city for a given pricing regime (weekday vs weekend).
- **Time dimension:** The files are snapshots from the source Kaggle dataset; they do not contain an explicit date, just weekday/weekend pricing.
- **Geographical information:** `lng` and `lat` give exact coordinates; `dist` and `metro_dist` summarise proximity to city centre and public transport.
- **Location quality indices:** `attr_index` / `rest_index` and their normalised versions describe how attractive an area is for tourism and restaurants compared to other parts of the same city.
- **Host and listing characteristics:** `room_type`, `person_capacity`, `bedrooms`, `host_is_superhost`, `multi`, `biz`, and ratings capture supply‑side characteristics and quality.
- **Target‑like variables:** `realSum` (pricing) and `guest_satisfaction_overall` (reviews) are the main outcomes you will often want to model or explain.


## 4. Making the data robust and analysis‑ready

To build a solid dataset for analysis or modelling, the following preprocessing steps are recommended.

### 4.1. Consolidate files into a single dataset

1. **Load all CSVs** from `data/day_one_data`.
2. For each file, derive and add:
   - `city` – from the file name prefix (e.g. `"amsterdam"`, `"vienna"`).
   - `is_weekend` – `True` for `*_weekends.csv`, `False` for `*_weekdays.csv`.
   - `source_file` – optional, the original file name for traceability.
3. **Drop the unnamed index column** (the first column in the raw CSV) so that the dataset only contains meaningful features.

### 4.2. Enforce consistent data types

- Cast columns explicitly:
  - `room_shared`, `room_private`, `host_is_superhost`, `multi`, `biz`, `is_weekend` → boolean.
  - `person_capacity`, `bedrooms`, `guest_satisfaction_overall` → integer.
  - `realSum`, `cleanliness_rating`, `dist`, `metro_dist`, `attr_index`, `attr_index_norm`, `rest_index`, `rest_index_norm`, `lng`, `lat` → float.
  - `room_type`, `city`, `source_file` → categorical/string.
- Validate that value ranges are sensible (e.g. `guest_satisfaction_overall` within the expected review scale).

### 4.3. Handle missing values and anomalies

- Check for **missing or zero prices** in `realSum`; decide whether to drop, impute, or filter them.
- Identify **extreme outliers** in `realSum`, `dist`, and the index variables (log‑transform or winsorise if needed).
- Inspect rows with inconsistent flags (e.g. `room_shared == True` but `room_private == True`) and correct or drop them.
- Verify geolocation: remove obviously invalid coordinates if any are present.

### 4.4. Create useful derived features

Some common engineered features that make analysis and modelling easier:

- **Price‑related:**
  - `price_per_person = realSum / person_capacity`.
  - `log_price = log(realSum)` to stabilise variance for regression models.
- **Location‑related:**
  - Bucket `dist` and `metro_dist` into distance bands (e.g. `0–1 km`, `1–3 km`, `3–5 km`, `>5 km`).
  - Create neighbourhood clusters by spatially clustering (`lng`, `lat`) per city if you need neighbourhood‑level analysis.
- **Quality and host features:**
  - Binary flags such as `is_entire_home` (from `room_type`), `high_cleanliness` (e.g. `cleanliness_rating >= 9`), `high_satisfaction` (e.g. `guest_satisfaction_overall >= 95`).

### 4.5. Standardise and normalise where appropriate

- If combining data across **all cities**, consider:
  - Standardising continuous variables (z‑scores) to make them comparable across cities.
  - Keeping both raw and normalised versions of `attr_index` / `rest_index` if you plan to compare within a city vs across cities.
- For models sensitive to scale (e.g. distance‑based models), scale numeric variables in a consistent way.

### 4.6. Document assumptions and transformations

- Keep a short log (in code or markdown) of:
  - Which rows were filtered or dropped (e.g. impossible prices, invalid coordinates).
  - How missing values were handled.
  - Exact formulas used for derived features.
  - Any city‑specific rules or corrections.


## 5. Recommended overall workflow (best way to make robust data)

1. **Ingest**: Load all weekday and weekend CSVs, dropping the unnamed index column and adding `city` and `is_weekend`.
2. **Type enforcement**: Cast every column to the correct type (booleans, integers, floats, categoricals) and validate ranges.
3. **Cleaning**: Remove or cap extreme outliers, handle missing values, and fix inconsistent flags.
4. **Feature engineering**: Add derived variables such as `price_per_person`, `log_price`, distance bands, neighbourhood clusters, and quality flags.
5. **Normalisation and scaling**: Standardise numeric features when comparing across cities or training models that are scale‑sensitive.
6. **Documentation and versioning**: Save the cleaned, combined dataset as a new file (e.g. `day_one_clean.parquet` or `day_one_clean.csv`) and clearly document all preprocessing steps so analysis is reproducible.

Following this workflow will give you a **single, clean, well‑typed dataset** that is robust and ready for exploratory analysis, visualisation, and modelling.
