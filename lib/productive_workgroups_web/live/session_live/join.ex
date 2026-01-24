defmodule ProductiveWorkgroupsWeb.SessionLive.Join do
  @moduledoc """
  LiveView for joining an existing workshop session.
  """
  use ProductiveWorkgroupsWeb, :live_view

  alias ProductiveWorkgroups.Sessions

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    case Sessions.get_session_by_code(code) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found. Please check the code and try again.")
         |> redirect(to: ~p"/")}

      session ->
        changeset = participant_changeset(%{})

        {:ok,
         socket
         |> assign(page_title: "Join Workshop")
         |> assign(session: session)
         |> assign(form: to_form(changeset, as: :participant))}
    end
  end

  @impl true
  def handle_event("validate", %{"participant" => params}, socket) do
    changeset =
      participant_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :participant))}
  end

  defp participant_changeset(attrs) do
    types = %{name: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> Ecto.Changeset.validate_required([:name], message: "Name is required")
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
          Join Workshop
        </h1>
        <p class="text-gray-400 text-center mb-8">
          Session code: <span class="font-mono text-white font-bold">{@session.code}</span>
        </p>

        <form id="join-form" action={~p"/session/#{@session.code}/join"} method="post" class="space-y-6">
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <div>
            <label for="participant_name" class="block text-sm font-medium text-gray-300 mb-2">
              Your Name
            </label>
            <input
              type="text"
              name="participant[name]"
              id="participant_name"
              value={@form[:name].value}
              placeholder="Enter your name"
              class="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              autofocus
            />
            <%= if @form[:name].errors != [] do %>
              <p class="mt-2 text-sm text-red-400">
                <%= for {msg, _opts} <- @form[:name].errors do %>
                  {msg}
                <% end %>
              </p>
            <% end %>
          </div>

          <button
            type="submit"
            class="w-full px-6 py-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors text-lg"
          >
            Join Workshop
          </button>
        </form>

        <p class="text-gray-500 text-sm text-center mt-6">
          You'll be able to participate once the facilitator starts the session.
        </p>
      </div>
    </div>
    """
  end
end
