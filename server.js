const express = require('express');
const { WebSocketServer, WebSocket } = require('ws');
const http = require('http');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// Armazena conexões ativas: { userId: { ws, username, status: 'online' | 'typing' } }
const clients = new Map();
// Armazena notificações pendentes em memória enquanto o server rodar
const pendingRequests = new Map(); // targetUserId -> Array of senderData

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
                        status: 'online'
                    });
                    
                    // Notifica amigos que ficou online
                    broadcastPresence(currentUserId, 'online');

                    // Envia solicitações pendentes
                    if (pendingRequests.has(currentUserId)) {
                        ws.send(JSON.stringify({
                            type: 'friend_requests',
                            requests: pendingRequests.get(currentUserId)
                        }));
                    }
                    break;

                case 'search_users':
                    const query = data.query.toLowerCase();
                    const results = [];
                    for (let [id, client] of clients.entries()) {
                        if (id !== currentUserId && client.username.toLowerCase().includes(query)) {
                            results.push({ userId: id, username: client.username });
                        }
                    }
                    ws.send(JSON.stringify({ type: 'search_results', results }));
                    break;

                case 'send_friend_request':
                    const targetId = String(data.targetUserId);
                    const reqData = { fromId: currentUserId, fromName: data.fromName };

                    if (clients.has(targetId)) {
                        clients.get(targetId).ws.send(JSON.stringify({
                            type: 'new_friend_request',
                            request: reqData
                        }));
                    } else {
                        if (!pendingRequests.has(targetId)) pendingRequests.set(targetId, []);
                        pendingRequests.get(targetId).push(reqData);
                    }
                    break;

                case 'accept_friend_request':
                    // Notifica quem enviou que o pedido foi aceito
                    const sender = clients.get(String(data.senderId));
                    if (sender) {
                        sender.ws.send(JSON.stringify({
                            type: 'friend_accepted',
                            userId: currentUserId,
                            username: data.username
                        }));
                    }
                    break;

                case 'send_message':
                    // Repassa a mensagem direto para o destinatário (Sem salvar no servidor)
                    const receiver = clients.get(String(data.toUserId));
                    if (receiver && receiver.ws.readyState === WebSocket.OPEN) {
                        receiver.ws.send(JSON.stringify({
                            type: 'private_message',
                            fromUserId: currentUserId,
                            msgType: data.msgType, // 'text' ou 'sticker'
                            content: data.content,
                            timestamp: Date.now()
                        }));
                    }
                    break;

                case 'typing_status':
                    const peer = clients.get(String(data.toUserId));
                    if (peer && peer.ws.readyState === WebSocket.OPEN) {
                        peer.ws.send(JSON.stringify({
                            type: 'typing_status',
                            fromUserId: currentUserId,
                            isTyping: data.isTyping
                        }));
                    }
                    break;

                case 'check_status':
                    const isOnline = clients.has(String(data.targetUserId));
                    ws.send(JSON.stringify({
                        type: 'presence_update',
                        userId: data.targetUserId,
                        status: isOnline ? 'online' : 'offline'
                    }));
                    break;
            }
        } catch (err) {
            console.error('Erro ao processar mensagem:', err);
        }
    });

    ws.on('close', () => {
        if (currentUserId) {
            clients.delete(currentUserId);
            broadcastPresence(currentUserId, 'offline');
        }
    });
});

function broadcastPresence(userId, status) {
    for (let [id, client] of clients.entries()) {
        if (id !== userId && client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(JSON.stringify({
                type: 'presence_update',
                userId,
                status
            }));
        }
    }
}

app.get('/', (req, res) => res.send('Servidor Chat Universal Ativo!'));

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Servidor rodando na porta ${PORT}`));
