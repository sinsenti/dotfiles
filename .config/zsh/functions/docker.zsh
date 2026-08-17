
dexec() {
  local container
  container=$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | \
    fzf --layout=reverse --header-lines=1 --header="[ Select Container to Shell Into ]" \
        --preview 'docker logs --tail 30 {1}' | awk '{print $1}')
  if [ -n "$container" ]; then
    echo -e "\033[1;32m[Attaching shell to $container]\033[0m"
    docker exec -it "$container" /bin/sh -c 'exec bash 2>/dev/null || exec sh'
  fi
}


dlogs() {
  local container
  container=$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | \
    fzf --layout=reverse --header-lines=1 --header="[ Select Container to Follow Logs ]" \
        --preview 'docker logs --tail 30 {1}' | awk '{print $1}')

  if [ -n "$container" ]; then
    echo -e "\033[1;34m[Streaming logs for $container... Press Ctrl+C to stop]\033[0m"
    docker logs -f --tail 100 "$container"
  fi
}

unalias dstop 2>/dev/null
dstop() {
  local containers
  containers=$(docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | \
    fzf --layout=reverse -m --header-lines=1 --header="[ Tab: Select Multiple | Enter: Stop Container(s) ]" \
        --preview 'docker logs --tail 20 {1}' | awk '{print $1}')

  if [ -n "$containers" ]; then
    echo -n "Action for selected containers: [s]top / [k]ill & remove / [c]ancel: "
    read -k 1 action
    echo ""
    case "$action" in
      s) echo "$containers" | xargs docker stop ;;
      k) echo "$containers" | xargs docker rm -f ;;
      *) echo "Cancelled." ;;
    esac
  fi
}

dock() {
  if ! docker compose ps &>/dev/null && ! docker-compose ps &>/dev/null; then
    echo "No active Docker Compose project found in this directory tree."
    return 1
  fi

  local service
  service=$(docker compose config --services 2>/dev/null || docker-compose config --services 2>/dev/null | \
    fzf --layout=reverse --header="[ Select Compose Service ]" \
        --preview 'docker compose logs --tail 30 {} 2>/dev/null || docker-compose logs --tail 30 {}')

  if [ -n "$service" ]; then
    echo -n "Action for '$service': [l]ogs / [r]estart / [b]uild & up / [e]xec / [c]ancel: "
    read -k 1 action
    echo ""
    case "$action" in
      l) docker compose logs -f --tail 100 "$service" ;;
      r) docker compose restart "$service" ;;
      b) docker compose up -d --build "$service" ;;
      e) docker compose exec "$service" /bin/sh -c 'exec bash 2>/dev/null || exec sh' ;;
      *) echo "Cancelled." ;;
    esac
  fi
}
