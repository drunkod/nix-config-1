# Secrets Management with SOPS and sops-nix

This repository uses [SOPS](https://github.com/getsops/sops) (Secrets OPerationS) paired with [sops-nix](https://github.com/Mic92/sops-nix) to securely manage secrets.

This architecture allows you to encrypt sensitive data (like API keys, passwords, and tokens) into files that can be safely committed to this public git repository. The secrets are decrypted securely at runtime by Nix during system deployment.

## 1. How It Works

- **Age Encryption**: We use `age` for asymmetric encryption. You have a private key on your machine, and a public key stored in the repository.
- **.sops.yaml**: This file sits at the root of the repository. It maps public keys to file paths, instructing SOPS on which keys should be able to decrypt which secret files.
- **sops CLI**: You use the `sops` command-line tool to edit and view the encrypted files. SOPS transparently decrypts the file into your editor, and encrypts it back when you save.
- **sops-nix**: During a `darwin-rebuild` or Home Manager activation, `sops-nix` uses your local private key to decrypt the secrets in the Nix store and securely provisions them into designated locations (like `~/.config/sops-nix/`). Nix configurations can then read these files to configure applications.

## 2. First-Time Setup (New Machine)

If you are cloning this repository on a new machine, you need to set up your `age` key.

1. **Generate a new age key:**
   ```bash
   mkdir -p ~/.config/sops/age
   nix run nixpkgs#age -- age-keygen -o ~/.config/sops/age/keys.txt
   ```
2. **Symlink the key for macOS SOPS CLI:**
   macOS expects the key in a different location than Linux/XDG standards.
   ```bash
   mkdir -p "$HOME/Library/Application Support/sops/age"
   ln -sf "$HOME/.config/sops/age/keys.txt" "$HOME/Library/Application Support/sops/age/keys.txt"
   ```
3. **Get your public key:**
   ```bash
   cat ~/.config/sops/age/keys.txt | grep "public key"
   ```
4. Add your new public key to `.sops.yaml` (see "How to Add New Keys" below).

## 3. How to Add New Keys (Machines/Users)

When you want to grant a new machine or user access to the secrets:

1. Obtain their `age` public key.
2. Edit the `.sops.yaml` file in the root of the repository:
   ```yaml
   keys:
     - &primary age14nzljj30cme3j7gkkcs27k2h94m5p9lswclc3kclzqcj5nwamqfqcrvs9z
     - &new_machine age1... # Add the new public key here
   
   creation_rules:
     - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
       key_groups:
         - age:
             - *primary
             - *new_machine # Add the reference here
   ```
3. **Update existing secrets**: Existing secrets were encrypted only for the old keys. You must re-encrypt them so the new key can read them:
   ```bash
   nix run nixpkgs#sops -- updatekeys secrets/default.yaml
   ```

## 4. How to Add or Edit Secrets

To create a new secret file or edit an existing one:

1. **Edit the file:**
   ```bash
   nix run nixpkgs#sops -- secrets/default.yaml
   ```
   *Note: This will open the decrypted file in your `$EDITOR` (usually vim/nano). Make your changes, save, and exit. SOPS will encrypt the file upon exiting.*

2. **Add a new secret value:**
   Inside the editor, write standard YAML:
   ```yaml
   freemodel:
     apikey: "sk-ant-my-secret-key"
   github:
     token: "ghp_my_secret_token"
   ```

3. **Commit the changes:**
   The modified `secrets/default.yaml` will be encrypted. Commit it to git as usual:
   ```bash
   git add secrets/default.yaml
   git commit -m "chore: update secrets"
   ```

## 5. Using Secrets in Nix Modules

Once a secret is in `secrets/default.yaml`, you can configure Nix to securely extract it.

In your Home Manager module (e.g., `modules/programs/claude-code.nix`):

```nix
{ config, lib, pkgs, ... }: {
  # 1. Tell sops-nix where your private key is
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # 2. Define the secret mapping
  sops.secrets."freemodel/apikey" = {
    sopsFile = ../../secrets/default.yaml;
    # Where should the decrypted file be placed?
    path = "${config.home.homeDirectory}/.config/sops-nix/freemodel-apikey";
  };

  # 3. Use the decrypted file in your configuration
  home.shellAliases = {
    # We dynamically 'cat' the decrypted file at invocation time
    claude-freemodel = "ANTHROPIC_API_KEY=$(cat ${config.sops.secrets."freemodel/apikey".path}) claude";
  };
}
```

This ensures the secret never leaks into the world-readable `/nix/store` and is only accessible dynamically at runtime.
