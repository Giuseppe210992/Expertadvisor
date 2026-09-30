"""Esperimento 8: il 'chiudi tutto al +0,5% giornaliero' e' un vantaggio reale o un artefatto?
Scomposizione per periodo, per strumento, per fonte (lordo/costi/swap) e confronto con controlli:
 - uscita dopo un giorno forte definito in ATR (indipendente dalla dimensione della posizione)
 - tempo in mercato ridotto casualmente (stessa quota di giorni flat) -> effetto swap/esposizione."""
import warnings; warnings.filterwarnings("ignore")
from exp5_final import *
PER = {"IS": ("2005-01-01", "2012-12-31"), "VAL": ("2013-01-01", "2016-12-31"), "OOS": ("2017-01-01", "2020-05-14")}
if __name__ == "__main__":
    base = replace(PROP, core_risk=0.04)
    rows = []
    for name, kw in {"nessun target": {}, "close_all 0.5%": dict(daily_target=0.005, target_mode="close_all"),
                     "close_all 0.25%": dict(daily_target=0.0025, target_mode="close_all"),
                     "close_all 1%": dict(daily_target=0.01, target_mode="close_all")}.items():
        for per, (a, b) in list(PER.items()) + [("FULL", (None, None))]:
            res = run_all(replace(base, start=a, end=b, **kw), name)
            ps = pstats(portfolio(res), res)
            expo = np.mean([r["daily"]["gross_exp"].gt(0).mean() for r in res])
            rows.append(dict(scenario=name, periodo=per, net_pct=ps["net_pct"], sharpe=ps["sharpe"], max_dd=ps["max_dd"],
                             gross_core=ps["gross_core"], exec=ps["exec_core"] + ps["exec_ov"], swap=ps["swap_core"],
                             n_core=ps["n_core"], tempo_in_mercato=expo,
                             strumenti_pos=sum(r["stats"]["net_profit"] > 0 for r in res)))
    df = pd.DataFrame(rows)
    print(df.to_string(float_format=lambda x: f"{x:,.4f}"))
    df.to_csv("results/exp8_daily_target_check.csv", index=False)
