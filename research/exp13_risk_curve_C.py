"""
Esperimento 13: curva rischio -> rendimento -> rovina della variante C CONGELATA (dati 2005-2020, in-sample).
Stessi trade della ricerca; cambia solo la frazione di capitale rischiata per trade.
Universo: i 6 strumenti della lista di validazione presenti nel dataset (USDJPY non disponibile) + EURUSD da solo.
La stessa curva va ricalcolata sui trade OOS 2020-2026 (validation/analyze_mt5.py --risk-curve).
"""
import sys, os, warnings
warnings.filterwarnings("ignore")
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "validation"))
import pandas as pd
from dataclasses import replace
from multiprocessing import Pool
from engine import run, P
from risk_curve import curve, to_markdown

C = replace(P(), n_ov=120, n_ov_exit=60, k_ov_stop=4.0, ov_against="short_core", hedge_mode="net", edge_n=20,
            day_tp_atr=0.5, compound=False)
SYMS = ["EUR_USD", "GBP_USD", "XAU_USD", "NAS100_USD", "SPX500_USD", "WTICO_USD"]


def entries(sym):
    tr = run(sym, C, capital=100_000.0)["trades"]
    g = tr.groupby("leg_id").agg(net=("net", "sum"), risk=("risk0", "first"), t_out=("t_out", "max"), kind=("kind", "first"))
    g["R"] = g.net / g.risk
    g["sym"] = sym
    return g.reset_index(drop=True)


if __name__ == "__main__":
    with Pool(4) as p:
        T = pd.concat(p.map(entries, SYMS), ignore_index=True)
    out = []
    for name, sub in [("Portafoglio 6 strumenti", T), ("Solo EURUSD", T[T.sym == "EUR_USD"])]:
        print(f"\n## {name}: {len(sub)} ingressi, R medio {sub.R.mean():+.3f}, "
              f"{len(sub) / ((sub.t_out.max() - sub.t_out.min()).days / 365.25):.0f} ingressi/anno\n")
        df = curve(sub[["t_out", "R"]])
        df.insert(0, "universo", name)
        out.append(df)
        print(to_markdown(df.drop(columns="universo")))
    pd.concat(out).to_csv("results/exp13_risk_curve_C.csv", index=False)
