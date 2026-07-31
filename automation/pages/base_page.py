from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from ..utils.logger import AutomationLogger
from ..utils.screenshot import ScreenshotUtility

logger = AutomationLogger.get_logger()

class BasePage:
    """Base Page Object Model providing core browser interaction primitives."""
    
    def __init__(self, driver):
        self.driver = driver
        self.wait = WebDriverWait(driver, 15)
        
    def navigate_to(self, url):
        logger.info(f"Navigating to page: {url}")
        self.driver.get(url)
        
    def find_element(self, by, value):
        try:
            return self.wait.until(EC.presence_of_element_located((by, value)))
        except Exception as e:
            logger.warning(f"Element not found within timeout ({by}={value}): {e}")
            return self.driver.find_element(by, value)
            
    def click(self, by, value):
        logger.info(f"Clicking element: {by}={value}")
        elem = self.find_element(by, value)
        elem.click()
        
    def send_keys(self, by, value, text):
        logger.info(f"Typing into element: {by}={value}")
        elem = self.find_element(by, value)
        elem.send_keys(text)
        
    def get_text(self, by, value):
        elem = self.find_element(by, value)
        return elem.text
        
    def is_displayed(self, by, value):
        try:
            elem = self.find_element(by, value)
            return elem.is_displayed()
        except Exception:
            return False
            
    def take_page_screenshot(self, test_id, name="page_state"):
        return ScreenshotUtility.capture_screenshot(self.driver, test_id, name)
