"""Esperimento 11: stress test completo dei costi e scenari di mercato per la modalita' harvest."""
import warnings; warnings.filterwarnings("ignore")
from exp5_final import *
HARV = replace(PROP, day_tp_atr=0.5)
if __name__ == "__main__":
    SC = {"base": {}, "spread x2": dict(m_spread=2), "spread x3": dict(m_spread=3), "commissioni x2": dict(m_comm=2),
          "slippage x3": dict(m_slip=3), "swap x2": dict(m_swap=2), "carry avverso +2%": dict(carry_adverse=0.02),
          "tutto peggiorato": dict(m_spread=2, m_comm=1.5, m_slip=3, m_swap=1.5, carry_adverse=0.01),
          "zero costi (solo lordo)": dict(m_spread=0, m_comm=0, m_slip=0, m_swap=0)}
    rows = []
    for name, kw in SC.items():
        res = run_all(replace(HARV, **kw), name)
        ps = pstats(portfolio(res), res)
        rows.append(dict(scenario=name, net_pct=ps["net_pct"], sharpe=ps["sharpe"], max_dd=ps["max_dd"],
                         costi_esec=ps["exec_core"] + ps["exec_ov"], swap=ps["swap_core"] + ps["swap_ov"]))
    df = pd.DataFrame(rows).set_index("scenario")
    print(df.to_string(float_format=lambda x: f"{x:,.4f}"))
    df.to_csv("results/stress_costs_harvest.csv")
    res = run_all(HARV, "H")
    tot = portfolio(res)
    print("\nRegimi (HARVEST):")
    for nm, a, b in [("GFC 2008-09", "2008-06-01", "2009-03-31"), ("Rally 2009-10", "2009-04-01", "2010-04-30"),
                     ("Crisi euro 2011", "2011-07-01", "2011-12-31"), ("Laterale 2012-13", "2012-01-01", "2013-12-31"),
                     ("Trend USD 2014-15", "2014-07-01", "2015-03-31"), ("Crash ago 2015", "2015-08-01", "2015-09-30"),
                     ("Q4 2018", "2018-10-01", "2018-12-31"), ("Laterale 2019", "2019-01-01", "2019-12-31"),
                     ("COVID feb-mag 2020", "2020-02-15", "2020-05-14")]:
        seg = tot[a:b]
        print(f"    {nm:20s}: rendimento {seg.iloc[-1]/seg.iloc[0]-1:+.2%}  max DD {(1 - seg / seg.cummax()).max():.2%}")
    y = tot.resample("YE").last().pct_change().dropna()
    print("\nRendimento per anno:", " ".join(f"{d.year}:{v:+.2%}" for d, v in y.items()))
    tr = pd.concat([r["trades"].assign(sym=r["sym"]) for r in res if len(r["trades"])])
    g_ = tr.groupby(["sym", "leg_id"]).agg(net=("net", "sum"), t=("t_out", "max")).sort_values("t")
    s_ = (g_.net <= 0).astype(int).values; mx = cur = 0
    for v in s_:
        cur = cur + 1 if v else 0; mx = max(mx, cur)
    stp = tr[tr.reason == "stop"].copy()
    stp["gap_R"] = -stp.dir * (stp.exit - stp.stop) / (stp.stop - stp.entry).abs().replace(0, np.nan)
    print(f"Massima serie negativa: {mx} | stop con gap: {(stp.gap_R > 0.01).sum()} su {len(stp)}, peggiore {stp.gap_R.max():.2f} R")
    print("Uscite per motivo:", tr[tr.kind == "core"].reason.value_counts().to_dict())
