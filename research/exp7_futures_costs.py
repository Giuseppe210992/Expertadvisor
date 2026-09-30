"""Esperimento 7: stessa strategia con struttura di costo 'futures' (nessun markup sul finanziamento,
spread/commissioni dimezzati) per capire se il problema e' la strategia o il veicolo CFD."""
import warnings; warnings.filterwarnings("ignore")
from exp5_final import *
if __name__ == "__main__":
    rows = []
    for name, kw in {"CFD retail (base)": {}, "finanziamento senza markup": dict(markup_mult=0.0),
                     "futures-like (no markup, costi esecuzione x0.5)": dict(markup_mult=0.0, m_spread=0.5, m_comm=0.5, m_slip=0.5)}.items():
        for lab, p in [("CORE_ONLY", CORE), ("ORIGINALE", ORIG), ("PROPOSTA", PROP)]:
            res = run_all(replace(p, **kw), lab)
            tot = portfolio(res); ps = pstats(tot, res)
            rows.append(dict(scenario=name, variant=lab, net_pct=ps["net_pct"], cagr=ps["cagr"], sharpe=ps["sharpe"], max_dd=ps["max_dd"],
                             net_core=ps["net_core"], net_ov=ps["net_ov"], swap=ps["swap_core"] + ps["swap_ov"]))
            if lab == "PROPOSTA" and "futures" in name:
                for rk in [0.02, 0.04, 0.08]:
                    r2 = run_all(replace(p, **kw, core_risk=rk, max_lev_use=30.0), "x")
                    t2 = portfolio(r2); p2 = pstats(t2)
                    rows.append(dict(scenario=name + f" rischio {rk:.0%}/sleeve", variant=lab, net_pct=p2["net_pct"], cagr=p2["cagr"],
                                     sharpe=p2["sharpe"], max_dd=p2["max_dd"]))
    df = pd.DataFrame(rows)
    print(df.to_string(float_format=lambda x: f"{x:,.4f}"))
    df.to_csv("results/exp7_futures_costs.csv", index=False)
