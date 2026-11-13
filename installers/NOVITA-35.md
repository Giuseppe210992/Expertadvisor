# giot.ai: installatore 35 · Code, navigazione alla pari, scarica i moduli

## Installazione

```
__COMANDO__
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
__COLLAUDI__
