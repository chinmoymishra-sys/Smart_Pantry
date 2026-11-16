# Design tokens (verified)

Colours were read from the vector fills of the Figma PDF export (page 1 = light
theme, page 2 = dark theme) and matched role-by-role by usage count. They are
implemented in `lib/core/theme/app_colors.dart`.

| Role | Light | Dark |
|---|---|---|
| Page background | `#F9FAFB` | `#0F141B` |
| Surface / card | `#FFFFFF` | `#111827` |
| Muted surface (callouts, tiles, disabled button) | `#F3F4F6` | `#1F2937` |
| Border / divider | `#E5E7EB` | `#1F2937` |
| Text primary | `#111827` | `#F9FAFB` |
| Text muted | `#6B7280` | `#9CA3AF` |
| Primary button / selected chip fill | `#111827` | `#FFFFFF` |
| On primary | `#FFFFFF` | `#111827` |
| Primary border | `#111827` | `#E5E7EB` |
| Warning text (use soon, missing) | `#B45309` | `#F59E0B` |
| Warning surface | `#FFFBEB` | `#292113` |
| Danger text (remove, discard) | `#B91C1C` | `#FCA5A5` |
| Danger surface | `#FEF2F2` | `#2A171B` |
| Camera / scanner backdrop | `#111827` | `#0B0F14` |

## Typography (Inter, bundled in `assets/fonts`)
| Style | Size / line-height / tracking | Weight |
|---|---|---|
| Page title | 28 / 1.15 / −0.8 | Regular |
| Hero count | 32 / 1.1 / −1 | Regular |
| Section title | 20 / 1.25 / −0.4 | Regular |
| Step instruction | 20 / 1.45 | Medium |
| Cooking body | 17 / 1.45 | Regular |
| Button | 15 | Regular (disabled: Semi Bold) |
| Card title | 15 / 1.45 | Regular / Semi Bold |
| Subtitle | 14 / 1.45 | Regular |
| Body | 13 / 1.45 | Regular |
| Form label / text action | 13 / 1.45 | Semi Bold |
| Caption | 12 / 1.45 | Regular |
| Overline / nav label | 11 | Regular (active nav: Bold) |
| Timer | 38 / −1 | Semi Bold |

## Spacing & shape
- Page gutter 22; header padding 10 / 18; content padding 6 / 24; section gap 20.
- Card radius 18, padding 16, 1px border. Callout radius 10, padding 14, info icon 19.
- Buttons: min height 52, radius 10, padding 14×16, icon 20 + gap 10.
- Chips: pill, min height 44, padding 11×14, check icon 14 when selected.
- Bottom navigation: 4 destinations, icon 22, label 11, padding 12/12/8, top border.
- Icons: Lucide (`lucide_icons_flutter`), the same set used in the design.
