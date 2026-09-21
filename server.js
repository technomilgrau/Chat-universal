const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '256kb' }));

// ============================================================
// Move Block V4 - backend de presença / MBWork
// ============================================================
// O histórico permanente de chats privados NÃO é armazenado aqui.
// O servidor apenas mantém:
// - presença e último perfil conhecido em memória;
// - solicitações de amizade em memória;
// - amizades conhecidas em memória, republicadas pelos clientes;
// - eventos pendentes para entrega enquanto o destinatário não sincroniza;
// - chat global legado, limitado às últimas 100 mensagens.
// ============================================================

const activeUsers = new Map();
const userDirectory = new Map();
const friendRequests = new Map();
const friendships = new Map();
const pendingEvents = new Map();
const typingStates = new Map();

let chatMessages = [];
let cachedStickerManifest = { files: [], fetchedAt: 0 };

const USER_TTL_MS = 10000;
const TYPING_TTL_MS = 3500;
const STICKER_CACHE_MS = 60000;

function normalizeId(value) {
    const n = Number(value);
    if (!Number.isFinite(n) || n <= 0) return null;
    return Math.trunc(n);
}

function getUserProfile(profile) {
    if (!profile) return null;
    const userId = normalizeId(profile.userId);
    if (!userId) return null;

    const previous = userDirectory.get(userId) || {};
    const name = String(profile.name || previous.name || '').trim();
    const displayName = String(profile.displayName || previous.displayName || name).trim();
    const avatar = String(
        profile.avatar ||
        previous.avatar ||
        `rbxthumb://type=AvatarHeadShot&id=${userId}&w=150&h=150`
    );

    const result = {
        userId,
        name,
        displayName,
        avatar
    };

    userDirectory.set(userId, result);
    return result;
}

function ensureFriendSet(userId) {
    if (!friendships.has(userId)) friendships.set(userId, new Set());
    return friendships.get(userId);
}

function ensureRequestMap(userId) {
    if (!friendRequests.has(userId)) friendRequests.set(userId, new Map());
    return friendRequests.get(userId);
}

function ensureEventQueue(userId) {
    if (!pendingEvents.has(userId)) pendingEvents.set(userId, []);
    return pendingEvents.get(userId);
}

function enqueueEvent(userId, event) {
    const id = normalizeId(userId);
    if (!id) return;

    const queue = ensureEventQueue(id);

    queue.push({
        ...event,
        eventId: `${Date.now()}_${Math.random().toString(36).slice(2)}`
    });

    if (queue.length > 200) {
        queue.splice(0, queue.length - 200);
    }
}

function serializeFriends(userId) {
    const set = ensureFriendSet(userId);
    const result = [];

    for (const friendId of set) {
        const profile = userDirectory.get(friendId);
        if (profile) result.push(profile);
    }

    return result;
}

function serializeNotifications(userId) {
    const map = ensureRequestMap(userId);

    return Array.from(map.values()).map((profile) => ({
        type: 'friend_request',
        user: profile
    }));
}

function serializePresence(userId) {
    const presence = {};
    const typing = {};
    const friendSet = ensureFriendSet(userId);
    const now = Date.now();

    for (const friendId of friendSet) {
        const active = activeUsers.get(friendId);

        presence[String(friendId)] =
            !!active &&
            now - active.lastSeen <= USER_TTL_MS;

        const typingKey = `${friendId}:${userId}`;
        const typingEntry = typingStates.get(typingKey);

        typing[String(friendId)] =
            !!typingEntry &&
            now - typingEntry.at <= TYPING_TTL_MS &&
            typingEntry.active === true;
    }

    return {
        presence,
        typing
    };
}

function mergeClientFriends(userId, friendList) {
    const set = ensureFriendSet(userId);

    if (!Array.isArray(friendList)) return;

    for (const profile of friendList) {
        const normalized = getUserProfile(profile);

        if (!normalized || normalized.userId === userId) {
            continue;
        }

        set.add(normalized.userId);
        ensureFriendSet(normalized.userId).add(userId);
    }
}

