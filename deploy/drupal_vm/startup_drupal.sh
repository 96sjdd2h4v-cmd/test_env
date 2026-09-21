#!/bin/bash
REPO_DIR="/home/beaufrans/drupal"
PAT_TOKEN="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"
REPO_URL="https://${PAT_TOKEN}@github.com/96sjdd2h4v-cmd/test_env.git"

# 1. Repo ophalen
if [ ! -d "$REPO_DIR" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
  chown -R beaufrans:beaufrans "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull
fi

# 2. Authenticeer Docker bij Artifact Registry
gcloud auth configure-docker europe-west1-docker.pkg.dev --quiet

# 3. Ga naar de juiste map en start Docker Compose
cd "$REPO_DIR/deploy/drupal_vm"
docker compose up -d