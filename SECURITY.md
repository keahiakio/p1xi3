# Security Policy

## Supported Versions

Only the latest commit on the `main` branch is actively supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| `main`  | :white_check_mark: |
| < `main`| :x:                |

## Scope & Security Posture

`p1xi3` is designed specifically for high-security, air-gapped environments. We take any potential boundary breaches, unauthorized network leakage, or privilege escalations very seriously.

## Reporting a Vulnerability

If you discover a security vulnerability or air-gap integrity issue in `p1xi3`, please report it responsibly:

1. **GitHub Private Vulnerability Reporting**: Use GitHub's private vulnerability advisory feature under the **Security** tab of the repository if available.
2. **Direct Contact**: If private reporting is unavailable, email [keahiakio@users.noreply.github.com](mailto:keahiakio@users.noreply.github.com) with the subject `[SECURITY] p1xi3 Vulnerability Report`.

Please include:
- A detailed description of the vulnerability and attack vector (e.g. unexpected network packet egress, loopback port binding issues).
- Proof of concept steps or logs.
- Suggested remediations or mitigations.

### Response Timeline
- We will acknowledge receipt of your report within 48 to 72 hours.
- We will coordinate patch development and release before public disclosure.
- Please do not open public issues or disclose details publicly until a fix has been published.
