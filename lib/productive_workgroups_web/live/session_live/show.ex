defmodule ProductiveWorkgroupsWeb.SessionLive.Show do
  @moduledoc """
  Main workshop LiveView - handles the full workshop flow.
  """
  use ProductiveWorkgroupsWeb, :live_view

  alias ProductiveWorkgroups.Sessions

  @impl true
  def mount(%{"code" => code}, session, socket) do
    browser_token = session["browser_token"]

    case Sessions.get_session_by_code(code) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found. Please check the code and try again.")
         |> redirect(to: ~p"/")}

      workshop_session ->
        if browser_token do
          participant = Sessions.get_participant_by_token(workshop_session, browser_token)

          if participant do
            if connected?(socket) do
              # Subscribe to session updates
              Sessions.subscribe(workshop_session)
            end

            # Load all participants for the lobby
            participants = Sessions.list_participants(workshop_session)

            {:ok,
             socket
             |> assign(page_title: "Workshop Session")
             |> assign(session: workshop_session)
             |> assign(participant: participant)
             |> assign(participants: participants)}
          else
            # Browser token doesn't match any participant - redirect to join
            {:ok,
             socket
             |> redirect(to: ~p"/session/#{code}/join")}
          end
        else
          # No browser token - redirect to join
          {:ok,
           socket
           |> redirect(to: ~p"/session/#{code}/join")}
        end
    end
  end

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    # Avoid duplicates by checking if participant already exists
    participants = socket.assigns.participants

    if Enum.any?(participants, &(&1.id == participant.id)) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, participants: participants ++ [participant])}
    end
  end

  @impl true
  def handle_info({:participant_left, participant_id}, socket) do
    participants =
      Enum.reject(socket.assigns.participants, fn p -> p.id == participant_id end)

    {:noreply, assign(socket, participants: participants)}
  end

  @impl true
  def handle_info({:participant_updated, participant}, socket) do
    participants =
      Enum.map(socket.assigns.participants, fn p ->
        if p.id == participant.id, do: participant, else: p
      end)

    {:noreply, assign(socket, participants: participants)}
  end

  @impl true
  def handle_info({:participant_ready, participant}, socket) do
    participants =
      Enum.map(socket.assigns.participants, fn p ->
        if p.id == participant.id, do: participant, else: p
      end)

    {:noreply, assign(socket, participants: participants)}
  end

  @impl true
  def handle_info({:session_started, session}, socket) do
    {:noreply, assign(socket, session: session)}
  end

  @impl true
  def handle_info({:session_updated, session}, socket) do
    {:noreply, assign(socket, session: session)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900">
      <%= case @session.state do %>
        <% "lobby" -> %>
          {render_lobby(assigns)}
        <% "intro" -> %>
          {render_intro(assigns)}
        <% "scoring" -> %>
          {render_scoring(assigns)}
        <% "summary" -> %>
          {render_summary(assigns)}
        <% "actions" -> %>
          {render_actions(assigns)}
        <% "completed" -> %>
          {render_completed(assigns)}
        <% _ -> %>
          {render_lobby(assigns)}
      <% end %>
    </div>
    """
  end

  defp render_lobby(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-lg w-full text-center">
        <h1 class="text-3xl font-bold text-white mb-2">Waiting Room</h1>
        <p class="text-gray-400 mb-8">
          Session code: <span class="font-mono text-white font-bold text-xl">{@session.code}</span>
        </p>

        <div class="bg-gray-800 rounded-lg p-6 mb-6">
          <h2 class="text-lg font-semibold text-white mb-4">Participants</h2>
          <ul class="space-y-2">
            <%= for p <- @participants do %>
              <li class="flex items-center justify-between bg-gray-700 rounded-lg px-4 py-3">
                <span class="text-white">{p.name}</span>
                <%= if p.id == @participant.id do %>
                  <span class="text-xs bg-blue-600 text-white px-2 py-1 rounded">You</span>
                <% end %>
              </li>
            <% end %>
          </ul>
        </div>

        <p class="text-gray-500 text-sm">
          Waiting for the facilitator to start the workshop...
        </p>
      </div>
    </div>
    """
  end

  defp render_intro(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-2xl w-full text-center">
        <h1 class="text-3xl font-bold text-white mb-4">Welcome to the Workshop</h1>
        <p class="text-gray-400">Introduction phase coming soon...</p>
      </div>
    </div>
    """
  end

  defp render_scoring(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-2xl w-full text-center">
        <h1 class="text-3xl font-bold text-white mb-4">Scoring Phase</h1>
        <p class="text-gray-400">Scoring interface coming soon...</p>
      </div>
    </div>
    """
  end

  defp render_summary(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-2xl w-full text-center">
        <h1 class="text-3xl font-bold text-white mb-4">Summary</h1>
        <p class="text-gray-400">Summary view coming soon...</p>
      </div>
    </div>
    """
  end

  defp render_actions(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-2xl w-full text-center">
        <h1 class="text-3xl font-bold text-white mb-4">Action Items</h1>
        <p class="text-gray-400">Actions interface coming soon...</p>
      </div>
    </div>
    """
  end

  defp render_completed(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-2xl w-full text-center">
        <h1 class="text-3xl font-bold text-white mb-4">Workshop Complete</h1>
        <p class="text-gray-400">Thank you for participating!</p>
      </div>
    </div>
    """
  end
end
