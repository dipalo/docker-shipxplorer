#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# Check to make sure the correct command line arguments have been set
EXITCODE=0
if [ -z "${LAT}" ]; then
  echo "ERROR: LAT environment variable not set"
  EXITCODE=1
fi
if [ -z "${LONG}" ]; then
  echo "ERROR: LONG environment variable not set"
  EXITCODE=1
fi
if [ -z "${BEASTHOST}" ]; then
  echo "ERROR: BEASTHOST environment variable not set"
  EXITCODE=1
fi
if [ -z "${ALT}" ]; then
  echo "ERROR: ALT environment variable not set"
  EXITCODE=1
else
  ALT="${ALT%%.*}"
fi
if [ $EXITCODE -ne 0 ]; then
  exit 1
fi

# Set up timezone
if [ -z "${TZ}" ]; then
  echo "WARNING: TZ environment variable not set"
else
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone
fi

# Generate /etc/rbfeeder.ini based on environment variables
echo """
[client]
network_mode=true
log_file=$RBFEEDER_LOG_FILE
debug_level=${DEBUG_LEVEL:-0}
""" > /etc/rbfeeder.ini

if [ -z "${SHARING_KEY}" ]
then
  echo ""
  echo "WARNING: SHARING_KEY environment variable was not set!"
  echo "Please make sure you note down the key generated."
  echo "Pass the key as environment var SHARING_KEY on next launch!"
  echo ""
else
  echo "key=$SHARING_KEY" >> /etc/rbfeeder.ini
fi

{
  echo "lat=$LAT"
  echo "lon=$LONG"
  echo "alt=$ALT"
  echo """
[network]
mode=beast
  """
  # shellcheck disable=SC2153
  echo "external_port=$BEASTPORT"
} >> /etc/rbfeeder.ini

# Attempt to resolve BEASTHOST into an IP address
if s6-dnsip4 "$BEASTHOST" > /dev/null 2>&1 ; then
  BEASTIP=$(s6-dnsip4 "$BEASTHOST" | head -1 2> /dev/null)
  echo "external_host=$BEASTIP" >> /etc/rbfeeder.ini
else
  echo "external_host=$BEASTHOST" >> /etc/rbfeeder.ini
fi

{
  echo "[mlat]"
  if [[ "$ENABLE_MLAT" == "true" ]]; then
    echo "mlat_cmd=/usr/bin/python3 /usr/local/bin/mlat-client --results beast,listen,30105"
    echo "autostart_mlat=true"
  else
    echo "autostart_mlat=false"
  fi
} >> /etc/rbfeeder.ini

# If UAT_RECEIVER_HOST is set, then add UAT configuration
if [[ -n "$UAT_RECEIVER_HOST" ]]; then
  {
    echo "[dump978]"
    echo "dump978_enabled=true"
    echo "dump978_port=30979"
  } >> /etc/rbfeeder.ini
fi

# Create log dirs
mkdir -p /var/log/rbfeeder
chown nobody:nogroup /var/log/rbfeeder
touch /var/log/rbfeeder.log
truncate --size=0 /var/log/rbfeeder.log
