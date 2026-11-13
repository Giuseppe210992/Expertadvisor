# giot.ai: installatore 32, Progetti uguali su tutti i dispositivi

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "5ae6db22dfc310242dee545b83b0f00d2e8928339682d33120836bd583b6ffec  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **I Progetti si sincronizzano tra telefono e computer** attraverso il tuo server, cifrati come l'archivio clienti. Viaggiano i documenti e i moduli caricati con il loro **file originale**, la pratica (immobile e dati), le parti con il ruolo e le istruzioni.
- Avviene all'apertura, ogni minuto, appena modifichi qualcosa e quando torni sull'app. Se lo stesso progetto cambia su due dispositivi, vince la modifica più recente.
- Un progetto eliminato sparisce anche dagli altri dispositivi e non risorge.
- Impostazioni → **Sincronizzazione**: interruttore, "Sincronizza ora" e ora dell'ultima sincronizzazione.
- **Difetto corretto**: aggiungendo un modulo a un Progetto, adesso si conserva anche l'originale, che serve per compilarlo identico.

Erano già condivisi: Clienti, Modelli, Il mio profilo, Cowork, Connettori. Restano per ora sul singolo dispositivo le **chat** e le impostazioni dell'app.

## Collaudi
- Due dispositivi veri (due browser con memoria separata): 9/9. Su B compaiono progetto, modulo, originale e pratica creati su A; le modifiche fatte su B arrivano su A; un'eliminazione si propaga e il progetto non risorge.
- Server: 20/20, con progetti e file cifrati su disco, conflitti, eliminazioni e accesso negato senza token.
- Regressione completa: app 92, 45, 36, 40, 37, 8, 14, 9, 22, 16, office 36, compilazione 13, esportazione 10; server 87, 106, 32, 41, 29, 31, 5, 41, 20, 25, 17. Tutto verde.

## Nota
I progetti che hai già su un dispositivo salgono sul server alla prima apertura dopo l'aggiornamento. Apri l'app **prima sul dispositivo che ha i moduli**, poi sugli altri.
