"""
Reproducible funnel demo (SYNTHETIC data).

The queries in ../sql run against the real BigQuery public GA4 dataset
(bigquery-public-data.ga4_obfuscated_sample_ecommerce). This script reproduces the
SAME session-level funnel logic on a small, SYNTHETIC GA4-shaped dataset so the
analysis runs end-to-end anywhere -- no BigQuery account required -- and generates
the chart in ../images.

The numbers produced here are ILLUSTRATIVE (synthetic), not the real Google
Merchandise Store figures. To get the real numbers, run ../sql/03_funnel_conversion_rates.sql
in the BigQuery sandbox (free) and drop the output into the README.

Usage:
    pip install -r ../requirements.txt
    python funnel_demo.py
"""

import os
import numpy as np
import pandas as pd
import duckdb
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA_DIR = os.path.join(ROOT, "data")
IMG_DIR = os.path.join(ROOT, "images")
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(IMG_DIR, exist_ok=True)

RNG = np.random.default_rng(42)          # fixed seed => reproducible output
N_SESSIONS = 20_000

# ---------------------------------------------------------------------------
# 1. Generate a synthetic, GA4-shaped event stream.
#    One row per event, with the columns we actually use in the funnel logic.
# ---------------------------------------------------------------------------
devices = RNG.choice(
    ["desktop", "mobile", "tablet"], size=N_SESSIONS, p=[0.55, 0.40, 0.05]
)
sources = RNG.choice(
    ["google", "(direct)", "youtube.com", "(data deleted)", "bing"],
    size=N_SESSIONS, p=[0.45, 0.30, 0.12, 0.10, 0.03],
)

rows = []
for i in range(N_SESSIONS):
    upid = f"user_{RNG.integers(0, 12_000)}"
    sid = 1_000_000 + i
    dev = devices[i]
    src = sources[i]

    def emit(event_name):
        rows.append((upid, sid, dev, src, event_name))

    emit("session_start")
    # Funnel with realistic, device-dependent drop-off.
    if RNG.random() < 0.72:
        emit("view_item")
        p_cart = 0.34 if dev != "mobile" else 0.26
        if RNG.random() < p_cart:
            emit("add_to_cart")
            if RNG.random() < 0.55:
                emit("begin_checkout")
                p_buy = 0.62 if dev == "desktop" else 0.50
                if RNG.random() < p_buy:
                    emit("purchase")

events = pd.DataFrame(
    rows, columns=["user_pseudo_id", "session_id", "device_category", "source", "event_name"]
)
print(f"Generated {len(events):,} synthetic events across {N_SESSIONS:,} sessions.\n")

# ---------------------------------------------------------------------------
# 2. Run the funnel logic in SQL (DuckDB) -- mirrors ../sql/03.
# ---------------------------------------------------------------------------
con = duckdb.connect()
con.register("events", events)

session_flags = """
CREATE TEMP TABLE sessions AS
SELECT
    user_pseudo_id,
    session_id,
    device_category,
    MAX(CASE WHEN event_name = 'view_item'      THEN 1 ELSE 0 END) AS viewed_item,
    MAX(CASE WHEN event_name = 'add_to_cart'    THEN 1 ELSE 0 END) AS added_to_cart,
    MAX(CASE WHEN event_name = 'begin_checkout' THEN 1 ELSE 0 END) AS began_checkout,
    MAX(CASE WHEN event_name = 'purchase'       THEN 1 ELSE 0 END) AS purchased
FROM events
GROUP BY user_pseudo_id, session_id, device_category;
"""
con.execute(session_flags)

totals = con.execute("""
SELECT
    SUM(viewed_item)    AS view_item,
    SUM(added_to_cart)  AS add_to_cart,
    SUM(began_checkout) AS begin_checkout,
    SUM(purchased)      AS purchase
FROM sessions
""").df().iloc[0]

# Tidy stage table with step + cumulative conversion.
stages = ["view_item", "add_to_cart", "begin_checkout", "purchase"]
labels = ["View item", "Add to cart", "Begin checkout", "Purchase"]
counts = [int(totals[s]) for s in stages]

funnel = pd.DataFrame({"stage": labels, "sessions": counts})
funnel["pct_of_view_item"] = (funnel["sessions"] / counts[0] * 100).round(2)
funnel["step_conversion_pct"] = (
    funnel["sessions"] / funnel["sessions"].shift(1) * 100
).round(2)
funnel.loc[0, "step_conversion_pct"] = 100.0

funnel.to_csv(os.path.join(DATA_DIR, "funnel_results.csv"), index=False)

# Device breakdown.
by_device = con.execute("""
SELECT
    device_category,
    SUM(viewed_item) AS view_item,
    SUM(purchased)   AS purchase,
    ROUND(SUM(purchased) * 100.0 / NULLIF(SUM(viewed_item), 0), 2) AS overall_conversion_pct
FROM sessions
GROUP BY device_category
ORDER BY view_item DESC
""").df()
by_device.to_csv(os.path.join(DATA_DIR, "funnel_by_device.csv"), index=False)

print("Funnel (synthetic):")
print(funnel.to_string(index=False))
print("\nBy device (synthetic):")
print(by_device.to_string(index=False))

# ---------------------------------------------------------------------------
# 3. Chart the funnel.
# ---------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5))
bars = ax.barh(funnel["stage"][::-1], funnel["sessions"][::-1], color="#2E75B6")
ax.set_xlabel("Sessions reaching stage")
ax.set_title("GA4 E-commerce Purchase Funnel (synthetic demo data)", fontweight="bold")

max_c = counts[0]
for bar, (_, r) in zip(bars, funnel[::-1].iterrows()):
    ax.text(
        bar.get_width() + max_c * 0.01,
        bar.get_y() + bar.get_height() / 2,
        f"{int(r['sessions']):,}  ({r['pct_of_view_item']:.1f}% of top)",
        va="center", fontsize=10,
    )
ax.set_xlim(0, max_c * 1.25)
ax.margins(y=0.05)
plt.tight_layout()
out_png = os.path.join(IMG_DIR, "funnel_chart.png")
plt.savefig(out_png, dpi=140)
print(f"\nSaved chart -> {out_png}")
print("Saved tables -> data/funnel_results.csv, data/funnel_by_device.csv")
