"""Esperimento 6: overlay dimensionato a RISCHIO COSTANTE (invece che frazione dei lotti della principale)."""
from exp_common import *
PER = {"IS": ("2005-01-01", "2012-12-31"), "VAL": ("2013-01-01", "2016-12-31"), "OOS": ("2017-01-01", "2020-05-14")}
d1ov = dict(n_ov=120, n_ov_exit=60, k_ov_stop=4.0)
VARS = {
    "H4_frac_both":       replace(P(), virtual_core=True),
    "H4_risk_both_cap1":  replace(P(), virtual_core=True, ov_size="risk", ov_risk=0.005, max_ratio=1.0),
    "H4_risk_both_cap3":  replace(P(), virtual_core=True, ov_size="risk", ov_risk=0.005, max_ratio=3.0),
    "H4_risk_short_cap3": replace(P(), virtual_core=True, ov_size="risk", ov_risk=0.005, max_ratio=3.0, ov_against="short_core"),
    "H4_risk_long_cap3":  replace(P(), virtual_core=True, ov_size="risk", ov_risk=0.005, max_ratio=3.0, ov_against="long_core"),
    "D1_risk_both_cap3":  replace(P(), virtual_core=True, ov_size="risk", ov_risk=0.005, max_ratio=3.0, **d1ov),
    "D1_risk_short_cap3": replace(P(), virtual_core=True, ov_size="risk", ov_risk=0.005, max_ratio=3.0, ov_against="short_core", **d1ov),
}
if __name__ == "__main__":
    jobs = [(s, replace(p, start=a, end=b), f"{v}|{per}") for v, p in VARS.items() for per, (a, b) in PER.items() for s in SYMS]
    jobs += [(s, p, f"{v}|FULL") for v, p in VARS.items() for s in SYMS]
    df = batch(jobs)
    df["variant"] = df.label.str.split("|").str[0]; df["period"] = df.label.str.split("|").str[1]
    df.to_csv("results/exp6_risk_sizing.csv", index=False)
    g = df.groupby(["variant", "period"]).agg(net=("net_profit", "sum"), gross=("gross_ov", "sum"), costs=("costs_exec", "sum"),
                                               swap=("swap", "sum"), n=("n_ov", "sum"), pos_instr=("net_profit", lambda x: (x > 0).sum()),
                                               maxdd_avg=("max_dd", "mean"))
    print(g.to_string(float_format=lambda x: f"{x:,.3f}"))
