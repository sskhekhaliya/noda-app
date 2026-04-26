# Design System Specification

## 1. Overview & Creative North Star: "The Digital Sanctuary"

This design system is built to transform the often-stressful act of studying into a moment of calm, focused immersion. Our Creative North Star is **"The Digital Sanctuary."** 

Unlike generic productivity tools that use rigid grids and aggressive primary colors, this system prioritizes cognitive ease through an editorial-inspired layout. We break the "template" look by utilizing intentional asymmetry—placing content off-center to create breathing room—and overlapping elements that suggest a fluid, interconnected flow of information. The experience should feel less like a software interface and more like a high-end digital journal where the UI recedes, leaving only the student and their knowledge.

## 2. Colors & Signature Tones

The palette is derived from the "Ocean-to-Teal" gradient of the logo, optimized for two distinct emotional states: the crisp, alert "Icy Light" and the deep, immersive "Deep Slate Dark."

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders for sectioning or containment. Structural boundaries must be defined exclusively through background color shifts. 
- Use `surface-container-low` (#f0f4f8) to sit on a `surface` (#f6fafe) background.
- This creates "soft boundaries" that reduce visual noise and study anxiety.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers, much like stacked sheets of frosted glass.
- **Base:** `surface` (#f6fafe)
- **Secondary Sectioning:** `surface-container` (#eaeef2)
- **Interactive Cards:** `surface-container-lowest` (#ffffff) to provide the highest "lift."

### Signature Textures & Glassmorphism
- **CTAs & Heroes:** Use a linear gradient from `primary` (#004f56) to `primary-container` (#006972) at a 135-degree angle. This provides a "soulful" depth that flat hex codes cannot replicate.
- **Glassmorphism:** For floating navigation or modal overlays, use `surface-container-lowest` with an 80% opacity and a `24px` backdrop-blur. This ensures the ocean-teal tones bleed through the interface, maintaining a sense of place.

## 3. Typography: Editorial Clarity

We utilize **Manrope** for its geometric yet warm characteristics. The hierarchy is designed to be "Editorial Heavy," using dramatic scale shifts to guide the eye without needing bold divider lines.

| Level | Size | Weight | Role |
| :--- | :--- | :--- | :--- |
| **Display-LG** | 3.5rem | 700 | Large, inspirational milestones. |
| **Headline-LG** | 2rem | 600 | Chapter headings / Subject titles. |
| **Title-MD** | 1.125rem | 600 | Card titles and section navigation. |
| **Body-LG** | 1rem | 400 | Primary study content; high readability. |
| **Label-MD** | 0.75rem | 500 | Metadata, tags, and small utility text. |

**Identity Note:** Headlines should use a tighter letter-spacing (-0.02em) to feel authoritative, while Body text should remain at 0em to maximize legibility during long study sessions.

## 4. Elevation & Depth: Tonal Layering

Traditional drop shadows are often too harsh for a "sanctuary" aesthetic. Instead, we use **Tonal Layering.**

*   **The Layering Principle:** Depth is achieved by stacking. A card component should be `surface-container-lowest` (white) placed on a `surface-container-low` background. The color difference *is* the shadow.
*   **Ambient Shadows:** Where a physical float is required (e.g., a floating action button), use a diffused shadow: `0px 8px 24px rgba(23, 28, 31, 0.06)`. The tint is derived from `on-surface` (#171c1f) to feel like natural light.
*   **The "Ghost Border" Fallback:** If accessibility requires a border, use `outline-variant` (#bec8ca) at **15% opacity**. Never use a 100% opaque border.
*   **Roundedness:** Following the provided scale, the standard card uses `xl` (1.5rem) to ensure a friendly, approachable feel that mitigates the "sharpness" of study pressure.

## 5. Components

### Buttons
*   **Primary:** Gradient fill (`primary` to `primary-container`), white text, `full` (pill) roundedness. 
*   **Secondary:** `secondary-container` (#afddfe) background with `on-secondary-container` (#34627e) text. No border.
*   **Tertiary:** Transparent background with `primary` text. Use for low-emphasis actions.

### Cards & Lists
*   **Constraint:** Zero dividers. Separate list items using `12px` of vertical white space or by alternating background tones between `surface` and `surface-container-low`.
*   **Fluidity:** Cards should utilize `lg` (1rem) or `xl` (1.5rem) corners to mirror the organic loops found in the Noda logo.

### Input Fields
*   **State:** Use `surface-container-high` (#e4e9ed) as the fill.
*   **Active:** Transition the background to `surface-container-lowest` and add a subtle `primary` (teal) ghost border (20% opacity).

### App-Specific Components
*   **Focus Timer:** A large `display-lg` readout using a circular "Glassmorphism" container with a soft `primary-fixed` (#a1eff9) glow.
*   **Study Nodes:** Small, circular selection chips with `full` roundedness, using `secondary-fixed` (#c7e7ff) to represent different subjects.

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical margins. Leave more "white space" on the left of headlines to create an editorial feel.
*   **Do** use the `primary` to `secondary` gradient for progress bars to symbolize the "flow" of learning.
*   **Do** ensure text contrast meets WCAG AA standards, especially in the "Deep Slate Dark" mode using `on-surface` tones.

### Don't
*   **Don't** use black (#000000) for text. Use `on-background` (#171c1f) to keep the contrast soft on the eyes.
*   **Don't** use standard 4px or 8px "Default" corners. Always lean toward the `xl` (1.5rem) values for a premium, modern feel.
*   **Don't** use "Alert Red" for errors unless critical. Use `error-container` (#ffdad6) for a softer, less anxiety-inducing warning.