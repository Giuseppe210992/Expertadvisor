"""Esperimento 10: modalita' 'harvest' (TP giornaliero 0,5 ATR) - livelli di rischio, metriche complete, per strumento."""
import warnings; warnings.filterwarnings("ignore")
from scipy import stats as st
from exp5_final import *
HARV = replace(PROP, day_tp_atr=0.5)
if __name__ == "__main__":
    res = run_all(HARV, "HARVEST")
    tot = portfolio(res); ps = pstats(tot, res)
    tot.to_csv("results/equity_HARVEST.csv")
    print("--- HARVEST (rischio 1%/sleeve)\n" + show(ps))
    tr = pd.concat([r["trades"].assign(sym=r["sym"]) for r in res if len(r["trades"])])
    for kind in ["core", "ov"]:
        g_ = tr[tr.kind == kind].groupby(["sym", "leg_id"]).agg(net=("net", "sum"), risk0=("risk0", "first"))
        x = g_["net"] / g_["risk0"]
        if len(x) > 2:
            t, pv = st.ttest_1samp(x, 0)
            print(f"  {kind}: n={len(x)} media R={x.mean():+.3f} t={t:+.2f} p={pv:.4f}")
    rows = pd.DataFrame([r["stats"] for r in res]); rows["sym"] = [r["sym"] for r in res]
    rows.to_csv("results/per_instrument_HARVEST.csv", index=False)
    print(rows[["sym", "net_pct", "max_dd", "sharpe", "pf", "win_rate", "payoff", "net_core", "net_ov", "costs_exec", "swap",
                "n_core", "dur_core_d"]].to_string(float_format=lambda x: f"{x:,.3f}"))
    json.dump({k: float(v) if isinstance(v, (int, float, np.floating, np.integer)) else str(v) for k, v in ps.items()},
              open("results/summary_harvest.json", "w"), indent=1)
    out = []
    for rk in [0.01, 0.04, 0.08, 0.16, 0.32]:
        r2 = run_all(replace(HARV, core_risk=rk, max_lev_use=30.0), "x")
        t2 = portfolio(r2); p2 = pstats(t2)
        out.append(dict(risk_sleeve=rk, risk_capitale=rk / 12, daily_mean=p2["daily_mean"], monthly_mean=p2["monthly_mean"],
                        cagr=p2["cagr"], max_dd=p2["max_dd"], sharpe=p2["sharpe"], worst_day=p2["worst_day"],
                        best_day=p2["best_day"], max_gross_lev=max(r["stats"]["exp_gross_max"] for r in r2)))
    rk = pd.DataFrame(out)
    print(rk.to_string(float_format=lambda x: f"{x:,.5f}"))
    rk.to_csv("results/risk_levels_harvest.csv", index=False)
