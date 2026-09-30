"""Esperimento 13b: sensibilita' della curva rischio/rendimento della variante C a un edge piu' piccolo.
Stessi trade di exp13 (portafoglio 6 strumenti); R traslati di una costante per avere edge pieno, dimezzato, nullo."""
import sys, os, warnings
warnings.filterwarnings("ignore")
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "validation"))
import numpy as np, pandas as pd
from multiprocessing import Pool
from exp13_risk_curve_C import entries, SYMS
from risk_curve import curve, to_markdown

if __name__ == "__main__":
    with Pool(4) as p:
        T = pd.concat(p.map(entries, SYMS), ignore_index=True)
    m, s = T.R.mean(), T.R.std()
    print(f"R per ingresso: media {m:+.4f}, dev. std {s:.3f}, asimmetria {T.R.skew():+.2f}, peggiore {T.R.min():+.2f}, "
          f"migliore {T.R.max():+.2f}")
    rows = []
    for lab, shift in [("edge pieno (in-sample)", 0.0), ("edge dimezzato", m / 2), ("edge nullo", m)]:
        R = T.R - shift
        kelly = R.mean() / (R ** 2).mean() if R.mean() > 0 else 0.0
        print(f"\n## {lab}: R medio {R.mean():+.4f}; rischio di Kelly (crescita massima) ~ {100 * kelly:.1f}% per trade\n")
        df = curve(pd.DataFrame({"t_out": T.t_out, "R": R}), risks=[0.5, 1, 2, 5, 10, 20, 50], horizons=[12])
        df.insert(0, "scenario", lab)
        rows.append(df)
        print(to_markdown(df.drop(columns="scenario")[["orizzonte", "rischio/trade %", "rend. annuo mediano",
              "capitale mediano (x)", "5° perc. (x)", "DD max 95° perc.", "P(DD>=20%)", "P(DD>=50%)", "P(rovina: -90%)"]]))
    pd.concat(rows).to_csv("results/exp13b_edge_sensitivity.csv", index=False)
