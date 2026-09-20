# Runs the app against rudransh-staging in Chrome.
#
#   .\scripts\run_staging.ps1
#
# The publishable key is public by design: it is in every deployed build, and
# row-level security is what actually guards the data. The secret and
# service_role keys must never appear here.
#
# Production is deliberately absent. Deploys to production go through CI.

$defines = @(
  "--dart-define=SUPABASE_URL=https://gyzxvtqmzrabjyexqeno.supabase.co",
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_iv7gqnWjqE9oZud3fRpwbA_Hqxhvkhe",
  "--dart-define=CLOUDINARY_CLOUD_NAME=n9mgnr8s",
  "--dart-define=CLOUDINARY_UPLOAD_PRESET=rudransh_certificates"
)

flutter run -d chrome @defines
