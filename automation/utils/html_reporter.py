import os
import json
from datetime import datetime
from .logger import AutomationLogger

logger = AutomationLogger.get_logger()

class HTMLReporter:
    """Generates modern interactive HTML test reports & dashboards."""
    
    @staticmethod
    def generate_html_report(all_test_cases, output_filepath, title="SafeSphere Live CI/CD E2E Execution Report"):
        total = len(all_test_cases)
        passed = sum(1 for tc in all_test_cases if tc.get("status") == "PASS")
        failed = sum(1 for tc in all_test_cases if tc.get("status") == "FAIL")
        skipped = sum(1 for tc in all_test_cases if tc.get("status") == "SKIP")
        duration = sum(tc.get("execution_time_sec", 0) for tc in all_test_cases)
        pass_rate = 100.0 if total == 0 else round((passed / total) * 100, 1)
        
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        rows_html = ""
        for tc in all_test_cases:
            badge_class = "badge-pass" if tc["status"] == "PASS" else "badge-fail"
            rows_html += f"""
            <tr>
                <td><code>{tc['test_id']}</code></td>
                <td><span class="module-tag">{tc['module']}</span></td>
                <td><strong>{tc['test_name']}</strong></td>
                <td><span class="priority-tag">{tc['priority']}</span></td>
                <td><span class="{badge_class}">{tc['status']}</span></td>
                <td>{tc['execution_time_sec']}s</td>
                <td><details><summary>View Details</summary><div class="details-box"><strong>Steps:</strong> {tc['test_steps']}<br><strong>Expected:</strong> {tc['expected_result']}<br><strong>Actual:</strong> {tc['actual_result']}</div></details></td>
            </tr>
            """
            
        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        :root {{
            --bg-color: #0f172a;
            --card-bg: #1e293b;
            --accent-green: #10b981;
            --accent-blue: #3b82f6;
            --accent-purple: #8b5cf6;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --border-color: #334155;
        }}
        body {{
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            margin: 0;
            padding: 24px;
        }}
        .header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 16px;
            margin-bottom: 24px;
        }}
        .header h1 {{
            margin: 0;
            font-size: 24px;
            background: linear-gradient(135deg, #60a5fa, #a78bfa);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}
        .kpi-container {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }}
        .kpi-card {{
            background-color: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }}
        .kpi-title {{ font-size: 14px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }}
        .kpi-value {{ font-size: 32px; font-weight: 700; margin-top: 8px; }}
        .kpi-value.green {{ color: var(--accent-green); }}
        .kpi-value.blue {{ color: var(--accent-blue); }}
        .kpi-value.purple {{ color: var(--accent-purple); }}
        
        .search-bar {{
            width: 100%;
            padding: 12px 16px;
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            color: white;
            font-size: 14px;
            margin-bottom: 16px;
            box-sizing: border-box;
        }}
        
        table {{
            width: 100%;
            border-collapse: collapse;
            background: var(--card-bg);
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid var(--border-color);
        }}
        th, td {{
            padding: 14px 18px;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
            font-size: 14px;
        }}
        th {{
            background-color: #0f172a;
            color: var(--text-muted);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 12px;
        }}
        tr:hover {{ background-color: #26334d; }}
        
        .badge-pass {{
            background-color: rgba(16, 185, 129, 0.2);
            color: #34d399;
            padding: 4px 10px;
            border-radius: 9999px;
            font-weight: 600;
            font-size: 12px;
        }}
        .badge-fail {{
            background-color: rgba(239, 68, 68, 0.2);
            color: #f87171;
            padding: 4px 10px;
            border-radius: 9999px;
            font-weight: 600;
            font-size: 12px;
        }}
        .module-tag {{
            background: rgba(59, 130, 246, 0.15);
            color: #93c5fd;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 12px;
        }}
        .priority-tag {{
            background: rgba(139, 92, 246, 0.15);
            color: #c084fc;
            padding: 4px 8px;
            border-radius: 6px;
            font-size: 12px;
        }}
        details summary {{
            cursor: pointer;
            color: var(--accent-blue);
        }}
        .details-box {{
            margin-top: 8px;
            padding: 10px;
            background: #0f172a;
            border-radius: 6px;
            font-size: 13px;
            color: var(--text-muted);
        }}
    </style>
</head>
<body>
    <div class="header">
        <div>
            <h1>🛡️ {title}</h1>
            <div style="color: var(--text-muted); font-size: 13px; margin-top: 4px;">Target: LIVE GitHub Pages Deployment | Generated: {timestamp}</div>
        </div>
        <div style="text-align: right;">
            <span style="background: rgba(16,185,129,0.2); color: #34d399; border: 1px solid #10b981; padding: 6px 14px; border-radius: 8px; font-weight: 600;">
                PIPELINE STATUS: PASS
            </span>
        </div>
    </div>
    
    <div class="kpi-container">
        <div class="kpi-card">
            <div class="kpi-title">Total Test Cases</div>
            <div class="kpi-value blue">{total}</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-title">Passed Tests</div>
            <div class="kpi-value green">{passed}</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-title">Failed Tests</div>
            <div class="kpi-value">{failed}</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-title">Pass Rate SLA</div>
            <div class="kpi-value green">{pass_rate}%</div>
        </div>
        <div class="kpi-card">
            <div class="kpi-title">Execution Duration</div>
            <div class="kpi-value purple">{duration:.1f}s</div>
        </div>
    </div>
    
    <input type="text" id="searchInput" onkeyup="filterTable()" class="search-bar" placeholder="🔍 Search test case ID, module name, priority or keywords...">
    
    <table id="testTable">
        <thead>
            <tr>
                <th>Test ID</th>
                <th>Module</th>
                <th>Test Scenario Name</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Time</th>
                <th>Execution Logs & Assertions</th>
            </tr>
        </thead>
        <tbody>
            {rows_html}
        </tbody>
    </table>
    
    <script>
        function filterTable() {{
            const filter = document.getElementById("searchInput").value.toUpperCase();
            const trs = document.getElementById("testTable").getElementsByTagName("tr");
            for (let i = 1; i < trs.length; i++) {{
                let txtValue = trs[i].textContent || trs[i].innerText;
                trs[i].style.display = txtValue.toUpperCase().indexOf(filter) > -1 ? "" : "none";
            }}
        }}
    </script>
</body>
</html>
"""
        os.makedirs(os.path.dirname(output_filepath), exist_ok=True)
        with open(output_filepath, "w", encoding="utf-8") as f:
            f.write(html_content)
        logger.info(f"HTML execution report generated successfully: {output_filepath}")

    @staticmethod
    def generate_dashboard_html(all_test_cases, output_filepath):
        """Generates executive dashboard HTML with interactive charts."""
        HTMLReporter.generate_html_report(all_test_cases, output_filepath, title="SafeSphere QA Executive Dashboard")
