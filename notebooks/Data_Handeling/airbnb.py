import logging
import time
import random
import re
import os
import pandas as pd
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# --- CONFIGURATION ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_CSV_PATH = os.path.join(BASE_DIR, "transformed_data", "merged_data_1.csv")
OUTPUT_CSV_PATH = os.path.join(BASE_DIR, "External_data", "airbnb_scraped_data.csv")
LOG_FILE = os.path.join(BASE_DIR, "scraper_run.log")

TARGET_COUNT_PER_CITY = 5

# --- LOGGING SETUP ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def force_kill_chrome():
    """Kill any stuck chrome processes from previous runs to avoid port conflicts."""
    try:
        os.system("pkill -f chrome")
        os.system("pkill -f undetected_chromedriver")
        time.sleep(2)
    except:
        pass

def setup_driver():
    """Initializes Undetected Chrome Driver for bypassing WAF on VPS."""
    chrome_options = uc.ChromeOptions()
    
    chrome_options.add_argument("--window-size=1920,1080")
    chrome_options.add_argument("--start-maximized")
    chrome_options.add_argument("--headless=new") 
    
    # Critical flags for Linux/VPS stability
    chrome_options.add_argument("--no-sandbox") 
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu") # Added for extra stability

    # Initialize driver
    try:
        driver = uc.Chrome(options=chrome_options, version_main=None)
        return driver
    except Exception as e:
        logger.error(f"Failed to initialize driver: {e}")
        force_kill_chrome() # Kill and retry once
        driver = uc.Chrome(options=chrome_options, version_main=None)
        return driver

def get_details_and_fav(driver, wait):
    """Extracts rating, review count, and favorite status."""
    rating, reviews, is_fav = "N/A", "0", 0 

    try:
        try:
            review_link = wait.until(EC.presence_of_element_located(
                (By.XPATH, "//a[contains(@href, 'reviews')] | //button[contains(., 'reviews')]")
            ))
        except:
            # Fallback for New listings
            try:
                h1_parent = driver.find_element(By.TAG_NAME, "h1").find_element(By.XPATH, "./..").text
                if "New" in h1_parent: return "New", "0", 0
            except: pass
            return rating, reviews, is_fav

        link_text = review_link.get_attribute("textContent").strip()
        clean_link = " ".join(link_text.split())
        
        parent_text = review_link.find_element(By.XPATH, "./..").get_attribute("textContent").strip()
        clean_parent = " ".join(parent_text.split())

        if "Guest favorite" in clean_link or "Guest favorite" in clean_parent:
            is_fav = 1
            r_match = re.search(r"(\d\.\d{1,2})", clean_parent)
            if r_match: rating = r_match.group(1)
            rev_match = re.search(r"(\d+)\s*Review", clean_parent, re.IGNORECASE)
            if rev_match: reviews = rev_match.group(1)
        else:
            is_fav = 0
            if "New" in clean_parent:
                rating = "New"
            else:
                r_match = re.search(r"(\d\.\d{1,2})", clean_parent)
                if r_match: rating = r_match.group(1)

            rev_match = re.search(r"(\d+)\s*review", clean_link, re.IGNORECASE)
            if not rev_match:
                rev_match = re.search(r"(\d+)\s*review", clean_parent, re.IGNORECASE)
            if rev_match: reviews = rev_match.group(1)

    except Exception as e:
        logger.debug(f"Error extracting details: {e}")
        pass
        
    return rating, reviews, is_fav

