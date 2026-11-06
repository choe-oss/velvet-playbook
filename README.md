# Velvet Playbook

[![Velvet](https://img.shields.io/badge/Velvet-Edition-blue.svg)](https://github.com/velvet-project/velvet-playbook)
[![Windows](https://img.shields.io/badge/Windows-Compatible-0078D6.svg)](https://microsoft.com)
[![License](https://img.shields.io/badge/License-GPLv3%20%2F%20Custom-green.svg)](#license)

> **Velvet** is a high-performance Windows Playbook designed for AME Wizard.  
> It preserves core security (Windows Defender, Core Isolation) and system compatibility while eliminating unnecessary background telemetry, bloatware, and high-resource processes for maximum responsiveness.

---

## 🚀 Key Features

### 1. Post-Desktop Interactive Setup
* **User Context Execution**: All settings and package installations execute reliably within the logged-in user profile.
* **Verbose Debug Console**: An elevated console window opens upon desktop login and displays the complete timestamped step, child-process, warning, and error stream without creating a log file. Every child script emits timestamped internal checkpoints, so the last checkpoint identifies the actual operation where execution is delayed.
* **Automated Clean Reboot**: After optimization and package deployment complete, a 10-second countdown safely reboots the system.

### 2. Velvet Theme & Custom Visuals
* **Velvet Theme (`Velvet.theme`)**: Registered directly in Windows Personalization themes (`ms-settings:themes`), supporting Dark Mode and system accent color.
* **Customizable Lock Screen**: Clean lock screen applied with no restrictive policies, allowing free personalization.

### 3. Powerful Debloat
* **UWP & Stock App Debloat**: Strips out unnecessary UWP apps, sponsored packages, OEM bloatware, Windows Terminal, and unneeded app runtimes while strictly preserving and updating `Microsoft.DesktopAppInstaller` (WinGet).
* **Microsoft Edge & OneDrive Removal**: Safely removes Edge browser and OneDrive with error tolerance.

### 4. Essential Software Suite
1. **Google Chrome** (`Google.Chrome`) + automated AdGuard extension policy
2. **Microsoft PC Manager** (`9pm860492szd` via WinGet)
3. **VLC Media Player** (`9NBLGGH4VVNH` via WinGet)
4. **voidtools Everything** (`voidtools.Everything`)
5. **ONLYOFFICE Desktop Editors** (`ONLYOFFICE.DesktopEditors`)
6. **Google Quick Share** (`Google.QuickShare`)
7. **Windhawk** (`RamenSoftware.Windhawk`) with the bundled Taskbar Styler mod
8. **KakaoTalk** (`Kakao.KakaoTalk`) using the vendor silent installer link
9. **Bandizip** (`Bandisoft.Bandizip`) using the vendor silent installer link
10. **qView** using the qView 7.1 release installer link

WinGet is used where a package is available through the local client. The playbook does not
download or execute arbitrary vendor installers at runtime, except the explicitly
configured KakaoTalk, Bandizip, and qView vendor links. Microsoft PC Manager and VLC UWP
are optional Store packages; their Store deployment errors are recorded but do not
block setup. KakaoTalk, Bandizip, and qView are required packages.

Windows 11 26H2 shell compatibility is checked by
`Executables/config-shell-compatibility.ps1`. Legacy registry values are verified
with warnings, while supported PolicyManager equivalents are applied and the
Explorer/Start shell is refreshed.

Windows 11 26H2 settings compatibility is applied by
`Executables/config-windows11-settings.ps1`. It configures the supported
PolicyManager paths for Start, taskbar search, Dynamic Lighting, and shell
refresh, while retaining legacy values only as fallbacks. It also synchronizes
PowerShell execution policy, taskbar End task, Folder Options, Explorer
Home/Gallery visibility, Quick Access metadata, Recycle Bin namespace pinning,
Do Not Disturb legacy profiles, and Windows registered-owner/OEM information.
Unsupported or missing Windows policy values are reported as warnings rather
than being treated as proof that the UI changed.

The script deliberately does not delete the shared Edge WebView2 runtime by
default: Windows components and third-party applications may depend on it.
`remove-bloatware.ps1 -RemoveWebView` is an explicit opt-in that attempts the
registered WebView2 uninstaller and reports its exit code; it is not used by
the normal setup flow. Removable Edge/Copilot AppX packages, Remote Desktop
AppX packages, Web Media Extensions, and stale Edge registrations are handled
by the bloatware and Edge cleanup passes, with failures shown in the setup
console. The built-in `mstsc.exe` is never deleted.

Application Compatibility cleanup disables the optional AppCompat inventory,
PCA, UAR, and telemetry policies and removes only per-program compatibility
registration/cache data. Shared AppCompat services, binaries, and the Windows
compatibility infrastructure remain installed to avoid breaking application
launch and setup reliability. PowerShell execution policy verification reports
Group Policy overrides and AppLocker rules separately; a registry value alone
is never treated as proof that script execution is permitted.

Windows 11 settings are applied to the current user, loaded user hives, and
machine policy paths where supported. About-page values use Windows'
`RegisteredOwner`, `RegisteredOrganization`, and OEM Information keys; the
visible fields vary by edition. The theme is copied to the system, current
user, and Default user Themes folders, registered through `CurrentTheme` and
`InstalledThemes`, and verified before Explorer refresh. Unsupported Home,
Gallery, Dynamic Lighting, or Start policy paths produce warnings rather than
success-shaped output.

### 5. Core System & Security Integrity
* **Windows Defender Always Active**: Tamper protection and real-time scanning remain intact.
* **VBS & Core Isolation Supported**: Memory integrity (HVCI) and kernel hardware-enforced stack protection remain supported.
* **Integrated Pop-up Blocker**: Microsoft PC Manager pop-up management is enabled.

---

## 📂 File Structure

```
.
├── Configuration/
│   ├── main.yml                     # Playbook Main Orchestration
│   └── Tasks/
│       ├── start.yml                # Initialization & Staging
│       ├── software.yml             # Browser Policies
│       ├── services.yml             # Service Tweaks
│       ├── registry.yml             # Registry Tweaks
│       ├── revert.yml               # Revert Tasks
│       ├── final.yml                # First-Logon Setup Task Registration
│       ├── packages/                # AppX & Feature Removal
│       └── registry/                # Category Registry YAMLs
├── Executables/
│   ├── setup.ps1                    # Main Post-Desktop Setup Script
│   ├── register-setup-task.ps1      # "Velvet-Setup" At-Logon Task (Highest, no UAC)
│   ├── stage-files.ps1              # Asset Staging to C:\ProgramData\Velvet
│   ├── config-theme.ps1             # Themes & Wallpapers Configuration
│   ├── config-user-preferences.ps1   # User, Explorer, Start & Taskbar Preferences
│   ├── config-shell-compatibility.ps1 # Windows 11 26H2 shell compatibility
│   ├── config-windows11-settings.ps1 # Windows 11 26H2 policy and shell settings
│   ├── config-application-settings.ps1 # Installed application settings
│   ├── config-profile.ps1           # User Profile Picture
│   ├── config-notepad.ps1           # Modern Notepad Configuration
│   ├── config-associations.ps1      # Default File Associations
│   ├── config-taskbarpins.ps1       # Taskbar Pin Cleanup
│   ├── config-startmenu.ps1         # Start Menu Grid & Pin Layout
│   ├── config-features.ps1          # Optional Features Configuration
│   ├── config-windhawk.ps1          # Windhawk Taskbar Configuration
│   ├── install-packages.ps1         # Software Packages Deployment
│   ├── remove-bloatware.ps1         # Bloatware Appx Removal
│   ├── remove-edge.ps1              # Edge Browser Safe Removal
│   ├── remove-onedrive.ps1          # OneDrive Removal
│   ├── cleaner.ps1                  # Disk & Cache Cleaner
│   ├── finalize-system.cmd          # BCD & OEM System Information
│   ├── user.png                     # Account Profile Image
│   ├── Themes/
│   │   └── Velvet.theme             # Velvet Windows Dark Theme
│   ├── Wallpapers/
│   │   ├── desktop.jpg              # Desktop Wallpaper
│   │   └── lockscreen.jpg           # Lockscreen Wallpaper
│   ├── Windhawk/                    # Windhawk Taskbar Styler source, profile, and module
│   ├── Licenses/
│   │   └── THIRD-PARTY-NOTICES.md   # Third-Party Notices & Attribution Audit
│   ├── default-layouts.xml          # Default Layouts XML
│   ├── layout-modification.xml      # Layout Modification XML
│   ├── layout-modification.json     # Layout Modification JSON
│   ├── oem-default-associations.xml # Default Associations XML
│   └── settings.json                # WinGet Settings JSON
├── playbook.conf                    # AME Wizard Master Configuration
├── playbook.png                     # Master Playbook Icon
├── LICENSE                          # GNU General Public License v3.0 (GPL-3.0)
└── README.md                        # Documentation & License Notices
```

---

## 🛠️ Deployment

1. Load `Velvet.apbx` in AME Wizard.
2. Follow the wizard to complete deployment and restart the system.
3. Sign in to your Windows user account.
4. The **`Velvet - Post-Installation Setup`** console will appear on the desktop without another UAC prompt. Like macOS verbose boot output, the setup window always prints timestamped step records, child-script stdout/stderr, exit codes, and errors directly in the running console without creating a log file.

---

## 📄 License

This project is licensed under the **[GNU General Public License v3.0 (GPL-3.0)](./LICENSE)**.
See [**`Executables/Licenses/THIRD-PARTY-NOTICES.md`**](./Executables/Licenses/THIRD-PARTY-NOTICES.md) for third-party notices and upstream attribution.
