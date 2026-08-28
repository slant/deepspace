# Deep Space D-6: The Long Way Home (Digital Companion)

Solo RPG companion web app for **Deep Space D-6: The Long Way Home** v1.43.

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

`config/map.yml` was generated from the official PDF starmap (page 8) in `public/docs/Deep Space D6 - The Long Way Home RPG v1.43.pdf`. Regenerate with:

```bash
.venv/bin/python scripts/extract_map_from_pdf.py
```

## Rulebook

The rulebook PDF is served at `/docs/Deep%20Space%20D6%20-%20The%20Long%20Way%20Home%20RPG%20v1.43.pdf`.




# Deep Space D-6: The Long Way Home

A digital companion web application for the solo RPG **Deep Space D-6: The Long Way Home** by Tony Go.

## About the Project

This is a full-featured web app designed to enhance and streamline the solo play experience of *Deep Space D-6: The Long Way Home*. It provides an interactive hex map, guided character creation, persistent campaign saves, story modals, and automatic progress tracking — all while staying faithful to the original PDF.

**Solo play only.**

## Features

- **Google OAuth** authentication
- Beautiful marketing-style landing page
- Campaign-based save system (each campaign tied to one character)
- Guided character & ship creation (Captain, Ship, 4 Officers)
- Fully interactive pointy-top hexagonal starmap (SVG rendered)
- Click-to-move ship with story modals
- Automatic server-side saving (never lose progress)
- Responsive design (desktop + mobile friendly)
- Dark sci-fi aesthetic

## Tech Stack

- **Ruby on Rails 8**
- PostgreSQL
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- Devise + OmniAuth (Google)
- SVG for map rendering
- ViewComponents

## Project Structure Highlights

- `app/models/` — Campaign, Character, Officer, etc.
- `app/components/` — ViewComponents for reusability
- `app/javascript/controllers/` — Stimulus controllers (especially map-related)
- `config/maps/` — YAML definitions for the starmap
- `public/map/` — Reference files for hex map rendering logic & styles

## Quick Start (Development)

```bash
# Clone the repo
git clone <repository-url>
cd deep-space-d6-long-way-home

# Install dependencies
bundle install
yarn install

# Setup database
rails db:create
rails db:migrate

# Start the server
rails server