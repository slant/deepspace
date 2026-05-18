# Deep Space D6 — The Long Way Home (Digital Companion)

Solo RPG companion web app for **Deep Space D6 - The Long Way Home** v1.43.

## Stack

- Rails 8, PostgreSQL, Hotwire (Turbo + Stimulus), Tailwind CSS
- Devise + Google OAuth (no email/password signup)
- SVG hex starmap (data-driven from `config/map.yml`)

## Setup

1. Install dependencies: `bundle install`
2. Copy `.env.example` to `.env` and set Google OAuth credentials
3. Create databases: `bin/rails db:prepare`
4. Run the app: `bin/dev` (or `bin/rails server` + `bin/rails tailwindcss:watch`)

## Google OAuth

Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com/) with redirect URI:

`http://localhost:3000/users/auth/google_oauth2/callback`

## Map data

`config/map.yml` was generated from the official PDF starmap (page 8) in `public/Deep Space D6 - The Long Way Home RPG v1.43.pdf`. Regenerate with:

```bash
.venv/bin/python scripts/extract_map_from_pdf.py
```

## Rulebook

The rulebook PDF is served at `/Deep%20Space%20D6%20-%20The%20Long%20Way%20Home%20RPG%20v1.43.pdf`.
