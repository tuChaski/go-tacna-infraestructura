# go-tacna — Infraestructura

Todo lo necesario para **instalar y ejecutar el sistema en servidores**, y también para levantarlo en tu computadora.

> **Propósito:** que el sistema funcione igual en tu laptop y en el VPS de producción, sin cambios manuales.

---

## Estado actual

La tarea **T002** agrega un entorno local en `docker-compose.yml`, con PostgreSQL 16/PostGIS, Laravel y Node.js. El Compose ampliado añade el frontend React/Vite, el API Gateway Laravel y un Nginx de entrada. Los archivos de Docker, manifiestos K3s y herramientas de operación están en este repositorio.

| Componente | Estado local |
|---|---|
| PostgreSQL 16 + PostGIS | Servicio Compose con volumen y healthcheck |
| Laravel Backend Core | Se monta desde el repo hermano `../go-tacna-backend/gotacna-backend-core`; espera PostgreSQL, instala Composer, migra, siembra una vez y expone `/up` |
| API Gateway Laravel | Se monta desde el repo hermano `../go-tacna-backend/gotacna-api-gateway`; reenvía `/api/v1/*` al core y expone `/up` |
| Nginx de entrada | Enruta `/api/` al gateway Laravel, `/socket.io/` a Node y el resto al frontend; publica solo `127.0.0.1:8001` |
| Node.js / Socket.IO | Se monta desde el repo hermano `../go-tacna-backend/go-tacna-location-service`; si no hay script `npm start`, usa un bootstrap temporal de salud/conexión Socket.IO alojado aquí |
| Frontend React/Vite | Build estático multi-stage servido por Nginx interno; las URLs Vite se fijan durante el build |
| K3s | Scaffold Kustomize en [`k8s/`](k8s/); requiere imágenes publicadas y Secret creado fuera de Git |

El servicio Location Service actual aún no tiene código de servidor ni script `start`. Por eso el bootstrap de infraestructura solo permite comprobar que Node y Socket.IO arrancan; no implementa GPS, eventos de negocio ni ETA. Cuando el servicio real incluya `npm start`, el contenedor ejecutará ese comando en lugar del bootstrap.

El seeder del core carga datos de demostración del ERD actual: empresas, administradores, conductores, pasajero, planes, rutas, micros, posiciones y una suscripción. El administrador general de prueba es `admin@gotacna.pe` / `admin123`. Las credenciales y las claves de ejemplo son exclusivamente para desarrollo local.

## Entorno local T002

Requisito: Docker Desktop con Docker Compose v2. Desde esta carpeta, el comando de inicialización es:

```bash
docker compose up -d --build --wait
```

Compose usa valores de desarrollo por defecto. Opcionalmente, copia `.env.example` a `.env` para personalizarlos. En Windows PowerShell:

```powershell
Copy-Item .env.example .env
docker compose up -d --build --wait
```

El servicio Laravel core ejecuta automáticamente `composer install`, `php artisan migrate --force` y el seeder una sola vez por volumen de bootstrap. El servicio gateway Laravel solo instala dependencias y arranca; no migra ni siembra porque no tiene base de datos propia. PostGIS se habilita al inicializar un volumen de base de datos vacío.

Comandos útiles (requieren GNU Make):

```bash
make setup
make logs
make down
```

Sin Make, se pueden usar directamente los comandos `docker compose` equivalentes. `make clean` elimina los volúmenes y borra la base de datos local.

Los repos hermanos deben existir en las rutas configuradas en `.env.example`. Si tienen otra ubicación, ajusta `BACKEND_PATH`, `GATEWAY_PATH`, `LOCATION_PATH` y `FRONTEND_PATH` en `.env`. El build de Vite incorpora sus variables `VITE_*`; al publicar bajo otro dominio, actualízalas y reconstruye la imagen.

Para instalación de K3s, secretos, NodePort, alias de `kubectl` y K9s, sigue la [guía de K3s](k8s/README.md). Esta implementación documenta los pasos pero no instala ni modifica el VPS.

## Referencia de despliegue anterior

Las secciones de producción que siguen provienen de la estructura anterior del monorepo y no describen servicios configurados por el Compose local T002. Confirma rutas, archivos y estado antes de ejecutar esos pasos.

---

## 1. Diseño anterior de entornos Compose

