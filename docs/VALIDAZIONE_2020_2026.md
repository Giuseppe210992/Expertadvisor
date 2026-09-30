# Protocollo di validazione out-of-sample 2020-2026: variante C

*Pre-registrazione. Questo documento viene scritto e committato **prima** di guardare qualsiasi risultato 2020-2026. Lo stato congelato è l'ultimo commit che modifica questo documento (vedi `git log -1 -- docs/VALIDAZIONE_2020_2026.md`). Dopo la prima versione (commit `f80349f`) sono state fatte, **prima di vedere qualsiasi dato 2020-2026**, solo correzioni che non cambiano le decisioni di trading del preset congelato: deposito del test (da 10.000 a 100.000, altrimenti i trade sarebbero saltati), prototipi di funzione, slippage e livelli SL/TP nel log, capitale necessario nel CostReport, range dell'input del preset da 50 €. Il tag `variante-C-congelata` va creato su quel commit.

## 1. Principi

1. **La strategia non cambia più in base ai risultati 2020-2026.** Si testa la variante C esattamente come nel preset `MQL5/Presets/CTO_VarianteC_congelata.set`.
2. **Nessuna ottimizzazione** su questo periodo, né globale né per strumento.
3. **Si guarda prima il caso peggiore** (drawdown, serie negative, Monte Carlo ai percentili 95-99), poi il rendimento medio.
4. **Il 10% giornaliero resta solo un riferimento teorico**: l'input `InpReferenceTargetPct` è mostrato sul pannello ma non influenza nessuna decisione di trading. L'EA opera solo quando c'è un segnale con aspettativa positiva misurata e si ferma per i limiti di rischio. Non esiste alcun meccanismo che aumenti l'esposizione per "recuperare" il target.
5. Se il test fallisce, la variante C si **abbandona**. Non si "aggiusta" guardando i risultati.

## 1b. Obiettivo di rendimento

Il 10% al giorno non è più un requisito: si accetta un rendimento inferiore purché sia **il più efficiente possibile**. In concreto:
- **"Efficienza" = rendimento per unità di rischio** (Sharpe, rendimento/drawdown), non rendimento assoluto. Con una strategia data, il rendimento assoluto si alza solo alzando il rischio per trade, e il limite lo fissa il **caso peggiore**.
- Per questo `analyze_mt5.py` calcola, per drawdown tollerati del 10%, 20% e 30% (99° percentile Monte Carlo), il **rischio massimo per trade** e il rendimento che ne deriva. È questo il numero da usare per scegliere il rischio **dopo** la validazione, non il 10% giornaliero.
- **"In pochi mesi"** va distinto in due cose. (1) **Sapere se la strategia funziona**: in pochi mesi di conto reale non si può, perché la variante C fa ~115 trade l'anno sul portafoglio e per distinguere un vantaggio di +0,02 R dal caso ne servono ~550 (circa 5 anni). La risposta rapida viene dal backtest 2020-2026 su tick reali, che copre quasi 7 anni in poche ore. (2) **Guadagnare in pochi mesi**: dipende dal rischio scelto, ed è proprio lì che si nasconde la tentazione di una martingala mascherata. Il rischio si fissa una volta sola, dal drawdown tollerato, e non si alza per recuperare.

## 2. Cosa si testa

