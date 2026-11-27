#!/bin/sh
set -eu

cd /app

if [ ! -f package.json ] || [ ! -f package-lock.json ]; then
    echo "Realtime necesita package.json y package-lock.json en /app." >&2
    exit 1
fi

npm ci

exec npm start
