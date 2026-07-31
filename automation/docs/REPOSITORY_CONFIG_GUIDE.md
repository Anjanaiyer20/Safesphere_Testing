# SafeSphere GitHub Repository & Pages Configuration Guide

This guide describes how to configure your GitHub repository to enable automatic GitHub Pages deployment and live E2E test execution.

---

## 1. Enabling GitHub Pages

1. Navigate to your repository on GitHub: `https://github.com/<username>/<repository>`
2. Click **Settings** -> **Pages** (in the left sidebar).
3. Under **Build and deployment**:
   - **Source**: Select `Deploy from a branch` (or `GitHub Actions`).
   - **Branch**: Select `gh-pages` / `/ (root)`.
4. Click **Save**.

---

## 2. GitHub Actions Workflow Permissions

1. Navigate to **Settings** -> **Actions** -> **General**.
2. Scroll to **Workflow permissions**.
3. Select **Read and write permissions**.
4. Check **Allow GitHub Actions to create and approve pull requests**.
5. Click **Save**.

---

## 3. Required Secrets & Variables (Optional)

If your environment uses custom staging endpoints, configure environment variables in **Settings** -> **Secrets and variables** -> **Actions**:
- `BASE_URL`: Optional override for deployment testing target URL.
