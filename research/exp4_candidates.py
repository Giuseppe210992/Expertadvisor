"""Esperimento 4: varianti candidate, scomposte per periodo (IS / VAL / OOS)."""
from exp_common import *

PER = {"IS": ("2005-01-01", "2012-12-31"), "VAL": ("2013-01-01", "2016-12-31"), "OOS": ("2017-01-01", "2020-05-14")}
d1ov = dict(n_ov=120, n_ov_exit=60, k_ov_stop=4.0)
VARS = {
    "V0_core_only":        replace(P(), ov_mode="none", hedge_mode="net"),
    "V1_H4_hedge":         P(),
    "V2_D1ov_both":        replace(P(), **d1ov),
    "V3_D1ov_rebound_net": replace(P(), **d1ov, ov_against="short_core", hedge_mode="net"),
    "V4_D1ov_edge_net":    replace(P(), **d1ov, edge_n=20, hedge_mode="net"),
    "V5_H4_edge_net":      replace(P(), edge_n=20, hedge_mode="net"),
}
if __name__ == "__main__":
    jobs = [(s, replace(p, start=a, end=b), f"{v}|{per}") for v, p in VARS.items() for per, (a, b) in PER.items() for s in SYMS]
    df = batch(jobs)
    df["variant"] = df.label.str.split("|").str[0]; df["period"] = df.label.str.split("|").str[1]
    df.to_csv("results/exp4_candidates.csv", index=False)
    g = df.groupby(["variant", "period"])[["net_profit", "net_core", "net_ov", "gross_ov", "costs_exec", "swap", "n_ov"]].sum()
    print(g.to_string(float_format=lambda x: f"{x:,.0f}"))
