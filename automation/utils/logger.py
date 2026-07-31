import logging
import os
from datetime import datetime

class AutomationLogger:
    """Central Logger for SafeSphere Test Automation Suite."""
    _logger = None

    @classmethod
    def get_logger(cls, log_dir="automation/logs"):
        if cls._logger is None:
            os.makedirs(log_dir, exist_ok=True)
            log_file = os.path.join(log_dir, f"automation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
            
            logger = logging.getLogger("SafeSphereAutomation")
            logger.setLevel(logging.INFO)
            
            # File Handler
            fh = logging.FileHandler(log_file)
            fh.setLevel(logging.INFO)
            
            # Console Handler
            ch = logging.StreamHandler()
            ch.setLevel(logging.INFO)
            
            # Formatter
            formatter = logging.Formatter('[%(asctime)s] [%(levelname)s] [%(filename)s:%(lineno)d]: %(message)s')
            fh.setFormatter(formatter)
            ch.setFormatter(formatter)
            
            logger.addHandler(fh)
            logger.addHandler(ch)
            
            cls._logger = logger
        return cls._logger
