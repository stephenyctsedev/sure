# Project Navigation Map

## 1. System Overview

This is a full-stack personal finance management application built primarily with Ruby on Rails. It features a web interface, a separate Flutter-based mobile app, and an extensive API. The system integrates with multiple financial data providers (Plaid, SimpleFIN, Coinbase, etc.) to aggregate user data.

- **Web Backend**: Ruby on Rails, Sidekiq (for background jobs)
- **Web Frontend**: Hotwire (Turbo/Stimulus), ERB templates, some JavaScript.
- **Mobile**: Flutter/Dart.
- **Database**: PostgreSQL (inferred from `Gemfile.lock` and common Rails convention).
- **Primary Dev Patterns**: MVC, Service Objects, Repository Pattern (for financial data).

## 2. Project Tree

```
.
├── app/                # Core Rails application (MVC, services, etc.)
│   ├── assets/
│   ├── controllers/    # Handles web requests and API logic
│   ├── javascript/     # Frontend JavaScript (Stimulus controllers)
│   ├── models/         # ActiveRecord data models
│   ├── services/       # Business logic service objects
│   └── views/          # ERB templates for the UI
├── bin/                # Executable scripts
├── config/             # Application configuration
│   ├── initializers/
│   └── routes.rb       # Defines all application routes
├── db/                 # Database schema, migrations, and seeds
├── lib/                # Custom libraries and modules
├── mobile/             # Flutter mobile application source
│   ├── lib/
│   └── pubspec.yaml    # Flutter dependencies
├── public/             # Static files and compiled assets
├── spec/               # RSpec tests for the Rails app
└── test/               # Minitest tests (seems to be a mix)
```

## 3. Core Entry Points

- **Web (Rack Server)**: `config.ru`
- **Web Routing**: `config/routes.rb`
- **Background Jobs**: `Sidekiq` (configured in `config/initializers/sidekiq.rb`)
- **Mobile App**: `mobile/lib/main.dart`

## 4. Module Map

| Directory/File | Primary Responsibility |
| :--- | :--- |
| `app/controllers` | Handles HTTP requests for both the web UI and the JSON API. |
| `app/models` | Defines the data structures and their relationships (ActiveRecord). |
| `app/views` | Contains the server-rendered HTML templates (ERB). |
| `app/services` | Encapsulates complex business logic (e.g., `Family::ExportService`). |
| `app/javascript` | Frontend code, primarily Stimulus controllers for dynamic behavior. |
| `config/routes.rb` | Maps URLs to controller actions. Defines API endpoints under `/api/v1`. |
| `db/schema.rb` | The canonical representation of the database schema. |
| `lib/` | Shared modules and code not specific to the MVC structure. |
| `mobile/lib` | Core source code for the Flutter mobile application. |
| `spec/` | Test suite for the application (RSpec). |

## 5. Key Data Models/Interfaces

The system revolves around a few core concepts:

- **`User` / `Family`**: Manages users and their group associations.
- **`Account`**: A central model, polymorphically linked to specific account types (`Depository`, `Investment`, `Loan`, etc.).
- **`Provider` / `Item`**: Represents connections to financial institutions (e.g., `PlaidItem`, `SimplefinItem`).
- **`Transaction` / `Entry`**: Core financial events linked to accounts.
- **`Holding` / `Security`**: Represents investment holdings and their corresponding securities.
- **`Rule`**: User-defined rules for categorizing or acting on transactions.

## 6. Critical Data Flows

1.  **Web Request Flow (MVC)**:
    `config/routes.rb` -> `app/controllers/*_controller.rb` -> `app/models/*.rb` -> `app/views/**/*.html.erb`

2.  **API Authentication & Request**:
    - Client sends credentials to `POST /api/v1/auth/login`.
    - `Api::V1::AuthController` validates and returns a JWT.
    - Subsequent requests include the JWT in the `Authorization` header.
    - API controllers (e.g., `Api::V1::TransactionsController`) handle the request.

3.  **Financial Data Sync**:
    - Triggered via UI or background job (`Sidekiq`).
    - A `*_items#sync` controller action is called (e.g., `PlaidItemsController#sync`).
    - A service object or job is invoked to fetch data from the external provider's API.
    - New `Entries`, `Holdings`, etc., are created/updated in the database.

## 7. Development Patterns

- **MVC (Model-View-Controller)**: The primary architectural pattern for the Rails web application.
- **Service Objects**: Business logic is encapsulated in plain Ruby objects in `app/services` to keep controllers and models lean.
- **Polymorphic Associations**: Used extensively on the `Account` model to handle many different types of financial accounts.
- **API Endpoints**: A versioned JSON API is provided under `/api/v1` for the mobile app and external clients.
- **Background Jobs**: `Sidekiq` is used for long-running tasks like data synchronization and report generation.
- **Dependency Injection**: Some services and controllers show signs of dependency injection, especially for external API clients.
