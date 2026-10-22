# Self-host WriteFreely with Docker

This repository builds [WriteFreely v0.17.2](https://github.com/writefreely/writefreely/tree/v0.17.2) from source and runs one blog with SQLite. Docker keeps the configuration, database, and encryption keys in the `writefreely-data` volume. A reverse proxy provides HTTPS.

## Start a blog

Install Docker with the Compose plugin. Set up a public domain and an HTTPS reverse proxy on the same host before opening the blog.

1. Build the image.

   ```sh
   docker compose build
   ```

2. Run WriteFreely's interactive setup.

   ```sh
   docker compose run --rm app config start
   ```

   Choose **Production, behind reverse proxy**, keep **Local port** at `8080`, choose **SQLite**, and enter `/data/writefreely.db` for **Filename**. Choose **Single user blog**, enter your own admin username and password, and set **Public URL** to your full `https://` URL. Answer the remaining prompts for your blog. Setup creates the SQLite schema and admin account.

3. Generate the encryption keys and start the server.

   ```sh
   docker compose run --rm app keys generate
   docker compose up -d
   ```

4. Point your HTTPS reverse proxy at `127.0.0.1:8080`. Preserve the `Host` header and forward `X-Forwarded-Proto: https` and the client IP in `X-Forwarded-For`. The Compose port is bound to the host's loopback address, so the reverse proxy must run on that host. For example, a Caddy site block can use `reverse_proxy 127.0.0.1:8080`; Caddy handles TLS and forwards these headers by default.

Open the public URL and sign in with the credentials you entered during setup. Use `docker compose logs -f app` to inspect startup errors.

## Back up the blog

Stop the app before archiving the volume so SQLite has a consistent state. Store the archive securely because it contains your configuration, account data, and encryption keys.

```sh
docker compose stop app
docker compose run --rm --no-deps --entrypoint tar app -C /data -cf - . > writefreely-backup.tar
docker compose start app
```

To restore, stop the app and use a new Compose project name. Compose creates an empty volume for the restored blog and leaves the old volume intact. Keep the `keys/` directory with its matching database.

```sh
docker compose stop app
docker compose -p writefreely-restored run --rm -T --no-deps --entrypoint tar app -C /data -xf - < writefreely-backup.tar
docker compose -p writefreely-restored up -d
```

## Upgrade WriteFreely

Update both `WRITEFREELY_REF` and `WRITEFREELY_COMMIT` in the Dockerfile to a matching upstream release tag and commit. After the backup, rebuild and run any database migration required by that WriteFreely release before starting it.

```sh
docker compose stop app
docker compose build --pull
docker compose run --rm app db migrate
docker compose up -d
```

Read the [upstream release notes](https://github.com/writefreely/writefreely/releases) for version-specific migration instructions. The image pins upstream source but package repositories and build dependencies can change; retain the image used for your last working deployment until the upgrade is confirmed.
