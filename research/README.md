# Ricerca quantitativa (Python)

Backtest di prototipo, indipendente da MetaTrader, usato per decidere **prima di scrivere codice MQL5**
se la strategia "posizione principale + operazioni opposte" ha un vantaggio statistico dopo i costi.

## Dati

- Fonte: repository pubblico `FutureSharks/financial-data` (candele Oanda da 1 minuto, 2005 → maggio 2020, UTC).
- `download_data.py` scarica 12 strumenti e li ricampiona a M15 in `data/` (escluso da git, ~55 MB).
- Il motore ricampiona a H1 (esecuzione), H4 (overlay) e D1 (principale, giornata chiusa alle 22:00 UTC).
- Limiti: prezzi mid (lo spread è modellato a parte), niente tick reali, dati fino al 2020.
  Il periodo 2020-2026 va testato in MT5 con i tick del proprio broker (vedi `docs/`).

```bash
pip install numpy pandas scipy matplotlib requests tabulate
python download_data.py EUR_USD GBP_USD AUD_USD USD_CAD EUR_JPY AUD_JPY XAU_USD NAS100_USD SPX500_USD UK100_GBP JP225_USD WTICO_USD
./run_all.sh     # ~35 minuti su 4 core; scrive results/ e docs/img/
```

## File

| File | Contenuto |
|---|---|
| `instruments.py` | Costi per strumento (spread medio/max, commissioni, slippage, markup swap, leva), tassi storici per lo swap, dividendi indici |
| `engine.py` | Motore H1: segnali su barre chiuse, esecuzione all'apertura successiva (rinviata fuori rollover), stop intrabar pessimistici, gap, P&L principale/overlay e costi contabilizzati separatamente |
| `math_checks.py` | Verifiche senza dati di mercato: 10%/giorno vs Kelly, identità hedge = esposizione netta, hedge meccanico su random walk, target giornaliero, martingala |
| `exp1_decomposition.py` | Scomposizione principale / overlay / costi, hedge "ingenuo", overlay stand-alone |
| `exp2_overlay_search.py` | Griglia di 72 overlay solo in-sample 2005-2012, poi verifica su 2013-2016 e 2017-2020 |
| `exp3_asymmetry.py` | Overlay opposto vs stesso verso; contro principale long vs short; hedge vs netting |
| `exp4_candidates.py` | Varianti candidate per periodo IS / VAL / OOS |
| `exp5_final.py` | Batteria finale: metriche, test t per ingresso, ipotesi nulla (ingressi casuali), livelli di rischio, stress dei costi, regimi, target giornaliero, walk-forward, Monte Carlo |
| `exp6_risk_sizing.py` | Overlay a rischio costante (ipotesi respinta) |
| `exp7_futures_costs.py` | Stessa strategia con struttura di costo "futures" |
| `exp8_daily_target_check.py` | Il "chiudi tutto al target giornaliero" è un artefatto? (periodi, tempo in mercato, swap) |
| `exp9_short_hold.py` | Uscite a tempo vs presa di profitto giornaliera in ATR, stress dei costi |
| `exp10_harvest.py`, `exp11_harvest_stress.py` | Variante C: livelli di rischio, metriche per strumento, test t, stress completo, regimi |
| `instrument_profile.py` | Volatilità, variance ratio, efficiency ratio, gap del lunedì per strumento |
| `make_charts.py`, `cost_table.py`, `cost_table2.py` | Grafici e tabelle dei costi del report |

## Due errori trovati e corretti durante la ricerca (per trasparenza)

1. **R-multipli per record invece che per ingresso**: con il take-profit parziale un ingresso vincente
   produce due record, ciascuno con il proprio R pieno, quindi i vincenti venivano contati due volte
   (l'overlay originale sembrava a +0,13 R con t=+4; per ingresso è −0,12 R con t=−4). Corretto sia nel motore
   sia nell'edge monitor dell'EA.
2. **Costi FX sovrastimati ed esecuzione nel rollover**: spread FX major inseriti 10 volte più alti
   (1,5 pip invece di 0,15 pip su EURUSD ECN) e ordini della principale eseguiti alle 22:00 UTC con spread
   di rollover. Corretto: esecuzione rinviata fuori rollover, come fa l'EA.
