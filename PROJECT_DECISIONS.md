# Windows playbook decisions

## 2026-11-06 — Child scripts run in separate PowerShell processes

`setup.ps1` owns sequencing. Child scripts do not invoke the next child script.
Each child runs in a separate `powershell.exe` process so its `exit` statement
cannot terminate the parent. The parent waits for completion and checks the
actual process exit code.

## 2026-11-06 — Completion is failure-aware

The setup task is not considered complete when one child exits successfully.
Any failed required step prevents `Completed=1`, task deletion, and automatic
reboot. The scheduled task remains available for a later retry.

## 2026-11-07 — All essential packages use WinGet; Store and PC Manager are removed

All essential packages (`Google.QuickShare`, `RamenSoftware.Windhawk`, `Google.Chrome`,
`ONLYOFFICE.DesktopEditors`, `Kakao.KakaoTalk`, `7zip.7zip`) are installed via `winget`.
Microsoft Store (`Microsoft.WindowsStore`) and Microsoft PC Manager are removed and
deprovisioned. Windows Photos (`Microsoft.Windows.Photos`), standard Paint (`Microsoft.Paint`),
modern Notepad (`Microsoft.WindowsNotepad`), Calculator (`Microsoft.WindowsCalculator`),
and media extensions are preserved. Static bloatware is removed in `appx.yml`, while
`remove-bloatware.ps1` only targets apps that auto-install or re-provision after first logon.

## 2026-11-06 — Network checks use TCP fallback

`Invoke-WebRequest` TLS validation can report a false offline state on systems
with certificate-chain problems. Package setup uses TCP connectivity checks to
Microsoft and GitHub endpoints instead of treating one HTTPS request as the
sole source of truth.

## 2026-11-06 — WebView2 is protected by default

The shared Microsoft Edge WebView2 runtime can be required by Windows features
and installed applications. The cleanup flow removes separately identifiable
Edge/Copilot packages and stale registrations but does not delete the shared
runtime by default. Any future removal must be explicit and opt-in.

## 2026-11-06 — Windows 11 26H2 settings are verification-based

Modern PolicyManager paths and supported APIs are preferred. Legacy registry
values can be written as fallbacks, but the scripts must verify the resulting
value and report warnings when the Windows shell does not expose or honor it.

## 2026-11-06 — Shared memory is local-first

Cross-client history should be stored locally in SQLite or Markdown/JSON, with
the same MCP server and database path configured in Claude, GPT-compatible
clients, and Argon. Raw conversation logs should not be uploaded by default;
summaries, decisions, changed files, and commit identifiers are preferred.

## 2026-11-06 — Personal content is excluded

Shared project memory stores technical project context only. Personal
questions, private-life details, credentials, account identifiers, contact
information, and other sensitive personal data are excluded from Markdown,
JSON, SQLite, and exported memory files.
