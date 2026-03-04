# Bradix — Setup Instructions

**Five steps. That's it.**

---

## Step 1: Plug in the NUC

Connect the MSI Cubi NUC to power and to your internet (Ethernet or Wi-Fi). Turn it on. Wait for it to boot into Ubuntu.

---

## Step 2: Open a terminal

If Ubuntu Desktop: right-click the desktop and select "Open Terminal", or press `Ctrl+Alt+T`.

If Ubuntu Server: you are already in a terminal.

---

## Step 3: Run the installer

Copy and paste this single command, then press Enter:

```bash
curl -sL https://raw.githubusercontent.com/toronto192020/Bradyx/main/one-click-install/bradix-install.sh | bash
```

The script will install everything automatically. It takes about 10-15 minutes depending on your internet speed.

---

## Step 4: Enter your email password

The script will ask for **one thing**: your Outlook App Password.

To get an App Password:
1. Go to [https://account.microsoft.com/security](https://account.microsoft.com/security)
2. Sign in with **bts@outlook.com**
3. Click **App passwords** (under Additional security)
4. Generate a new password and paste it when prompted

That is the only thing you need to type.

---

## Step 5: Done. Walk away.

The system is now running. It will:

- Check deadlines every day at 8am
- Send a weekly digest every Monday at 9am
- Alert you immediately if anything is due within 48 hours
- Escalate overdue tasks daily until acknowledged
- Back up everything to the NAS every night
- Sync case data from GitHub every hour
- Auto-start on reboot
- Find and configure the Jetson automatically

**Access the dashboard from your phone** using the Tailscale IP shown at the end of installation. Your login credentials are saved in `/opt/bradix/CREDENTIALS.txt` on the NUC.

**Check system status anytime** by running `bradix-status` in the terminal.

---

*The Quiet Guardian is active. It is watching, so you don't have to.*
