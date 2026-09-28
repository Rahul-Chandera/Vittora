#!/usr/bin/env python3
"""Write index.json and README.md next to the marketing screenshots.

Built from the files actually on disk, so the index can never list a screen that
was not captured. Each entry says what the screen shows, in words an AI agent
(or a person) can pick from without opening every image.

Usage: index_marketing_screenshots.py <screenshots-root>
"""
import json
import os
import re
import sys

from PIL import Image

ROOT = sys.argv[1]

# "<NN>-<area>-<screen>" -> what the screen shows. Keyed without platform and
# appearance, which the file name already carries.
DESCRIPTIONS = {
    "01-dashboard-overview": "Home dashboard: this month's spending vs income, savings rate, overall budget progress, quick actions and recent transactions.",
    "02-dashboard-insights-and-recent-activity": "Dashboard scrolled: recent transactions, top spending categories donut, account balances, net worth and upcoming bills.",
    "03-transactions-list": "Transaction list grouped by day, with category icons, payees and search.",
    "03-transactions-list-and-detail": "Transactions list with a selected transaction's details alongside (Mac split view).",
    "04-transactions-detail": "A single transaction: amount, category, account, payment method and similar past transactions.",
    "05-transactions-add-expense-form": "Adding an expense: amount entry, expense/income switch, category, account, payee, date and notes.",
    "06-budgets-monthly-budgets": "Monthly budgets: total budget progress and per-category budgets with spent and remaining.",
    "07-budgets-budget-detail": "One budget in detail: progress ring, amount, spent, remaining and daily spending.",
    "08-budgets-household-shared-budgets": "Household sharing: a shared Groceries budget, members and their permissions (owner, can edit, view only).",
    "09-budgets-household-spending-by-member": "Shared household budget: this month's spending split by member, and each member's expenses.",
    "10-reports-all-reports": "Reports hub: this month's spending and income, personalised 'worth a look' insights, and every report.",
    "11-reports-monthly-overview": "Monthly Overview report: 12-month income vs expense chart and month-by-month breakdown.",
    "12-reports-category-breakdown": "Category Breakdown report: spending by category donut with percentages.",
    "13-reports-spending-trends": "Spending Trends report: daily spending trend line with total, average and peak.",
    "14-reports-cash-flow": "Cash Flow report: monthly net cash flow bars with a 6-month projection.",
    "15-reports-cash-flow-forecast": "Cash Flow Forecast: projected balance for the next 30 and 90 days.",
    "16-reports-annual-summary": "Annual Summary: yearly income vs expenses by month and totals.",
    "17-reports-net-worth-history": "Net Worth: assets, liabilities and net worth over time.",
    "18-reports-subscription-audit": "Subscription Audit: every recurring charge with monthly and annual cost.",
    "19-reports-50-30-20-budget-rule": "50/30/20 guideline: needs, wants and savings against the recommended split.",
    "20-reports-emergency-fund": "Emergency Fund: months of essential spending covered, with 3- and 6-month targets.",
    "21-reports-financial-health-score": "Financial Health Score out of 100: budget adherence, debt level and savings rate.",
    "22-reports-spending-outlook-and-what-if": "Spending Outlook: this month's projected spending, plus a what-if slider for cutting a category.",
    "23-reports-year-in-review": "Year in Review ('Vittora Wrapped'): total spent, monthly bars and top categories — shareable.",
    "24-reports-custom-report-builder": "Custom Report builder: pick date range, grouping and type; results by category.",
    "30-savings-goals": "Savings goals with progress rings and overall progress.",
    "31-savings-goal-detail": "One savings goal: amount saved, target, remaining and adding a contribution.",
    "32-debt-ledger": "Debt ledger: what friends owe you and what you owe them, with net position.",
    "33-debt-analytics": "Debt analytics: how long debts have been open, exposure by person and settle speed.",
    "34-debt-person-detail": "Debts with one person: owed each way, net, and history with settle and remind.",
    "35-splits-groups": "Split expense groups with totals and members.",
    "36-splits-group-detail-balances": "A split group: who owes whom, settle-up suggestion and outstanding expenses.",
    "37-tax-estimator": "Tax Estimator (US): estimated federal tax, effective and marginal rate, bracket distribution.",
    "38-tax-bracket-breakdown": "Tax bracket breakdown: income, deductions, tax per bracket and payroll lines.",
    "40-recurring-bills-and-subscriptions": "Recurring transactions: monthly spend on bills and subscriptions, with upcoming dates.",
    "41-recurring-bill-detail": "A recurring bill: amount, schedule, next date, upcoming dates and the Lock Screen countdown option.",
    "42-accounts-list": "Accounts: net worth card, cash, bank and credit card balances.",
    "43-accounts-account-detail": "An account: current balance, details and recent transactions.",
    "44-categories-list": "Spending categories with icons and colours.",
    "45-payees-list": "Payees: people and businesses you transact with.",
    "50-shopping-mode-start-with-budget": "Shopping Mode: start a live shopping session that counts against a budget.",
    "51-shopping-mode-running-total-and-budget-left": "Shopping Mode running: live total, items and how much of the budget is left.",
    "52-live-activities-shopping-total-in-dynamic-island": "Live Activity: the shopping total live in the Dynamic Island (cropped to the top of the screen).",
    "60-settings-overview": "Settings: profile, Vittora Pro, preferences and data management.",
    "61-settings-appearance-and-themes": "Appearance: light, dark and OLED black themes, accent colours and a live preview.",
    "62-settings-app-lock-and-privacy": "Security: App Lock with Face ID or passcode.",
    "63-settings-export-and-backup": "Manage Data: record counts, CSV export and automatic export.",
    "64-settings-notifications": "Notifications settings for bill reminders and budget alerts.",
    "70-pro-paywall": "Vittora Pro: Pro features and yearly (7-day free trial), monthly and lifetime plans.",
    "71-onboarding-welcome": "Welcome screen: Vittora's promise and core features.",
    # Apple Watch (always dark — watchOS has no light appearance)
    "01-watch-dashboard-today-and-budget-left": "Apple Watch: today's spending, budget left and recent transactions.",
    "02-watch-recent-transactions": "Apple Watch: recent transactions with categories.",
    "03-watch-quick-expense-digital-crown": "Apple Watch: quick expense entry — turn the Digital Crown to set the amount.",
    "04-watch-voice-entry-say-it": "Apple Watch voice entry: 'Add 42.50 for groceries' parsed into $42.50 and the Groceries category.",
}

