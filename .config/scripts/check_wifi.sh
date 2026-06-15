while true; do
  if ping -c 1 -W 2 1.1.1.1 >/dev/null; then
    echo "$(date +'%H:%M:%S') - ✅ Online"
    curl https://icanhazip.com/
  else
    echo "$(date +'%H:%M:%S') - ❌ OFFLINE (No internet)"
  fi
  sleep 2
done
