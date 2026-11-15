# Make the site's favicon files from assets/favicon.svg.
#
# Writes, next to the SVG:
#   favicon.ico           16, 32 and 48 px (rounded corners, transparent)
#   apple-touch-icon.png  180 px, square (iOS rounds the corners itself)
#   icon-192.png          for site.webmanifest
#   icon-512.png          for site.webmanifest
#
# Rerun after editing the SVG and commit the results; CI doesn't run this.
# magick is not part of the site's renv library, so run it with your user
# library from the project root:
#   Rscript --vanilla tools/make-favicons.R

library(magick)

svg <- readLines("assets/favicon.svg")
px <- 1024 # rasterize once, large, then scale down
density <- 72 * px / 64 # the SVG is 64 units wide

# ImageMagick renders SVG on an opaque white background, so the rounded
# corners can't come from the SVG's own transparency. Render the icon as a
# full square, then cut the corners with a mask taken from the same rect.
rasterize <- function(lines) {
  image_read(charToRaw(paste(lines, collapse = "\n")), density = density)
}
square <- rasterize(sub(' rx="14"', "", svg, fixed = TRUE))
mask <- rasterize(c(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">',
  grep("<rect width=\"64\"", svg, value = TRUE, fixed = TRUE) |>
    sub('fill="[^"]*"', 'fill="#000"', x = _),
  "</svg>"
)) |>
  image_negate() |>
  image_convert(type = "Grayscale", matte = FALSE) # CopyOpacity reads intensity only without alpha
rounded <- image_composite(square, mask, operator = "CopyOpacity")

scale_to <- function(img, size) image_strip(image_resize(img, sprintf("%dx%d!", size, size)))

ico <- image_join(lapply(c(16, 32, 48), \(s) scale_to(rounded, s)))
image_write(ico, "assets/favicon.ico", format = "ico")

image_write(scale_to(square, 180), "assets/apple-touch-icon.png", format = "png")

for (size in c(192, 512)) {
  image_write(scale_to(rounded, size), sprintf("assets/icon-%d.png", size), format = "png")
}

message("Wrote favicon.ico, apple-touch-icon.png, icon-192.png, icon-512.png to assets/")
