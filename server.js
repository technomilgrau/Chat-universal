// Server Node.js para Chat Universal
// Suporte a WebSocket, Presença Online/Offline em Tempo Real e Roteamento
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocketServer({ port: PORT });

// Mapeamento: userId (string) -> { ws: WebSocket, username: string, displayName: string }
const connectedUsers = new Map();

console.log(`[SERVIDOR] Servidor WebSocket iniciado na porta ${PORT}`);

function broadcastPresence(userId, status) {
    const payload = JSON.stringify({
        type: 'presence_update',
        userId: String(userId),
        status: status
    });

    for (const [id, user] of connectedUsers.entries()) {
        if (id !== String(userId) && user.ws.readyState === 1) {
            user.ws.send(payload);
        }
    }
}

wss.on('connection', (ws) => {
    let clientUserId = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            if (!data || !data.type) return;

            // 1. REGISTRO DE USUÁRIO
            if (data.type === 'register') {
                clientUserId = String(data.userId);
                connectedUsers.set(clientUserId, {
                    ws: ws,
                    username: data.username || 'Desconhecido',
                    displayName: data.displayName || data.username || 'Desconhecido'
                });

                console.log(`[PRESENCE] Usuário registrado: ${data.username} (${clientUserId})`);
                console.log(`[PRESENCE] Usuário online: ${clientUserId}`);

                // Envia para o novo usuário o status ONLINE de todos os usuários já conectados
                for (const [existingId, existingUser] of connectedUsers.entries()) {
                    if (existingId !== clientUserId) {
                        ws.send(JSON.stringify({
                            type: 'presence_update',
                            userId: String(existingId),
                            status: 'online'
                        }));
                    }
                }

                // Notifica todos os outros usuários que este cliente está ONLINE
                broadcastPresence(clientUserId, 'online');
            }

            // 2. ENVIO DE MENSAGENS (TEXTO E STICKER)
            else if (data.type === 'send_message') {
                const targetId = String(data.toUserId);
                const targetUser = connectedUsers.get(targetId);

                console.log(`[CHAT] Enviando mensagem de ${clientUserId} para ${targetId}`);

                if (targetUser && targetUser.ws.readyState === 1) {
                    targetUser.ws.send(JSON.stringify({
                        type: 'private_message',
                        fromUserId: clientUserId,
                        msgId: data.msgId,
                        msgType: data.msgType || 'text',
                        content: data.content,
                        fromName: data.fromName,
                        fromDisplayName: data.fromDisplayName
                    }));
                }
            }

            // 3. DIGITANDO...
            else if (data.type === 'typing') {
                const targetId = String(data.toUserId);
                const targetUser = connectedUsers.get(targetId);

                if (targetUser && targetUser.ws.readyState === 1) {
                    targetUser.ws.send(JSON.stringify({
                        type: 'typing_status',
                        fromUserId: clientUserId,
                        isTyping: !!data.isTyping
                    }));
                }
            }

            // 4. SOLICITAÇÃO DE AMIZADE
            else if (data.type === 'send_friend_request') {
                const targetId = String(data.targetUserId);
                const targetUser = connectedUsers.get(targetId);

                if (targetUser && targetUser.ws.readyState === 1) {
                    targetUser.ws.send(JSON.stringify({
                        type: 'new_friend_request',
                        fromId: clientUserId,
                        fromName: data.fromName,
                        fromDisplayName: data.fromDisplayName
                    }));
                }
            }

            // 5. ACEITAR AMIZADE
            else if (data.type === 'accept_friend_request') {
                const senderId = String(data.senderId);
                const senderUser = connectedUsers.get(senderId);

                if (senderUser && senderUser.ws.readyState === 1) {
                    senderUser.ws.send(JSON.stringify({
                        type: 'friend_accepted',
                        userId: clientUserId,
                        username: data.username,
                        displayName: data.displayName
                    }));
                }
            }

            // 6. EDITAR MENSAGEM
            else if (data.type === 'edit_message') {
                const targetId = String(data.toUserId);
                const targetUser = connectedUsers.get(targetId);

                if (targetUser && targetUser.ws.readyState === 1) {
                    targetUser.ws.send(JSON.stringify({
                        type: 'message_edited',
                        fromUserId: clientUserId,
                        msgId: data.msgId,
                        content: data.content
                    }));
                }
            }

            // 7. APAGAR MENSAGEM
            else if (data.type === 'delete_message') {
                const targetId = String(data.toUserId);
                const targetUser = connectedUsers.get(targetId);

                if (targetUser && targetUser.ws.readyState === 1) {
                    targetUser.ws.send(JSON.stringify({
                        type: 'message_deleted',
                        fromUserId: clientUserId,
                        msgId: data.msgId
                    }));
                }
            }

            // 8. DESFAZER AMIZADE
            else if (data.type === 'unfriend') {
                const targetId = String(data.targetUserId);
                const targetUser = connectedUsers.get(targetId);

                if (targetUser && targetUser.ws.readyState === 1) {
                    targetUser.ws.send(JSON.stringify({
                        type: 'unfriended',
                        fromUserId: clientUserId
                    }));
                }
            }

            // 9. PESQUISAR USUÁRIOS CONECTADOS
            else if (data.type === 'search_users') {
                const query = String(data.query || '').toLowerCase();
                const results = [];

                for (const [id, user] of connectedUsers.entries()) {
                    if (id !== clientUserId) {
                        const uName = (user.username || '').toLowerCase();
                        const dName = (user.displayName || '').toLowerCase();
                        if (uName.includes(query) || dName.includes(query)) {
                            results.push({
                                userId: id,
                                username: user.username,
                                displayName: user.displayName
                            });
                        }
                    }
                }

                ws.send(JSON.stringify({
                    type: 'search_results',
                    results: results
                }));
            }

        } catch (err) {
            console.error('[ERRO SERVIDOR] Erro ao processar mensagem:', err);
        }
    });

    ws.on('close', () => {
        if (clientUserId) {
            console.log(`[PRESENCE] Usuário desconectado: ${clientUserId}`);
            console.log(`[PRESENCE] Usuário offline: ${clientUserId}`);
            connectedUsers.delete(clientUserId);
            broadcastPresence(clientUserId, 'offline');
        }
    });

    ws.on('error', (error) => {
        console.error(`[WS ERRO] Ocorreu um erro no socket do cliente ${clientUserId}:`, error);
        if (clientUserId) {
            connectedUsers.delete(clientUserId);
            broadcastPresence(clientUserId, 'offline');
        }
    });
});
