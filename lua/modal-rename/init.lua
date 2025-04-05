local M = {}

-- Function to get directory contents and populate buffer
local function create_popup(lines)
    -- Calculate window dimensions
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.6)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Create Buffer
    local buf = vim.api.nvim_create_buf(false, true)

    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Create floating window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Modal Rename ',
        title_pos = 'center',
    })

    return buf, win
end

local function get_netrw_dir()
    if vim.bo.filetype == 'netrw' then
        return vim.fn.expand('%:p:h')
    end
    return vim.fn.getcwd()

end

function M.setup()
    -- Get current directory files
    local dir = get_netrw_dir()
    local files = vim.fn.readdir(dir)

    -- Filter out ../ and ./"
    files = vim.tbl_filter(function(f)
        return f ~= '.' and f ~= '..'
    end, files)

    -- Store original filenames
    M.original_files = {}
    local display_lines = {}

    for i, file in ipairs(files) do
        M.original_files[i] = dir .. '/' .. file
        table.insert(display_lines, file)
    end

    -- Create popup
    local buf, win = create_popup(display_lines)
    M.current_buf = buf
    M.current_win = win

    -- Set buffer-local mappings
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua require("modal-rename").execute_rename()<CR>',
        {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require("modal-rename").close()<CR>',
        {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':lua require("modal-rename").close()<CR>',
        {noremap = true, silent = true})

    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
end

function M.execute_rename()
    local buf = M.current_buf
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Execute renames
    for i, new_name in ipairs(lines) do
        local old_path = M.original_files[i]
        if old_path then
            local dir = vim.fn.fnamemodify(old_path, ':h')
            local new_path = dir .. '/' .. new_name

            if old_path ~= new_path then
                local success, err = os.rename(old_path, new_path)
                if not success then
                    vim.api.nvim_echo({{'Error renaming ' .. old_path .. ': ' .. (err or 'unknown error'), 'Error'}}, true, {})
                end
            end
        end
    end

    M.close()
    --refresh netrw if in
    if vim.bo.filetype == 'netrw' then
        vim.cmd('silent! Explore')
    end
    vim.api.nvim_echo({{'Files renamed successfully!', 'Normal'}}, false, {})
end

function M.close()
    if M.current_win and vim.api.nvim_win_is_valid(M.current_win) then
        vim.api.nvim_win_close(M.current_win, true)
    end
    M.current_buf = nil
    M.current_win = nil
    M.original_files = nil
end

-- Autocommand to setup netrw keybinding
vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    callback = function()
        vim.api.nvim_buf_set_keymap(0, 'n', '<leader>rn', ':lua require("modal-rename").setup()<CR>',
            { noremap = true, silent = true, desc = "Rename all files in directory, modally" })
    end,
})

return M







