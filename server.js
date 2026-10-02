const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Armazenamento temporário em memória
const users = {};          // username -> profile
const friendRequests = {}; // username -> [ requests ]
const typingStatus = {};   // key -> timestamp
const pendingMessages = {};// username -> [ msgs ]
const pendingEdits = {};   // username -> [ edits ]
const pendingDeletes = {}; // username -> [ deletes ]
const globalEvents = {};   // username -> [ events ]
const syncData = {};       // username -> { friend: history }

// Rota raiz
app.get('/', (req, res) => {
    res.send('Servidor Chat-Universal Online! 🚀');
});

// Registro do Usuário
app.post('/register', (req, res) => {
    const { username, displayName, userId } = req.body;
    if (!username) return res.status(400).json({ error: 'Username obrigatório' });

    if (!users[username]) {
        users[username] = {
            username,
            displayName: displayName || username,
            userId: userId || 1,
            bio: '',
            lastSeen: Date.now(),
            friends: []
        };
    } else {
        users[username].displayName = displayName || users[username].displayName;
        users[username].userId = userId || users[username].userId;
        users[username].lastSeen = Date.now();
    }

    res.json({ success: true, user: users[username] });
});

// Heartbeat de Presença
app.post('/heartbeat', (req, res) => {
    const { username } = req.body;
    if (username && users[username]) {
        users[username].lastSeen = Date.now();
    }
    res.json({ success: true });
});

// Atualizar Biografia
app.post('/update_bio', (req, res) => {
    const { username, bio } = req.body;
    if (username && users[username]) {
        users[username].bio = bio || '';
        return res.json({ success: true });
    }
    res.status(400).json({ error: 'Usuário não encontrado' });
});

// Obter Perfil
app.get('/get_profile', (req, res) => {
    const { username } = req.query;
    if (users[username]) {
        const u = users[username];
        return res.json({
            username: u.username,
            displayName: u.displayName,
            userId: u.userId,
            bio: u.bio || '',
            friendCount: u.friends.length
        });
    }
    res.status(404).json({ error: 'Usuário não encontrado' });
});

// Pesquisar Usuários
app.get('/users', (req, res) => {
    const query = (req.query.query || '').toLowerCase();
    const result = [];
    for (const u of Object.values(users)) {
        if (u.username.toLowerCase().includes(query) || u.displayName.toLowerCase().includes(query)) {
            result.push({
                username: u.username,
                displayName: u.displayName,
                userId: u.userId
            });
        }
    }
    res.json(result);
});

// Enviar Solicitação de Amizade
app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (!to || !from) return res.status(400).json({ error: 'Parâmetros ausentes' });

    if (!friendRequests[to]) friendRequests[to] = [];
    const exists = friendRequests[to].some(r => r.from === from);
    if (!exists) {
        friendRequests[to].push({ from, fromDisplay, fromId });
    }
    res.json({ success: true });
});

// Obter Solicitações de Amizade
app.get('/get_requests', (req, res) => {
    const { username } = req.query;
    res.json(friendRequests[username] || []);
});

// Aceitar Amizade
app.post('/accept_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }

    if (users[user] && !users[user].friends.includes(friend)) {
        users[user].friends.push(friend);
    }
    if (users[friend] && !users[friend].friends.includes(user)) {
        users[friend].friends.push(user);
    }

    if (!globalEvents[friend]) globalEvents[friend] = [];
    globalEvents[friend].push({ type: 'friend_accept', username: user });

    res.json({ success: true });
});

// Recusar Amizade
app.post('/decline_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) {
        friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    }
    res.json({ success: true });
});

// Desfazer Amizade
app.post('/unfriend', (req, res) => {
    const { user, friend } = req.body;
    if (users[user]) users[user].friends = users[user].friends.filter(f => f !== friend);
    if (users[friend]) users[friend].friends = users[friend].friends.filter(f => f !== user);

    if (!globalEvents[friend]) globalEvents[friend] = [];
    globalEvents[friend].push({ type: 'unfriend', username: user });

    res.json({ success: true });
});

