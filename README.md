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

## To use it

loging to leetcode, developer tool, go to application, go to cookies, find leetcode.com, find LEETCODE_SESSION and csrftoken
set -Ux CSRF_TOKEN leetcode_token
set -UX LEETCODE_SESSION your_session_token
set -gx LEETCODE_USERNAME "jasonli108"

set -gx LEETCODE_COOKIE_STRING -b '\_\_stripe_mid=eecaf200-a007-4b67-acc7-6dded14941f3dcd7c2; ip_check=(false, "72.69.109.128"); cf_clearance=Owf3Vz494izSOozTXYBIzLgF4vkLTWkU7Uv4cKTS574-1768238783-1.2.1.1-J_csuw7z1fUUHyEBxPdecaEqlIP8qBct2B0wLErho3ccwlKe7vxY1TIfG1DinaBoOekvD8bzoZpANiTQ8N4r4dr6EsffghZca.clViSj5jJGkSpF3QTEvDxk7afqJf_BnpCcowfgeGUXZPT2sHveAF0o.H94ycDBrNeoudBa4h.m.SXSpa31iQBz_xNwnPRyUVJ0JuQ5glCUJOiRMoI_YSjFnGFc_r687u7TtaFh1cM; csrftoken=ZixPNf55Hc9A6Eks1JAobPHhTQsp7AzS; messages=W1siX19qc29uX21lc3NhZ2UiLDAsMjUsIlN1Y2Nlc3NmdWxseSBzaWduZWQgaW4gYXMgamFzb25saTEwOC4iLCIiXV0:1vfLgS:rf8jAF_o2jX4kElcMS6ilXHn1iCkOF1sMymamgkSESU; INGRESSCOOKIE=93032dc14b987f74941f3a38f01daba5|8e0876c7c1464cc0ac96bc2edceabd27; LEETCODE_SESSION=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfYXV0aF91c2VyX2lkIjoiMTk4NjUzOSIsIl9hdXRoX3VzZXJfYmFja2VuZCI6ImFsbGF1dGguYWNjb3VudC5hdXRoX2JhY2tlbmRzLkF1dGhlbnRpY2F0aW9uQmFja2VuZCIsIl9hdXRoX3VzZXJfaGFzaCI6IjE0NjJiZjJlMmIwYmU2MDkzYzAwMDc4YTc3M2NiM2IyMjYzZmNkNjhlYTQ3MDc5NDNkMjNkZGMwY2FjYTdhOGYiLCJzZXNzaW9uX3V1aWQiOiI0NWI1ODRkMyIsImlkIjoxOTg2NTM5LCJlbWFpbCI6Imphc29ubGkxMDhAZ21haWwuY29tIiwidXNlcm5hbWUiOiJqYXNvbmxpMTA4IiwidXNlcl9zbHVnIjoiamFzb25saTEwOCIsImF2YXRhciI6Imh0dHBzOi8vYXNzZXRzLmxlZXRjb2RlLmNvbS91c2Vycy9kZWZhdWx0X2F2YXRhci5qcGciLCJyZWZyZXNoZWRfYXQiOjE3NjgyMzg3ODgsImlwIjoiNzIuNjkuMTA5LjEyOCIsImlkZW50aXR5IjoiOGRmMWQxZTFkMmM1ODRlNGEwMTU4NGRiZTkyNTE3NDQiLCJkZXZpY2Vfd2l0aF9pcCI6WyJjNTExYTI0NjI0ZGE3MGM0ZThjYjM3YTkxZDhiOTU2MiIsIjcyLjY5LjEwOS4xMjgiXSwiX3Nlc3Npb25fZXhwaXJ5IjoxMjA5NjAwfQ.nbjLNX8gocFKGexcwX9U_261RMdYCtvLLkdYkYa30Rg'

the cookies_string is a string that contains all the cookies for leetcode.com, you can get it from your browser developer tools
go to the progress type document, and copy the Cookie

:LeetCode to load the questions and :LeetCodeSubmit to submit your solution
