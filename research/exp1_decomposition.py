"""Esperimento 1: scomposizione principale / overlay / costi su tutti gli strumenti + test di ipotesi nulla."""
from exp_common import *

base = P()
variants = {
    "core_only":     replace(base, ov_mode="none"),
    "core+overlay":  base,
    "overlay_alone": replace(base, virtual_core=True),
    "naive_hedge":   replace(base, ov_mode="naive"),
    "naive_alone":   replace(base, ov_mode="naive", virtual_core=True),
}
if __name__ == "__main__":
    jobs = [(s, p, v) for v, p in variants.items() for s in SYMS]
    df = batch(jobs)
    df.to_csv("results/exp1_decomposition.csv", index=False)
    cols = ["sym", "label", "net_pct", "cagr", "max_dd", "sharpe", "pf", "net_core", "net_ov", "gross_core", "gross_ov",
            "costs_exec", "swap", "n_core", "n_ov", "wr_ov", "dur_core_d", "dur_ov_d"]
    for v in variants:
        print("\n###", v)
        print(fmt(df[df.label == v], cols))
    # riepilogo: somma su strumenti (capitale 100k ciascuno)
    print("\n### Somma su 12 strumenti (100k ciascuno)")
    print(df.groupby("label")[["net_profit", "gross_core", "gross_ov", "net_core", "net_ov", "costs_exec", "swap"]].sum().to_string(float_format=lambda x: f"{x:,.0f}"))
