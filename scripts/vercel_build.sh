#!/usr/bin/env bash
# Vercel's build step. In Vercel → Settings → Build and Deployment, the Build
# Command is just:
#
#   bash scripts/vercel_build.sh
#
# Vercel caps that field at 256 characters, so the flags live here instead.
# Each value comes from a Vercel environment variable (Settings →
# Environments); one left unset builds as empty, which the app treats as "not
# configured". The Install Command clones Flutter into ./flutter.
set -euo pipefail

export PATH="$PWD/flutter/bin:$PATH"

flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}" \
  --dart-define=ADMIN_EMAIL="${ADMIN_EMAIL:-}" \
  --dart-define=CLOUDINARY_CLOUD_NAME="${CLOUDINARY_CLOUD_NAME:-}" \
  --dart-define=CLOUDINARY_UPLOAD_PRESET="${CLOUDINARY_UPLOAD_PRESET:-}" \
  --dart-define=UPI_ID="${UPI_ID:-}" \
  --dart-define=UPI_PAYEE="${UPI_PAYEE:-}" \
  --dart-define=RAZORPAY_KEY_ID="${RAZORPAY_KEY_ID:-}" \
  --dart-define=TURNSTILE_SITE_KEY="${TURNSTILE_SITE_KEY:-0x4AAAAAAE_MTddf-fDjScJ1}"
