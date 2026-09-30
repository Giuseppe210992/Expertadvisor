# Registro dei test OOS (variante C congelata, nessuna modifica dopo i risultati)

## 1. EURUSD - TenTrade-Server (demo) - 2019.01.01 -> 2026.09.30, H1, deposito 100000, rischio 0,25%

Fonte: diario del tester incollato in chat il 2026-09-30 (CSV di trade/eventi da allegare per l'analisi completa).

| Voce | Valore |
|---|---|
| Round-trip | 60 (7,7/anno; ricerca 2005-2020: 9,5/anno) |
| Uscite | 58 presa di profitto giornaliera, 2 stop loss, 0 overlay |
| Vincenti | 36 (60%) |
| Media vincita / perdita | +0,13 R / -0,28 R |
| Profit factor (eseguito, senza swap) | 0,68 |
| Media per trade | -0,036 R (mediana +0,08 R), t = -1,09 |
| Lordo pre-costi | -482,76 USD (-1,9 R) |
| Costi (spread stimato 36,17 + slippage 22,75 + swap 27,94) | 86,86 USD (0,35 R in totale) |
| Netto | -569,62 USD (-0,57% in 7,75 anni, -2,3 R) |
| Long / short | 29 trade -0,97 R / 31 trade -1,20 R |

Esito rispetto al protocollo: EURUSD NON soddisfa il prerequisito del criterio 2 (R > 0, t >= 2, n >= 200)
-> rischio assegnato 0 dalla regola pre-registrata. Coerente con la ricerca 2005-2020 (PF 1,05, edge ~0).

Deviazioni registrate (non corrette):
- Tick reali scartati per 989.624 minuti su 2.878.252 (382 giorni interi), in pratica da 2019-01 a ~2021-09:
  prezzi dei tick non coerenti con le barre M1 del server; il tester ha usato tick generati. Il periodo
  ~2021-09 -> 2026-09 e' su tick reali.
- Spread medio nel tester 3,0 pt contro 11,2 pt misurati oggi sul demo (CTO_CostReport): i costi del tester
  sono circa 1/3,7 di quelli attuali del conto standard; lo stress x3 e' quindi lo scenario realistico.
- Leva del tester 1:33 invece di 1:30 (irrilevante a 0,25% di rischio).
