# giot.ai: installatore 48 · Compilazione professionale dei moduli (regole fisse + controllo)

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-48.sh -o installa-giot-chat.sh && echo "c7349fad428c4bcd7c938c1b4a232a18c9e82597f40d98518780ee97304d5d7c  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Regole fisse, non affidate al modello AI.** I dati principali si ricavano dalla tua richiesta e dal documento in foto, e si mettono sempre allo stesso modo:
  - **numero del documento** («n.49», «numero 49») → spazio «n°»;
  - **data**: quella che scrivi tu («datata al 18/11/2026»), altrimenti quella di oggi. Se la data è divisa in giorno, mese e anno va nei tre spazi; nello spazio corto dell'anno si scrive «26»;
  - **importi**: da «1220 compreso iva» si ricava imponibile 1.000,00, IVA 22% 220,00 e totale 1.220; da «1.500 + iva» si ricava il totale. L'aliquota si legge dal modulo;
  - **intestatario** (Spettabile/Egregio/Cliente): nome e cognome dal documento in foto. Fronte e retro della stessa persona vengono uniti;
  - **codice fiscale, comune, provincia, via e numero civico** ciascuno nel suo spazio.
- **Controllo dei valori del modello**: si scartano i valori che non hanno senso per lo spazio:
  - la X in uno spazio di testo;
  - un numero al posto del nome;
  - il numero della fattura messo nella via;
  - un codice fiscale non valido;
  - un importo che non è un importo.

  Il messaggio dice cosa è stato scartato.
- **«Da completare»** elenca solo i dati che mancano davvero.
- **Se il modello non risponde**, il modulo si compila lo stesso con le regole.
- **Nei moduli scritti in prosa** (proposte, dichiarazioni) le regole non toccano nomi e codici fiscali: il primo codice fiscale può essere quello dell'agenzia.
- **Scelta del modulo**:
  - conta di più la parola subito dopo «compila» («Compila la bozza **fattura**…»);
  - «mezzo assegno» non porta più alla «Restituzione assegno»;
  - «dichiarazione di accettazione» non si confonde con «non accettazione».

## Collaudi
- Fattura con un modello che risponde male apposta (49 nel nome e nella via, X nell'indirizzo, data intera nello spazio corto): il PDF esce corretto. Prova della fattura 22/22.
- Regole da sole: 10/10.
- Regressione completa: tutto verde (interfaccia 24 collaudi, server 20 collaudi; app4 e app6 rilanciati da soli dopo un rallentamento della macchina: 36/36 e 37/37).
