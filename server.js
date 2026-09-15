const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// Armazenamento em memória (Dados Públicos e Relacionais)
const users = {}; 
const friendRequests = []; 
const messageQueue = {}; 
const syncRequests = {}; 

app.post('/register', (req, res) => {
    const { username, displayName, userId } = req.body;
    if (!users[username]) {
        users[username] = { username, displayName, userId, bio: "", friends: [], status: 'Online' };
    } else {
        users[username].displayName = displayName;
        users[username].userId = userId;
        users[username].status = 'Online';
    }
    res.json({ success: true });
});

app.get('/users', (req, res) => {
    const query = (req.query.query || '').toLowerCase();
    const results = Object.values(users)
        .filter(u => u.username.toLowerCase().includes(query) || u.displayName.toLowerCase().includes(query))
        .map(u => ({
            username: u.username,
            displayName: u.displayName,
            userId: u.userId
        }));
    res.json(results);
});

// Retorna dados do Perfil (contagem de amigos e bio)
app.get('/profile', (req, res) => {
    const { username } = req.query;
    const u = users[username];
    if (u) {
        res.json({
            username: u.username,
            displayName: u.displayName,
            userId: u.userId,
            bio: u.bio,
            friendCount: u.friends.length,
            friends: u.friends
        });
    } else {
        res.status(404).json({ error: 'User not found' });
    }
});

app.post('/update_bio', (req, res) => {
    const { username, bio } = req.body;
    if (users[username]) {
        users[username].bio = bio.substring(0, 80); // Limite 80 caracteres
        res.json({ success: true });
    } else {
        res.status(404).json({ error: 'User not found' });
    }
});

app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (users[to] && !users[to].friends.includes(from)) {
        const existing = friendRequests.find(r => r.from === from && r.to === to);
        if (!existing) {
            friendRequests.push({ from, fromDisplay, fromId, to });
        }
    }
    res.json({ success: true });
});

app.get('/get_requests', (req, res) => {
    const { username } = req.query;
    const reqs = friendRequests.filter(r => r.to === username);
    res.json(reqs);
});

// Garante amizade recíproca para os dois lados
app.post('/accept_request', (req, res) => {
    const { user, friend } = req.body;
    const index = friendRequests.findIndex(r => r.from === friend && r.to === user);
    if (index !== -1) friendRequests.splice(index, 1);
    
    if (users[user] && !users[user].friends.includes(friend)) users[user].friends.push(friend);
    if (users[friend] && !users[friend].friends.includes(user)) users[friend].friends.push(user);
    
    res.json({ success: true });
});

app.post('/decline_request', (req, res) => {
    const { user, friend } = req.body;
    const index = friendRequests.findIndex(r => r.from === friend && r.to === user);
    if (index !== -1) friendRequests.splice(index, 1);
    res.json({ success: true });
});

app.post('/remove_friend', (req, res) => {
    const { user, friend } = req.body;
    if (users[user]) users[user].friends = users[user].friends.filter(f => f !== friend);
    if (users[friend]) users[friend].friends = users[friend].friends.filter(f => f !== user);
    res.json({ success: true });
});

app.get('/check_friendship', (req, res) => {
    const { user, friend } = req.query;
    let status = 'none';
    if (users[user] && users[user].friends.includes(friend)) {
        status = 'friends';
    } else if (friendRequests.find(r => r.from === user && r.to === friend)) {
        status = 'pending_sent';
    } else if (friendRequests.find(r => r.from === friend && r.to === user)) {
        status = 'pending_received';
    }
    res.json({ status });
});

// Transmissão de Mensagens
app.post('/send_message', (req, res) => {
    const { from, to, msg } = req.body;
    if (!messageQueue[to]) messageQueue[to] = [];
    messageQueue[to].push({ ...msg, to, isAction: false, isSync: false });
    res.json({ success: true });
});

app.post('/message_action', (req, res) => {
    const { from, to, msgId, action, newText } = req.body;
    if (!messageQueue[to]) messageQueue[to] = [];
    messageQueue[to].push({ isAction: true, action, msgId, newText, from, to });
    res.json({ success: true });
});

// Sincronização/Recuperação de Histórico
app.post('/request_sync', (req, res) => {
    const { from, to } = req.body;
    if (!syncRequests[to]) syncRequests[to] = [];
    syncRequests[to].push({ from });
    res.json({ success: true });
});

app.get('/get_sync_requests', (req, res) => {
    const { user } = req.query;
    const reqs = syncRequests[user] || [];
    syncRequests[user] = [];
    res.json(reqs);
});

app.post('/send_sync_data', (req, res) => {
    const { from, to, history } = req.body;
    if (!messageQueue[to]) messageQueue[to] = [];
    messageQueue[to].push({ isSync: true, history, from });
    res.json({ success: true });
});

app.get('/get_messages', (req, res) => {
    const { to } = req.query;
    if (messageQueue[to] && messageQueue[to].length > 0) {
        const msgs = [...messageQueue[to]];
        messageQueue[to] = [];
        res.json(msgs);
    } else {
        res.json([]);
    }
});

app.post('/set_status', (req, res) => {
    const { username, status } = req.body;
    if (users[username]) users[username].status = status;
    res.json({ success: true });
});

app.get('/get_status', (req, res) => {
    const { username } = req.query;
    res.json({ status: users[username] ? users[username].status : 'Offline' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
