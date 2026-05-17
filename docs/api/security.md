---
title: Security (IP Allowlist)
sidebar_label: Security
---

# Security (IP Allowlist)

For additional security, every user must provide an IP CIDR address
range. This range may be `0.0.0.0/0` (meaning no restriction), but we
**highly recommend** a more restrictive range to provide an extra
layer of protection.

Configure the range on the
[Manage Users](https://app.tpastream.com/settings/users) page under
**Settings**.

The allowlist applies to **both** authentication methods:

- For [SSH-JWT](/api/authentication#ssh-jwt-preferred), a request
  with a valid signature whose source IP isn't in the allowlist gets
  a `403`.
- For [API Token Basic Auth](/api/authentication#api-tokens-legacy),
  the same allowlist is enforced.
