# A licensed Pricedown webfont (optional)

The Grand Theft Auto wordmark is set in **Pricedown** by Ray Larabie (Typodermic Fonts), customised for each game's logo. Pricedown's free licence covers
installing it on a computer; it does **not** cover embedding it in a website, so QuickSilver does not ship it. The display face (`"QS Display"` in
`css/site.css`) therefore:

1. uses a copy of Pricedown installed on the visitor's own computer, when the browser allows it (`local("Pricedown Bl")`, `local("Pricedown")` — nothing
   is downloaded or redistributed; Safari only matches system fonts this way);
2. otherwise uses **Lilita One** (SIL OFL 1.1, `fonts/lilita-one-latin-400.woff2`), the closest legally usable face in the side-by-side comparison in
   `docs/REPORT-XXVIII.md`.

To use Pricedown for every visitor, buy a **webfont** licence from the foundry (Typodermic Fonts, or its resellers such as MyFonts) that covers this site's
traffic, put the WOFF2 file it comes with here as `fonts/licensed/pricedown.woff2`, and add it to the display face in `css/site.css`, before Lilita One:

```css
@font-face { font-family: "QS Display"; src: local("Pricedown Bl"), local("PricedownBl-Regular"), local("Pricedown"),
  url("../fonts/licensed/pricedown.woff2") format("woff2"), url("../fonts/lilita-one-latin-400.woff2") format("woff2"); … }
```

Then list it in `THIRD_PARTY_NOTICES.md` with the licence's terms. Do not add a copy downloaded from a free-font site: that copy's licence is the desktop one.
