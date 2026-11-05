# Staging deployment and verification

1. Run `npm ci`, `npm test` and `node --test test/backend_rls_test.cjs` in app/.
   PGlite executes PostgreSQL SQL/RLS against a minimal auth fixture; it does not
   emulate the hosted Supabase Auth service.
2. Create an isolated staging Supabase project. Configure SMTP, email confirmation,
   password policy and approved Auth redirect/recovery URLs. Install Supabase CLI.
3. After explicit operator authorization, run `supabase link --project-ref REF`,
   inspect the schema, then `supabase db push` and `supabase functions deploy account`.
   Keep the function's `auth.getUser()` verification enabled. `config.toml`
   disables only the gateway's legacy-secret verifier, which is incompatible
   with modern signing keys. The function rejects missing/invalid user tokens
   before RPC; it uses the built-in URL/anon key, never a service-role key.
   See https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys.
4. Register/verify the operator normally. As database owner run
   `psql -v admin_id=VERIFIED_UUID -f supabase/bootstrap_admin.sql`. Verify its audit
   record. No account or password is created by bootstrap.
5. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in the build environment. Run
   `npm run build:admin` and serve build/admin/ over HTTPS. Enter the public
   URL/key in the connection form and log in as the verified operator.
6. Run `npm run build:extension`. Load build/cleartok-web-production in an isolated
   Chrome profile. Session tokens remain in chrome.storage.session and are not
   passed to the TikTok page function. Configure and test recovery URLs separately.
7. Flutter takes the same values through --dart-define or the production scripts.
   Missing configuration shows a setup message. Existing Hive data stays local;
   ClearTok logout does not clear TikTok cookies.

## Policy

Active installation limits are Free=1, Premium=5, Admin=10. Enrollment locks the
profile row before counting/inserting. Revoked installation IDs cannot reactivate
themselves. IDs represent installations under a session, not hardware identity.
Reinstalling may create a new ID subject to the account limit.

Feature flags initially allow repost/unlike/unfollow for Free. Administrative
database changes and their audit insert are one transaction. Account status is
checked in the backend even if an old Auth JWT is still valid. Flutter checks
before writes and periodically during a batch. Extension checks before page
commands. A modified local client can bypass TikTok gating. Device revocation is
not global GoTrue session revocation.

## Release

Use Android scaffolding from the existing workflow, JDK 17, the required SDK and
licenses. Supply a verified production signer; the build script refuses the
generated debug signing configuration. R8/resource shrinking and private mapping
retention are configured by the production script. Preserve application ID and
the native MethodChannel. iOS requires macOS/Xcode and the existing IPA packaging
and re-signing process. Keep split symbols/R8 mappings outside public artifacts.

## Rollback and remaining validation

Back up the database before applying migrations. Roll back app code separately;
do not drop profiles/auth.users as a UI rollback. Preserve data and use a reviewed
forward migration for schema repair. Retain prior artifacts with their symbols.

Hosted register/login, SMTP confirmation, recovery redirects, session restoration,
Admin UI actions and native builds still require a staging project/test devices.
This work does not deploy production. Test both recovery callbacks and access
revocation before making the service public.
