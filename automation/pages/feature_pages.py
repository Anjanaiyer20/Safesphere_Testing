from selenium.webdriver.common.by import By
from .base_page import BasePage

class LocationPage(BasePage):
    """Page Object for Real-time GPS Tracking, Safe Zones, and Geofencing."""
    GPS_STATUS = (By.ID, "gps-status-indicator")
    SHARE_LIVE_LOCATION_BTN = (By.ID, "share-location-btn")
    SAFE_ZONE_MARKER = (By.CLASS_NAME, "safe-zone-marker")
    GEOFENCE_ALERT_BANNER = (By.ID, "geofence-alert")

class RoutePage(BasePage):
    """Page Object for AI Risk Score Safe Routing & Lit Path Selector."""
    ORIGIN_INPUT = (By.ID, "route-origin")
    DESTINATION_INPUT = (By.ID, "route-destination")
    CALCULATE_SAFE_ROUTE_BTN = (By.ID, "calc-safe-route-btn")
    LIT_PATH_TOGGLE = (By.ID, "lit-path-toggle")
    RISK_SCORE_CARD = (By.ID, "risk-score-card")

class ContactsPage(BasePage):
    """Page Object for Emergency Contacts & Guardian Management."""
    ADD_CONTACT_BTN = (By.ID, "add-contact-btn")
    CONTACT_NAME_INPUT = (By.ID, "contact-name")
    CONTACT_PHONE_INPUT = (By.ID, "contact-phone")
    IMPORT_CONTACTS_BTN = (By.ID, "import-contacts")

class IncidentsPage(BasePage):
    """Page Object for Community Incident Reports & Evidence Media."""
    REPORT_INCIDENT_BTN = (By.ID, "report-incident-btn")
    INCIDENT_TYPE_SELECT = (By.ID, "incident-type")
    DESCRIPTION_AREA = (By.ID, "incident-desc")
    ATTACH_AUDIO_BTN = (By.ID, "attach-audio")

class ProfilePage(BasePage):
    """Page Object for User Settings, Medical ID, and Privacy Controls."""
    MEDICAL_ID_TAB = (By.ID, "tab-medical-id")
    BLOOD_TYPE_INPUT = (By.ID, "blood-type")
    EMERGENCY_NOTES = (By.ID, "medical-notes")
    BIOMETRIC_TOGGLE = (By.ID, "biometric-lock-toggle")
