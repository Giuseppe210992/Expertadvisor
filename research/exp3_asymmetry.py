"""Esperimento 3: overlay opposto vs stesso verso; asimmetria per direzione; costo hedge vs netting."""
from exp_common import *

base = P()
variants = {
    "opp_alone": replace(base, virtual_core=True),
    "same_alone": replace(base, virtual_core=True, ov_side="same"),
    "opp120_alone": replace(base, virtual_core=True, n_ov=120, n_ov_exit=60, k_ov_stop=4.0),
    "same120_alone": replace(base, virtual_core=True, ov_side="same", n_ov=120, n_ov_exit=60, k_ov_stop=4.0),
    "core+ov_hedge": base,
    "core+ov_net": replace(base, hedge_mode="net"),
    "core_only": replace(base, ov_mode="none"),
}

def _job2(args):
    sym, p, label = args
    r = run(sym, p)
    s = stats(r, label); s["sym"] = sym
    tr = r["trades"]
    ov = tr[tr["kind"] == "ov"] if len(tr) else tr
    # direzione della principale = opposta all'overlay se ov_side=opposite
    sign = -1 if p.ov_side == "opposite" else 1
    s["ov_net_core_long"] = ov[ov["dir"] * sign > 0]["net"].sum() if len(ov) else 0
    s["ov_net_core_short"] = ov[ov["dir"] * sign < 0]["net"].sum() if len(ov) else 0
    s["ov_n_core_long"] = (ov["dir"] * sign > 0).sum() if len(ov) else 0
    s["ov_n_core_short"] = (ov["dir"] * sign < 0).sum() if len(ov) else 0
    return s

if __name__ == "__main__":
    from multiprocessing import Pool
    jobs = [(s, p, v) for v, p in variants.items() for s in SYMS]
    with Pool(4) as pool:
        df = pd.DataFrame(pool.map(_job2, jobs))
    df.to_csv("results/exp3_asymmetry.csv", index=False)
    g = df.groupby("label")[["net_profit", "gross_ov", "net_ov", "costs_exec", "swap", "swap_core", "swap_ov",
                             "ov_net_core_long", "ov_net_core_short", "ov_n_core_long", "ov_n_core_short", "n_ov"]].sum()
    print("### Somme su 12 strumenti x 100k, 2005-2020.05")
    print(g.to_string(float_format=lambda x: f"{x:,.0f}"))
    print("\n### Per strumento: overlay opposto (H4 n20) split per direzione della principale")
    d = df[df.label == "opp_alone"][["sym", "ov_net_core_long", "ov_n_core_long", "ov_net_core_short", "ov_n_core_short"]]
    print(d.to_string(float_format=lambda x: f"{x:,.0f}"))
    print("\n### Hedge vs netting (stessi segnali): differenza di swap")
    a = df[df.label == "core+ov_hedge"].set_index("sym"); b = df[df.label == "core+ov_net"].set_index("sym")
    print(pd.DataFrame({"swap_hedge": a["swap"], "swap_net": b["swap"], "extra_cost_hedge": b["swap"] - a["swap"],
                        "net_hedge": a["net_profit"], "net_net": b["net_profit"]}).to_string(float_format=lambda x: f"{x:,.0f}"))
