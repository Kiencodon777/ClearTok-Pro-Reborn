# Staging artifacts

Manual workflow_dispatch runs use the GitHub `staging` environment and never
publish a GitHub Release or update the public update feed. Push runs use
`production`. Source changes must be reviewed and uploaded only with the owner's
separate commit/push authorization.

Environment variables (public values):

- SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY
- ANDROID_EXPECTED_CERT_SHA256: certificate digest verified against the previous APK
- UPDATE_FEED_URL when applicable

Android environment secrets:

- ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD

The signer setup compares the configured keystore certificate with the expected
digest. The previous APK certificate must be independently checked before
setting that value. A missing or different signer blocks Android; there is no
debug-key fallback. Keystores stay in runner.temp and are not artifact inputs.

Flutter production scripts receive VERSION/GITHUB_RUN_NUMBER and backend values.
Installable archives are checked for CRC/private file names and receive SHA-256
sidecars. Existing iOS ad-hoc packaging/re-signing checks remain in the workflow.

Download `release-android`, `release-ios` or `release-web` from a successful
manual run. Symbol artifacts are separate, private to repository access, named
with platform and source SHA and retained for 30 days. Repository administrators
must archive symbols securely before retention expires if longer diagnostics
are required. Never attach private-symbols artifacts to Releases.

Local regression commands:

```
npm ci
npm test
python -m unittest discover -s test -p '*_test.py'
```

Current results and blockers are recorded in TEST_REPORT.md. The staging database
and account function have been deployed. Successful login, SMTP delivery,
signing-key availability and remote CI still require runtime verification.

## Existing staging migration history

The three initial migrations were applied through Dashboard SQL, rather than the
CLI. Do not run db push against this project before reconciling migration history:
it may try to create existing tables again. After checking the schema and linking
only to project jsxxxbspjmpbaomotgcj, the operator can mark each applied version:

```
supabase link --project-ref jsxxxbspjmpbaomotgcj
supabase migration list
supabase migration repair 202611040001 --status applied
supabase migration repair 202611040002 --status applied
supabase migration repair 202611040003 --status applied
supabase migration list
```

These commands update migration tracking, not application data; they have not been
run by the agent. Reference: https://supabase.com/docs/reference/cli/supabase-migration-repair.

Run supabase/staging_rls_check.sql only on staging as database owner. It creates
three fixture identities inside a transaction and rolls back all of them. It
tests database authorization, not email confirmation or password login.

Rollback the reviewed source patch separately from database changes. Preserve
auth/users and application tables; do not drop data to roll back a client build.
Retain prior installable artifacts and private symbols. An Android signing-key
change needs an explicit compatibility decision because the old APK is debug-signed.
