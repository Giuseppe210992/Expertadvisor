# giot.ai: installatore 44 · Cowork: link a ogni annuncio e «Salva come cliente»

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-44.sh -o installa-giot-chat.sh && echo "446d3aff150faecd2b0b09b4c8ae05a0efdb2cfe5e6edf9b0012afaf333aff97  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Una scheda per ogni elemento trovato** (annunci, offerte, eventi): titolo, etichetta privato o agenzia, zona, prezzo e dettagli.
- **«Apri annuncio»:** porta alla singola inserzione, dove tocchi «Mostra numero».
  - Cowork usa solo link che ha letto davvero nelle pagine: i link inventati vengono scartati.
  - Esclude i link di accesso, quelli di altri siti e quelli di servizio.
  - Se un link manca, la scheda lo dice («link non disponibile»).
- **Niente telefoni né email nei risultati:** se compaiono, vengono sostituiti da «[contatto sul sito]».
- **«Salva come cliente»:** si apre una scheda con le note già compilate (annuncio, zona, prezzo, dettagli, link, data).
  - Nome, cognome e telefono li scrivi tu dopo averlo sentito, con il suo consenso.
  - Il cliente entra nell'archivio e si apre la sua pagina.
- Le schede compaiono dai controlli fatti dopo l'installazione.

## Collaudi
- Cowork con un sito di annunci finto: 7/7.
- Nel browser, a misura di telefono: 9/9.
- Regressione completa: tutto verde.
