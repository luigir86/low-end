# Releasing to Google Play from GitHub

`.github/workflows/release-play.yml` ("Release Play") builds the signed `.aab`
from `main` and uploads it to Google Play as a **draft**. Nothing reaches the
testers until the owner opens the draft in Play Console and presses
*Review release* > *Start rollout*. Building on the PC
(`flutter build appbundle --release`, store/README.md) still works the same.

## Each release

1. A pull request raises `version:` in `pubspec.yaml` (the number after `+`
   must be higher than the last one on Play), `appVersion` in
   `lib/app/version.dart`, the release notes in
   `store/listing/<locale>/release_notes.txt` (≤ 500 characters each) and the
   history in `docs/release-checklist.md`. Merge it.
2. GitHub > **Actions** > **Release Play** > **Run workflow**, branch `main`:
   - *track*: `alpha` is Play's *Closed testing* track, `internal` is
     *Internal testing*;
   - *upload*: untick to build the `.aab` only.
3. About 15 minutes later the run is green. The bundle
   (`low-end-<version>.aab`) can be downloaded from the run page
   (*Artifacts*, kept 90 days). The log of *Check the signature* shows the
   certificate's SHA-256: it must start with `75:11:C0:4C` and end with `E7:9D`.
4. Play Console > the track > the draft release: check it, then
   *Review release* > *Start rollout*.

The workflow stops before uploading when a test fails, a secret is missing, a
release note is longer than 500 characters, or the bundle is not signed. Play
itself refuses a versionCode it already has.

## One-time setup (owner only)

### 1. A service account that can upload

1. <https://console.cloud.google.com> > create a project (e.g. "low-end-play").
2. *APIs & Services* > *Library* > **Google Play Android Developer API** > *Enable*.
3. *IAM & Admin* > *Service accounts* > *Create service account* (e.g.
   "github-release"); no roles needed in Google Cloud.
4. Open it > *Keys* > *Add key* > *Create new key* > **JSON**. A `.json` file
   is downloaded: it is a password, keep it out of the repository and of
   OneDrive, delete it once it is in GitHub.
5. Play Console > *Users and permissions* > *Invite new users*: the service
   account's e-mail (`...@...iam.gserviceaccount.com`), *App permissions* >
   Low End, with only **Release apps to testing tracks** (and *View app
   information*). Not production: production stays a manual step.

### 2. The repository secrets

GitHub > the repository > *Settings* > *Secrets and variables* > *Actions* >
*New repository secret*, five times:

| Name | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the upload keystore as text (below) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` from `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` from `android/key.properties` |
| `PLAY_SERVICE_ACCOUNT_JSON` | the whole content of the service account's `.json` |

The keystore as text, in PowerShell on the PC (the file is only read):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\ribal\Projects\Keys\LowEnd-keys\upload-keystore.jks")) | Set-Clipboard
```

then paste into the secret. Secrets are encrypted, never shown again, not
printed in logs, and not given to pull requests from forks. Only people with
write access can start the workflow.

### Why the upload key in GitHub is acceptable

With Play App Signing, Google keeps the key that signs the app for users; the
keystore here is only the **upload** key. If it ever leaked, Play support can
replace it (Play Console > *App integrity*). The original stays on the PC and
in its backup.