// Obter Status do Usuário
app.get('/get_status', (req, res) => {
    const { username, viewer } = req.query;
    if (!users[username]) return res.json({ status: 'Offline' });

    const now = Date.now();
    const isOnline = (now - users[username].lastSeen) < 15000;

    const key = `${username}_${viewer}`;
    const lastType = typingStatus[key] || 0;
    const isTyping = (now - lastType) < 4000;

    if (isTyping) return res.json({ status: 'Digitando...' });
    if (isOnline) return res.json({ status: 'Online' });
    return res.json({ status: 'Offline' });
});

// Definir Digitando
app.post('/set_typing', (req, res) => {
    const { from, to } = req.body;
    if (from && to) {
        typingStatus[`${from}_${to}`] = Date.now();
    }
    res.json({ success: true });
});

// Enviar Mensagem / Figurinha (Adiciona à Fila Offline Temporária)
app.post('/send_message', (req, res) => {
    const { from, to, msg } = req.body;
    if (!to || !msg) return res.status(400).json({ error: 'Parâmetros ausentes' });

    if (!pendingMessages[to]) pendingMessages[to] = [];
    pendingMessages[to].push(msg);

    res.json({ success: true });
});

// Editar Mensagem
app.post('/edit_message', (req, res) => {
    const { from, to, msgId, newText } = req.body;
    if (!pendingEdits[to]) pendingEdits[to] = [];
    pendingEdits[to].push({ sender: from, msgId, newText });
    res.json({ success: true });
});

// Apagar Mensagem
app.post('/delete_message', (req, res) => {
    const { from, to, msgId } = req.body;
    if (!pendingDeletes[to]) pendingDeletes[to] = [];
    pendingDeletes[to].push({ sender: from, msgId });
    res.json({ success: true });
});

// Obter Todos os Pendentes (Fila Offline)
app.get('/get_all_pending', (req, res) => {
    const { to } = req.query;
    res.json({
        msgs: pendingMessages[to] || [],
        edits: pendingEdits[to] || [],
        deletes: pendingDeletes[to] || []
    });
});

// Confirmar Recebimento (Apaga da Render após Usuário Receber)
app.post('/ack_all_pending', (req, res) => {
    const { to, msgIds, editIds, deleteIds } = req.body;

    if (pendingMessages[to] && Array.isArray(msgIds)) {
        pendingMessages[to] = pendingMessages[to].filter(m => !msgIds.includes(m.id));
    }
    if (pendingEdits[to] && Array.isArray(editIds)) {
        pendingEdits[to] = pendingEdits[to].filter(e => !editIds.includes(e.msgId));
    }
    if (pendingDeletes[to] && Array.isArray(deleteIds)) {
        pendingDeletes[to] = pendingDeletes[to].filter(d => !deleteIds.includes(d.msgId));
    }

    res.json({ success: true });
});

// Eventos Globais
app.get('/get_global_events', (req, res) => {
    const { username } = req.query;
    const events = globalEvents[username] || [];
    globalEvents[username] = [];
    res.json(events);
});

// Pedir Sincronização
app.post('/request_sync', (req, res) => {
    const { from, to } = req.body;
    if (!globalEvents[to]) globalEvents[to] = [];
    globalEvents[to].push({ type: 'sync_request', username: from });
    res.json({ success: true });
});

// Fornecer Sincronização
app.post('/provide_sync', (req, res) => {
    const { from, to, history } = req.body;
    if (!syncData[to]) syncData[to] = {};
    syncData[to][from] = history;
    res.json({ success: true });
});

// Obter Sincronização
app.get('/get_sync', (req, res) => {
    const { username } = req.query;
    const data = syncData[username] || {};
    syncData[username] = {};
    res.json(data);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Servidor Chat Universal rodando na porta ${PORT}`);
});
