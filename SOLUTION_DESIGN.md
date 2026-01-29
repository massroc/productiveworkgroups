# Productive Work Groups - Solution Design

## Document Info
- **Version:** 1.1
- **Last Updated:** 2026-01-29
- **Status:** Draft

---

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [SOLID Principles Application](#solid-principles-application)
3. [Phoenix Contexts (Bounded Contexts)](#phoenix-contexts-bounded-contexts)
4. [Domain Models](#domain-models)
5. [Database Schema](#database-schema)
6. [Real-Time Architecture](#real-time-architecture)
7. [LiveView Component Structure](#liveview-component-structure)
8. [State Management](#state-management)
9. [Security Considerations](#security-considerations)
10. [Error Handling Strategy](#error-handling-strategy)
11. [Testing Strategy](#testing-strategy)
12. [Deployment Architecture](#deployment-architecture)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser (Client)                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 Phoenix LiveView                         │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │   │
│  │  │  Lobby   │ │ Scoring  │ │ Summary  │ │ Actions  │   │   │
│  │  │   View   │ │   View   │ │   View   │ │   View   │   │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │ WebSocket
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Phoenix Application                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    LiveView Layer                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 Phoenix PubSub (Real-time)               │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────────┐    │
│  │   Workshops   │ │   Sessions    │ │    Facilitation   │    │
│  │    Context    │ │    Context    │ │      Context      │    │
│  └───────────────┘ └───────────────┘ └───────────────────────┘    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Ecto / PostgreSQL                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Design Philosophy

1. **Separation of Concerns** - Clear boundaries between workshop content, session management, and facilitation logic
2. **Configuration-Driven** - Workshop definitions stored as data, enabling future workshop types
3. **Real-Time First** - Built on Phoenix PubSub for seamless multi-user synchronization
4. **Progressive Enhancement** - Core functionality works; enhanced features layer on top

---

## SOLID Principles Application

### Single Responsibility Principle (SRP)

Each module has one reason to change:

| Module | Responsibility |
|--------|---------------|
| `Workshops` | Workshop template definitions and question content |
| `Sessions` | Session lifecycle, participant management |
| `Scoring` | Score submission, validation, aggregation |
| `Facilitation` | Timer management, phase transitions, prompts |
| `Notes` | Notes and action item capture |
| `Presence` | Real-time participant presence tracking |

### Open/Closed Principle (OCP)

**Workshop Templates are extensible without modification:**

```elixir
# New workshop types can be added as data without changing core logic
defmodule ProductiveWorkGroups.Workshops.Template do
  @callback questions() :: [Question.t()]
  @callback introduction_screens() :: [Screen.t()]
  @callback time_allocations() :: map()
end

# Six Criteria is one implementation
defmodule ProductiveWorkGroups.Workshops.SixCriteria do
  @behaviour ProductiveWorkGroups.Workshops.Template
  # Implementation...
end
```

**Scoring strategies are pluggable:**

```elixir
defmodule ProductiveWorkGroups.Scoring.Strategy do
  @callback validate(score :: integer(), question :: Question.t()) :: :ok | {:error, String.t()}
  @callback color_code(score :: integer(), question :: Question.t()) :: :green | :amber | :red
  @callback optimal_score(question :: Question.t()) :: integer()
end

# Balance scale (-5 to +5, optimal at 0)
defmodule ProductiveWorkGroups.Scoring.BalanceScale do
  @behaviour ProductiveWorkGroups.Scoring.Strategy
end

# Maximal scale (0 to 10, optimal at 10)
defmodule ProductiveWorkGroups.Scoring.MaximalScale do
  @behaviour ProductiveWorkGroups.Scoring.Strategy
end
```

### Liskov Substitution Principle (LSP)

All workshop templates are interchangeable:

```elixir
# Any workshop template can be used wherever Template is expected
def start_session(template) when is_struct(template, Template) do
  questions = template.questions()
  # Works with SixCriteria or any future workshop type
end
```

### Interface Segregation Principle (ISP)

Focused behaviours rather than monolithic interfaces:

```elixir
# Separate concerns into focused behaviours
defmodule ProductiveWorkGroups.Scoreable do
  @callback submit_score(participant_id, question_id, score) :: {:ok, Score.t()} | {:error, term()}
end

defmodule ProductiveWorkGroups.Timeable do
  @callback start_timer(section_id, duration_ms) :: {:ok, Timer.t()}
  @callback pause_timer(timer_id) :: :ok
  @callback resume_timer(timer_id) :: :ok
end

defmodule ProductiveWorkGroups.Notable do
  @callback add_note(session_id, question_id, content) :: {:ok, Note.t()}
end
```

### Dependency Inversion Principle (DIP)

High-level modules don't depend on low-level details:

```elixir
# LiveView depends on abstract Session behaviour, not concrete implementation
defmodule ProductiveWorkGroupsWeb.WorkshopLive do
  # Injected dependency - can be mocked in tests
  def mount(_params, _session, socket) do
    session_server = socket.assigns[:session_server] || ProductiveWorkGroups.Sessions.Server
    # Use session_server abstraction
  end
end

# PubSub abstracted for testing
defmodule ProductiveWorkGroups.Broadcaster do
  @callback broadcast(topic :: String.t(), event :: atom(), payload :: map()) :: :ok
end
```

---

## Phoenix Contexts (Bounded Contexts)

### Context Map

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌─────────────┐      ┌─────────────┐      ┌────────────┐  │
│  │  Workshops  │◄────►│  Sessions   │◄────►│  Scoring   │  │
│  │             │      │             │      │            │  │
│  │ - Templates │      │ - Session   │      │ - Scores   │  │
│  │ - Questions │      │ - Particip. │      │ - Aggreg.  │  │
│  │ - Scales    │      │ - State     │      │ - Colors   │  │
│  └─────────────┘      └─────────────┘      └────────────┘  │
│         │                    │                    │         │
│         │                    ▼                    │         │
│         │           ┌─────────────┐               │         │
│         └──────────►│ Facilitation│◄──────────────┘         │
│                     │             │                         │
│                     │ - Timers    │                         │
│                     │ - Phases    │                         │
│                     │ - Prompts   │                         │
│                     └─────────────┘                         │
│                            │                                │
│                            ▼                                │
│                     ┌─────────────┐                         │
│                     │    Notes    │                         │
│                     │             │                         │
│                     │ - Notes     │                         │
│                     │ - Actions   │                         │
│                     └─────────────┘                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Context Definitions

#### 1. Workshops Context

**Purpose:** Manage workshop templates and content (the "what" of workshops)

```elixir
defmodule ProductiveWorkGroups.Workshops do
  @moduledoc """
  The Workshops context manages workshop templates, questions, and content.
  This is the domain knowledge - what questions to ask and how to present them.
  """

  # Public API
  def list_templates()
  def get_template!(id)
  def get_questions(template)
  def get_question!(template, question_number)
  def get_introduction_screens(template)
  def get_discussion_prompts(question, score_context)
  def get_facilitator_help(phase, context)
end
```

**Entities:**
- `Template` - Workshop definition (Six Criteria, future types)
- `Question` - Individual question with explanation, scale, prompts
- `Scale` - Scoring scale definition (balance or maximal)
- `Screen` - Introduction/transition screen content

#### 2. Sessions Context

**Purpose:** Manage session lifecycle and participants (the "who" and "when")

```elixir
defmodule ProductiveWorkGroups.Sessions do
  @moduledoc """
  The Sessions context manages workshop sessions and participants.
  Handles session creation, joining, state transitions, and participant tracking.
  """

  # Session management
  def create_session(template_id, opts \\ [])
  def get_session!(id)
  def get_session_by_code(code)
  def end_session(session_id)

  # Participant management
  def join_session(session_id, participant_name)
  def leave_session(session_id, participant_id)
  def mark_participant_ready(session_id, participant_id)
  def mark_participant_inactive(session_id, participant_id)
  def reactivate_participant(session_id, participant_id)
  def get_active_participants(session_id)

  # State queries
  def all_participants_ready?(session_id)
  def all_participants_scored?(session_id, question_id)
  def get_session_state(session_id)
end
```

**Entities:**
- `Session` - Workshop instance with state, timing, settings
- `Participant` - Person in a session with status, browser token
- `SessionSettings` - Time allocation, participant limits

**Session Persistence & Resumption:**

Sessions are fully persisted to the database, allowing teams to pause and resume workshops across browser sessions or days. The same session link remains valid throughout.

| Session State | Expiry | Behavior |
|---------------|--------|----------|
| Incomplete (in progress) | 14 days from last activity | Team can resume via original link |
| Completed | 90 days from completion | Available for review, then cleaned up |
| Expired | - | Link redirects to homepage (no error) |

**Resumption Flow:**
```
1. Team starts workshop → Session created with code ABC123
2. Complete questions 1-4 → State persisted to DB
3. Everyone closes browser (break/meeting/end of day)
4. Team returns later → Same link: /workshop/ABC123
5. Participants rejoin:
   - Browser token matches → Auto-recognized
   - Token missing → Re-enter name, matched to original participant
6. Resume at question 5 → All previous scores/notes intact
```

**Design Rationale:**
- Same session ID/link preserved - already shared in calendar invites, Slack, etc.
- Simpler mental model: "same workshop = same link"
- All state (scores, notes, current question, timer) persisted
- No need to "export and re-import" or create new sessions

#### 3. Scoring Context

**Purpose:** Handle score submission, validation, and aggregation

```elixir
defmodule ProductiveWorkGroups.Scoring do
  @moduledoc """
  The Scoring context handles all scoring operations.
  Validates scores, calculates aggregations, and determines traffic light colors.
  """

  # Score submission
  def submit_score(participant_id, question_id, value)
  def update_score(score_id, new_value)  # Only before reveal
  def lock_scores(session_id, question_id)

  # Score retrieval
  def get_scores(session_id, question_id)
  def get_participant_scores(participant_id)
  def get_all_session_scores(session_id)

  # Aggregation
  def calculate_average(session_id, question_id)
  def calculate_spread(session_id, question_id)
  def get_score_summary(session_id)

  # Traffic light
  def color_for_score(score_value, question)
  def color_for_average(average, question)
end
```

**Entities:**
- `Score` - Individual participant score for a question
- `ScoreSummary` - Aggregated statistics for a question

#### 4. Facilitation Context

**Purpose:** Manage workshop flow, timing, and guidance

```elixir
defmodule ProductiveWorkGroups.Facilitation do
  @moduledoc """
  The Facilitation context manages the workshop flow.
  Handles phase transitions, timers, and contextual guidance.
  """

  # Phase management
  def get_current_phase(session_id)
  def advance_phase(session_id)
  def can_advance?(session_id)
  def get_phase_requirements(session_id)

  # Timer management
  def start_section_timer(session_id, section)
  def pause_timer(session_id)
  def resume_timer(session_id)
  def adjust_timer(session_id, new_duration)
  def get_time_remaining(session_id)
  def get_overall_time_remaining(session_id)

  # Guidance
  def get_discussion_prompts(session_id)
  def get_facilitator_help(session_id, topic)
  def is_time_exceeded?(session_id)
end
```

**Entities:**
- `Phase` - Current workshop phase (intro, scoring, summary, actions)
- `Timer` - Active timer with remaining time, paused state
- `TimeAllocation` - Budgeted time per section

#### 5. Notes Context

**Purpose:** Capture discussion notes and action items

```elixir
defmodule ProductiveWorkGroups.Notes do
  @moduledoc """
  The Notes context handles capturing discussion notes and action items.
  """

  # Notes
  def add_note(session_id, question_id, content, author_id)
  def update_note(note_id, content)
  def delete_note(note_id)
  def get_notes(session_id, question_id)
  def get_all_notes(session_id)

  # Actions
  def add_action(session_id, content, opts \\ [])
  def update_action(action_id, attrs)
  def delete_action(action_id)
  def assign_owner(action_id, owner_name)
  def link_to_question(action_id, question_id)
  def get_actions(session_id)
end
```

**Entities:**
- `Note` - Discussion note linked to a question
- `Action` - Action item with optional owner and question link

---

## Domain Models

### Entity Relationship Diagram

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│   Template   │       │   Session    │       │ Participant  │
├──────────────┤       ├──────────────┤       ├──────────────┤
│ id           │       │ id           │       │ id           │
│ name         │◄──────│ template_id  │       │ session_id   │──┐
│ description  │       │ code         │◄──────│ name         │  │
│ version      │       │ state        │       │ browser_token│  │
└──────────────┘       │ settings     │       │ status       │  │
       │               │ started_at   │       │ joined_at    │  │
       │               │ completed_at │       └──────────────┘  │
       ▼               └──────────────┘              │          │
┌──────────────┐              │                      │          │
│   Question   │              │                      ▼          │
├──────────────┤              │               ┌──────────────┐  │
│ id           │              │               │    Score     │  │
│ template_id  │──────────────┼───────────────├──────────────┤  │
│ number       │              │               │ id           │  │
│ title        │              │               │ session_id   │──┘
│ explanation  │              │               │ question_id  │──┐
│ scale_type   │◄─────────────┼───────────────│ participant_id│  │
│ scale_min    │              │               │ value        │  │
│ scale_max    │              │               │ submitted_at │  │
│ optimal      │              │               │ locked       │  │
└──────────────┘              │               └──────────────┘  │
                              │                                  │
                              ▼                                  │
                       ┌──────────────┐       ┌──────────────┐  │
                       │    Timer     │       │     Note     │  │
                       ├──────────────┤       ├──────────────┤  │
                       │ id           │       │ id           │  │
                       │ session_id   │       │ session_id   │  │
                       │ section      │       │ question_id  │──┘
                       │ duration_ms  │       │ content      │
                       │ remaining_ms │       │ author_id    │
                       │ paused       │       │ created_at   │
                       │ started_at   │       └──────────────┘
                       └──────────────┘
                                             ┌──────────────┐
                                             │    Action    │
                                             ├──────────────┤
                                             │ id           │
                                             │ session_id   │
                                             │ content      │
                                             │ owner        │
                                             │ question_id  │
                                             │ created_at   │
                                             └──────────────┘
```

### Core Schemas

```elixir
defmodule ProductiveWorkGroups.Sessions.Session do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "sessions" do
    field :code, :string  # 6-character join code
    field :state, Ecto.Enum, values: [:lobby, :intro, :scoring, :summary, :actions, :completed]
    field :current_question, :integer, default: 0
    field :scores_revealed, :boolean, default: false

    # Settings (embedded)
    embeds_one :settings, Settings do
      field :total_duration_minutes, :integer, default: nil  # nil = no timer; optional presets: 120, 210, or custom
      field :max_participants, :integer, default: 20
      field :skip_intro, :boolean, default: false
    end

    # Timestamps
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :last_activity_at, :utc_datetime  # Updated on any participant action
    field :expires_at, :utc_datetime        # Calculated: last_activity + 14 days (or completed + 90 days)

    belongs_to :template, ProductiveWorkGroups.Workshops.Template, type: :binary_id
    has_many :participants, ProductiveWorkGroups.Sessions.Participant
    has_many :scores, ProductiveWorkGroups.Scoring.Score
    has_many :notes, ProductiveWorkGroups.Notes.Note
    has_many :actions, ProductiveWorkGroups.Notes.Action

    timestamps()
  end
end

defmodule ProductiveWorkGroups.Sessions.Participant do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "participants" do
    field :name, :string
    field :browser_token, :string  # For reconnection
    field :status, Ecto.Enum, values: [:active, :inactive, :dropped]
    field :is_facilitator, :boolean, default: false
    field :is_observer, :boolean, default: false  # Observer cannot enter scores
    field :ready, :boolean, default: false
    field :joined_at, :utc_datetime
    field :last_seen_at, :utc_datetime

    belongs_to :session, ProductiveWorkGroups.Sessions.Session, type: :binary_id
    has_many :scores, ProductiveWorkGroups.Scoring.Score

    timestamps()
  end
end

defmodule ProductiveWorkGroups.Scoring.Score do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "scores" do
    field :value, :integer
    field :locked, :boolean, default: false
    field :submitted_at, :utc_datetime

    belongs_to :session, ProductiveWorkGroups.Sessions.Session, type: :binary_id
    belongs_to :participant, ProductiveWorkGroups.Sessions.Participant, type: :binary_id
    belongs_to :question, ProductiveWorkGroups.Workshops.Question, type: :binary_id

    timestamps()
  end
end
```

### Value Objects

```elixir
defmodule ProductiveWorkGroups.Scoring.ScoreResult do
  @moduledoc "Immutable value object representing a scored question result"

  defstruct [
    :question_number,
    :scores,           # List of {participant_name, value, color}
    :average,
    :average_color,
    :spread,           # Standard deviation
    :all_submitted,
    :revealed
  ]
end

defmodule ProductiveWorkGroups.Facilitation.TimeStatus do
  @moduledoc "Immutable value object representing current time status"

  defstruct [
    :section_remaining_ms,
    :section_total_ms,
    :overall_remaining_ms,
    :overall_total_ms,
    :is_paused,
    :is_exceeded,
    :pacing  # :ahead, :on_track, :behind
  ]
end
```

---

## Database Schema

### Migrations

```elixir
# Migration: Create Templates and Questions (Workshop Content)
defmodule ProductiveWorkGroups.Repo.Migrations.CreateWorkshopContent do
  use Ecto.Migration

  def change do
    create table(:templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :version, :string, default: "1.0"
      add :active, :boolean, default: true

      timestamps()
    end

    create table(:questions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_id, references(:templates, type: :binary_id, on_delete: :delete_all), null: false
      add :number, :integer, null: false
      add :title, :string, null: false
      add :short_title, :string
      add :explanation, :text, null: false
      add :scale_type, :string, null: false  # "balance" or "maximal"
      add :scale_min, :integer, null: false
      add :scale_max, :integer, null: false
      add :optimal_value, :integer, null: false
      add :discussion_prompts, {:array, :string}, default: []
      add :facilitator_help, :text

      timestamps()
    end

    create unique_index(:questions, [:template_id, :number])
  end
end

# Migration: Create Sessions and Participants
defmodule ProductiveWorkGroups.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_id, references(:templates, type: :binary_id), null: false
      add :code, :string, size: 6, null: false
      add :state, :string, default: "lobby"
      add :current_question, :integer, default: 0
      add :scores_revealed, :boolean, default: false
      add :settings, :map, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :last_activity_at, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:sessions, [:code])
    create index(:sessions, [:state])
    create index(:sessions, [:expires_at])
    create index(:sessions, [:last_activity_at])

    create table(:participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :browser_token, :string, null: false
      add :status, :string, default: "active"
      add :ready, :boolean, default: false
      add :joined_at, :utc_datetime
      add :last_seen_at, :utc_datetime

      timestamps()
    end

    create index(:participants, [:session_id])
    create unique_index(:participants, [:session_id, :browser_token])
  end
end

# Migration: Create Scores
defmodule ProductiveWorkGroups.Repo.Migrations.CreateScores do
  use Ecto.Migration

  def change do
    create table(:scores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :participant_id, references(:participants, type: :binary_id, on_delete: :delete_all), null: false
      add :question_id, references(:questions, type: :binary_id), null: false
      add :value, :integer, null: false
      add :locked, :boolean, default: false
      add :submitted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:scores, [:session_id, :participant_id, :question_id])
    create index(:scores, [:session_id, :question_id])
  end
end

# Migration: Create Notes and Actions
defmodule ProductiveWorkGroups.Repo.Migrations.CreateNotesAndActions do
  use Ecto.Migration

  def change do
    create table(:notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :question_id, references(:questions, type: :binary_id), null: true  # Can be general note
      add :author_id, references(:participants, type: :binary_id, on_delete: :nilify_all)
      add :content, :text, null: false

      timestamps()
    end

    create index(:notes, [:session_id])
    create index(:notes, [:session_id, :question_id])

    create table(:actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :question_id, references(:questions, type: :binary_id), null: true  # Optional link
      add :content, :text, null: false
      add :owner, :string  # Just a name, not a participant reference
      add :position, :integer  # For ordering

      timestamps()
    end

    create index(:actions, [:session_id])
  end
end

# Migration: Create Timers
defmodule ProductiveWorkGroups.Repo.Migrations.CreateTimers do
  use Ecto.Migration

  def change do
    create table(:timers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :section, :string, null: false  # "intro", "question_1", "summary", etc.
      add :duration_ms, :integer, null: false
      add :remaining_ms, :integer, null: false
      add :paused, :boolean, default: false
      add :started_at, :utc_datetime
      add :paused_at, :utc_datetime

      timestamps()
    end

    create unique_index(:timers, [:session_id, :section])
  end
end

# Migration: Create Feedback
defmodule ProductiveWorkGroups.Repo.Migrations.CreateFeedback do
  use Ecto.Migration

  def change do
    create table(:feedback, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)
      add :section, :string  # Where in workshop feedback was given
      add :category, :string  # "working_well", "improvement", "bug"
      add :content, :text, null: false
      add :email, :string  # Optional contact

      timestamps()
    end
  end
end
```

### Indexes Strategy

| Table | Index | Purpose |
|-------|-------|---------|
| sessions | code (unique) | Fast join by code |
| sessions | state | Filter active sessions |
| sessions | expires_at | Cleanup expired sessions |
| sessions | last_activity_at | Identify stale sessions |
| participants | session_id | List session participants |
| participants | session_id, browser_token (unique) | Reconnection lookup |
| scores | session_id, question_id | Get all scores for reveal |
| scores | session_id, participant_id, question_id (unique) | One score per participant per question |

---

## Real-Time Architecture

### PubSub Topics

```elixir
defmodule ProductiveWorkGroups.PubSub.Topics do
  @moduledoc "Centralized topic definitions for PubSub"

  # Session-level events (all participants)
  def session(session_id), do: "session:#{session_id}"

  # Presence tracking
  def presence(session_id), do: "presence:#{session_id}"

  # Timer updates (frequent, separate channel)
  def timer(session_id), do: "timer:#{session_id}"
end
```

### Event Types

```elixir
defmodule ProductiveWorkGroups.PubSub.Events do
  @moduledoc "Event definitions for real-time updates"

  # Session events
  @type session_event ::
    :participant_joined
    | :participant_left
    | :participant_ready
    | :participant_unready
    | :phase_changed
    | :question_changed
    | :scores_revealed
    | :session_ended

  # Scoring events
  @type scoring_event ::
    :score_submitted
    | :score_updated
    | :all_scored

  # Notes events
  @type notes_event ::
    :note_added
    | :note_updated
    | :note_deleted
    | :action_added
    | :action_updated
    | :action_deleted

  # Timer events
  @type timer_event ::
    :timer_started
    | :timer_paused
    | :timer_resumed
    | :timer_tick
    | :timer_exceeded
end
```

### Presence Tracking

```elixir
defmodule ProductiveWorkGroupsWeb.Presence do
  use Phoenix.Presence,
    otp_app: :productive_work_groups,
    pubsub_server: ProductiveWorkGroups.PubSub

  @doc "Track a participant joining a session"
  def track_participant(socket, session_id, participant) do
    track(socket, "presence:#{session_id}", participant.id, %{
      name: participant.name,
      status: participant.status,
      ready: participant.ready,
      joined_at: participant.joined_at
    })
  end

  @doc "Get all present participants for a session"
  def list_participants(session_id) do
    list("presence:#{session_id}")
    |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta end)
  end
end
```

### Broadcast Helper

```elixir
defmodule ProductiveWorkGroups.Broadcaster do
  @moduledoc "Centralized broadcasting for real-time events"

  alias Phoenix.PubSub
  alias ProductiveWorkGroups.PubSub.Topics

  def broadcast_session_event(session_id, event, payload \\ %{}) do
    PubSub.broadcast(
      ProductiveWorkGroups.PubSub,
      Topics.session(session_id),
      {event, payload}
    )
  end

  def broadcast_timer_tick(session_id, time_status) do
    PubSub.broadcast(
      ProductiveWorkGroups.PubSub,
      Topics.timer(session_id),
      {:timer_tick, time_status}
    )
  end
end
```

---

## LiveView Component Structure

### Component Hierarchy

```
WorkshopLive (root)
├── Components/
│   ├── Header
│   │   ├── SessionCode
│   │   ├── TimerDisplay
│   │   └── FacilitatorHelpButton
│   │
│   ├── ParticipantList
│   │   └── ParticipantCard (× n)
│   │
│   ├── Phases/
│   │   ├── LobbyPhase
│   │   │   ├── JoinForm
│   │   │   └── WaitingRoom
│   │   │
│   │   ├── IntroPhase
│   │   │   ├── IntroScreen
│   │   │   └── SkipIntroButton
│   │   │
│   │   ├── ScoringPhase
│   │   │   ├── QuestionCard
│   │   │   ├── ScoreInput (balance or maximal)
│   │   │   ├── ScoreReveal
│   │   │   ├── DiscussionPrompts
│   │   │   └── NotesCapture
│   │   │
│   │   ├── SummaryPhase
│   │   │   ├── ScoreSummaryGrid
│   │   │   └── PatternHighlights
│   │   │
│   │   └── ActionsPhase
│   │       ├── ActionsList
│   │       ├── ActionForm
│   │       └── ActionCard
│   │
│   ├── Shared/
│   │   ├── TrafficLight
│   │   ├── ProgressBar
│   │   ├── ReadyButton
│   │   ├── Modal
│   │   └── Toast
│   │
│   └── FeedbackButton
│
└── Modals/
    ├── FacilitatorHelpModal
    └── FeedbackModal
```

### Component Design Principles

1. **Stateless where possible** - Components receive assigns, parent manages state
2. **Slots for flexibility** - Use slots for customizable content areas
3. **Consistent styling API** - Common props like `class`, `variant`, `size`

### Example Components

```elixir
defmodule ProductiveWorkGroupsWeb.Components.TrafficLight do
  use Phoenix.Component

  @doc """
  Renders a traffic light indicator for a score.

  ## Examples

      <.traffic_light color={:green} />
      <.traffic_light color={:amber} size={:lg} />
  """

  attr :color, :atom, required: true, values: [:green, :amber, :red]
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: nil

  def traffic_light(assigns) do
    ~H"""
    <span class={[
      "inline-block rounded-full",
      size_class(@size),
      color_class(@color),
      @class
    ]} />
    """
  end

  defp size_class(:sm), do: "w-3 h-3"
  defp size_class(:md), do: "w-4 h-4"
  defp size_class(:lg), do: "w-6 h-6"

  defp color_class(:green), do: "bg-green-500"
  defp color_class(:amber), do: "bg-amber-500"
  defp color_class(:red), do: "bg-red-500"
end

defmodule ProductiveWorkGroupsWeb.Components.ScoreInput do
  use Phoenix.Component

  @doc """
  Renders a score input appropriate for the scale type.
  Balance scale: -5 to +5 slider with 0 highlighted
  Maximal scale: 0 to 10 slider
  """

  attr :scale_type, :atom, required: true, values: [:balance, :maximal]
  attr :value, :integer, default: nil
  attr :disabled, :boolean, default: false
  attr :on_change, :any, required: true

  def score_input(%{scale_type: :balance} = assigns) do
    ~H"""
    <div class="score-input balance-scale">
      <input
        type="range"
        min="-5"
        max="5"
        value={@value}
        disabled={@disabled}
        phx-change={@on_change}
        class="w-full"
      />
      <div class="flex justify-between text-sm text-gray-400">
        <span>-5</span>
        <span class="text-green-400">0</span>
        <span>+5</span>
      </div>
    </div>
    """
  end

  def score_input(%{scale_type: :maximal} = assigns) do
    ~H"""
    <div class="score-input maximal-scale">
      <input
        type="range"
        min="0"
        max="10"
        value={@value}
        disabled={@disabled}
        phx-change={@on_change}
        class="w-full"
      />
      <div class="flex justify-between text-sm text-gray-400">
        <span>0</span>
        <span class="text-green-400">10</span>
      </div>
    </div>
    """
  end
end
```

---

## State Management

### Session State Machine

```
                    ┌─────────┐
                    │  lobby  │
                    └────┬────┘
                         │ all participants ready
                         ▼
                    ┌─────────┐
            ┌──────►│  intro  │ (skippable)
            │       └────┬────┘
            │            │ complete intro / skip
            │            ▼
            │       ┌─────────┐
            │       │ scoring │◄───────────┐
            │       └────┬────┘            │
            │            │                 │
            │            ▼                 │
            │    ┌───────────────┐         │
            │    │ question N    │         │
            │    │ ┌───────────┐ │         │
            │    │ │ awaiting  │ │         │
            │    │ │  scores   │ │         │
            │    │ └─────┬─────┘ │         │
            │    │       │ all   │         │
            │    │       ▼ scored│         │
            │    │ ┌───────────┐ │         │
            │    │ │  reveal   │ │         │
            │    │ └─────┬─────┘ │         │
            │    │       │ all   │         │
            │    │       ▼ ready │         │
            │    └───────────────┘         │
            │            │                 │
            │            │ N < 8 ──────────┘
            │            │ N = 8
            │            ▼
            │       ┌─────────┐
            │       │ summary │
            │       └────┬────┘
            │            │ all ready
            │            ▼
            │       ┌─────────┐
            │       │ actions │
            │       └────┬────┘
            │            │ complete
            │            ▼
            │       ┌───────────┐
            └───────│ completed │
                    └───────────┘
```

### LiveView State Structure

```elixir
defmodule ProductiveWorkGroupsWeb.WorkshopLive do
  use ProductiveWorkGroupsWeb, :live_view

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(ProductiveWorkGroups.PubSub, "session:#{session.id}")
      Phoenix.PubSub.subscribe(ProductiveWorkGroups.PubSub, "timer:#{session.id}")

      # Track presence
      ProductiveWorkGroupsWeb.Presence.track_participant(socket, session.id, participant)
    end

    {:ok,
     socket
     |> assign(:session, session)
     |> assign(:participant, participant)
     |> assign(:participants, participants)
     |> assign(:current_phase, session.state)
     |> assign(:current_question, current_question)
     |> assign(:my_score, nil)
     |> assign(:scores, %{})  # question_id => [scores]
     |> assign(:scores_revealed, false)
     |> assign(:time_status, time_status)
     |> assign(:notes, [])
     |> assign(:actions, [])
     |> assign(:show_facilitator_help, false)}
  end

  # State is updated via handle_info callbacks from PubSub
  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    {:noreply, update(socket, :participants, &[participant | &1])}
  end

  def handle_info({:scores_revealed, %{question_id: qid, scores: scores}}, socket) do
    {:noreply,
     socket
     |> assign(:scores_revealed, true)
     |> update(:scores, &Map.put(&1, qid, scores))}
  end

  def handle_info({:timer_tick, time_status}, socket) do
    {:noreply, assign(socket, :time_status, time_status)}
  end
end
```

---

## Security Considerations

### Authentication & Authorization

| Concern | MVP Approach | Future Enhancement |
|---------|--------------|-------------------|
| Session access | Anyone with link can join (before start) | Invite-only option |
| Participant identity | Browser token + name match | Account-based auth |
| Rejoin verification | Browser localStorage token | Login required |
| Score visibility | Team only, never external | Unchanged |

### Input Validation

```elixir
defmodule ProductiveWorkGroups.Scoring do
  def submit_score(participant_id, question_id, value) do
    with {:ok, participant} <- get_active_participant(participant_id),
         {:ok, question} <- Workshops.get_question(question_id),
         :ok <- validate_score_value(value, question),
         :ok <- validate_not_already_locked(participant_id, question_id) do
      # Proceed with score submission
    end
  end

  defp validate_score_value(value, %{scale_type: :balance}) when value in -5..5, do: :ok
  defp validate_score_value(value, %{scale_type: :maximal}) when value in 0..10, do: :ok
  defp validate_score_value(_, _), do: {:error, :invalid_score}
end
```

### Rate Limiting

```elixir
# In endpoint.ex or a plug
plug ProductiveWorkGroupsWeb.Plugs.RateLimiter,
  routes: [
    {"/api/sessions", :create, limit: 10, window: :minute},
    {"/api/feedback", :create, limit: 5, window: :minute}
  ]
```

### Data Sanitization

- All user input (names, notes, actions) sanitized before storage and display
- Phoenix's built-in XSS protection via `~H` sigil
- Content Security Policy headers configured

---

## Error Handling Strategy

### Error Types

```elixir
defmodule ProductiveWorkGroups.Error do
  defexception [:type, :message, :details]

  @type error_type ::
    :not_found
    | :invalid_state
    | :unauthorized
    | :validation_failed
    | :session_expired
    | :session_full
    | :already_exists

  def not_found(resource), do: %__MODULE__{type: :not_found, message: "#{resource} not found"}
  def invalid_state(msg), do: %__MODULE__{type: :invalid_state, message: msg}
  def session_expired(), do: %__MODULE__{type: :session_expired, message: "Session has expired"}
end
```

### Context Error Handling

```elixir
defmodule ProductiveWorkGroups.Sessions do
  def join_session(session_id, name) do
    with {:ok, session} <- get_active_session(session_id),
         :ok <- validate_can_join(session),
         :ok <- validate_participant_limit(session),
         {:ok, participant} <- create_participant(session, name) do
      broadcast_participant_joined(session_id, participant)
      {:ok, participant}
    else
      {:error, :session_not_found} -> {:error, Error.not_found("Session")}
      {:error, :session_started} -> {:error, Error.invalid_state("Session already started")}
      {:error, :session_full} -> {:error, Error.session_full()}
      error -> error
    end
  end
end
```

### LiveView Error Display

```elixir
defmodule ProductiveWorkGroupsWeb.WorkshopLive do
  def handle_info({:error, %Error{} = error}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, error.message)
     |> maybe_redirect(error)}
  end

  defp maybe_redirect(socket, %Error{type: :session_expired}) do
    push_navigate(socket, to: ~p"/")
  end
  defp maybe_redirect(socket, _), do: socket
end
```

### Connection Recovery

```elixir
defmodule ProductiveWorkGroupsWeb.WorkshopLive do
  # Automatic reconnection handling
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Re-sync state after reconnection
    {:noreply, reload_session_state(socket)}
  end

  defp reload_session_state(socket) do
    session = Sessions.get_session!(socket.assigns.session.id)

    socket
    |> assign(:session, session)
    |> assign(:participants, Sessions.get_active_participants(session.id))
    |> assign(:scores, Scoring.get_all_session_scores(session.id))
  end
end
```

---

## Testing Strategy

### Test Pyramid

```
                    ┌─────────┐
                    │   E2E   │  Few, critical paths
                    │  Tests  │  (Wallaby/Playwright)
                    └────┬────┘
                         │
              ┌──────────┴──────────┐
              │   Integration Tests │  LiveView, PubSub
              │                     │  (Phoenix.LiveViewTest)
              └──────────┬──────────┘
                         │
         ┌───────────────┴───────────────┐
         │         Unit Tests            │  Contexts, Schemas
         │                               │  (ExUnit)
         └───────────────────────────────┘
```

### Context Testing

```elixir
defmodule ProductiveWorkGroups.ScoringTest do
  use ProductiveWorkGroups.DataCase

  alias ProductiveWorkGroups.Scoring

  describe "submit_score/3" do
    setup do
      session = insert(:session)
      participant = insert(:participant, session: session)
      question = insert(:question, scale_type: :balance)

      %{session: session, participant: participant, question: question}
    end

    test "creates score with valid balance value", ctx do
      assert {:ok, score} = Scoring.submit_score(ctx.participant.id, ctx.question.id, 0)
      assert score.value == 0
    end

    test "rejects out of range balance value", ctx do
      assert {:error, :invalid_score} = Scoring.submit_score(ctx.participant.id, ctx.question.id, 6)
    end

    test "broadcasts score_submitted event", ctx do
      Phoenix.PubSub.subscribe(ProductiveWorkGroups.PubSub, "session:#{ctx.session.id}")

      {:ok, _} = Scoring.submit_score(ctx.participant.id, ctx.question.id, 3)

      assert_receive {:score_submitted, %{participant_id: pid}}
      assert pid == ctx.participant.id
    end
  end
end
```

### LiveView Testing

```elixir
defmodule ProductiveWorkGroupsWeb.WorkshopLiveTest do
  use ProductiveWorkGroupsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "scoring phase" do
    setup do
      session = insert(:session, state: :scoring, current_question: 1)
      participant = insert(:participant, session: session)

      %{session: session, participant: participant}
    end

    test "displays current question", %{conn: conn, session: session, participant: participant} do
      {:ok, view, _html} =
        conn
        |> init_test_session(participant)
        |> live(~p"/workshop/#{session.code}")

      assert has_element?(view, "[data-question-number='1']")
      assert has_element?(view, ".score-input")
    end

    test "submitting score updates UI", %{conn: conn, session: session, participant: participant} do
      {:ok, view, _html} =
        conn
        |> init_test_session(participant)
        |> live(~p"/workshop/#{session.code}")

      view
      |> element(".score-input")
      |> render_change(%{value: "3"})

      view
      |> element("button", "Submit Score")
      |> render_click()

      assert has_element?(view, ".score-submitted-indicator")
    end
  end
end
```

### Factory Pattern

```elixir
defmodule ProductiveWorkGroups.Factory do
  use ExMachina.Ecto, repo: ProductiveWorkGroups.Repo

  def session_factory do
    %ProductiveWorkGroups.Sessions.Session{
      code: sequence(:code, &"TEST#{&1}"),
      state: :lobby,
      template: build(:template),
      settings: %{total_duration_minutes: 210, max_participants: 20}
    }
  end

  def participant_factory do
    %ProductiveWorkGroups.Sessions.Participant{
      name: sequence(:name, &"Participant #{&1}"),
      browser_token: Ecto.UUID.generate(),
      status: :active,
      session: build(:session)
    }
  end

  def score_factory do
    %ProductiveWorkGroups.Scoring.Score{
      value: Enum.random(-5..5),
      locked: false,
      session: build(:session),
      participant: build(:participant),
      question: build(:question)
    }
  end
end
```

---

## Deployment Architecture

### Fly.io Configuration

```toml
# fly.toml
app = "productive-work-groups"
primary_region = "syd"  # Sydney for AU-based teams

[build]
  [build.args]
    MIX_ENV = "prod"

[env]
  PHX_HOST = "productiveworkgroups.fly.dev"
  PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

  [http_service.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 800

[[services]]
  protocol = "tcp"
  internal_port = 8080

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 512

[deploy]
  release_command = "/app/bin/migrate"
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix secret key |
| `PHX_HOST` | Public hostname |
| `POOL_SIZE` | DB connection pool size |

### Release Configuration

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL not set"

  config :productive_work_groups, ProductiveWorkGroups.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE not set"

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :productive_work_groups, ProductiveWorkGroupsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [port: port],
    secret_key_base: secret_key_base,
    server: true
end
```

### Database Backups

- Fly.io Postgres includes daily automatic backups
- Point-in-time recovery available
- Manual backup before major deployments

---

## Appendix: Six Criteria Workshop Data

### Template Seed Data

```elixir
defmodule ProductiveWorkGroups.Seeds.SixCriteria do
  alias ProductiveWorkGroups.Repo
  alias ProductiveWorkGroups.Workshops.{Template, Question}

  def seed! do
    template = Repo.insert!(%Template{
      id: "six-criteria-v1",
      name: "Six Criteria of Productive Work",
      description: "Based on research by Drs Fred & Merrelyn Emery",
      version: "1.0"
    })

    questions = [
      %{
        number: 1,
        title: "Elbow Room",
        short_title: "Elbow Room",
        scale_type: :balance,
        scale_min: -5,
        scale_max: 5,
        optimal_value: 0,
        explanation: "The ability to make decisions about how you do your work...",
        discussion_prompts: [
          "There's a spread in scores here. What might be behind the different experiences?",
          "What would need to change for scores to improve?"
        ]
      },
      # ... remaining 7 questions
    ]

    for q <- questions do
      Repo.insert!(%Question{template_id: template.id} |> Map.merge(q))
    end
  end
end
```

### Time Allocation Defaults

```elixir
defmodule ProductiveWorkGroups.Facilitation.TimeAllocations do
  @default_percentages %{
    introduction: 0.05,
    questions_1_4: 0.35,
    mid_transition: 0.02,
    questions_5_8: 0.35,
    summary: 0.08,
    actions: 0.12,
    buffer: 0.03
  }

  def calculate(total_minutes) do
    for {section, pct} <- @default_percentages, into: %{} do
      {section, round(total_minutes * pct)}
    end
  end

  def per_question_minutes(total_minutes) do
    question_time = total_minutes * 0.35  # Each question block
    round(question_time / 4)  # 4 questions per block
  end
end
```

---

*Document Version: 1.1*
*Last Updated: 2026-01-29*
