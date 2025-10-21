# nvim-leetcode

[![Made with Neovim](https://img.shields.io/badge/Made%20with-Neovim-57A143.svg?style=for-the-badge&logo=neovim)](https://neovim.io/)

A Neovim plugin to interact with LeetCode.

- [Features](#features)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Configuration](#configuration)
- [Authentication](#authentication)
- [Usage](#usage)
- [License](#license)
- [Contributing](#contributing)
- [Testing](#testing)

## Features

- Fetch and display LeetCode problems.
- Submit your solutions to LeetCode.

## Dependencies

- `curl`
- `python3`
- `browser-cookie3`

You can install the Python dependency using pip:

```bash
pip install browser-cookie3
```

## Installation

Using `packer.nvim`:

```lua
use {
  'yuheng108/nvim-leetcode',
  requires = {
    'nvim-lua/plenary.nvim',
  },
}
```

## Configuration

The plugin can be configured by passing a table to the `setup` function.

Example:

```lua
require('nvim-leetcode').setup({
  python_executable = "/usr/bin/python3",
  venv_activate_path = "/path/to/your/venv",
})
```

### Authentication

The plugin authenticates with LeetCode using your browser's cookies. It will automatically try to find your cookies from the following browsers:

- Chrome
- Firefox
- Brave
- Edge
- Chromium
- Opera
- Vivaldi
- Safari

If you want to use a different browser, or if the automatic detection fails, you can manually provide the `LEETCODE_SESSION` and `CSRF_TOKEN` cookies as environment variables.

To get the `LEETCODE_SESSION` and `CSRF_TOKEN` from your browser:

1. Open LeetCode in your browser and log in.
2. Open the developer tools (usually by pressing `F12`).
3. Go to the "Application" tab (or "Storage" in Firefox).
4. Go to the "Cookies" section and find the cookies for `leetcode.com`.
5. Find the `LEETCODE_SESSION` and `csrftoken` cookies and copy their values.

```bash
export LEETCODE_SESSION="your_session_token"
export CSRF_TOKEN="your_csrf_token"
```

## Usage

- `:LeetCode` - Fetch and display the list of problems.
- `:LeetCodeSubmit` - Submit the current solution.

## License

MIT

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Testing

To run the tests, you will need to have `make` installed. Then, you can run the following command:

```bash
make test
```
