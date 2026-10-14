# PostgreSQL local

`init-postgis.sql` is mounted into the official PostGIS image's initialization directory. It runs only when PostgreSQL initializes an empty `postgres_data` volume. The image supplies the PostGIS extension; this script enables it in the configured database.

If the volume already existed before adding this script, recreate the local database volume with `docker compose down -v` before starting the environment again. This deletes local database data.