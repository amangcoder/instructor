# Instructor Marketing Website

A modern marketing website for the Instructor mobile app built with Next.js 15, React 19, and Tailwind CSS v4.

## Project Structure

```
web/
├── app/
│   ├── layout.tsx          # Root layout with Manrope font and global styles
│   ├── page.tsx            # Home page stub
│   └── globals.css         # Global styles with Tailwind v4 @theme config
├── public/                 # Static assets (favicon, images, etc.)
├── package.json            # Dependencies and scripts
├── tsconfig.json           # TypeScript configuration with path aliases
├── next.config.ts          # Next.js configuration (hybrid mode)
├── postcss.config.js       # PostCSS configuration for Tailwind
└── .env.example            # Environment variables template
```

## Setup Instructions

### 1. Install Dependencies
```bash
cd web
pnpm install
```

### 2. Environment Variables
Copy `.env.example` to `.env.local` and configure:
```bash
cp .env.example .env.local
```

Edit `.env.local`:
```env
BACKEND_URL=http://localhost:3071
API_KEY=your_api_key_here
```

### 3. Development Server
```bash
pnpm dev
```

The site will be available at http://localhost:3072

### 4. Build for Production
```bash
pnpm build
pnpm start
```

## Technology Stack

- **Framework:** Next.js 15.2.3+ (App Router)
- **UI Library:** React 19
- **Styling:** Tailwind CSS v4 (CSS-based @theme configuration)
- **Font:** Manrope (weights: 400, 700, 800) via next/font/google
- **Language:** TypeScript 5.6+
- **Typography Plugin:** @tailwindcss/typography

## Brand Colors

The following CSS custom properties are defined in `globals.css`:

- `--color-primary`: #565C8C (Primary brand color)
- `--color-primary-container`: #C0C6FD (Primary container)
- `--color-surface`: #FBF8FE (Background surface)
- `--color-on-surface`: #31323B (Text on surface)

## Configuration Details

### TypeScript
- Strict mode enabled for type safety
- Path aliases configured:
  - `@/*` → `./src/*`
  - `@/components/*` → `./src/components/*`
  - `@/lib/*` → `./src/lib/*`
  - `@/utils/*` → `./src/utils/*`
  - etc.

### Tailwind CSS v4
- CSS-based configuration in `globals.css` (no `tailwind.config.ts`)
- PostCSS integration via `postcss.config.js`
- Typography plugin included via `@tailwindcss/typography`

### Next.js Configuration
- Hybrid deployment mode (static pages + API routes)
- React Strict Mode enabled
- ESLint enabled (not ignored during builds)

## Development Guidelines

1. **Components:** Follow the app/components directory structure
2. **Styling:** Use Tailwind CSS classes with custom CSS variables for brand colors
3. **TypeScript:** Always use strict types, no `any` unless necessary
4. **Fonts:** Use the Manrope font via the CSS variable or Tailwind classes
5. **Testing:** Add tests alongside components (`.test.tsx` or `.spec.tsx`)

## Available Scripts

- `pnpm dev` - Start development server
- `pnpm build` - Build for production
- `pnpm start` - Start production server
- `pnpm lint` - Run ESLint
- `pnpm type-check` - Run TypeScript compiler check

## Deployment

The project is configured for hybrid deployment:
- Static pages (/, /privacy-policy, /data-deletion) are pre-rendered
- API routes can be deployed to serverless functions or traditional servers
- See `next.config.ts` for deployment configuration