async function fetchStickerManifest() {
    const now = Date.now();

    if (
        now - cachedStickerManifest.fetchedAt <
        STICKER_CACHE_MS
    ) {
        return cachedStickerManifest.files;
    }

    const apiUrl =
        'https://api.github.com/repos/technomilgrau/Move-block-online-update-beta-/contents/Figurinhas?ref=main';

    const response = await fetch(apiUrl, {
        headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'MoveBlockV4'
        }
    });

    if (!response.ok) {
        throw new Error(
            `GitHub manifest HTTP ${response.status}`
        );
    }

    const data = await response.json();

    const files = Array.isArray(data)
        ? data
            .filter(
                (item) =>
                    item &&
                    item.type === 'file'
            )
            .map(
                (item) =>
                    String(item.name || '')
            )
            .filter(
                (name) =>
                    /\.(png|jpe?g)$/i.test(name)
            )
        : [];

    cachedStickerManifest = {
        files: Array.from(new Set(files)).sort(
            (a, b) => a.localeCompare(b)
        ),
        fetchedAt: now
    };

    return cachedStickerManifest.files;
}

function isValidStickerName(name, manifest) {
    if (
        typeof name !== 'string' ||
        !/\.(png|jpe?g)$/i.test(name)
    ) {
        return false;
    }

    return manifest.includes(name);
}

// ============================================================
// ROTA PRINCIPAL
// ============================================================

app.get('/', (req, res) => {
    res.status(200).send('Servidor Online!');
});

// ============================================================
// PESQUISA DE USUÁRIOS
// ============================================================

app.get('/users/search', (req, res) => {
    const q = String(
        req.query.q || ''
    ).trim().toLowerCase();

    if (!q) {
        return res.json({
            users: []
        });
    }

    const users = [];

    for (const profile of userDirectory.values()) {
        const name = String(
            profile.name || ''
        ).toLowerCase();

        const displayName = String(
            profile.displayName || ''
        ).toLowerCase();

        if (
            name.includes(q) ||
            displayName.includes(q)
        ) {
            users.push(profile);
        }

        if (users.length >= 30) {
            break;
        }
    }

    res.json({
        users
    });
});

// ============================================================
// FIGURINHAS
// ============================================================

app.get('/stickers', async (req, res) => {
    try {
        const files =
            await fetchStickerManifest();

        res.json({
            files
        });
    } catch (error) {
        res.status(502).json({
            error:
                'Não foi possível obter o manifesto de Figurinhas.',
            files:
                cachedStickerManifest.files
        });
    }
});

// ============================================================
// SINCRONIZAÇÃO
// ============================================================

app.post('/sync', (req, res) => {
    const profile =
        getUserProfile(
            req.body &&
            req.body.profile
        );

    const fallbackName =
        String(
            req.body &&
            req.body.user ||
            ''
        ).trim();

    const userId =
        profile
            ? profile.userId
            : normalizeId(
                req.body &&
                req.body.userId
            );

    if (!userId) {
        return res.json({
            activeCount:
                activeUsers.size,

            chat:
                chatMessages,

            friends: [],

            notifications: [],

            presence: {},

            typing: {},

            events: []
        });
    }

    if (!profile) {
        getUserProfile({
            userId,
            name: fallbackName,
            displayName: fallbackName
        });
    }

    activeUsers.set(userId, {
        userId,
        lastSeen: Date.now()
    });

    mergeClientFriends(
        userId,
        req.body &&
        req.body.friends
    );

    const queue =
        ensureEventQueue(userId);

    const events =
        queue.splice(
            0,
            queue.length
        );

    const {
        presence,
        typing
    } = serializePresence(userId);

    res.json({
        activeCount:
            activeUsers.size,

        chat:
            chatMessages,

        friends:
            serializeFriends(userId),

        notifications:
            serializeNotifications(userId),

        presence,

        typing,

        events
    });
});

// ============================================================
// CHAT GLOBAL
// ============================================================

app.post('/send', (req, res) => {
    const user =
        String(
            req.body &&
            req.body.user ||
            ''
        ).trim();

    const msg =
        String(
            req.body &&
            req.body.msg ||
            ''
        ).trim();

    if (user && msg) {
        chatMessages.push({
            user,
            msg
        });

        if (chatMessages.length > 100) {
            chatMessages.shift();
        }
    }

    res.json({
        success: true
    });
});

// ============================================================
// ADICIONAR AMIGO
// ============================================================

