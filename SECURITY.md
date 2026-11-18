# Security Policy

## Supported versions

NeuroNova is under active development. Only the latest code on `main`
(and the site deployed from it at https://neuronova.muslimit.net/) is supported.

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Report privately through GitHub:
**Security tab → "Report a vulnerability"** on this repository
(private vulnerability reporting).

Include what you found, steps to reproduce, and the affected version or
commit. You can expect an initial reply within a few days. Once a fix is
released, you are welcome to be credited if you wish.

## Scope and known limitations

- Scores and progress are stored **locally on the device** and can be edited
  by the player. This is a known limitation until server-side validation is
  built; reports about editing local scores are not treated as vulnerabilities.
- Never commit secrets (API keys, tokens, SSH keys, `.env` files). Deployment
  credentials live in GitHub Actions secrets only.
- If you find a leaked credential in the repository or its history, report it
  privately as described above.
