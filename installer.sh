#!/usr/bin/env bash
set -e

# Check all things that will be needed for this script to succeed like access to docker and docker-compose
# If any check fails exit with a message on what the user needs to do to fix the problem
command -v git >/dev/null 2>&1 || { echo >&2 "'git' is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "'docker' is required but not installed. See https://gitlab.com/shardeum/validator/dashboard/-/tree/dashboard-gui-nextjs#how-to for details."; exit 1; }
if command -v docker-compose &>/dev/null; then
  echo "docker-compose is installed on this machine"
elif docker --help | grep -q "compose"; then
  echo "docker compose subcommand is installed on this machine"
else
  echo "docker-compose or docker compose is not installed on this machine"
  exit 1
fi

export DOCKER_DEFAULT_PLATFORM=linux/amd64

docker-safe() {
  if ! command -v docker &>/dev/null; then
    echo "docker is not installed on this machine"
    exit 1
  fi

  if ! docker $@; then
    echo "Trying again with sudo..."
    sudo docker $@
  fi
}

docker-compose-safe() {
  if command -v docker-compose &>/dev/null; then
    cmd="docker-compose"
  elif docker --help | grep -q "compose"; then
    cmd="docker compose"
  else
    echo "docker-compose or docker compose is not installed on this machine"
    exit 1
  fi

  if ! $cmd $@; then
    echo "Trying again with sudo..."
    sudo $cmd $@
  fi
}

cat << EOF

#########################
# 0. GET INFO FROM USER #
#########################

EOF

read -p "Do you want to run the web based Dashboard? (y/n): " RUNDASHBOARD
RUNDASHBOARD=${RUNDASHBOARD:-y}

read -p "Set the password to access the Dashboard: " -s DASHPASS
echo

while :; do
  read -p "Enter the port (1025-65536) to access the web based Dashboard (default 8080): " DASHPORT
  DASHPORT=${DASHPORT:-8080}
  [[ $DASHPORT =~ ^[0-9]+$ ]] || { echo "Enter a valid port"; continue; }
  if ((DASHPORT >= 1025 && DASHPORT <= 65536)); then
    DASHPORT=${DASHPORT:-8080}
    break
  else
    echo "Port out of range, try again"
  fi
done

read -p "What base directory should the node use (defaults to ~/.shardeum): " NODEHOME
NODEHOME=${NODEHOME:-~/.shardeum}

PS3='Select a network to connect to: '
options=("mainnet" "betanet" "devnet" "custom")
select opt in "${options[@]}"
do
    case $opt in
        "mainnet")
            echo "Mainnet not released yet. Please select another network"
            ;;
        "betanet")
            echo "Betanet not released yet. Please select another network"
            ;;
        "devnet")
            APPSEEDLIST="18.185.177.105"
            APPMONITOR="3.76.104.97"
            break
            ;;
        "custom")
            read -p "What is the IP of the archiver?: " APPSEEDLIST
            read -p "What is the IP of the monitor?: " APPMONITOR
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

cat <<EOF

###########################
# 1. Pull Compose Project #
###########################

EOF

git clone https://gitlab.com/shardeum/validator/dashboard.git ${NODEHOME} &&
  cd ${NODEHOME} &&
  chmod a+x ./*.sh

cat <<EOF

#########################
# 2. Building base image #
#########################

EOF

cd ${NODEHOME} &&
docker-safe build --no-cache -t test-dashboard -f Dockerfile --build-arg RUNDASHBOARD=${RUNDASHBOARD} .

cat <<EOF

###############################
# 3. Create and Set .env File #
###############################

EOF

cd ${NODEHOME} &&
touch ./.env
cat >./.env <<EOL
APP_IP=auto
APP_SEEDLIST=${APPSEEDLIST}
APP_MONITOR=${APPMONITOR}
EOL

cat <<EOF

############################
# 4. Start Compose Project #
############################

EOF

cd ${NODEHOME} &&
./docker-up.sh

echo "Starting image. This could take a while..."
(docker-safe logs -f shardeum-dashboard &) | grep -q 'done'

#Do not indent
if [ $RUNDASHBOARD = "y" ]
then
cat <<EOF
  To use the Web Dashboard:
    1. Open a web browser and navigate to the web dashboard at localhost:8080 or ServerIP:8080
    2. Go to the Settings tab and connect a wallet.
    3. Go to the Maintenance tab and click the Start Node button.
EOF
fi

cat <<EOF

To use the Command Line Interface:
	1. Navigate to the Shardeum home directory ($NODEHOME).
	2. Enter the validator container with ./shell.sh.
	3. Run "operator-cli --help" for commands

EOF


