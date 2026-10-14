# Cómo contribuir a go-tacna-infraestructura

Las reglas completas están en la guía de Git del repo `go-tacna-docs`: `guias/git.md`.

## Resumen

- Ramas: `feature/T000-nombre`, `fix/T000-nombre`, `docs/tema`, creadas desde `develop`.
- Commits y título de PR: `tipo(alcance): descripción en imperativo`.
- Alcances de este repo: k3s, compose, ingress, db, scripts, ci.
- Todo entra por Pull Request con 1 aprobación. Nunca se sube directo a `main` ni a `develop`.
- Nunca se suben archivos `.env` ni secretos.
