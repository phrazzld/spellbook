# UI Rules — Battle-Tested Gotchas

Quick-lookup reference: 152 severity-tagged rules across 12 categories.
Some rules overlap with detailed references (motion-craft.md, mobile-excellence.md,
implementation-constraints.md) — this file is the triage view, those are deep dives.

## Severity Guide

- **CRITICAL** — Breaks UX, causes user confusion or data loss
- **HIGH** — Noticeable degradation, professional vs amateur signal
- **MEDIUM** — Polish item, compounds with other issues
- **LOW** — Refinement, matters at scale

---

## 1. Animation & Motion

### Easing

**CRITICAL: Gesture-driven motion needs springs, not easing curves.**
Easing curves (cubic-bezier) have fixed duration — they can't respond to velocity.
When the user flicks, swipes, or drags, the animation must inherit the gesture's
momentum. Springs do this naturally; easing curves create a jarring disconnect.

```css
/* WRONG: Easing for gesture-driven motion */
transition: transform 300ms ease-out;

/* RIGHT: Spring physics */
/* Use framer-motion spring, react-spring, or CSS spring() when available */
```

**HIGH: Exit animations must mirror entry state, not play entry in reverse.**
If an element slides in from the left, it should slide out to the left (back where
it came from), not slide out to the right. Reverse playback looks like a VHS rewind.

**HIGH: Stagger delays must be short (30-50ms) and total duration capped.**
Long staggers (>80ms per item) on lists with 20+ items means the last item appears
2+ seconds later. Cap total stagger duration at ~400ms regardless of item count.

**MEDIUM: Never animate `width`, `height`, `top`, `left`.** Use `transform` and
`opacity` only. Layout-triggering properties cause reflow on every frame.

**MEDIUM: Reduced motion preference must disable motion, not duration.**
`prefers-reduced-motion` should remove animations entirely or replace with
opacity fades. Setting `duration: 0` causes visual glitches (flash of final state).

```css
@media (prefers-reduced-motion: reduce) {
  /* WRONG */
  * { animation-duration: 0s !important; }

  /* RIGHT */
  * { animation: none !important; transition: none !important; }
}
```

### Springs

**HIGH: Spring `stiffness` and `damping` must be tuned together.**
High stiffness + low damping = oscillation (bouncy). Low stiffness + high damping = sluggish.
Reasonable defaults: stiffness 100-300, damping 15-30.

**MEDIUM: Springs with `mass` > 1 feel heavy.** Use mass for deliberate "weighty"
interactions (dragging large objects). Default mass should be 1 for most UI.

**MEDIUM: Avoid `bounce` parameter shortcuts.** They hide the physics. Explicit
`stiffness`/`damping`/`mass` lets you reason about behavior.

### Container Animation

**CRITICAL: Container animation needs two-div pattern (outer animated, inner counter-animated).**
When animating a container's size, the content inside distorts (text squishes, images
stretch). Fix: animate the outer div, counter-animate the inner div to maintain
its natural dimensions.

```jsx
// WRONG: Content distorts during animation
<motion.div animate={{ scaleX: expanded ? 1 : 0.5 }}>
  <Content /> {/* Text and images squish */}
</motion.div>

// RIGHT: Two-div pattern
<motion.div animate={{ scaleX: expanded ? 1 : 0.5 }}>
  <motion.div animate={{ scaleX: expanded ? 1 : 2 }}> {/* Counter-scale */}
    <Content /> {/* Stays crisp */}
  </motion.div>
</motion.div>
```

**HIGH: Layout animations must use `layout` prop, not manual width/height.**
Framer Motion's `layout` prop handles FLIP animation automatically. Manual
width/height animation triggers reflow.

### Scroll Animation

**HIGH: Scroll-linked animations must use `scroll-timeline` or Intersection Observer, not scroll event listeners.**
Scroll event listeners fire on the main thread and cause jank. CSS `scroll-timeline`
or `IntersectionObserver` with thresholds are off-main-thread.

**MEDIUM: Parallax must be subtle (0.1-0.3x scroll speed difference).** Aggressive
parallax (0.5x+) causes motion sickness and makes content hard to read.

---

## 2. Typography

**CRITICAL: Use `tabular-nums` for data columns.**
Without it, numbers with different digit widths (1 vs 4) cause columns to jitter
when values change. Prices, counts, percentages — anything in a table or that updates.

```css
.data-value { font-variant-numeric: tabular-nums; }
```

**CRITICAL: Use `text-wrap: balance` for headings.**
Prevents orphaned words (single word on last line). Supported in all modern browsers.

```css
h1, h2, h3 { text-wrap: balance; }
```

**HIGH: Line length must be 45-75 characters for body text.** Longer lines cause
eye tracking fatigue. Use `max-width: 65ch` on text containers.

**HIGH: Don't use viewport units for font size without clamp.**
`font-size: 5vw` is unreadable on mobile and absurdly large on ultrawide.

```css
/* WRONG */
font-size: 5vw;

/* RIGHT */
font-size: clamp(1rem, 2.5vw + 0.5rem, 3rem);
```

