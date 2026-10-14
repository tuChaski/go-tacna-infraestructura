#!/bin/sh
set -eu

cd /app

if [ ! -f package.json ] || [ ! -f package-lock.json ]; then
    echo "Location Service necesita package.json y package-lock.json en /app." >&2
    exit 1
fi

npm ci

if node -e "const p = require('./package.json'); process.exit(p.scripts && p.scripts.start ? 0 : 1)"; then
    exec npm start
fi

echo "No existe npm start en Location Service; usando el bootstrap Socket.IO de desarrollo de infraestructura."
exec node /opt/gotacna-bootstrap/bootstrap.cjs