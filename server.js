const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.get('/', (req, res) => res.send('Servidor Delta Universal Ativo'));

// Estruturas de Dados
const clients = new Map(); // userId -> { ws, username, displayName, pairedWith }
const privateChats = new Map(); // chatId -> { host, guest }
const groups = new Map(); // groupId -> { name, owner, members: Set, banned: Set, background: {} }
const friendRequests = new Map(); // targetId -> Set(senderId)

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
                        displayName: data.displayName,
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

                case 'friend_request': {
                    const targetId = String(data.targetId);
                    if (!friendRequests.has(targetId)) friendRequests.set(targetId, new Set());
                    friendRequests.get(targetId).add(currentUserId);
                    
                    const sender = clients.get(currentUserId);
                    sendTo(targetId, {
                        type: 'friend_request_received',
                        senderId: currentUserId,
                        senderName: sender.username,
                        senderDisplay: sender.displayName
                    });
                    break;
                }

                case 'friend_accept': {
                    const senderId = String(data.senderId);
                    if (friendRequests.has(currentUserId) && friendRequests.get(currentUserId).has(senderId)) {
                        friendRequests.get(currentUserId).delete(senderId);
                        sendTo(currentUserId, { type: 'friend_added', friendId: senderId });
                        sendTo(senderId, { type: 'friend_added', friendId: currentUserId });
                    }
                    break;
                }

                case 'friend_reject': {
                    const senderId = String(data.senderId);
                    if (friendRequests.has(currentUserId)) {
                        friendRequests.get(currentUserId).delete(senderId);
                    }
                    break;
                }

                case 'chat_create': {
                    const chatId = uuidv4();
                    privateChats.set(chatId, { host: currentUserId, guest: null });
                    sendTo(currentUserId, { type: 'chat_created', chatId });
                    break;
                }

                case 'chat_invite': {
                    const targetId = String(data.targetId);
                    const chatId = data.chatId;
                    const chat = privateChats.get(chatId);
                    
                    if (chat && chat.host === currentUserId) {
                        if (chat.guest) {
                            sendTo(currentUserId, { type: 'chat_error', message: "Você não pode convidar mais de 1 pessoa ao seu bate papo, pra isso crie um grupo" });
                            return;
                        }
                        const sender = clients.get(currentUserId);
                        sendTo(targetId, { type: 'chat_invite_received', chatId, senderId: currentUserId, senderName: sender.username });
                    }
                    break;
                }

                case 'chat_invite_accept': {
                    const chatId = data.chatId;
                    const chat = privateChats.get(chatId);
                    if (chat && !chat.guest) {
                        chat.guest = currentUserId;
                        sendTo(chat.host, { type: 'chat_user_joined', chatId, userId: currentUserId, username: clients.get(currentUserId).username });
                        sendTo(currentUserId, { type: 'chat_joined', chatId, hostId: chat.host });
                    }
                    break;
                }

                case 'chat_leave': {
                    const chatId = data.chatId;
                    const chat = privateChats.get(chatId);
                    if (chat) {
                        if (chat.host === currentUserId) {
                            // Anfitrião saiu: encerra chat para todos
                            if (chat.guest) sendTo(chat.guest, { type: 'chat_ended', chatId });
                            privateChats.delete(chatId);
                        } else if (chat.guest === currentUserId) {
                            // Convidado saiu
                            sendTo(chat.host, { type: 'chat_user_left', chatId, userId: currentUserId, username: clients.get(currentUserId).username });
                            chat.guest = null;
                        }
                    }
                    break;
                }

                case 'chat_message': {
                    const { chatId, message, isSticker } = data;
                    const chat = privateChats.get(chatId);
                    const sender = clients.get(currentUserId);
                    if (chat && sender) {
                        const payload = { type: 'chat_message', chatId, senderId: currentUserId, senderName: sender.username, message, isSticker };
                        sendTo(chat.host, payload);
                        if (chat.guest) sendTo(chat.guest, payload);
                    }
                    break;
                }

                case 'group_create': {
                    const groupId = uuidv4();
                    groups.set(groupId, {
                        name: data.name,
                        owner: currentUserId,
                        members: new Set([currentUserId]),
                        banned: new Set(),
                        background: null
                    });
                    sendTo(currentUserId, { type: 'group_created', groupId, name: data.name });
                    break;
                }

                case 'group_invite': {
                    const { groupId, targetId } = data;
                    const group = groups.get(groupId);
                    if (group && group.members.has(currentUserId) && !group.banned.has(targetId)) {
                        const sender = clients.get(currentUserId);
                        sendTo(targetId, { type: 'group_invite_received', groupId, groupName: group.name, senderName: sender.username });
                    }
                    break;
                }

                case 'group_invite_accept': {
                    const groupId = data.groupId;
                    const group = groups.get(groupId);
                    if (group && !group.banned.has(currentUserId)) {
                        group.members.add(currentUserId);
                        group.members.forEach(memberId => {
                            sendTo(memberId, { type: 'group_user_joined', groupId, userId: currentUserId, username: clients.get(currentUserId).username });
                        });
                        sendTo(currentUserId, { type: 'group_joined', groupId, name: group.name, owner: group.owner, members: Array.from(group.members), background: group.background });
                    }
                    break;
                }

                case 'group_message': {
                    const { groupId, message, isSticker } = data;
                    const group = groups.get(groupId);
                    const sender = clients.get(currentUserId);
                    if (group && group.members.has(currentUserId)) {
                        const payload = { type: 'group_message', groupId, senderId: currentUserId, senderName: sender.username, message, isSticker };
                        group.members.forEach(memberId => sendTo(memberId, payload));
                    }
                    break;
                }

                case 'group_ban':
                case 'group_kick': {
                    const { groupId, targetId } = data;
                    const group = groups.get(groupId);
                    if (group && group.owner === currentUserId) {
                        group.members.delete(targetId);
                        if (data.type === 'group_ban') group.banned.add(targetId);
                        
                        group.members.forEach(memberId => {
                            sendTo(memberId, { type: 'group_user_removed', groupId, userId: targetId, action: data.type });
                        });
                        sendTo(targetId, { type: 'group_kicked', groupId });
                    }
                    break;
                }

                case 'group_unban': {
                    const { groupId, targetId } = data;
                    const group = groups.get(groupId);
                    if (group && group.owner === currentUserId) {
                        group.banned.delete(targetId);
                    }
                    break;
                }

                case 'group_delete': {
                    const groupId = data.groupId;
                    const group = groups.get(groupId);
                    if (group && group.owner === currentUserId) {
                        group.members.forEach(memberId => {
                            sendTo(memberId, { type: 'group_deleted', groupId });
                        });
                        groups.delete(groupId);
                    }
                    break;
                }

                case 'group_background_update': {
                    const { groupId, backgroundData } = data;
                    const group = groups.get(groupId);
                    if (group && group.members.has(currentUserId)) {
                        group.background = backgroundData;
                        group.members.forEach(memberId => {
                            sendTo(memberId, { type: 'group_background_sync', groupId, backgroundData });
                        });
                    }
                    break;
                }

                case 'clone_invite': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith) {
                        sendTo(user.pairedWith, { type: 'clone_invite_received', senderName: user.username });
                    }
                    break;
                }

                case 'clone_accept': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith) {
                        sendTo(user.pairedWith, { type: 'clone_accepted' });
                        sendTo(currentUserId, { type: 'clone_start' }); // Feedback local
                    }
                    break;
                }

                case 'clone_cancel': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith) sendTo(user.pairedWith, { type: 'clone_cancel_received' });
                    break;
                }

                case 'clone_cancel_accept': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith) {
                        sendTo(user.pairedWith, { type: 'clone_cancelled' });
                        sendTo(currentUserId, { type: 'clone_cancelled' });
                    }
                    break;
                }

                case 'clone_sync': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith) {
                        sendTo(user.pairedWith, { type: 'clone_sync', cframe: data.cframe, animation: data.animation });
                    }
                    break;
                }

                case 'request_bring': {
                    const user = clients.get(currentUserId);
                    if (user && user.pairedWith && data.position) {
                        sendTo(user.pairedWith, { type: 'teleport_to', position: data.position });
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
            displayName: val.displayName,
            paired: !!val.pairedWith
        });
    });

    const payload = JSON.stringify({ type: 'user_list', users: userList });
    clients.forEach((client) => {
        if (client.ws.readyState === WebSocket.OPEN) client.ws.send(payload);
    });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
