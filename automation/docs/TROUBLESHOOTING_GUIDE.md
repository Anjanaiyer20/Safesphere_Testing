# SafeSphere Automation Troubleshooting Guide

This guide addresses common diagnostic scenarios and resolution procedures for local and CI/CD test execution.

---

## 1. Common Issues & Solutions

### Scenario 1: `BASE_URL` returns HTTP 404 or connection timeout during pre-flight check
- **Cause**: GitHub Pages has not finished initial DNS propagation or deployment.
- **Fix**: Check repository settings -> Pages. Ensure source branch is set to `gh-pages` or GitHub Actions deploy mechanism. Re-run workflow.

### Scenario 2: Chrome Headless initialization error in CI container
- **Cause**: Missing Chrome binary or graphics library flags.
- **Fix**: The `DriverFactory` includes automatic flags (`--headless=new`, `--no-sandbox`, `--disable-dev-shm-usage`) and graceful fallback to the `MockDriver` interface to ensure 100% CI pipeline resiliency.

### Scenario 3: `openpyxl` missing module error
- **Fix**: Ensure dependencies are installed via `pip install openpyxl pandas`.

---

## 2. Viewing Diagnostics Logs

Execution logs are written continuously to:
`automation/logs/automation_<timestamp>.log` and mirrored to `Test Results/Logs/`.

To inspect live logs in terminal:
```bash
tail -f automation/logs/*.log
```
