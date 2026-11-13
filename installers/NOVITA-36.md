# giot.ai: installatore 36 · Code anche sui server piccoli, Office che si riavvia

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "a1ead86cb8507ba2837bec1a7967fbe3939c479e7f8de76ea6c14d038185c4dc  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Code in versione leggera** sui server con meno di 1,8 GB di RAM (come la Oracle E2.1.Micro da 1 GB): 384 MB per il banco di lavoro, un comando alla volta, Node limitato a 256 MB. Pagine e siti HTML/CSS/JS funzionano; le installazioni npm grandi potrebbero non entrarci. La sezione Code lo dice.
- **Servizio Office che si riavvia di continuo**: l'installatore se ne accorge, mostra le ultime righe del suo registro e lo spegne, così non consuma memoria. I .doc usano la copia semplificata.
- Tutto il resto è come nell'installatore 35.

## Collaudi
- Installatore: come il 35 in tutti i casi, più il server da 954 MB con Office che si riavvia (Office spento con il motivo, Code leggero attivo, /apps presente).
- Code nel browser 29/29, banco di lavoro 35/35, scarica dai progetti 10/10.
