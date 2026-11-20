# giot.ai: installatore 51 · Avviso chiaro per i .doc senza originale

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-51.sh -o installa-giot-chat.sh && echo "fa4b0cd7e53a1032b70c7ff008e65ed484fb5d698b7bd68c163ebbe7fdf9b377  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **.doc caricati con versioni vecchie di giot:** di quei file restava solo la copia semplificata e l'originale non era conservato, quindi la riconversione fedele dell'installatore 50 non può partire.
- **Ora giot lo dice chiaramente** quando compila uno di questi file: «questa NON è la formattazione del tuo originale». Spiega anche la soluzione: eliminare il file dal progetto e ricaricarlo, così viene convertito con fedeltà.
- **Se l'originale c'è ma il convertitore non risponde**, giot dice di riprovare tra poco.

## Collaudi
- .doc vero: convertito subito 8/8; da copia semplificata con originale 8/8; senza originale l'avviso compare 3/3.
- Compilazione 28/28, moduli 37/37, fattura 10/10.
