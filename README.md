# CTO: Core Trend + Counter-Trend Overlay (MT5)

Progetto di ricerca e sviluppo di un Expert Advisor MetaTrader 5 basato su:

- una **posizione principale** di lungo periodo (trend-following D1, LONG o SHORT);
- **operazioni opposte** con una propria logica di trade (ingresso, stop, target, trailing, incremento solo in
  profitto), pensate per produrre profitto autonomo durante i movimenti contrari, non solo per "congelare" la perdita.

**Leggere prima [`docs/ANALISI_STRATEGIA_CTO.md`](docs/ANALISI_STRATEGIA_CTO.md)**: contiene l'analisi di fattibilità,
i risultati dei test su 12 strumenti (2005-2020) con tutti i costi, e il verdetto sul target del 10% giornaliero.
Il codice è stato scritto **dopo** l'analisi e i suoi default corrispondono alla variante che l'analisi ha
indicato come la più solida, non all'idea originale (che nei test perde denaro dopo i costi).

## Struttura

```
docs/        analisi completa, grafici, protocollo di validazione 2020-2026 (VALIDAZIONE_2020_2026.md)
validation/  analisi dei backtest MT5 (stress costi, Monte Carlo, criteri) e confronto broker
research/    motore di backtest Python, esperimenti, risultati (riproducibili: research/run_all.sh)
MQL5/
  Experts/CTO/CoreTrendOverlay.mq5    EA
  Include/CTO/*.mqh                   moduli (segnali, esecuzione, rischio, costi, edge monitor, registro overlay)
  Scripts/CTO/CTO_CostReport.mq5      misura dei costi reali sul proprio broker (da eseguire per primo)
  Presets/                            variante C congelata; esperimento con capitale minimo (50 €)
```

## Avvertenze

- Il codice MQL5 **non è stato compilato** in questo ambiente: va compilato in MetaEditor e verificato nel tester.
- I risultati di ricerca sono ottenuti su dati Oanda M1 2005-2020 con costi **stimati**; vanno riconvalidati
  sui tick reali del proprio broker per il periodo 2020-2026 prima di qualsiasi uso con denaro reale.
- Nessun risultato di questo progetto supporta l'uso di denaro reale allo stato attuale (vedi sezione 14 del documento).
