---
title: Generating an SSH Key
sidebar_label: Generating an SSH Key
---

# Generating an SSH Key

To generate an SSH keypair:

1. Open your Terminal (Linux / macOS) or Git Bash (Windows).
2. Paste one of the following commands, depending on which key type
   you want to use:

   ```bash
   # Ed25519 (recommended for new keys: short, fast, modern)
   ssh-keygen -t ed25519
   # RSA (4096-bit, broadly compatible)
   ssh-keygen -t rsa -b 4096
   # ECDSA on NIST P-521
   ssh-keygen -t ecdsa -b 521
   ```

   This creates a new SSH keypair.

   a. When prompted to "Enter a file in which to save the key," press
      Enter to accept the default location:

      ```
      Enter a file in which to save the key (/home/you/.ssh/id_<type>): [Press enter]
      ```

   b. At the prompt, you may enter a secure passphrase (optional):

      ```
      Enter passphrase (empty for no passphrase): [Type a passphrase]
      Enter same passphrase again: [Type passphrase again]
      ```

Once the keypair is created, upload the **public** half to
[`https://app.tpastream.com/settings/ssh`](https://app.tpastream.com/settings/ssh).
See [Authentication](/api/authentication#2-add-your-public-key-to-your-tpa-stream-account)
for the rest of the setup.
