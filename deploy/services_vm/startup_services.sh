#!/bin/bash
REPO_DIR="/home/beaufrans/drupal"
REPO_URL="https://${PAT_TOKEN}@github.com/96sjdd2h4v-cmd/test_env.git"

#Repo ophalen
if [ ! -d "$REPO_DIR" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
  chown -R beaufrans:beaufrans "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi

#Authenticeer Docker bij Artifact Registry
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://europe-west1-docker.pkg.dev

#Ga naar de drupal_vm submap en start de stack
cd "$REPO_DIR/deploy/drupal_vm"
docker compose up -d