NAME = re.compile(r"^(iphone|ipad|mac|watch)-(light|dark)-(\d\d-.+)\.png$")
WATCH = re.compile(r"^watch-[a-z0-9-]+?-(dashboard|recent|quick-expense|voice)\.png$")

entries = []
for dirpath, _, files in os.walk(ROOT):
    for name in sorted(files):
        if not name.endswith(".png"):
            continue
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, ROOT)
        m = NAME.match(name)
        if m:
            platform, appearance, key = m.groups()
            number, area, screen = key.split("-", 2)
        else:
            w = WATCH.match(name)
            if not w:
                continue
            platform, appearance = "watch", "dark"
            key = f"watch-{w.group(1)}"
            number, area, screen = "", "watch", w.group(1)
        with Image.open(path) as im:
            size = im.size
        entries.append({
            "file": rel,
            "platform": platform,
            "appearance": appearance,
            "feature_area": area,
            "screen": screen,
            "order": number,
            "size_px": list(size),
            "description": DESCRIPTIONS.get(key, ""),
        })

entries.sort(key=lambda e: (e["platform"], e["appearance"], e["order"], e["file"]))
with open(os.path.join(ROOT, "index.json"), "w") as f:
    json.dump({
        "app": "Vittora — private personal finance for iPhone, iPad, Mac and Apple Watch",
        "data": "Demo showcase data (US region, USD, en_US). No real user data.",
        "naming": "<platform>-<appearance>-<NN>-<feature-area>-<screen>.png; NN orders screens by product area",
        "screenshots": entries,
    }, f, indent=2)

missing = sorted({e["file"] for e in entries if not e["description"]})
lines = [
    "# Vittora marketing screenshots",
    "",
    "Demo showcase data — US region, **USD**, en_US. No real user data.",
    "",
    "**File names:** `<platform>-<appearance>-<NN>-<feature-area>-<screen>.png` —",
    "e.g. `iphone-dark-08-budgets-household-shared-budgets.png`. `NN` orders screens by",
    "product area. `index.json` has the same list with a description of every screen.",
    "",
    "| Folder | Screens |",
    "|---|---|",
]
for folder in sorted({os.path.dirname(e["file"]) for e in entries}):
    lines.append(f"| `{folder}` | {sum(1 for e in entries if os.path.dirname(e['file']) == folder)} |")
lines += ["", "## Screens", "", "| # | Area | Screen | What it shows |", "|---|---|---|---|"]
seen = set()
for e in entries:
    k = (e["order"], e["feature_area"], e["screen"])
    if k in seen:
        continue
    seen.add(k)
    lines.append(f"| {e['order']} | {e['feature_area']} | {e['screen']} | {e['description']} |")
with open(os.path.join(ROOT, "README.md"), "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"{len(entries)} screenshots indexed; {len(missing)} without a description")
for m in missing:
    print("  no description:", m)
