# Mem0 on lab

This runs the Mem0 self-hosted REST API, dashboard, and Postgres/pgvector on
the lab host. The API and dashboard are reachable only through Tailscale, and
Postgres plus the API history database live under `/mnt/encrypted/mem0`.

The API and dashboard images are built from the Mem0 source revision pinned in
`default.nix`; the upstream Docker Hub API image is not used. Mem0 stores
memories in Postgres with pgvector. Model calls use the existing lab
OpenAI-compatible proxy for extraction and lab Ollama for embeddings.

## Configure secrets

Create the agenix environment file from the lab checkout:

```sh
agenix -e hosts/lab/mem0/environment.env.age
```

Include these entries (use the model-proxy API key as `OPENAI_API_KEY`):

```dotenv
OPENAI_API_KEY=your-lab-proxy-api-key
JWT_SECRET=generate-a-long-random-secret
POSTGRES_PASSWORD=generate-a-different-long-random-password
```

For example, generate independent values with `openssl rand -base64 48` and
paste them into the encrypted file. Do not commit a plaintext `.env` file. The
NixOS module is enabled only when `environment.env.age` exists.

Deploy the lab configuration with the usual `deploy -r lab` command. The first
deployment builds the two application images on lab and can take several
minutes. The service waits for `/mnt/encrypted` to be mounted before starting.

## First login and model setup

Open `http://lab.tail4a3ea.ts.net:3000` over Tailscale and complete the
one-time admin setup wizard. Create an API key in the dashboard for each
client that will call Mem0.

In the dashboard's **Configuration** page, configure the LLM and embedder.
Use the existing gpt-6-luna model through the lab proxy for extraction, and
the already-installed `qllama/bge-small-en-v1.5` Ollama model for embeddings:

```json
{
  "llm": {
    "provider": "openai",
    "config": {
      "model": "gpt-6-luna",
      "api_key": "<OPENAI_API_KEY from the agenix file>",
      "openai_base_url": "http://host.docker.internal:8317/v1",
      "temperature": 0.2
    }
  },
  "embedder": {
    "provider": "openai",
    "config": {
      "model": "qllama/bge-small-en-v1.5",
      "api_key": "ollama",
      "openai_base_url": "http://host.docker.internal:11434/v1"
    }
  }
}
```

The API and dashboard must use the same Tailscale DNS name configured in
`default.nix` for dashboard access and CORS. The configuration page saves model
overrides in Mem0's Postgres app database, so they persist across restarts.

The API is at `http://lab.tail4a3ea.ts.net:8888`; its OpenAPI explorer is at
`/docs`. OSS endpoints do not use the hosted platform's `/v1/` prefix. Send
client requests with `X-API-Key: <issued Mem0 key>`.

## Operations

```sh
sudo systemctl status mem0-stack
sudo journalctl -u mem0-stack -f
sudo docker compose --project-name mem0 --file /nix/store/*-mem0-compose.yaml ps
```

Redeploy after changing the Nix source pin or compose definition. Running `systemctl stop mem0-stack` stops the containers but keeps all data. Do not run `docker compose down --volumes` unless you intend to delete the database and memories. The NixOS module prunes request logs older than 30 days once a week.
