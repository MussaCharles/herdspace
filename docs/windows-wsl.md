# Windows with WSL

Scope: use a Windows computer as a client, or run a Herdr server inside WSL. WSL (Windows Subsystem for Linux) runs Linux inside Windows. Ghostty has no Windows build, so Windows Terminal is the terminal in this setup.

The tests in this repository do not run on Windows. The Linux scripts have tests in containers, but the Windows Terminal steps have no test.

## Windows as a client

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {
  'fontFamily': 'Menlo, Consolas, Courier New, monospace', 'fontSize': '14px',
  'primaryColor': '#0d1117', 'primaryTextColor': '#e6edf3', 'primaryBorderColor': '#3fb950',
  'textColor': '#e6edf3', 'lineColor': '#58a6ff', 'secondaryColor': '#161b22', 'tertiaryColor': '#0d1117',
  'edgeLabelBackground': '#0b0f14', 'clusterBkg': '#0b0f14', 'clusterBorder': '#30363d', 'titleColor': '#d2a8ff',
  'actorBkg': '#0d1f12', 'actorBorder': '#3fb950', 'actorTextColor': '#7ee787', 'actorLineColor': '#30363d',
  'signalColor': '#58a6ff', 'signalTextColor': '#e6edf3', 'sequenceNumberColor': '#0b0f14'
}, 'flowchart': {'curve': 'basis', 'nodeSpacing': 34, 'rankSpacing': 42, 'wrappingWidth': 340}}}%%
flowchart LR
  classDef cmd fill:#0d1f12,stroke:#3fb950,stroke-width:2px,color:#7ee787
  classDef step fill:#0d1117,stroke:#58a6ff,stroke-width:1.5px,color:#c9e1ff
  classDef ask fill:#2a2000,stroke:#e3b341,stroke-width:2px,color:#f2cc60
  classDef host fill:#1a0f24,stroke:#bc8cff,stroke-width:2px,color:#d2a8ff
  classDef data fill:#082028,stroke:#39c5cf,stroke-width:1.5px,color:#a5f3fc
  classDef stop fill:#2a0f12,stroke:#ff7b72,stroke-width:2px,color:#ffa198
  subgraph win["WINDOWS"]
    wt["Windows Terminal"]:::step --> wsl["WSL Ubuntu<br/>zsh and tools"]:::host
  end
  wsl -- " ssh " --> srv["Server<br/>Herdr"]:::cmd
  style win fill:#0b0f14,stroke:#58a6ff,color:#c9e1ff
```

Install Ubuntu in WSL. Run this command in PowerShell:

```powershell
wsl --install -d Ubuntu
```

Open Ubuntu from the Start menu, and clone this repository there. Then run the Linux client script with no Ghostty:

```bash
./bootstrap-client-linux.sh --no-ghostty
```

Windows Terminal does not need the terminal description, because it uses `xterm-256color`.

Do these steps in Windows Terminal:

1. Install a Nerd Font on Windows, and select it in the Ubuntu profile. Without it, the prompt shows boxes in place of icons.
2. Open Settings, then Actions. Remove `Ctrl+Shift+T` and `Ctrl+Shift+W`, so that those keys reach Herdr.
3. Use `Ctrl+Shift+V` to paste.

The prefix keys always work, for example `ctrl+b`, then `c` for a new tab. The [cheat sheet](cheat-sheet.md) lists them.

## WSL as a server

Run the Linux server script inside WSL. WSL needs systemd for the login service. Add these lines to `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

Restart WSL. Run this command in PowerShell:

```powershell
wsl --shutdown
```

Then run the server script:

```bash
./bootstrap-server-linux.sh
```

A Herdr server in WSL stops when WSL stops. Use this setup for a computer that you work on. For a server that must stay on, use Linux or macOS.

## References

- [Install WSL](https://learn.microsoft.com/windows/wsl/install)
- [Systemd in WSL](https://learn.microsoft.com/windows/wsl/systemd)
- [Windows Terminal](https://learn.microsoft.com/windows/terminal/)
