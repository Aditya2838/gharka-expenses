# GharKa Expenses

A mobile-friendly family expense tracker built with plain HTML, CSS, JavaScript, Supabase Auth and Supabase Postgres.

## Included
- Individual email/password login for Aditya, Mom, Dad and Bhavana
- Invite-code-only registration
- Add, edit and delete your own expenses
- Family-wide read-only visibility of expense entries
- Monthly totals, today's total, your own monthly total
- Member and category breakdowns
- Date, category, payment method and notes
- Responsive mobile layout

## Setup

1. Create a Supabase project.
2. Open **SQL Editor** and run all of `schema.sql`.
3. Before running the SQL, replace the four sample invite codes in the `INSERT INTO public.family_invites` section with your own private codes. Keep a note of which code belongs to which person.
4. In Supabase, open **Project Settings → API** (or API Keys) and copy the Project URL and the publishable key (or legacy anon public key).
5. Open `index.html` and replace:
   - `YOUR_SUPABASE_PROJECT_URL`
   - `YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY`
6. In Supabase **Authentication → URL Configuration**, set your local development URL / deployed site URL and add it to the allowed redirect URLs.
7. Serve the folder using VS Code Live Server, or deploy `index.html` to Netlify / Vercel / GitHub Pages.
8. Each family member opens the site, selects **Create account**, chooses their assigned name, enters their unique invite code, email and password. Confirm email if Supabase email confirmation is enabled, then log in.

## Important security notes
- Use only the Supabase publishable/anon key in the browser. **Never** put the `service_role` key in `index.html`.
- Invite codes are one-time and cannot be read from the frontend because RLS is enabled and no invite-table read policy is created.
- The SQL trigger creates the profile and consumes the invite code during signup.
- Members can see all family expenses, but can edit/delete only expenses they personally created.
- The family member profile names are unique within this family.
- If you need to reset an invite after a failed signup, inspect `family_invites.used_by` in Supabase SQL Editor as project owner. Do not expose the service role key in the website.
- The sample invite strings in schema.sql are placeholders. Change them before use.

## Run locally
Open the folder in VS Code and use the Live Server extension. Do not open the HTML as a `file://` URL; use a local HTTP server.

## Notes
The page fetches the latest 1,000 expense rows for the family. This is a starter implementation; for a very large history, add server-side date pagination.
