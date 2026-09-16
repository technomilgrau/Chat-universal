const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// ==========================================
// BANCO DE DADOS EM MEMÓRIA
// ==========================================
const users = {}; // { username: { displayName, userId, status, bio, friends: [] } }
const friendRequests = {}; // { to: [{from, fromDisplay, fromId}] }
const pendingMessages = {}; // { to: { from: { msgs: [], edits: [], deletes: [] } } }
const globalEvents = {}; // { username: [ event1, event2 ] }
const pendingSyncs = {}; // { to: { from: historyArray } }

// ==========================================
// ROTAS DE USUÁRIO, PESQUISA E PERFIL
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
            bio: "",
            friends: []
        };
    } else {
        users[username].displayName = displayName || users[username].displayName;
        users[username].userId = userId || users[username].userId;
        users[username].status = "Online";
    }
    if (!globalEvents[username]) globalEvents[username] = [];
    res.json({ success: true });
});

app.get('/users', (req, res) => {
    const query = (req.query.query || "").toLowerCase();
    if (!query) return res.json([]);

    const results = [];
    for (const key in users) {
        if (key.toLowerCase().includes(query) || users[key].displayName.toLowerCase().includes(query)) {
            results.push({
                username: users[key].username,
                displayName: users[key].displayName,
                userId: users[key].userId,
                friendCount: users[key].friends.length
            });
        }
    }
    res.json(results);
});

app.get('/get_profile', (req, res) => {
    const username = req.query.username;
    if (users[username]) {
        res.json({
            username: users[username].username,
            displayName: users[username].displayName,
            userId: users[username].userId,
            bio: users[username].bio || "",
            friendCount: users[username].friends.length
        });
    } else {
        res.json(null);
    }
});

app.post('/update_bio', (req, res) => {
    const { username, bio } = req.body;
    if (users[username]) {
        users[username].bio = bio.substring(0, 80); // limite back-end
    }
    res.json({ success: true });
});

// ==========================================
// ROTAS DE STATUS E AMIZADES
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

app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (!friendRequests[to]) friendRequests[to] = [];
    if (users[from] && users[from].friends.includes(to)) return res.json({ success: false, reason: "Já são amigos" });

    const alreadySent = friendRequests[to].find(req => req.from === from);
    if (!alreadySent) {
        friendRequests[to].push({ from, fromDisplay: fromDisplay || from, fromId: fromId || 1 });
    }
    res.json({ success: true });
});

app.get('/get_requests', (req, res) => {
    res.json(friendRequests[req.query.username] || []);
});

app.post('/accept_request', (req, res) => {
    const { user, friend } = req.body;
    
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }
    
    // Adiciona para os dois lados
    if (users[user] && !users[user].friends.includes(friend)) users[user].friends.push(friend);
    if (users[friend] && !users[friend].friends.includes(user)) users[friend].friends.push(user);

    // Envia evento global para o amigo saber que foi aceito
    if (!globalEvents[friend]) globalEvents[friend] = [];
    globalEvents[friend].push({ type: 'friend_accept', username: user });

    res.json({ success: true });
});

app.post('/decline_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }
    res.json({ success: true });
});

app.post('/unfriend', (req, res) => {
    const { user, friend } = req.body;
    if (users[user]) users[user].friends = users[user].friends.filter(f => f !== friend);
    if (users[friend]) users[friend].friends = users[friend].friends.filter(f => f !== user);

    if (!globalEvents[friend]) globalEvents[friend] = [];
    globalEvents[friend].push({ type: 'unfriend', username: user });
    
    res.json({ success: true });
});

// ==========================================
// ROTAS DE CHAT E MENSAGENS (TEXTO, EDIT, DEL)
// ==========================================
app.post('/send_message', (req, res) => {
    const { from, to, msg } = req.body;
    if (!pendingMessages[to]) pendingMessages[to] = {};
    if (!pendingMessages[to][from]) pendingMessages[to][from] = { msgs: [], edits: [], deletes: [] };
    
    pendingMessages[to][from].msgs.push(msg);
    res.json({ success: true });
});

app.post('/edit_message', (req, res) => {
    const { from, to, msgId, newText } = req.body;
    if (!pendingMessages[to]) pendingMessages[to] = {};
    if (!pendingMessages[to][from]) pendingMessages[to][from] = { msgs: [], edits: [], deletes: [] };
    
    pendingMessages[to][from].edits.push({ msgId, newText });
    res.json({ success: true });
});

app.post('/delete_message', (req, res) => {
    const { from, to, msgId } = req.body;
    if (!pendingMessages[to]) pendingMessages[to] = {};
    if (!pendingMessages[to][from]) pendingMessages[to][from] = { msgs: [], edits: [], deletes: [] };
    
    pendingMessages[to][from].deletes.push(msgId);
    res.json({ success: true });
});

app.get('/get_messages', (req, res) => {
    const { from, to } = req.query;
    if (pendingMessages[to] && pendingMessages[to][from]) {
        const data = pendingMessages[to][from];
        pendingMessages[to][from] = { msgs: [], edits: [], deletes: [] };
        return res.json(data);
    }
    res.json({ msgs: [], edits: [], deletes: [] });
});

// ==========================================
// SINCRONIZAÇÃO E EVENTOS GLOBAIS
// ==========================================
app.get('/get_global_events', (req, res) => {
    const username = req.query.username;
    if (globalEvents[username] && globalEvents[username].length > 0) {
        const events = globalEvents[username];
        globalEvents[username] = [];
        return res.json(events);
    }
    res.json([]);
});

app.post('/request_sync', (req, res) => {
    const { from, to } = req.body;
    if (!globalEvents[to]) globalEvents[to] = [];
    globalEvents[to].push({ type: 'sync_request', username: from });
    res.json({ success: true });
});

app.post('/provide_sync', (req, res) => {
    const { from, to, history } = req.body;
    if (!pendingSyncs[to]) pendingSyncs[to] = {};
    pendingSyncs[to][from] = history;
    res.json({ success: true });
});

app.get('/get_sync', (req, res) => {
    const username = req.query.username;
    if (pendingSyncs[username]) {
        const data = pendingSyncs[username];
        pendingSyncs[username] = {};
        return res.json(data);
    }
    res.json({});
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
