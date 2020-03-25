#!/bin/bash

getTraefikCert() {
  kubectl get secret -o json traefik-default-cert | jq -r '.data."tls.crt"' | base64 -d | openssl x509 -in - -noout -text
}

getTraefikCert