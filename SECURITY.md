# Security Architecture in Nix Configurations

This document explores the security practices and modules inspired by the `khanelinix` framework. It outlines the strategies for securing both macOS (Darwin) and Linux (NixOS) environments using Nix modules.

## 1. Secrets Management (SOPS)

The cornerstone of the security architecture is `sops-nix`, which handles all sensitive data securely.

*   **Age Encryption**: Keys are generated exclusively using `age`, completely decoupling secrets from passwords and relying on asymmetric encryption.
*   **Git Integration**: `secrets/default.yaml` and other `.yaml` files in the repository contain encrypted data safely committed alongside code.
*   **Module Abstraction**: Instead of using raw `sops-nix` configurations everywhere, a custom wrapper (e.g., `services.sops.enable`) installs the CLI utilities (`sops`, `age`) and establishes a single source of truth for the `keyFile` path (`~/.config/sops/age/keys.txt`). 
*   **Runtime Injection**: API keys (like Anthropic) and other credentials are dynamically loaded into the environment at execution time (via shell aliases or activation scripts), preventing them from leaking into the world-readable `/nix/store`.

## 2. Darwin (macOS) Security Enhancements

On macOS, security is primarily handled by integrating Nix closely with the system's native tools and standardizing developer credentials.

*   **Sudo Authentication with TouchID**: Reconfiguring `/etc/pam.d/sudo` natively through `nix-darwin` to allow biometric authentication (TouchID) instead of requiring a typed password for `sudo` commands.
*   **GPG Integration**: Centralizing GnuPG configurations, tying GPG agents directly to macOS's keychain for seamless commit signing and SSH authentication.

## 3. NixOS (Linux) Security Enhancements

The Linux side of the configuration is significantly more comprehensive, taking advantage of deep kernel and system-level integrations.

*   **USB Device Authorization (usbguard)**: Implementing a white-listing policy for USB devices to prevent physical access attacks (like BadUSB).
*   **Pluggable Authentication Modules (PAM)**: Advanced PAM configurations that enable U2F (YubiKey) authentication across the entire system, requiring physical token presence for logins.
*   **Privilege Escalation**:
    *   **doas**: A lightweight, secure alternative to `sudo` ported from OpenBSD.
    *   **sudo-rs**: A memory-safe Rust implementation of `sudo` to mitigate historical memory corruption vulnerabilities found in the standard `sudo` binary.
*   **Auditing and Monitoring**:
    *   **auditd**: The Linux Audit Daemon runs continuously to monitor system calls and log security events, providing a robust trail for forensic analysis.
    *   **clamav**: An open-source antivirus engine configured for continuous scanning and threat detection.
*   **Certificate Management**: **ACME** (Let's Encrypt) integration for automatic generation and renewal of SSL/TLS certificates for any hosted services.
*   **PolicyKit (polkit)**: Fine-grained access control policies allowing unprivileged processes to communicate with privileged processes without requiring full root access.

## Summary

By codifying these security practices into Nix modules, you achieve a highly reproducible, auditable, and immutable security posture across all your machines. The "best practice" is to wrap these upstream tools into your own custom boolean toggles (like `security.usbguard.enable`), allowing you to rapidly deploy identical security policies to new hosts.
