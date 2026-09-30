"""Costi prodotti dalla strategia, per strumento e variante (rischio 1% per sleeve di 100k, 2005-2020)."""
import pandas as pd
from instruments import INSTR
out = []
for lab, f in [("B", "results/per_instrument_PROPOSTA.csv"), ("C", "results/per_instrument_HARVEST.csv")]:
    d = pd.read_csv(f)
    if "sym" not in d: d["sym"] = list(INSTR)   # stesso ordine di esecuzione degli esperimenti
    for _, r in d.iterrows():
        days = r.years * 252
        gross = r.gross_core + r.gross_ov
        costs = r.costs_exec - min(r.swap, 0)
        out.append({"Var.": lab, "Strumento": r.sym, "Trade": int(r.n_trades), "Spread": f"{r.spread:,.0f}",
                    "Commissioni": f"{r.comm:,.0f}", "Comm./giorno": f"{r.comm/days:.2f}", "Slippage": f"{r.slip:,.0f}",
                    "Swap": f"{r.swap:,.0f}", "Costo medio A+C": f"{r.costs_exec/max(r.n_trades,1):.1f}",
                    "Lordo": f"{gross:,.0f}", "Lordo/costi": f"{gross/costs:.2f}" if costs > 0 else "n/d",
                    "Netto": f"{r.net_profit:,.0f}"})
md = pd.DataFrame(out).to_markdown(index=False)
open("results/cost_table2.md", "w").write(md)
print(md)
