const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Servidor Delta Avançado Ativo'));

const clients = new Map();
let nextGroupId = 1;

wss.on('connection', (ws) => {
    let currentUserId = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'register': {
                    currentUserId = String(data.userId);
                    clients.set(currentUserId, {
                        ws,
                        username: data.username,
                        groupId: null,
                        friends: new Set()
                    });
                    broadcastUserList();
                    break;
                }

                case 'friend_request': {
                    sendTo(data.targetId, { type: 'friend_request', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                }

                case 'friend_accept': {
                    const user = clients.get(currentUserId);
                    const target = clients.get(String(data.targetId));
                    if (user && target) {
                        user.friends.add(String(data.targetId));
                        target.friends.add(currentUserId);
                        sendTo(currentUserId, { type: 'chat', sender: 'Sistema', message: `Você e ${target.username} agora são amigos!` });
                        sendTo(data.targetId, { type: 'chat', sender: 'Sistema', message: `Você e ${user.username} agora são amigos!` });
                        broadcastUserList();
                    }
                    break;
                }

                case 'pair_request': {
                    sendTo(data.targetId, { type: 'pair_request', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                }

                case 'pair_accept': {
                    const user = clients.get(currentUserId);
                    const target = clients.get(String(data.targetId));

                    if (user && target) {
                        let groupId = user.groupId || target.groupId;
                        if (!groupId) {
                            groupId = `group_${nextGroupId++}`;
                        }
                        user.groupId = groupId;
                        target.groupId = groupId;

                        sendToGroup(groupId, { type: 'paired', groupId });
                        broadcastUserList();
                    }
                    break;
                }

                case 'unpair': {
                    const user = clients.get(currentUserId);
                    if (user && user.groupId) {
                        const oldGroup = user.groupId;
                        user.groupId = null;
                        sendTo(currentUserId, { type: 'unpaired' });
                        sendToGroup(oldGroup, { type: 'chat', sender: 'Sistema', message: `${user.username} saiu do grupo.` });
                        broadcastUserList();
                    }
                    break;
                }

                case 'chat': {
                    const user = clients.get(currentUserId);
                    if (user && user.groupId) {
                        sendToGroup(user.groupId, { type: 'chat', sender: user.username, message: data.message });
                    }
                    break;
                }

                case 'clone_request': {
                    sendTo(data.targetId, { type: 'clone_request', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                }

                case 'clone_accept': {
                    sendTo(data.targetId, { type: 'clone_start', targetId: currentUserId });
                    sendTo(currentUserId, { type: 'clone_start', targetId: data.targetId });
                    break;
                }

                case 'clone_cancel_request': {
                    sendTo(data.targetId, { type: 'clone_cancel_request', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                }

                case 'clone_cancel_accept': {
                    sendTo(data.targetId, { type: 'clone_stop', targetId: currentUserId });
                    sendTo(currentUserId, { type: 'clone_stop', targetId: data.targetId });
                    break;
                }

                case 'clone_sync': {
                    const user = clients.get(currentUserId);
                    if (user && user.groupId) {
                        sendToGroup(user.groupId, Object.assign(data, { fromId: currentUserId }), currentUserId);
                    }
                    break;
                }
            }
        } catch (err) {
            console.error('Erro:', err);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
            const user = clients.get(currentUserId);
            if (user && user.groupId) {
                sendToGroup(user.groupId, { type: 'chat', sender: 'Sistema', message: `${user.username} desconectou.` });
            }
            clients.delete(currentUserId);
            broadcastUserList();
        }
    });
});

function sendTo(userId, data) {
    const client = clients.get(String(userId));
    if (client && client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(JSON.stringify(data));
    }
}

function sendToGroup(groupId, data, excludeId = null) {
    const payload = JSON.stringify(data);
    clients.forEach((client, id) => {
        if (client.groupId === groupId && id !== excludeId && client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(payload);
        }
    });
}

function broadcastUserList() {
    const userList = [];
    clients.forEach((val, key) => {
        userList.push({
            userId: key,
            username: val.username,
            groupId: val.groupId,
            friends: Array.from(val.friends)
        });
    });

    const payload = JSON.stringify({ type: 'user_list', users: userList });
    clients.forEach((client) => {
        if (client.ws.readyState === WebSocket.OPEN) client.ws.send(payload);
    });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Rodando na porta ${PORT}`));
