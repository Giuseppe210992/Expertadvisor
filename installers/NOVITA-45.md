# giot.ai: installatore 45 · Biblioteca di Code

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-45.sh -o installa-giot-chat.sh && echo "cad5e5611fb4086665f4aedb701fe4e90f0099bf32039e8e55ab822f2156f071  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Biblioteca** in Code (pulsante accanto a GitHub): manuali che l'agente consulta mentre lavora. Puoi aggiungere PDF, testo o Markdown e toglierli quando vuoi.
- **Ogni manuale viene diviso in paragrafi** con il titolo «Capitolo › sezione». Le righe con l'email vengono tolte.
- **Nuovo strumento dell'agente, consult_manual:** cerca i 3-4 paragrafi più pertinenti, con un punteggio di pertinenza. Viene proposto all'agente solo se c'è almeno un manuale.
- **I manuali restano privati sul server:** non sono nell'installatore, non vengono pubblicati e non vanno su GitHub.

## Collaudi
- Biblioteca sul server con un corso vero di 3 volumi: 17/17. Gli 8 argomenti cercati portano tutti al capitolo giusto.
- Biblioteca nel browser: 11/11.
- Regressione completa: tutto verde.
