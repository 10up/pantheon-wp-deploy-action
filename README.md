# Pantheon WordPress Deploy Action

> Deploy WordPress sites to Pantheon

[![Support Level](https://img.shields.io/badge/support-active-green.svg)](#support-level) [![Release Version](https://img.shields.io/github/release/10up/pantheon-wp-deploy-action.svg)](https://github.com/10up/pantheon-wp-deploy-action/releases/latest) [![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://github.com/10up/pantheon-wp-deploy-action/blob/trunk/LICENSE) [![Automated Tests](https://github.com/10up/pantheon-wp-deploy-action/actions/workflows/test.yml/badge.svg)](https://github.com/10up/pantheon-wp-deploy-action/actions/workflows/test.yml)

[Pantheon](https://pantheon.io/product/wordpress-hosting) has its own deployment workflow called "WebOps" which is based around a unique, git-driven infrastructure. All environments on Pantheon are version-controlled with git, this includes WordPress core, plugins, themes, etc. Pantheon's `master` branch is tied to the `Dev` environment, from there you need to manually(from the dashboard or via the Terminus CLI) promote the content to Pantheon's `Test` environment and ultimately to the `Live` site which is the production environment. At 10up, the code in the git's main branch is production ready(preprod and production environments only) therefore our preferred deployment workflow for Github + Pantheon sites is:
* Use Pantheon multidev environments for the project's lower environments(dev, staging, etc.) and create a Github branch with the same name as the multidev environment to automatically deploy to them
* The Github main branch deploys to the Pantheon's `Dev` environment but automatically promotes the code to the Pantheon `Test` environment
  * We use the Pantheon's `Test` environment as our preprod environment
* Once the changes have been tested we promote the code in the `Test` environment to `Live`

# Requirements

* The `Development Mode` must to be set as `Git` in the dashboard
* This Github action expects a payload/artifact containing a fully built WordPress site with the following structure:
  * WordPress root files at the top level. e.g. `pantheon.yml`, `wp-config.php`, etc
  * Plugins, MU Plugins, drop-in plugins, Themes, `vendor` directory and everything that should go inside the `wp-content` directory(excluding the `uploads` directory) in a folder with the same name

# Inputs

| Name | Required | Description |
| --- | --- | --- |
| `pantheon_git_url` | True | Pantheon's Git URL |
| `multidev_env_name` | False | Pantheon's multidev environment name. If set, the Github action will deploy to a multidev environment with the same name. This input is ignored on actions executed from the main branch |
| `working_dir` | False | Directory containing the WordPress built site |
| `site_name` | False | Pantheon's site name |
| `terminus_token` | False | Token to authenticate with the Terminus CLI. See instructions to generate machine tokens [here](https://docs.pantheon.io/machine-tokens) | 
| `ssh_private_key` | True | Private SSH Key to access the Pantheon's repository. The public key must be added to Pantheon, see instructions [here](https://docs.pantheon.io/ssh-keys) |
| `wordpress_version` | True | WordPress core version to fetch into the site from Pantheon's upstream before deploying to Pantheon |
| `root_files` | False | Files to copy in the WordPress root directory. e.g. `pantheon.yml`, `wp-config.php`, etc |
| `git_user_name` | False | GIT user name needed to pull and push to the Pantheon's repository |
| `git_user_email` | False | GIT user email address needed to pull and push to the Pantheon's repository |
| `promote_test_to_live` | False | Backups Pantheon Live site and promotes Test to Live. If this value is set to `yes`(must be an exact match) the action will only backup the Live site, promote Test to Live and then exits; all other steps will be ignored. This input is applied on actions executed from the main branch only. The workflow **must** use `workflow_dispatch` as trigger in order to manually execute this action  |

# Examples

## Deploy to a multidev environment

This example assumes the WordPress site has been previously built inside the `payload` directory following the structure described [here](#requirements)

```yaml
name: Deploy

on:
  push:
    branches:
      - staging

jobs:
  deploy:
    name: Deploy built site to Pantheon
    runs-on: ubuntu-latest

    steps:
      # Fetch previously built site.
      - name: Fetch artifact
        uses: actions/cache@v3
        with:
          path: payload
          key: ${{ github.sha }}

      # Deploy to Pantheon
      - name: Deploy to Pantheon
        uses: 10up/pantheon-wp-deploy-action@v1
        with:
          pantheon_git_url: "${{ secrets.PANTHEON_GIT_URL }}"
          multidev_env_name: "staging"
          ssh_private_key: "${{ secrets.PRIVATE_KEY }}"
          wordpress_version: "6.4.3"
          working_dir: "./payload"
          root_files: "pantheon.yml wp-config.php"
```

## Deploy to Pantheon's Dev environment and automatically promotes Dev to Test

This example assumes the WordPress site has been previously built inside the `payload` directory following the structure described [here](#requirements)

```yaml
name: Deploy

on:
  push:
    branches:
      - trunk

jobs:
  deploy:
    name: Deploy built site to Pantheon
    runs-on: ubuntu-latest

    steps:
      # Fetch previously built site.
      - name: Fetch artifact
        uses: actions/cache@v3
        with:
          path: payload
          key: ${{ github.sha }}

      # Deploy to Pantheon
      - name: Deploy to Pantheon
        uses: 10up/pantheon-wp-deploy-action@v1
        with:
          pantheon_git_url: "${{ secrets.PANTHEON_GIT_URL }}"
          ssh_private_key: "${{ secrets.PRIVATE_KEY }}"
          terminus_token: "${{ secrets.TERMINUS_TOKEN }}"
          site_name: "my-pantheon-site"
          wordpress_version: "6.4.3"
          working_dir: "./payload"
          root_files: "pantheon.yml wp-config.php"
```

## Deploy to Pantheon's Dev environment only (not recommended)

This example assumes the WordPress site has been previously built inside the `payload` directory following the structure described [here](#requirements)

```yaml
name: Deploy

on:
  push:
    branches:
      - trunk

jobs:
  deploy:
    name: Deploy built site to Pantheon
    runs-on: ubuntu-latest

    steps:
      # Fetch previously built site.
      - name: Fetch artifact
        uses: actions/cache@v3
        with:
          path: payload
          key: ${{ github.sha }}

      # Deploy to Pantheon
      - name: Deploy to Pantheon
        uses: 10up/pantheon-wp-deploy-action@v1
        with:
          pantheon_git_url: "${{ secrets.PANTHEON_GIT_URL }}"
          ssh_private_key: "${{ secrets.PRIVATE_KEY }}"
          site_name: "my-pantheon-site"
          wordpress_version: "6.4.3"
          working_dir: "./payload"
          root_files: "pantheon.yml wp-config.php"
```

By not adding the `terminus_token` the action will skip the step to automatically promote `Dev` to `Test`

## Deploy to Pantheon's Live environment

In this example the inputs `pantheon_git_url`, `ssh_private_key` and `wordpress_version` aren't being used by the Github action but they are marked as required in the `actions.yml` so we add them to prevent the action from failing

```yaml
name: Promote Test to Live

on: workflow_dispatch

jobs:
  deploy:
    name: Promote Test to Live
    runs-on: ubuntu-latest

    steps:
      - name: Promote Test to Live
        uses: 10up/pantheon-wp-deploy-action@v1
        with:
          pantheon_git_url: "${{ secrets.PANTHEON_GIT_URL }}"
          ssh_private_key: "${{ secrets.PRIVATE_KEY }}"
          terminus_token: "${{ secrets.TERMINUS_TOKEN }}"
          wordpress_version: "6.4.3"
          site_name: "my-pantheon-site"
          promote_test_to_live: "yes"
```

## Support Level

**Active:** 10up is actively working on this, and we expect to continue work for the foreseeable. Bug reports, feature requests, questions, and pull requests are welcome.

## Changelog

A complete listing of all notable changes to this Github Action are documented in [CHANGELOG.md](https://github.com/10up/pantheon-wp-deploy-action/blob/trunk/CHANGELOG.md).

## Contributing

Please read [CODE_OF_CONDUCT.md](https://github.com/10up/pantheon-wp-deploy-action/blob/trunk/CODE_OF_CONDUCT.md) for details on our code of conduct, [CONTRIBUTING.md](https://github.com/10up/pantheon-wp-deploy-action/blob/trunk/CONTRIBUTING.md) for details on the process for submitting pull requests to us, and [CREDITS.md](https://github.com/10up/pantheon-wp-deploy-action/blob/trunk/CREDITS.md) for a listing of maintainers and contributors.

## Like what you see?

<p align="center">
<a href="http://10up.com/contact/"><img src="https://10up.com/uploads/2016/10/10up-Github-Banner.png" width="850"></a>
</p>
