# Maplog UI system

Maplog keeps its existing lime primary color and uses a warm, photography-first social layout. The implementation follows one hierarchy: primitive tokens → semantic roles → component styles.

## Foundations

| Role | Swift token | Rule |
| --- | --- | --- |
| Primary | `Color.maplogPrimary` | Main CTA and selected state only |
| Primary pressed | `Color.maplogPrimaryPressed` | Press feedback |
| Main text | `Color.maplogTextPrimary` | Headings and high-emphasis UI |
| Secondary text | `Color.maplogTextSecondary` | Descriptions and metadata |
| Page background | `Color.maplogBackground` | Main scrolling canvas |
| Surface | `Color.maplogSurface` | Cards, sheets, navigation |
| Border | `Color.maplogBorder` | Dividers and control outlines |

Spacing uses a 4-point base: 4, 8, 12, 16, 20, 24, 32, 40. Page gutters are 20pt and section gaps are 24–32pt. Avoid adding a new numeric padding when one of `MaplogSpacing` already expresses the role.

Radii are 8pt for inner details, 12pt for controls, 16pt for cards, 20pt for prominent media, and 28pt for hero surfaces. Pills are reserved for filters, badges, and floating navigation—not standard CTAs.

## Typography

- `MaplogFont.largeTitle`: 28pt bold, screen hero title
- `MaplogFont.screenTitle`: 22pt bold, navigation/detail title
- `MaplogFont.sectionTitle`: 20pt semibold, section heading
- `MaplogFont.cardTitle`: 17pt semibold, card title
- `MaplogFont.button`: 16pt semibold, control label
- `MaplogFont.body` / `bodyStrong`: primary reading text
- `MaplogFont.callout`: secondary metadata
- `MaplogFont.caption` / `badge`: compact labels only

Use sentence case. Keep headings short and apply no more than two text emphasis levels inside one card.

## Components

### Buttons

Use `MaplogButtonStyle` variants:

- `.primary`: one main action per surface
- `.secondary`: outlined paired action
- `.tonal`: low-emphasis contained action
- `.text`: inline or navigation action
- `.destructive`: irreversible action only
- `.brand`: authenticated provider buttons only

All controls include pressed scaling, disabled opacity, and at least a 44pt tap target. `PrimaryActionButton` is the standard full-width 52pt CTA.

### Cards

Use `.maplogCard(style:)`:

- `.photo`: image-led listing cards, no decorative shadow
- `.standard`: grouped content with a hairline and light lift
- `.elevated`: confirmations or content that must sit above the page

Do not wrap every section in a card. Let spacing group simple content.

### Other primitives

- `MaplogSectionHeader`: every scroll section heading
- `MaplogSearchButton`: navigation into search
- `MaplogFilterChip`: selectable category/filter only
- `MaplogStatusBadge`: short state text
- `MaplogIconButton`: circular icon action with accessibility label
- `MaplogToast`: transient confirmation message

## Screen rules

1. Main pages use 20pt horizontal gutters and 24–32pt section rhythm.
2. Media leads discovery cards; copy and actions follow beneath it.
3. Keep one lime focal action in a viewport. Secondary actions stay neutral.
4. Full-screen reel/map content may use dark overlays, but sheets and detail pages return to semantic surfaces.
5. Every icon-only button needs an accessibility label and a 44pt hit area.
6. New screens must use tokens and shared primitives before introducing local styles.
