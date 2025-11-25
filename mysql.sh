#!/bin/bash

set -euo pipefail

USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"
LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

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

# On Amazon Linux 2, we typically use MariaDB via amazon-linux-extras
if ! rpm -q mariadb-server &>/dev/null; then
  amazon-linux-extras install -y mariadb10.5 &>>"$LOG_FILE" || yum install -y mariadb-server &>>"$LOG_FILE"
  VALIDATE $? "Installing MariaDB (MySQL compatible)"
fi

systemctl enable mariadb &>>"$LOG_FILE"
VALIDATE $? "Enabling MariaDB"

systemctl restart mariadb &>>"$LOG_FILE"
VALIDATE $? "Starting MariaDB"

# Set root password if not already set
mysql -uroot -e 'SELECT 1;' &>>"$LOG_FILE" && {
  mysqladmin -uroot password 'RoboShop@1' &>>"$LOG_FILE" || true
}
VALIDATE $? "Setting root password (if needed)"

echo -e "$G MySQL/MariaDB setup complete $N"
