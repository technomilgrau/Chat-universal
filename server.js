const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Servidor Delta de Pareamento Ativo'));

// Armazena usuários ativos: userId -> { ws, username, pairedWith }
const clients = new Map();

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
                        pairedWith: null
                    });
                    broadcastUserList();
                    break;
                }

                case 'pair': {
                    const targetId = String(data.targetId);
                    const user = clients.get(currentUserId);
                    const target = clients.get(targetId);

                    if (user && target && !user.pairedWith && !target.pairedWith) {
                        user.pairedWith = targetId;
                        target.pairedWith = currentUserId;

                        sendTo(currentUserId, { type: 'paired', targetId, targetName: target.username });
                        sendTo(targetId, { type: 'paired', targetId: currentUserId, targetName: user.username });

                        broadcastUserList();
                    }
                    break;
                }

                case 'unpair': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith) {
                        const targetId = user.pairedWith;
                        const target = clients.get(targetId);

                        user.pairedWith = null;
                        if (target) target.pairedWith = null;

                        sendTo(currentUserId, { type: 'unpaired' });
                        if (targetId) sendTo(targetId, { type: 'unpaired' });

                        broadcastUserList();
                    }
                    break;
                }

                case 'chat': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith) {
                        const payload = {
                            type: 'chat',
                            sender: user.username,
                            message: data.message
                        };
                        sendTo(currentUserId, payload);
                        sendTo(user.pairedWith, payload);
                    }
                    break;
                }

                case 'request_bring': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith && data.position) {
                        sendTo(user.pairedWith, {
                            type: 'teleport_to',
                            position: data.position
                        });
                    }
                    break;
                }
            }
        } catch (err) {
            console.error('Erro de processamento:', err);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
            const user = clients.get(currentUserId);
            if (user && user.pairedWith) {
                const target = clients.get(user.pairedWith);
                if (target) target.pairedWith = null;
                sendTo(user.pairedWith, { type: 'unpaired' });
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

function broadcastUserList() {
    const userList = [];
    clients.forEach((val, key) => {
        userList.push({
            userId: key,
            username: val.username,
            paired: !!val.pairedWith
        });
    });

    const payload = JSON.stringify({ type: 'user_list', users: userList });
    clients.forEach((client) => {
        if (client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(payload);
        }
    });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
