#!/bin/bash

set -eo pipefail

# Backup Pantheon Live site and promote Test to Live if `promote_test_to_live` is set to 'yes', `workflow_dispatch`
# is used to manually trigger the action and the action runs from the main branch; then exits (Do not perform any of the other steps).
# `promote_test_to_live` is a string type variable so the value must match exactly
if [ "${GITHUB_EVENT_NAME}" = "workflow_dispatch" ] && [ "${INPUT_PROMOTE_TEST_TO_LIVE}" = "yes" ] && { [ "${GITHUB_REF}" = "trunk" ] || [ "${GITHUB_REF}" = "master" ] || [ "${GITHUB_REF}" = "main" ] || [ "${GITHUB_REF}" = "production" ]; }; then
  if [ -z "${INPUT_SITE_NAME}" ]; then
    echo "The site_name input is not defined. Exiting..."
    exit 1
  fi
  if [ -z "${INPUT_TERMINUS_TOKEN}" ]; then
    echo "The terminus_token input is not defined. Exiting..."
    exit 1
  fi

  echo "Backing up ${INPUT_SITE_NAME}.live before deploying"
  terminus -y backup:create --element code "${INPUT_SITE_NAME}".live
  terminus -y backup:create --element database "${INPUT_SITE_NAME}".live

  echo "Deploying to ${INPUT_SITE_NAME}.live"
  terminus -y env:deploy "${INPUT_SITE_NAME}".live

  echo "Deploy complete, clearing cache on ${INPUT_SITE_NAME}.live"  
  terminus -y env:clear-cache "${INPUT_SITE_NAME}".live

  exit 0
fi

# Add SSH key to access Pantheon git repository
mkdir -p  "${HOME}"/.ssh
echo "${INPUT_SSH_PRIVATE_KEY}" > "${HOME}"/.ssh/id_rsa
chmod 400 "${HOME}"/.ssh/id_rsa

# Configure git
git config --global user.email "${INPUT_GIT_USER_EMAIL}"
git config --global user.name "${INPUT_GIT_USER_NAME}"

# Clone Pantheon repository
echo "Cloning Pantheon's repository"
git clone "${INPUT_PANTHEON_GIT_URL}" /tmp/site

# Ensure only the main branch can deploy to Pantheon's `master` branch.
# There is no Github variable that returns the main branch for a repository so we are
# manually validating common names used for the main branch in a GIT repository.
if [ "${GITHUB_REF}" != "trunk" ] && [ "${GITHUB_REF}" != "master" ] && [ "${GITHUB_REF}" != "main" ] && [ "${GITHUB_REF}" != "production" ]; then
  if [ -z "${INPUT_MULTIDEV_ENV_NAME}" ]; then
    echo "The multidev_env_name input is not defined for the ${GITHUB_REF} branch. Only the main branch is allowed to deploy to Pantheon's dev environment"
    exit 1
  else
    pushd /tmp/site || exit 1
    echo "Checking out multidev ${INPUT_MULTIDEV_ENV_NAME} branch"
    git checkout "${INPUT_MULTIDEV_ENV_NAME}" || git checkout -b "${INPUT_MULTIDEV_ENV_NAME}"
    popd || exit 1
  fi
fi

# Sync wp-content
echo "Syncing wp-content folder"
if [ -z "${INPUT_WORKING_DIR}" ]; then
  RSYNC_SOURCE_DIR="${GITHUB_WORKSPACE}"
else
  RSYNC_SOURCE_DIR="${INPUT_WORKING_DIR}"
fi

rsync -vrxc --delete --force "${RSYNC_SOURCE_DIR}"/wp-content/ /tmp/site/wp-content/ \
  --exclude=uploads \
  --exclude=mu-plugins/pantheon* \
  --exclude=wp-content/db.php \
  --exclude=wp-content/pantheon.php

# Sync files to the root directory such as pantheon.yml from a space-separated list
 if [ ! -z "${INPUT_ROOT_FILES}" ]; then
  echo "Syncing WordPress root files"
  for FILE in ${INPUT_ROOT_FILES}; do
    if [ ! -e "${RSYNC_SOURCE_DIR}/${FILE}" ]; then 
      echo "$FILE from root_files list was not found, exiting" 
      exit 1
    fi
    echo "Sending $FILE..."
    rsync -vrxc "${RSYNC_SOURCE_DIR}"/"${FILE}" /tmp/site/"${FILE}"
  done
fi

cd /tmp/site
git add .
git status
git commit -qm "Deploying ${GITHUB_REPOSITORY} - ${GITHUB_SHA}"
echo "WordPress built files committed into local repository"

# Clone and merge WordPress version into local repository
# downgrades and same version merges should say "already up to date" and won't change anything
echo "Merging WordPress version ${INPUT_WORDPRESS_VERSION} from Pantheon upstream"

git remote add pantheon-wpcore https://github.com/pantheon-systems/WordPress.git
git fetch --tags pantheon-wpcore
# use -Xtheirs to prefer Pantheon's code if merge conflicts exist      
git merge -Xtheirs -m "Merge Pantheon upstream core version ${INPUT_WORDPRESS_VERSION}" "${INPUT_WORDPRESS_VERSION}"

# Push built site to Pantheon
echo "Deploying built site to Pantheon"
git push origin "${INPUT_MULTIDEV_ENV_NAME:-master}"

# Always promote the Pantheon's Dev environment to Test when deploying to Pantheon master
# There is no Github variable that returns the main branch for a repository so we are
# manually validating common names used for the main branch in a GIT repository.
if [ -z "${INPUT_MULTIDEV_ENV_NAME}" ] && { [ "${GITHUB_REF}" = "trunk" ] || [ "${GITHUB_REF}" = "master" ] || [ "${GITHUB_REF}" = "main" ] || [ "${GITHUB_REF}" = "production" ]; }; then
  if [ -z "${INPUT_SITE_NAME}" ]; then
    echo "The site_name input is not defined. Promote the Dev environment to Test manually in the Pantheon dashboard. Exiting..."
    exit 1
  fi
  if [ -z "${INPUT_TERMINUS_TOKEN}" ]; then
    echo "The terminus_token input is not defined. Promote the Dev environment to Test manually in the Pantheon dashboard. Exiting..."
    exit 1
  fi
  
  echo "Promoting ${INPUT_SITE_NAME}.dev to ${INPUT_SITE_NAME}.test."
  
  terminus auth:login --machine-token="${INPUT_TERMINUS_TOKEN}"
  terminus -y env:deploy "${INPUT_SITE_NAME}".test --note "Deploying ${GITHUB_REPOSITORY} - ${GITHUB_SHA}"
  terminus -y env:clear-cache "${INPUT_SITE_NAME}".test
fi
