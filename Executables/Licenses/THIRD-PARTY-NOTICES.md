# Third-Party Notices and Open-Source Licensing Compliance

This document provides detailed licensing information and attribution for upstream projects, documentation, and references incorporated or consulted during the development of the **Velvet Playbook**.

The **Velvet Playbook** project is licensed under the [GNU General Public License v3.0 (GPL-3.0)](../../LICENSE).

---

## 1. Upstream Project Attributions & Legal Audit

### A. Amelabs (AME Wizard Playbook Architecture)
- **Source**: [Amelabs Official Documentation](https://docs.amelabs.net)
- **Nature of Use**: Configuration schema and action directives (`playbook.conf`, `!registryValue`, `!powerShell`, `!cmd`, `!run`, `!appx`, `!task`).
- **Copyright & Compliance**:
  - The playbook YAML schema is an open specification designed for community playbooks.
  - The Velvet Playbook contains original configuration directives and does **not** bundle or redistribute proprietary AME Wizard binaries (`TrustedUninstaller.exe`, `AME Wizard.exe`).
  - **Verdict**: 100% compliant.

### B. AtlasOS
- **Source**: [AtlasOS GitHub Repository](https://github.com/Atlas-OS/Atlas)
- **License**: [GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.html)
- **Nature of Use**: Registry tweak definitions (telemetry, background diagnostics, search mode, service state tracking).
- **Copyright & Compliance**:
  - Windows registry keys, paths, and values (`DWORD 0/1`, `REG_SZ`) represent configuration parameters of the Microsoft Windows operating system and are not subject to copyright (*Lotus Dev. Corp. v. Borland Int'l, Inc.*).
  - Procedural PowerShell scripts, state-tracking conventions, and debloat logic originating from or inspired by AtlasOS are licensed under GPL-3.0, fulfilling the copyleft requirements of the GPL-3.0 license.
  - **Verdict**: 100% compliant under GPL-3.0.

### C. ReviOS
- **Source**: [Revision AME Playbook Repository](https://github.com/MeetRevision)
- **License**: GNU General Public License v3.0 / MIT License
- **Nature of Use**: Explorer view tweaks, optional feature identification, and user interface preferences.
- **Copyright & Compliance**:
  - Incorporates configuration parameters and PowerShell scripts compatible with GPL-3.0.
  - Full author attribution maintained.
  - **Verdict**: 100% compliant under GPL-3.0.

### D. Rufus
- **Source**: [Rufus by Pete Batard / Akeo Consulting](https://github.com/pbatard/rufus)
- **License**: [GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.html)
- **Nature of Use**: Windows 11 hardware requirement bypass keys (`BypassTPMCheck`, `BypassSecureBootCheck`, `BypassRAMCheck`, `BypassCPUCheck`, `BypassStorageCheck`, `PreventDeviceEncryption`).
- **Copyright & Compliance**:
  - The `LabConfig` registry bypass flags are official Microsoft Windows Setup keys documented by Microsoft and popularized by Rufus `res/wue/wue.c`.
  - Setting these registry keys does not constitute distributing copyrighted Rufus code, but credit is formally attributed here.
  - **Verdict**: 100% compliant.

### E. UniGetUI (formerly WingetUI)
- **Source**: [UniGetUI by SomePythonThings](https://github.com/marticliment/UniGetUI)
- **License**: [GNU Lesser General Public License v3.0 (LGPL-3.0)](https://www.gnu.org/licenses/lgpl-3.0.html)
- **Nature of Use**: Identification of standard WinGet Package Identifiers (`Google.Chrome`, `9pm860492szd`, `9NBLGGH4VVNH`, `voidtools.Everything`, `ONLYOFFICE.DesktopEditors`, `Google.QuickShare`, `RamenSoftware.Windhawk`).
- **Copyright & Compliance**:
  - Package IDs are public strings registered in the community repository (`microsoft/winget-pkgs`).
  - No UniGetUI compiled binaries or UI code are bundled in this playbook.
  - **Verdict**: 100% compliant.

### F. Windhawk & Windows 11 Taskbar Styler
- **Source**: [Ramen Software / m417z](https://github.com/ramensoftware/windhawk-mods)
- **License**: [GNU General Public License v3.0 (GPL-3.0)](https://www.gnu.org/licenses/gpl-3.0.html)
- **Nature of Use**: `windows-11-taskbar-styler.wh.cpp` source is retained for reference; no compiled module DLL is bundled or deployed.
- **Copyright & Compliance**:
  - Distributed strictly under GPL-3.0 with complete source code (`windows-11-taskbar-styler.wh.cpp`) included in the repository.
  - Author copyright notice (`// @author m417z`) preserved verbatim in source headers.
  - **Verdict**: 100% compliant under GPL-3.0.

---

## 2. Program Installation Methods: Copyright Analysis

The Velvet Playbook uses two methods to deploy software:
1. **Microsoft WinGet (`winget.exe`)**:
   - The official Microsoft Windows Package Manager.
   - At runtime, WinGet connects directly to official vendor servers and downloads the vendor's installer directly to the target system.
   - The playbook merely issues standard CLI commands (`winget install --id ...`).
2. **Direct Vendor CDN / Official Web Download**:
   - No direct vendor installer is downloaded or executed by the current playbook.

### Legal Verdict on Software Deployment:
- **No Unauthorized Binary Redistribution**:
  Proprietary commercial installers (e.g., Google Chrome, Bandizip, KakaoTalk, Microsoft PC Manager) are **NOT bundled or stored** within the `.apbx` or `.zip` playbook archives.
- **Package-manager retrieval**:
  Applications are retrieved by the local WinGet client using package IDs and source agreements.
- **Standard User Execution**:
  Applications requiring user-context installation (e.g. KakaoTalk) are executed with standard non-elevated user permissions without decompiling or modifying vendor executables.

---

## 3. Summary of Repository Licensing

| Component | Source / Author | License | Bundle Status |
| :--- | :--- | :--- | :--- |
| **Velvet Playbook** | Velvet Project | **GPL-3.0** | Source Repository |
| **Taskbar Styler Mod** | m417z (Ramen Software) | **GPL-3.0** | Source (`.wh.cpp`) + Binary |
| **Wallpapers & Avatar** | Velvet Project | **CC-BY-4.0 / GPL-3.0** | Included |
| **Scripts & YAMLs** | Velvet Project (incorporating AtlasOS/ReviOS logic) | **GPL-3.0** | Included |
| **Google Chrome** | Google LLC | Proprietary | Downloaded at runtime via WinGet |
| **Microsoft PC Manager** | Microsoft Corp. | Proprietary | Downloaded at runtime via WinGet (`9pm860492szd`) |
| **KakaoTalk** | Kakao Corp. | Proprietary | Downloaded at runtime via official CDN |
| **Bandizip (Beta)** | Bandisoft | Proprietary | Downloaded at runtime via official Bandisoft portal |
| **VLC Media Player** | VideoLAN | GPL-2.0+ | Downloaded at runtime via WinGet |
| **qView** | jurplel | GPL-3.0 | Downloaded at runtime via GitHub Releases |
| **ONLYOFFICE** | Ascensio System SIA | AGPL-3.0 | Downloaded at runtime via WinGet |
| **Everything** | voidtools | Freeware | Downloaded at runtime via WinGet |
