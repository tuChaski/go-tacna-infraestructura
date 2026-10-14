# K3s: despliegue de Go-Tacna

Estos manifiestos son una base de despliegue, no una instalación ejecutada ni verificada en el VPS. No contienen secretos. El despliegue completo requiere imágenes de backend, frontend y Location Service publicadas en un registry; los valores `REPLACE_WITH_TAG` se deben cambiar por tags existentes antes de aplicar los manifiestos.

## Instalar K3s en el VPS

Ejecuta estos pasos manualmente por SSH como administrador. Confirma primero acceso de consola, espacio en disco, reglas del firewall y respaldos. K3s queda configurado para no instalar Traefik, porque el diseño de Go-Tacna mantiene Nginx global en el host.

```bash
curl -sfL https://get.k3s.io | sh -s - --disable traefik
sudo k3s kubectl get nodes
```

No abras el puerto NodePort `30081` al público. El Nginx global del host debe conectarse a `127.0.0.1:30081`; verifica que la configuración de red del VPS permita ese acceso local antes de cambiar el proxy.

## Herramientas de administración

Alias y autocompletado Bash para el usuario que administra K3s:

```bash
echo 'alias k="sudo k3s kubectl"' >> ~/.bashrc
echo 'source <(sudo k3s kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc
k get nodes
```

K9s es opcional. Instálalo desde una fuente que hayas verificado y confirma el binario antes de usarlo con permisos de administrador. El instalador web indicado por el proyecto es:

```bash
curl -sS https://webinstall.dev/k9s | bash
```

Luego ejecuta `k9s` para inspeccionar pods, servicios y logs.

## Preparar imágenes y secretos

Antes de desplegar:

1. Construye y publica imágenes versionadas para Laravel, frontend y Location Service en un registry accesible desde el VPS. No uses `latest` para despliegues repetibles.
2. Sustituye los tres tags `REPLACE_WITH_TAG` en `backend.yaml`, `frontend.yaml` y `websocket.yaml` por las imágenes publicadas. Si el registry es privado, crea también un `imagePullSecret` y asócialo a los Pods.
3. Crea el namespace y prepara fuera del repositorio un archivo de variables con permisos `0600`. Debe incluir `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `APP_KEY` y `JWT_SECRET`. No guardes ese archivo en Git.

Ejemplo de creación del Secret usando una ruta protegida del VPS:

```bash
sudo install -m 600 /dev/null /root/gotacna-secrets.env
sudo nano /root/gotacna-secrets.env
sudo k3s kubectl apply -f k8s/namespace.yaml
sudo k3s kubectl -n gotacna create secret generic gotacna-secrets \
  --from-env-file=/root/gotacna-secrets.env
```

Kubernetes Secrets no sustituyen el cifrado y control de acceso de etcd. Para producción, habilita cifrado en reposo y restringe RBAC; considera SOPS o un gestor de secretos si el equipo adopta GitOps.

## Validar y aplicar

Desde la raíz de `go-tacna-infraestructura`, una vez actualizadas las imágenes y creado el Secret:

```bash
sudo k3s kubectl kustomize k8s/
sudo k3s kubectl apply -k k8s/
sudo k3s kubectl -n gotacna get pods,services,pvc
sudo k3s kubectl -n gotacna rollout status statefulset/postgres
sudo k3s kubectl -n gotacna rollout status deployment/backend
```

El gateway queda como `NodePort 30081`; configura el Nginx global para pasar el tráfico del dominio a `http://127.0.0.1:30081`. La terminación TLS sigue siendo responsabilidad del Nginx global. Revisa healthchecks, logs y reglas de firewall antes de publicar cambios.

## Estado y limitaciones

- PostgreSQL usa una PVC `10Gi` con la clase `local-path` que K3s instala por defecto. Es almacenamiento local del nodo, no alta disponibilidad ni respaldo.
- El backend necesita una imagen que exponga HTTP en `8000` y `/up`; los manifiestos no construyen ni publican imágenes.
- El frontend debe compilarse con `VITE_API_BASE_URL=/api/v1` y `VITE_WS_URL=https://go-tacna.site` (o el origen público real), ya que Vite incorpora esos valores al bundle durante el build.
- Location Service aún necesita una imagen ejecutable con `/health`, Socket.IO y el contrato de negocio. El bootstrap de Compose no es una imagen de producción.
- La configuración de Nginx en `k8s/gateway.yaml` refleja `docker/nginx/default.conf`; mantenlas sincronizadas cuando cambien las rutas.
- Ejecutar `kubectl apply` crea recursos y puede iniciar servicios; estos pasos quedan para el operador del VPS. No se han ejecutado desde esta implementación.