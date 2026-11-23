# giot.ai: installatore 56 · Più intelligente: modelli migliori e richieste capite davvero

## Installazione

Comando e impronta sha256 nel messaggio di consegna (file `installa-giot-chat-56.sh`).

## 1. Perché giot sembrava «stupido» rispetto a Gemini e ChatGPT

Gemini e ChatGPT gratuiti usano sempre il loro modello migliore. giot invece, con «Automatico», lasciava scegliere a FreeLLMAPI. FreeLLMAPI dava il punteggio più alto ad **agnes-3.0-flash** e ad altri modelli piccoli, soprattutto perché rispondono veloci.

Prova sugli stessi compiti (capire una richiesta ambigua, un ragionamento logico, un italiano corretto):

| Modello | Capisce la richiesta | Logica | Italiano |
|---|---|---|---|
| gemini-3.5 / 3.6 flash | sì | giusta | ottimo |
| gpt-oss-120b | sì | giusta | buono |
| qwen3.8-27b | in parte | sbagliata | buono |
| agnes-3.0-flash | in parte | sbagliata | discreto |
| agnes-2.5-flash | no | sbagliata | scorretto |

## 2. Cosa cambia: la «classifica di qualità» di giot

- **Con «Automatico» la scelta la fa giot, con una classifica fissa:**
  1. Gemini 3.8 → 3.7 → 3.6 → 3.5 Flash, poi Gemini 3 Flash Preview;
  2. gpt-oss-120b;
  3. Gemini 2.5 Flash;
  4. solo se tutti questi falliscono, decide FreeLLMAPI.
- **«Più veloce»** usa i modelli rapidi ma decenti: qwen3.8-27b, Gemini Flash Lite e gpt-oss. Agnes non c'è più.
- **Modello in errore o finito (quota):** si passa subito al successivo, senza farti vedere l'errore. Quel modello si salta per qualche minuto, e per più tempo se continua a sbagliare.
- **Modello lento:** se non inizia a rispondere entro 25 secondi si passa al successivo.
- **Con una foto** si usano solo modelli che vedono le immagini (Gemini).
- **Gemini 3 «pensa» prima di rispondere:** riceve più spazio per la risposta, così non si tronca a metà.
- **Anche Cowork** (i compiti automatici sul server) usa la stessa classifica.
- **Un modello scelto a mano** dal menu resta quello: la classifica vale solo per «Automatico».
- **Interruttore** in Impostazioni → Comportamento: «Usa sempre i modelli migliori» (acceso). Se lo spegni, torna a decidere FreeLLMAPI.

## 3. Capire davvero cosa chiedi (e togliere oggetti dalle foto)

### Cosa non andava
- «Elimina gli occhiali dalla foto» e «Rimuovi gli occhiali dal tavolo» finivano alla chat normale. Risultato: «non dispongo di strumenti», «non ho braccia», consigli di siti esterni.
- «No, rimuovili dalla foto», scritto senza riallegare la foto, faceva partire una ricerca web.

### Cosa cambia
- **Centralino che capisce.** Quando c'è di mezzo un'immagine (allegata ora, nei messaggi prima o creata da giot), oppure la frase parla di foto, un modello legge il messaggio **insieme agli ultimi scambi** e decide cosa vuoi davvero:
  - modificare la foto;
  - creare un'immagine;
  - oppure parlarne o fare una domanda.

  Capisce anche frasi informali o sottintese e correzioni come «no, dalla foto».
- **Parole di rimozione:** elimina, cancella, togli, rimuovi, leva, «fai sparire»… con una foto sono una modifica.
- **Togliere un oggetto non ricrea più la foto da una descrizione.**
  - Senza generatore IA: «Apri nello studio», dipingi l'oggetto con il dito, poi **«Togli ciò che dipingi»**. Lo sfondo viene ricostruito con la grana vera della foto e fuori dalla zona la foto resta identica al pixel.
  - Con un generatore collegato, la rimozione la fa l'IA.
- **Istruzioni del modello:** giot sa che modifica le foto, quindi non risponde più «non posso».

## Collaudi
- Classifica di qualità nell'app: 16/16.
  - ordine giusto, modello in errore saltato e ricordato;
  - solo modelli con visione per le foto, più spazio ai Gemini 3;
  - ultima spiaggia FreeLLMAPI, interruttore.
- Classifica in Cowork: 7/7. Gemini in errore → Gemini che risponde vuoto → gpt-oss-120b che risponde bene.
- Il tuo caso degli occhiali: 12/12.
- Tutti i collaudi precedenti ripetuti.

## Limiti onesti
- I Gemini gratuiti hanno una quota giornaliera. Quando finisce si scende a gpt-oss-120b, che resta un buon modello.
- In questo momento Gemini 3.8 risponde con errore da Google: giot lo salta da solo e usa il 3.7 o il 3.6.
