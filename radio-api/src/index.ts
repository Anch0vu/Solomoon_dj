import http from 'http'
import { WebSocketServer } from 'ws'
import { checkToken } from './auth'
import { handleDJSession } from './ws-bridge'

const PORT = Number(process.env.PORT ?? 8080)

// Only one DJ session at a time — a second connection closes the first.
let activeDJ: import('ws').WebSocket | null = null

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' }).end('ok')
    return
  }
  res.writeHead(404).end()
})

const wss = new WebSocketServer({ server, path: '/dj' })

wss.on('connection', (ws, req) => {
  const params = new URL(req.url ?? '', 'http://x').searchParams
  const token = params.get('token')

  if (!checkToken(token)) {
    console.warn('[radio-api] Rejected unauthorized DJ connection')
    ws.close(4001, 'Unauthorized')
    return
  }

  // Kick the previous DJ if one is connected — harbour allows only one source.
  if (activeDJ && activeDJ.readyState === activeDJ.OPEN) {
    console.log('[radio-api] Kicking previous DJ session')
    activeDJ.close(1001, 'Replaced by new session')
  }
  activeDJ = ws

  console.log('[radio-api] DJ connected')
  handleDJSession(ws)

  ws.on('close', () => {
    if (activeDJ === ws) activeDJ = null
  })
})

server.listen(PORT, () => {
  console.log(`[radio-api] listening on :${PORT}`)
})
