# TEMPO configuration

This guide covers client-side setup after installation. Use the [deployment guide](/en/DEPLOYMENT) to run the sync service first.

## Setup map

| Capability | Location | Required values |
| --- | --- | --- |
| Sync | Settings → Self-hosted sync | HTTPS base URL, 64-character token, unique device name |
| AI | Settings → AI assistant | Provider; direct mode also needs an API key |
| Weather | Settings → Weather and quote | QWeather API Host, key, Location ID and display city |
| RSS | RSS → Subscriptions | RSS/Atom URL and source group |

## Sync clients

Enter the same server base URL and token on every device, but use a different device name. Do not append `/v1/sync` to the URL. Save with “Verify, save and sync now”; this validates the server before credentials are persisted.

The service is designed for one person. Local writes are durable first, foreground clients receive change notifications immediately, and reconnects upload queued changes. iOS may be suspended in the background and catches up when it becomes active again.

## AI

The recommended setup keeps the provider key on your server:

```dotenv
AI_BASE_URL=https://api.openai.com/v1/chat/completions
AI_API_KEY=your-server-side-key
AI_MODEL=gpt-5.6-terra
```

Run `docker compose up -d`, then select the self-hosted provider in Qingxu. Direct OpenAI defaults to `gpt-5.6-terra`; Direct DeepSeek defaults to `deepseek-flash`. Existing custom model selections are not overwritten by an app upgrade. Direct API keys stay in platform secure storage and are not synced.

## Weather and daily quote

Use the project-specific QWeather API Host without a scheme or path, the matching API key, a Location ID and a display city. Test the connection before saving. Hitokoto provides the daily quote without a key. Weather and quote now appear at the top of Inbox and retain the latest cache while offline.

## Secrets and updates

Sync tokens, direct AI keys and weather keys never enter the sync document. Stable identifiers and signing identities are required for in-place iOS/Android upgrades. Use Settings → Software update to open the latest GitHub Release.

For proxy, backup and container troubleshooting, continue with [self-hosted deployment](/en/DEPLOYMENT).
