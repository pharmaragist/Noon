return {
  -- base
  bg = "{{colors.surface.default.hex}}",
  bg_alt = "{{colors.surface_container.default.hex}}",
  bg_dim = "{{colors.surface_container_low.default.hex}}",
  bg_sel = "{{colors.surface_container_high.default.hex}}",
  bg_float = "{{colors.surface_container_low.default.hex}}",
  fg = "{{colors.on_surface.default.hex}}",
  fg_dim = "{{colors.on_surface_variant.default.hex}}",
  border = "{{colors.outline_variant.default.hex}}",

  -- accents
  accent = "{{colors.primary.default.hex}}",
  accent_fg = "{{colors.on_primary.default.hex}}",
  accent_dim = "{{colors.primary_container.default.hex}}",
  accent_dim_fg = "{{colors.on_primary_container.default.hex}}",
  accent_alt = "{{colors.secondary.default.hex}}",
  accent_alt_fg = "{{colors.on_secondary.default.hex}}",
  tertiary = "{{colors.tertiary.default.hex}}",
  tertiary_fg = "{{colors.on_tertiary.default.hex}}",

  -- semantic
  error = "{{colors.error.default.hex}}",
  error_fg = "{{colors.on_error.default.hex}}",
  warn = "{{colors.tertiary.default.hex}}",
  warn_fg = "{{colors.on_tertiary.default.hex}}",
  info = "{{colors.secondary.default.hex}}",
  info_fg = "{{colors.on_secondary.default.hex}}",
  hint = "{{colors.outline.default.hex}}",
  ok = "{{colors.primary.default.hex}}",

  -- git/diff (tinted from Material roles)
  git_add = "{{colors.primary.default.hex}}",
  git_change = "{{colors.secondary.default.hex}}",
  git_delete = "{{colors.error.default.hex}}",
  diff_add = "{{colors.primary_container.default.hex}}",
  diff_change = "{{colors.secondary_container.default.hex}}",
  diff_delete = "{{colors.error_container.default.hex}}",
  diff_text = "{{colors.surface_container_highest.default.hex}}",
}
