# UX Path Categories Reference

Use this reference to ensure comprehensive coverage across any application type. Not all categories apply to every app — the discovery agent should select the relevant ones.

## Universal Categories (apply to almost any app)

### Authentication & Identity
- Sign up (email, OAuth, SSO, magic link)
- Log in / log out
- Password reset / change
- Session management (timeout, refresh, multi-device)
- Account deletion / deactivation
- Profile management

### Onboarding & First-Time Experience
- First launch / empty state
- Setup wizard / guided tour
- Feature discovery
- Import existing data
- Invite flow (being invited vs inviting others)

### Core CRUD Operations
- Create primary entities
- Read / browse / search entities
- Update / edit entities
- Delete / archive entities
- Bulk operations (select all, batch delete, batch edit)

### Navigation & Discovery
- Primary navigation (sidebar, tab bar, menu)
- Search and filtering
- Breadcrumbs / back navigation
- Deep linking / direct URL access
- Keyboard navigation / shortcuts

### Settings & Configuration
- User preferences (theme, language, notifications)
- App configuration (integrations, API keys, webhooks)
- Permission / role management
- Billing / subscription management

### Error States & Recovery
- Network failure mid-operation
- Invalid input / validation errors
- 404 / not found pages
- Permission denied
- Rate limiting
- Session expiration during work
- Undo / revert actions

### Data Management
- Import / export
- Backup / restore
- Pagination / infinite scroll
- Sorting / filtering
- Data visualization (charts, graphs, tables)

## Web App Categories

### Responsive / Multi-Device
- Desktop viewport workflows
- Mobile viewport workflows
- Tablet viewport workflows
- Touch vs mouse interactions

### Real-time Features
- Live updates / WebSocket events
- Collaborative editing
- Notifications (in-app, push, email)
- Presence indicators

### Content Management
- Rich text editing
- File / image upload
- Media preview
- Version history

## Mobile App Categories

### Platform-Specific
- iOS-specific interactions (swipe, force touch, share sheet)
- Android-specific (back button, notifications, intents)
- Permissions (camera, location, contacts, notifications)
- Offline mode / sync

### Gestures & Interactions
- Pull to refresh
- Swipe actions
- Long press menus
- Drag and drop

## CLI / Terminal App Categories

### Command Patterns
- Help / usage display
- Flag / argument parsing
- Interactive prompts
- Pipe / stdin input
- Output formatting (JSON, table, plain)
- Verbose / debug modes

### Session Management
- Config file management
- Environment variable usage
- Authentication tokens

## API / Backend Categories

### Endpoint Patterns
- CRUD endpoint usage
- Authentication flows (API keys, OAuth tokens)
- Pagination through results
- Error response handling
- Rate limit behavior
- Webhook delivery / retry

## Desktop App Categories

### Window Management
- Multi-window workflows
- Menu bar interactions
- System tray
- Keyboard shortcuts
- File system integration (open, save, drag-drop)

### OS Integration
- Native notifications
- File associations
- Auto-update flow
- Deep link handling

## Cross-Cutting Concerns (apply to multiple categories)

### Collaboration
- Sharing / permissions
- Comments / annotations
- Activity feed / audit log
- Team management

### Performance & Loading
- Slow network behavior
- Large dataset handling
- Background processing feedback
- Progress indicators

### Accessibility
- Screen reader navigation
- Keyboard-only operation
- High contrast / reduced motion

## Story Complexity Heuristics

| Type | Steps | Scope | Example |
|------|-------|-------|---------|
| Short | 2-5 | Single feature | Toggle dark mode |
| Medium | 5-15 | One workflow | Create and share a document |
| Long | 15-40 | Cross-feature journey | New user onboards, creates project, invites team, completes first task |

## Persona Templates

Adapt these to the specific app:

- **New User**: Never seen the app. Needs onboarding. May be confused.
- **Regular User**: Uses the app daily. Knows the basics. Has preferences set.
- **Power User**: Uses advanced features. Keyboard shortcuts. Custom workflows.
- **Admin**: Manages other users. Configures the system. Handles edge cases.
- **Returning User**: Used the app months ago. Forgot some things. Has old data.
- **Impatient User**: Wants to accomplish something fast. Skips tutorials. Gets frustrated by friction.
- **Cautious User**: Reads everything. Wants confirmation before destructive actions. Worries about data loss.
