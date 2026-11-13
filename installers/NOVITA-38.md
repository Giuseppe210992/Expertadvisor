# giot.ai: installatore 38 · Priorità di memoria

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "8f035123d69b751518ea34866cf8c10f12bd10efa732c18cccb8fe72247cd955  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Priorità quando la memoria finisce** (OOM killer): prima il banco di lavoro di Code (+800), poi Office (+500). giot-fetch, cioè archivio e Cowork, è protetto (-200). FreeLLMAPI e Caddy restano neutri (0), quindi dopo i contenitori sacrificabili.
- **Code e swap**: se il server ha almeno 1 GB di swap, il banco di lavoro leggero può usarne fino a 384 MB oltre ai 384 MB di RAM.
- **Riepilogo finale** con RAM, swap e servizi attivi.
- Lo swap del sistema (già presente: 4 GB) e swappiness non vengono toccati.
