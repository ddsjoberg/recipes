# Sjochengberg Recipes

Our family recipe site, built with [Quarto](https://quarto.org) and published
to GitHub Pages at <https://ddsjoberg.github.io/recipes/>.

## Adding a new recipe

### 1. Create the post folder

Each recipe lives in its own folder under `posts/`. The folder name becomes the
URL, so use lowercase words joined by hyphens:

```
posts/
  garlic-noodles/
    index.qmd        <- the recipe
    noodles.jpg      <- optional photos
```

### 2. Write `index.qmd`

Copy this template and fill it in:

```markdown
---
title: "Garlic Noodles"
date: "2026-11-14"
categories: [dinner, pasta]
image: noodles-1600.webp
---

A sentence or two about the dish and where it came from.
Adapted from [Some Site](https://example.com).

## Ingredients

- 1 pound spaghetti
- 6 cloves garlic, minced
- 2 tablespoons butter

## Directions

1. Boil the noodles until al dente.
1. Melt the butter and cook the garlic until fragrant.
1. Toss everything together and serve.

## Notes

Anything you'd change next time.
```

**Front matter**

| Field        | Required | Notes |
|--------------|----------|-------|
| `title`      | yes      | Shown on the card and page. |
| `date`       | yes      | `YYYY-MM-DD`. The home page is sorted newest first. |
| `categories` | no       | Reuse existing ones where you can (e.g. `chicken`, `soup`, `dessert`, `cheng`, `sjoberg`, `avi`). They become filters on the home page. |
| `image`      | no       | The photo for the home page card and the top of the recipe page. If left out, the card uses the first image in the post, or a lettered placeholder if there is none. |

**Section names matter.** The site adds cooking features based on two headings,
so keep them spelled exactly like this:

- `## Ingredients` — every bullet (`-`) becomes a checkbox you can tick off.
  Subheadings like `#### Sauce` are fine for grouping.
- `## Directions` — every numbered step (`1.`) gets a tappable step number to
  mark where you are.

Other sections (`## Notes`, `## Source`, `## Background`) are shown as normal
text. `## Source` is left off when the recipe is printed.

### 3. Add photos

Phone photos are several MB each, so make a web-sized copy before using them:

1. Drop the original photo into the post folder.
2. From the project root, run:

   ```bash
   Rscript --vanilla tools/resize-images.R
   ```

   For every image over 300 KB, this writes `<name>-1600.webp` next to it
   (resized, rotated correctly, and with location data removed). It skips
   photos that already have a copy. It needs the `magick` R package in your
   regular R library (`install.packages("magick")`).

3. Use the `-1600.webp` file in the post, both in `image:` and in the body:

   ```markdown
   ![](noodles-1600.webp)
   ```

The original stays in the repo but isn't published, because Quarto only copies
files a page actually links to. Small images, like a screenshot of the source
recipe, can be used as-is. Alt text is filled in from the recipe title when
you leave the brackets empty.

### 4. Preview locally

```bash
quarto preview
```

This opens the site in your browser and reloads as you edit. (In RStudio or
Positron you can also use the **Render** / **Preview** button.)

### 5. Publish

Commit the new folder and push to `main`:

```bash
git add posts/garlic-noodles
git commit -m "Add garlic noodles"
git push
```

The GitHub Actions workflow renders the site and publishes it to the
`gh-pages` branch. It usually takes a few minutes. Don't commit `_site/`; it's
built automatically.

## How the site is put together

| File | What it does |
|------|--------------|
| `_quarto.yml` | Site settings, themes, and where the files below are hooked in. |
| `index.qmd` + `_listing-cards.ejs` | Home page and its recipe card grid. |
| `posts/_metadata.yml` | Settings shared by every recipe. |
| `_filters/recipe.lua` | Turns ingredients into checkboxes, adds step markers, the hero photo, and image alt text. |
| `assets/recipes.css` | Site styles: colors, cards, recipe layout, print. |
| `assets/head.html` | Page transitions, link prerendering, and the "Keep screen on" switch. |
| `styles.scss`, `styles-dark.scss` | Bootstrap theme settings for light and dark mode. |
| `tools/resize-images.R` | Makes web-sized photo copies. |
