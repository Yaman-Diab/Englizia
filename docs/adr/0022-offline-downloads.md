# 22. Lessons downloaded to open with no connection

Status: Accepted · Date: 2026-11-18

## Context
The owner asked (2026-11-18) that a learner can download lessons, video included, and open them with no connection, inside the app only: nothing downloaded may be usable outside it, and downloads must not grow without bound. This overrides student doc §21, which keeps a lesson's text only, streams every video, and puts downloading a whole track out of scope; the document needs updating.

No app can make copying impossible: a rooted phone, or a camera pointed at the screen, gets past anything. The aim is that nothing on the phone is a usable file, and that what is kept stops opening without the server's word.

## Decision

**Where and how it is kept**
- `MediaVault` (`core/media/`) keeps everything in the app's own support folder: not the cache (the system empties it), not shared storage, the gallery or the downloads folder. Android's backup is off for the app; iOS keeps the folder out of iCloud and computer backups.
- Pictures, clips, the lesson itself and the list of downloads are sealed with AES-256-GCM. The key is made on the phone and lives in the Keystore or Keychain (`flutter_secure_storage`); it never leaves the phone. A file copied off it is noise, and one that was changed is refused.
- A file is named by a hash of its address without the query, so the folder says nothing of what it holds and a signed link that changes still finds its file. A file two lessons share is kept once.
- A file is written beside its place and moved, so it is whole or absent.

**Video**
- The lightest rendition of the HLS stream is kept, part by part, and only one whose sound is inside its own files. Its segments stay sealed on the phone with HLS's own AES-128: by the stream's key when it came sealed, else by a key the phone makes. Keys are sealed with the vault's key.
- The phone's player only plays from an address, so `MediaServer` serves the vault to it on `127.0.0.1` alone, on a port the system picks, under a secret made when it starts. Segments leave it still sealed and the player opens them itself with the key it asks for; no unsealed video is ever written. Clips are opened in memory and served the same way; pictures are decoded from memory.
- That needs cleartext to this phone only: Android's `network_security_config.xml` allows `127.0.0.1` and `localhost` and nothing else; iOS has `NSAllowsLocalNetworking`.
- A lesson's video is still kept from being captured while it plays (ADR 18).
- Real DRM (Widevine, FairPlay) would be stronger, but needs licence servers that must work in Syria and a streaming service that offers it, neither decided (STATUS D-021).

**For a while, and for the account**
- A download opens offline until the panel's `validDays` pass; then the server is asked again: the same version opens for another while, a new version is fetched again, and a lesson no longer offered is removed. The moment it runs out is sealed with the lesson.
- Downloads go with the account: signing out, or another account signing in, removes them and throws the key away. A guest's upgrade keeps them, as it is the same account.

**So downloads don't grow without bound**
- By hand only: a lesson, or a unit, from the unit screen. Nothing bigger, and nothing by itself.
- Every limit is the panel's, in the effective settings (`downloads`): the room all downloads may take, how many lessons, how long they open, the room to leave on the phone, and after how long a completed lesson's download is removed. With no limits, nothing about downloads is shown.
- A download says its size and the phone's free room before it starts, and is refused when it doesn't fit.
- «عبر Wi-Fi فقط» is on until the learner turns it off.
- What is half done after a cut is kept and carried on; whatever no download names any more is swept.
- «التنزيلات» in the settings shows the room taken and removes one or all.

**Packages**: `cryptography` with `cryptography_flutter` (AES-GCM by the platform's own code; HLS's AES-CBC runs in Dart off the main isolate) and `path_provider`. No download-manager package: a queue of one lesson at a time on `MediaClient`, which sends no session to a file's host.

## Consequences
- Downloads run while the app is open; a closed app carries on at its next start.
- The phone's clock decides when a download runs out, so a clock set back keeps one open longer.
- The server must give each lesson's files with their sizes (docs/api/downloads.md, proposed). Until then mock mode downloads made-up files.
- Unchecked on a device: playing a kept video through the local server on both platforms above all (STATUS D-119).
