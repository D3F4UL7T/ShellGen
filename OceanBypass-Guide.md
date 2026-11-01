# Ocean Screenshare Residue Reduction — DoomsDay / Ghost Clients

**Developed by bruta / D3F4ULT**  
Lab / educational use only.

Ocean (anticheat.ac) is a forensic scanner. It does not only look at running processes. Core sources:

- Prefetch (execution proof) — **left intact by this tool**
- Amcache / ShimCache
- BAM (Background Activity Moderator)
- UserAssist / RunMRU
- Recent / Jump Lists
- Recycle Bin + NTFS recovery
- Memory strings / loaded modules
- .minecraft integrity (RUIN mode)
- Browser history + downloads
- Macro / AHK residue
- Antivirus correlation

A pure JAR that stays on disk and in memory will get flagged.  
DoomsDay self-destruct helps, but residual artifacts remain.

---

## What this package does

`OceanCleaner.ps1` reduces the **high-signal residual traces** Ocean uses for detections and warnings, while leaving Prefetch alone (per operator request).

### What it clears
- Leftover injector / loader processes
- Recent + JumpLists
- Temp
- UserAssist + RunMRU
- AppCompat / Layers
- BAM execution entries (when elevated)
- Minecraft logs (truncate) + suspicious mods + crash-reports
- Recycle Bin
- ActivitiesCache
- Optional: Application event log (`-Deep`)

### What it deliberately does **not** touch
- Prefetch (operator preference — also because mass Prefetch deletion itself is an Ocean warning signal)
- Amcache.hve (tampering is noisy and recoverable via VSS)
- Live process memory (requires unload + reboot)

---

## Operational flow that actually improves odds

1. **Play** with DoomsDay injected or external tools active.
2. Staff freezes / sends Ocean pin.
3. **Immediately**:
   - Trigger DoomsDay self-destruct / unload
   - Close Minecraft completely
   - Run elevated:
     ```powershell
     powershell -ExecutionPolicy Bypass -File OceanCleaner.ps1 -Deep
     ```
   - Confirm no client JAR remains on disk
4. Launch a **completely clean** vanilla / Lunar / Feather instance (no mods, no injectors).
5. Run the Ocean scanner from that clean instance.
6. If they demand manual AnyDesk check, keep desktop clean and only show the clean launcher.

### Extra hardening (optional)
- Keep client + injector on a FAT32 USB, inject from there, remove USB before SS.
- Separate Windows user profile or VM for client use is stronger than any scrubber.
- Avoid AHK / Razer / Logitech macros that leave config files.
- Clear browser download history for client sites manually.
- Reboot if time allows (clears more volatile memory artifacts).

---

## Honest limits

Ocean’s memory scan + RUIN mode can still catch injected modules if strings remain in process memory.  
Full NTFS recovery can resurrect deleted fragments.  
Manual staff who know what they are doing can still find behavioral anomalies.  
No public tool fully “defeats” Ocean permanently; signatures update.

This package is **maximum practical residue reduction** without the Prefetch wipe that itself becomes a detection signal.

---

## Files

| File | Purpose |
|------|---------|
| `OceanCleaner.ps1` | Residue scrubber (Prefetch intact) |
| `OceanBypass-Guide.md` | This guide |

Run elevated. Keep a clean Minecraft instance ready for the actual scan.
