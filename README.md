[![Automated Tests](https://github.com/basicmachines-co/open-ghl-mcp/actions/workflows/test.yml/badge.svg)](https://github.com/basicmachines-co/open-ghl-mcp/actions/workflows/test.yml)
# GoHighLevel MCP Server

A Model Context Protocol (MCP) server that provides seamless integration with the GoHighLevel API v2. This server enables AI assistants to interact with GoHighLevel's CRM functionality, starting with comprehensive contact management.

## Features

- 🔐 **OAuth 2.0 Authentication**: Full OAuth flow with automatic token management by default
- 🔑 **Private Integration Token (PIT) Support**: Use GHL's static API tokens for single-location setups
- 🏢 **Multi-location Support**: Works with agency accounts to manage multiple sub-accounts
- 👥 **Contact Management**: Complete CRUD operations for contacts
- 💬 **Conversations**: Search conversations, view messages, send SMS and Email
- 🎯 **Opportunities**: Full sales pipeline management with stage tracking
- 📅 **Calendars & Appointments**: Calendar management, appointment booking, free slot lookup
- 📝 **Forms & Submissions**: List forms, view submissions, upload files to custom fields
- 🏷️ **Tag Management**: Add and remove tags from contacts
- 🔄 **Automatic Token Refresh**: Handles token expiration seamlessly
- 🛠️ **MCP Tools & Resources**: Both tools and resources for flexible integration

## Prerequisites

- Python 3.12+
- `uv` package manager (or pip)
- One of the following:
  - **Standard Mode Configuration**: Access via our hosted GoHighLevel app (coming soon)
  - **Custom Mode Configuration**: Your own GoHighLevel Marketplace App credentials
  - **PIT Mode Configuration**: A Private Integration Token from GHL Settings

## Getting Started - Installation

1. Clone the repository:
```bash
git clone https://github.com/basicmachines-co/open-ghl-mcp.git
cd open-ghl-mcp
```
2. Install dependencies:
```bash
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

3. Start the server:
```bash
python -m src.main
```

## 1. Configuration

### Option A — Custom OAuth Mode
Use your own GoHighLevel Marketplace App:

1. Create your own GoHighLevel Marketplace App
2. Set the redirect URL to: `http://localhost:8080/oauth/callback`
3. Set the permissions you want for the tools and resources below

### Option B — Private Integration Token (PIT) Mode
For single-location setups without OAuth overhead:

1. In GHL, go to **Settings → Integrations → Private Integrations**
2. Create a new integration and note your token (`pit-...`)
3. Add your server's IP to the **Allowed Hosts** list
4. Create a `.env` file:
```env
AUTH_MODE=pit
GHL_PIT_TOKEN=pit-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
GHL_LOCATION_ID=your-location-id
```

> **Note**: PIT tokens are tied to a single location, don't expire, and require IP allowlisting. They are ideal for server-side automations where you control the network environment.


## 2. Usage

### Running the MCP Server

1. Start the server:
```bash
python -m src.main
```

2. Complete the setup wizard.

3. Configure your LLM to use the MCP server

### First-time Authentication

#### Custom Mode Setup
1. The server will ask you for your GHL Marketplace App Client ID and Secret
2. Install your App to generate an OAuth Token

## API Reference

This MCP server provides comprehensive access to GoHighLevel API v2 through both **Tools** (for actions) and **Resources** (for data browsing). All endpoints are fully tested and validated.

### 🛠️ MCP Tools (Actions)

#### 👥 Contact Management
| Tool | GoHighLevel Endpoint | Description |
|------|---------------------|-------------|
| `create_contact` | `POST /contacts` | Create a new contact |
| `update_contact` | `PUT /contacts/{id}` | Update existing contact |
| `delete_contact` | `DELETE /contacts/{id}` | Delete a contact |
| `get_contact` | `GET /contacts/{id}` | Get a single contact |
| `search_contacts` | `GET /contacts` | Search contacts with filters |
| `add_contact_tags` | `POST /contacts/{id}/tags` | Add tags to a contact |
| `remove_contact_tags` | `DELETE /contacts/{id}/tags` | Remove tags from a contact |

#### 💬 Conversations & Messaging
| Tool | GoHighLevel Endpoint | Description |
|------|---------------------|-------------|
| `get_conversations` | `GET /conversations/search` | Search and list conversations |
| `get_conversation` | `GET /conversations/{id}` | Get a single conversation |
| `get_messages` | `GET /conversations/{id}/messages` | Get messages from a conversation |
| `send_message` | `POST /conversations/{id}/messages` | Send messages (SMS ✅, Email ✅, WhatsApp, IG, FB, Custom, Live_Chat) |
| `update_message_status` | `PUT /conversations/messages/{messageId}/status` | ⚠️ Custom providers only — not available for standard messages |

#### 🎯 Opportunities & Sales Pipeline
| Tool | GoHighLevel Endpoint | Description |
|------|---------------------|-------------|
| `get_opportunities` | `GET /opportunities/search` | Search opportunities with filters |
| `get_opportunity` | `GET /opportunities/{id}` | Get a single opportunity |
| `create_opportunity` | `POST /opportunities` | Create new opportunity |
| `update_opportunity` | `PUT /opportunities/{id}` | Update existing opportunity |
| `delete_opportunity` | `DELETE /opportunities/{id}` | Delete opportunity |
| `update_opportunity_status` | `PUT /opportunities/{id}/status` | Update opportunity status |
| `get_pipelines` | `GET /opportunities/pipelines` | List all pipelines (stages embedded in each pipeline) |

> **Note**: There are no individual pipeline or stage lookup endpoints — `get_pipelines` returns all pipelines with their stages included.

#### 📅 Calendar & Appointments
| Tool | GoHighLevel Endpoint | Description |
|------|---------------------|-------------|
| `get_calendars` | `GET /calendars/?locationId={id}` | List all calendars for location |
| `get_calendar` | `GET /calendars/{id}` | Get calendar details (54+ fields) |
| `get_appointments` | `GET /contacts/{contactId}/appointments` | Get appointments for a contact |
| `get_appointment` | `GET /calendars/events/appointments/{id}` | Get a specific appointment |
| `create_appointment` | `POST /calendars/events/appointments` | Create a new appointment |
| `update_appointment` | `PUT /calendars/events/appointments/{id}` | Update an existing appointment |
| `delete_appointment` | `DELETE /calendars/events/{id}` | Delete an appointment |
| `get_free_slots` | `GET /calendars/{id}/free-slots` | Get available time slots |

#### 📝 Forms & Submissions
| Tool | GoHighLevel Endpoint | Description |
|------|---------------------|-------------|
| `get_forms` | `GET /forms` | List all forms (basic info: id, name, locationId) |
| `get_all_form_submissions` | `GET /forms/submissions` | Get all submissions with filtering |
| `upload_form_file` | `POST /forms/upload-custom-files` | Upload file to custom field |

> **Note**: Limited API support for forms. The following are NOT available:
> - `GET /forms/{id}` (401 "Route not supported")
> - `GET /forms/{id}/submissions` (404 Not Found)
> - `POST /forms/submit` (401 Unauthorized)

### 📖 MCP Resources (Data Browsing)

#### 👥 Contact Resources
| Resource URI | GoHighLevel Endpoint | Description |
|-------------|---------------------|-------------|
| `contacts://{location_id}` | `GET /contacts` | Browse all contacts for location |
| `contact://{location_id}/{contact_id}` | `GET /contacts/{id}` | View single contact details |

#### 💬 Conversation Resources
| Resource URI | GoHighLevel Endpoint | Description |
|-------------|---------------------|-------------|
| `conversations://{location_id}` | `GET /conversations/search` | Browse all conversations for location |
| `conversation://{location_id}/{conversation_id}` | `GET /conversations/{id}` | View conversation with messages |

#### 🎯 Opportunity Resources
| Resource URI | GoHighLevel Endpoint | Description |
|-------------|---------------------|-------------|
| `opportunities://{location_id}` | `GET /opportunities/search` | Browse all opportunities for location |
| `opportunity://{location_id}/{opportunity_id}` | `GET /opportunities/{id}` | View single opportunity details |
| `pipelines://{location_id}` | `GET /opportunities/pipelines` | Browse all pipelines with stages |

#### 📅 Calendar Resources
| Resource URI | GoHighLevel Endpoint | Description |
|-------------|---------------------|-------------|
| `calendars://{location_id}` | `GET /calendars/` | Browse all calendars for location |
| `calendar://{location_id}/{calendar_id}` | `GET /calendars/{id}` | View calendar details |
| `appointments://{location_id}/{contact_id}` | `GET /contacts/{id}/appointments` | Browse appointments for contact |

### 🔐 Authentication Requirements

All endpoints require proper authentication:

- **Company Token**: Used for location token exchange
- **Location Token**: Required for all location-specific operations (expires every 24 hours)
- **Automatic Refresh**: The MCP server handles token refresh automatically

### 📋 Example Usage

```bash
# Get all contacts for your location
contacts://YOUR_LOCATION_ID

# Get specific contact details
contact://YOUR_LOCATION_ID/YOUR_CONTACT_ID

# Browse appointments for a contact
appointments://YOUR_LOCATION_ID/YOUR_CONTACT_ID

# Browse opportunities for your location
opportunities://YOUR_LOCATION_ID

# View conversation details
conversation://YOUR_LOCATION_ID/YOUR_CONVERSATION_ID
```

## Authentication Modes

| Mode | Setup | Token Type | Scope | Best For |
|------|-------|------------|-------|----------|
| **Standard** | Via Basic Machines hosted app | OAuth 2.0 | Agency + all locations | Hosted/managed deployments |
| **Custom** | Your own Marketplace App | OAuth 2.0 | Agency + all locations | Multi-location agency control |
| **PIT** | GHL Settings → Private Integrations | Static Bearer token | Single location | Server automations, single-location |

## Roadmap — Not Yet Implemented

These GHL API areas are not yet in this MCP server but are planned:

| Feature | GHL Endpoints | OAuth Scopes Needed |
|---------|--------------|---------------------|
| **Location Details** | `GET /locations/{id}` | `locations.readonly` (already in scopes) |
| **Custom Fields** | `GET/POST/PUT/DELETE /locations/{id}/customFields` | `locations.readonly/write` |
| **Contact Notes** | `GET/POST/PUT/DELETE /contacts/{id}/notes` | `contacts.readonly/write` (already in scopes) |
| **Contact Tasks** | `GET/POST/PUT/DELETE /contacts/{id}/tasks` | `contacts.readonly/write` (already in scopes) |
| **Workflows** | `GET /workflows`, `POST /contacts/{id}/workflow/{wfId}` | `workflows.readonly/write` |
| **Users** | `GET /users`, `GET /users/{id}` | `users.readonly` |
| **Surveys** | `GET /surveys`, `GET /surveys/submissions` | `surveys.readonly` |
| **Products** | `GET /products`, `POST /products` | `products.readonly/write` |

## Development

### Testing

For local testing with real GoHighLevel accounts, you'll need:
- A GoHighLevel account with API access
- At least one sub-account (location) for testing
- Test contacts and data in your GoHighLevel instance

Create your own testing guidelines and keep sensitive data like location IDs and contact IDs in local files that are not committed to the repository.

### Running Tests

```bash
# Run all tests
uv run pytest

# Run tests with coverage report
uv run pytest --cov=src --cov-report=term-missing

# Run specific test file
uv run pytest tests/test_api_client.py -v
```

### Code Quality

This project uses automated code quality tools. Before committing changes:

```bash
# Format code with Black
uv run black src/ tests/

# Check linting with flake8
uv run flake8 src/ tests/

# Run type checking with mypy
uv run mypy src/ --ignore-missing-imports

# Run all checks at once
uv run black src/ tests/ && uv run flake8 src/ tests/ && uv run mypy src/ --ignore-missing-imports
```

### Pre-commit Hook (optional)

To automatically format code before commits:

```bash
# Create a git pre-commit hook
echo '#!/bin/sh
uv run black src/ tests/
uv run flake8 src/ tests/
' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Continuous Integration

The project uses GitHub Actions for CI/CD:
- Tests run automatically on all pushes and pull requests
- Tested with Python 3.12 and 3.13
- Includes linting, type checking, and test coverage
- Coverage reports are uploaded to Codecov (if configured)

## Architecture

The server follows a modular architecture:

- **OAuth Service**: Handles authentication and token management
- **API Client**: Manages communication with GoHighLevel API
- **MCP Server**: FastMCP-based server exposing tools and resources
- **Data Models**: Pydantic models for data validation

## License

This project is licensed under the GNU Affero General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and feature requests, please use the GitHub issues tracker.
