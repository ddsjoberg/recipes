--[[
Recipe page enhancements. Runs only on posts/<slug>/index.qmd and works on the
existing Markdown, so posts need no special syntax:

* Ingredient bullets (under "## Ingredients") become checkboxes, so you can
  tick things off while gathering. Styling is pure CSS (:has(:checked)).
* Direction steps (under "## Directions") get a numbered "current step" radio
  button, so you can keep your place at the stove.
* If the post sets `image:` in front matter, that photo is shown at the top as
  the hero image (high fetch priority) and its duplicate in the body is removed.
* Images get alt text when it is empty, lazy loading, async decoding, and
  intrinsic width/height to stop layout shift.
* A scale picker (½×, 1×, 2×, 3×) is added; assets/scale.js rewrites the
  ingredient amounts.
* A "Keep screen on" switch is added (enabled by assets/head.html when the
  browser supports the Screen Wake Lock API).
]]

local stringify = pandoc.utils.stringify

local function input_file()
  return (quarto.doc.input_file or ""):gsub("\\", "/")
end

local function is_post()
  return input_file():match("/posts/[^/]+/index%.qmd$") ~= nil
end

local function html_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- Intrinsic size of a local image, or nil.
local function image_size(src)
  if src:match("^%a+:") or src:match("^/") then return nil end
  local path = pandoc.path.join({ pandoc.path.directory(input_file()), src })
  local fh = io.open(path, "rb")
  if not fh then return nil end
  local data = fh:read("a")
  fh:close()
  local ok, size = pcall(pandoc.image.size, data)
  if ok and size and size.width and size.height then return size end
  return nil
end

local function only_image(blk)
  if blk.t ~= "Para" and blk.t ~= "Plain" then return nil end
  local img
  for _, el in ipairs(blk.content) do
    if el.t == "Image" and not img then
      img = el
    elseif el.t ~= "Space" and el.t ~= "SoftBreak" and el.t ~= "LineBreak" then
      return nil
    end
  end
  return img
end

local function checkbox_items(list)
  for _, item in ipairs(list.content) do
    local first = item[1]
    if first and (first.t == "Plain" or first.t == "Para") and #first.content > 0 then
      first.content:insert(1, pandoc.RawInline("html",
        '<label class="ingredient"><input type="checkbox"><span>'))
      first.content:insert(pandoc.RawInline("html", "</span></label>"))
    end
  end
  return list
end

local function step_items(list)
  local start = (list.listAttributes and list.listAttributes.start) or list.start or 1
  for i, item in ipairs(list.content) do
    local n = start + i - 1
    local marker = pandoc.RawInline("html", string.format(
      '<label class="step-marker"><input type="radio" name="current-step" ' ..
      'aria-label="Mark step %d as the current step"><span aria-hidden="true">%d</span></label>',
      n, n))
    local first = item[1]
    if first and (first.t == "Plain" or first.t == "Para") then
      first.content:insert(1, marker)
    else
      item:insert(1, pandoc.Plain({ marker }))
    end
  end
  return list
end

function Pandoc(doc)
  if not is_post() then return nil end

  local title = stringify(doc.meta.title or "")
  local hero = doc.meta.image and stringify(doc.meta.image) or nil
  if hero == "" then hero = nil end

  local out = pandoc.List()
  local section = nil

  for _, blk in ipairs(doc.blocks) do
    local keep = true
    if blk.t == "Header" and blk.level <= 2 then
      section = stringify(blk.content):lower()
    end

    -- Drop the body copy of the hero photo; it is shown at the top instead.
    local img = only_image(blk)
    if hero and img and img.src == hero then keep = false end

    if keep and section == "ingredients" then
      blk = pandoc.walk_block(pandoc.Div({ blk }), {
        BulletList = function(l)
          return checkbox_items(l)
        end,
      }).content[1]
    elseif keep and section == "directions" then
      blk = pandoc.walk_block(pandoc.Div({ blk }), { OrderedList = step_items }).content[1]
    end

    if keep then out:insert(blk) end

    -- Cooking tools, first thing in the Ingredients section (only under the
    -- "## Ingredients" heading itself, not its subheadings): the scale picker
    -- (assets/scale.js) and the "Keep screen on" switch (assets/head.html).
    -- Both stay hidden until their script enables them.
    if blk.t == "Header" and blk.level <= 2 and section == "ingredients" then
      out:insert(pandoc.RawBlock("html", table.concat({
        '<div class="recipe-tools">',
        '<fieldset class="recipe-scale" hidden>',
        '<legend>Scale</legend>',
        '<label><input type="radio" name="recipe-scale" value="0.5"><span>½×</span></label>',
        '<label><input type="radio" name="recipe-scale" value="1" checked><span>1×</span></label>',
        '<label><input type="radio" name="recipe-scale" value="2"><span>2×</span></label>',
        '<label><input type="radio" name="recipe-scale" value="3"><span>3×</span></label>',
        '</fieldset>',
        '<label class="wake-lock" hidden><input type="checkbox" switch role="switch"> Keep screen on</label>',
        '</div>',
      }, "\n")))
    end
  end

  -- Alt text, lazy loading and intrinsic size for body images.
  out = pandoc.List(pandoc.walk_block(pandoc.Div(out), {
    Image = function(im)
      if #im.caption == 0 then
        local alt = im.src:match("^source") and ("Original recipe card for " .. title) or title
        im.caption = { pandoc.Str(alt) }
      end
      im.attributes.loading = im.attributes.loading or "lazy"
      im.attributes.decoding = "async"
      if not im.attributes.width and not im.attributes.height then
        local size = image_size(im.src)
        if size then
          im.attributes.width = tostring(size.width)
          im.attributes.height = tostring(size.height)
        end
      end
      return im
    end,
  }).content)

  local top = pandoc.List()
  if hero then
    local size = image_size(hero)
    local dims = size and string.format(' width="%d" height="%d"', size.width, size.height) or ""
    top:insert(pandoc.RawBlock("html", string.format(
      '<img class="recipe-hero" src="%s" alt="%s"%s fetchpriority="high" decoding="async">',
      html_escape(hero), html_escape(title), dims)))
  end

  doc.blocks = top .. out
  return doc
end
