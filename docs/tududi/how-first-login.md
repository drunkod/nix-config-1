Tududi’s local login is:

```text
URL:   http://127.0.0.1:3002
Email: admin@tududi.invalid
```

The password is the randomly generated SOPS-managed password. It is **not printed by the system** and should not be pasted into this chat.

### Safely copy the password to your clipboard

From the repository:

```zsh
cd ~/nix-config

sops decrypt --output-type json \
  --extract '["tududi"]["admin-password"]' \
  secrets/default.yaml \
  | tr -d '\n' \
  | pbcopy
```

Then open:

```text
http://127.0.0.1:3002
```

Log in with:

- **Email:** `admin@tududi.invalid`
- **Password:** paste with `Cmd+V`
