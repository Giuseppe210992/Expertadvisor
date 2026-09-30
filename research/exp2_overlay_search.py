"""
Esperimento 2: esiste una famiglia di overlay contro-trend con vantaggio autonomo?
Ricerca a griglia SOLO in-sample (2005-2012) sull'overlay "stand-alone" (virtual_core=True),
aggregato su 12 strumenti. Le migliori configurazioni sono poi verificate su
validazione (2013-2016) e out-of-sample (2017-2020.05) senza ulteriori modifiche.
"""
import itertools
from exp_common import *

IS = dict(start="2005-01-01", end="2012-12-31")
VAL = dict(start="2013-01-01", end="2016-12-31")
OOS = dict(start="2017-01-01", end="2020-05-14")

grid = list(itertools.product([20, 60, 120], ["none", "ema", "d1"], [2.0, 4.0], [0.5, 1.0], [0.0, 2.0]))
# n_ov, filtro, k_ov_stop, n_exit (come frazione di n_ov), tp_R

def mk(n_ov, filt, kst, exf, tp, per):
    return replace(P(), virtual_core=True, n_ov=n_ov, ov_filter=filt, k_ov_stop=kst,
                   n_ov_exit=max(5, int(n_ov * exf)), tp_R=tp, **per)

def agg(df):
    g = df.groupby("label").agg(net=("net_profit", "sum"), gross=("gross_ov", "sum"), costs=("costs_exec", "sum"),
                                swap=("swap", "sum"), n=("n_ov", "sum"),
                                pos_instr=("net_profit", lambda x: (x > 0).sum()))
    return g

if __name__ == "__main__":
    jobs = []
    for cfg in grid:
        lab = "n%d_%s_k%.0f_x%.1f_tp%.0f" % cfg
        for s in SYMS:
            jobs.append((s, mk(*cfg, IS), lab))
    df = batch(jobs)
    g = agg(df).sort_values("net", ascending=False)
    g["net_per_trade"] = g["net"] / g["n"]
    print("### IN-SAMPLE 2005-2012: overlay stand-alone, somma 12 strumenti x 100k, rischio principale virtuale 1%")
    print(g.to_string(float_format=lambda x: f"{x:,.0f}"))
    print(f"\nConfigurazioni con netto IS > 0: {(g.net > 0).sum()} su {len(g)}")
    print(f"Configurazioni con LORDO IS > 0: {(g.gross > 0).sum()} su {len(g)}")
    df.to_csv("results/exp2_is.csv", index=False)
    top = list(g.index[:5])
    rows = []
    for lab in top:
        cfg = [c for c in grid if ("n%d_%s_k%.0f_x%.1f_tp%.0f" % c) == lab][0]
        for per_name, per in [("VAL", VAL), ("OOS", OOS)]:
            jj = [(s, mk(*cfg, per), f"{lab}|{per_name}") for s in SYMS]
            d2 = batch(jj)
            a = agg(d2)
            rows.append(a)
    out = pd.concat(rows)
    print("\n### TOP-5 IS verificate su VALIDAZIONE e OUT-OF-SAMPLE (nessuna ri-ottimizzazione)")
    print(out.to_string(float_format=lambda x: f"{x:,.0f}"))
