
### `README.md`

```markdown
# Instagram Autopilot Downloader & Sender

An automated pipeline for Armbian designed to monitor Instagram accounts, prioritize time-sensitive Stories, and manage media archival.

## 📂 Project Structure

* `insta-download.sh`: Multi-pass downloader using `Instaloader`.
* `insta-sender.sh`: Logic for broadcasting new media to Telegram.
* `targets.txt`: Plain text list of Instagram usernames to monitor.
* `config/`: Contains the session file (`session-kapuk2026`) to bypass login challenges.
* `downloads/`: Local storage organized by `{target}` username.

## 🚀 How it Works

The downloader uses a **Two-Pass Priority System**:
1.  **Phase 1 (Stories)**: Quickly iterates through all targets to download all active Stories before they expire. This phase has no download limit.
2.  **Phase 2 (Feed/Highlights)**: Downloads Posts, Reels, and Highlights with a safety limit (default: 10 items) and a 60s cooldown between targets to prevent rate limiting.

The sender script scans the `downloads/` directory and transmits new media to Telegram, tracking progress via local registry files to avoid duplicate uploads.

## ⏱ Scheduling (Crontab)

The automation is configured in `crontab -e`:

```bash
# High-priority Story and Feed download at 3:00 AM
0 3 * * * /bin/bash /home/root/ig-downloader/insta-download.sh

# Broadcast to Telegram daily at 11:30 PM
30 23 * * * /bin/bash /home/root/ig-downloader/insta-sender.sh
```

## 🛠 Maintenance

* **Session Management**: If downloads fail with authentication errors, update the session file in the `config/` folder using `instaloader --login`.
* **Rate Limits**: To protect the account, the script includes a 60-second sleep timer between users during the main feed download.
* **Storage**: Media is saved to `~/ig-downloader/downloads/`. Because this runs on an Armbian STB, monitor disk usage periodically.

## ⚙️ Environment
* **Host**: Armbian (STB Hardware)
* **Tools**: `Instaloader`, `bash`, `Python 3`
```

### Quick Install
To create the file on your server, run:

```bash
nano /home/root/ig-downloader/README.md
```
Then paste the content above and save (`Ctrl+O`, `Enter`, `Ctrl+X`).

This documentation will be especially helpful if you need to remember why the script runs in two phases or where to look if the `config/` session expires.