El diseño anterior planteaba un Compose base y un override de producción. Esos archivos no están presentes actualmente en este repositorio.

## 2. Servicios del diseño anterior

| Servicio | Función prevista |
|---|---|
| `db` | PostgreSQL 16 con PostGIS |
| `backend` | API Laravel |
| `realtime` | Tiempo real Node.js |
| `web-admin` | Web compilada |
| `nginx` | Proxy inverso |
| `certbot` | Emisión y renovación de certificados |

**Nginx es el único servicio que publica puertos.** Los demás se comunican por la red interna de Docker, con `expose` en vez de `ports`.

### PostGIS

`docker/postgres/init-postgis.sql` ejecuta `CREATE EXTENSION IF NOT EXISTS postgis;` la primera vez que se crea el volumen. Es lo que permite guardar el trazado de una ruta como una línea y calcular distancias geoespaciales.

> Si el volumen `postgres-data` ya existe, ese script **no se vuelve a ejecutar**. Para activarlo en una base existente, conéctate y lanza el `CREATE EXTENSION` a mano.

### Proxy y rutas

`deploy/nginx/default.conf`:

| Ruta | Destino |
|---|---|
| `/.well-known/acme-challenge/` | `/var/www/certbot` (para Let's Encrypt) |
| `/api/` | `gateway:8000` (gateway Laravel) → `backend:8000` (core) |
| `/socket.io/` | `realtime:3001` (con `Upgrade` / `Connection: upgrade`) |
| `/` | `web-admin:4173` |

En `/socket.io/` el `proxy_read_timeout` sube a `3600s`: sin eso, Nginx cortaría las conexiones de los pasajeros. El Nginx de entrada conserva `Host`, `X-Forwarded-Host` y `X-Forwarded-Proto` para que la paginación del core use el dominio público correcto.

---

## 3. Variables de entorno

Se define **un solo `.env` en la raíz del proyecto**, que alimenta todos los servicios.

| Variable | Por defecto | Para qué |
|---|---|---|
| `APP_KEY` | — | clave del core Laravel (**obligatoria**) |
| `GATEWAY_APP_KEY` | — | clave del gateway Laravel (**obligatoria**, distinta de `APP_KEY`) |
| `APP_URL` | `http://localhost:8001` | URL pública de la aplicación |
| `DB_DATABASE` | `gotacna_db` | base de datos |
| `DB_USERNAME` | `postgres` | usuario de PostgreSQL |
| `DB_PASSWORD` | — | clave de PostgreSQL (**obligatoria**) |
| `JWT_SECRET` | — | secreto JWT del core; si el servicio de tiempo real valida tokens, debe compartirlo (**obligatoria**) |
| `CORE_API_URL` | `http://backend:8000` | URL interna del core usada por el gateway Laravel |
| `CORE_API_TIMEOUT` | `30` | timeout del proxy del gateway en segundos |
| `CORS_ALLOWED_ORIGINS` | `http://localhost:5173,http://localhost:8001` | orígenes permitidos por la API |
| `REALTIME_PORT` | `3001` | puerto del servidor de tiempo real |
| `CORS_ORIGIN` | `http://localhost:5173` | origen permitido por Socket.IO |
| `OFFLINE_AFTER_MS` | `120000` | umbral para marcar un micro sin conexión |
| `HTTP_PORT` | `80` | puerto HTTP |
| `HTTPS_PORT` | `443` | puerto HTTPS |
| `DOMAIN` | `rutas.example.com` | dominio del certificado |
| `CERTBOT_EMAIL` | `admin@example.com` | correo para Let's Encrypt |
| `VITE_API_URL` | `http://localhost/api` | URL de la API que compila la web |
| `VITE_REALTIME_URL` | `http://localhost` | URL del servidor de tiempo real |

```bash
cp .env.example .env
```

Las variables marcadas como obligatorias están marcadas en el Compose con `${VAR:?mensaje}`, así que el Compose **falla al arrancar** en vez de levantar un servicio mal configurado.

> **Nunca subas `.env` al repositorio.** Cada repo trae su `.env.example`.

---

## 4. HTTPS (Let's Encrypt)

Android **no permite GPS sobre HTTP** fuera de `localhost`, así que el certificado no es opcional: es un requisito del Modo Conductor.

```bash
# 1. Configurar DOMAIN y CERTBOT_EMAIL en .env
# 2. Publicar el puerto 80 y apuntar el DNS al servidor
./deploy/scripts/certbot.sh
```

El script:

1. Verifica que existan `DOMAIN` y `CERTBOT_EMAIL`.
2. Pide el certificado con el desafío webroot (necesita el puerto 80 libre).
3. Genera `deploy/nginx/ssl.conf` con los certificate paths de `DOMAIN`.
4. Recarga Nginx, después de validar la configuración con `nginx -t`.

**Renovación:** el contenedor de `certbot` corre con un entrypoint propio. Para renovar sin Cron, añade el comando a un cron del servidor:

```cron
0 3 * * 0 docker compose --env-file /ruta/al/proyecto/.env -f /ruta/al/proyecto/docker/docker-compose.yml run --rm certbot renew --quiet
```

---

## 5. Despliegue

### Manual, en el servidor

```bash
cd /ruta/al/proyecto
git pull --ff-only origin main
./deploy/scripts/deploy.sh
```

`deploy.sh` se niega a seguir si falta `.env` o si no hay Docker Compose, luego hace `git pull`, valida el Compose con `config --quiet` y levanta todo con `up -d --build --remove-orphans`.

Variables opcionales de `deploy.sh`:

| Variable | Por defecto | Para qué |
|---|---|---|
| `DEPLOY_BRANCH` | `main` | rama a la que hace `pull` |
| `SKIP_GIT_PULL` | `false` | `true` omite el `pull` |

### Automático (CI/CD)

`.github/workflows/deploy.yml` se dispara al hacer push a `main` o manualmente. Se conecta por SSH al VPS y ejecuta `./deploy/scripts/deploy.sh`.

Secretos requeridos en el repositorio:

| Secreto | Contenido |
|---|---|
| `DEPLOY_HOST` | IP o dominio del VPS |
| `DEPLOY_USER` | usuario SSH |
| `DEPLOY_SSH_KEY` | clave privada SSH |
| `DEPLOY_PATH` | ruta del proyecto en el servidor |

El workflow usa el **environment `production`**, que puede requerir aprobación manual antes de desplegar.

---

## 6. Referencia histórica de Kubernetes

> **No usar esta sección para desplegar.** La guía vigente de K3s está en [`k8s/README.md`](k8s/README.md). El texto que sigue conserva decisiones previas y puede no coincidir con la infraestructura actual.

Lo anterior funciona con **Docker Compose**. Para producción segzde usar **k3s**, un Kubernetes ligero.

### Stack de producción

| Tecnología | Propósito |
|---|---|
| **k3s** | Kubernetes ligero: administra contenedores, los reinicia si fallan y los conecta entre sí |
| **Kustomize** | Define las diferencias entre staging y producción sin duplicar manifiestos |
| **Traefik** (incluido en k3s) | Recibe el tráfico y lo reparte: `/` a la web, `/api` a Laravel, `/socket.io` a Node |
| **cert-manager + Let's Encrypt** | Certificados HTTPS automáticos y renovados |
| **GitHub Actions + GHCR** | Pruebas, construcción de imágenes y despliegue automático |
| **VPS Hostinger** | Servidor en la nube |

### Por qué Traefik en lugar del Nginx actual

Traefik lee solo los manifiestos de Kubernetes: descubre los servicios y rehace el enrutado automáticamente, y renueva los certificados por su cuenta. Eso elimina el `deploy/scripts/certbot.sh` y los archivos de Nginx, que en k3s pasarían a ser un Ingress:

```yaml
# Ejemplo del Ingress que reemplazaría deploy/nginx/default.conf
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rutas
spec:
  rules:
    - host: rutas.example.com
      http:
        paths:
          - path: /api
            backend: { service: { name: backend, port: { number: 8000 } } }
          - path: /socket.io
            backend: { service: { name: realtime, port: { number: 3001 } } }
          - path: /
            backend: { service: { name: web, port: { number: 4173 } } }
```

> Esto es **objetivo, no estado actual**. La migración a k3s todavía no ha empezado.

### Entornos

- **staging:** mismo Compose con otro `.env` y otro `DOMAIN`. Sirve para verificar antes de publicar.
- **production:** `docker-compose.prod.yml` sobrepuesto, con secretos reales.

---

## 7. Problemas conocidos

1. **`docker/docker-compose.yml` apunta a `../web-admin`, una carpeta que no existe.** La carpeta real es `web`. Consecuencia: el servicio `web-admin` no puede construir su imagen y `nginx` tampoco.
2. **Faltan los `Dockerfile` de `backend/` y de `web/`.** Solo existe `realtime/Dockerfile`, así que tampoco pueden construirse.
3. **`nginx` no monta `ssl.conf`.** `docker-compose.prod.yml` publica el 443, pero `deploy/nginx/` se monta completo como `/etc/nginx/conf.d`, así que el archivo sí estaría disponible — sin embargo **nunca se genera** hasta correr `certbot.sh`. Hasta entonces el 443 no sirve nada.
4. **El job `web-admin` de la CI nunca se ejecuta**, porque detecta `web-admin/package-lock.json`.
5. **El estado del tiempo real es en memoria**: si el contenedor de `realtime` se reinicia, se pierde el mapa de posiciones. Aceptable en el MVP, pero no hay persistencia ni alta disponibilidad.

---

## 8. Comandos útiles

```bash
# Estado de los servicios
docker compose --env-file .env -f docker/docker-compose.yml ps

# Ver solo el tiempo real
docker compose --env-file .env -f docker/docker-compose.yml logs -f realtime

# Reiniciar un solo servicio
docker compose --env-file .env -f docker/docker-compose.yml restart realtime

# Validar la configuración sin levantar nada
docker compose --env-file .env -f docker/docker-compose.yml config --quiet

# Validar la configuración de Nginx
docker compose --env-file .env -f docker/docker-compose.yml exec -T nginx nginx -t

# Entrar a PostgreSQL
docker compose --env-file .env -f docker/docker-compose.yml exec db psql -U gotacna -d gotacna
```

---

## 9. Seguridad

- **Nunca subas `.env`.** Va en `.gitignore`; solo se versiona `.env.example`.
- **`JWT_SECRET`, `DB_PASSWORD` y las claves de despliegue** se configuran como secretos: en GitHub Actions como *secrets*, en producción como variables del entorno del servidor.
- **El acceso a la base de datos no se publica:** no tiene `ports`, solo `expose`. Desde fuera solo se entra por Nginx.
- **HTTPS es obligatorio**, porque Android bloquea el GPS sobre conexiones inseguras.
- Let's Encrypt exige que el **puerto 80 esté libre** y que el DNS apunte al servidor antes de pedir el certificado.

---

## 10. Equipo

| Integrante | Rol prioritario |
|---|---|
| Royfrankly Navarro | Coordinación general, Backend y DevOps |
| David Montador | Arquitectura de software y módulo GPS en tiempo real |
| Alex Huaracha | Diseño UI/UX y desarrollo Frontend/Móvil |
| Edison Catari | Calidad (QA), pruebas y automatización |

---

## 11. Glosario

- **Contenedor / imagen:** una imagen es la "receta empaquetada" de un servicio; un contenedor es esa imagen en ejecución.
- **Kubernetes / k3s:** sistema que administra muchos contenedores en un servidor.
- **Ingress:** objeto de Kubernetes que declara qué ruta va a qué servicio.
- **Kustomize:** herramienta que genera manifiestos por entorno sin duplicarlos.
- **Staging:** entorno de pruebas igual al real, donde se verifica antes de publicar.
- **Traefik:** proxy inverso que además emite y renueva certificados.
- **webroot de ACME:** carpeta donde se validan los desafíos de Let's Encrypt (`/.well-known/acme-challenge/`).
- **CI/CD:** automatización que prueba (CI) y despliega (CD) el código al subir cambios.

---

## 12. Enlaces

| Repositorio | Propósito |
|---|---|
| `go-tacna-infraestructura` | Este repositorio. Docker, k3s, Traefik y despliegue. |
| `go-tacna-backend` | API Laravel y servidor de tiempo real. |
| `go-tacna-frontend` | Web pública y panel de administración. |
| `go-tacna-movil` | App Android (Pasajero y Modo Conductor). |
| `go-tacna-docs` | Informe, requisitos, contratos y cronograma. |

Tablero de tareas: [Planificación go-tacna](https://github.com/orgs/go-tacna/projects/1)