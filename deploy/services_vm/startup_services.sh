#!/bin/bash
REPO_DIR="/home/beaufrans/drupal"

#Repo ophalen
if [ ! -d "$REPO_DIR" ]; then
  git clone https://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github.com/96sjdd2h4v-cmd/test_env.git "$REPO_DIR"
  chown -R beaufrans:beaufrans "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi

#Authenticeer Docker bij Artifact Registry
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://europe-west1-docker.pkg.dev

#Ga naar de drupal_vm submap en start de stack
cd "$REPO_DIR/deploy/drupal_vm"
docker compose up -d