# giot.ai: installatore 47 · Scelta del modulo giusto e importi come a penna

## Installazione

Comando e impronta sha256 nel messaggio di consegna (file `installa-giot-chat-47.sh`).

## Cosa cambia
- **Scelta del modulo nel progetto:**
  - le parole si confrontano per radice: «fatture» trova «fattura»;
  - contano di più le parole subito dopo «modulo» («il modulo fatture…»);
  - «bozza», «bianco», «modulo», «pdf» e i numeri non contano più, perché li hanno quasi tutti i nomi dei file.
- **Se due moduli vanno bene allo stesso modo, chiede quale:** compare «Quale compilo?» con un pulsante per ogni modulo.
- **La stessa persona letta due volte** (fronte e retro del documento, o nome scritto in due modi con lo stesso cognome) conta come una sola. Quindi si usa la compilazione normale, non «uno per persona».
- **Anno in uno spazio da due cifre** («‘__»): si scrive «26» invece di «2026», che prima veniva accorciato.
- **Importo con «,00» già stampato** («_.___,00»): si scrive solo «1.220», senza il «,00» doppio.
- I moduli già nel progetto vengono riconosciuti di nuovo con queste regole la prima volta che li compili.

## Collaudi
- Progetto con fattura, restituzione assegno e due dichiarazioni: 12/12.
  - «Compila il modulo fatture bozza n.49 mezzo assegno…» sceglie la fattura;
  - «Compila la dichiarazione» chiede quale delle due e compila quella scelta.
