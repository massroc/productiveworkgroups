defmodule ProductiveWorkgroupsWeb.SessionLive.Show do
  @moduledoc """
  Main workshop LiveView - handles the full workshop flow.
  """
  use ProductiveWorkgroupsWeb, :live_view

  alias ProductiveWorkgroups.Notes
  alias ProductiveWorkgroups.Scoring
  alias ProductiveWorkgroups.Sessions
  alias ProductiveWorkgroups.Workshops

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
        mount_with_session(socket, workshop_session, browser_token, code)
    end
  end

  defp mount_with_session(socket, workshop_session, nil, code) do
    {:ok, redirect(socket, to: ~p"/session/#{code}/join")}
  end

  defp mount_with_session(socket, workshop_session, browser_token, code) do
    participant = Sessions.get_participant_by_token(workshop_session, browser_token)
    mount_with_participant(socket, workshop_session, participant, code)
  end

  defp mount_with_participant(socket, _workshop_session, nil, code) do
    {:ok, redirect(socket, to: ~p"/session/#{code}/join")}
  end

  defp mount_with_participant(socket, workshop_session, participant, _code) do
    if connected?(socket), do: Sessions.subscribe(workshop_session)

    participants = Sessions.list_participants(workshop_session)

    {:ok,
     socket
     |> assign(page_title: "Workshop Session")
     |> assign(session: workshop_session)
     |> assign(participant: participant)
     |> assign(participants: participants)
     |> assign(intro_step: 1)
     |> assign(show_mid_transition: false)
     |> assign(note_input: "")
     |> load_scoring_data(workshop_session, participant)}
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

  # Handle score submission broadcast from other participants
  @impl true
  def handle_info({:score_submitted, _participant_id, question_index}, socket) do
    session = socket.assigns.session

    if session.state == "scoring" and session.current_question_index == question_index do
      {:noreply, load_scores(socket, session, question_index)}
    else
      {:noreply, socket}
    end
  end

  # Handle note updates from other participants
  @impl true
  def handle_info({:note_updated, question_index}, socket) do
    session = socket.assigns.session

    if session.state == "scoring" and session.current_question_index == question_index do
      {:noreply, load_notes(socket, session, question_index)}
    else
      {:noreply, socket}
    end
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
          {:noreply,
           socket
           |> assign(session: updated_session)
           |> load_scoring_data(updated_session, participant)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to advance to scoring")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_score", params, socket) do
    score = params["score"] || params["value"]

    int_value =
      cond do
        is_integer(score) -> score
        is_binary(score) and score != "" -> String.to_integer(score)
        true -> nil
      end

    if int_value do
      {:noreply, assign(socket, selected_value: int_value)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_score", _params, socket) do
    submit_score(socket, socket.assigns.selected_value)
  end

  defp submit_score(socket, nil) do
    {:noreply, put_flash(socket, :error, "Please select a score first")}
  end

  defp submit_score(socket, selected_value) do
    session = socket.assigns.session
    participant = socket.assigns.participant
    question_index = session.current_question_index

    case Scoring.submit_score(session, participant, question_index, selected_value) do
      {:ok, _score} ->
        maybe_reveal_scores(session, question_index)
        broadcast_score_update(session, participant.id, question_index)

        {:noreply,
         socket
         |> assign(my_score: selected_value)
         |> assign(has_submitted: true)
         |> load_scores(session, question_index)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to submit score")}
    end
  end

  defp maybe_reveal_scores(session, question_index) do
    if Scoring.all_scored?(session, question_index) do
      Scoring.reveal_scores(session, question_index)
    end
  end

  defp broadcast_score_update(session, participant_id, question_index) do
    Phoenix.PubSub.broadcast(
      ProductiveWorkgroups.PubSub,
      Sessions.session_topic(session),
      {:score_submitted, participant_id, question_index}
    )
  end

  @impl true
  def handle_event("mark_ready", _params, socket) do
    participant = socket.assigns.participant

    case Sessions.set_participant_ready(participant, true) do
      {:ok, updated_participant} ->
        {:noreply, assign(socket, participant: updated_participant)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to mark as ready")}
    end
  end

  # Note handling events
  @impl true
  def handle_event("update_note_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, note_input: value)}
  end

  @impl true
  def handle_event("add_note", _params, socket) do
    content = String.trim(socket.assigns.note_input)

    if content == "" do
      {:noreply, socket}
    else
      session = socket.assigns.session
      participant = socket.assigns.participant
      question_index = session.current_question_index

      attrs = %{content: content, author_name: participant.name}

      case Notes.create_note(session, question_index, attrs) do
        {:ok, _note} ->
          broadcast_note_update(session, question_index)

          {:noreply,
           socket
           |> assign(note_input: "")
           |> load_notes(session, question_index)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to add note")}
      end
    end
  end

  @impl true
  def handle_event("delete_note", %{"id" => note_id}, socket) do
    session = socket.assigns.session
    question_index = session.current_question_index

    note = Enum.find(socket.assigns.question_notes, &(&1.id == note_id))

    if note do
      case Notes.delete_note(note) do
        {:ok, _} ->
          broadcast_note_update(session, question_index)
          {:noreply, load_notes(socket, session, question_index)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete note")}
      end
    else
      {:noreply, socket}
    end
  end

  defp broadcast_note_update(session, question_index) do
    Phoenix.PubSub.broadcast(
      ProductiveWorkgroups.PubSub,
      Sessions.session_topic(session),
      {:note_updated, question_index}
    )
  end

  # Mid-workshop transition event
  @impl true
  def handle_event("continue_past_transition", _params, socket) do
    {:noreply, assign(socket, show_mid_transition: false)}
  end

  @impl true
  def handle_event("next_question", _params, socket) do
    advance_to_next_question(socket, socket.assigns.participant.is_facilitator)
  end

  defp advance_to_next_question(socket, false), do: {:noreply, socket}

  defp advance_to_next_question(socket, true) do
    session = socket.assigns.session
    Sessions.reset_all_ready(session)

    template = Workshops.get_template_with_questions(session.template_id)
    is_last_question = session.current_question_index + 1 >= length(template.questions)

    do_advance(socket, session, is_last_question)
  end

  defp do_advance(socket, session, true) do
    case Sessions.advance_to_summary(session) do
      {:ok, updated_session} ->
        {:noreply, assign(socket, session: updated_session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to advance to summary")}
    end
  end

  defp do_advance(socket, session, false) do
    participant = socket.assigns.participant
    current_index = session.current_question_index

    # Show mid-workshop transition when moving from question 4 (index 3) to question 5 (index 4)
    show_transition = current_index == 3

    case Sessions.advance_question(session) do
      {:ok, updated_session} ->
        {:noreply,
         socket
         |> assign(session: updated_session)
         |> assign(show_mid_transition: show_transition)
         |> load_scoring_data(updated_session, participant)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to advance to next question")}
    end
  end

  # Scoring data helpers

  defp load_scoring_data(socket, session, participant) do
    if session.state == "scoring" do
      template = Workshops.get_template_with_questions(session.template_id)
      question_index = session.current_question_index
      question = Enum.find(template.questions, &(&1.index == question_index))

      my_score = Scoring.get_score(session, participant, question_index)

      socket
      |> assign(template: template)
      |> assign(current_question: question)
      |> assign(selected_value: if(my_score, do: my_score.value, else: nil))
      |> assign(my_score: if(my_score, do: my_score.value, else: nil))
      |> assign(has_submitted: my_score != nil)
      |> load_scores(session, question_index)
      |> load_notes(session, question_index)
    else
      socket
      |> assign(template: nil)
      |> assign(current_question: nil)
      |> assign(selected_value: nil)
      |> assign(my_score: nil)
      |> assign(has_submitted: false)
      |> assign(all_scores: [])
      |> assign(scores_revealed: false)
      |> assign(score_count: 0)
      |> assign(active_participant_count: 0)
      |> assign(question_notes: [])
    end
  end

  defp load_scores(socket, session, question_index) do
    scores = Scoring.list_scores_for_question(session, question_index)
    all_scored = Scoring.all_scored?(session, question_index)
    participants = socket.assigns.participants

    active_count =
      Enum.count(participants, fn p -> p.status == "active" end)

    # Get scores with participant names
    scores_with_names =
      Enum.map(scores, fn score ->
        participant = Enum.find(participants, &(&1.id == score.participant_id))

        %{
          value: score.value,
          participant_name: if(participant, do: participant.name, else: "Unknown"),
          participant_id: score.participant_id,
          color: get_score_color(socket.assigns[:current_question], score.value)
        }
      end)

    socket
    |> assign(all_scores: scores_with_names)
    |> assign(scores_revealed: all_scored)
    |> assign(score_count: length(scores))
    |> assign(active_participant_count: active_count)
  end

  defp load_notes(socket, session, question_index) do
    notes = Notes.list_notes_for_question(session, question_index)
    assign(socket, question_notes: notes)
  end

  defp get_score_color(nil, _value), do: :gray

  defp get_score_color(question, value) do
    Scoring.traffic_light_color(question.scale_type, value, question.optimal_value)
  end

  defp calculate_average([]), do: 0

  defp calculate_average(values) do
    Float.round(Enum.sum(values) / length(values), 1)
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
    <%= if @show_mid_transition do %>
      {render_mid_transition(assigns)}
    <% else %>
      <div class="flex flex-col items-center min-h-screen px-4 py-8">
        <div class="max-w-2xl w-full">
          <!-- Progress indicator -->
          <div class="mb-6">
            <div class="flex justify-between items-center text-sm text-gray-400 mb-2">
              <span>Question {@session.current_question_index + 1} of 8</span>
              <span>{@score_count}/{@active_participant_count} submitted</span>
            </div>
            <div class="w-full bg-gray-700 rounded-full h-2">
              <div
                class="bg-green-500 h-2 rounded-full transition-all duration-300"
                style={"width: #{(@session.current_question_index + 1) / 8 * 100}%"}
              />
            </div>
          </div>
          
    <!-- Question card -->
          <div class="bg-gray-800 rounded-lg p-6 mb-6">
            <div class="text-sm text-green-400 mb-2">{@current_question.criterion_name}</div>
            <h1 class="text-2xl font-bold text-white mb-4">{@current_question.title}</h1>
            <p class="text-gray-300 whitespace-pre-line">{@current_question.explanation}</p>
          </div>

          <%= if @scores_revealed do %>
            {render_score_results(assigns)}
          <% else %>
            {render_score_input(assigns)}
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_mid_transition(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-2xl w-full text-center">
        <div class="bg-gray-800 rounded-lg p-8">
          <div class="text-6xl mb-4">🔄</div>
          <h1 class="text-3xl font-bold text-white mb-6">New Scoring Scale Ahead</h1>

          <div class="text-gray-300 space-y-4 text-lg text-left">
            <p class="text-center">
              Great progress! You've completed the first four questions.
            </p>

            <div class="bg-gray-700 rounded-lg p-6 my-6">
              <p class="text-white font-semibold mb-3">
                The next four questions use a different scale:
              </p>
              <div class="flex justify-between items-center mb-4">
                <span class="text-gray-400">0</span>
                <span class="text-green-400 font-semibold text-xl">→</span>
                <span class="text-green-400 font-semibold">10</span>
              </div>
              <ul class="space-y-2 text-gray-300">
                <li>
                  • For these, <span class="text-green-400 font-semibold">more is always better</span>
                </li>
                <li>• <span class="text-green-400 font-semibold">10 is optimal</span></li>
              </ul>
            </div>

            <p class="text-gray-400 text-center">
              These measure aspects of work where you can never have too much.
            </p>
          </div>

          <button
            phx-click="continue_past_transition"
            class="mt-8 px-8 py-3 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors text-lg"
          >
            Continue to Question 5 →
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_score_input(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 mb-6">
      <h2 class="text-lg font-semibold text-white mb-4">
        <%= if @has_submitted do %>
          Score Submitted - Waiting for others...
        <% else %>
          Select Your Score
        <% end %>
      </h2>

      <%= if @current_question.scale_type == "balance" do %>
        {render_balance_scale(assigns)}
      <% else %>
        {render_maximal_scale(assigns)}
      <% end %>

      <%= if not @has_submitted do %>
        <button
          phx-click="submit_score"
          disabled={@selected_value == nil}
          class={[
            "w-full mt-6 px-6 py-3 font-semibold rounded-lg transition-colors",
            if(@selected_value != nil,
              do: "bg-green-600 hover:bg-green-700 text-white",
              else: "bg-gray-600 text-gray-400 cursor-not-allowed"
            )
          ]}
        >
          Submit Score
        </button>
      <% else %>
        <div class="mt-6 text-center">
          <div class="inline-flex items-center gap-2 text-gray-400">
            <div class="animate-pulse w-2 h-2 bg-green-500 rounded-full" />
            Waiting for {@active_participant_count - @score_count} more participant(s)...
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_balance_scale(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between text-sm text-gray-400">
        <span>Too little</span>
        <span>Just right</span>
        <span>Too much</span>
      </div>

      <div class="flex gap-1">
        <%= for v <- -5..5 do %>
          <button
            type="button"
            phx-click="select_score"
            phx-value-score={v}
            class={[
              "flex-1 min-w-0 py-3 rounded-lg font-semibold text-sm transition-all cursor-pointer",
              cond do
                @selected_value == v -> "bg-green-500 text-white"
                v == 0 -> "bg-gray-600 text-white hover:bg-gray-500"
                true -> "bg-gray-700 text-gray-300 hover:bg-gray-600"
              end
            ]}
          >
            <%= if v > 0 do %>
              +{v}
            <% else %>
              {v}
            <% end %>
          </button>
        <% end %>
      </div>

      <div class="flex justify-between text-xs text-gray-500">
        <span>-5</span>
        <span class="text-green-400">0 = optimal</span>
        <span>+5</span>
      </div>
    </div>
    """
  end

  defp render_maximal_scale(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between text-sm text-gray-400">
        <span>Low</span>
        <span>High</span>
      </div>

      <div class="flex gap-1">
        <%= for v <- 0..10 do %>
          <button
            type="button"
            phx-click="select_score"
            phx-value-score={v}
            class={[
              "flex-1 min-w-0 py-3 rounded-lg font-semibold text-sm transition-all cursor-pointer",
              cond do
                @selected_value == v -> "bg-green-500 text-white"
                v >= 7 -> "bg-gray-600 text-white hover:bg-gray-500"
                true -> "bg-gray-700 text-gray-300 hover:bg-gray-600"
              end
            ]}
          >
            {v}
          </button>
        <% end %>
      </div>

      <div class="flex justify-between text-xs text-gray-500">
        <span>0</span>
        <span class="text-green-400">10 = best</span>
      </div>
    </div>
    """
  end

  defp render_score_results(assigns) do
    # Calculate summary
    values = Enum.map(assigns.all_scores, & &1.value)
    average = calculate_average(values)

    assigns =
      assigns
      |> Map.put(:average, average)
      |> Map.put(:average_color, get_score_color(assigns.current_question, round(average)))

    ~H"""
    <div class="space-y-6">
      <!-- Results summary -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h2 class="text-lg font-semibold text-white mb-4">Results</h2>
        
    <!-- Team average -->
        <div class="text-center mb-6">
          <div class="text-sm text-gray-400 mb-1">Team Average</div>
          <div class={[
            "text-4xl font-bold",
            case @average_color do
              :green -> "text-green-400"
              :amber -> "text-yellow-400"
              :red -> "text-red-400"
              _ -> "text-gray-400"
            end
          ]}>
            <%= if @current_question.scale_type == "balance" and @average > 0 do %>
              +
            <% end %>
            {@average}
          </div>
        </div>
        
    <!-- Individual scores -->
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
          <%= for score <- @all_scores do %>
            <div class={[
              "rounded-lg p-3 text-center",
              case score.color do
                :green -> "bg-green-900/50 border border-green-700"
                :amber -> "bg-yellow-900/50 border border-yellow-700"
                :red -> "bg-red-900/50 border border-red-700"
                _ -> "bg-gray-700"
              end
            ]}>
              <div class={[
                "text-2xl font-bold",
                case score.color do
                  :green -> "text-green-400"
                  :amber -> "text-yellow-400"
                  :red -> "text-red-400"
                  _ -> "text-gray-400"
                end
              ]}>
                <%= if @current_question.scale_type == "balance" and score.value > 0 do %>
                  +
                <% end %>
                {score.value}
              </div>
              <div class="text-sm text-gray-400 truncate">{score.participant_name}</div>
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- Discussion prompts -->
      <%= if length(@current_question.discussion_prompts) > 0 do %>
        <div class="bg-gray-800 rounded-lg p-6">
          <h2 class="text-lg font-semibold text-white mb-4">Discussion Prompts</h2>
          <ul class="space-y-3">
            <%= for prompt <- @current_question.discussion_prompts do %>
              <li class="flex gap-3 text-gray-300">
                <span class="text-green-400">•</span>
                <span>{prompt}</span>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
      
    <!-- Notes capture -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h2 class="text-lg font-semibold text-white mb-4">
          Discussion Notes
          <%= if length(@question_notes) > 0 do %>
            <span class="text-sm font-normal text-gray-400">({length(@question_notes)})</span>
          <% end %>
        </h2>
        
    <!-- Existing notes -->
        <%= if length(@question_notes) > 0 do %>
          <ul class="space-y-3 mb-4">
            <%= for note <- @question_notes do %>
              <li class="bg-gray-700 rounded-lg p-3">
                <div class="flex justify-between items-start gap-2">
                  <p class="text-gray-300 flex-1">{note.content}</p>
                  <button
                    type="button"
                    phx-click="delete_note"
                    phx-value-id={note.id}
                    class="text-gray-500 hover:text-red-400 transition-colors text-sm"
                    title="Delete note"
                  >
                    ✕
                  </button>
                </div>
                <p class="text-xs text-gray-500 mt-1">— {note.author_name}</p>
              </li>
            <% end %>
          </ul>
        <% end %>
        
    <!-- Add note form -->
        <form phx-submit="add_note" class="flex gap-2">
          <input
            type="text"
            name="note"
            value={@note_input}
            phx-change="update_note_input"
            placeholder="Capture a key discussion point..."
            class="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
          />
          <button
            type="submit"
            class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
          >
            Add
          </button>
        </form>
        <p class="text-xs text-gray-500 mt-2">
          Notes are visible to all participants and saved with the session.
        </p>
      </div>
      
    <!-- Ready / Next controls -->
      <div class="bg-gray-800 rounded-lg p-6">
        <%= if @participant.is_facilitator do %>
          <button
            phx-click="next_question"
            class="w-full px-6 py-3 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
          >
            <%= if @session.current_question_index + 1 >= 8 do %>
              Continue to Summary →
            <% else %>
              Next Question →
            <% end %>
          </button>
          <p class="text-center text-gray-500 text-sm mt-2">
            As facilitator, advance when the team is ready.
          </p>
        <% else %>
          <%= if @participant.is_ready do %>
            <div class="text-center text-gray-400">
              <span class="text-green-400">✓</span> You're ready. Waiting for facilitator...
            </div>
          <% else %>
            <button
              phx-click="mark_ready"
              class="w-full px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors"
            >
              I'm Ready to Continue
            </button>
          <% end %>
        <% end %>
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
