# MCP Server Support for Sure API

## Overview

Add a Model Context Protocol (MCP) server so that AI assistants (Claude Desktop,
Cursor, Continue, etc.) can interact with a user's Sure financial data directly
through natural-language tool calls.

---

## Goals

1. Expose Sure's external API (`/api/v1/`) as a set of MCP **tools**.
2. Allow users to authenticate with an API key generated in their account settings.
3. Ship a standalone MCP server binary/package that can be configured in any
   MCP-compatible client (e.g. `claude_desktop_config.json`).

---

## Scope (v1)

### Tools to expose

| Tool name              | Maps to                              | Description                                      |
|------------------------|--------------------------------------|--------------------------------------------------|
| `list_accounts`        | `GET /api/v1/accounts`               | List all accounts with optional pagination       |
| `get_account`          | `GET /api/v1/accounts/:id`           | Retrieve a single account by ID                  |
| `create_account`       | `POST /api/v1/accounts`              | Create a new manual account                      |
| `update_account`       | `PATCH /api/v1/accounts/:id`         | Rename or update balance / notes of an account   |
| `list_transactions`    | `GET /api/v1/transactions`           | List transactions with filtering / pagination    |
| `get_transaction`      | `GET /api/v1/transactions/:id`       | Retrieve a single transaction                    |
| `create_transaction`   | `POST /api/v1/transactions`          | Create a new manual transaction                  |
| `update_transaction`   | `PATCH /api/v1/transactions/:id`     | Update category, notes, tags, etc.               |
| `list_categories`      | `GET /api/v1/categories`             | List all spending categories                     |
| `get_category`         | `GET /api/v1/categories/:id`         | Retrieve a single category                       |

Additional tools (holdings, trades, imports, sync) can be added in later iterations.

---

## Implementation Plan

### 1. MCP server package

Create a new Node.js/TypeScript package at `mcp/` in the repo root (or publish
separately as `@sure-finance/mcp-server`).

```
mcp/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts          # MCP server entry point
│   ├── client.ts         # Typed API client wrapping fetch
│   ├── tools/
│   │   ├── accounts.ts
│   │   ├── transactions.ts
│   │   └── categories.ts
│   └── types.ts          # Shared TypeScript types
└── README.md
```

Use the official `@modelcontextprotocol/sdk` package for the server skeleton.

### 2. Authentication

The server reads the API key from the `SURE_API_KEY` environment variable.
Optionally accept `SURE_BASE_URL` (default: `https://app.sure.am`) so
self-hosted users can point it at their own instance.

```jsonc
// claude_desktop_config.json example
{
  "mcpServers": {
    "sure": {
      "command": "npx",
      "args": ["-y", "@sure-finance/mcp-server"],
      "env": {
        "SURE_API_KEY": "<your-api-key>",
        "SURE_BASE_URL": "https://app.sure.am"   // optional
      }
    }
  }
}
```

### 3. Tool schema example — `create_account`

```typescript
server.tool(
  "create_account",
  {
    name: z.string().describe("Account name"),
    accountable_type: z
      .enum([
        "Depository", "Investment", "Crypto", "Property",
        "Vehicle", "OtherAsset", "CreditCard", "Loan", "OtherLiability",
      ])
      .describe("Account type"),
    balance: z.number().optional().describe("Opening balance (default: 0)"),
    currency: z.string().optional().describe("ISO 4217 currency code"),
    institution_name: z.string().optional(),
    notes: z.string().optional(),
  },
  async (params) => {
    const account = await client.post("/api/v1/accounts", { account: params });
    return { content: [{ type: "text", text: JSON.stringify(account, null, 2) }] };
  }
);
```

### 4. Error handling

- Surface `4xx` / `5xx` API errors as MCP `isError: true` responses with the
  original `error` and `message` fields from the JSON body.
- Include the HTTP status code in the error text so the AI can reason about it.

### 5. Rate limiting awareness

Read `X-RateLimit-Remaining` from every response and, when it drops below 10,
include a note in the tool result asking the AI to reduce request frequency.

---

## Testing

- Unit tests for the API client (mock fetch responses).
- Integration smoke test against a local Sure instance using a test API key.

---

## Documentation updates

- Add a new section to `docs/api/` explaining MCP setup.
- Include a Quickstart for Claude Desktop, Cursor, and Continue.
- Document all supported tools with input/output examples.

---

## Out of scope (v1)

- OAuth / browser-based auth flow (API key only for now).
- MCP **resources** (e.g. `sure://accounts/{id}`) — may be added later.
- Streaming / SSE responses.
- Write operations beyond accounts and transactions (imports, trades, etc.).
