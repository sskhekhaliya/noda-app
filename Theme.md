# Noda App - UI Theme Specification

Based on the logo's visual identity, this theme extracts the core gradient colors (deep ocean blue and vibrant teal) and the dark slate typography to create a cohesive Light and Dark mode. 

The design language should feel **fluid, academic, and modern**, aligning with the "infinite hierarchy" and "seamless feed" concepts of the app.

---

## 🎨 Color Palette Extracted from Logo

* **Primary Deep Blue:** `#1D4A7A` (Bottom-left curve of the logo nodes)
* **Primary Teal/Green:** `#2D8A68` (Top-right curve of the logo nodes)
* **Brand Gradient:** `linear-gradient(135deg, #1D4A7A 0%, #2D8A68 100%)`
* **Logo Text (Slate):** `#353B40`

---

## ☀️ Light Theme
The light theme uses a clean, airy, "icy" background to make the rich gradient nodes pop, mimicking the exact background of your logo image.

### Base Colors
| Role | Hex | Usage |
| :--- | :--- | :--- |
| **Background** | `#F4F9F9` | Main app background (Feed, Hierarchy canvas) |
| **Surface** | `#FFFFFF` | Note cards, modals, dropdown menus |
| **Surface Alt** | `#E8F0F0` | Search bars, inactive UI elements, hovered rows |

### Typography & Icons
| Role | Hex | Usage |
| :--- | :--- | :--- |
| **Text Primary** | `#353B40` | Main note content, Main Topic titles (Matches logo text) |
| **Text Secondary** | `#64748B` | Subtopic titles, dates, breadcrumbs |
| **Icons (Active)** | `#2D8A68` | Active tabs, selected buttons |
| **Icons (Inactive)**| `#94A3B8` | Unselected menu items |

### Accents & Interactions
| Role | Hex | Usage |
| :--- | :--- | :--- |
| **Primary Action** | `#1D4A7A` | Master Play button, Save buttons |
| **Secondary Action**| `#2D8A68` | Shuffle button, "Create Sub-note" action |
| **Focus/Ring** | `#7CB8A0` | Keyboard focus states, active text inputs |
| **Dividers** | `#DCE4E4` | Lines between feed cards, hierarchy borders |

---

## 🌙 Dark Theme
The dark theme flips the slate text color to the background, creating a deep, focused environment for late-night studying. The primary colors are slightly lightened/desaturated to maintain accessible contrast.

### Base Colors
| Role | Hex | Usage |
| :--- | :--- | :--- |
| **Background** | `#121619` | Main app background (Deep contrast for OLEDs) |
| **Surface** | `#1C2227` | Note cards, modals, bottom sheets |
| **Surface Alt** | `#272F35` | Search bars, selected hierarchy items |

### Typography & Icons
| Role | Hex | Usage |
| :--- | :--- | :--- |
| **Text Primary** | `#E2E8F0` | Main note content, Main Topic titles |
| **Text Secondary** | `#94A3B8` | Subtopic titles, dates, breadcrumbs |
| **Icons (Active)** | `#48B58F` | Active tabs, selected buttons |
| **Icons (Inactive)**| `#64748B` | Unselected menu items |

### Accents & Interactions
| Role | Hex | Usage |
| :--- | :--- | :--- |
| **Primary Action** | `#3A78BE` | Master Play button, Save buttons (Lightened Blue) |
| **Secondary Action**| `#48B58F` | Shuffle button, "Create Sub-note" action (Lightened Teal) |
| **Brand Gradient** | `linear-gradient(135deg, #3A78BE 0%, #48B58F 100%)` | Premium features, App Header, Splash Screen |
| **Dividers** | `#2D373D` | Lines between feed cards, hierarchy borders |

---

## 📐 Typography Recommendations
To match the bold, clean, geometric sans-serif font of the "NODA" logo, consider the following font families for the app UI:

1.  **Montserrat** (Closest match to the logo's strong, wide geometry)
2.  **Inter** (Excellent for dense UI reading and nested notes)
3.  **Plus Jakarta Sans** (Modern, highly legible for learning apps)

---

## 💻 CSS Variables (Implementation Ready)

```css
/* LIGHT THEME */
:root {
  --bg-main: #F4F9F9;
  --bg-surface: #FFFFFF;
  --bg-surface-alt: #E8F0F0;
  
  --text-primary: #353B40;
  --text-secondary: #64748B;
  
  --brand-blue: #1D4A7A;
  --brand-teal: #2D8A68;
  --brand-gradient: linear-gradient(135deg, var(--brand-blue) 0%, var(--brand-teal) 100%);
  
  --border-color: #DCE4E4;
}

/* DARK THEME */
[data-theme="dark"] {
  --bg-main: #121619;
  --bg-surface: #1C2227;
  --bg-surface-alt: #272F35;
  
  --text-primary: #E2E8F0;
  --text-secondary: #94A3B8;
  
  --brand-blue: #3A78BE; /* Adjusted for dark mode contrast */
  --brand-teal: #48B58F; /* Adjusted for dark mode contrast */
  --brand-gradient: linear-gradient(135deg, var(--brand-blue) 0%, var(--brand-teal) 100%);
  
  --border-color: #2D373D;
}