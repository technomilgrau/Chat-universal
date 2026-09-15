const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const users = {}; 
const friendRequests = {}; 
const pendingMessages = {}; 
const profiles = {}; // Armazena bios e lista de amigos { bio: "", friends: [] }

// ==========================================
// ROTAS DE USUÁRIO E PERFIL
// ==========================================
app.post('/register', (req, res) => {
    const { username, displayName, userId } = req.body;
    if (!username) return res.status(400).send("Faltam dados");
    
    users[username] = { username, displayName: displayName || username, userId: userId || 1, status: "Online" };
    if (!profiles[username]) profiles[username] = { bio: "", friends: [] };
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

app.get('/get_profile', (req, res) => {
    const { target } = req.query;
    if (!profiles[target]) return res.json({ bio: "", friendsCount: 0 });
    res.json({ bio: profiles[target].bio, friendsCount: profiles[target].friends.length });
});

app.post('/update_bio', (req, res) => {
    const { username, bio } = req.body;
    if (profiles[username]) profiles[username].bio = bio.substring(0, 80);
    res.json({ success: true });
});

// ==========================================
// ROTAS DE STATUS
// ==========================================
app.post('/set_status', (req, res) => {
    const { username, status } = req.body;
    if (users[username]) users[username].status = status;
    res.json({ success: true });
});

app.get('/get_status', (req, res) => {
    const status = users[req.query.username] ? users[req.query.username].status : "Offline";
    res.json({ status });
});

// ==========================================
// ROTAS DE AMIZADE
// ==========================================
app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (!friendRequests[to]) friendRequests[to] = [];
    if (!friendRequests[to].find(req => req.from === from)) {
        friendRequests[to].push({ from, fromDisplay: fromDisplay || from, fromId: fromId || 1 });
    }
    res.json({ success: true });
});

app.get('/get_requests', (req, res) => res.json(friendRequests[req.query.username] || []));

app.post('/accept_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    
    // Adiciona amizade mútua
    if (profiles[user] && !profiles[user].friends.includes(friend)) profiles[user].friends.push(friend);
    if (profiles[friend] && !profiles[friend].friends.includes(user)) profiles[friend].friends.push(user);
    res.json({ success: true });
});

app.post('/decline_request', (req, res) => {
    const { user, friend } = req.body;
    if (friendRequests[user]) friendRequests[user] = friendRequests[user].filter(r => r.from !== friend);
    res.json({ success: true });
});

app.post('/remove_friend', (req, res) => {
    const { user, friend } = req.body;
    if (profiles[user]) profiles[user].friends = profiles[user].friends.filter(f => f !== friend);
    if (profiles[friend]) profiles[friend].friends = profiles[friend].friends.filter(f => f !== user);
    res.json({ success: true });
});

app.get('/get_friends', (req, res) => {
    res.json(profiles[req.query.username] ? profiles[req.query.username].friends : []);
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
app.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
