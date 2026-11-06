# Conversation summary

## Scope

This summary combines the pre-Velvet history in the supplied
`CONVERSATION_LOG.md` with the current Velvet Playbook session.

## Before Velvet branding

The earlier playbook lineage was called Carbon Playbook and later TinyOS.
That history covered:

- AME Wizard playbook structure and deployment lifecycle
- AppX and provisioned-package cleanup
- Edge and OneDrive removal
- Windows registry and OEM branding
- theme and wallpaper deployment
- profile-picture propagation
- VLC UWP and other application installation
- removal of legacy runtime/tooling components

Those records explain prior design intent but do not override the current Velvet
repository's names, paths, or package policy.

## Current Velvet work

The main problem was that `setup.ps1` sometimes stopped at an early progress
step, appeared to complete after a child script exited, or incorrectly treated
network and package failures as success. The setup flow was rewritten to:

1. Run child scripts in separate PowerShell processes.
2. Capture exact child exit codes.
3. Print timestamped progress and heartbeat messages.
4. Preserve the scheduled task when required work fails.
5. Avoid stale `Completed=1` state preventing recovery.
6. Reboot only after the full required flow succeeds.

Package installation was strengthened with:

- WinGet path resolution through `Start-Process`
- TCP-based network detection
- direct vendor installers for KakaoTalk, Bandizip, and qView
- required/optional failure classification
- package result recording in `packages_installed.flag`
- mandatory verification of Microsoft PC Manager and VLC UWP

Windows 11 26H2 compatibility work added validation and fallbacks for modern
shell and policy behavior. It also addressed AppCompat remnants, Edge ghost
registrations, loaded user hives, profile propagation, Start/Search settings,
Dynamic Lighting, Do Not Disturb, Explorer Home/Gallery, Quick Access, Recycle
Bin namespace pinning, and Folder Options.

## Current outcome

- Latest package-policy commit: `a274c7c92915bac50f6a3fbe4e3b378f2e4b4245`
- Latest Windows 11 compatibility commit: `ba2136279a67cb2366c62a1c7508b89879a254ee`
- Changes were pushed to `origin/main`.
- PowerShell 5.1 parser checks and `git diff --check` passed for the relevant
  changes.
- Store package metadata for PC Manager and VLC was checked through WinGet.
- Actual end-to-end installation on a clean Windows 11 26H2 machine remains the
  definitive runtime check.

## Follow-up priorities

1. Run the package installer on a clean Windows 11 26H2 system and inspect
   `C:\ProgramData\Velvet\packages_installed.flag`.
2. Confirm PC Manager and VLC appear in AppX and WinGet verification results.
3. Confirm the scheduled task is removed only after all required steps pass.
4. Confirm modern Windows UI behavior after Explorer/Start refresh.
5. Keep local memory exports synchronized with important commits and decisions.
