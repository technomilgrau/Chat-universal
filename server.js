const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Delta Chat & Sync Server Ativo'));

const clients = new Map(); // userId -> { ws, username, currentChat, currentGroup }
const groups = new Map(); // groupId -> { name, owner, members: [], banned: [] }

wss.on('connection', (ws) => {
    let currentUserId = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'register':
                    currentUserId = String(data.userId);
                    clients.set(currentUserId, { ws, username: data.username, currentChat: null, currentGroup: null });
                    broadcastUserList();
                    break;

                // --- SISTEMA DE AMIZADES E CONVITES ---
                case 'friend_request':
                    sendTo(data.targetId, { type: 'friend_request', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                case 'friend_accept':
                    sendTo(data.targetId, { type: 'friend_accept', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                case 'chat_invite':
                    sendTo(data.targetId, { type: 'chat_invite', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                case 'chat_accept':
                    const user1 = clients.get(currentUserId);
                    const user2 = clients.get(String(data.targetId));
                    if (user1 && user2) {
                        user1.currentChat = data.targetId;
                        user2.currentChat = currentUserId;
                        sendTo(currentUserId, { type: 'chat_connected', targetId: data.targetId, targetName: user2.username });
                        sendTo(data.targetId, { type: 'chat_connected', targetId: currentUserId, targetName: user1.username });
                    }
                    break;
                case 'chat_leave':
                    const leaver = clients.get(currentUserId);
                    if (leaver && leaver.currentChat) {
                        sendTo(leaver.currentChat, { type: 'chat_ended', reason: `${leaver.username} saiu do chat.` });
                        const target = clients.get(leaver.currentChat);
                        if (target) target.currentChat = null;
                        leaver.currentChat = null;
                    }
                    break;

                // --- SISTEMA DE GRUPOS ---
                case 'create_group':
                    const groupId = 'gp_' + Date.now();
                    groups.set(groupId, { name: data.name, owner: currentUserId, members: [currentUserId], banned: [] });
                    clients.get(currentUserId).currentGroup = groupId;
                    sendTo(currentUserId, { type: 'group_created', groupId, name: data.name });
                    break;
                case 'invite_group':
                    const gp = groups.get(data.groupId);
                    if (gp && gp.owner === currentUserId && !gp.banned.includes(data.targetId)) {
                        sendTo(data.targetId, { type: 'group_invite', groupId: data.groupId, name: gp.name, fromName: clients.get(currentUserId).username });
                    }
                    break;
                case 'accept_group':
                    const grp = groups.get(data.groupId);
                    if (grp) {
                        grp.members.push(currentUserId);
                        clients.get(currentUserId).currentGroup = data.groupId;
                        broadcastToGroup(data.groupId, { type: 'group_msg', sender: 'Sistema', message: `${clients.get(currentUserId).username} entrou no grupo.` });
                    }
                    break;
                case 'kick_group': // Ban/Kick logic
                case 'ban_group':
                    const mGrp = groups.get(data.groupId);
                    if (mGrp && mGrp.owner === currentUserId) {
                        mGrp.members = mGrp.members.filter(id => id !== data.targetId);
                        if (data.type === 'ban_group') mGrp.banned.push(data.targetId);
                        sendTo(data.targetId, { type: 'kicked_group', reason: data.type === 'ban_group' ? 'Banido' : 'Expulso' });
                        clients.get(data.targetId).currentGroup = null;
                    }
                    break;
                case 'delete_group':
                    if (groups.has(data.groupId) && groups.get(data.groupId).owner === currentUserId) {
                        broadcastToGroup(data.groupId, { type: 'group_deleted' });
                        groups.get(data.groupId).members.forEach(id => { if (clients.has(id)) clients.get(id).currentGroup = null; });
                        groups.delete(data.groupId);
                    }
                    break;

                // --- MENSAGENS E DADOS ---
                case 'chat_msg':
                    const senderData = clients.get(currentUserId);
                    if (senderData.currentChat) {
                        const payload = { type: 'chat_msg', sender: senderData.username, message: data.message, sticker: data.sticker };
                        sendTo(currentUserId, payload);
                        sendTo(senderData.currentChat, payload);
                    } else if (senderData.currentGroup) {
                        broadcastToGroup(senderData.currentGroup, { type: 'group_msg', sender: senderData.username, message: data.message, sticker: data.sticker });
                    }
                    break;

                // --- SISTEMA DE CLONES ---
                case 'clone_invite':
                    sendTo(data.targetId, { type: 'clone_invite', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                case 'clone_accept':
                    sendTo(data.targetId, { type: 'clone_accepted', fromId: currentUserId });
                    break;
                case 'clone_cancel':
                    sendTo(data.targetId, { type: 'clone_cancelled' });
                    break;
                case 'sync_transform': // CFrame e Animações do Clone
                    if (data.targetId) {
                        sendTo(data.targetId, { 
                            type: 'sync_update', 
                            cframe: data.cframe, 
                            animationId: data.animationId,
                            chatBubble: data.chatBubble 
                        });
                    }
                    break;
            }
        } catch (err) {
            console.error('Erro:', err);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
            const user = clients.get(currentUserId);
            if (user && user.currentChat) {
                sendTo(user.currentChat, { type: 'chat_ended', reason: 'Usuário desconectado.' });
                const target = clients.get(user.currentChat);
                if (target) target.currentChat = null;
            }
            clients.delete(currentUserId);
            broadcastUserList();
        }
    });
});

function sendTo(userId, data) {
    const client = clients.get(String(userId));
    if (client && client.ws.readyState === WebSocket.OPEN) client.ws.send(JSON.stringify(data));
}
function broadcastToGroup(groupId, data) {
    const gp = groups.get(groupId);
    if (gp) {
        gp.members.forEach(memberId => {
            sendTo(memberId, data);
        });
    }
}
function broadcastUserList() {
    const userList = Array.from(clients.entries()).map(([id, val]) => ({ userId: id, username: val.username }));
    const payload = JSON.stringify({ type: 'user_list', users: userList });
    clients.forEach(client => { if (client.ws.readyState === WebSocket.OPEN) client.ws.send(payload); });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