| Elemento | Valore |
|---|---|
| Strategia | variante C (`docs/ANALISI_STRATEGIA_CTO.md`, sezioni 3 e 5.2) |
| Parametri | `MQL5/Presets/CTO_VarianteC_congelata.set` (identici ai default dell'EA nel commit congelato) |
| Periodo valutato | 1 gennaio 2020 → 30 settembre 2026 |
| Periodo del tester | **dal 1 gennaio 2019** (un anno di riscaldamento per EMA200 e ATR); l'analisi considera solo le posizioni aperte dal 2020 (`--start 2020-01-01`) |
| Strumenti (un test per simbolo) | EURUSD, GBPUSD, USDJPY, XAUUSD, NAS100, SPX500 (US500), WTI (USOIL), con i nomi esatti del broker |
| Dati | storico del broker scelto; modalità **"Ogni tick basato su tick reali"** |
| Deposito di ogni test | **100.000** (valuta del conto, denaro virtuale del tester), leva **1:30**. Con 10.000 il lotto minimo di oro, indici, petrolio e perfino EURUSD rischierebbe più dello 0,25% previsto e l'EA **salterebbe i trade**: il test sarebbe vuoto o distorto. 100.000 corrisponde alle sleeve della ricerca. L'effetto di un conto da 50 € si valuta a parte (sezione 6) |
| Ritardo di esecuzione | "casuale" nelle impostazioni del tester |
| Commissioni | quelle reali del conto (inserite nel simbolo personalizzato o nelle impostazioni del tester se il broker non le applica nello storico) |
| Swap | quelli del broker (verificare con `CTO_CostReport` che nel tester siano valorizzati) |

Nota: USDJPY non era nel dataset di ricerca, quindi è un test fuori campione anche come strumento. Il periodo 2017-2020 degli altri strumenti è già stato osservato durante la ricerca e non entra nella validazione.

## 3. Procedura

1. checkout del commit congelato (o del tag `variante-C-congelata`, se creato) e copia di `MQL5/` nella cartella dati del terminale; compilazione in MetaEditor: 0 errori, e 0 warning oltre a eventuali "possible loss of data" su conversioni numeriche. Il codice usa `DEAL_SL`/`DEAL_TP` (proprietà dei deal presenti nelle build MT5 recenti): se il compilatore non le riconosce, aggiornare il terminale. Qualsiasi errore va corretto **senza cambiare la logica di trading**.
2. Verifica visuale su 2-3 mesi di un simbolo: ingressi solo dopo la chiusura D1 e fuori rollover, presa di profitto giornaliera quando il movimento favorevole raggiunge 0,5 ATR, stop sul server a 4 ATR.
3. Per ciascuno dei 7 simboli: Strategy Tester con il preset congelato, dal 2019-01-01 al 2026-09-30, deposito 100.000, leva 1:30.
   **Controllo obbligatorio**: nel journal del tester non devono comparire righe "ingresso saltato: il lotto minimo rischierebbe…". Se compaiono, il deposito è troppo piccolo per quel simbolo: si alza il deposito (non il rischio) e si ripete il test di quel simbolo.
4. Raccolta dei log da `Common\Files`: `CTO_trades_<simbolo>_710100_tester.csv` (e `CTO_daily_*.csv`). Il file del tester viene riscritto a ogni test: copiarlo dopo ogni simbolo.
5. Analisi:
   ```bash
   python validation/analyze_mt5.py --logs "logs/CTO_trades_*_tester.csv" --deposit 100000 \
          --start 2020-01-01 --end 2026-09-30 --split 2023-01-01 \
          --cost-mult 2 3 --risk-levels 0.25 1 5 25 50 --horizon-days 90 --max-dd 0.10 0.20 0.30 \
          --expected EURUSD GBPUSD USDJPY XAUUSD NAS100 US500 USOIL \
          --out docs/risultati_validazione_2020_2026.md
   ```
6. Commit del report **così com'è**, anche se negativo.

## 4. Criteri di superamento (fissati ora, codificati in `validation/analyze_mt5.py`)

| # | Criterio | Soglia |
|---|---|---|
| 1 | Sharpe annuo netto del portafoglio dei 7 strumenti | ≥ 0,5 |
| 2 | R medio netto per ingresso della principale | > 0 con t ≥ 2 e almeno 200 ingressi |
| 4 | Profit factor netto | ≥ 1,15 |
| 5a | Netto con spread e commissioni ×2 | > 0 |
| 5b | Netto con swap negativo ×2 | > 0 |
| 6a | Strumenti con netto positivo | ≥ 60% (almeno 5 su 7) |
| 6b | Quota del profitto dal migliore strumento | ≤ 40% |
| 7 | Netto positivo sia nel 2020-2022 sia nel 2023-2026 | entrambi > 0 |

Criteri valutati a parte:
- **8 (parametri vicini)**: stesso test con `InpCoreDayTpAtr` = 0,35 e 0,75. Entrambi devono avere netto > 0. Serve solo come controllo di robustezza: **non** si sceglie il valore migliore.
- **9 (worst case)**: il drawdown massimo reale non deve superare il 99° percentile del Monte Carlo al rischio usato.
- **10 (esecuzione)**: nel forward, spread e slippage medi entro +25% di quelli del backtest.

**Esito**: la variante C è considerata validata solo se superano **tutti** i criteri 1-7. Criterio 3 (overlay): se il contributo netto degli overlay è ≤ 0, per il forward si imposta `InpOvAgainst = OV_DISABLED`. È l'unica modifica ammessa, ed è decisa ora.

## 5. Scelta del broker (prima di qualsiasi conto reale)

Per ogni broker candidato, sul **conto demo dello stesso tipo del futuro conto reale**:

1. Aprire in Market Watch i 7 simboli e lasciare accumulare i tick (per `InpDays` ≥ 30 giorni serve che il terminale abbia lo storico tick; in alternativa `InpDays` più piccolo).
2. Aprire e chiudere manualmente 0,01 lotti su ogni simbolo, così la commissione diventa **osservabile** nello storico. In alternativa inserirla a mano in `InpCommPerLotSide`.
3. Eseguire `CTO_CostReport` con `InpSymbols` = i nomi esatti del broker e `InpCapital = 50`.
4. Unire i risultati:
   ```bash
   python validation/merge_cost_reports.py "CTO_cost_report_*.csv" > docs/confronto_broker.md
   ```

La tabella prodotta contiene, per ogni broker e ogni simbolo: spread medio e massimo, ora peggiore, commissione, costo di apertura, chiusura e round-trip del lotto minimo, swap LONG e SHORT (per notte e in %/anno), costo per notte di un hedge, giorno dello swap triplo, lotto minimo e step, margine del lotto minimo, margin call e stop-out, **rischio del lotto minimo allo stop della variante C** e **costi attesi a 30/60/90 giorni in valuta e in % dei 50 €**.

Da verificare anche fuori dallo script, sul sito e nel contratto di ogni broker: entità regolamentata per i residenti in Italia (CONSOB/ESMA o passaporto UE), protezione dal saldo negativo, disponibilità di **MetaTrader 5** (lo script e l'EA sono MQL5), conto hedging o netting, lotto minimo e conti "cent".

## 6. Il problema dei 50 € (da leggere prima di usarli)

La variante C mette lo stop a 4 × ATR giornaliero. Con i livelli di volatilità 2018-2020 lo stop vale circa il 2,7% del prezzo su EURUSD, 3,2% su GBPUSD, 3,9% sull'oro, 5% sull'S&P 500, 6,6% sul Nasdaq e 11% sul petrolio. Con il **lotto minimo 0,01**:

| Strumento | Nozionale 0,01 lotti (circa) | Perdita allo stop | In % di 50 € |
|---|---|---|---|
| EURUSD | 1.000 EUR | ~27 € | **~55%** |
| USDJPY | 1.000 USD | ~20-25 € | **~40-50%** |
| XAUUSD | 1 oncia | ben oltre 50 € | **> 100%** |
| Indici, petrolio | dipende dal contratto del broker | in genere oltre 50 € | **> 100%** |

(I valori esatti per il proprio broker sono nella colonna `risk_min_lot_pct_capital` di `CTO_CostReport`.)

Conseguenze:
1. **Con i parametri congelati l'EA su un conto da 50 € non apre nessun trade**: il lotto calcolato è sotto il minimo e l'EA, per progetto, non arrotonda per eccesso.
2. Per operare comunque serve il preset `CTO_Esperimento_50EUR.set`, che consente il lotto minimo fino al 60% di rischio. **Non è la strategia validata**: è la stessa logica con un dimensionamento 150-600 volte più aggressivo di quello testato.
3. Con quel rischio, il Monte Carlo (test sintetico sul 2017-2020, periodo **favorevole**) dà, su 90 giorni al 50% per trade: **probabilità di un drawdown ≥ 50% intorno al 19%**. Sull'intero periodo: drawdown mediano ~78%.
4. Su EURUSD con leva 30:1 il margine di 0,01 lotti vale ~39 € su 50: il livello di margine parte da ~130%, e lo **stop-out del broker (tipicamente 50%) scatta vicino allo stop della strategia**. Il risultato dipende quindi dalle regole di stop-out del broker più che dalla strategia.
5. Su oro, indici e petrolio il margine del lotto minimo supera spesso i 50 €: **non negoziabili**.

**Cosa consiglio di fare con i 50 €**
- Usarli solo **dopo** che il backtest 2020-2026 ha superato i criteri, e solo come **esperimento di esecuzione e di costo** (spread, slippage, swap e commissioni reali), su **un solo simbolo FX** (EURUSD o USDJPY), considerando la perdita di tutti i 50 € come costo dell'esperimento.
- In alternativa, verificare se il broker offre conti **cent** o micro-lotti (0,001): riducono il rischio per trade di 10-100 volte e rendono l'esperimento più simile alla strategia testata.
- Per eseguire la variante C come progettata (portafoglio di 7 strumenti a 0,25% per trade) servono indicativamente **almeno 10.000**; per il solo forex con rischio ≤ 2% per trade, **almeno 1.500-2.000**.

## 7. Dopo la validazione

- **Criteri superati** → forward su demo di 3-6 mesi con il preset congelato, poi conto reale minimo. Il criterio 10 (esecuzione) si misura confrontando `CTO_trades_*_live.csv` con il backtest dello stesso periodo.
- **Criteri non superati** → la variante C si abbandona. Eventuali nuove idee (ad esempio un edge monitor anche sulla principale, per fermare l'EA quando la sua aspettativa recente non è più positiva) vanno trattate come **nuova ricerca**, con un nuovo periodo di validazione mai osservato.
