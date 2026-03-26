-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module 'lazy'
---@type LazySpec
return {
  -- Send code to terminal REPL
  {
    'jpalardy/vim-slime',
    init = function()
      vim.g.slime_target = 'tmux'
      vim.g.slime_no_mappings = true
      vim.g.slime_suggest_default = 1
      vim.g.slime_cell_delimiter = '```'
    end,
    keys = {
      { '<leader>rl', '<Plug>SlimeLineSend j',     desc = '[R]un [L]ine and move down' },
      { '<leader>rc', '<Plug>SlimeSendCell',       desc = '[R]un [C]ell' },
      { '<leader>rr', '<Plug>SlimeParagraphSend',  desc = '[R]un paragraph' },
      { '<leader>rr', '<Plug>SlimeRegionSend',     desc = '[R]un region', mode = 'x' },
      { '<leader>rs', '<Plug>SlimeConfig',         desc = '[R]EPL [S]elect pane' },
    },
    config = function()
      -- Find tmux pane ID by title
      local function pane_id_by_title(title)
        local result = vim.fn.system("tmux list-panes -a -F '#{pane_title} #{pane_id}'")
        for line in result:gmatch('[^\n]+') do
          local t, id = line:match('^(.-)%s+(%%%d+)$')
          if t == title then return id end
        end
        return nil
      end

      local function set_slime_target(title)
        local id = pane_id_by_title(title)
        if id then
          vim.b.slime_config = { socket_name = 'default', target_pane = id }
        else
          vim.notify('vim-slime: no tmux pane titled "' .. title .. '" found', vim.log.levels.WARN)
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'r', 'rmd', 'quarto' },
        callback = function()
          set_slime_target('R')
          vim.keymap.set('n', '<leader>-', 'a <- <Esc>', { buffer = true, desc = 'Insert <-' })
          vim.keymap.set('i', '<leader>-', ' <- ',       { buffer = true, desc = 'Insert <-' })
          vim.keymap.set('i', '<C-m>', ' %>% ',          { buffer = true, desc = 'Insert %>%' })
          -- Send word under cursor
          vim.keymap.set('n', '<leader>rw', function()
            vim.fn['slime#send'](vim.fn.expand('<cword>') .. '\n')
          end, { buffer = true, desc = '[R]un [W]ord' })
          -- Send full multi-line R expression (balanced parens)
          vim.keymap.set('n', '<leader>re', function()
            local function line_depth(line)
              local depth = 0
              local in_str = nil
              local i = 1
              while i <= #line do
                local c = line:sub(i, i)
                if in_str then
                  if c == '\\' then i = i + 1       -- skip escaped char
                  elseif c == in_str then in_str = nil
                  end
                else
                  if c == '"' or c == "'" then in_str = c
                  elseif c == '#' then break         -- rest is comment
                  elseif c == '(' or c == '[' or c == '{' then depth = depth + 1
                  elseif c == ')' or c == ']' or c == '}' then depth = depth - 1
                  end
                end
                i = i + 1
              end
              return depth
            end

            local start_line = vim.fn.line('.')
            local end_line = start_line
            local depth = 0
            for lnum = start_line, vim.fn.line('$') do
              depth = depth + line_depth(vim.fn.getline(lnum))
              end_line = lnum
              if depth <= 0 then break end
            end
            local text = table.concat(vim.fn.getline(start_line, end_line), '\n')
            vim.fn['slime#send'](text .. '\n')
          end, { buffer = true, desc = '[R]un [E]xpression' })
        end,
      })
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'python' },
        callback = function()
          set_slime_target('Python')
        end,
      })
    end,
  },

  -- Quarto: LSP + code runner for .qmd files
  {
    'quarto-dev/quarto-nvim',
    ft = { 'quarto' },
    dependencies = {
      'jmbuhr/otter.nvim',
      'nvim-treesitter/nvim-treesitter',
      'jpalardy/vim-slime',
    },
    opts = {
      lspFeatures = {
        enabled = true,
        chunks = 'curly',
        languages = { 'r', 'python', 'julia', 'bash', 'html' },
        diagnostics = { enabled = true, triggers = { 'BufWritePost' } },
        completion = { enabled = true },
      },
      codeRunner = {
        enabled = true,
        default_method = 'slime',
      },
    },
    keys = {
      { '<leader>qp', function()
          local file = vim.fn.expand('%:p')
          local port = 4321
          vim.cmd('botright 15split | terminal quarto preview ' .. file .. ' --no-browser --port ' .. port .. ' --no-render')
        end, desc = 'Quarto [P]review (SSH)' },
    },
  },
}
