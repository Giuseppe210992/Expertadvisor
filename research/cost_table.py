"""Tabella dei costi per strumento (markdown) per il report."""
import warnings; warnings.filterwarnings("ignore")
import pandas as pd, numpy as np
from instruments import INSTR, swap_rates, RATES, DIV
from engine import load_bars, atr

# tassi indicativi "attuali" (2026, APPROSSIMATI: verificare sul broker)
NOW = {"USD": 3.75, "EUR": 2.0, "GBP": 3.75, "JPY": 0.75, "AUD": 3.6, "CAD": 2.25}

def swap_now(sym):
    s = INSTR[sym]; m = s["swap_markup"]; q = NOW.get(s["quote"], NOW["USD"]) / 100
    if s["kind"] == "fx":
        b = NOW[s["base"]] / 100
        return b - q - m, q - b - m
    dv = DIV.get(sym, 0.0)
    return -(q + m) + dv, q - m - dv

per = pd.read_csv("results/per_instrument_PROPOSTA.csv")
rows = []
for sym, sp in INSTR.items():
    h1, h4, d1 = load_bars(sym)
    a = atr(d1, 20).loc["2015":].median()
    px = d1["close"].loc["2015":].median()
    rt = sp["spread_avg"] + 2 * sp["slippage"] + 2 * sp["comm_frac"] * px   # round trip in prezzo
    r = per[per.label == sym].iloc[0] if (per.label == sym).any() else per.iloc[list(INSTR).index(sym)]
    sl19, ss19 = swap_rates(sym, 2019)
    sln, ssn = swap_now(sym)
    gross = r.gross_core + r.gross_ov
    costs = r.costs_exec - min(r.swap, 0)
    rows.append({
        "Strumento": sym,
        "Spread medio": f"{sp['spread_avg']/sp['point']:.1f} pt",
        "Spread max": f"{sp['spread_max']/sp['point']:.0f} pt",
        "Comm./lato": f"{sp['comm_frac']*1e5:.1f} per 100k" if sp["comm_frac"] else "0 (nello spread)",
        "Slippage/lato": f"{sp['slippage']/sp['point']:.1f} pt",
        "Round-trip % ATR D1": f"{rt/a*100:.1f}%",
        "Swap L/S 2019 (%/anno)": f"{sl19*100:+.1f} / {ss19*100:+.1f}",
        "Swap L/S oggi* (%/anno)": f"{sln*100:+.1f} / {ssn*100:+.1f}",
        "Hedge: costo swap (%/anno)": f"{(sln+ssn)*100:+.1f}",
        "Costi esecuzione strategia": f"{r.costs_exec:,.0f}",
        "Swap strategia": f"{r.swap:,.0f}",
        "Lordo/costi": f"{gross/costs:.2f}" if costs > 0 else "n/d",
        "Netto": f"{r.net_profit:,.0f}",
    })
df = pd.DataFrame(rows)
md = df.to_markdown(index=False)
open("results/cost_table.md", "w").write(md)
print(md)
