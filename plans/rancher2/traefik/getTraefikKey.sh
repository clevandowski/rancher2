#!/bin/bash

getTraefikKey() {
  kubectl get secret -o json traefik-default-cert | jq -r '.data."tls.key"' | base64 -d | openssl rsa -in - -noout -text
}

getTraefikKey