# giot.ai: installatore 39 · Connettori: niente strumenti pesanti per una semplice ricerca

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "2b628bf04896971fb8893ca2a332f2d16fe4e4f5aeef261a2a3fa1a594793a39  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- Per una domanda normale la chat offre al modello solo gli strumenti **leggeri** dei connettori: cercare, leggere una pagina, consultare lo stato. Per TinyFish sono search, fetch_content, get_… e list_….
- Gli strumenti **pesanti** (automazione del browser, ricerca approfondita, dataset, monitor) compaiono solo se li chiedi: «automatizza…», «naviga sul sito…», «compila il form sul sito…», «ricerca approfondita…».
- Gli strumenti che **spendono soldi o cancellano dati** (ricarica del credito, portafoglio, delete…) non vengono mai offerti in automatico.
- Istruzione al modello: per una ricerca bastano 1-2 ricerche e la lettura di 1-2 pagine, senza ripetere ricerche quasi uguali.
- Al massimo 24 strumenti offerti per volta (prima 60): il modello sceglie meglio.
- Comprende anche le priorità di memoria dell'installatore 38 e Office corretto del 37.

## Collaudi
- Classificazione con i nomi reali di TinyFish: 11/11.
- App 92/92, connettori e strumenti interni 9/9, installatore identico al 38.
