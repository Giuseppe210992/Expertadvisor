# Validazione out-of-sample e confronto broker

Protocollo: [`docs/VALIDAZIONE_2020_2026.md`](../docs/VALIDAZIONE_2020_2026.md) (pre-registrato, tag git `variante-C-congelata`).

| File | Uso |
|---|---|
| `analyze_mt5.py` | Legge i log `CTO_trades_*_tester.csv` scritti dall'EA nel tester MT5: metriche per strumento e di portafoglio, principale vs overlay vs costi, stress spread+commissioni ×2/×3 e swap ×2, Monte Carlo a blocchi (caso peggiore a vari livelli di rischio), esito dei criteri pre-registrati |
| `merge_cost_reports.py` | Unisce i CSV di `CTO_cost_report` di più broker in una tabella di confronto (costi del lotto minimo, swap, stop-out, rischio allo stop, costi a 30/60/90 giorni sui 50 €) |
| `tests/make_synthetic_logs.py` | Collaudo: converte i trade del backtest Python nel formato di log dell'EA (i risultati del collaudo riguardano il 2017-2020, già osservato: **non** sono evidenza di validazione) |

```bash
pip install pandas numpy tabulate
python validation/analyze_mt5.py --logs "logs/CTO_trades_*_tester.csv" --deposit 10000 --out docs/risultati_validazione_2020_2026.md
python validation/merge_cost_reports.py "costi/CTO_cost_report_*.csv" > docs/confronto_broker.md
```
