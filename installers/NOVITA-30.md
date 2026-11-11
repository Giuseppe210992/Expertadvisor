# giot.ai: installatore 30, cosa c'è di nuovo e cosa provare

## Come installarlo

Dalla Cloud Shell di Oracle (il comando con l'impronta sha256 è nel messaggio della chat):

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "<SHA256>  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

Dopo l'installazione, sul telefono chiudi la web app dal task manager e riaprila.

## Novità

### 1. Libreria dei modelli (fase 7)
Nuova voce **Modelli** nel menu.
- **Aggiungi un modello**: PDF o Word, con nome e categoria (Contratti, Incarichi, Dichiarazioni, Privacy…). Il file viene cifrato sul server.
- **Compila per un cliente**: scegli il cliente e il modulo si apre già caricato.
- **Impara da solo**:
  - se correggi un campo con un dato del cliente (per esempio il telefono), il modello se lo ricorda;
  - se il modello di intelligenza artificiale ha indicato un dato per un'etichetta strana, anche questo viene ricordato;
  - le scritte fatte a mano sul PDF (la data, un testo fisso) tornano da sole nello stesso punto.
- **Dal secondo cliente in poi** il modulo si compila senza chiedere niente al modello e senza rispiegare nulla.
- **Versioni**: "Nuova versione" quando il modulo cambia. Le vecchie restano e le associazioni non si perdono.
- **Salva come modello**: dopo aver compilato un file nuovo, un pulsante lo mette in libreria con tutto quello che ha imparato.
- Nella compilazione guidata c'è anche il pulsante **"Dalla libreria dei modelli"**.

### 2. La chat può usare GIOT
Quando serve, la chat ha nuovi strumenti:
- **"Avvisami quando…"**: crea da sola un compito Cowork. Prima chiede **Consenti / Nega**.
- **"Che compiti ho su Cowork?"**: stato dei compiti, avanzamento della coda, eventi trovati e inviati a LiveLocal.
- **"Quali eventi ha trovato Cowork a Formia?"**: elenco degli eventi trovati, filtrabile.
- **"Cerca il cliente Rossi"**: ricerca nell'archivio. Al modello vanno solo nome, Comune e numero di documenti, mai codice fiscale o recapiti.
- Per le domande normali questi strumenti non vengono proposti, quindi la chat resta veloce come prima.

### 3. I compiti Cowork leggono davvero i link
Se scrivi un link nel compito (per esempio un post Instagram), Cowork apre **quel link**:
- lettura diretta, poi TinyFish come riserva;
- se il testo è corto, legge anche la locandina.

Prima faceva solo una ricerca web generica, che dava risposte inutili come quella vista ieri sera. Se il link non si apre, lo dice chiaramente invece di inventare.

### 4. Cowork → LiveLocal (dall'installatore 29)
Gli eventi trovati dalla coda vanno nel repository LiveLocal come consegne. Il token di GitHub va inserito in Cowork → la coda → Modifica, ed è spiegato nella chat di ieri.
**Ancora da fare**: applicare a LiveLocal la patch `installers/livelocal-consegne-cowork.patch`. La mia richiesta di scrittura su quel repository è stata bloccata dal controllo dei permessi.

### 5. Installatore più robusto
- La riga `/fetch` di Caddy viene scritta anche se il lettore impiega più di qualche secondo a partire. È il problema di ieri sera, quando Cowork risultava "non attivo".
- Se la costruzione del servizio Office (LibreOffice) fallisce, l'installatore mostra le ultime righe dell'errore. **Mandamele**: servono per capire perché sul tuo server non si costruisce.

## Collaudi (tutti con dati fittizi)
- Libreria dei modelli: server 31/31, app 22/22.
- Strumenti della chat: 9/9.
- Cowork che legge i link: 5/5.
- Invio a LiveLocal: 31/31 (la consegna è accettata dal vero importatore di LiveLocal), interfaccia 14/14.
- Regressione: vedi il messaggio in chat.

## Cosa provare domattina (5 minuti)
1. **Modelli** → Aggiungi un modello → la tua "Dichiarazione nulla a pretendere" → Compila per un cliente → Scarica. Poi compilala per un secondo cliente: deve essere già tutto a posto.
2. In chat: "avvisami quando escono i biglietti per il concerto di Natale a Formia" → **Consenti** → controlla in Cowork.
3. In chat: "che compiti ho su Cowork?".
4. Cowork → crea un compito con un link Instagram → "Controlla ora": il riepilogo deve parlare del post.
