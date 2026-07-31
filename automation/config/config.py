import os
import json

class Config:
    """Central configuration manager for SafeSphere Automation Suite."""
    
    BASE_URL = os.getenv("BASE_URL", "https://Anjanaiyer20.github.io/Safesphere_Testing/").rstrip('/') + '/'
    HEADLESS = os.getenv("HEADLESS", "true").lower() == "true"
    BROWSER = os.getenv("BROWSER", "chrome").lower()
    IMPLICIT_WAIT = int(os.getenv("IMPLICIT_WAIT", "10"))
    EXPLICIT_WAIT = int(os.getenv("EXPLICIT_WAIT", "15"))
    
    # Credentials from Environment Variables (Never hardcoded or logged)
    TEST_USER_EMAIL = os.getenv("TEST_USER_EMAIL", "env_user@safesphere.internal")
    TEST_USER_PASSWORD = os.getenv("TEST_USER_PASSWORD", "env_secret_password")
    
    SCREENSHOT_DIR = os.getenv("SCREENSHOT_DIR", os.path.abspath("automation/screenshots"))
    LOG_DIR = os.getenv("LOG_DIR", os.path.abspath("automation/logs"))
    REPORT_DIR = os.getenv("REPORT_DIR", os.path.abspath("automation/reports"))
    
    @classmethod
    def get_setting(cls, key, default=None):
        settings_path = os.path.join(os.path.dirname(__file__), "settings.json")
        if os.path.exists(settings_path):
            with open(settings_path, 'r') as f:
                data = json.load(f)
                return data.get(key, default)
        return default
