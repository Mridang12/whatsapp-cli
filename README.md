# whatsapp-cli

`wmsg` is a macOS command-line tool for reading local WhatsApp Desktop messages and sending text messages through WhatsApp.app automation.

## Requirements

- macOS with WhatsApp Desktop installed and signed in
- Full Disk Access for the terminal running `wmsg` to read WhatsApp's local SQLite database
- Automation permission for the terminal to control WhatsApp.app and System Events when sending

## Build

```bash
make build
./bin/wmsg --help
```

For development:

```bash
make wmsg ARGS="chats --limit 5"
make test
```

## Commands

```bash
wmsg chats --limit 10
wmsg history --chat-id 1 --limit 25 --attachments
wmsg watch --chat-id 1 --json
wmsg send --to "Jane Doe" --text "hello from wmsg" --verify --json
wmsg status --json
```

By default, the reader opens:

```text
~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite
```

Use `--db /path/to/ChatStorage.sqlite` to point at a copied fixture or another WhatsApp profile.

## Notes

Sending uses AppleScript UI automation. Contact selection depends on WhatsApp Desktop's search behavior, so pass the contact or group name exactly as it appears in WhatsApp.

