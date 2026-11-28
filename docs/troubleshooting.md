# Troubleshooting

Start with `.\scripts\validate.ps1` from the repository folder. It reports missing tools, sign-in problems and drift between the repo and your Claude home.

## Installing

| Symptom | Fix |
|---|---|
| "running scripts is disabled on this system" | Use `setup.cmd`, or the `powershell -NoProfile -ExecutionPolicy RemoteSigned -File ...` form. If it says the policy is set by Group Policy, ask IT. |
| `winget` is not recognized | Common on a new Windows profile. `install.ps1` and `setup.cmd` register App Installer for your user. If that fails, update "App Installer" from the Microsoft Store (or install Git from git-scm.com) and run `install.ps1` again. |
| `curl.exe` fails or is blocked | Download `install.ps1` from the repository page in a browser. If Windows marks it as downloaded from the internet, read it, then run `Unblock-File install.ps1` before running it. |
| An install asks for administrator approval | Setup only uses per-user installs. If a prompt still appears, cancel it and ask IT rather than working around it. |
| `Running as administrator` | Close the elevated window and run setup from a normal terminal, so tools and configuration go to your own account. |
| `... holds an incomplete clone` / `... is not a claude-config clone` | `install.ps1` never deletes folders. Delete the interrupted clone (or pick another folder with `-Path`) and run it again. |
| `git`, `gh` or `claude` not found right after setup | Terminals that were already open keep their old `PATH`. Open a new one. |
| `Claude Code is also installed via winget` / `npm` | Run `setup.cmd` and confirm removal, or run `winget uninstall --id Anthropic.ClaudeCode -e --scope user` / `npm uninstall -g @anthropic-ai/claude-code`. A machine-wide WinGet copy needs IT. |
| Claude Code on Windows complains about Git Bash | Install Git for Windows. Claude Code needs it. |
| `The term 'Get-FileHash' is not recognized` | An older copy of the scripts run from Windows PowerShell started inside PowerShell 7. Update the repo (`git pull`) or run `setup.cmd`. |

## Syncing

| Symptom | Fix |
|---|---|
| `... was modified locally; left unchanged` | Keep your edit: `sync.ps1 -Capture`, then commit. Discard it: `sync.ps1 -Force` (backed up first). |
| `settings.<key> kept local value ...` | Informational: your local value differs from the repo. Change either side to match, or leave it. |
| `settings.<key> is no longer shared; kept your value ...` | Informational, shown once: the repo stopped sharing that preference (for example `model`, `theme` and `tui`). Your value stays. Change it with `/config` if you like. |
| `settings.json is not valid JSON` | Fix the file (or `restore.ps1 -Latest`), then rerun. Sync never rewrites a file it can't parse. |
| `Local branch has diverged from upstream` | In the repo, run `git status` and `git log --oneline --graph --all -10`, resolve it, then rerun. |

## Skills

| Symptom | Fix |
|---|---|
| Skills don't show up | Start a new session and run `validate.ps1`. Check that `skills\<name>\SKILL.md` exists in your Claude home. |
| A skill name clashes with a built-in command | `validate.ps1` rejects names on its list of known built-ins (which is why the ship skill is `/vult-ship`). If a newer Claude Code adds a clashing command, rename the skill as described in [Team setup](team-setup.md#rename-a-skill) and add the built-in name to `$reservedNames` in `scripts/validate.ps1`. |
| Sign-in shows "Could not check Claude Code sign-in" | Run `claude auth status` to see the full output. See [Sign-in](installation.md#sign-in). |
