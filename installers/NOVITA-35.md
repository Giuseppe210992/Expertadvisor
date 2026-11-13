# giot.ai: installatore 35 · Code, navigazione alla pari, scarica i moduli

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "65ac39ae3df9de51529cb5aa66cd94b629f375c466c9e8b9bf4f3f86a9c7b59e  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

La prima volta l'installatore prepara anche il banco di lavoro di Code (1-3 minuti in più).

## Cosa cambia

### Navigazione
- **Progetti, Clienti, Modelli, Cowork e Code** stanno in un unico blocco in cima alla barra laterale, tutte allo stesso livello.
- I «Progetti recenti» stanno sotto, come elenco a parte.

### Progetti: scarica i documenti
- Accanto a ogni documento di un progetto c'è il pulsante **Scarica**: riscarichi il file **identico** a quello caricato (PDF, Word, .doc, Excel…).
- Funziona anche da un altro dispositivo: se il file manca, lo prende dal server (sincronizzazione dei progetti).
- I .doc vecchi caricati da oggi si riscaricano come .doc originali. Quelli caricati prima si scaricano nella versione .docx convertita.

### Code (nuova sezione)
- Descrivi cosa costruire (un sito, una pagina, una web app, uno script). L'agente scrive i file, li prova sul server e corregge gli errori da solo, **al massimo 3 tentativi** per lo stesso problema. Poi si ferma e ti chiede come procedere.
- Lo schermo è diviso in due parti. A sinistra c'è la chat con i passaggi in diretta (scrittura, esecuzione, auto-correzione, anteprima). A destra ci sono tre schede:
  - **File**: albero dei file, apri e modifichi a mano, salvi sul server;
  - **Terminale**: l'uscita dei comandi in diretta, e puoi scriverne di tuoi;
  - **Anteprima**: il risultato su un indirizzo privato non indovinabile.
- **Pubblica**: l'app va su `https://ai.roomandrelax.it/apps/<nome>/`, solo dopo la tua conferma (**Consenti** o Annulla). Puoi ritirarla quando vuoi.

### Sicurezza di Code
- I comandi girano in un **contenitore separato** (`giot-sandbox`):
  - **niente** chiave dell'archivio clienti, niente dati della chat o dei progetti;
  - utente senza privilegi, sistema in sola lettura;
  - limiti fissi: 1 GB di memoria, 1 processore, 256 processi, tempo massimo per ogni comando.
- Il contenitore usa una rete propria, chiusa dal firewall verso il server (FreeLLMAPI, archivio, Office, SSH) e verso i metadati di Oracle. Internet invece lo raggiunge, così `npm install` funziona.
- **Prima di ogni comando** il banco di lavoro verifica di non raggiungere quei servizi. Se li raggiunge, spegne i comandi e lo dice.
- Le app pubblicate su `/apps/` sono **isolate dal browser**: anche se stanno sullo stesso indirizzo della chat, non possono leggere token, chat o progetti.
- `giot-fetch` non cambia: stessi limiti di prima. Si limita a controllare l'accesso e a inoltrare le richieste `/code/*`.
- Se il banco di lavoro non parte, la sezione Code dice «non attivo». Chat, Clienti, Modelli, Cowork e compilazione funzionano come prima.

Per ora Code pubblica **app statiche** (HTML/CSS/JS, oppure Vite/Astro dopo la build). I programmi con un server proprio che resta acceso arriveranno in un secondo momento.

## Collaudi
- Code nel browser: 29/29 (sezioni alla pari, nuovo progetto, agente con errore → correzione → anteprima, terminale, file, stop dopo 3 tentativi, Consenti/Annulla, app isolata dai dati della chat, telefono).
- Banco di lavoro e inoltro: 35/35 (accesso, percorsi «..» e collegamenti simbolici rifiutati, tempo massimo, un comando per volta, uscita troncata, comandi spenti se non isolato, pubblicazione senza file nascosti come .env).
- Scarica dai progetti: 10/10 (stessi byte, anche dal secondo dispositivo).
- Regressione completa: app 92, 45, 36, 40, 37, 8, 14, 9, 22, 16, 19, 10, 29, office 36, compilazione 13, esportazione 10; server 87, 106, 32, 41, 29, 31, 5, 41, 20, 25, 17, chiavi 10, Code 35. Tutto verde.
- Installatore: come il 34 in tutti i casi, più Code attivo, Code che non parte (resto invariato, niente /apps) e Code saltato. Chiave dell'archivio e chiave di Code mai sostituite.
