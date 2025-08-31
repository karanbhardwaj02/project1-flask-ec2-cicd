
# Full Setup — Step by Step (Ubuntu + GitHub + AWS EC2)

## 0) What you'll build
A Flask "Hello" app deployed behind Nginx on an Ubuntu EC2 server. GitHub Actions uploads code and restarts the service automatically on every push to `main`.

## 1) Local prerequisites (your Ubuntu machine)
```bash
sudo apt update
sudo apt install -y git openssh-client awscli
# optional but nice:
# sudo snap install --classic code   # VS Code via snap
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## 2) Create the GitHub repository
- Create a new repo on GitHub (e.g., `flask-aws-ec2-cicd`).
- Copy this starter project into that repo and `git push` it.
```bash
cd path/to/your/repo
git init
git add .
git commit -m "Initial commit: Flask CI/CD to EC2"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

## 3) Launch an Ubuntu EC2 instance
- AMI: Ubuntu Server 22.04 LTS (x86_64)
- Instance type: t2.micro (free-tier eligible)
- Security Group inbound rules: SSH (22) from your IP, HTTP (80) from 0.0.0.0/0
- Key pair: create or use existing (for your personal SSH access)
- (Optional) Allocate an Elastic IP so the IP doesn't change

## 4) Create a dedicated 'deploy' user and SSH key
**On your local Ubuntu**, generate a key just for GitHub Actions → EC2:
```bash
ssh-keygen -t ed25519 -C "github-actions@<your-repo>" -f ~/.ssh/gh-actions-ec2
# This creates:
#   ~/.ssh/gh-actions-ec2      (private key)    <-- Add to GitHub Secrets as EC2_SSH_KEY
#   ~/.ssh/gh-actions-ec2.pub  (public key)     <-- Put on EC2 in authorized_keys
```

**SSH into EC2 using your own key (not the one above):**
```bash
ssh -i /path/to/your-ec2-key.pem ubuntu@<EC2_PUBLIC_IP>
```

**On EC2, create the 'deploy' user and install basics:**
```bash
# on EC2
sudo adduser --disabled-password --gecos "" deploy
sudo usermod -aG sudo deploy

# SSH setup for deploy user
sudo -u deploy mkdir -p /home/deploy/.ssh
echo "<PASTE CONTENTS OF ~/.ssh/gh-actions-ec2.pub HERE>" | sudo tee -a /home/deploy/.ssh/authorized_keys
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh

# Base packages
sudo apt update
sudo apt install -y python3-venv python3-pip nginx git rsync

# Firewall (optional but recommended)
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

**Test login as deploy user from your machine:**
```bash
ssh -i ~/.ssh/gh-actions-ec2 deploy@<EC2_PUBLIC_IP>
```

## 5) Set GitHub Secrets
In GitHub → your repo → Settings → Secrets and variables → Actions → "New repository secret":
- `EC2_HOST` → your EC2 public IP (or domain)
- `EC2_USER` → `deploy`
- `EC2_SSH_KEY` → paste **the private key** from `~/.ssh/gh-actions-ec2`
- `TARGET_DIR` → `/srv/flaskapp`
- (optional) `SSH_PORT` → `22`

## 6) First deployment
Push to `main`. The workflow will:
- Upload the repository to EC2 (to `/home/deploy/__upload`)
- Rsync code into `/srv/flaskapp`
- Create a Python venv
- Install requirements
- Set up/enable systemd service
- Configure Nginx reverse proxy
- Start/restart everything

Then browse: `http://<EC2_PUBLIC_IP>/`

## 7) Logs & troubleshooting
```bash
# on EC2
sudo systemctl status flaskapp
sudo journalctl -u flaskapp -n 100 --no-pager

sudo nginx -t
sudo systemctl status nginx
sudo tail -n 200 /var/log/nginx/error.log
```

## 8) Optional: Add your domain + HTTPS
- Point your domain's A record to the EC2 IP
- Install certbot:
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```
- Certbot auto-renews via systemd timer.

You're done! 🚀
