# Remote Access Setup Plan

> Created: 2026-03-24 (work PC session)
> Goal: Bidirectional remote access between work PC and home PC. Either endpoint can reach the other at any time — for running `wip`, full GUI access, or simultaneous use of both machines.
> **Standalone plan file — no edits to existing files. Merge on home PC after setup.**

---

## Device Registry

| Device | Tailscale Name | Tailscale IP | Role |
|--------|---------------|--------------|------|
| Work PC | `gsadus-vadim` | `100.92.227.106` | Configured 2026-03-24 |
| Home PC | _(pending)_ | _(pending)_ | Configure when back |

---

## Progress Summary

### gsadus-vadim (Work PC) — 2026-03-24

| # | Step | Status |
|---|------|--------|
| 1 | Disable sleep (set to Never) | ✅ Done |
| 2 | Disable hibernate (`powercfg -h off`) | ✅ Done |
| 3 | Set `NoAutoRebootWithLoggedOnUsers` registry key | ✅ Done |
| 4 | Install Tailscale + sign in | ✅ Done — `gsadus-vadim` / `100.92.227.106` |
| 5 | Install OpenSSH Server | ✅ Done |
| 6 | Start sshd + set to Automatic | ✅ Done |
| 7 | Set default SSH shell to pwsh | ✅ Done — `C:\Program Files\PowerShell\7\pwsh.exe` |
| 8 | Set up SSH key auth (administrators_authorized_keys) | ✅ Done — key auth confirmed, no password needed |
| 9 | Test SSH locally (`ssh localhost`) | ✅ Done — pwsh session opened successfully |
| 10 | Install Chrome Remote Desktop + set PIN | ⬜ Next |
| 11 | Test CRD from phone | ⬜ Pending |
| 12 | Reboot + verify all services auto-start | ⬜ Pending |
| 13 | Lock screen (Win+L) — do NOT sign out | ⬜ Before leaving |

### Home PC — pending physical access

