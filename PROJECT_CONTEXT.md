# Velvet Playbook project context

## Project

- **Repository:** `choe-oss/velvet-playbook`
- **Purpose:** Windows 11 playbook deployment and first-logon optimization.
- **Primary setup path:** `C:\ProgramData\Velvet`
- **Main orchestrator:** `Executables/setup.ps1`
- **Target environment:** Windows PowerShell 5.1 and Windows 11 26H2.

## Current architecture

`setup.ps1` runs child PowerShell scripts as separate processes. It captures
their exit codes, displays timestamped checkpoints, records step failures, and
only marks the installation complete when all required steps succeed. The
first-logon scheduled task runs elevated so the normal path does not display a
second UAC prompt.

The package installer writes diagnostic results to:

```text
C:\ProgramData\Velvet\packages_installed.flag
```

Required package failures must return exit code `1`; optional package failures
must remain visible without blocking the rest of setup.

## Windows 11 26H2 compatibility

The compatibility layer applies supported policy paths where available and
keeps legacy registry values only as fallbacks. It verifies values instead of
assuming that writing a registry key changed the Windows UI.

Covered areas include:

- Do Not Disturb / legacy Quiet Hours profiles
- PowerShell execution policy
- Taskbar End task
- Registered owner and OEM support information
- Dynamic Lighting
- Start pinned layout and taskbar search
- Cross-device resume
- Explorer Home and Gallery namespace visibility
- Quick Access metadata and Recycle Bin namespace pinning
- Folder Options values
- Edge ghost registrations and stale shortcuts/OpenWith entries
- Loaded user registry hives and profile picture propagation
- Safe AppCompat policy/cache cleanup

The shared Edge WebView2 runtime is not removed by default because Windows and
third-party applications may depend on it. Removable Edge/Copilot AppX
packages and stale registrations are handled separately.

## Package policy

The following are required:

- Google Chrome
- Google Quick Share
- Windhawk
- Microsoft PC Manager (`9pm860492szd`, `msstore`)
- VLC UWP (`9NBLGGH4VVNH`, `msstore`)
- voidtools Everything
- ONLYOFFICE Desktop Editors
- KakaoTalk
- Bandizip
- qView

Microsoft Store installations are verified through AppX checks for the current
user, all users, and provisioned packages, plus `winget list` where available.
Store source diagnostics and installer output are retained in the package flag.

## Historical context

`CONVERSATION_LOG.md` predates the Velvet Playbook branding. It records the
earlier Carbon Playbook/TinyOS lineage and earlier decisions around AppX
removal, VLC installation, package deployment, themes, profiles, and setup
orchestration. It should be treated as project history, not as the current
source-of-truth for file names or branding.

## Important commits

| Commit | Meaning |
|---|---|
| `3bb6a3b` | Parent/child setup execution stabilization |
| `fd9702d` | Child exit-code and cleaner wait fixes |
| `1d2aba0` | WinGet process invocation fix |
| `db0d38c` | Stale completion state recovery |
| `8291b34` | Direct app installs and shell compatibility |
| `e72b48d` | qView installation |
| `ba2136279a67cb2366c62a1c7508b89879a254ee` | Windows 11 26H2 compatibility hardening |
| `a274c7c92915bac50f6a3fbe4e3b378f2e4b4245` | VLC/PC Manager required installation and verification |

## Operational cautions

- Do not use same-process dot-sourcing for child scripts that call `exit`.
- Do not treat a successful-looking WinGet exit code as proof of Store
  installation.
- Do not silently convert required failures into optional failures.
- Do not delete the shared WebView2 runtime without an explicit opt-in.
- Registry paths that are unsupported by the current Windows shell must produce
  a warning or verification failure, not a false success.
