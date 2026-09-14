const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Delta Pairing System V4 - Roteamento Master'));

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
                    clients.set(currentUserId, { ws, username: data.username, activeChat: null, activeGroup: null });
                    broadcastUserList();
                    break;

                // Sistema de Amigos e 1v1
                case 'friend_request':
                    sendTo(data.targetId, { type: 'friend_notification', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                case 'friend_accept':
                    sendTo(data.targetId, { type: 'friend_added', id: currentUserId, name: clients.get(currentUserId).username });
                    sendTo(currentUserId, { type: 'friend_added', id: data.targetId, name: clients.get(String(data.targetId)).username });
                    break;
                case 'chat_invite':
                    sendTo(data.targetId, { type: 'chat_notification', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                case 'chat_accept':
                    if (clients.has(currentUserId) && clients.has(String(data.targetId))) {
                        clients.get(currentUserId).activeChat = String(data.targetId);
                        clients.get(String(data.targetId)).activeChat = currentUserId;
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

                // Sistema de Grupos
                case 'create_group':
                    const groupId = 'gp_' + Date.now();
                    groups.set(groupId, { name: data.name, owner: currentUserId, members: new Set([currentUserId]), banned: new Set(), bg: null });
                    clients.get(currentUserId).activeGroup = groupId;
                    sendTo(currentUserId, { type: 'group_joined', groupId, name: data.name, isOwner: true });
                    break;
                case 'invite_group':
                    const gpHost = clients.get(currentUserId);
                    if (gpHost && gpHost.activeGroup) {
                        const gp = groups.get(gpHost.activeGroup);
                        if (!gp.banned.has(String(data.targetId))) {
                            sendTo(data.targetId, { type: 'group_notification', fromId: currentUserId, fromName: gpHost.username, groupId: gpHost.activeGroup, groupName: gp.name });
                        }
                    }
                    break;
                case 'accept_group':
                    const gp = groups.get(data.groupId);
                    if (gp) {
                        gp.members.add(currentUserId);
                        clients.get(currentUserId).activeGroup = data.groupId;
                        // Pede para o dono enviar o histórico local para o novo membro
                        sendTo(gp.owner, { type: 'request_group_history', targetId: currentUserId, groupId: data.groupId });
                        gp.members.forEach(m => sendTo(m, { type: 'group_message', sender: 'Sistema', message: `${clients.get(currentUserId).username} entrou no grupo.`, isSticker: false }));
                    }
                    break;
                case 'sync_group_history':
                    // Roteia o histórico do dono para o novo membro
                    sendTo(data.targetId, { type: 'receive_group_history', history: data.history });
                    break;
                case 'group_message':
                    const gSender = clients.get(currentUserId);
                    if (gSender && gSender.activeGroup) {
                        const gpData = groups.get(gSender.activeGroup);
                        gpData.members.forEach(m => sendTo(m, { type: 'group_message', sender: gSender.username, message: data.message, isSticker: data.isSticker }));
                    }
                    break;
                case 'group_command':
                    const cmdSender = clients.get(currentUserId);
                    if (cmdSender && cmdSender.activeGroup) {
                        const gpCmd = groups.get(cmdSender.activeGroup);
                        if (gpCmd.owner === currentUserId) {
                            if (data.action === 'kick' || data.action === 'ban') {
                                gpCmd.members.delete(String(data.targetId));
                                if (data.action === 'ban') gpCmd.banned.add(String(data.targetId));
                                sendTo(data.targetId, { type: 'group_kicked' });
                                gpCmd.members.forEach(m => sendTo(m, { type: 'group_message', sender: 'Sistema', message: `Usuário removido.`, isSticker: false }));
                            }
                            if (data.action === 'delete') {
                                gpCmd.members.forEach(m => {
                                    if (clients.has(m)) clients.get(m).activeGroup = null;
                                    sendTo(m, { type: 'group_deleted' });
                                });
                                groups.delete(cmdSender.activeGroup);
                            }
                            if (data.action === 'bg_update') {
                                gpCmd.bg = data.bgData;
                                gpCmd.members.forEach(m => sendTo(m, { type: 'group_bg_sync', bgData: data.bgData }));
                            }
                        }
                    }
                    break;

                // Sistema de Clones
                case 'clone_request':
                    sendTo(data.targetId, { type: 'clone_prompt', fromId: currentUserId, fromName: clients.get(currentUserId).username });
                    break;
                case 'clone_accept':
                    sendTo(data.targetId, { type: 'clone_start', targetId: currentUserId });
                    sendTo(currentUserId, { type: 'clone_start', targetId: data.targetId });
                    break;
                case 'clone_cancel':
                    sendTo(data.targetId, { type: 'clone_stop' });
                    break;
                case 'clone_sync':
                    sendTo(data.targetId, { type: 'clone_update', cframe: data.cframe, chatMsg: data.chatMsg });
                    break;
            }
        } catch (err) { console.error(err); }
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
    if (client && client.ws.readyState === WebSocket.OPEN) client.ws.send(JSON.stringify(data));
}

function broadcastUserList() {
    const userList = [];
    clients.forEach((val, key) => userList.push({ userId: key, username: val.username }));
    const payload = JSON.stringify({ type: 'user_list', users: userList });
    clients.forEach(c => { if (c.ws.readyState === WebSocket.OPEN) c.ws.send(payload); });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Rodando na porta ${PORT}`));
