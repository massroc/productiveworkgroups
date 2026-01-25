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
             |> assign(participants: participants)
             |> assign(intro_step: 1)}
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
  def handle_event("start_workshop", _params, socket) do
    session = socket.assigns.session
    participant = socket.assigns.participant

    if participant.is_facilitator do
      case Sessions.start_session(session) do
        {:ok, updated_session} ->
          {:noreply, assign(socket, session: updated_session)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to start workshop")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("intro_next", _params, socket) do
    current_step = socket.assigns.intro_step
    {:noreply, assign(socket, intro_step: min(current_step + 1, 4))}
  end

  @impl true
  def handle_event("intro_prev", _params, socket) do
    current_step = socket.assigns.intro_step
    {:noreply, assign(socket, intro_step: max(current_step - 1, 1))}
  end

  @impl true
  def handle_event("skip_intro", _params, socket) do
    {:noreply, assign(socket, intro_step: 4)}
  end

  @impl true
  def handle_event("continue_to_scoring", _params, socket) do
    session = socket.assigns.session
    participant = socket.assigns.participant

    if participant.is_facilitator do
      case Sessions.advance_to_scoring(session) do
        {:ok, updated_session} ->
          {:noreply, assign(socket, session: updated_session)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to advance to scoring")}
      end
    else
      {:noreply, socket}
    end
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
        <p class="text-gray-400 mb-4">
          Share this code with your team:
        </p>
        <p class="font-mono text-white font-bold text-4xl mb-8 tracking-wider">
          {@session.code}
        </p>

        <div class="bg-gray-800 rounded-lg p-6 mb-6">
          <h2 class="text-lg font-semibold text-white mb-4">
            Participants ({length(@participants)})
          </h2>
          <ul class="space-y-2">
            <%= for p <- @participants do %>
              <li class="flex items-center justify-between bg-gray-700 rounded-lg px-4 py-3">
                <div class="flex items-center gap-2">
                  <span class="text-white">{p.name}</span>
                  <%= if p.is_facilitator do %>
                    <span class="text-xs bg-purple-600 text-white px-2 py-1 rounded">
                      Facilitator
                    </span>
                  <% end %>
                </div>
                <%= if p.id == @participant.id do %>
                  <span class="text-xs bg-blue-600 text-white px-2 py-1 rounded">You</span>
                <% end %>
              </li>
            <% end %>
          </ul>
        </div>

        <%= if @participant.is_facilitator do %>
          <button
            phx-click="start_workshop"
            class="w-full px-6 py-4 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors text-lg mb-4"
          >
            Start Workshop
          </button>
          <p class="text-gray-500 text-sm">
            Click above when everyone has joined.
          </p>
        <% else %>
          <p class="text-gray-500 text-sm">
            Waiting for the facilitator to start the workshop...
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_intro(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-2xl w-full">
        <%= case @intro_step do %>
          <% 1 -> %>
            {render_intro_welcome(assigns)}
          <% 2 -> %>
            {render_intro_how_it_works(assigns)}
          <% 3 -> %>
            {render_intro_balance_scale(assigns)}
          <% 4 -> %>
            {render_intro_safe_space(assigns)}
          <% _ -> %>
            {render_intro_welcome(assigns)}
        <% end %>

        <div class="flex items-center justify-between mt-8">
          <div>
            <%= if @intro_step > 1 do %>
              <button
                phx-click="intro_prev"
                class="px-4 py-2 text-gray-400 hover:text-white transition-colors"
              >
                ← Back
              </button>
            <% else %>
              <div></div>
            <% end %>
          </div>

          <div class="flex items-center gap-2">
            <%= for step <- 1..4 do %>
              <div class={[
                "w-2 h-2 rounded-full",
                if(step == @intro_step, do: "bg-green-500", else: "bg-gray-600")
              ]} />
            <% end %>
          </div>

          <div>
            <%= if @intro_step < 4 do %>
              <div class="flex items-center gap-4">
                <%= if @participant.is_facilitator and @intro_step == 1 do %>
                  <button
                    phx-click="skip_intro"
                    class="px-4 py-2 text-gray-500 hover:text-gray-300 text-sm transition-colors"
                  >
                    Skip intro
                  </button>
                <% end %>
                <button
                  phx-click="intro_next"
                  class="px-6 py-2 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
                >
                  Next →
                </button>
              </div>
            <% else %>
              <%= if @participant.is_facilitator do %>
                <button
                  phx-click="continue_to_scoring"
                  class="px-6 py-3 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
                >
                  Begin Scoring →
                </button>
              <% else %>
                <span class="text-gray-500 text-sm">Waiting for facilitator...</span>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_intro_welcome(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-3xl font-bold text-white mb-6">Welcome to the Six Criteria Workshop</h1>
      <div class="text-gray-300 space-y-4 text-lg">
        <p>
          This workshop helps your team have a meaningful conversation about what makes work engaging and productive.
        </p>
        <p>
          Based on forty years of research by Fred and Merrelyn Emery, the Six Criteria are the psychological factors that determine whether work is motivating or draining.
        </p>
        <p class="italic text-gray-400 border-l-4 border-green-600 pl-4 text-left">
          "If you don't get these criteria right, there will not be the human interest to see the job through."
          <span class="block text-sm mt-1 not-italic">— Fred Emery</span>
        </p>
      </div>
    </div>
    """
  end

  defp render_intro_how_it_works(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-3xl font-bold text-white mb-6">How This Workshop Works</h1>
      <div class="text-gray-300 space-y-4 text-lg text-left">
        <p>You'll work through 8 questions covering 6 criteria together as a team.</p>
        <p class="font-semibold text-white">For each question:</p>
        <ol class="list-decimal list-inside space-y-2 pl-4">
          <li>Everyone scores independently (your score stays hidden)</li>
          <li>Once everyone has submitted, all scores are revealed</li>
          <li>You discuss what you see — especially any differences</li>
          <li>When ready, you move to the next question</li>
        </ol>
        <p class="text-gray-400 mt-6">
          The goal isn't to "fix" scores — it's to
          <span class="text-white font-semibold">surface and understand</span>
          different experiences within your team.
        </p>
      </div>
    </div>
    """
  end

  defp render_intro_balance_scale(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-3xl font-bold text-white mb-6">Understanding the Balance Scale</h1>
      <div class="text-gray-300 space-y-4 text-lg text-left">
        <p>
          The first four questions use a <span class="text-white font-semibold">balance scale</span>
          from -5 to +5:
        </p>

        <div class="bg-gray-800 rounded-lg p-6 my-6">
          <div class="flex justify-between items-center mb-4">
            <span class="text-red-400 font-semibold">-5</span>
            <span class="text-green-400 font-semibold text-xl">0</span>
            <span class="text-red-400 font-semibold">+5</span>
          </div>
          <div class="flex justify-between items-center text-sm text-gray-400">
            <span>Too little</span>
            <span>Just right</span>
            <span>Too much</span>
          </div>
        </div>

        <ul class="space-y-2 pl-4">
          <li>• These criteria need the right amount — not too much, not too little</li>
          <li>• <span class="text-green-400 font-semibold">0 is optimal</span> (balanced)</li>
          <li>• Negative means too little, positive means too much</li>
        </ul>

        <p class="text-gray-400 mt-4">
          Don't overthink — go with your gut feeling about your current experience.
        </p>
      </div>
    </div>
    """
  end

  defp render_intro_safe_space(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-3xl font-bold text-white mb-6">Creating a Safe Space</h1>
      <div class="text-gray-300 space-y-4 text-lg text-left">
        <p>
          This workshop operates under the <span class="text-white font-semibold">Prime Directive</span>:
        </p>

        <blockquote class="italic text-gray-400 border-l-4 border-purple-600 pl-4 my-6">
          "Regardless of what we discover, we understand and truly believe that everyone did the best job they could, given what they knew at the time, their skills and abilities, the resources available, and the situation at hand."
        </blockquote>

        <p>
          Your scores reflect the <span class="text-white">system and environment</span>
          — not individual failings. Low scores aren't accusations; they're opportunities to improve how work is structured.
        </p>

        <ul class="space-y-2 pl-4 mt-4">
          <li>
            • <span class="text-white">Be honest</span>
            — this only works if people share their real experience
          </li>
          <li>• There are no right or wrong scores</li>
          <li>• Differences are expected — they reveal different experiences</li>
          <li>• Your individual scores are visible only to this team</li>
        </ul>

        <div class="bg-gray-800 rounded-lg p-4 mt-6 text-center">
          <p class="text-white font-semibold">Ready?</p>
          <p class="text-gray-400 text-sm mt-1">
            When everyone is ready, the facilitator will begin scoring.
          </p>
        </div>
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
