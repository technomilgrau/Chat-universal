const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const users = {}; 
const friendRequests = {}; 
const pendingMessages = {}; 
const pendingActions = {}; // Para edições e exclusões de mensagens

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
            friends: [] // Armazena amigos confirmados
        };
    } else {
        users[username].status = "Online";
    }
    res.json({ success: true, user: users[username] });
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

app.post('/update_bio', (req, res) => {
    const { username, bio } = req.body;
    if (users[username]) {
        users[username].bio = bio.substring(0, 80); // Limite de 80 caracteres
    }
    res.json({ success: true });
});

app.post('/set_status', (req, res) => {
    const { username, status } = req.body;
    if (users[username]) users[username].status = status;
    res.json({ success: true });
});

app.get('/get_status', (req, res) => {
    const username = req.query.username;
    const status = users[username] ? users[username].status : "Offline";
    res.json({ status });
});

app.post('/send_request', (req, res) => {
    const { from, fromDisplay, fromId, to } = req.body;
    if (!from || !to) return res.status(400).send("Faltam dados");

    if (!friendRequests[to]) friendRequests[to] = [];
    if (!friendRequests[to].find(r => r.from === from)) {
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
    // Adiciona na lista de ambos (Amizade mútua)
    if (users[user] && !users[user].friends.includes(friend)) users[user].friends.push(friend);
    if (users[friend] && !users[friend].friends.includes(user)) users[friend].friends.push(user);
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
    res.json({ success: true });
});

app.post('/send_message', (req, res) => {
    const { from, to, msg } = req.body;
    if (!pendingMessages[to]) pendingMessages[to] = {};
    if (!pendingMessages[to][from]) pendingMessages[to][from] = [];
    pendingMessages[to][from].push(msg);
    res.json({ success: true });
});

app.post('/message_action', (req, res) => {
    const { from, to, action, msgId, newText } = req.body;
    if (!pendingActions[to]) pendingActions[to] = {};
    if (!pendingActions[to][from]) pendingActions[to][from] = [];
    pendingActions[to][from].push({ action, msgId, newText });
    res.json({ success: true });
});

app.get('/get_messages', (req, res) => {
    const { from, to } = req.query;
    let msgs = [];
    let actions = [];
    if (pendingMessages[to] && pendingMessages[to][from]) {
        msgs = [...pendingMessages[to][from]];
        pendingMessages[to][from] = [];
    }
    if (pendingActions[to] && pendingActions[to][from]) {
        actions = [...pendingActions[to][from]];
        pendingActions[to][from] = [];
    }
    res.json({ messages: msgs, actions: actions });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
