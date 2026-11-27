-- The reader mode: no spell marks in Markdown and text files. LazyVim turns
-- them on, but the files are for reading. <leader>us shows them again.
if vim.g.herdspace_reader then
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("herdspace_no_spell", { clear = true }),
    pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
    callback = function() vim.opt_local.spell = false end,
  })
end
