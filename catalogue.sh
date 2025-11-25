#!/bin/bash

set -euo pipefail

USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$(pwd)

mkdir -p "$LOGS_FOLDER"
echo "Script started at: $(date)" | tee -a "$LOG_FILE"

if [ "$USERID" -ne 0 ]; then
  echo -e "$R ERROR:: Please run this script as root $N"
  exit 1
fi

VALIDATE() {
  if [ $1 -ne 0 ]; then
    echo -e "$2 ... $R FAILURE $N" | tee -a "$LOG_FILE"
    exit 1
  else
    echo -e "$2 ... $G SUCCESS $N" | tee -a "$LOG_FILE"
  fi
}

# Install NodeJS 16 from tarball (works with Amazon Linux 2 glibc)
NODE_TARBALL_URL="https://nodejs.org/dist/v16.20.2/node-v16.20.2-linux-x64.tar.xz"
NODE_DIR="/usr/local/node-v16.20.2-linux-x64"

if ! command -v node &>/dev/null; then
  curl -L -o /tmp/node-v16.20.2-linux-x64.tar.xz "$NODE_TARBALL_URL" &>>"$LOG_FILE"
  VALIDATE $? "Downloading NodeJS 16 tarball"

  mkdir -p /usr/local
  tar -xJf /tmp/node-v16.20.2-linux-x64.tar.xz -C /usr/local &>>"$LOG_FILE"
  VALIDATE $? "Extracting NodeJS 16"

  for bin in node npm npx; do
    ln -sf "$NODE_DIR/bin/$bin" "/usr/bin/$bin"
  done
  VALIDATE $? "Creating NodeJS symlinks"

  echo -e "NodeJS binary: $(command -v node)" | tee -a "$LOG_FILE"
  node -v | tee -a "$LOG_FILE"
else
  echo -e "NodeJS already installed at: $(command -v node)" | tee -a "$LOG_FILE"
  node -v | tee -a "$LOG_FILE"
fi

# roboshop user
id roboshop &>>"$LOG_FILE" || useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
VALIDATE $? "Ensuring roboshop user"

# /app setup
rm -rf /app
mkdir -p /app
chown roboshop:roboshop /app
VALIDATE $? "Preparing /app"

# Download catalogue artefact
curl -L -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading catalogue artefact"

unzip -o /tmp/catalogue.zip -d /app &>>"$LOG_FILE"
VALIDATE $? "Unzipping catalogue"

# Install dependencies
cd /app
sudo -u roboshop npm install &>>"$LOG_FILE"
VALIDATE $? "Installing Node dependencies"

# Systemd service
cp "$SCRIPT_DIR/catalogue.service" /etc/systemd/system/catalogue.service
VALIDATE $? "Copying catalogue.service"

systemctl daemon-reload
systemctl enable catalogue &>>"$LOG_FILE"
VALIDATE $? "Enabling catalogue"

systemctl restart catalogue &>>"$LOG_FILE"
VALIDATE $? "Starting catalogue"

echo -e "$G Catalogue setup complete $N"
