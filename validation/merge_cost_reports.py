"""
Unisce i CSV prodotti da CTO_CostReport.mq5 su piu' broker (uno per server) in una tabella di confronto.

Uso:  python merge_cost_reports.py CTO_cost_report_*.csv  > confronto_broker.md
I file si trovano in  <Dati terminale>/../Common/Files/  (File > Apri cartella dati > risalire a Common).
"""
import sys, glob
import pandas as pd

ROWS = [("spread_avg_pts", "Spread medio (punti)"), ("spread_max_pts", "Spread massimo (punti)"),
        ("worst_hour_server", "Ora con spread peggiore (server)"),
        ("comm_per_lot_side", "Commissione per lotto per lato"), ("comm_source", "Fonte commissione"),
        ("cost_open_min_lot", "Costo apertura lotto minimo"), ("cost_close_min_lot", "Costo chiusura lotto minimo"),
        ("cost_roundtrip_min_lot", "Costo A+C lotto minimo"), ("roundtrip_pct_atr", "A+C in % ATR D1"),
        ("swap_long_night_min_lot", "Swap LONG per notte (lotto min.)"), ("swap_short_night_min_lot", "Swap SHORT per notte (lotto min.)"),
        ("swap_long_pct_yr", "Swap LONG %/anno"), ("swap_short_pct_yr", "Swap SHORT %/anno"),
        ("hedge_cost_night_min_lot", "Costo hedge per notte (lotto min.)"), ("triple_swap_day", "Giorno swap triplo"),
        ("min_lot", "Lotto minimo"), ("lot_step", "Step"), ("margin_min_lot", "Margine lotto minimo"),
        ("margin_min_lot_pct_capital", "Margine lotto min. in % capitale"),
        ("risk_min_lot_at_stop", "Rischio lotto min. allo stop C (4 ATR)"), ("risk_min_lot_pct_capital", "... in % del capitale"),
        ("cost_30d", "Costi attesi 30 giorni"), ("cost_60d", "Costi attesi 60 giorni"), ("cost_90d", "Costi attesi 90 giorni"),
        ("cost_90d_pct_capital", "Costi 90 giorni in % capitale"),
        ("capital_needed_risk_0_25pct", "Capitale minimo per rischio 0,25%/trade"),
        ("capital_needed_risk_1pct", "Capitale minimo per rischio 1%/trade"),
        ("capital_needed_risk_2pct", "Capitale minimo per rischio 2%/trade")]
ACCOUNT = [("account_currency", "Valuta del conto"), ("hedging_account", "Conto hedging"),
           ("margin_call", "Margin call"), ("stop_out", "Stop-out"), ("stop_out_mode", "Unita' stop-out")]


def main(paths):
    files = [f for p in paths for f in glob.glob(p)]
    if not files:
        sys.exit("nessun file")
    df = pd.concat([pd.read_csv(f, sep=";") for f in files], ignore_index=True)
    df["col"] = df["broker"].astype(str) + " (" + df["server"].astype(str) + ")"
    print("# Confronto broker (dati misurati da CTO_CostReport)\n")
    # --- tabella principale: capitale necessario perche' il lotto minimo rispetti il rischio per trade
    print("## Capitale necessario (lotto minimo, stop della variante C = 4 x ATR20 D1)\n")
    print("Perdita al minimo = perdita di UNA posizione al lotto minimo se colpisce lo stop, in valuta del conto. "
          "Capitale per X% = capitale con cui quella perdita vale X% del conto. Il capitale per il portafoglio "
          "è il massimo tra gli strumenti che si vogliono negoziare.\n")
    for col, g in df.groupby("col"):
        ccy = g["account_currency"].iloc[0]
        t = pd.DataFrame({"Strumento": g["symbol"], "Lotto minimo": g["min_lot"],
                          f"Perdita al minimo ({ccy})": g["risk_min_lot_at_stop"].round(2),
                          "Capitale per 0,25%": g["capital_needed_risk_0_25pct"].round(0),
                          "Capitale per 1%": g["capital_needed_risk_1pct"].round(0),
                          "Capitale per 2%": g["capital_needed_risk_2pct"].round(0),
                          "Margine lotto min.": g["margin_min_lot"].round(2)})
        print(f"### {col}\n")
        print(t.to_markdown(index=False))
        print(f"\nCapitale per negoziare TUTTI gli strumenti: {g['capital_needed_risk_0_25pct'].max():,.0f} (0,25%) · "
              f"{g['capital_needed_risk_1pct'].max():,.0f} (1%) · {g['capital_needed_risk_2pct'].max():,.0f} (2%) {ccy}\n")
    acc = df.groupby("col").first()
    print("## Conto\n")
    print(pd.DataFrame({lab: acc[c] for c, lab in ACCOUNT}).T.to_markdown())
    for sym, g in df.groupby("symbol"):
        g = g.set_index("col")
        print(f"\n## {sym}\n")
        print(pd.DataFrame({lab: g[c] for c, lab in ROWS if c in g}).T.to_markdown())
    # riepilogo: costi 90 giorni del portafoglio (somma degli strumenti) e strumenti non negoziabili con il capitale dato
    print("\n## Riepilogo per broker\n")
    summ = df.groupby("col").agg(costi_90g=("cost_90d", "sum"), costi_90g_pct=("cost_90d_pct_capital", "sum"),
                                 strumenti=("symbol", "count"),
                                 margine_oltre_capitale=("margin_min_lot_pct_capital", lambda x: int((x > 100).sum())),
                                 rischio_oltre_50pct=("risk_min_lot_pct_capital", lambda x: int((x > 50).sum())),
                                 capitale_min_025_max=("capital_needed_risk_0_25pct", "max"),
                                 capitale_min_1_max=("capital_needed_risk_1pct", "max"))
    print(summ.to_markdown())
    print("\nNota: 'rischio_oltre_50pct' = strumenti su cui UNA posizione al lotto minimo con lo stop della variante C "
          "rischia piu' di meta' del capitale indicato nello script. 'capitale_min_*_max' = capitale necessario perche' "
          "TUTTI gli strumenti del report rispettino quel rischio con il lotto minimo.")


if __name__ == "__main__":
    main(sys.argv[1:])
