"""Esperimento 9: da dove viene il miglioramento del target giornaliero?
Uscita temporale (N giorni), take-profit giornaliero in ATR (indipendente dalla leva), stress costi."""
import warnings; warnings.filterwarnings("ignore")
from exp5_final import *
PER = {"IS": ("2005-01-01", "2012-12-31"), "VAL": ("2013-01-01", "2016-12-31"), "OOS": ("2017-01-01", "2020-05-14"), "FULL": (None, None)}
if __name__ == "__main__":
    base = replace(PROP, core_risk=0.01)
    V = {"base (tenuta lunga)": {}, "uscita dopo 1 giorno": dict(max_hold_days=1), "uscita dopo 2 giorni": dict(max_hold_days=2),
         "uscita dopo 5 giorni": dict(max_hold_days=5), "TP giornaliero 0.5 ATR": dict(day_tp_atr=0.5),
         "TP giornaliero 1 ATR": dict(day_tp_atr=1.0),
         "TP 0.5 ATR + spread x3": dict(day_tp_atr=0.5, m_spread=3), "TP 0.5 ATR + slippage x3": dict(day_tp_atr=0.5, m_slip=3),
         "TP 0.5 ATR + tutto peggiorato": dict(day_tp_atr=0.5, m_spread=2, m_comm=1.5, m_slip=3, m_swap=1.5, carry_adverse=0.01)}
    rows = []
    for name, kw in V.items():
        pers = PER.items() if ("x3" not in name and "peggiorato" not in name) else [("FULL", (None, None))]
        for per, (a, b) in pers:
            res = run_all(replace(base, start=a, end=b, **kw), name)
            ps = pstats(portfolio(res), res)
            rows.append(dict(regola=name, periodo=per, net_pct=ps["net_pct"], cagr=ps["cagr"], sharpe=ps["sharpe"], max_dd=ps["max_dd"],
                             lordo=ps["gross_core"], esec=ps["exec_core"], swap=ps["swap_core"], n=ps["n_core"],
                             in_mercato=np.mean([r["daily"]["gross_exp"].gt(0).mean() for r in res]),
                             strum_pos=sum(r["stats"]["net_profit"] > 0 for r in res)))
    df = pd.DataFrame(rows)
    print(df.to_string(float_format=lambda x: f"{x:,.4f}"))
    df.to_csv("results/exp9_short_hold.csv", index=False)