**MEDIUM: System font stack for body, display font for headings only.**
Loading a custom font for body text adds 100-300ms of layout shift (FOIT/FOUT).
System fonts for body are instant and readable.

**MEDIUM: `font-display: swap` for custom fonts.** Prevents invisible text during
font load. Accept the brief FOUT (flash of unstyled text) over FOIT (flash of
invisible text).

**MEDIUM: Leading (line-height) must increase with line length.** Short lines
(mobile): 1.4-1.5. Long lines (desktop): 1.6-1.8.

**LOW: Hyphenation for justified text.** If you must use `text-align: justify`
(generally avoid), enable `hyphens: auto` to prevent rivers of whitespace.

---

## 3. Color

**CRITICAL: Never use pure black (#000000) on pure white (#FFFFFF).**
The extreme contrast causes halation (text appears to vibrate). Use off-black
(`#1a1a1a`, `zinc-950`) on off-white (`#fafafa`, `zinc-50`).

**HIGH: OKLCH for color systems, not HSL.**
HSL's "lightness" is perceptually non-uniform — 50% lightness yellow looks much
brighter than 50% lightness blue. OKLCH fixes this. All colors at the same L value
actually look equally bright.

```css
/* HSL: "same lightness" but visually different brightness */
--blue: hsl(220, 80%, 50%);   /* Looks dark */
--yellow: hsl(50, 80%, 50%);  /* Looks bright */

/* OKLCH: actually perceptually uniform */
--blue: oklch(0.6 0.2 250);
--yellow: oklch(0.6 0.2 90);
```

**HIGH: Brand-tinted neutrals over pure grays.** Add chroma 0.005-0.02 at your
brand hue to neutral grays. Creates cohesion without being noticeable.

**HIGH: Color contrast 4.5:1 minimum for text (WCAG AA).** 3:1 for large text
(>18pt). Use `oklch` lightness channel to guarantee contrast ratios.

**MEDIUM: Dark mode is not "invert colors."** Reduce contrast slightly (surfaces
at 10-15% lightness, not 0%), reduce saturation, use the same brand hue with
adjusted lightness.

**MEDIUM: Semantic color tokens, not palette references.** `--color-danger` not
`--color-red-500`. Semantics survive theme changes; palette references don't.

**LOW: Don't rely on color alone for state.** Always pair with icon, text, or
pattern. 8% of men have color vision deficiency.

---

## 4. Layout

**CRITICAL: Use `min-h-[100dvh]` not `h-screen` for full-height layouts.**
`h-screen` (100vh) doesn't account for mobile browser chrome (address bar, toolbar).
`100dvh` does.

**HIGH: CSS Grid for 2D layouts, Flexbox for 1D.** Grid for page structure,
card grids, dashboards. Flexbox for nav bars, button groups, inline elements.
Don't use Flexbox math (`calc(33.33% - 1rem)`) when Grid does it automatically.

**HIGH: Container queries over media queries for components.** Components don't
know what page they'll be on. `@container` lets them adapt to their parent's
size, not the viewport.

**MEDIUM: `gap` over margin for spacing between siblings.** Margin causes
double-spacing issues, needs `:last-child` overrides, and doesn't work consistently
in both directions.

**MEDIUM: `auto-fill` vs `auto-fit` in grid matters.** `auto-fill` creates empty
tracks (maintains column width). `auto-fit` collapses empty tracks (items stretch).
Use `auto-fill` for card grids, `auto-fit` for fluid layouts.

**LOW: Logical properties over physical.** `margin-inline-start` not `margin-left`
for RTL support.

---

## 5. Interaction

**CRITICAL: Touch targets must be 44x44px minimum (WCAG).** The visual element can
be smaller, but the clickable area must be at least 44x44. Use padding, not just
the element's dimensions.

```css
/* Visual is 24px icon, but touch target is 44px */
.icon-button {
  width: 24px; height: 24px;
  padding: 10px;
  /* Total: 44x44 */
}
```

**HIGH: Hover states must not cause layout shift.** Adding borders, changing padding,
or swapping content on hover pushes surrounding elements. Use `outline`, `box-shadow`,
`transform: scale()`, or opacity changes instead.

**HIGH: Focus styles must be visible.** Default browser focus rings are fine. If you
customize, ensure 3:1 contrast against adjacent colors. Never `outline: none` without
a replacement.

**HIGH: Disabled buttons should explain why.** A grayed-out button with no tooltip
or helper text is a dead end. Show what's missing: "Complete all required fields"
or a tooltip on hover.

**MEDIUM: Click feedback must be < 100ms.** If the action takes longer, show
immediate visual feedback (button state change, loading indicator) within 100ms.
After 400ms, show a progress indicator.

**MEDIUM: Scroll position preservation on navigation.** When navigating back,
restore scroll position. When navigating forward to a list, scroll to top.

**LOW: Double-click protection on forms.** Disable submit button after first click
or debounce. Double submissions cause duplicate records.

---

## 6. Audio & Media

**HIGH: Audio must have a visual equivalent.** Every sound effect needs a
corresponding visual indicator. Not all users can hear; not all environments
allow sound.

**HIGH: Never autoplay audio.** Browsers block it anyway, and it's hostile UX.
Video autoplay is acceptable only when muted.

**MEDIUM: Loading states for media.** Images, videos, and iframes need placeholder/
skeleton states. `aspect-ratio` prevents layout shift during load.

```css
.video-container {
  aspect-ratio: 16/9;
  background: var(--color-surface-secondary);
}
```

**MEDIUM: `loading="lazy"` for below-fold images.** But NOT for above-fold hero
images or LCP candidates — those should be `loading="eager"` with `fetchpriority="high"`.

---

## 7. Forms

**CRITICAL: Label every input.** `<label for="...">` or `aria-label`. Placeholder
text is not a label — it disappears when the user starts typing.

**HIGH: Inline validation on blur, not on every keystroke.** Keystroke validation
shows errors before the user finishes typing. Validate on blur (leaving the field)
or on submit.

**HIGH: Error messages next to the field, not at the top of the form.** Users
shouldn't have to map "Field X is invalid" to the field's location.

**MEDIUM: Show password requirements BEFORE validation fails.** Don't make users
guess the rules, then tell them they guessed wrong.

**MEDIUM: Autofill-friendly markup.** Use `autocomplete` attributes: `name`,
`email`, `tel`, `street-address`, `cc-number`. Saves users from retyping.

**LOW: `inputmode` for mobile keyboards.** `inputmode="numeric"` for phone
numbers, ZIP codes. `inputmode="email"` for email fields. `type="tel"` for
phone numbers.

---

## 8. Loading & Empty States

**HIGH: Skeleton screens over spinners for known layouts.** Skeletons show
structure, reducing perceived wait time. Spinners communicate "something is
happening" but give no spatial context.

**HIGH: Empty states must have a call to action.** "No results" is not enough.
"No results — try adjusting your filters" or "No projects yet — Create your first"

**MEDIUM: Optimistic updates for low-risk actions.** Like/unlike, toggle, reorder.
Show the result immediately, revert on failure. Don't make users wait for a
round-trip on a toggle.

**MEDIUM: Error states must offer recovery.** "Something went wrong" with no
action is a dead end. Always offer: retry, go back, contact support.

---

## 9. Responsive Design

**HIGH: Test at 375px, 768px, 1024px, 1440px.** These cover iPhone SE,
iPad portrait, iPad landscape/small laptop, desktop.

**HIGH: Horizontal scroll is almost always a bug.** If content overflows
horizontally, something is wrong. Exceptions: code blocks, tables, carousels.

**MEDIUM: Navigation must collapse to mobile menu at the right breakpoint.**
Not too early (wastes desktop space) or too late (items overflow on tablet).
Test with actual nav items, not 3-item placeholder.

**MEDIUM: Images must use `srcset` and `sizes`.** Serving a 2000px image to
a 375px phone wastes bandwidth and slows load.

---

## 10. Performance Perception

**HIGH: Instant navigation over loading screens.** Use `<Link prefetch>`,
route pre-fetching, or streaming SSR. The fastest loading screen is no
loading screen.

**HIGH: Above-fold content must render without JavaScript.** SSR/SSG the
initial view. JS enhances; it shouldn't be required for first paint.

**MEDIUM: Debounce search input (200-300ms).** Searching on every keystroke
hammers the API and shows irrelevant intermediate results.

**MEDIUM: Virtual scrolling for lists > 100 items.** Rendering 1000 DOM nodes
causes jank. Use `react-virtual`, `tanstack-virtual`, or CSS `content-visibility`.

---

## 11. Accessibility Beyond Contrast

**CRITICAL: Modals must trap focus.** Tab should cycle within the modal, not
escape to background content. Escape key should close. Focus should return to
trigger on close.

**HIGH: Announce dynamic content changes.** Toast notifications, live updates,
error messages that appear — use `aria-live="polite"` or `role="alert"`.

**HIGH: Skip navigation link.** First focusable element should be "Skip to
main content" for keyboard users.

**MEDIUM: Meaningful alt text, not filenames.** `alt="Dashboard showing revenue
trend for Q4"` not `alt="dashboard-screenshot-2024.png"`.

**LOW: Respect `prefers-contrast: more`.** Increase border visibility, reduce
transparency, strengthen text contrast.

---

## 12. UX Laws — When Violations Matter

**Fitts's Law:** Target size and distance matter. Far-away small buttons are
slow to reach. Place primary actions near the user's current focus.

**Hick's Law:** More choices = more decision time. Long dropdowns, many nav
items, feature-heavy dashboards — reduce or chunk.

**Miller's Law:** Working memory holds ~7 items. Group related items.
Step indicators, breadcrumbs, and progressive disclosure help.

**Doherty Threshold:** Responses under 400ms feel instant. Above 400ms, users
perceive a wait. Above 1000ms, they lose focus.

**Jakob's Law:** Users expect your site to work like other sites they know.
Don't reinvent navigation, checkout, or settings patterns.

**Aesthetic-Usability Effect:** Beautiful interfaces are perceived as more
usable (even when they aren't). Design quality IS a UX feature.

**Peak-End Rule:** Users judge experiences by the peak moment and the ending.
Nail the core interaction and the completion/success state.
