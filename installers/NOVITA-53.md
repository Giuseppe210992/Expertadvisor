# giot.ai: installatore 53 · Connettore Google Calendar

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-53.sh -o installa-giot-chat.sh && echo "d16d50a960dc6cfd1e6b5b07ac264db861e6b9042b5ff5b6976e52a98ceb94d2  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Google Calendar collegabile** da Impostazioni → Google Calendar, con l'accesso al proprio account Google (OAuth).
  - Si configura una volta: si crea un'app su console.cloud.google.com (guida passo passo nell'app) e si inseriscono ID client e client secret.
  - ID client, secret e token stanno **solo sul server** (file con permessi 600): nel telefono e nella chat non passano mai.
  - Permesso chiesto a Google: solo gli **eventi** del calendario (più l'email, per mostrare quale account è collegato).
  - «Scollega» revoca l'accesso anche presso Google.
- **In chat:**
  - «che impegni ho giovedì?»: legge gli eventi del periodo;
  - «fissa una visita domani alle 10 in via Appia»: crea l'appuntamento;
  - sposta o modifica un appuntamento;
  - cancella un appuntamento.

  Tutto in ora italiana, anche per gli eventi di tutto il giorno. **Ogni scrittura nel calendario chiede prima conferma** e mostra cosa verrà scritto.

## Collaudi
- Server con un Google finto: 23/23.
  - accesso con «state» casuale, valido una volta sola;
  - rinnovo automatico del token;
  - creazione, elenco, modifica e cancellazione degli eventi;
  - ora italiana ed eventi di tutto il giorno;
  - revoca allo scollegamento;
  - nessun segreto restituito all'app o scritto nei log.
- App: 10/10.
  - guida e indirizzo di ritorno da copiare;
  - stato «Collegato»;
  - impegni letti in chat;
  - appuntamento creato solo dopo la conferma;
  - scollegamento.
- Regressione completa: tutto verde (interfaccia 27 collaudi + 2 varianti, server 21 collaudi).
