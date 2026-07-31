import os
from datetime import datetime
from .logger import AutomationLogger

logger = AutomationLogger.get_logger()

class ScreenshotUtility:
    """Screenshot capture helper for Selenium WebDriver & E2E tests."""
    
    @staticmethod
    def capture_screenshot(driver, test_id, name="snapshot", directory="automation/screenshots"):
        os.makedirs(directory, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        filename = f"{test_id}_{name}_{timestamp}.png"
        filepath = os.path.join(directory, filename)
        
        try:
            if driver:
                driver.save_screenshot(filepath)
                logger.info(f"Screenshot captured for [{test_id}]: {filepath}")
                return filepath
        except Exception as e:
            logger.warning(f"Could not capture screenshot for [{test_id}]: {str(e)}")
            
        # Fallback dummy file creation if driver is not present or headless mock
        try:
            with open(filepath, "w") as f:
                f.write(f"Mock screenshot artifact for test {test_id} at {timestamp}")
            return filepath
        except Exception as e:
            logger.error(f"Failed to create fallback screenshot: {str(e)}")
            return ""
