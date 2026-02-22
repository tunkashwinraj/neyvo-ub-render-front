# Neyvo Pulse — Theme Design Reference (data only)

Design system name: **Spearia Aura** — warm, professional, for business owners.

---

## Colors

**Primary (teal)**  
- primary: #0D9488  
- primaryLight: #14B8A6  
- primaryDark: #0F766E  

**Accent (coral)**  
- accent: #EA580C  
- accentLight: #F97316  
- accentDark: #C2410C  

**Neutrals**  
- bg: #FAFAF9  
- surface: #FFFFFF  
- surfaceElevated: #FFFFFF  
- border: #E7E5E4  
- borderLight: #F5F5F4  
- bgDark: #F5F5F4  
- bgHover: #FAFAFA  

**Text**  
- textPrimary: #0F172A  
- textSecondary: #475569  
- textMuted: #94A3B8  
- textOnPrimary: #FFFFFF  
- textOnAccent: #FFFFFF  

**Semantic**  
- success: #059669  
- warning: #D97706  
- error: #E11D48  
- info: #0284C7  

**Status**  
- statusActive: #10B981  
- statusPending: #FBBF24  
- statusCancelled: #EF4444  
- statusCompleted: #6366F1  
- statusNoShow: #6B7280  

**Icons**  
- iconPrimary: #0D9488  
- iconSecondary: #64748B  
- iconMuted: #94A3B8  

**Gradients (direction → color stops)**  
- primary: top-left to bottom-right → #0D9488, #14B8A6  
- accent: top-left to bottom-right → #EA580C, #F97316  
- hero: top to bottom → #0D9488, #14B8A6, #2DD4BF  

---

## Fonts

**Heading font:** Plus Jakarta Sans (Google Fonts)  
**Body font:** DM Sans (Google Fonts)  

**Type styles**

| Style          | Font             | Size (px) | Weight |
|----------------|------------------|-----------|--------|
| displayLarge   | Plus Jakarta Sans| 32        | 700    |
| displayMedium  | Plus Jakarta Sans| 28        | 700    |
| headlineLarge  | Plus Jakarta Sans| 24        | 600    |
| headlineMedium | Plus Jakarta Sans| 20        | 600    |
| titleLarge     | Plus Jakarta Sans| 18        | 600    |
| titleMedium    | Plus Jakarta Sans| 16        | 600    |
| bodyLarge      | DM Sans          | 16        | 400    |
| bodyMedium     | DM Sans          | 14        | 400    |
| bodySmall      | DM Sans          | 12        | 400    |
| labelLarge     | DM Sans          | 14        | 600    |
| labelMedium    | DM Sans          | 12        | 600    |
| labelSmall     | DM Sans          | 11        | 500    |

Letter spacing: displayLarge -0.5, displayMedium -0.3; others default.

---

## Spacing (px, 4px base)

- xs: 4  
- sm: 8  
- md: 12  
- lg: 16  
- xl: 24  
- xxl: 32  
- xxxl: 40  
- section: 48  
- screen: 64  
- touchTarget (min tap height): 44  

---

## Border radius (px)

- sm: 8  
- md: 12  
- lg: 16  
- xl: 24  
- full: 999  

---

## Shadows (conceptual)

- Card: light, soft (e.g. blur 10, offset 0,2, black ~4% opacity); border borderLight.  
- Primary card: teal tint (~12% primary), blur 16, offset 0,4; border primary ~20%.  
- Elevated: black ~8%, blur 16, offset 0,4.  
- Glass: primary ~5%, blur 20, offset 0,10.  

---

## Component usage (what uses what)

- **Primary buttons:** primary bg, textOnPrimary, radius md, min height touchTarget.  
- **Outlined buttons:** transparent bg, primary text, border color.  
- **Cards:** surface bg, radius md, light shadow, border borderLight.  
- **Inputs:** surface bg, border, radius md; focused border primary 2px.  
- **App bar:** surface bg, no elevation, border bottom.  
- **Nav active:** primary text, primary ~8% background.  

That’s the full set of theme data used in the app.
