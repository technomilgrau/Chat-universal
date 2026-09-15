const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Memória temporária do servidor (Zera ao reiniciar, mas o Lua salva histórico local)
const users = {}; // Armazena quem está online: { username: { displayName, userId, status } }
const friendRequests = {}; // Formato: { recebedor: [{from, fromDisplay, fromId}] }
const pendingMessages = {}; // Formato: { recebedor: { remetente: [msg1, msg2] } }

// ==========================================
// ROTAS DE USUÁRIO E PESQUISA
// ==========================================

// 1. Registra o usuário quando ele executa o script (Faz ele aparecer na pesquisa)
app.post('/register', (req, res) => {
    const { username, displayName, userId } = req.body;
    if (!username) return res.status(400).send("Faltam dados");
    
    users[username] = {
        username,
        displayName: displayName || username,
        userId: userId || 1,
        status: "Online"
    };
    res.json({ success: true });
});

// 2. Pesquisa de usuários pelo nick
app.get('/users', (req, res) => {
    const query = (req.query.query || "").toLowerCase();
    if (!query) return res.json([]);

    const results = [];
    for (const key in users) {
        // Busca tanto pelo @username quanto pelo Display Name
        if (key.toLowerCase().includes(query) || users[key].displayName.toLowerCase().includes(query)) {
            results.push(users[key]);
        }
    }
    res.json(results);
});

// ==========================================
// ROTAS DE STATUS E DIGITAÇÃO
// ==========================================

app.post('/set_status', (req, res) => {
    const { username, status } = req.body;
    if (users[username]) {
        users[username].status = status;
    }
    res.json({ success: true });
});

app.get('/get_status', (req, res) => {
    const username = req.query.username;
    const status = users[username] ? users[username].status : "Offline";
    res.json({ status });
});

// ==========================================
// ROTAS DE PEDIDOS DE AMIZADE
// ==========================================

app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (!from || !to) return res.status(400).send("Faltam dados");

    if (!friendRequests[to]) friendRequests[to] = [];
    
    // Evita pedidos duplicados
    const alreadySent = friendRequests[to].find(req => req.from === from);
    if (!alreadySent) {
        friendRequests[to].push({ from, fromDisplay: fromDisplay || from, fromId: fromId || 1 });
    }
    res.json({ success: true });
});

app.get('/get_requests', (req, res) => {
    const username = req.query.username;
    res.json(friendRequests[username] || []);
});

app.post('/accept_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }
    res.json({ success: true });
});

app.post('/decline_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }
    res.json({ success: true });
});

// ==========================================
// ROTAS DE CHAT PRIVADO
// ==========================================

app.post('/send_message', (req, res) => {
    const { from, to, msg } = req.body;
    if (!from || !to || !msg) return res.status(400).send("Faltam dados");

    if (!pendingMessages[to]) pendingMessages[to] = {};
    if (!pendingMessages[to][from]) pendingMessages[to][from] = [];
    
    pendingMessages[to][from].push(msg);
    res.json({ success: true });
});

app.get('/get_messages', (req, res) => {
    const { from, to } = req.query;
    if (!from || !to) return res.json([]);

    if (pendingMessages[to] && pendingMessages[to][from]) {
        const msgs = pendingMessages[to][from];
        pendingMessages[to][from] = []; // Limpa da memória após o Lua puxar as mensagens
        return res.json(msgs);
    }
    res.json([]);
});

// ==========================================
// INICIALIZAÇÃO DO SERVIDOR
// ==========================================

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor do Chat Universal rodando na porta ${PORT}`);
});
