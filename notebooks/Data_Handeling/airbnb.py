import logging
import time
import random
import re
import os
import pandas as pd
import undetected_chromedriver as uc  # Changed import
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# --- CONFIGURATION (LINUX PATHS) ---
# Get the absolute path of the directory where this script is located
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Construct absolute Linux paths dynamically
# This ensures it works even if you run the script from a different folder
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

def setup_driver():
    """Initializes Chrome Driver with VPS-friendly options."""
    chrome_options = uc.Options()
    chrome_options.add_argument("--window-size=1920,1080")
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--start-maximized")
    
    # Critical flags for Linux/VPS environments
    chrome_options.add_argument("--no-sandbox") 
    chrome_options.add_argument("--disable-dev-shm-usage")
    
    # Check if running as root (common in some VPS setups)
    if os.geteuid() == 0:
        chrome_options.add_argument("--no-sandbox")

    service = Service(ChromeDriverManager().install())
    driver = uc.Chrome(service=service, options=chrome_options)
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
            wait = WebDriverWait(driver, 8)
            
            URL = f"https://www.airbnb.com/s/{city}/homes?refinement_paths%5B%5D=%2Fhomes&date_picker_type=calendar&search_type=filter_change&flexible_trip_lengths%5B%5D=one_week&monthly_start_date=2026-02-01&monthly_length=3&monthly_end_date=2026-05-01&price_filter_input_type=2&channel=EXPLORE&price_filter_num_nights=5&min_bedrooms=2&selected_filter_order%5B%5D=min_bedrooms%3A2&selected_filter_order%5B%5D=room_types%3AEntire%20home%2Fapt&update_selected_filters=true&query={city}&search_mode=regular_search&room_types%5B%5D=Entire%20home%2Fapt"
            
            driver.get(URL)
            items_scraped_this_city = 0
            
            while items_scraped_this_city < TARGET_COUNT_PER_CITY:
                try:
                    wait.until(EC.presence_of_all_elements_located((By.CSS_SELECTOR, "div[data-testid='card-container']")))
                except:
                    logger.warning(f"No listings found for {city}. Moving to next city.")
                    break

                listings = driver.find_elements(By.CSS_SELECTOR, "div[data-testid='card-container']")
                listing_urls = []
                
                for l in listings:
                    try:
                        url = l.find_element(By.TAG_NAME, "a").get_attribute("href")
                        listing_urls.append(url)
                    except: continue

                main_window = driver.current_window_handle

                for url in listing_urls:
                    if items_scraped_this_city >= TARGET_COUNT_PER_CITY: break
                    
                    try:
                        driver.execute_script(f"window.open('{url}', '_blank');")
                        driver.switch_to.window(driver.window_handles[-1])
                        
                        wait.until(EC.presence_of_element_located((By.TAG_NAME, "h1")))
                        
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
                            logger.debug(f"Could not find price for {url}")

                        rating, reviews, is_fav = get_details_and_fav(driver, wait)

                        data_entry = {
                            "Name": name, "city": city, "Price": price, "Superhost": is_superhost,
                            "is_fav": is_fav, "Rating": rating, "Reviews": reviews, "URL": url
                        }
                        all_data.append(data_entry)
                        
                        logger.info(f"Collected [{len(all_data)}]: {city} | {price} | ★{rating}")

                        time.sleep(random.uniform(1.0, 2.0))
                        
                        driver.close()
                        driver.switch_to.window(main_window)
                        items_scraped_this_city += 1
                        
                    except Exception as e:
                        logger.error(f"Error scraping listing: {e}")
                        if len(driver.window_handles) > 1:
                            driver.close()
                            driver.switch_to.window(main_window)
                        continue

                if items_scraped_this_city < TARGET_COUNT_PER_CITY:
                    try:
                        next_btn = driver.find_element(By.CSS_SELECTOR, "a[aria-label='Next']")
                        driver.execute_script("arguments[0].click();", next_btn)
                        time.sleep(4)
                    except:
                        break

        except Exception as e:
            logger.error(f"Critical error processing city {city}: {e}")
        
        finally:
            if driver:
                driver.quit()
            logger.info(f"Finished city: {city}")

    logger.info(f"Scraping complete. Total items: {len(all_data)}")
    
    if all_data:
        os.makedirs(os.path.dirname(OUTPUT_CSV_PATH), exist_ok=True)
        df_scraped = pd.DataFrame(all_data)
        df_scraped.to_csv(OUTPUT_CSV_PATH, index=False)
        logger.info(f"Data saved to {OUTPUT_CSV_PATH}")
        logger.info("\n" + str(df_scraped["city"].value_counts()))
    else:
        logger.warning("No data collected.")

if __name__ == "__main__":
    main()
