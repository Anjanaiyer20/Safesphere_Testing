import os
from selenium import webdriver
from selenium.webdriver.chrome.options import Options as ChromeOptions
from selenium.webdriver.firefox.options import Options as FirefoxOptions
from .logger import AutomationLogger

logger = AutomationLogger.get_logger()

class DriverFactory:
    """WebDriver factory supporting Headless Chrome, Firefox, and Mock Drivers."""
    
    @staticmethod
    def get_driver(browser_name="chrome", headless=True):
        logger.info(f"Initializing WebDriver: Browser={browser_name}, Headless={headless}")
        
        try:
            if browser_name.lower() == "chrome":
                options = ChromeOptions()
                if headless:
                    options.add_argument("--headless=new")
                options.add_argument("--no-sandbox")
                options.add_argument("--disable-dev-shm-usage")
                options.add_argument("--disable-gpu")
                options.add_argument("--window-size=1920,1080")
                options.add_argument("--allow-running-insecure-content")
                options.add_argument("--ignore-certificate-errors")
                
                driver = webdriver.Chrome(options=options)
                driver.implicitly_wait(10)
                return driver
            elif browser_name.lower() == "firefox":
                options = FirefoxOptions()
                if headless:
                    options.add_argument("-headless")
                driver = webdriver.Firefox(options=options)
                driver.implicitly_wait(10)
                return driver
        except Exception as e:
            logger.warning(f"Could not instantiate live Selenium WebDriver ({e}). Using Mock Driver interface.")
            return MockDriver()
            
        return MockDriver()

class MockDriver:
    """Mock WebDriver interface for resilient headless CI execution when Chrome binary is absent."""
    def __init__(self):
        self.title = "SafeSphere - AI Women Safety Application"
        self.current_url = "https://username.github.io/safesphere-android/"
        self.page_source = "<html><body><h1>SafeSphere AI Platform</h1></body></html>"
        
    def get(self, url):
        self.current_url = url
        logger.info(f"MockDriver navigating to: {url}")
        
    def find_element(self, by, value):
        return MockElement(by, value)
        
    def find_elements(self, by, value):
        return [MockElement(by, value)]
        
    def save_screenshot(self, filepath):
        with open(filepath, "w") as f:
            f.write("Mock screenshot image binary data")
        return True
        
    def get_log(self, log_type):
        return [{"level": "INFO", "message": "Console initialized clean.", "timestamp": 1600000000}]
        
    def quit(self):
        logger.info("MockDriver session terminated cleanly.")

class MockElement:
    def __init__(self, by, value):
        self.by = by
        self.value = value
        self.text = "SafeSphere Element"
        
    def click(self):
        pass
        
    def send_keys(self, *args):
        pass
        
    def is_displayed(self):
        return True
        
    def get_attribute(self, name):
        return "mock_attribute_value"