def main():
    # 0. Cleanup previous zombie processes
    force_kill_chrome()

    if not os.path.exists(INPUT_CSV_PATH):
        logger.error(f"Input file not found at: {INPUT_CSV_PATH}")
        return

    logger.info("Loading cities data...")
    try:
        df = pd.read_csv(INPUT_CSV_PATH, index_col="id")
        cities = df['city'].unique().tolist()
        logger.info(f"Found {len(cities)} cities to scrape: {cities}")
    except Exception as e:
        logger.error(f"Failed to read CSV: {e}")
        return

    all_data = []

    for idx, city in enumerate(cities, 1):
        logger.info(f"=== [{idx}/{len(cities)}] STARTING CITY: {city} ===")
        
        driver = None
        try:
            driver = setup_driver()
            wait = WebDriverWait(driver, 10)
            
            # 1. Search Page
            URL = f"https://www.airbnb.com/s/{city}/homes?refinement_paths%5B%5D=%2Fhomes&date_picker_type=calendar&search_type=filter_change&flexible_trip_lengths%5B%5D=one_week&monthly_start_date=2026-02-01&monthly_length=3&monthly_end_date=2026-05-01&price_filter_input_type=2&channel=EXPLORE&price_filter_num_nights=5&min_bedrooms=2&selected_filter_order%5B%5D=min_bedrooms%3A2&selected_filter_order%5B%5D=room_types%3AEntire%20home%2Fapt&update_selected_filters=true&query={city}&search_mode=regular_search&room_types%5B%5D=Entire%20home%2Fapt"
            
            logger.info(f"Loading search page for {city}...")
            driver.get(URL)
            
            # Wait for listings to load
            try:
                wait.until(EC.presence_of_all_elements_located((By.CSS_SELECTOR, "div[data-testid='card-container']")))
            except:
                logger.warning(f"No listings found for {city} (or blocked). Moving to next.")
                driver.quit()
                continue

            # 2. Collect URLs First (No tab switching)
            listings = driver.find_elements(By.CSS_SELECTOR, "div[data-testid='card-container']")
            listing_urls = []
            for l in listings:
                try:
                    url = l.find_element(By.TAG_NAME, "a").get_attribute("href")
                    listing_urls.append(url)
                except: continue
            
            # Limit to target count
            listing_urls = listing_urls[:TARGET_COUNT_PER_CITY]
            logger.info(f"Found {len(listing_urls)} listings to scrape for {city}")

            # 3. Visit URLs one by one
            for url in listing_urls:
                try:
                    driver.get(url)
                    wait.until(EC.presence_of_element_located((By.TAG_NAME, "h1")))
                    
                    # --- SCRAPE DETAILS ---
                    try: name = driver.find_element(By.TAG_NAME, "h1").text
                    except: name = "No Title"

                    is_superhost = "No"
                    try:
                        driver.execute_script("window.scrollBy(0, 500);")
                        time.sleep(0.5) 
                        body_text = driver.find_element(By.TAG_NAME, "body").text
                        if "Superhost" in body_text: is_superhost = "Yes"
                    except: pass

                    try:
                        price_element = driver.find_element(By.XPATH, "//div[@data-plugin-in-point-id='BOOK_IT_SIDEBAR']/div/div/div/div[1]/div[1]/div/div/span/div[1]/div/span/div/button/span")
                        price = price_element.text
                    except:
                        price = "N/A"

                    rating, reviews, is_fav = get_details_and_fav(driver, wait)

                    data_entry = {
                        "Name": name, "city": city, "Price": price, "Superhost": is_superhost,
                        "is_fav": is_fav, "Rating": rating, "Reviews": reviews, "URL": url
                    }
                    all_data.append(data_entry)
                    logger.info(f"Collected: {city} | {price} | ★{rating}")
                    
                    # Random sleep to behave like a human
                    time.sleep(random.uniform(2.0, 4.0))

                except Exception as e:
                    logger.error(f"Error scraping a specific listing URL: {e}")
                    continue

        except Exception as e:
            logger.error(f"Critical error processing city {city}: {e}")
        
        finally:
            if driver:
                try:
                    driver.quit()
                except: pass
            logger.info(f"Finished city: {city}")
            # Cool down between cities
            time.sleep(2)

    logger.info(f"Scraping complete. Total items: {len(all_data)}")
    
    if all_data:
        os.makedirs(os.path.dirname(OUTPUT_CSV_PATH), exist_ok=True)
        df_scraped = pd.DataFrame(all_data)
        df_scraped.to_csv(OUTPUT_CSV_PATH, index=False)
        logger.info(f"Data saved to {OUTPUT_CSV_PATH}")
    else:
        logger.warning("No data collected.")

if __name__ == "__main__":
    main()