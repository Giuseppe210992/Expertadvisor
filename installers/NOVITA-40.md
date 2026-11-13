# giot.ai: installatore 40 · Code + GitHub: compila, prova e pubblica da solo

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "784c396932d9f62a6137c1e93c836b457769f922c47d3c63c28c4553b40468bf  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia

### Code pubblica su GitHub Pages, in autonomia
- Nuovo strumento dell'agente **github_deploy**. L'agente invia il progetto al suo repository GitHub; **GitHub Actions** installa, compila, **prova l'app in un browser vero** e la pubblica su **GitHub Pages** (`https://<utente>.github.io/<progetto>/`).
- **Auto-correzione anche su GitHub.** Se la build o la prova falliscono, l'agente riceve il passaggio fallito e le righe d'errore del registro, corregge i file e ripubblica, fino a 3 tentativi. Poi si ferma e ti spiega.
- **Le build girano su GitHub**, su macchine con molta memoria. Così il server da 1 GB non è più un limite per React, Vite e simili.
- **La prova con il browser** apre il sito dentro la sottocartella (come su GitHub Pages) e blocca la pubblicazione se trova:
  - errori JavaScript;
  - file mancanti;
  - percorsi assoluti che su Pages si rompono;
  - una pagina vuota.
- **Prima di pubblicare chiede sempre «Consenti».** Il repository è pubblico, come richiesto da GitHub Pages gratuito.
- Nella scheda Anteprima c'è un **pannello GitHub**: repository, stato (in coda / in corso / pubblicato / non riuscito), «Apri il sito», «Registro», «Aggiorna su GitHub».

### Modelli di partenza
- «Nuovo» chiede da dove partire: **Vuoto, Sito statico, Web app Vite, Web app React**.
- Sono modelli già collaudati: si compilano, superano la prova con il browser e funzionano in una sottocartella. Con una base giusta l'agente sbaglia molto meno.

### Scelta del modello
- Per Code scegli il modello dell'agente (predefinito: «Automatico · modelli più capaci»). La scelta viene ricordata.

### Sicurezza
- Il **token di GitHub** si inserisce nella sezione Code (pulsante «GitHub») e va **solo al tuo server**, in un file leggibile soltanto dal servizio. Non resta nel browser, non entra nel banco di lavoro (che esegue codice non fidato) e non finisce nei file inviati.
- **Non vengono mai inviati a GitHub:** `node_modules`, cartelle di build, `.env`, file `.pem` / `.key`.

## Come collegare GitHub
1. Apri https://github.com/settings/personal-access-tokens/new (token «fine-grained»).
2. Nome «giot Code». In **Repository access** scegli «All repositories»: serve per creare i repository nuovi.
3. In **Permissions → Repository**:
   - *Read and write* per Administration, Contents, Pages e Workflows;
   - *Read-only* per Actions.
4. Genera il token e incollalo in giot.ai → Code → **GitHub**. Mai in una chat.

## Collaudi
- Code + GitHub sul server, con un GitHub finto: 26/26. Token mai restituito né visibile al banco di lavoro; niente node_modules/.env/chiavi inviati; Pages attivato prima del push; esito riuscito/fallito con le righe d'errore.
- Nel browser: 22/22. Modelli di partenza, collegamento del token, l'agente pubblica, GitHub fallisce, l'agente legge il registro, corregge, ripubblica; pannello GitHub; conferma Consenti/Annulla.
- Prova con il browser (lo script che gira su GitHub), eseguita qui con Chromium vero: pagina buona OK; errore JavaScript, percorso assoluto e pagina vuota bloccati con un messaggio chiaro. I modelli statico, Vite e React compilano e superano la prova.
- Regressione completa: app 92, 45, 36, 40, 37, 8, 14, 9, 22, 16, 19, 10, 29, 22, office 36, compilazione 13, esportazione 10; server 87, 106, 32, 41, 29, 31, 5, 41, 20, 25, 17, chiavi 10, Code 35, connettori 11, GitHub 26. Tutto verde.
- Non ancora provato con il GitHub vero: serve il tuo token.
