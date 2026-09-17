const express = require('express');
const app = express();
app.use(express.json());

const users = {}; 
const pendingMessages = {}; 
const pendingEdits = {}; 
const pendingDeletes = {}; 
const friendRequests = {}; 
const friends = {}; 
const typingStatus = {}; 
const syncRequests = {}; 
const syncResponses = {}; 

function ensureQueues(username) {
    if (!pendingMessages[username]) pendingMessages[username] = [];
    if (!pendingEdits[username]) pendingEdits[username] = [];
    if (!pendingDeletes[username]) pendingDeletes[username] = [];
    if (!friendRequests[username]) friendRequests[username] = [];
    if (!friends[username]) friends[username] = new Set();
    if (!syncRequests[username]) syncRequests[username] = [];
    if (!syncResponses[username]) syncResponses[username] = {};
}

app.post('/register', (req, res) => {
    const { username, displayName, userId } = req.body;
    if (!username) return res.status(400).json({ error: 'Username obrigatorio' });
    ensureQueues(username);
    users[username] = {
        displayName: displayName || username,
        userId: userId || 1,
        lastSeen: Date.now(),
        bio: users[username]?.bio || ''
    };
    res.json({ success: true });
});

app.post('/heartbeat', (req, res) => {
    const { username } = req.body;
    if (username && users[username]) {
        users[username].lastSeen = Date.now();
    }
    res.json({ success: true });
});

app.get('/get_status', (req, res) => {
    const { username, viewer } = req.query;
    if (!username) return res.json({ status: 'Offline' });
    
    const typingKey = `${username}_${viewer}`;
    if (typingStatus[typingKey] && Date.now() - typingStatus[typingKey] < 3000) {
        return res.json({ status: 'Digitando...' });
    }
    
    const user = users[username];
    if (user && Date.now() - user.lastSeen < 12000) {
        return res.json({ status: 'Online' });
    }
    return res.json({ status: 'Offline' });
});

app.post('/set_typing', (req, res) => {
    const { from, to } = req.body;
    if (from && to) {
        typingStatus[`${from}_${to}`] = Date.now();
    }
    res.json({ success: true });
});

app.get('/get_profile', (req, res) => {
    const { username } = req.query;
    const user = users[username] || { displayName: username, userId: 1, bio: '', lastSeen: 0 };
    const friendCount = friends[username] ? friends[username].size : 0;
    res.json({
        username,
        displayName: user.displayName,
        userId: user.userId,
        bio: user.bio || '',
        friendCount
    });
});

app.post('/update_bio', (req, res) => {
    const { username, bio } = req.body;
    if (username && users[username]) {
        users[username].bio = bio || '';
    }
    res.json({ success: true });
});

app.post('/send_message', (req, res) => {
    const { from, to, msg } = req.body;
    if (!to || !msg) return res.status(400).json({ error: 'Dados invalidos' });
    ensureQueues(to);
    pendingMessages[to].push(msg);
    res.json({ success: true });
});

// Endpoint legado mantido por compatibilidade
app.get('/get_messages', (req, res) => {
    const { from, to } = req.query;
    if (!to || !from) return res.json({ msgs: [], edits: [], deletes: [] });
    ensureQueues(to);

    const msgsForTo = pendingMessages[to].filter(m => m.sender === from);
    pendingMessages[to] = pendingMessages[to].filter(m => m.sender !== from);

    const editsForTo = pendingEdits[to].filter(e => e.sender === from);
    pendingEdits[to] = pendingEdits[to].filter(e => e.sender !== from);

    const deletesForTo = pendingDeletes[to].filter(d => d.sender === from);
    pendingDeletes[to] = pendingDeletes[to].filter(d => d.sender !== from);

    res.json({ msgs: msgsForTo, edits: editsForTo, deletes: deletesForTo.map(d => d.msgId) });
});

// === NOVOS ENDPOINTS: Sistema Avançado de Fila Temporária ===
app.get('/get_all_pending', (req, res) => {
    const { to } = req.query;
    if (!to) return res.json({ msgs: [], edits: [], deletes: [] });
    ensureQueues(to);
    res.json({
        msgs: pendingMessages[to] || [],
        edits: pendingEdits[to] || [],
        deletes: pendingDeletes[to] || []
    });
});

app.post('/ack_all_pending', (req, res) => {
    const { to, msgIds, editIds, deleteIds } = req.body;
    if (to) {
        ensureQueues(to);
        if (msgIds && msgIds.length > 0) {
            pendingMessages[to] = pendingMessages[to].filter(m => !msgIds.includes(m.id));
        }
        if (editIds && editIds.length > 0) {
            pendingEdits[to] = pendingEdits[to].filter(e => !editIds.includes(e.msgId));
        }
        if (deleteIds && deleteIds.length > 0) {
            pendingDeletes[to] = pendingDeletes[to].filter(d => !deleteIds.includes(d.msgId));
        }
    }
    res.json({success: true});
});
// =========================================================

app.post('/edit_message', (req, res) => {
    const { from, to, msgId, newText } = req.body;
    if (to && msgId) {
        ensureQueues(to);
        pendingEdits[to].push({ msgId, newText, sender: from });
    }
    res.json({ success: true });
});

app.post('/delete_message', (req, res) => {
    const { from, to, msgId } = req.body;
    if (to && msgId) {
        ensureQueues(to);
        pendingDeletes[to].push({ msgId, sender: from });
    }
    res.json({ success: true });
});

app.get('/users', (req, res) => {
    const query = (req.query.query || '').toLowerCase();
    const result = Object.keys(users)
        .filter(u => u.toLowerCase().includes(query) || users[u].displayName.toLowerCase().includes(query))
        .map(u => ({ username: u, displayName: users[u].displayName, userId: users[u].userId }));
    res.json(result);
});

app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (to) {
        ensureQueues(to);
        if (!friendRequests[to].some(r => r.from === from)) {
            friendRequests[to].push({ from, fromDisplay, fromId });
        }
    }
    res.json({ success: true });
});

app.get('/get_requests', (req, res) => {
    const { username } = req.query;
    ensureQueues(username);
    res.json(friendRequests[username] || []);
});

app.post('/accept_request', (req, res) => {
    const { user, friend } = req.body;
    ensureQueues(user); ensureQueues(friend);
    friends[user].add(friend);
    friends[friend].add(user);
    friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    res.json({ success: true });
});

app.post('/decline_request', (req, res) => {
    const { user, friend } = req.body;
    ensureQueues(user);
    friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    res.json({ success: true });
});

app.post('/unfriend', (req, res) => {
    const { user, friend } = req.body;
    if (friends[user]) friends[user].delete(friend);
    if (friends[friend]) friends[friend].delete(user);
    res.json({ success: true });
});

app.get('/get_global_events', (req, res) => {
    const { username } = req.query;
    ensureQueues(username);
    const events = [];
    if (syncRequests[username] && syncRequests[username].length > 0) {
        while (syncRequests[username].length > 0) {
            const reqItem = syncRequests[username].shift();
            events.push({ type: 'sync_request', username: reqItem.from });
        }
    }
    res.json(events);
});

app.post('/request_sync', (req, res) => {
    const { from, to } = req.body;
    ensureQueues(to);
    syncRequests[to].push({ from });
    res.json({ success: true });
});

app.post('/provide_sync', (req, res) => {
    const { from, to, history } = req.body;
    ensureQueues(to);
    syncResponses[to][from] = history;
    res.json({ success: true });
});

app.get('/get_sync', (req, res) => {
    const { username } = req.query;
    ensureQueues(username);
    const data = syncResponses[username] || {};
    syncResponses[username] = {};
    res.json(data);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
