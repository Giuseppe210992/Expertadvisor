# giot.ai: installatore 49 · Dichiarazioni compilate come in Word

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-49.sh -o installa-giot-chat.sh && echo "c1c938f43da1faa92123660a8f0ec16b93d038e69e9b88a28b1cff81b51b54be  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Dati dentro il testo (dichiarazioni e lettere nate da Word, anche in PDF):**
  - il dato prende il posto degli underscore dentro la frase;
  - i paragrafi si ricompongono, giustificati, con lo stesso carattere e la stessa interlinea;
  - il testo originale viene tolto (non coperto), quindi copiando dal PDF non compare due volte; loghi e linee restano;
  - nei documenti tutti in MAIUSCOLO anche i dati vanno in maiuscolo;
  - i dati mancanti restano con gli underscore originali.
- **Sugli spazi per proposte, incarichi e moduli a tabella:** il foglio resta identico. La scelta è automatica (nome del file, caselle, tabelle). Il pulsante «Scrivi sugli spazi» / «Integra nel testo» la cambia, e giot la ricorda per quel modulo.
- **Importi in lettere:** «DICONSI EURO ____/00» si scrive «milleduecentoventi», preso dall'importo in cifre scritto subito prima. Se nel modulo ci sono più importi in lettere (prezzo e caparra), si usa solo l'importo in cifre accanto, senza indovinare.
- **Importo dalla richiesta:** «assegno di 1.220 euro» basta a compilare cifre e lettere quando il modulo ha un solo importo.
- **Date negli spazi `__/__/____`:** giorno, mese e anno sono scritti ciascuno sul suo tratto, non sopra le barre stampate.
- **Anno già stampato** («LÌ __ ________ 2026»): si scrive «20 novembre».
- **Mese nello spazio lungo** della fattura: si scrive «novembre».
- **Date che non sono di oggi:** «sottoscritta in data», «datata il» e la data della proposta non ricevono la data di oggi. Restano vuote se non le dai tu.
- **Etichette degli spazi a inizio riga:** prendono la fine della riga prima («CODICE FISCALE:», «NUMERO», «A MEZZO ASSEGNO BANCARIO N°»), non il testo che segue.
- **Posizione precisa degli spazi** nella riga: si misura con il carattere vero della pagina.
- **Richiesta riconosciuta anche senza la parola «modulo»:** «Compila la restituzione dell'assegno» basta, se nel progetto c'è un modulo con quel nome.

## Collaudi
- Prova della compilazione: 28/28 (testo integrato, cambio di modo, fattura, modello che sbaglia).
- Regressione completa: tutto verde (interfaccia 24 collaudi, server 20 collaudi).
- Restituzione assegno: «1.220», «milleduecentoventi», data di oggi nei tre tratti, data della proposta vuota.
- Fattura: 18 · novembre · 26, nome, indirizzo, codice fiscale e importi.
- Regole: 14/14.
