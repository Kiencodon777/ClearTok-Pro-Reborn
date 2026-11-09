# Admin online

On this Windows checkout, double-click `Open-Admin.cmd` in the project root.
It builds the admin and opens a loopback web server in your browser. Keep its
terminal open while using the admin. Requires Node.js, Python and `npm ci` once.
Do not open `admin/index.html` directly: it is unbundled source, and JavaScript
modules cannot run from a `file://` page. No Supabase URL/key entry is needed.

Open https://kiencodon777.github.io/ClearTok-Pro-Reborn/ and sign in with your
ClearTok admin account. The public Supabase connection is already filled in.
Only accounts approved as admin by the backend can access management data.

First deployment: repository Settings → Pages → Build and deployment → Source
must be GitHub Actions. Follow the “Deploy admin online” workflow for deployment
status. A Pages URL is usable only after that workflow succeeds.

Never enter a service-role key. Signing keys and passwords do not belong here.
