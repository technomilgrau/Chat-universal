const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Memória temporária (Zera se o servidor reiniciar, mas o Lua salva os históricos!)
const friendRequests = {}; // Formato: { recebedor: ["remetente1", "remetente2"] }
const pendingMessages = {}; // Formato: { recebedor: { remetente: ["msg1", "msg2"] } }

// Rota 1: Enviar pedido de amizade
app.post('/send_request', (req, res) => {
    const { from, to } = req.body;
    if (!from || !to) return res.status(400).send("Faltam dados");

    if (!friendRequests[to]) friendRequests[to] = [];
    if (!friendRequests[to].includes(from)) {
        friendRequests[to].push(from);
    }
    
    res.json({ success: true });
});

// Rota 2: Enviar mensagem privada
app.post('/send_private', (req, res) => {
    const { from, to, msg } = req.body;
    if (!from || !to || !msg) return res.status(400).send("Faltam dados");

    if (!pendingMessages[to]) pendingMessages[to] = {};
    if (!pendingMessages[to][from]) pendingMessages[to][from] = [];
    
    pendingMessages[to][from].push(msg);
    
    res.json({ success: true });
});

// Rota 3: Sincronizar e receber dados (chamado a cada 3s pelo Lua)
app.post('/sync_private', (req, res) => {
    const { user } = req.body;
    if (!user) return res.status(400).send("Usuário não informado");

    // Pega os dados pendentes
    const myRequests = friendRequests[user] || [];
    const myMessages = pendingMessages[user] || {};

    // Responde pro script Lua
    res.json({
        requests: myRequests,
        newMessages: myMessages
    });

    // LIMPEZA: Apaga da memória do servidor pois o jogador já recebeu e salvou no .json local
    delete friendRequests[user];
    delete pendingMessages[user];
});

// Inicia o servidor na porta do Render
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor do Chat Universal rodando na porta ${PORT}`);
});
