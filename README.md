# Go Tacna — Infraestructura local

Este repositorio reúne los contenedores de la base de datos, API, Socket.IO y web. Los archivos de código siguen en los repositorios hermanos y se montan o compilan desde allí.

```text
rutas-en-tiempo-real/
├── rutas-en-tiempo-real-infraestructura/  ← ejecutar Docker Compose aquí
├── rutas-en-tiempo-real-backend/          ← Laravel y realtime
├── rutas-en-tiempo-real-frontend/         ← web React
└── rutas-en-tiempo-real-movil/            ← Expo, fuera de Docker
```

## Requisitos y primer arranque en Manjaro

Necesitas Docker Engine con `docker compose` v2. Docker instala PHP, Node y PostgreSQL **dentro de los contenedores**; no hace falta instalar extensiones PHP en Manjaro.

```bash
sudo systemctl start docker
cd /home/david/Documentos/rutas-en-tiempo-real/rutas-en-tiempo-real-infraestructura
cp .env.example .env                 # solo si todavía no existe .env
```

La primera compilación descarga imágenes y puede tardar varios minutos. Si ya existe `.env`, consérvalo: contiene tus preferencias locales. Si los repositorios están en otras carpetas, cambia `BACKEND_PATH`, `GATEWAY_PATH`, `REALTIME_PATH` y `FRONTEND_PATH` en ese archivo antes de arrancar.

### Configurar las claves del `.env`

Antes del primer arranque, abre **el `.env` de esta carpeta**. Cambia `DB_PASSWORD` por una contraseña local y genera tres valores nuevos en la terminal:

```bash
printf 'base64:%s\n' "$(openssl rand -base64 32)"  # APP_KEY del core
printf 'base64:%s\n' "$(openssl rand -base64 32)"  # GATEWAY_APP_KEY
openssl rand -hex 32                        # JWT_SECRET
```

Copia cada resultado en su variable correspondiente del `.env`. `APP_KEY` y `GATEWAY_APP_KEY` deben ser **diferentes**. El `JWT_SECRET` se escribe **una sola vez**: Docker entrega ese mismo valor al core Laravel y al servidor Socket.IO. No copies estos secretos al README ni los subas a Git. Los valores de `.env.example` son ejemplos para desarrollo, no claves personales.

Al usar Compose, **no necesitas crear ni copiar los `.env` de `gotacna-backend-core`, `gotacna-api-gateway` o `realtime`**. Tampoco necesitas ejecutar `php artisan key:generate` ni `php artisan jwt:secret` en Manjaro: las variables del `.env` de infraestructura se pasan directamente a los contenedores. Si cambias `DB_PASSWORD` después de crear el volumen de PostgreSQL, la contraseña almacenada en esa base no cambia automáticamente; conserva la original o actualízala dentro de PostgreSQL.

Con el `.env` configurado, inicia los servicios:

```bash
sudo docker compose up -d --build --wait
sudo docker compose ps
```

## Qué arranca

| Servicio Compose | Código o imagen | Función |
| --- | --- | --- |
| `postgres` | `postgis/postgis:16-3.4-alpine` | Base de datos PostgreSQL con PostGIS y volumen persistente |
| `backend` | `backend/gotacna-backend-core` | Laravel: instala Composer, migra y carga datos demo si `SEED_DEMO_DATA=true` |
| `gateway` | `backend/gotacna-api-gateway` | Reenvía `/api/*` al core |
| `websocket` | `backend/realtime` | Ejecuta el servidor Node real con salas y ETA |
| `frontend` | `rutas-en-tiempo-real-frontend` | Compila React y lo sirve con Nginx |
| `nginx` | `docker/nginx/default.conf` | Punto de entrada común en `:8001` |

Core, gateway y Node usan variables de entorno del Compose. El core y Node reciben el mismo `JWT_SECRET`. El `.env` de infraestructura es distinto de los `.env` que usarías al arrancar cada servicio manualmente.

## Abrir y comprobar

Abre `http://localhost:8001` para la web. La API está en `http://localhost:8001/api/v1/rutas`. Socket.IO se sirve en `http://localhost:8001/socket.io/` y puedes comprobar el handshake con:

```bash
curl 'http://localhost:8001/socket.io/?EIO=4&transport=polling'
```

La respuesta de Socket.IO debe comenzar por `0{`. Los puertos internos `:8000` y `:3001` no se publican en el host; usa `:8001` para la web, la API y Socket.IO. PostgreSQL se publica solo en `127.0.0.1:5432` para herramientas locales.

## Acceso desde un teléfono

Por defecto `:8001` solo escucha en `127.0.0.1`, así que un teléfono no puede entrar. En `.env` cambia:

```dotenv
GATEWAY_BIND_HOST=0.0.0.0
```

Aplica el cambio y averigua la IP local de la laptop:

```bash
sudo docker compose up -d --force-recreate nginx
hostname -I
```

Con el teléfono en la misma red Wi-Fi, abre `http://IP_DE_TU_LAPTOP:8001/api/v1/rutas`. Si falla, permite el puerto 8001 en el firewall local. Para abrir la **web** desde esa IP, ajusta además `APP_URL`, `VITE_WS_URL`, `CORS_ORIGIN` y `CORS_ALLOWED_ORIGINS` al origen `http://IP_DE_TU_LAPTOP:8001` y reconstruye con `sudo docker compose up -d --build --wait`. El proyecto móvil se arranca aparte con Expo; consulta su [README](../rutas-en-tiempo-real-movil/README.md).

## Trabajo diario y errores

```bash
sudo docker compose up -d                 # arranque normal
sudo docker compose ps                    # estado de los servicios
sudo docker compose logs --tail=100       # últimos errores
sudo docker compose logs -f backend gateway websocket
sudo docker compose down                  # detener, conservando la base de datos
```

Ejecuta estos comandos desde esta carpeta. Si un contenedor no queda `Healthy`, mira sus logs. Si `:8001` está ocupado, detén el `php artisan serve` local que use ese puerto o cambia `GATEWAY_PUBLISHED_PORT` en `.env`. `docker compose down -v` **borra los volúmenes y los datos locales**; úsalo solo si deseas reiniciar la base desde cero.

El frontend se compila durante `up --build`. Para ver cambios de su código en Docker, reconstruye `frontend` y `nginx`; para desarrollo con recarga inmediata, usa `npm run dev` en el repositorio frontend y deja el backend de Docker encendido.

El despliegue K3s está documentado por separado en [k8s/README.md](k8s/README.md).
