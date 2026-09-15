const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Memória temporária do servidor
const users = {}; 
const friendRequests = {}; 
const newFriendsQueue = {}; // Para avisar o usuário B que o usuário A aceitou o pedido
const pendingMessages = {}; 

// ==========================================
// ROTAS DE USUÁRIO E PERFIL
// ==========================================

app.post('/register', (req, res) => {
    const { username, displayName, userId } = req.body;
    if (!username) return res.status(400).send("Faltam dados");
    
    if (!users[username]) {
        users[username] = {
            username,
            displayName: displayName || username,
            userId: userId || 1,
            status: "Online",
            bio: "Adicionar bio+",
            friends: [] // Lista de amigos mútuos
        };
    } else {
        users[username].status = "Online";
        users[username].displayName = displayName || username;
    }
    res.json({ success: true });
});

app.get('/users', (req, res) => {
    const query = (req.query.query || "").toLowerCase();
    if (!query) return res.json([]);

    const results = [];
    for (const key in users) {
        if (key.toLowerCase().includes(query) || users[key].displayName.toLowerCase().includes(query)) {
            results.push(users[key]);
        }
    }
    res.json(results);
});

// Pegar dados do perfil (Bio, Amigos, etc)
app.get('/get_profile', (req, res) => {
    const username = req.query.username;
    if (users[username]) {
        res.json({
            bio: users[username].bio,
            friendsCount: users[username].friends.length
        });
    } else {
        res.json({ bio: "Adicionar bio+", friendsCount: 0 });
    }
});

// Atualizar a Bio
app.post('/update_bio', (req, res) => {
    const { username, bio } = req.body;
    if (users[username]) {
        users[username].bio = bio;
    }
    res.json({ success: true });
});

// ==========================================
// ROTAS DE STATUS E DIGITAÇÃO
// ==========================================

app.post('/set_status', (req, res) => {
    const { username, status } = req.body;
    if (users[username]) users[username].status = status;
    res.json({ success: true });
});

app.get('/get_status', (req, res) => {
    const username = req.query.username;
    res.json({ status: users[username] ? users[username].status : "Offline" });
});

// ==========================================
// ROTAS DE AMIZADE (COM CORREÇÃO DE SINCRONIA)
// ==========================================

app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (!friendRequests[to]) friendRequests[to] = [];
    const alreadySent = friendRequests[to].find(req => req.from === from);
    if (!alreadySent) {
        friendRequests[to].push({ from, fromDisplay, fromId });
    }
    res.json({ success: true });
});

app.get('/get_requests', (req, res) => {
    res.json(friendRequests[req.query.username] || []);
});

app.post('/accept_request', (req, res) => {
    const { user, friend } = req.body;
    
    // Remove o pedido da lista
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }

    // Adiciona na lista de amigos de ambos no servidor
    if (users[user] && !users[user].friends.includes(friend)) users[user].friends.push(friend);
    if (users[friend] && !users[friend].friends.includes(user)) users[friend].friends.push(user);

    // Coloca na fila para o 'friend' saber que foi aceito
    if (!newFriendsQueue[friend]) newFriendsQueue[friend] = [];
    if (!newFriendsQueue[friend].includes(user)) newFriendsQueue[friend].push(user);

    res.json({ success: true });
});

app.post('/remove_friend', (req, res) => {
    const { user, friend } = req.body;
    if (users[user]) users[user].friends = users[user].friends.filter(f => f !== friend);
    if (users[friend]) users[friend].friends = users[friend].friends.filter(f => f !== user);
    
    // Avisa o outro para remover também (usando comando via chat invisível)
    if (!pendingMessages[friend]) pendingMessages[friend] = {};
    if (!pendingMessages[friend][user]) pendingMessages[friend][user] = [];
    pendingMessages[friend][user].push({ action: "unfriend", sender: user, timestamp: Date.now() });

    res.json({ success: true });
});

app.post('/decline_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }
    res.json({ success: true });
});

// Rota para o usuário puxar quem aceitou ele
app.get('/get_new_friends', (req, res) => {
    const username = req.query.username;
    if (newFriendsQueue[username]) {
        const newlyAccepted = [...newFriendsQueue[username]];
        newFriendsQueue[username] = [];
        return res.json(newlyAccepted);
    }
    res.json([]);
});

// ==========================================
// ROTAS DE CHAT PRIVADO
// ==========================================

app.post('/send_message', (req, res) => {
    const { from, to, msg } = req.body;
    if (!pendingMessages[to]) pendingMessages[to] = {};
    if (!pendingMessages[to][from]) pendingMessages[to][from] = [];
    pendingMessages[to][from].push(msg);
    res.json({ success: true });
});

app.get('/get_messages', (req, res) => {
    const { from, to } = req.query;
    if (pendingMessages[to] && pendingMessages[to][from]) {
        const msgs = pendingMessages[to][from];
        pendingMessages[to][from] = []; 
        return res.json(msgs);
    }
    res.json([]);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => { console.log(`Servidor rodando na porta ${PORT}`); });
