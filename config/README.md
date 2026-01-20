# Configuration Directory

This directory contains configuration files for the VERA-AI monitoring system.

## Setup Instructions

1. **Copy the template**:
   ```bash
   cp config_template.R config.R
   ```

2. **Edit config.R** with your credentials:
   - API keys (CrowdTangle, OpenAI)
   - Google service account path
   - Slack bot tokens
   - CrowdTangle list IDs

3. **Never commit config.R** (it's in .gitignore)

## Files

| File | Purpose | Commit? |
|------|---------|---------|
| `config_template.R` | Template with placeholders | Yes |
| `config.R` | Your actual credentials | **NO** |

## Required Credentials

### CrowdTangle API
- Obtain from CrowdTangle dashboard (deprecated August 2024)
- For new projects, use Meta Content Library

### Google Service Account
1. Create project at [Google Cloud Console](https://console.cloud.google.com)
2. Enable Sheets and Drive APIs
3. Create service account and download JSON key
4. Share target Google Sheet with service account email

### Slack Bot
1. Create app at [Slack API](https://api.slack.com/apps)
2. Add bot token scopes: `chat:write`, `files:write`
3. Install to workspace
4. Copy bot token (starts with `xoxb-`)

### OpenAI API
- Obtain from [OpenAI Platform](https://platform.openai.com/api-keys)
- Used for GPT-4 network labeling (optional but recommended)

## Parameters Reference

See `config_template.R` comments for detailed parameter descriptions.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `dryrun` | `FALSE` | Skip writes for testing |
| `timeframe` | `"6 HOUR"` | Monitoring window |
| `coordination_interval` | `"60 secs"` | Max time between coordinated posts |
| `percentile_edge_weight` | `0.95` | Network edge filtering |
| `cooR.shares_cthreshold` | `50` | Chart generation threshold |

---

*See [../docs/IMPLEMENTATION.md](../docs/IMPLEMENTATION.md) for full system documentation.*
