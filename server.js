const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Servidor Delta Universal Ativo'));

const clients = new Map();
const groups = new Map(); // id_grupo -> { owner, members: Set, bans: Set }

// Heartbeat para evitar que a Render feche a conexão por inatividade
const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) return ws.terminate();
        ws.isAlive = false;
        ws.ping();
    });
}, 30000);

wss.on('connection', (ws) => {
    let currentUserId = null;
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'register':
                    currentUserId = String(data.userId);
                    clients.set(currentUserId, { ws, username: data.username, activeChat: null });
                    broadcastUserList();
                    break;

                // Sistema de Amizades
                case 'friend_request':
                case 'friend_accept':
                case 'friend_decline':
                    sendTo(data.targetId, data);
                    break;

                // Bate-papo 1x1
                case 'chat_invite':
                case 'chat_accept':
                case 'chat_leave':
                    sendTo(data.targetId, data);
                    break;

                case 'chat_message':
                    // Envia para o alvo (DM) ou processa para o Grupo
                    if (data.groupId) {
                        const group = groups.get(data.groupId);
                        if (group) {
                            group.members.forEach(memberId => {
                                sendTo(memberId, data);
                            });
                        }
                    } else if (data.targetId) {
                        sendTo(data.targetId, data);
                        sendTo(currentUserId, data); // Retorna para o próprio usuário processar no json local
                    }
                    break;

                // Grupos
                case 'group_create':
                    groups.set(data.groupId, { 
                        owner: currentUserId, 
                        members: new Set([currentUserId]),
                        bans: new Set()
                    });
                    break;
                    
                case 'group_invite':
                    if (groups.has(data.groupId) && !groups.get(data.groupId).bans.has(data.targetId)) {
                        sendTo(data.targetId, data);
                    }
                    break;

                case 'group_join':
                    if (groups.has(data.groupId)) {
                        groups.get(data.groupId).members.add(currentUserId);
                        broadcastToGroup(data.groupId, { type: 'group_sys_msg', msg: `${clients.get(currentUserId).username} entrou no grupo.` });
                    }
                    break;
                    
                case 'group_kick':
                case 'group_ban':
                    if (groups.has(data.groupId) && groups.get(data.groupId).owner === currentUserId) {
                        groups.get(data.groupId).members.delete(data.targetId);
                        if (data.type === 'group_ban') groups.get(data.groupId).bans.add(data.targetId);
                        sendTo(data.targetId, { type: 'group_kicked', groupId: data.groupId });
                    }
                    break;

                // Sistema de Clone R6/R15 e Animações
                case 'clone_invite':
                case 'clone_accept':
                case 'clone_cancel':
                    sendTo(data.targetId, data);
                    break;

                case 'sync_clone':
                    sendTo(data.targetId, data); // Roteamento ultrarrápido dos dados JSON e CFrame
                    break;
            }
        } catch (err) {
            console.error('Erro:', err);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
            clients.delete(currentUserId);
            // Remove de grupos
            groups.forEach((group, groupId) => {
                group.members.delete(currentUserId);
            });
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

function broadcastToGroup(groupId, data) {
    const group = groups.get(groupId);
    if (!group) return;
    group.members.forEach(memberId => sendTo(memberId, data));
}

function broadcastUserList() {
    const userList = [];
    clients.forEach((val, key) => {
        userList.push({ userId: key, username: val.username });
    });
    const payload = JSON.stringify({ type: 'user_list', users: userList });
    clients.forEach(client => {
        if (client.ws.readyState === WebSocket.OPEN) client.ws.send(payload);
    });
}

server.on('close', () => clearInterval(interval));
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Delta Node rodando na porta ${PORT}`));
