# Copilot Instructions - MCP .NET Samples

Use repo-proven patterns. This repository is a mono-repo of independent MCP server samples, not one shared application.

## Build, test, and lint commands
- The repo targets .NET 10 (`global.json`, `Directory.Build.props`). Each sample builds independently, and CI builds from the sample directory with `dotnet restore && dotnet build`.
- Sample solution files:
  - `.\awesome-copilot\McpAwesomeCopilot.sln`
  - `.\markdown-to-html\McpMarkdownToHtml.sln`
  - `.\todo-list\McpTodoList.sln`
  - `.\outlook-email\McpOutlookEmail.sln`

| Task | Command |
| --- | --- |
| Build one sample from repo root | `dotnet build .\todo-list\McpTodoList.sln` |
| Build the way CI does | `cd .\todo-list; dotnet restore; dotnet build` |
| Run one sample in STDIO mode | `dotnet run --project .\todo-list\src\McpSamples.TodoList.HybridApp` |
| Run one sample in HTTP mode | `dotnet run --project .\todo-list\src\McpSamples.TodoList.HybridApp -- --http` |
| Build a container image | `docker build -f Dockerfile.todo-list -t todo-list:latest .` |
| Deploy one sample to Azure | `cd .\todo-list; azd auth login; azd up` |

- No test projects are checked in today, and CI does not run a repo-defined lint or formatting command. Do not invent `dotnet test`, single-test filters, or `dotnet format` steps in repo guidance.

## High-level architecture
- The repo is organized as four self-contained hybrid servers: `awesome-copilot`, `markdown-to-html`, `todo-list`, and `outlook-email`. Each sample has its own solution file, `src\<Project>.HybridApp`, `infra\`, sample-specific `.vscode\mcp.*.json` templates, and a root-level `Dockerfile.<sample>`.
- `shared\McpSamples.Shared` owns the common host/runtime plumbing: `AppSettings.UseStreamableHttp(...)`, `AddAppSettings<T>()`, `BuildApp(useStreamableHttp)`, and `McpDocumentTransformer<T>`.
- Every sample `Program.cs` follows the same pattern: detect transport first, choose `WebApplication.CreateBuilder(args)` for HTTP or `Host.CreateApplicationBuilder(args)` for STDIO, register only sample-specific services, then hand off to `BuildApp(useStreamableHttp)`.
- `BuildApp(...)` is the central MCP wiring. It calls `AddMcpServer()`, chooses HTTP vs STDIO transport, maps `/mcp` in HTTP mode, and auto-registers tools, prompts, and resources from the entry assembly with `WithToolsFromAssembly(...)`, `WithPromptsFromAssembly(...)`, and `WithResourcesFromAssembly(...)`.
- Samples that publish OpenAPI docs (`awesome-copilot` and `todo-list`) also add `AddHttpContextAccessor()`, register both Swagger 2.0 and OpenAPI 3.0 documents, apply `McpDocumentTransformer<T>`, and map `/{documentName}.json` after `BuildApp(...)`.

## Sample-specific architecture notes
- `awesome-copilot`: `MetadataService` is the boundary for `metadata.json`. It caches the deserialized file in memory and uses HTTP only for `load_instruction`; do not add new code that repeatedly re-reads or re-deserializes the metadata file.
- `markdown-to-html`: extra switches (`-tc`, `-p`, `--tags`) are parsed in `MarkdownToHtmlAppSettings.ParseMore(...)`. They only reach the app when passed after the `--` delimiter to `dotnet run`.
- `todo-list`: the database is intentionally in-memory SQLite, but it persists for the process lifetime because `Program.cs` opens one singleton `SqliteConnection` and keeps it alive. Breaking that singleton turns every request into an empty database.
- `todo-list`: repository updates use EF Core set-based APIs (`ExecuteUpdateAsync`, `ExecuteDeleteAsync`) rather than manual entity mutation loops.
- `outlook-email`: HTTP mode is shaped for Azure Functions custom-handler hosting. It binds to `FUNCTIONS_CUSTOMHANDLER_PORT` when present and defaults to port `5260` otherwise.
- `outlook-email`: Microsoft Graph auth stays inside this sample. It builds `GraphServiceClient` from managed identity or explicit tenant/client/secret settings; do not move auth-specific behavior into `shared`.

## Key conventions
- Prefer adding new MCP tools, prompts, or resources as public attributed types in the sample project. Assembly scanning does the registration; manual registration should be the exception.
- Keep `shared` generic. Transport selection, app-settings plumbing, and OpenAPI transformation live there; sample-only auth, storage, and domain logic stay in the sample directory.
- Preserve the `dotnet run --project ... -- <sample flags>` pattern from the sample READMEs. Missing the second `--` is a common source of broken local runs.
- Match the existing `System.Text.Json` behavior when working with metadata or config payloads: camelCase and case-insensitive property names.
- Root Dockerfiles are named `Dockerfile.<sample>` and expose port `8080`. Local HTTP dev ports are `5250` for awesome-copilot, `5280` for markdown-to-html, `5240` for todo-list, and `5260` for outlook-email.
- VS Code setup is template-based: copy the right sample `.vscode\mcp.*.json` file to repo-root `.vscode\mcp.json` rather than editing sample templates in place.
- If you add OpenAPI docs to another sample, follow the existing full pattern: `AddHttpContextAccessor()`, both `AddOpenApi(...)` registrations, `McpDocumentTransformer<T>`, and `MapOpenApi("/{documentName}.json")`.
- New samples should match the existing shape: sample folder with its own `.sln`, `src\<Project>.HybridApp`, `infra\`, `.vscode\mcp.*.json`, a root `Dockerfile.<sample>`, and a root README entry.
