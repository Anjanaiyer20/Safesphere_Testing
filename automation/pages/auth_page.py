from selenium.webdriver.common.by import By
from .base_page import BasePage

class AuthPage(BasePage):
    """Page Object for SafeSphere Authentication & Session Management."""
    
    USERNAME_INPUT = (By.ID, "username-input")
    PASSWORD_INPUT = (By.ID, "password-input")
    LOGIN_BTN = (By.ID, "login-button")
    REGISTER_BTN = (By.ID, "register-button")
    FORGOT_PASSWORD_LINK = (By.ID, "forgot-password")
    MFA_CODE_INPUT = (By.ID, "mfa-code")
    LOGOUT_BTN = (By.ID, "logout-button")
    
    def perform_login(self, username, password):
        self.send_keys(*self.USERNAME_INPUT, username)
        self.send_keys(*self.PASSWORD_INPUT, password)
        self.click(*self.LOGIN_BTN)
        
    def perform_logout(self):
        self.click(*self.LOGOUT_BTN)
