# TEMPO documentation

TEMPO is a personal, local-first task and focus app for iPhone, Android, Mac, and Windows. Your data stays on each device by default; connect your own server when you want real-time sync.

## Get started

| Goal | Guide |
| --- | --- |
| Run your own sync server | [Self-hosted sync](/en/DEPLOYMENT) |
| Configure clients and integrations | [Configuration](/en/CONFIGURATION) |
| Download the latest build | [GitHub Releases](https://github.com/FelixZoe/TEMPO/releases/latest) |

## Fast path

1. Install Docker and Docker Compose on a Linux server.
2. Copy `.env.example` to `.env`.
3. Generate a 64-character hexadecimal `SYNC_TOKEN`.
4. Start the service and place it behind HTTPS.
5. Enter the same server URL and token on every device.

TEMPO is designed for one person. Do not share the same endpoint and token with unrelated users.
