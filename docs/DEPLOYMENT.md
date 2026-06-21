# Deployment — `jobdun.com.au`

The marketing site at `jobdun.com.au` is built by
[`.github/workflows/deploy-website.yml`](../.github/workflows/deploy-website.yml)
and deployed to **Cloudflare Pages** from every push to `main`.

## Required secrets (GitHub → Settings → Secrets and variables → Actions)

| Secret | Where to get it | Scope |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare dashboard → My Profile → API Tokens → Create Token → **Edit Cloudflare Pages** template. Under "Account Resources" restrict to the Pages project this site lives in. | `pages:write` |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare dashboard → Workers & Pages → your project → right sidebar. The 32-char hex. | n/a |

## Required variables (GitHub → Settings → Variables → Actions → Repository variables)

| Variable | Default | Notes |
|---|---|---|
| `CLOUDFLARE_PROJECT_NAME` | `jobdun-site` | The Pages project name. Set to the name you used in Cloudflare Pages. |

## One-time Pages setup (already done)

1. Cloudflare dashboard → Workers & Pages → Create application → Pages → **Connect to Git**.
2. Select the `jobdun/jobdun-app` repo. **Do not** enable the build step here — the GitHub Actions workflow builds the site and uses `cloudflare/pages-action@v1` to push the artifact. Cloudflare's built-in build step is left blank.
3. Custom domain: `jobdun.com.au` (and `www.jobdun.com.au` → 301 to apex). Set in Pages → Custom domains.
4. Cloudflare's edge headers (X-Frame-Options, HSTS, Permissions-Policy) are configured in `web/_headers` and shipped with the build — no dashboard config needed for those.

## How a deploy runs

1. Push to `main` triggers `.github/workflows/deploy-website.yml`.
2. **build** job: pins Flutter `3.41.7`, runs `flutter build web -t lib/website/main_website.dart --no-tree-shake-icons --release`, verifies the artifact (`main.dart.js`, `index.html`, `_headers`, `_redirects` all present), uploads as a GitHub Actions artifact.
3. **deploy** job: downloads the artifact, hands `build/web/` to `cloudflare/pages-action@v1` with the token + account + project. Cloudflare publishes to the `production` environment; the GitHub Actions summary links to `https://jobdun.com.au`.

Concurrency is set to `deploy-website` with `cancel-in-progress: true` — a new commit to `main` cancels any in-flight deploy so the queue never publishes a half-built artifact.

## Why not Cloudflare's built-in build step?

Cloudflare Pages' default build environment doesn't ship Flutter. The two options are:

1. **Custom build image** (Cloudflare's newer feature) — pins a Docker image with Flutter pre-installed. Works, but the lock-in is heavier: the build environment lives in Cloudflare's dashboard, not in the repo.
2. **GitHub Actions** (this workflow) — Flutter pin lives in the workflow file, the build is reproducible, the artifact is inspectable in the Actions UI, and PRs can lint the build before merge. Cost: GitHub Actions minutes (free tier: 2000 min/month, this job uses ~3 min/deploy).

We went with (2). Migrate to (1) later if GitHub Actions becomes a cost concern.

## Preview deploys on PR

Not enabled. Add later by:
1. Cloudflare dashboard → Pages → Settings → Build → enable Preview deployments.
2. Change the workflow's `on:` to include `pull_request`.
3. Remove the `if:` gate on the `deploy` job — it currently skips on `pull_request` events to avoid burning the secrets on forks.

## Rollback

Cloudflare Pages keeps the last 50 deployments. To roll back:
1. Cloudflare dashboard → Workers & Pages → `jobdun-site` → **Deployments** tab.
2. Find a green build, click **...** → **Rollback to this deployment**.

No workflow run required.
