# Security Policy 🔐

## Supported Versions

We provide security updates for the following versions of **vibeproxy**:

| Version | Supported          |
| ------- | ------------------ |
| v0.1.x  | :white_check_mark: |
| < v0.1  | :x:                |

## Reporting a Vulnerability

We take the security of **vibeproxy** seriously. If you discover a security vulnerability, please do NOT open a public issue. Instead, report it privately.

Please report any security concerns directly to the maintainers at [kooshapari@gmail.com](mailto:kooshapari@gmail.com).

### What to include in your report
- A detailed description of the vulnerability
- Steps to reproduce (proof of concept)
- Potential impact on the system or user data
- Any suggested fixes or mitigations

We will acknowledge your report within 48 hours and provide a timeline for resolution.

## Security Best Practices (Multi)

- **Dependency Scanning**: All dependencies are scanned for vulnerabilities using cargo-audit/go-consulk/pip-audit
- **Input Validation**: All user inputs are validated and sanitized
- **Secret Management**: Secrets are managed via environment variables, never hardcoded
- **Error Handling**: Error messages do not expose sensitive information
- **Logging**: Sensitive data is redacted from logs

## Hardening Measures

- **Static Analysis**: Regular SAST scans using security linters
- **Dependency Audit**: Automated vulnerability scanning in CI
- **Code Review**: Security-focused review for all changes
- **Minimal Dependencies**: Keep dependency count minimal to reduce attack surface

---
Thank you for helping keep the ecosystem secure!
