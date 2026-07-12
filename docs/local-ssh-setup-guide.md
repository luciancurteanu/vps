# Local SSH Setup Guide

## What you need

From the **server** → into your **PC's `.ssh` folder**

---

## 1. Private key (`example_com`)

**Server source:** `/home/admin/.ssh/id_rsa`

Copy the **full contents** (including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`).

**Local destination:** `C:\Users\USERPROFILE\.ssh\example_com`

### How to copy

From the server console, run:

```bash
cat /home/admin/.ssh/id_rsa
```

Copy the entire output and paste it into a new file at:

```
C:\Users\USERPROFILE\.ssh\example_com
```

---

## 2. Public key (`example_com.pub`)

Generate it locally from the private key (PowerShell):

```powershell
ssh-keygen -y -f "$env:USERPROFILE\.ssh\example_com" > "$env:USERPROFILE\.ssh\example_com.pub"
```

---

## 3. SSH config (`config`)

**Local destination:** `C:\Users\USERPROFILE\.ssh\config`

Contents:

```
Host example.com ip_address
    HostName ip_address
    Port 22
    User admin
    IdentityFile C:\Users\USERPROFILE\.ssh\example_com
    IdentitiesOnly yes
```

---

## 4. Test it

```powershell
ssh admin@ip_address
```

Expected result: successful login as `admin`.

---

## Summary of files on your PC

| File | Source |
|---|---|
| `C:\Users\USERPROFILE\.ssh\example_com` | Copied from server `/home/admin/.ssh/id_rsa` |
| `C:\Users\USERPROFILE\.ssh\example_com.pub` | Generated locally via `ssh-keygen -y` |
| `C:\Users\USERPROFILE\.ssh\config` | Created manually with the block above |
