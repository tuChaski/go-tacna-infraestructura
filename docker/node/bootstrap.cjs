const http = require('node:http');
const { Server } = require('socket.io');

const port = Number(process.env.PORT || 3001);
const corsOrigin = process.env.CORS_ORIGIN || 'http://localhost:5173';

const httpServer = http.createServer((request, response) => {
  if (request.url === '/health') {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ status: 'ok', mode: 'infrastructure-bootstrap' }));
    return;
  }

  response.writeHead(404, { 'content-type': 'application/json' });
  response.end(JSON.stringify({ error: 'not_found' }));
});

const io = new Server(httpServer, {
  cors: { origin: corsOrigin },
});

io.on('connection', (socket) => {
  console.info(`Development Socket.IO client connected: ${socket.id}`);
});

httpServer.listen(port, '0.0.0.0', () => {
  console.info(`Infrastructure Socket.IO bootstrap listening on ${port}`);
});

process.on('SIGTERM', () => {
  io.close(() => process.exit(0));
});