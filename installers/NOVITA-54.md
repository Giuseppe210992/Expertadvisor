# giot.ai: installatore 54 · Account per gli amici

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-54.sh -o installa-giot-chat.sh && echo "4712ef6d99eb8a93e79726109ecd5f5156d5368ed32fb8b49580811c533c3dd7  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **«Accedi con Google» per gli amici** nella pagina di accesso.
  - L'amico sceglie il suo account Google e vede «Richiesta inviata: il proprietario deve approvarti».
  - Al proprietario arriva una **notifica sul telefono con i pulsanti Accetta e Rifiuta**. Il collegamento è monouso e vale 7 giorni.
  - Appena approvato, l'amico entra da solo: l'app ricontrolla ogni 20 secondi, anche se la chiude e la riapre.
  - Usa la stessa app Google del calendario e lo stesso indirizzo di ritorno: niente da rifare su console.cloud.google.com.
- **Pannello «Account degli amici»** in Impostazioni (solo proprietario): Accetta, Rifiuta, Sospendi, Riattiva, Elimina. «Elimina» cancella dal server tutti i dati dell'amico.
- **Ogni amico ha i suoi dati**, separati sul server e non solo nascosti nell'app:
  - chat (sul suo telefono);
  - progetti sincronizzati (cifrati, file distinti);
  - memoria;
  - compiti Cowork e notifiche (arrivano solo ai suoi dispositivi);
  - Google Calendar (collega il suo account).
- **Solo il proprietario** ha archivio clienti, Modelli, profilo dello studio, Code, connettori ed elenchi di link di Cowork. Il server rifiuta queste richieste agli amici (403), anche se fatte a mano.
- **Modelli per gli amici tramite il server**, con la chiave FreeLLMAPI del proprietario, che non arriva mai sul loro telefono. Ogni amico ha un token suo per dispositivo; sul server se ne conserva solo l'impronta.
- **Limiti per persona:** non ancora, si aggiungono dopo come deciso.

## Collaudi
- Server: 40/40.
  - accesso con Google;
  - notifica al proprietario decifrata, con Accetta e Rifiuta veri;
  - collegamenti monouso e falsificati;
  - token monouso;
  - porte chiuse agli amici (clienti, Modelli, profilo, connettori, Code, account, configurazione Google);
  - dati separati (memoria, progetti con lo stesso id, Cowork, notifiche, calendario);
  - modelli tramite il server;
  - sospensione, cancellazione con tutti i dati, nessun segreto nei log.
- App con tre persone: 16/16.
  - attesa e approvazione;
  - menu ridotto e indirizzi chiusi;
  - chat tramite il server;
  - memoria separata;
  - secondo amico rifiutato;
  - sospensione.
- Regressione completa: tutto verde (interfaccia 28 collaudi + 2 varianti, server 22 collaudi).
