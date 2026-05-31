# whatsapp-cli

`wmsg` is a macOS command-line tool for reading local WhatsApp Desktop messages and sending text messages through WhatsApp.app automation.

It reads WhatsApp's local SQLite database in read-only mode and sends through WhatsApp.app using AppleScript UI automation.

## Requirements

- macOS with WhatsApp Desktop installed and signed in
- Full Disk Access for the terminal running `wmsg` to read WhatsApp's local SQLite database
- Automation permission for the terminal to control WhatsApp.app and System Events when sending

## Build and install

```bash
make build
./bin/wmsg --help
```

For development:

```bash
make wmsg ARGS="chats --limit 5"
make test
```

## Database path

By default, `wmsg` opens:

```text
~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite
```

Every command that reads the database accepts `--db /path/to/ChatStorage.sqlite`, which is useful for copied fixtures or alternate WhatsApp profiles.

## Global usage

```bash
wmsg <command> [options]
wmsg --help
wmsg --version
wmsg <command> --help
```

Most commands support:

| Option | Description |
| --- | --- |
| `--db <path>` | Path to `ChatStorage.sqlite`. |
| `--json` | Emit newline-delimited JSON. |
| `--verbose` | Reserved for verbose diagnostics. |

## Command list

```bash
wmsg chats --limit 10
wmsg history --chat-id 1 --limit 25 --attachments
wmsg watch --chat-id 1 --json
wmsg send --to "Jane Doe" --text "hello from wmsg" --verify --json
wmsg status --json
```

## `wmsg chats`

List recent WhatsApp conversations.

```bash
wmsg chats [--limit <count>] [--include-system] [--db <path>] [--json]
```

| Option | Description | Default |
| --- | --- | --- |
| `--limit <count>` | Number of chats to list. | `20` |
| `--include-system` | Include WhatsApp status/broadcast pseudo-sessions. | off |

By default, `chats` hides WhatsApp status/broadcast pseudo-sessions so contacts do not appear twice because of recent status updates. Text output includes the chat row id, display name, WhatsApp identifier, last-message timestamp, group marker, and unread count when nonzero. JSON output includes `id`, `identifier`, `name`, `lastMessageAt`, `lastMessageText`, `unreadCount`, `isArchived`, `isRemoved`, `isGroup`, `sessionType`, and `participants`.

Examples:

```bash
wmsg chats --limit 5
wmsg chats --limit 5 --json
wmsg chats --limit 5 --include-system
```

## `wmsg history`

Show recent messages for a chat. Use `wmsg chats` first to find the chat row id.

```bash
wmsg history --chat-id <rowid> [--limit <count>] [--participants <jid[,jid...]>] [--start <iso8601>] [--end <iso8601>] [--attachments] [--db <path>] [--json]
```

| Option | Description | Default |
| --- | --- | --- |
| `--chat-id <rowid>` | Required chat row id from `wmsg chats`. | none |
| `--limit <count>` | Number of messages to show. | `50` |
| `--participants <jid[,jid...]>` | Filter by comma-separated sender JIDs, such as `me,+15551234567@s.whatsapp.net`. | none |
| `--start <iso8601>` | Inclusive ISO8601 start time. | none |
| `--end <iso8601>` | Exclusive ISO8601 end time. | none |
| `--attachments` | Include attachment metadata. Without it, text output only shows an attachment count. | off |

Messages are returned newest first. JSON output includes `rowID`, `chatID`, `sender`, `senderName`, `text`, `date`, `isFromMe`, `stanzaID`, `fromJID`, `toJID`, `messageType`, `messageStatus`, `errorStatus`, `attachmentsCount`, and optional `attachments`.

Examples:

```bash
wmsg history --chat-id 1 --limit 20
wmsg history --chat-id 1 --start 2026-01-01T00:00:00Z --end 2026-02-01T00:00:00Z
wmsg history --chat-id 1 --participants me --attachments --json
```

## `wmsg watch`

Stream new WhatsApp messages by polling the local database.

```bash
wmsg watch [--chat-id <rowid>] [--from-row-id <rowid>] [--poll-interval <seconds>] [--batch-limit <count>] [--db <path>] [--json]
```

| Option | Description | Default |
| --- | --- | --- |
| `--chat-id <rowid>` | Limit the stream to one chat. | all chats |
| `--from-row-id <rowid>` | Start after a specific message row id. | current newest row |
| `--poll-interval <seconds>` | Poll interval in seconds. | `0.5` |
| `--batch-limit <count>` | Maximum messages emitted per poll. | `100` |

Without `--from-row-id`, `watch` starts from the current newest database row and only emits future messages.

Examples:

```bash
wmsg watch
wmsg watch --chat-id 1 --json
wmsg watch --from-row-id 12345 --poll-interval 1
```

## `wmsg send`

Send a WhatsApp text message through WhatsApp.app UI automation.

```bash
wmsg send --to <contact-or-group-name> --text <message> [--chat-id <rowid>] [--search-delay <seconds>] [--select-offset <count>] [--verify] [--no-restore-clipboard] [--db <path>] [--json]
```

| Option | Description | Default |
| --- | --- | --- |
| `--to <name>` | Required contact or group name as shown in WhatsApp. | none |
| `--text <message>` | Required message body. | none |
| `--chat-id <rowid>` | Chat row id used when verifying the sent message. | none |
| `--search-delay <seconds>` | Seconds to wait for WhatsApp search results. | `1.5` |
| `--select-offset <count>` | Down-arrow presses before opening a search result. | `2` |
| `--verify` | After sending, look for the sent message in the database. | off |
| `--no-restore-clipboard` | Leave the sent text on the clipboard instead of restoring the old clipboard. | off |

`send` uses WhatsApp search, selects a result, pastes the message through the clipboard, and presses Return. Contact selection depends on WhatsApp Desktop's current UI/search behavior, so pass the contact or group name exactly as it appears in WhatsApp. The first run may trigger macOS Automation permission prompts.

Examples:

```bash
wmsg send --to "Jane Doe" --text "hello"
wmsg send --to "Family" --text "hello" --verify --json
wmsg send --to "Jane Doe" --text "hello" --search-delay 2 --select-offset 1
```

## `wmsg status`

Check whether the database can be read and whether WhatsApp.app appears to be running.

```bash
wmsg status [--db <path>] [--json]
```

Text output reports database status, database errors, WhatsApp process status, and automation errors. JSON output includes `databasePath`, `databaseReadable`, `databaseError`, `whatsAppRunning`, and `automationError`.

Examples:

```bash
wmsg status
wmsg status --json
```

## Notes

- Reading requires Full Disk Access for the terminal because WhatsApp stores its database in a protected macOS container.
- Sending requires Automation permission for WhatsApp.app and System Events.
- `wmsg` does not modify the WhatsApp database directly; reads are read-only and sends go through WhatsApp.app.
