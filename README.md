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
* **Interactive Progress Window**: An elevated console window opens upon desktop login to display real-time, step-by-step progress.
* **Automated Clean Reboot**: After optimization and package deployment complete, a 10-second countdown safely reboots the system.

### 2. Velvet Theme & Custom Visuals
* **Velvet Theme (`Velvet.theme`)**: Registered directly in Windows Personalization themes (`ms-settings:themes`), supporting Dark Mode and system accent color.
* **Customizable Lock Screen**: Clean lock screen applied with no restrictive policies, allowing free personalization.

### 3. Powerful Debloat
* **UWP & Stock App Debloat**: Strips out unnecessary UWP apps, sponsored packages, OEM bloatware, Windows Terminal, and unneeded app runtimes while strictly preserving and updating `Microsoft.DesktopAppInstaller` (WinGet).
* **Microsoft Edge & OneDrive Removal**: Safely removes Edge browser and OneDrive with error tolerance.

### 4. Essential Software Suite
1. **Google Chrome** (`Google.Chrome`) + automated AdGuard extension policy
2. **Bandizip (Official Beta)** - Direct download from `https://kr.bandisoft.com/bandizip/dl.php?beta`
3. **Microsoft PC Manager** (`9pm860492szd` via WinGet) - Automated pop-up management and Bandizip pop-up blocking toggle configuration
4. **VLC Media Player** (`9NBLGGH4VVNH` via WinGet)
5. **voidtools Everything** (`voidtools.Everything`)
6. **qView** (Official 64-bit silent direct install)
7. **KakaoTalk** (Official CDN 64-bit silent user-mode install)
8. **ONLYOFFICE Desktop Editors** (`ONLYOFFICE.DesktopEditors`)
9. **Google Quick Share** (`Google.QuickShare`)
10. **Windhawk** (`RamenSoftware.Windhawk`) + Taskbar Styler (SimplyTransparent)

### 5. Core System & Security Integrity
* **Windows Defender Always Active**: Tamper protection and real-time scanning remain intact.
* **VBS & Core Isolation Supported**: Memory integrity (HVCI) and kernel hardware-enforced stack protection remain supported.
* **Integrated Pop-up Blocker**: Microsoft PC Manager pop-up management enabled with Bandizip pop-up block button activated.

---

## 📂 File Structure

```
src/
├── Configuration/
│   ├── main.yml                     # Playbook Main Orchestration
│   └── Tasks/
│       ├── start.yml                # Initialization & Staging
│       ├── software.yml             # Browser Policies
│       ├── services.yml             # Service Tweaks
│       ├── registry.yml             # Registry Tweaks
│       ├── revert.yml               # Revert Tasks
│       ├── final.yml                # Post-Desktop RunOnce Registration
│       ├── packages/                # AppX & Feature Removal
│       └── registry/                # Category Registry YAMLs
├── Executables/
│   ├── setup.ps1                    # Main Post-Desktop Setup Script
│   ├── stage-files.ps1              # Asset Staging to C:\ProgramData\Velvet
│   ├── config-theme.ps1             # Themes & Wallpapers Configuration
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
│   ├── Windhawk/                    # Windhawk Taskbar Styler Source (.wh.cpp)
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
4. The **`Velvet - Post-Installation Setup`** console will appear on the desktop, configure the theme, install software packages, set up file associations and pop-up blocking, and then safely restart the system after a 10-second countdown.

---

## 📄 License

This project is licensed under the **[GNU General Public License v3.0 (GPL-3.0)](./LICENSE)**.
See [**`Executables/Licenses/THIRD-PARTY-NOTICES.md`**](./Executables/Licenses/THIRD-PARTY-NOTICES.md) for third-party notices and upstream attribution.
