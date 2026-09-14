const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Estado em memória
const clients = new Map(); // ws -> { userId, username, displayName }
const users = new Map(); // userId -> ws
const groups = new Map(); // groupId -> { ownerId, members: Set(userId), banned: Set(userId), background: string, bgPosition: string }
const activeChats = new Map(); // chatId -> { hostId, guestId }

app.get('/', (req, res) => res.send('MBChat WebSocket Server Online'));

function sendToUser(userId, data) {
    const ws = users.get(userId);
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(data));
    }
}

function broadcastToGroup(groupId, data, excludeUserId = null) {
    const group = groups.get(groupId);
    if (!group) return;
    group.members.forEach(memberId => {
        if (memberId !== excludeUserId) {
            sendToUser(memberId, data);
        }
    });
}

wss.on('connection', (ws) => {
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            const type = data.type;

            if (type === 'register') {
                const { userId, username, displayName } = data;
                clients.set(ws, { userId, username, displayName });
                users.set(userId, ws);
                ws.send(JSON.stringify({ type: 'register_success', userId }));
                return;
            }

            const clientInfo = clients.get(ws);
            if (!clientInfo) return; // Requer registro
            const senderId = clientInfo.userId;

            switch (type) {
                // --- AMIZADES ---
                case 'search_users':
                    const query = (data.query || '').toLowerCase();
                    const friends = data.friends || [];
                    const results = [];
                    for (const [uid, info] of clients.entries()) {
                        if (info.userId !== senderId && !friends.includes(info.userId)) {
                            if (info.username.toLowerCase().includes(query) || info.displayName.toLowerCase().includes(query)) {
                                results.push({ userId: info.userId, username: info.username, displayName: info.displayName });
                            }
                        }
                    }
                    ws.send(JSON.stringify({ type: 'search_results', results }));
                    break;

                case 'friend_request':
                    sendToUser(data.targetId, {
                        type: 'friend_request_received',
                        sender: { userId: senderId, username: clientInfo.username, displayName: clientInfo.displayName }
                    });
                    break;

                case 'friend_accept':
                    sendToUser(data.targetId, {
                        type: 'friend_accepted',
                        sender: { userId: senderId, username: clientInfo.username, displayName: clientInfo.displayName }
                    });
                    break;

                // --- CHAT PRIVADO ---
                case 'chat_invite':
                    // Valida limite de 2 pessoas
                    let activeHostChat = Array.from(activeChats.entries()).find(([cid, c]) => c.hostId === senderId);
                    if (activeHostChat && activeHostChat[1].guestId) {
                        ws.send(JSON.stringify({ type: 'error_message', message: "Você não pode convidar mais de 1 pessoa ao seu bate papo, pra isso crie um grupo" }));
                        return;
                    }
                    sendToUser(data.targetId, {
                        type: 'chat_invite_received',
                        chatId: data.chatId,
                        sender: { userId: senderId, username: clientInfo.username, displayName: clientInfo.displayName }
                    });
                    break;

                case 'chat_invite_accept':
                    if (!activeChats.has(data.chatId)) {
                        activeChats.set(data.chatId, { hostId: data.hostId, guestId: senderId });
                    } else {
                        activeChats.get(data.chatId).guestId = senderId;
                    }
                    sendToUser(data.hostId, { type: 'chat_joined', chatId: data.chatId, userId: senderId, username: clientInfo.username });
                    ws.send(JSON.stringify({ type: 'chat_join_success', chatId: data.chatId }));
                    break;

                case 'chat_leave':
                    const chat = activeChats.get(data.chatId);
                    if (chat) {
                        if (chat.hostId === senderId) {
                            // Host saiu, desconecta o convidado e encerra
                            sendToUser(chat.guestId, { type: 'chat_closed', chatId: data.chatId });
                            activeChats.delete(data.chatId);
                        } else if (chat.guestId === senderId) {
                            sendToUser(chat.hostId, { type: 'chat_left', chatId: data.chatId, userId: senderId, username: clientInfo.username });
                            chat.guestId = null;
                        }
                    }
                    break;

                case 'chat_message':
                case 'sticker_message':
                    const tgtChat = activeChats.get(data.chatId);
                    if (tgtChat) {
                        const recipient = tgtChat.hostId === senderId ? tgtChat.guestId : tgtChat.hostId;
                        if (recipient) {
                            sendToUser(recipient, data);
                        }
                    }
                    break;

                // --- GRUPOS ---
                case 'group_create':
                    groups.set(data.groupId, {
                        ownerId: senderId,
                        members: new Set([senderId]),
                        banned: new Set(),
                        background: 'nenhuma',
                        bgPosition: '{0,0},{0,0}'
                    });
                    ws.send(JSON.stringify({ type: 'group_created', groupId: data.groupId, name: data.name }));
                    break;

                case 'group_invite':
                    const g = groups.get(data.groupId);
                    if (g && !g.banned.has(data.targetId) && !g.members.has(data.targetId)) {
                        sendToUser(data.targetId, {
                            type: 'group_invite_received',
                            groupId: data.groupId,
                            groupName: data.groupName,
                            sender: { userId: senderId, username: clientInfo.username, displayName: clientInfo.displayName }
                        });
                    }
                    break;

                case 'group_invite_accept':
                    const grp = groups.get(data.groupId);
                    if (grp && !grp.banned.has(senderId)) {
                        grp.members.add(senderId);
                        broadcastToGroup(data.groupId, { type: 'group_member_joined', groupId: data.groupId, user: { userId: senderId, username: clientInfo.username, displayName: clientInfo.displayName } }, senderId);
                        ws.send(JSON.stringify({ type: 'group_join_success', groupId: data.groupId, background: grp.background, bgPosition: grp.bgPosition }));
                    }
                    break;

                case 'group_message':
                case 'group_sticker':
                    broadcastToGroup(data.groupId, data, senderId);
                    break;

                case 'group_kick':
                case 'group_ban':
                case 'group_unban':
                case 'group_delete_request':
                case 'group_delete_confirm':
                case 'group_background':
                    const modGrp = groups.get(data.groupId);
                    if (modGrp && modGrp.ownerId === senderId) {
                        if (type === 'group_kick') {
                            modGrp.members.delete(data.targetId);
                            sendToUser(data.targetId, { type: 'group_kicked', groupId: data.groupId });
                            broadcastToGroup(data.groupId, { type: 'group_member_removed', groupId: data.groupId, userId: data.targetId });
                        } else if (type === 'group_ban') {
                            modGrp.members.delete(data.targetId);
                            modGrp.banned.add(data.targetId);
                            sendToUser(data.targetId, { type: 'group_banned', groupId: data.groupId });
                            broadcastToGroup(data.groupId, { type: 'group_member_removed', groupId: data.groupId, userId: data.targetId });
                        } else if (type === 'group_unban') {
                            modGrp.banned.delete(data.targetId);
                        } else if (type === 'group_delete_request') {
                            broadcastToGroup(data.groupId, { type: 'group_delete_prompt', groupId: data.groupId });
                        } else if (type === 'group_delete_confirm') {
                            broadcastToGroup(data.groupId, { type: 'group_deleted', groupId: data.groupId });
                            groups.delete(data.groupId);
                        } else if (type === 'group_background') {
                            modGrp.background = data.background;
                            modGrp.bgPosition = data.bgPosition;
                            broadcastToGroup(data.groupId, { type: 'group_background_update', groupId: data.groupId, background: data.background, bgPosition: data.bgPosition }, senderId);
                        }
                    }
                    break;
                case 'group_sync_history':
                    sendToUser(data.targetId, {
                        type: 'group_history_sync',
                        groupId: data.groupId,
                        history: data.history
                    });
                    break;

                // --- CLONE ---
                case 'clone_invite':
                    sendToUser(data.targetId, { type: 'clone_invite_received', senderId: senderId, username: clientInfo.username });
                    break;
                case 'clone_accept':
                    sendToUser(data.targetId, { type: 'clone_accepted', senderId: senderId });
                    break;
                case 'clone_cancel':
                    sendToUser(data.targetId, { type: 'clone_cancelled', senderId: senderId });
                    break;
                case 'clone_sync':
                    sendToUser(data.targetId, { type: 'clone_update', senderId: senderId, cframe: data.cframe, moveDir: data.moveDir, jump: data.jump });
                    break;
            }
        } catch (err) {
            console.error("Erro ao processar mensagem:", err);
        }
    });

    ws.on('close', () => {
        const clientInfo = clients.get(ws);
        if (clientInfo) {
            users.delete(clientInfo.userId);
        }
        clients.delete(ws);
    });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
});
