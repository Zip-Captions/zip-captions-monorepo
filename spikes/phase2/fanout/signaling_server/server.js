// Spike 2.1 — throwaway signaling relay. Not the real SignalingService (Unit 3 doesn't exist yet).
//
// Protocol (JSON messages over one WebSocket connection per participant):
//   Broadcaster -> server: { type: "broadcaster-hello", broadcastId }
//   Viewer      -> server: { type: "viewer-hello", broadcastId, viewerId }
//   Server -> broadcaster: { type: "viewer-joined", viewerId }
//   Broadcaster -> server -> viewer: { type: "offer", viewerId, sdp }
//   Viewer -> server -> broadcaster: { type: "answer", viewerId, sdp }
//   Either -> server -> other: { type: "ice", viewerId, from: "broadcaster"|"viewer", candidate }
//   Server -> viewer (if no broadcaster yet): { type: "error", reason: "no-broadcaster" }
//
// One broadcaster per broadcastId at a time. Messages are routed by broadcastId + viewerId only —
// there is no auth, no persistence, no reconnection handling. This is a load-generation tool, not a
// reference implementation.

const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT || 8090);

/** @type {Map<string, { broadcaster: import('ws').WebSocket | null, viewers: Map<string, import('ws').WebSocket> }>} */
const rooms = new Map();

function roomFor(broadcastId) {
  let room = rooms.get(broadcastId);
  if (!room) {
    room = { broadcaster: null, viewers: new Map() };
    rooms.set(broadcastId, room);
  }
  return room;
}

const wss = new WebSocketServer({ port: PORT });

wss.on('connection', (ws) => {
  let role = null;
  let broadcastId = null;
  let viewerId = null;

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }

    switch (msg.type) {
      case 'broadcaster-hello': {
        role = 'broadcaster';
        broadcastId = msg.broadcastId;
        const room = roomFor(broadcastId);
        room.broadcaster = ws;
        console.log(`[relay] broadcaster connected for "${broadcastId}"`);
        break;
      }

      case 'viewer-hello': {
        role = 'viewer';
        broadcastId = msg.broadcastId;
        viewerId = msg.viewerId;
        const room = roomFor(broadcastId);
        room.viewers.set(viewerId, ws);
        if (room.broadcaster && room.broadcaster.readyState === ws.OPEN) {
          room.broadcaster.send(JSON.stringify({ type: 'viewer-joined', viewerId }));
        } else {
          ws.send(JSON.stringify({ type: 'error', reason: 'no-broadcaster' }));
        }
        break;
      }

      case 'offer':
      case 'answer':
      case 'ice': {
        const room = rooms.get(broadcastId);
        if (!room) return;
        const target = role === 'broadcaster' ? room.viewers.get(msg.viewerId) : room.broadcaster;
        if (target && target.readyState === ws.OPEN) {
          target.send(JSON.stringify({ ...msg, from: role }));
        }
        break;
      }

      default:
        console.warn(`[relay] unknown message type: ${msg.type}`);
    }
  });

  ws.on('close', () => {
    if (!broadcastId) return;
    const room = rooms.get(broadcastId);
    if (!room) return;
    if (role === 'broadcaster' && room.broadcaster === ws) {
      room.broadcaster = null;
      console.log(`[relay] broadcaster disconnected for "${broadcastId}"`);
    } else if (role === 'viewer' && viewerId) {
      room.viewers.delete(viewerId);
    }
  });
});

console.log(`[relay] Spike 2.1 signaling relay listening on ws://localhost:${PORT}`);
