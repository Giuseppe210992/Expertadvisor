# giot.ai: installatore 37 · Servizio Office corretto

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "0ea801cb494fb128428f56ffb7b0bfb0fd4180fd40d87d7a5d9412d1a1530550  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Servizio Office**: l'immagine usava «python3-minimal», che non contiene il modulo hmac, quindi il servizio si chiudeva subito («ModuleNotFoundError: No module named 'hmac'»). Ora l'immagine usa Python completo e si chiama giot-office:2. Viene ricostruita una volta (5-10 minuti, scarica LibreOffice) e la vecchia immagine viene cancellata.
- Sui server con meno di 1,8 GB di RAM, Office ha 640 MB invece di 1 GB.
- Il resto è come nell'installatore 36 (Code in versione leggera, già attivo).
