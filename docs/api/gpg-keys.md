---
title: Generating a GPG Key
sidebar_label: Generating a GPG Key
---

# Generating a GPG Key

To generate a GPG keypair:

1. Download and install the
   [GPG command line tools](https://www.gnupg.org/download/).
2. Open Terminal.
3. Generate a GPG key pair:

   ```bash
   gpg --full-generate-key
   ```

4. Accept defaults unless you need custom options (use 4096-bit
   keys).
5. List your keys:

   ```bash
   gpg --list-secret-keys --keyid-format=long
   ```

6. Export your public key:

   ```bash
   gpg --armor --export YOUR_KEY_ID
   ```

7. Copy everything between:

   ```
   -----BEGIN PGP PUBLIC KEY BLOCK-----
   ```

   and

   ```
   -----END PGP PUBLIC KEY BLOCK-----
   ```

8. Add your GPG key to your TPA Stream account.
