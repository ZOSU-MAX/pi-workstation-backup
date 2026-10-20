# Offsite Backup Runbook

Daily mirror of selected host paths into a git repo pushed to GitHub.
See `SKILL.md` for the surrounding workstation layout.

## Layout

    /opt/data/workstation/backup/
      config.json    include/exclude lists, remote URL, repo_dir
      run.py         sync + commit + push
      repo/          the git repo (mirrors absolute paths under its root)

The repo mirrors absolute paths: `repo/opt/data/workstation/gateway/gateway.py`
is `/opt/data/workstation/gateway/gateway.py`. Restoring is stripping the `repo/`
prefix and copying back.

## Procedure

    cd /opt/data/workstation/backup
    python3 run.py --dry-run     # what would be copied
    python3 run.py               # sync + commit + push
    python3 run.py --status      # repo state, remote, last commit

Daily cron `offsite-backup` at 04:00, script `backup-run.sh`, silent on success.

## Credentials

The token lives in `~/.git-credentials` (mode 600) with
`git config --global credential.helper store`. The remote URL in `config.json`
carries NO token.

**Never put the token in `config.json`.** That file sits inside an include root,
so it gets committed and pushed — the key would end up in the remote it is
supposed to protect. Keep secrets out of every path that is backed up.

## Pitfalls

- **Never include the backup repo in its own include list.** `Path.rglob` is lazy,
  so files copied into `repo/` during the walk get yielded again and copied
  again; the repo grows without bound (8 MB of source became 34 MB before it was
  caught). Add the repo path to `exclude_prefixes` in `config.json`.
- **Dedupe is mtime+size based.** `shutil.copy2` preserves mtime, so an unchanged
  file is skipped. Verify with a second run printing `copied 0 file(s)` /
  `nothing to commit` — if it copies everything again, an exclusion is missing.
- **`github.com` is intermittently unreachable from this host** (TLS resets, then
  multi-minute connect timeouts) while `api.github.com` stays fast. Git pushes go
  to github.com, so expect occasional failures.
- **Flaky-TLS git settings** — set with `--global`, not per-repo, or a repo
  rebuild loses them:

      git config --global http.version HTTP/1.1
      git config --global http.postBuffer 524288000
      git config --global http.lowSpeedLimit 1000
      git config --global http.lowSpeedTime 600

- **Diverged history needs a force push.** Rebuilding the local repo from scratch
  makes the remote non-fast-forward; `git push --force origin HEAD` fixes it.
  Deliberate — it discards the remote's previous commits.
- **Retry the push instead of concluding it failed for good.** A short loop of
  attempts with a sleep between them gets through an intermittent window.
