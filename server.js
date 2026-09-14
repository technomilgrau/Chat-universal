const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Delta Advanced Pairing Server Ativo'));

// Estruturas de Dados
const clients = new Map(); // userId -> ws, username
const friends = new Map(); // userId -> Set(friendIds)
const groups = new Map(); // groupId -> { name, owner, members: Set() }

wss.on('connection', (ws) => {
    let currentUserId = null;
    
    // SISTEMA ANTI-DESCONEXÃO (Keep-Alive para a Render)
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'register': {
                    currentUserId = String(data.userId);
                    clients.set(currentUserId, { ws, username: data.username, activeChat: null, activeGroup: null });
                    if (!friends.has(currentUserId)) friends.set(currentUserId, new Set());
                    broadcastUsers();
                    console.log(`[+] Usuário conectado: ${data.username} (${currentUserId})`);
                    break;
                }

                // --- SISTEMA DE AMIZADES ---
                case 'friend_request': {
                    sendTo(data.targetId, { type: 'notification', notifType: 'friend_request', senderId: currentUserId, senderName: clients.get(currentUserId).username });
                    break;
                }
                case 'friend_accept': {
                    friends.get(currentUserId).add(String(data.targetId));
                    if (!friends.has(String(data.targetId))) friends.set(String(data.targetId), new Set());
                    friends.get(String(data.targetId)).add(currentUserId);
                    sendTo(data.targetId, { type: 'friend_added', friendId: currentUserId, friendName: clients.get(currentUserId).username });
                    sendTo(currentUserId, { type: 'friend_added', friendId: data.targetId, friendName: data.targetName });
                    break;
                }

                // --- BATE-PAPO PRIVADO (1v1) ---
                case 'chat_invite': {
                    sendTo(data.targetId, { type: 'notification', notifType: 'chat_invite', senderId: currentUserId, senderName: clients.get(currentUserId).username });
                    break;
                }
                case 'chat_accept': {
                    const me = clients.get(currentUserId);
                    const host = clients.get(data.hostId);
                    if (me && host) {
                        me.activeChat = data.hostId;
                        host.activeChat = data.hostId; // O host é dono da sala
                        sendTo(currentUserId, { type: 'chat_connected', hostId: data.hostId, hostName: host.username });
                        sendTo(data.hostId, { type: 'chat_joined', userId: currentUserId, userName: me.username });
                    }
                    break;
                }
                case 'chat_leave': {
                    const me = clients.get(currentUserId);
                    if (me && me.activeChat) {
                        sendTo(me.activeChat, { type: 'system_message', text: `${me.username} saiu do chat.` });
                        me.activeChat = null;
                    }
                    break;
                }

                // --- GRUPOS ---
                case 'group_create': {
                    const groupId = 'gp_' + Date.now();
                    groups.set(groupId, { name: data.name, owner: currentUserId, members: new Set([currentUserId]) });
                    clients.get(currentUserId).activeGroup = groupId;
                    sendTo(currentUserId, { type: 'group_created', groupId, name: data.name });
                    break;
                }
                case 'group_invite': {
                    sendTo(data.targetId, { type: 'notification', notifType: 'group_invite', groupId: data.groupId, groupName: data.groupName, senderName: clients.get(currentUserId).username });
                    break;
                }
                case 'group_accept': {
                    const gp = groups.get(data.groupId);
                    if (gp) {
                        gp.members.add(currentUserId);
                        clients.get(currentUserId).activeGroup = data.groupId;
                        gp.members.forEach(m => sendTo(m, { type: 'group_update', groupId: data.groupId, members: Array.from(gp.members) }));
                    }
                    break;
                }
                case 'group_action': { // Kick, Ban, Delete
                    const gp = groups.get(data.groupId);
                    if (gp && gp.owner === currentUserId) {
                        if (data.action === 'delete') {
                            gp.members.forEach(m => {
                                clients.get(m).activeGroup = null;
                                sendTo(m, { type: 'group_deleted' });
                            });
                            groups.delete(data.groupId);
                        } else if (data.action === 'kick' || data.action === 'ban') {
                            gp.members.delete(data.targetId);
                            clients.get(data.targetId).activeGroup = null;
                            sendTo(data.targetId, { type: 'group_kicked' });
                            gp.members.forEach(m => sendTo(m, { type: 'system_message', text: `${data.targetName} foi removido do grupo.` }));
                        }
                    }
                    break;
                }

                // --- MENSAGENS E STICKERS ---
                case 'send_message': {
                    const payload = { type: 'message', senderId: currentUserId, senderName: clients.get(currentUserId).username, content: data.content, isSticker: data.isSticker };
                    
                    if (data.context === 'private') {
                        const hostId = clients.get(currentUserId).activeChat;
                        if (hostId) {
                            sendTo(hostId, payload); // Envia pro host
                            // O host precisa repassar se houver outra pessoa
                            clients.forEach((c, id) => { if (c.activeChat === hostId && id !== hostId) sendTo(id, payload); });
                        }
                    } else if (data.context === 'group') {
                        const gp = groups.get(data.groupId);
                        if (gp) {
                            gp.members.forEach(m => sendTo(m, payload));
                        }
                    }
                    break;
                }

                // --- SISTEMA DE CLONE ---
                case 'clone_request': {
                    sendTo(data.targetId, { type: 'notification', notifType: 'clone_request', senderId: currentUserId, senderName: clients.get(currentUserId).username });
                    break;
                }
                case 'clone_accept': {
                    sendTo(data.hostId, { type: 'clone_start', targetId: currentUserId });
                    sendTo(currentUserId, { type: 'clone_start', targetId: data.hostId });
                    break;
                }
                case 'clone_sync': {
                    // Repassa dados de animação e CFrame
                    sendTo(data.targetId, { type: 'clone_update', cframe: data.cframe, anims: data.anims, senderId: currentUserId });
                    break;
                }
            }
        } catch (err) {
            console.error("[!] Erro ao processar mensagem do WebSocket:", err);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
            const username = clients.get(currentUserId)?.username || "Desconhecido";
            console.log(`[-] Usuário desconectado: ${username} (${currentUserId})`);
            clients.delete(currentUserId);
            broadcastUsers();
        }
    });
});

// Loop a cada 30 segundos pingando todos os clientes conectados.
// Se algum não responder (isAlive = false), significa que a conexão caiu e o servidor limpa ela.
const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) return ws.terminate();
        ws.isAlive = false;
        ws.ping();
    });
}, 30000);

wss.on('close', () => {
    clearInterval(interval);
});

function sendTo(userId, data) {
    const client = clients.get(String(userId));
    if (client && client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(JSON.stringify(data));
    }
}

function broadcastUsers() {
    const userList = [];
    clients.forEach((val, key) => userList.push({ userId: key, username: val.username }));
    const payload = JSON.stringify({ type: 'users_list', users: userList });
    clients.forEach(client => { if (client.ws.readyState === WebSocket.OPEN) client.ws.send(payload); });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
