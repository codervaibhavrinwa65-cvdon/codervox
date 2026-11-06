# CODERVOX — Supabase setup

This folder contains a real multi-user starter for CODERVOX. It is not a static mockup: after Supabase is configured, users can register, sign in, publish posts, see the shared feed, like/comment, follow members, search profiles and receive feed refreshes.

## Files
- `index.html` — responsive CODERVOX frontend
- `supabase-schema.sql` — database tables, profile trigger, Row Level Security policies and image bucket setup

## 1. Create a Supabase project
1. Open https://supabase.com/ and create a project.
2. Save the database password somewhere private. Do not put it in website code.
3. In the project dashboard, open **SQL Editor**.
4. Paste all of `supabase-schema.sql` and run it.
5. In **Project Settings → API** (or **Connect**), copy the Project URL and the public publishable key (or legacy `anon` key).

## 2. Configure the website
Open `index.html` in a code editor. Find these lines near the bottom:

```js
const SUPABASE_URL = "YOUR_SUPABASE_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY";
```

Replace the placeholders with your own Project URL and public publishable/anon key.

**Never use the `service_role` key or any secret key in browser code.** The public key is designed for frontend use only when Row Level Security is correctly configured.

## 3. Deploy on GitHub Pages
1. Create a GitHub repository, for example `codervox`.
2. Upload `index.html` to the repository root.
3. Commit the file.
4. Open **Settings → Pages**.
5. Choose **Deploy from a branch**, branch `main`, folder `/ (root)`, then save.
6. Open the Pages URL shown by GitHub.

You can also deploy the same `index.html` to Netlify or Cloudflare Pages.

## 4. Test with two accounts
1. Open the deployed website in a normal browser window and create account A.
2. Confirm the email if Supabase email confirmation is enabled.
3. Publish a text post and optionally an image under 5 MB.
4. Open a private/incognito window or another device and create account B.
5. Account B should see account A's public post, like/comment and follow account A.

## Current functionality
- Email/password registration and sign-in
- Shared public profile records
- Edit display name, username, bio and avatar URL
- Shared post feed, image upload, likes and comments
- Follow/unfollow and member search
- Realtime refresh when new posts are inserted
- Report-post submission
- Responsive dark CODERVOX interface

## Important limitations before public launch
This is a starter/MVP, not a complete Instagram replacement. Stories, direct messages, private accounts, push notifications, video/reels, robust moderation/admin review, rate limits, account deletion/export and advanced feed ranking are not implemented yet. The report table accepts reports but does not provide an admin review dashboard.

Before inviting the public:
- Configure Supabase Auth email templates and allowed redirect URLs for your deployed domain.
- Keep Row Level Security enabled. Review the SQL policies and test them using separate accounts.
- Add an admin-only moderation workflow and clear community rules.
- Set sensible project usage alerts/limits and review the current Supabase pricing.
- Add privacy policy, terms, contact/support and account deletion process.
- Avoid collecting sensitive personal information. Do not publish home addresses, school schedules or private contact details.
- If this is used by minors, set up suitable moderation, reporting and privacy protections before opening registration broadly.

## Troubleshooting
- **“Setup required”**: check the Project URL and public key constants.
- **Email confirmation**: check the inbox and spam folder; adjust Auth settings only if appropriate.
- **Username already taken**: choose another username.
- **Image upload fails**: verify the SQL bucket policies ran and the image is JPG/PNG/WebP under 5 MB.
- **RLS error**: rerun the schema script and inspect the Supabase logs. Do not disable RLS as a workaround.
