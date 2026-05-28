# ClipX design system

## Visual theme and atmosphere
ClipX uses a native macOS productivity-tool posture: dark-first, quiet, precise, and glassy without decorative clutter. The app surfaces feel local, private, and fast, with muted slate layers, soft depth, and a restrained cyan-indigo accent.

## Color palette and roles
| Token | Dark value | Light value | Role |
|---|---:|---:|---|
| Canvas | `oklch(10.5% 0.012 255)` | `oklch(97.5% 0.006 250)` | App and marketing background |
| Surface | `oklch(18% 0.012 255 / 0.72)` | `oklch(100% 0.002 250 / 0.86)` | Mac window panels |
| Raised | `oklch(24% 0.014 255 / 0.72)` | `oklch(100% 0.002 250 / 0.96)` | Clipboard rows and cards |
| Text | `oklch(93% 0.006 250)` | `oklch(19% 0.014 250)` | Primary text |
| Muted | `oklch(69% 0.014 250)` | `oklch(49% 0.014 250)` | Metadata and secondary copy |
| Border | `oklch(100% 0 0 / 0.09)` | `oklch(82% 0.009 250 / 0.72)` | Hairlines and dividers |
| Accent | `oklch(68% 0.13 232)` | `oklch(56% 0.15 236)` | Primary action and focus |
| Mint | `oklch(73% 0.11 165)` | `oklch(54% 0.12 165)` | Success and privacy |
| Amber | `oklch(78% 0.13 82)` | `oklch(63% 0.14 76)` | Favorite and warning |

## Typography rules
Use SF Pro Display for headings and SF Pro Text for interface copy, falling back to system UI. Display type is compact, weight 650 to 760, letter-spacing `-0.022em`. Metadata and shortcuts use the mono stack with tabular numbers.

## Component styling
Buttons use a fixed 12px radius, 40px minimum height, transform-only press feedback, and visible focus rings. Clipboard rows are raised translucent surfaces with a left type glyph, app source metadata, one action cluster, and no colored side borders. Settings rows are macOS preference rows with right-aligned switches and inline helper copy.

## Layout principles
Desktop app screens use a 1200 by 800 macOS window, a 236px sidebar, a flexible history column, and a 352px detail panel. The quick launcher is a 760 by 520 centered command window. The website uses a product mockup as the hero anchor, then feature, privacy, audience, pricing, and footer bands.

## Depth and elevation
Dark mode uses luminance steps and inset hairlines instead of heavy black shadows. Light mode uses subtle shadow plus a 4 percent background step between canvas, panels, and rows. Glass is reserved for macOS windows, command surfaces, and nav chrome.

## Do's and don'ts
- Do use concise English UI copy with realistic clipboard content.
- Do keep the accent budget small: primary actions, focus, and selected states.
- Do show privacy as product behavior, not as generic shield marketing.
- Do keep actions keyboard first with visible keycaps.
- Do not use cartoon icons, emoji feature rows, or colorful AI gradients.
- Do not combine all requested surfaces into one long screenshot page.
- Do not invent performance or security metrics without a source.

## Responsive behavior
Marketing pages adapt from 1440px desktop down to 360px mobile. App mockup pages preserve the desktop window contract but allow horizontal-free scaling and compact internal grids below 900px. Hit targets stay at least 40px on web and 44px in app-like controls.

## Agent prompt guide
- Main window: use `--bg`, `--surface`, `--raised`, 16px window radius, 236px sidebar, selected rows with `--accent-soft`, and code previews in `--code-bg`.
- Command palette: use a 760 by 520 glass window, search at 48px height, selected result with `--accent-soft`, right key hint cluster, and opacity plus scale entrance.
- Settings privacy: use a macOS preference sidebar, grouped rows, mint privacy indicators, and right-aligned switches.
- Landing hero: use a dark canvas, product mockup centered, floating clipboard snippets, headline at 72px desktop and 44px mobile, and two primary navigation actions.
