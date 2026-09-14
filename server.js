const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

// Armazenamento em memória (Volátil, apenas para roteamento e pesquisa)
const clients = new Map(); // userId -> WebSocket
const registeredUsers = new Map(); // userId -> { userId, username, avatar }

console.log(`[Server] Iniciado na porta ${PORT}`);

wss.on('connection', (ws) => {
    let currentUserId = null;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'register':
                    currentUserId = data.userId;
                    clients.set(currentUserId, ws);
                    registeredUsers.set(currentUserId, {
                        userId: data.userId,
                        username: data.username,
                        avatar: data.avatar
                    });
                    console.log(`[Server] User registered: ${data.username} (${data.userId})`);
                    
                    // Avisar os amigos que este usuário está online
                    if (data.friends && Array.isArray(data.friends)) {
                        data.friends.forEach(friendId => {
                            const friendWs = clients.get(String(friendId));
                            if (friendWs && friendWs.readyState === WebSocket.OPEN) {
                                friendWs.send(JSON.stringify({
                                    type: 'presence_update',
                                    userId: currentUserId,
                                    status: 'online'
                                }));
                                // Enviar status do amigo de volta para o usuário atual
                                ws.send(JSON.stringify({
                                    type: 'presence_update',
                                    userId: String(friendId),
                                    status: 'online'
                                }));
                            }
                        });
                    }
                    break;

                case 'search_users':
                    const query = data.query.toLowerCase();
                    const results = [];
                    for (const [id, user] of registeredUsers.entries()) {
                        if (id !== currentUserId && user.username.toLowerCase().includes(query)) {
                            results.push(user);
                        }
                    }
                    ws.send(JSON.stringify({
                        type: 'search_results',
                        results: results
                    }));
                    break;

                case 'send_friend_request':
                case 'accept_friend_request':
                case 'decline_friend_request':
                    const targetWs = clients.get(String(data.targetId));
                    if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                        targetWs.send(JSON.stringify(data));
                        console.log(`[Server] Forwarded ${data.type} from ${currentUserId} to ${data.targetId}`);
                    }
                    break;

                case 'private_message':
                    const recipientWs = clients.get(String(data.targetId));
                    if (recipientWs && recipientWs.readyState === WebSocket.OPEN) {
                        recipientWs.send(JSON.stringify(data));
                        console.log(`[Server] Forwarded message (${data.message.type}) from ${currentUserId} to ${data.targetId}`);
                    }
                    break;

                case 'typing_status':
                    const chatPartnerWs = clients.get(String(data.targetId));
                    if (chatPartnerWs && chatPartnerWs.readyState === WebSocket.OPEN) {
                        chatPartnerWs.send(JSON.stringify({
                            type: 'typing_status',
                            userId: currentUserId,
                            isTyping: data.isTyping
                        }));
                    }
                    break;
            }
        } catch (error) {
            console.error(`[Server] Erro ao processar mensagem:`, error);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
            console.log(`[Server] User disconnected: ${currentUserId}`);
            clients.delete(currentUserId);
            
            // Broadcast offline status to all connected users (simplificado para garantir que os amigos saibam)
            for (const [id, clientWs] of clients.entries()) {
                if (clientWs.readyState === WebSocket.OPEN) {
                    clientWs.send(JSON.stringify({
                        type: 'presence_update',
                        userId: currentUserId,
                        status: 'offline'
                    }));
                }
            }
        }
    });
});