| # | Step | Status |
|---|------|--------|
| 1 | Install Tailscale (same account) | ⬜ Pending |
| 2 | Install OpenSSH Server + set default shell to pwsh | ⬜ Pending |
| 3 | Set up SSH key auth (generate key, add work PC's public key) | ⬜ Pending |
| 4 | Install Chrome Remote Desktop + set PIN | ⬜ Pending |
| 5 | Disable sleep + hibernate | ⬜ Pending |
| 6 | Set `NoAutoRebootWithLoggedOnUsers` registry key | ⬜ Pending |
| 7 | Test: `ssh gsadus-vadim` → pwsh on work PC | ⬜ Pending |
| 8 | Test: CRD → connect to work PC from browser | ⬜ Pending |
| 9 | Set up SSH keys bidirectionally | ⬜ Pending |
| 10 | Reboot → verify everything auto-starts | ⬜ Pending |
| 11 | Update `end-day` in `profile.ps1` — replace shutdown with screen lock | ⬜ Pending |

---

## Power Policy (CRITICAL — both PCs)

### Display off only. No sleep. No hibernate.

Sleep and hibernate cut network access — neither Tailscale nor CRD can wake a sleeping PC remotely. The fix is simple: let the display turn off, but keep the PC fully awake.

**Configure on each PC:**

1. **Disable sleep:**
   Settings > System > Power & battery > Screen, sleep, & hibernate timeouts
   - "When plugged in, put my device to sleep after" → **Never**

2. **Disable hibernate:**
   ```powershell
   # Admin terminal
   powercfg -h off
   ```

3. **Set display off timer** — 15–30 min is fine. Display off does not affect remote access.

4. **`end-day` function** currently runs `shutdown /s /t 900` — change to screen lock only (do on home PC when back to avoid conflicts):
   ```powershell
   # Replace shutdown line with:
   rundll32.exe user32.dll,LockWorkStation
   ```

> **Fallback:** If the PC does end up sleeping or shut down unexpectedly, call someone at the other location to power it on and sign in. Not ideal but always available.

### Prevent Windows Update forced restarts

```powershell
# Admin terminal — prevent auto-reboot when logged in
$path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
New-Item -Path $path -Force | Out-Null
New-ItemProperty -Path $path -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -PropertyType DWORD -Force
```

---

## Tailscale Setup

### Concept
Tailscale creates a private encrypted mesh VPN between your devices. Each PC gets a stable IP (e.g. `100.x.x.x`) that works from anywhere — no port forwarding, no router config. Includes MagicDNS for friendly hostnames.

### Work PC — ✅ Complete
- Installed and signed in
- Machine name: `gsadus-vadim`
- Tailscale IP: `100.92.227.106`
- Shows as Connected in admin console: https://login.tailscale.com/admin/machines

### Home PC — do when back
- [ ] Install Tailscale (same account)
- [ ] Verify machine appears in admin console
- [ ] Note Tailscale IP: ___________________
- [ ] Test: `ping gsadus-vadim` (should resolve via MagicDNS)

### Edge cases
- **Ethernet preferred over Wi-Fi** for unattended PCs — Wi-Fi reconnection after display-off can be flaky
- **Firewall:** Tailscale automatically programs Windows Firewall — no manual config needed
- **Auto-updates:** Enable in Tailscale admin console

---

## OpenSSH Server Setup

### Work PC — ✅ Complete
- OpenSSH Server installed via `Add-WindowsCapability`
- sshd service running + set to Automatic startup
- Default shell set to `C:\Program Files\PowerShell\7\pwsh.exe`
- SSH key auth configured via `C:\ProgramData\ssh\administrators_authorized_keys`
- Permissions set correctly with `icacls`
- Tested: `ssh localhost` opens pwsh session without password prompt ✅

### Home PC — do when back
- [ ] Install OpenSSH Server:
  ```powershell
  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
  Start-Service sshd
  Set-Service -Name sshd -StartupType Automatic
  ```
- [ ] Set default shell to pwsh:
  ```powershell
  # Verify path first
  (Get-Command pwsh).Source

  New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
      -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
  ```
- [ ] Generate SSH key pair:
  ```powershell
  ssh-keygen -t ed25519
  ```
- [ ] Add home PC public key to work PC's `administrators_authorized_keys` (via SSH):
  ```powershell
  # From home PC — copy public key to work PC
  $key = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
  ssh Vadim@100.92.227.106 "Add-Content -Path 'C:\ProgramData\ssh\administrators_authorized_keys' -Value '$key'"
  ```
- [ ] Add work PC's public key to home PC's `administrators_authorized_keys` (same pattern)
- [ ] Test cross-PC: `ssh Vadim@gsadus-vadim` → pwsh session on work PC

### SSH notes
- Admin accounts on Windows use `C:\ProgramData\ssh\administrators_authorized_keys` — NOT `~/.ssh/authorized_keys`
- Permissions on that file must be set exactly or key auth is silently ignored:
  ```powershell
  icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "BUILTIN\Administrators:F"
  icacls "C:\ProgramData\ssh\administrators_authorized_keys" /grant "NT AUTHORITY\SYSTEM:F"
  ```
- Interactive SSH sessions load `$PROFILE` automatically → `wip`, `unwip`, `wip-all` all available

### Daily usage (once both PCs configured)
```powershell
# Interactive session on the other PC
ssh Vadim@gsadus-vadim     # from home → work
ssh Vadim@<home-ip>        # from work → home

# One-liner to run wip-all remotely without opening a full session
ssh Vadim@gsadus-vadim "pwsh -Command '. C:\GSADUs\profile.ps1; wip-all'"
```

---

## Chrome Remote Desktop Setup

### Concept
Full GUI remote desktop via browser. Uses Google account — no IP config needed. Good fallback when you need to see the screen or interact with GUI apps.

### Work PC — ⬜ In progress
- [ ] Go to https://remotedesktop.google.com/access
- [ ] Sign in with Google account → "Set up Remote Access" → "Turn on"
- [ ] Download + install host app, set a PIN (6+ digits)
- [ ] Verify machine appears under "My Computers"
- [ ] Test from phone before leaving

### Home PC — do when back
- [ ] Install Chrome Remote Desktop host (same Google account)
- [ ] Set a PIN
- [ ] Test from work PC browser: remotedesktop.google.com → home PC

---

## Security Notes

- **MFA on your Tailscale identity provider** (Google/GitHub) is the most important security measure
- Tailscale default ACL (allow all) is fine for a two-device personal setup
- SSH password auth can be disabled in `C:\ProgramData\ssh\sshd_config` once key auth is confirmed on both ends
