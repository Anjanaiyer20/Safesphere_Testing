# SafeSphere Local Test Automation Execution Guide

This guide explains how to execute the SafeSphere E2E, Appium, Vulnerability, and Load testing suites locally on your workstation.

---

## 1. Prerequisites

Ensure you have the following installed on your machine:
- **Python**: 3.9+ (Python 3.11 recommended)
- **Chrome Browser**: Latest stable version
- **ChromeDriver** / **Selenium**: (Managed automatically by Selenium Manager)
- **Flutter SDK**: (Required if building the Web target locally)

---

## 2. Environment Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/<username>/safesphere-android.git
   cd safesphere-android
   ```

2. **Set up Virtual Environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install Dependencies**:
   ```bash
   pip install --upgrade pip
   pip install selenium pandas openpyxl requests urllib3
   ```

---

## 3. Running the Test Suite Locally

### Execution against Live GitHub Pages Deployment (Default)
```bash
python automation/run_all_tests.py
```

### Execution against Custom Target URL (e.g. Local Server or Staging)
```bash
BASE_URL="http://localhost:8080/" HEADLESS="true" python automation/run_all_tests.py
```

---

## 4. Generated Artifacts Location

After execution completes, all generated artifacts are available in the project root:

```
Test Results/
├── Excel/
│   ├── Automation_Test_Report.xlsx      (Master Workbook with 6 Sheets)
│   ├── Selenium_Test_Report.xlsx        (300 Selenium Test Cases)
│   ├── Appium_Test_Report.xlsx          (300 Appium Test Cases)
│   ├── Vulnerability_Test_Report.xlsx   (300 Security Audit Test Cases)
│   ├── Load_Test_Report.xlsx            (300 Performance Test Cases)
│   ├── Passed_Test_Cases.xlsx
│   ├── Failed_Test_Cases.xlsx
│   └── Summary_Report.xlsx
│
├── HTML/
│   ├── execution-report.html            (Interactive Filterable Report)
│   └── dashboard.html                   (Executive Dashboard)
│
├── JSON/
│   └── execution-results.json           (Machine-readable Results)
│
├── Screenshots/                         (Execution Snapshots)
├── Logs/                                (Automation Execution Logs)
└── Summary/
    └── summary.md                       (Markdown Execution Summary)
```