app.post('/friends/request', (req, res) => {
    const from =
        getUserProfile(
            req.body &&
            req.body.from
        );

    const toUserId =
        normalizeId(
            req.body &&
            req.body.toUserId
        );

    if (!from || !toUserId) {
        return res.status(400).json({
            success: false,
            error: 'Usuário inválido.'
        });
    }

    if (from.userId === toUserId) {
        return res.status(400).json({
            success: false,
            error:
                'Não é possível adicionar a si mesmo.'
        });
    }

    const target =
        userDirectory.get(toUserId);

    if (!target) {
        return res.status(404).json({
            success: false,
            error:
                'Usuário ainda não registrado.'
        });
    }

    const fromFriends =
        ensureFriendSet(
            from.userId
        );

    if (
        fromFriends.has(toUserId)
    ) {
        return res.json({
            success: true,
            alreadyFriends: true
        });
    }

    ensureRequestMap(
        toUserId
    ).set(
        from.userId,
        from
    );

    enqueueEvent(
        toUserId,
        {
            type:
                'friend.request',

            user:
                from
        }
    );

    res.json({
        success: true
    });
});

// ============================================================
// ACEITAR AMIZADE
// ============================================================

app.post('/friends/accept', (req, res) => {
    const requesterId =
        normalizeId(
            req.body &&
            req.body.userId
        );

    const targetId =
        normalizeId(
            req.body &&
            req.body.byUserId
        );

    if (!requesterId || !targetId) {
        return res.status(400).json({
            success: false
        });
    }

    const requestMap =
        ensureRequestMap(
            targetId
        );

    const requester =
        requestMap.get(
            requesterId
        ) ||
        userDirectory.get(
            requesterId
        );

    const target =
        userDirectory.get(
            targetId
        );

    if (!requester || !target) {
        return res.status(404).json({
            success: false
        });
    }

    requestMap.delete(
        requesterId
    );

    ensureFriendSet(
        targetId
    ).add(
        requesterId
    );

    ensureFriendSet(
        requesterId
    ).add(
        targetId
    );

    enqueueEvent(
        requesterId,
        {
            type:
                'friend.accepted',

            user:
                target
        }
    );

    enqueueEvent(
        targetId,
        {
            type:
                'friend.accepted',

            user:
                requester
        }
    );

    res.json({
        success: true,
        friend:
            requester
    });
});

// ============================================================
// RECUSAR AMIZADE
// ============================================================

app.post('/friends/reject', (req, res) => {
    const requesterId =
        normalizeId(
            req.body &&
            req.body.userId
        );

    const targetId =
        normalizeId(
            req.body &&
            req.body.byUserId
        );

    if (!requesterId || !targetId) {
        return res.status(400).json({
            success: false
        });
    }

    ensureRequestMap(
        targetId
    ).delete(
        requesterId
    );

    res.json({
        success: true
    });
});

// ============================================================
// DIGITANDO...
// ============================================================

app.post('/presence/typing', (req, res) => {
    const fromUserId =
        normalizeId(
            req.body &&
            req.body.fromUserId
        );

    const toUserId =
        normalizeId(
            req.body &&
            req.body.toUserId
        );

    if (!fromUserId || !toUserId) {
        return res.status(400).json({
            success: false
        });
    }

    const friends =
        ensureFriendSet(
            fromUserId
        );

    if (
        !friends.has(toUserId)
    ) {
        return res.status(403).json({
            success: false,
            error:
                'Não são amigos.'
        });
    }

    typingStates.set(
        `${fromUserId}:${toUserId}`,
        {
            active:
                req.body.active === true,

            at:
                Date.now()
        }
    );

    res.json({
        success: true
    });
});

// ============================================================
// ENVIAR MENSAGEM PRIVADA
// ============================================================

