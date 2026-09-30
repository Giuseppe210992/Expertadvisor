# Guida di avvio passo per passo (conto DEMO e tester)

Obiettivo: eseguire la validazione 2020-2026 della variante C **senza denaro reale** e mandare i log per l'analisi.

## Fase 0 - Prerequisiti
1. MetaTrader 5 installato (dal sito del broker candidato).
2. Un **conto DEMO** del broker: *File → Apri un conto → cerca il broker → conto demo*. Accedi con quel conto.
3. Il file `CTO_MQL5.zip`.

## Fase 1 - Installare i file
1. In MT5: *File → Apri cartella dati* → entra nella cartella **MQL5**.
2. Dallo zip copia:
   - `Experts/CTO` → dentro `MQL5/Experts`
   - `Include/CTO` → dentro `MQL5/Include`
   - `Scripts/CTO` → dentro `MQL5/Scripts`
   - `Presets` → dentro `MQL5/Presets` (**facoltativo**: se la cartella non esiste creala, oppure salta questo punto; i valori predefiniti dell'EA sono già la variante C congelata e il preset si può caricare nel tester da qualunque cartella con tasto destro → *Carica* nella scheda *Input*)
3. In MT5, nel **Navigatore** (Ctrl+N): tasto destro → *Aggiorna*.

(In alternativa per l'EA: il file unico `CoreTrendOverlay_single.mq5` incollato in un nuovo EA, come già fatto con `prova111`.)

## Fase 2 - Compilare
1. Nel Navigatore, sotto *Expert Advisors → CTO*: tasto destro su `CoreTrendOverlay` → *Modifica*. Si apre MetaEditor.
2. Premi **F7**. In basso, scheda *Errori*: deve risultare **0 errori**.
3. Ripeti per `Scripts/CTO/CTO_CostReport`.

## Fase 3 - Nomi dei simboli
1. *Visualizza → Market Watch* (Ctrl+M) → tasto destro → *Mostra tutti*.
2. Annota i nomi **esatti** usati dal broker per: EURUSD, GBPUSD, USDJPY, XAUUSD, Nasdaq 100, S&P 500, petrolio WTI.
   Possono avere suffissi o nomi diversi (es. `EURUSD.r`, `US500`, `USTEC`, `NAS100`, `USOIL`, `WTI`).

## Fase 4 - Misurare i costi del broker (script)
1. Apri un grafico qualsiasi. Trascina `CTO_CostReport` dal Navigatore (sezione *Script*) sul grafico.
2. Nella finestra degli input:
   - `InpSymbols` = i 7 nomi esatti separati da virgola;
   - `InpCapital` = 50.
3. OK. I risultati compaiono in *Strumenti → Esperti*; il file è `Common\Files\CTO_cost_report_<server>.csv`.
4. Se una commissione risulta "sconosciuta": apri e chiudi a mano 0,01 lotti su quel simbolo (sul demo) e rilancia lo script, oppure scrivi la commissione in `InpCommPerLotSide`.

## Fase 5 - Prova breve in modalità visuale
*Visualizza → Tester strategie* (Ctrl+R), scheda *Impostazioni*:

| Campo | Valore |
|---|---|
| Expert | CTO\CoreTrendOverlay (o prova111) |
| Simbolo | EURUSD (nome del broker) |
| Timeframe | H1 |
| Date | Personalizzate: 2019.01.01 → 2019.06.30 |
| Ritardi | Ritardo casuale |
| Modellazione | Ogni tick basato su tick reali |
| Deposito | 100000 |
| Leva | 1:30 |
| Ottimizzazione | Disabilitata |
| Visualizzazione | spuntata |

Scheda *Input*: non toccare nulla (i valori predefiniti sono la variante C congelata). Premi *Avvia*.
Controlla che: gli ingressi avvengano dopo l'1:00 ora server, ogni posizione abbia lo stop loss, nel *Diario* compaiano righe `[CTO]`.

## Fase 6 - Test completi (uno per simbolo)
Stesse impostazioni, **visualizzazione spenta**, date **2019.01.01 → 2026.09.30**, per ciascuno dei 7 simboli.
Il primo download dei tick reali può richiedere molto tempo. Se per un simbolo la modellazione "tick reali" non è disponibile, usa "Ogni tick" e segnalalo.

## Fase 7 - Raccogliere i file
*File → Apri cartella dati* → risali di **un** livello (cartella `Terminal`) → `Common` → `Files`. Copia:
- `CTO_trades_<SIMBOLO>_710100_tester.csv` (7 file)
- `CTO_events_<SIMBOLO>_710100_tester.csv` (7 file)
- `CTO_cost_report_<server>.csv`

Ogni file ha il simbolo nel nome: rilanciare il test dello **stesso** simbolo lo sovrascrive.

## Fase 8 - Inviare
Allega i file in chat. Verranno analizzati con `validation/analyze_mt5.py` secondo il protocollo `docs/VALIDAZIONE_2020_2026.md`.

## Da NON fare
- Non avviare l'EA su un conto reale.
- Non ottimizzare e non cambiare gli input.
- Non ripetere un test "per vedere se va meglio": ogni risultato si registra così com'è.
