# Wirecutter App

## Stack
- Expo SDK 54 with Expo Router (file-based routing)
- TypeScript (strict mode)
- React Native 0.81 with Swift native modules via Expo Modules API
- React 19

## Architecture
- Screens live in `app/` using Expo Router file conventions
- Tab screens: `app/(tabs)/` — index (Home), categories, search, saved
- Detail screens: `app/product/[id].tsx`, `app/category/[slug].tsx`
- Shared components in `components/`
- NYT design system tokens and primitives in `components/nyt-design-system/`
- Native iOS modules in `modules/` using Expo Modules API (Swift)
- API layer in `services/`, hooks in `hooks/`, state in `store/`

## Conventions
- All components are functional with TypeScript props interfaces
- Use design tokens from `components/nyt-design-system/tokens.ts` — never hardcode colors/spacing
- Import design system via `@/components/nyt-design-system`
- Prefer composition over inheritance
- Name branches: `feature/{your-name}/{description}`
- Run `npx expo lint` before committing
- Run `npx expo start` to test in Expo Go or simulator

## Native Modules
- Create with: `npx create-expo-module@latest modules/{name} --local`
- Swift code goes in `modules/{name}/ios/`
- Always export a TypeScript interface alongside the native module
- See `modules/haptics-advanced/` for the pattern

## Git Workflow
- `main` branch is protected — all changes go through PRs
- PRs require 1 approval before merging
- Create feature branches: `git checkout -b feature/{your-name}/{feature-name}`
- Push and open PR: `git push -u origin HEAD && gh pr create`

## Key Files
- `components/nyt-design-system/tokens.ts` — design tokens (colors, typography, spacing)
- `services/types.ts` — shared TypeScript interfaces
- `services/api.ts` — API client functions
- `app/(tabs)/_layout.tsx` — tab navigation configuration
