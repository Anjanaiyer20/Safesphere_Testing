# SafeSphere CI/CD Execution Guide

This document details the architecture and trigger workflows for the automated GitHub Actions CI/CD pipeline (`.github/workflows/deploy-and-test.yml`).

---

## 1. Pipeline Architecture

The pipeline executes automatically across 13 stages on every push, pull request, or manual invocation (`workflow_dispatch`).

```
[1. Checkout] ➔ [2. Setup Dependencies] ➔ [3. Build Flutter Web] ➔ [4. Static Analysis]
     │
     ▼
[5. Deploy to GitHub Pages] ➔ [6. Wait DNS Propagation] ➔ [7. Health Verification]
     │
     ▼
[8. Run 1,200 Multi-Suite Tests] ➔ [9. HTML Reports] ➔ [10. Excel Reports]
     │
     ▼
[11. Upload Artifacts (30d)] ➔ [12. Publish Summary] ➔ [13. Archive History]
```

---

## 2. Environment Variables & Overrides

| Variable Name | Description | Default / Pipeline Value |
| :--- | :--- | :--- |
| `BASE_URL` | Live Target URL for E2E tests | `https://<owner>.github.io/<repo>/` |
| `HEADLESS` | Run Chrome in Headless Mode | `"true"` |
| `IMPLICIT_WAIT` | Selenium implicit timeout in seconds | `10` |
| `EXPLICIT_WAIT` | Selenium explicit timeout in seconds | `15` |

---

## 3. GitHub Actions Artifacts Retention

- **Retention Period**: 30 Days
- **Artifact Bundle**: `SafeSphere-E2E-Automation-Artifacts`
- **Contents**: All Excel workbooks, HTML interactive dashboards, JSON results, execution logs, and captured screenshots.