app.post('/dm/send', async (req, res) => {
    const message =
        req.body &&
        req.body.message;

    if (
        !message ||
        typeof message !== 'object'
    ) {
        return res.status(400).json({
            success: false
        });
    }

    const senderId =
        normalizeId(
            message.senderId
        );

    const receiverId =
        normalizeId(
            message.receiverId
        );

    if (!senderId || !receiverId) {
        return res.status(400).json({
            success: false
        });
    }

    if (
        !ensureFriendSet(
            senderId
        ).has(receiverId)
    ) {
        return res.status(403).json({
            success: false,
            error:
                'Apenas amigos podem enviar mensagens privadas.'
        });
    }

    if (
        typeof message.stickerId ===
        'string'
    ) {
        try {
            const manifest =
                await fetchStickerManifest();

            if (
                !isValidStickerName(
                    message.stickerId,
                    manifest
                )
            ) {
                return res.status(400).json({
                    success: false,
                    error:
                        'Figurinha não encontrada no repositório.'
                });
            }
        } catch (error) {
            return res.status(502).json({
                success: false,
                error:
                    'Não foi possível validar a figurinha agora.'
            });
        }
    }

    const safeMessage = {
        id:
            String(
                message.id ||
                `${Date.now()}_${Math.random().toString(36).slice(2)}`
            ),

        senderId,

        senderName:
            String(
                message.senderName || ''
            ),

        senderDisplayName:
            String(
                message.senderDisplayName || ''
            ),

        receiverId,

        text:
            typeof message.text ===
            'string'
                ? message.text
                : undefined,

        stickerId:
            typeof message.stickerId ===
            'string'
                ? message.stickerId
                : undefined,

        time:
            String(
                message.time || ''
            ),

        date:
            String(
                message.date || ''
            ),

        createdAt:
            Number(
                message.createdAt
            ) ||
            Date.now(),

        edited: false,

        deleted: false
    };

    enqueueEvent(
        receiverId,
        {
            type:
                'dm.message',

            message:
                safeMessage
        }
    );

    res.json({
        success: true,
        messageId:
            safeMessage.id
    });
});

// ============================================================
// EDITAR MENSAGEM
// ============================================================

app.post('/dm/edit', (req, res) => {
    const fromUserId =
        normalizeId(
            req.body &&
            req.body.fromUserId
        );

    const toUserId =
        normalizeId(
            req.body &&
            req.body.toUserId
        );

    const messageId =
        String(
            req.body &&
            req.body.messageId ||
            ''
        );

    const text =
        String(
            req.body &&
            req.body.text ||
            ''
        );

    if (
        !fromUserId ||
        !toUserId ||
        !messageId
    ) {
        return res.status(400).json({
            success: false
        });
    }

    if (
        !ensureFriendSet(
            fromUserId
        ).has(toUserId)
    ) {
        return res.status(403).json({
            success: false
        });
    }

    enqueueEvent(
        toUserId,
        {
            type:
                'dm.edit',

            otherUserId:
                fromUserId,

            messageId,

            text,

            editedAt:
                Date.now()
        }
    );

    res.json({
        success: true
    });
});

// ============================================================
// EXCLUIR MENSAGEM
// ============================================================

app.post('/dm/delete', (req, res) => {
    const fromUserId =
        normalizeId(
            req.body &&
            req.body.fromUserId
        );

    const toUserId =
        normalizeId(
            req.body &&
            req.body.toUserId
        );

    const messageId =
        String(
            req.body &&
            req.body.messageId ||
            ''
        );

    if (
        !fromUserId ||
        !toUserId ||
        !messageId
    ) {
        return res.status(400).json({
            success: false
        });
    }

    if (
        !ensureFriendSet(
            fromUserId
        ).has(toUserId)
    ) {
        return res.status(403).json({
            success: false
        });
    }

    enqueueEvent(
        toUserId,
        {
            type:
                'dm.delete',

            otherUserId:
                fromUserId,

            messageId,

            deletedAt:
                Date.now()
        }
    );

    res.json({
        success: true
    });
});

// ============================================================
// LIMPEZA DE PRESENÇA
// ============================================================

setInterval(() => {
    const now =
        Date.now();

    for (
        const [
            userId,
            entry
        ]
        of activeUsers.entries()
    ) {
        if (
            now -
            entry.lastSeen >
            USER_TTL_MS
        ) {
            activeUsers.delete(
                userId
            );
        }
    }

    for (
        const [
            key,
            entry
        ]
        of typingStates.entries()
    ) {
        if (
            now -
            entry.at >
            TYPING_TTL_MS
        ) {
            typingStates.delete(
                key
            );
        }
    }
}, 5000);

// ============================================================
// INICIAR SERVIDOR
// ============================================================

const PORT =
    process.env.PORT || 3000;

app.listen(
    PORT,
    () =>
        console.log(
            `Servidor rodando na porta ${PORT}`
        )
);
