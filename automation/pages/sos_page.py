from selenium.webdriver.common.by import By
from .base_page import BasePage

class SOSPage(BasePage):
    """Page Object for SafeSphere Emergency SOS & Siren Dispatch System."""
    
    SOS_TRIGGER_BTN = (By.ID, "sos-panic-button")
    SILENT_ALERT_BTN = (By.ID, "silent-alert-button")
    SIREN_TOGGLE_BTN = (By.ID, "siren-toggle-button")
    CANCEL_SOS_BTN = (By.ID, "cancel-sos-button")
    AUDIO_RECORDING_INDICATOR = (By.ID, "audio-recording-active")
    BROADCAST_STATUS_BADGE = (By.ID, "broadcast-status")
    
    def trigger_sos(self):
        self.click(*self.SOS_TRIGGER_BTN)
        
    def trigger_silent_alert(self):
        self.click(*self.SILENT_ALERT_BTN)
        
    def cancel_sos(self, pin="1234"):
        self.click(*self.CANCEL_SOS_BTN)
