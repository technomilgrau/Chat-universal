const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Delta Pairing System V3 - Ativo (URL Atualizada)'));

const clients = new Map();
const groups = new Map();

wss.on('connection', (ws) => {
    let currentUserId = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'register':
                    currentUserId = String(data.userId);
                    clients.set(currentUserId, {
                        ws,
                        username: data.username,
                        friends: new Set(),
                        activeChat: null,
                        activeGroup: null
                    });
                    broadcastUserList();
                    break;

                case 'friend_request':
                    sendTo(data.targetId, { type: 'friend_notification', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;

                case 'friend_accept':
                    const me = clients.get(currentUserId);
                    const them = clients.get(String(data.targetId));
                    if (me && them) {
                        me.friends.add(String(data.targetId));
                        them.friends.add(currentUserId);
                        sendTo(currentUserId, { type: 'friend_added', id: data.targetId, name: them.username });
                        sendTo(data.targetId, { type: 'friend_added', id: currentUserId, name: me.username });
                    }
                    break;

                case 'chat_invite':
                    sendTo(data.targetId, { type: 'chat_notification', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;

                case 'chat_accept':
                    const host = clients.get(String(data.targetId));
                    const guest = clients.get(currentUserId);
                    if (host && guest) {
                        host.activeChat = currentUserId;
                        guest.activeChat = String(data.targetId);
                        sendTo(currentUserId, { type: 'chat_connected', targetId: data.targetId, host: false });
                        sendTo(data.targetId, { type: 'chat_connected', targetId: currentUserId, host: true });
                    }
                    break;

                case 'leave_chat':
                    const user = clients.get(currentUserId);
                    if (user && user.activeChat) {
                        const other = user.activeChat;
                        user.activeChat = null;
                        if (clients.has(other)) clients.get(other).activeChat = null;
                        sendTo(other, { type: 'chat_ended', message: `${user.username} saiu do chat.` });
                        sendTo(currentUserId, { type: 'chat_ended', message: `Você saiu do chat.` });
                    }
                    break;

                case 'chat_message':
                    const sender = clients.get(currentUserId);
                    if (sender && sender.activeChat) {
                        const payload = { type: 'chat_receive', sender: sender.username, message: data.message, isSticker: data.isSticker };
                        sendTo(currentUserId, payload);
                        sendTo(sender.activeChat, payload);
                    }
                    break;

                case 'create_group':
                    const groupId = 'gp_' + Date.now();
                    groups.set(groupId, { name: data.name, owner: currentUserId, members: new Set([currentUserId]), banned: new Set() });
                    clients.get(currentUserId).activeGroup = groupId;
                    sendTo(currentUserId, { type: 'group_joined', groupId, name: data.name, isOwner: true });
                    break;

                case 'invite_group':
                    const gpHost = clients.get(currentUserId);
                    if (gpHost && gpHost.activeGroup) {
                        const gp = groups.get(gpHost.activeGroup);
                        if (!gp.banned.has(String(data.targetId))) {
                            sendTo(data.targetId, { type: 'group_notification', fromName: gpHost.username, groupId: gpHost.activeGroup, groupName: gp.name });
                        }
                    }
                    break;

                case 'group_command':
                    const cmdSender = clients.get(currentUserId);
                    if (cmdSender && cmdSender.activeGroup) {
                        const gp = groups.get(cmdSender.activeGroup);
                        if (gp.owner === currentUserId) {
                            if (data.action === 'kick' || data.action === 'ban') {
                                gp.members.delete(String(data.targetId));
                                if (data.action === 'ban') gp.banned.add(String(data.targetId));
                                sendTo(data.targetId, { type: 'group_message', sender: 'Sistema', message: `Você foi removido.` });
                            }
                        }
                    }
                    break;

                case 'clone_request':
                    sendTo(data.targetId, { type: 'clone_prompt', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;

                case 'clone_accept':
                    sendTo(data.targetId, { type: 'clone_start', targetId: currentUserId });
                    sendTo(currentUserId, { type: 'clone_start', targetId: data.targetId });
                    break;

                case 'clone_sync':
                    sendTo(data.targetId, { type: 'clone_update', cframe: data.cframe });
                    break;
            }
        } catch (err) {
            console.error(err);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
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
    clients.forEach((val, key) => userList.push({ userId: key, username: val.username }));
    const payload = JSON.stringify({ type: 'user_list', users: userList });
    clients.forEach(client => {
        if (client.ws.readyState === WebSocket.OPEN) client.ws.send(payload);
    });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Rodando na porta ${PORT}`));
