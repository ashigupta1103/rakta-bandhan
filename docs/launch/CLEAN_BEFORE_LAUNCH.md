# Clean the test data before launch

Do this once, after all your testing is finished and just before the public build. It removes every test account and everything people created, so the first real users see an empty, honest app.

The script is [`functions/scripts/clean-test-data.mjs`](../../functions/scripts/clean-test-data.mjs). Its check on the emulators is `cd functions && npm run smoke:clean` (passes). It has **not** been run against the live project.

## What stays and what goes

| Stays | Goes |
|---|---|
| Every admin (each uid in the `admins` collection) and their sign-in accounts | Every other sign-in account, including accounts that never finished registering |
| Accounts you name with `--keep-email` (use it for the Play review accounts) | Donor profiles, public listings, usernames, ID-proof records |
| `config` (your switches), `hospitals`, `announcements`, published `testimonials`, `audit_log` | Requests with their chats and calls, donation history, reports, support and partnership messages, community stories, testimonial submissions, broadcasts, the impact counter |

It refuses to run if it cannot find an admin sign-in account, so it can never delete you. If an admin also has a donor profile, that profile stays too.

## Steps

**1. One-time setup so the script can sign in as you (about 10 minutes).** This is your own Google login. No service-account key is created, and step 6 removes the login again.

1. Install the Google Cloud CLI for Windows: <https://cloud.google.com/sdk/docs/install-sdk> (the installer, accept the defaults).
2. Open a new PowerShell window and run:

```powershell
gcloud auth application-default login
gcloud auth application-default set-quota-project rakta-bandhan-india
```

Sign in as raktabandhan2026@gmail.com when the browser opens.

**2. Dry run. Nothing is deleted.**

```powershell
Set-Location X:\BloodBankkk\functions
node scripts/clean-test-data.mjs --project rakta-bandhan-india --yes-live
```

Read the list under "Keeping these accounts". It must show your admin email, and nobody you want to lose. If you have Play review accounts, add `--keep-email reviewer-a@x.com,reviewer-b@x.com`.

**3. Delete for real.** Same command with `--apply` added:

```powershell
node scripts/clean-test-data.mjs --project rakta-bandhan-india --yes-live --apply
```

**4. Empty the photo bucket.** The script does not touch Cloudflare. In the Cloudflare dashboard (the raktabandhan2026 account): R2, bucket `bloodbank`, Objects, select all, Delete. Repeat until it is empty.

**5. Check.**
- Firebase console, Authentication, Users: only the admin (and reviewers).
- Firestore: `donors`, `requests`, `community_stories` are empty. `admins`, `config`, `hospitals` still there.
- Open the admin site and log in.

**6. Take the sign-in off your PC:**

```powershell
gcloud auth application-default revoke
```

## If something goes wrong

- "Refusing to touch a real project": you left out `--yes-live` or `--project`.
- A permission or quota-project error from Google: re-run the two `gcloud` commands in step 1 and make sure you signed in as the project owner.
- You deleted the admin by mistake: create the Authentication user again in the console, then put its new uid in the `admins` collection (a document whose ID is that uid).
