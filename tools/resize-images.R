# Make web-sized copies of large recipe photos. The originals are kept.
#
# For every image in posts/*/ that is bigger than 300 KB, this writes
# <name>-1600.webp next to it: auto-rotated, at most 1600px on the long
# edge, quality 80, with metadata (including phone GPS data) removed.
# Point the post at the -1600.webp copy. Quarto only deploys files that a
# page references, so the originals stay in the repo but are not published.
#
# magick is not part of the site's renv library, because CI doesn't need it.
# Run it with your user library from the project root:
#   Rscript --vanilla tools/resize-images.R

library(magick)

files <- list.files(
  "posts",
  pattern = "[.](jpe?g|png|jfif)([.]crdownload)?$",
  ignore.case = TRUE, recursive = TRUE, full.names = TRUE
)
files <- files[file.size(files) > 300 * 1024]

for (f in files) {
  base <- sub("[.]crdownload$", "", f)
  out <- paste0(tools::file_path_sans_ext(base), "-1600.webp")
  if (file.exists(out)) next
  img <- image_read(f) |>
    image_orient() |>
    image_resize("1600x1600>") |>
    image_strip()
  image_write(img, out, format = "webp", quality = 80)
  message(sprintf("%-70s %6.0f KB -> %4.0f KB", out,
                  file.size(f) / 1024, file.size(out) / 1024))
}
