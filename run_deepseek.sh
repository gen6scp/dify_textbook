#!/bin/bash -x

get_model(){
    sleep 10
    local com="curl http://$LAN_IP:11434/api/tags"
    echo "
-------------------------------------------------------
Asking Ollama the models [$com]
-------------------------------------------------------"
    exec $com
}

LAN_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
get_model &
OLLAMA_HOST=$LAN_IP:11434 ollama serve
