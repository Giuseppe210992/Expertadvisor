# giot.ai: installatore 46 · Compilazione dei moduli PDF a tabella (fatture)

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-46.sh -o installa-giot-chat.sh && echo "00ede01ceb5363b3aa695d6e9bc6b574d728e1c648af5d50da0a9131d8127406  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Spazi corti e importi riconosciuti:** «n°__/26», «N.__», «(__)», «_.___,__». Sulla fattura gli spazi trovati passano da 5 a 13.
- **Etichette delle tabelle:** il nome della riga nella cella a sinistra («SPETTABILE/EGREGIO», «COD. FISC.», «IMPONIBILE») diventa l'etichetta dello spazio. Le etichette dei moduli scritti in prosa restano come prima, così i Modelli salvati non perdono le associazioni.
- **Testo dopo lo spazio:** il modello vede anche cosa è stampato subito dopo lo spazio (per esempio «/26» o «N.»).
- **Moduli già nel progetto:** vengono riconosciuti di nuovo con le regole nuove la prima volta che li compili.
- **Foto del documento d'identità:**
  - prima si leggono le persone (nome, codice fiscale, nascita, residenza) e i dati arrivano al modello come testo;
  - con una sola persona si usa la compilazione normale, che gestisce anche numero, pagamento e importi;
  - con più persone resta il percorso «per persona».
- **Regole per il modello:** il nome va solo negli spazi del nome; «numero 49» è il numero del documento; la X va solo nelle caselle; la data divisa in giorno, mese e anno va scritta a pezzi.

## Collaudi
- Fattura con la foto di un documento: 10/10.
  - «49» finisce sul numero della fattura;
  - il nome finisce accanto a SPETTABILE;
  - il codice fiscale finisce al suo posto;
  - nell'indirizzo non finisce niente di sbagliato.
- Regressione completa: tutto verde (compreso Modelli 22/22 e abbinamenti 16/16).
