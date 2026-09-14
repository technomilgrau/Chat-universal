const { WebSocketServer } = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8080;
const server = http.createServer((req, res) => res.end('MBChat WS Server Online'));
const wss = new WebSocketServer({ server });

// Estado volátil do servidor
const users = new Map(); // ws -> userId
const connections = new Map(); // userId -> ws
const groups = new Map(); // groupId -> { ownerId, members: Set, banned: Set }

wss.on('connection', (ws) => {
    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            const userId = users.get(ws);

            switch (data.type) {
                case 'register':
                    users.set(ws, data.userId);
                    connections.set(data.userId, ws);
                    break;

                // --- SISTEMA DE AMIZADES ---
                case 'friend_request':
                case 'friend_accept':
                case 'friend_reject':
                    sendToUser(data.targetId, { ...data, fromId: userId });
                    break;

                // --- SISTEMA DE CHAT PRIVADO ---
                case 'chat_invite':
                case 'chat_invite_accept':
                case 'chat_leave':
                case 'chat_message':
                case 'sticker_message':
                    // Encaminha para o alvo (targetId)
                    sendToUser(data.targetId, { ...data, fromId: userId });
                    break;

                // --- SISTEMA DE GRUPOS ---
                case 'group_create':
                    groups.set(data.groupId, {
                        ownerId: userId,
                        members: new Set([userId]),
                        banned: new Set()
                    });
                    break;

                case 'group_invite':
                    if (groups.has(data.groupId) && groups.get(data.groupId).members.has(userId)) {
                        sendToUser(data.targetId, { ...data, fromId: userId });
                    }
                    break;

                case 'group_invite_accept':
                    if (groups.has(data.groupId)) {
                        const group = groups.get(data.groupId);
                        if (!group.banned.has(userId)) {
                            group.members.add(userId);
                            broadcastToGroup(data.groupId, { ...data, newMemberId: userId });
                        }
                    }
                    break;

                case 'group_message':
                case 'group_background':
                    if (groups.has(data.groupId) && groups.get(data.groupId).members.has(userId)) {
                        broadcastToGroup(data.groupId, { ...data, fromId: userId }, userId);
                    }
                    break;

                case 'group_kick':
                case 'group_ban':
                case 'group_unban':
                case 'group_delete_request':
                case 'group_delete_confirm':
                    if (groups.has(data.groupId)) {
                        const group = groups.get(data.groupId);
                        if (group.ownerId === userId) { // VALIDAÇÃO DE AUTORIDADE
                            if (data.type === 'group_ban') group.banned.add(data.targetId);
                            if (data.type === 'group_unban') group.banned.delete(data.targetId);
                            if (['group_kick', 'group_ban'].includes(data.type)) group.members.delete(data.targetId);
                            
                            broadcastToGroup(data.groupId, { ...data, fromId: userId });
                            
                            if (data.type === 'group_delete_confirm') groups.delete(data.groupId);
                        }
                    }
                    break;

                // --- SISTEMA DE CLONE ---
                case 'clone_invite':
                case 'clone_accept':
                case 'clone_reject':
                case 'clone_cancel':
                    sendToUser(data.targetId, { ...data, fromId: userId });
                    break;
            }
        } catch (e) {
            console.error('Erro ao processar mensagem', e);
        }
    });

    ws.on('close', () => {
        const userId = users.get(ws);
        if (userId) {
            users.delete(ws);
            connections.delete(userId);
        }
    });
});

function sendToUser(userId, data) {
    const ws = connections.get(userId);
    if (ws && ws.readyState === 1) {
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

server.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
