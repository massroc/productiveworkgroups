defmodule ProductiveWorkgroupsWeb.SessionLive.New do
  @moduledoc """
  LiveView for creating a new workshop session.
  """
  use ProductiveWorkgroupsWeb, :live_view

  alias ProductiveWorkgroups.{Workshops, Sessions}

  @impl true
  def mount(_params, _session, socket) do
    template = Workshops.get_template_by_slug("six-criteria")

    changeset = session_changeset(%{planned_duration_minutes: template && template.default_duration_minutes})

    {:ok,
     socket
     |> assign(page_title: "Create Workshop")
     |> assign(template: template)
     |> assign(form: to_form(changeset, as: :session))}
  end

  @impl true
  def handle_event("create_session", %{"session" => params}, socket) do
    template = socket.assigns.template

    case template do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Workshop template not found. Please contact support.")}

      template ->
        case Sessions.create_session(template, params) do
          {:ok, session} ->
            {:noreply,
             socket
             |> push_navigate(to: ~p"/session/#{session.code}/join")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to create session. Please try again.")}
        end
    end
  end

  defp session_changeset(attrs) do
    types = %{planned_duration_minutes: :integer}

    {%{}, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex flex-col items-center justify-center px-4">
      <div class="max-w-md w-full">
        <.link navigate={~p"/"} class="text-gray-400 hover:text-white mb-8 inline-flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
          </svg>
          Back to Home
        </.link>

        <h1 class="text-2xl font-bold text-white mb-2 text-center">
          Create New Workshop
        </h1>
        <p class="text-gray-400 text-center mb-8">
          Set up your Six Criteria workshop session
        </p>

        <.form for={@form} id="session-form" phx-submit="create_session" class="space-y-6">
          <div>
            <label for="planned_duration_minutes" class="block text-sm font-medium text-gray-300 mb-2">
              Planned Duration
            </label>
            <select
              name="session[planned_duration_minutes]"
              id="planned_duration_minutes"
              class="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-3 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="60">1 hour (Quick session)</option>
              <option value="120">2 hours (Focused session)</option>
              <option value="210" selected>3.5 hours (Recommended)</option>
              <option value="240">4 hours (Half day)</option>
              <option value="360">6 hours (Full day)</option>
            </select>
            <p class="mt-2 text-sm text-gray-500">
              Choose based on your team's experience. First-time teams should allow more time.
            </p>
          </div>

          <button
            type="submit"
            class="w-full px-6 py-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors text-lg"
          >
            Start Workshop
          </button>
        </.form>

        <p class="text-gray-500 text-sm text-center mt-6">
          After creating, you'll get a link to share with your team.
        </p>
      </div>
    </div>
    """
  end
end
