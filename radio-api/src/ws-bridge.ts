import { ChildProcessWithoutNullStreams, spawn } from 'child_process'
import WebSocket from 'ws'

function harborUrl(): string {
  const pass = process.env.HARBOR_PASSWORD
  const host = process.env.LIQUIDSOAP_HOST ?? 'liquidsoap'
  const port = process.env.HARBOR_PORT ?? '8005'
  if (!pass) throw new Error('HARBOR_PASSWORD is not set')
  return `icecast://source:${pass}@${host}:${port}/live`
}

export function handleDJSession(ws: WebSocket): void {
  let ff: ChildProcessWithoutNullStreams | null = null
  let alive = true

  function spawnFfmpeg(): void {
    let url: string
    try { url = harborUrl() } catch (e) {
      console.error(e)
      ws.close(1011, 'Server misconfiguration')
      return
    }

    // Browser sends WebM/Opus chunks via MediaRecorder.
    // ffmpeg decodes WebM from stdin and re-encodes to MP3 for the harbor.
    // -fflags +nobuffer: don't buffer input — reduces latency.
    // -flags +low_delay: minimise codec delay.
    ff = spawn('ffmpeg', [
      '-hide_banner', '-loglevel', 'warning',
      '-fflags', '+nobuffer',
      '-flags', '+low_delay',
      '-i', 'pipe:0',
      '-acodec', 'libmp3lame',
      '-b:a', '320k',
      '-ar', '44100',
      '-ac', '2',
      '-f', 'mp3',
      '-content_type', 'audio/mpeg',
      url,
    ])

    ff.stderr.on('data', (d: Buffer) => process.stderr.write(d))

    ff.on('exit', (code) => {
      console.log(`[ws-bridge] ffmpeg exited with code ${code}`)
      // If ffmpeg dies unexpectedly while DJ is still connected, close WS.
      if (alive) ws.close(1011, 'ffmpeg exited')
    })

    console.log('[ws-bridge] ffmpeg started → harbor')
  }

  spawnFfmpeg()

  ws.on('message', (data: Buffer) => {
    // Write binary audio chunks (WebM frames) to ffmpeg stdin.
    // If stdin is no longer writable, the ffmpeg process already exited.
    if (ff?.stdin?.writable) ff.stdin.write(data)
  })

  ws.on('close', (code, reason) => {
    alive = false
    console.log(`[ws-bridge] DJ disconnected (${code} ${reason})`)
    if (ff) {
      // Give ffmpeg a moment to flush its output buffer before killing.
      ff.stdin?.end()
      setTimeout(() => { if (ff) { ff.kill('SIGTERM'); ff = null } }, 2000)
    }
  })

  ws.on('error', (err) => {
    console.error('[ws-bridge] WS error:', err.message)
    alive = false
    ff?.kill('SIGTERM')
    ff = null
  })
}
