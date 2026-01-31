defmodule ProductiveWorkgroupsWeb.SessionLive.Show do
  @moduledoc """
  Main workshop LiveView - handles the full workshop flow.
  """
  use ProductiveWorkgroupsWeb, :live_view

  alias ProductiveWorkgroups.Export
  alias ProductiveWorkgroups.Facilitation
  alias ProductiveWorkgroups.Notes
  alias ProductiveWorkgroups.Scoring
  alias ProductiveWorkgroups.Sessions
  alias ProductiveWorkgroups.Workshops
  alias ProductiveWorkgroupsWeb.SessionLive.ActionFormComponent
  alias ProductiveWorkgroupsWeb.SessionLive.ScoreResultsComponent

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

  defp mount_with_session(socket, _workshop_session, nil, code) do
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
     |> assign(show_facilitator_tips: false)
     |> assign(show_notes: false)
     |> assign(note_input: "")
     |> assign(show_export_modal: false)
     |> init_timer_assigns()
     |> load_scoring_data(workshop_session, participant)
     |> load_summary_data(workshop_session)
     |> load_actions_data(workshop_session)
     |> maybe_start_timer()}
  end

  # Timer management helpers

  defp init_timer_assigns(socket) do
    socket
    |> assign(timer_enabled: false)
    |> assign(segment_duration: nil)
    |> assign(timer_remaining: nil)
    |> assign(timer_phase: nil)
    |> assign(timer_phase_name: nil)
    |> assign(timer_ref: nil)
    |> assign(timer_warning_threshold: nil)
  end

  defp maybe_start_timer(socket) do
    session = socket.assigns.session
    participant = socket.assigns.participant

    if participant.is_facilitator and Facilitation.timer_enabled?(session) do
      start_phase_timer(socket, session)
    else
      socket
    end
  end

  defp start_phase_timer(socket, session) do
    # Cancel any existing timer
    socket = cancel_timer(socket)

    segment_duration = Facilitation.calculate_segment_duration(session)
    timer_phase = Facilitation.current_timer_phase(session)
    warning_threshold = Facilitation.warning_threshold(session)

    if segment_duration && timer_phase do
      # Schedule the first tick
      timer_ref = Process.send_after(self(), :timer_tick, 1000)

      socket
      |> assign(timer_enabled: true)
      |> assign(segment_duration: segment_duration)
      |> assign(timer_remaining: segment_duration)
      |> assign(timer_phase: timer_phase)
      |> assign(timer_phase_name: Facilitation.phase_name(timer_phase))
      |> assign(timer_ref: timer_ref)
      |> assign(timer_warning_threshold: warning_threshold)
    else
      socket
      |> assign(timer_enabled: false)
    end
  end

  defp cancel_timer(socket) do
    if socket.assigns[:timer_ref] do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    assign(socket, timer_ref: nil)
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
    old_session = socket.assigns.session

    socket =
      socket
      |> assign(session: session)
      |> handle_state_transition(old_session, session)

    {:noreply, socket}
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

  # Handle action updates from other participants
  @impl true
  def handle_info({:action_updated, _action_id}, socket) do
    session = socket.assigns.session

    if session.state in ["summary", "actions", "completed"] do
      {:noreply, load_actions_data(socket, session)}
    else
      {:noreply, socket}
    end
  end

  # Handle flash messages from child components
  @impl true
  def handle_info({:flash, kind, message}, socket) do
    {:noreply, put_flash(socket, kind, message)}
  end

  # Handle reload request from ActionFormComponent
  @impl true
  def handle_info(:reload_actions, socket) do
    {:noreply, load_actions_data(socket, socket.assigns.session)}
  end

  # Handle timer tick for facilitator timer countdown
  @impl true
  def handle_info(:timer_tick, socket) do
    if socket.assigns.timer_enabled and socket.assigns.timer_remaining > 0 do
      new_remaining = socket.assigns.timer_remaining - 1
      timer_ref = Process.send_after(self(), :timer_tick, 1000)

      {:noreply,
       socket
       |> assign(timer_remaining: new_remaining)
       |> assign(timer_ref: timer_ref)}
    else
      {:noreply, assign(socket, timer_ref: nil)}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Helper for handling state transitions in session_updated broadcasts
  defp handle_state_transition(socket, old_session, session) do
    state_changed = old_session.state != session.state
    question_changed = old_session.current_question_index != session.current_question_index

    case {state_changed, question_changed, session.state} do
      {true, _, "scoring"} ->
        socket
        |> load_scoring_data(session, socket.assigns.participant)
        |> maybe_restart_timer_on_transition(old_session, session)

      {_, true, "scoring"} ->
        # Show mid-workshop transition when moving from question 4 (index 3) to question 5 (index 4)
        show_transition = old_session.current_question_index == 3

        socket
        |> assign(show_mid_transition: show_transition)
        |> load_scoring_data(session, socket.assigns.participant)
        |> maybe_restart_timer_on_transition(old_session, session)

      {true, _, "summary"} ->
        socket
        |> load_summary_data(session)
        |> load_actions_data(session)
        |> maybe_restart_timer_on_transition(old_session, session)

      {true, _, "actions"} ->
        # Don't restart timer when transitioning from summary to actions - shared timer
        socket |> load_summary_data(session) |> load_actions_data(session)

      {true, _, "completed"} ->
        socket
        |> load_summary_data(session)
        |> load_actions_data(session)
        |> stop_timer()

      _ ->
        socket
    end
  end

  defp maybe_restart_timer_on_transition(socket, old_session, session) do
    participant = socket.assigns.participant

    if participant.is_facilitator do
      old_phase = Facilitation.current_timer_phase(old_session)
      new_phase = Facilitation.current_timer_phase(session)

      # Only restart if the phase actually changed
      # (summary→actions keeps the same "summary_actions" phase, so no restart)
      if old_phase != new_phase and Facilitation.timer_enabled?(session) do
        start_phase_timer(socket, session)
      else
        socket
      end
    else
      socket
    end
  end

  defp stop_timer(socket) do
    socket
    |> cancel_timer()
    |> assign(timer_enabled: false)
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
           |> load_scoring_data(updated_session, participant)
           |> start_phase_timer(updated_session)}

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
    do_submit_score(socket, socket.assigns.selected_value)
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

  # Note handlers - kept for backward compatibility with tests
  @impl true
  def handle_event("toggle_facilitator_tips", _params, socket) do
    {:noreply, assign(socket, show_facilitator_tips: !socket.assigns.show_facilitator_tips)}
  end

  @impl true
  def handle_event("toggle_notes", _params, socket) do
    {:noreply, assign(socket, show_notes: !socket.assigns.show_notes)}
  end

  @impl true
  def handle_event("update_note_input", %{"note" => value}, socket) do
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

  @impl true
  def handle_event("continue_past_transition", _params, socket) do
    {:noreply, assign(socket, show_mid_transition: false)}
  end

  @impl true
  def handle_event("next_question", _params, socket) do
    do_advance_to_next_question(socket, socket.assigns.participant.is_facilitator)
  end

  @impl true
  def handle_event("continue_to_actions", _params, socket) do
    session = socket.assigns.session
    participant = socket.assigns.participant

    if participant.is_facilitator do
      case Sessions.advance_to_actions(session) do
        {:ok, updated_session} ->
          {:noreply,
           socket
           |> assign(session: updated_session)
           |> load_actions_data(updated_session)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to advance to actions")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("continue_to_wrapup", _params, socket) do
    session = socket.assigns.session
    participant = socket.assigns.participant

    if participant.is_facilitator do
      case Sessions.advance_to_completed(session) do
        {:ok, updated_session} ->
          {:noreply,
           socket
           |> assign(session: updated_session)
           |> load_summary_data(updated_session)
           |> load_actions_data(updated_session)
           |> stop_timer()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to advance to wrap-up")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_action", %{"id" => action_id}, socket) do
    session = socket.assigns.session
    action = Enum.find(socket.assigns.all_actions, &(&1.id == action_id))

    if action do
      case Notes.delete_action(action) do
        {:ok, _} ->
          broadcast_action_update(session, action_id)
          {:noreply, load_actions_data(socket, session)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete action")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("finish_workshop", _params, socket) do
    participant = socket.assigns.participant

    if participant.is_facilitator do
      do_finish_workshop(socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    participant = socket.assigns.participant

    if participant.is_facilitator do
      do_go_back(socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_export_modal", _params, socket) do
    {:noreply, assign(socket, show_export_modal: !socket.assigns.show_export_modal)}
  end

  @impl true
  def handle_event("close_export_modal", _params, socket) do
    {:noreply, assign(socket, show_export_modal: false)}
  end

  @impl true
  def handle_event("export", %{"format" => format, "content" => content}, socket) do
    session = socket.assigns.session

    format_atom = String.to_existing_atom(format)
    content_atom = String.to_existing_atom(content)

    case Export.export(session, format: format_atom, content: content_atom) do
      {:ok, {filename, content_type, data}} ->
        {:noreply,
         socket
         |> assign(show_export_modal: false)
         |> push_event("download", %{filename: filename, content_type: content_type, data: data})}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to export data")}
    end
  end

  # Private helper functions

  defp do_finish_workshop(socket) do
    session = socket.assigns.session

    # Session is already in "completed" state on the wrap-up page - just navigate home
    if session.state == "completed" do
      {:noreply, push_navigate(socket, to: "/")}
    else
      # Legacy: handle finish from actions state
      case Sessions.complete_session(session) do
        {:ok, _updated_session} ->
          {:noreply, push_navigate(socket, to: "/")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to complete workshop")}
      end
    end
  end

  defp do_go_back(socket) do
    session = socket.assigns.session
    do_go_back_from_state(socket, session, session.state)
  end

  defp do_go_back_from_state(socket, session, "scoring")
       when session.current_question_index == 0 do
    # If on first question scoring entry (not results), go back to intro
    if socket.assigns.scores_revealed do
      # On results page - just unreveal scores for current question
      unreveal_current_question_scores(socket, session)
    else
      # On scoring entry - go back to intro
      go_back_to_intro(socket, session)
    end
  end

  defp do_go_back_from_state(socket, session, "scoring") do
    if socket.assigns.scores_revealed do
      # On results page - unreveal current question's scores to return to scoring entry
      unreveal_current_question_scores(socket, session)
    else
      # On scoring entry - go back to previous question's results
      go_back_to_previous_question_results(socket, session)
    end
  end

  defp do_go_back_from_state(socket, session, "summary") do
    Sessions.reset_all_ready(session)
    template = get_or_load_template(socket, session.template_id)
    last_index = length(template.questions) - 1
    Scoring.unreveal_scores(session, last_index)

    # Don't restart timer - timer only moves forward, keeps current countdown
    case Sessions.go_back_to_scoring(session, last_index) do
      {:ok, updated_session} ->
        {:noreply,
         socket
         |> assign(session: updated_session)
         |> load_scoring_data(updated_session, socket.assigns.participant)
         |> assign(scores_revealed: false)
         |> assign(has_submitted: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to go back")}
    end
  end

  defp do_go_back_from_state(socket, session, "actions") do
    Sessions.reset_all_ready(session)

    case Sessions.go_back_to_summary(session) do
      {:ok, updated_session} ->
        {:noreply,
         socket
         |> assign(session: updated_session)
         |> load_summary_data(updated_session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to go back")}
    end
  end

  defp do_go_back_from_state(socket, session, "completed") do
    Sessions.reset_all_ready(session)

    case Sessions.go_back_to_summary(session) do
      {:ok, updated_session} ->
        {:noreply,
         socket
         |> assign(session: updated_session)
         |> load_summary_data(updated_session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to go back")}
    end
  end

  defp do_go_back_from_state(socket, _session, _state) do
    # Cannot go back from lobby or intro
    {:noreply, socket}
  end

  defp unreveal_current_question_scores(socket, session) do
    Sessions.reset_all_ready(session)
    current_index = session.current_question_index
    Scoring.unreveal_scores(session, current_index)

    {:noreply,
     socket
     |> load_scoring_data(session, socket.assigns.participant)
     |> assign(scores_revealed: false)
     |> assign(has_submitted: false)}
  end

  defp go_back_to_previous_question_results(socket, session) do
    Sessions.reset_all_ready(session)
    # Don't unreveal - we want to show the previous question's results
    # Don't restart timer - timer only moves forward, keeps current countdown

    case Sessions.go_back_question(session) do
      {:ok, updated_session} ->
        {:noreply,
         socket
         |> assign(session: updated_session)
         |> assign(show_mid_transition: false)
         |> load_scoring_data(updated_session, socket.assigns.participant)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to go back")}
    end
  end

  defp go_back_to_intro(socket, session) do
    Sessions.reset_all_ready(session)

    case Sessions.go_back_to_intro(session) do
      {:ok, updated_session} ->
        {:noreply,
         socket
         |> assign(session: updated_session)
         |> assign(intro_step: 4)
         |> stop_timer()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to go back")}
    end
  end

  defp do_submit_score(socket, nil) do
    {:noreply, put_flash(socket, :error, "Please select a score first")}
  end

  defp do_submit_score(socket, selected_value) do
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

  defp broadcast_note_update(session, question_index) do
    Phoenix.PubSub.broadcast(
      ProductiveWorkgroups.PubSub,
      Sessions.session_topic(session),
      {:note_updated, question_index}
    )
  end

  defp broadcast_action_update(session, action_id) do
    Phoenix.PubSub.broadcast(
      ProductiveWorkgroups.PubSub,
      Sessions.session_topic(session),
      {:action_updated, action_id}
    )
  end

  defp do_advance_to_next_question(socket, false), do: {:noreply, socket}

  defp do_advance_to_next_question(socket, true) do
    session = socket.assigns.session
    Sessions.reset_all_ready(session)

    # Reuse cached template
    template = get_or_load_template(socket, session.template_id)
    is_last_question = session.current_question_index + 1 >= length(template.questions)

    do_advance(socket, session, is_last_question)
  end

  defp do_advance(socket, session, true) do
    case Sessions.advance_to_summary(session) do
      {:ok, updated_session} ->
        {:noreply,
         socket
         |> assign(session: updated_session)
         |> load_summary_data(updated_session)
         |> start_phase_timer(updated_session)}

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
         |> load_scoring_data(updated_session, participant)
         |> start_phase_timer(updated_session)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to advance to next question")}
    end
  end

  # Scoring data helpers

  defp load_scoring_data(socket, session, participant) do
    if session.state == "scoring" do
      # Reuse cached template to avoid repeated database queries
      template = get_or_load_template(socket, session.template_id)
      question_index = session.current_question_index
      question = Enum.find(template.questions, &(&1.index == question_index))

      my_score = Scoring.get_score(session, participant, question_index)

      socket
      |> assign(template: template)
      |> assign(current_question: question)
      |> assign(selected_value: if(my_score, do: my_score.value, else: nil))
      |> assign(my_score: if(my_score, do: my_score.value, else: nil))
      |> assign(has_submitted: my_score != nil)
      |> assign(show_facilitator_tips: false)
      |> assign(show_notes: false)
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
      |> assign(show_facilitator_tips: false)
      |> assign(show_notes: false)
    end
  end

  defp load_scores(socket, session, question_index) do
    scores = Scoring.list_scores_for_question(session, question_index)
    all_scored = Scoring.all_scored?(session, question_index)

    # Use participants from socket assigns - kept in sync via PubSub handlers
    participants = socket.assigns.participants

    active_count =
      Enum.count(participants, fn p -> p.status == "active" and not p.is_observer end)

    # Build participant map for O(1) lookups instead of O(n) Enum.find
    participant_map = Map.new(participants, &{&1.id, &1})

    # Get scores with participant names
    scores_with_names =
      Enum.map(scores, fn score ->
        participant = Map.get(participant_map, score.participant_id)

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

  defp load_summary_data(socket, session) do
    if session.state in ["summary", "actions", "completed"] do
      # Reuse cached template if available, otherwise load it
      template = get_or_load_template(socket, session.template_id)
      scores_summary = Scoring.get_all_scores_summary(session, template)
      all_notes = Notes.list_all_notes(session)

      # Get individual scores grouped by question (ordered by participant joined_at)
      participants = socket.assigns.participants
      individual_scores = Scoring.get_all_individual_scores(session, participants, template)

      # Group notes by question_index
      notes_by_question = Enum.group_by(all_notes, & &1.question_index)

      # Single pass grouping instead of triple filtering
      grouped = Enum.group_by(scores_summary, & &1.color)

      socket
      |> assign(summary_template: template)
      |> assign(scores_summary: scores_summary)
      |> assign(all_notes: all_notes)
      |> assign(individual_scores: individual_scores)
      |> assign(notes_by_question: notes_by_question)
      |> assign(strengths: Map.get(grouped, :green, []))
      |> assign(concerns: Map.get(grouped, :red, []))
      |> assign(neutral: Map.get(grouped, :amber, []))
    else
      socket
      |> assign(summary_template: nil)
      |> assign(scores_summary: [])
      |> assign(all_notes: [])
      |> assign(individual_scores: %{})
      |> assign(notes_by_question: %{})
      |> assign(strengths: [])
      |> assign(concerns: [])
      |> assign(neutral: [])
    end
  end

  # Reuse cached template to avoid repeated database queries
  defp get_or_load_template(socket, template_id) do
    cached = socket.assigns[:template] || socket.assigns[:summary_template]

    if cached && cached.id == template_id do
      cached
    else
      Workshops.get_template_with_questions(template_id)
    end
  end

  defp load_actions_data(socket, session) do
    if session.state in ["summary", "actions", "completed"] do
      actions = Notes.list_all_actions(session)

      socket
      |> assign(all_actions: actions)
      |> assign(action_count: length(actions))
    else
      socket
      |> assign(all_actions: [])
      |> assign(action_count: 0)
    end
  end

  defp get_score_color(nil, _value), do: :gray

  defp get_score_color(question, value) do
    Scoring.traffic_light_color(question.scale_type, value, question.optimal_value)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900">
      {render_facilitator_timer(assigns)}
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

  defp render_facilitator_timer(assigns) do
    ~H"""
    <%= if @participant.is_facilitator and @timer_enabled and @timer_remaining do %>
      <.facilitator_timer
        remaining_seconds={@timer_remaining}
        total_seconds={@segment_duration}
        phase_name={@timer_phase_name}
        warning_threshold={@timer_warning_threshold}
      />
    <% end %>
    """
  end

  defp render_lobby(assigns) do
    join_url = ProductiveWorkgroupsWeb.Endpoint.url() <> "/session/#{assigns.session.code}/join"

    assigns =
      assigns
      |> assign(:join_url, join_url)

    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="max-w-lg w-full text-center">
        <h1 class="text-3xl font-bold text-white mb-2">Waiting Room</h1>
        <p class="text-gray-400 mb-4">
          Share this link with your team:
        </p>
        <div class="bg-gray-800 rounded-lg p-4 mb-8">
          <div class="flex items-center gap-2">
            <input
              type="text"
              readonly
              value={@join_url}
              id="join-url"
              class="flex-1 bg-gray-700 border-none rounded-lg px-4 py-3 text-white font-mono text-sm focus:ring-2 focus:ring-blue-500"
            />
            <button
              type="button"
              phx-click={JS.dispatch("phx:copy", to: "#join-url")}
              class="px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
            >
              Copy
            </button>
          </div>
        </div>

        <div class="bg-gray-800 rounded-lg p-6 mb-6">
          <h2 class="text-lg font-semibold text-white mb-4">
            Participants ({length(@participants)})
          </h2>
          <ul class="space-y-2">
            <%= for p <- @participants do %>
              <li class="flex items-center justify-between bg-gray-700 rounded-lg px-4 py-3">
                <div class="flex items-center gap-2">
                  <span class="text-white">{p.name}</span>
                  <%= cond do %>
                    <% p.is_observer -> %>
                      <span class="text-xs bg-gray-600 text-gray-300 px-2 py-1 rounded">
                        Observer
                      </span>
                    <% p.is_facilitator -> %>
                      <span class="text-xs bg-purple-600 text-white px-2 py-1 rounded">
                        Facilitator
                      </span>
                    <% true -> %>
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
            class="w-full px-6 py-4 font-semibold rounded-lg transition-colors text-lg mb-4 bg-green-600 hover:bg-green-700 text-white"
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
                <%= if @intro_step == 1 do %>
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
    <div class="text-center min-h-[340px]">
      <h1 class="text-3xl font-bold text-white mb-6">Welcome to the Six Criteria Workshop</h1>
      <div class="text-gray-300 space-y-8 text-lg leading-tight">
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
    <div class="text-center min-h-[340px]">
      <h1 class="text-3xl font-bold text-white mb-6">How This Workshop Works</h1>
      <div class="text-gray-300 text-lg text-left leading-tight">
        <p class="mb-6">You'll work through 8 questions covering 6 criteria together as a team.</p>
        <p class="font-semibold text-white mb-2">For each question:</p>
        <ol class="list-decimal list-inside space-y-0.5 pl-4">
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
    <div class="text-center min-h-[340px]">
      <h1 class="text-3xl font-bold text-white mb-6">Understanding the Balance Scale</h1>
      <div class="text-gray-300 text-lg text-left leading-tight">
        <p class="mb-4">
          The first four questions use a <span class="text-white font-semibold">balance scale</span>
          from -5 to +5:
        </p>

        <div class="bg-gray-800 rounded-lg p-6 my-4">
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

        <ul class="space-y-0.5 pl-4">
          <li>• These criteria need the right amount — not too much, not too little</li>
          <li>• <span class="text-green-400 font-semibold">0 is optimal</span> (balanced)</li>
          <li>• Negative means too little, positive means too much</li>
        </ul>

        <p class="text-gray-400 mt-6">
          Don't overthink — go with your gut feeling about your current experience.
        </p>
      </div>
    </div>
    """
  end

  defp render_intro_safe_space(assigns) do
    ~H"""
    <div class="text-center min-h-[340px]">
      <h1 class="text-3xl font-bold text-white mb-6">Creating a Safe Space</h1>
      <div class="text-gray-300 text-lg text-left leading-tight">
        <p class="mb-4">
          This workshop operates under the <span class="text-white font-semibold">Prime Directive</span>:
        </p>

        <blockquote class="italic text-gray-400 border-l-4 border-purple-600 pl-4 my-4">
          "Regardless of what we discover, we understand and truly believe that everyone did the best job they could, given what they knew at the time, their skills and abilities, the resources available, and the situation at hand."
          <span class="block text-sm mt-1 not-italic">— Norm Kerth</span>
        </blockquote>

        <p class="mb-4">
          Your scores reflect the <span class="text-white">system and environment</span>
          — not individual failings. Low scores aren't accusations; they're opportunities to improve how work is structured.
        </p>

        <ul class="space-y-0.5 pl-4">
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

            <%= if length(@current_question.discussion_prompts) > 0 do %>
              <%= if @show_facilitator_tips do %>
                <!-- Expanded tips section -->
                <div class="mt-4 pt-4 border-t border-gray-700">
                  <div class="flex items-center justify-between mb-3">
                    <h3 class="text-sm font-semibold text-purple-400">Facilitator Tips</h3>
                    <button
                      type="button"
                      phx-click="toggle_facilitator_tips"
                      class="text-sm text-gray-400 hover:text-white transition-colors"
                    >
                      Hide tips
                    </button>
                  </div>
                  <ul class="space-y-2">
                    <%= for prompt <- @current_question.discussion_prompts do %>
                      <li class="flex gap-2 text-gray-300 text-sm">
                        <span class="text-purple-400">•</span>
                        <span>{prompt}</span>
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% else %>
                <!-- Collapsed state - show More tips button -->
                <button
                  type="button"
                  phx-click="toggle_facilitator_tips"
                  class="mt-4 text-sm text-purple-400 hover:text-purple-300 transition-colors flex items-center gap-1"
                >
                  <span>More tips</span>
                  <span class="text-xs">+</span>
                </button>
              <% end %>
            <% end %>
          </div>

          <%= if @scores_revealed do %>
            <.live_component
              module={ScoreResultsComponent}
              id="score-results"
              all_scores={@all_scores}
              current_question={@current_question}
              show_notes={@show_notes}
              question_notes={@question_notes}
              note_input={@note_input}
              participant={@participant}
              session={@session}
            />
          <% else %>
            {render_score_input(assigns)}
            <!-- Facilitator navigation bar during scoring entry -->
            <%= if @participant.is_facilitator do %>
              <div class="bg-gray-800 rounded-lg p-6">
                <div class="flex gap-3">
                  <button
                    phx-click="go_back"
                    class="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-gray-300 hover:text-white font-medium rounded-lg transition-colors flex items-center gap-2"
                  >
                    <span>←</span>
                    <span>Back</span>
                  </button>
                  <button
                    disabled
                    class="flex-1 px-6 py-3 bg-gray-600 text-gray-400 font-semibold rounded-lg cursor-not-allowed"
                  >
                    <%= if @session.current_question_index + 1 >= 8 do %>
                      Continue to Summary →
                    <% else %>
                      Next Question →
                    <% end %>
                  </button>
                </div>
                <p class="text-center text-gray-500 text-sm mt-2">
                  Waiting for all scores to be submitted...
                </p>
              </div>
            <% end %>
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
      <%= if @participant.is_observer do %>
        <div class="text-center">
          <div class="text-purple-400 text-lg font-semibold mb-2">Observer Mode</div>
          <p class="text-gray-400">
            You are observing this session. Waiting for team members to submit their scores...
          </p>
          <div class="mt-4 inline-flex items-center gap-2 text-gray-500">
            <div class="animate-pulse w-2 h-2 bg-purple-500 rounded-full" />
            {@score_count}/{@active_participant_count} scores submitted
          </div>
        </div>
      <% else %>
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

  defp render_summary(assigns) do
    ~H"""
    <div class="flex flex-col items-center min-h-screen px-4 py-8">
      <div class="max-w-4xl w-full">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-white mb-2">Workshop Summary</h1>
          <p class="text-gray-400">
            Review your team's responses before creating action items.
          </p>
        </div>
        
    <!-- Participants -->
        <div class="bg-gray-800 rounded-lg p-4 mb-6">
          <h2 class="text-sm font-semibold text-gray-400 mb-3">Participants</h2>
          <div class="flex flex-wrap gap-2">
            <%= for p <- @participants do %>
              <div class="bg-gray-700 rounded-lg px-3 py-1.5 flex items-center gap-2 text-sm">
                <span class="text-white">{p.name}</span>
                <%= cond do %>
                  <% p.is_observer -> %>
                    <span class="text-xs bg-gray-600 text-gray-300 px-1.5 py-0.5 rounded">
                      Observer
                    </span>
                  <% p.is_facilitator -> %>
                    <span class="text-xs bg-purple-600 text-white px-1.5 py-0.5 rounded">
                      Facilitator
                    </span>
                  <% true -> %>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- All Questions with Individual Scores and Notes -->
        <div class="space-y-4 mb-6">
          <%= for score <- @scores_summary do %>
            <% question_notes = Map.get(@notes_by_question, score.question_index, []) %>
            <% question_scores = Map.get(@individual_scores, score.question_index, []) %>
            <div class={[
              "rounded-lg p-4 border",
              case score.color do
                :green -> "bg-green-900/20 border-green-700"
                :amber -> "bg-yellow-900/20 border-yellow-700"
                :red -> "bg-red-900/20 border-red-700"
                _ -> "bg-gray-700 border-gray-600"
              end
            ]}>
              <!-- Question header -->
              <div class="flex items-start justify-between mb-3">
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <span class="text-sm text-gray-400">Q{score.question_index + 1}</span>
                    <h3 class="font-semibold text-white">{score.title}</h3>
                  </div>
                  <div class="text-xs text-gray-500 mt-1">
                    <%= if score.scale_type == "balance" do %>
                      -5 to +5, optimal at 0
                    <% else %>
                      0 to 10, higher is better
                    <% end %>
                  </div>
                </div>
                <div class="text-right">
                  <%= if score.combined_team_value do %>
                    <div class={[
                      "text-2xl font-bold",
                      case score.color do
                        :green -> "text-green-400"
                        :amber -> "text-yellow-400"
                        :red -> "text-red-400"
                        _ -> "text-gray-400"
                      end
                    ]}>
                      {round(score.combined_team_value)}/10
                    </div>
                    <div class="flex items-center justify-end gap-1 text-xs text-gray-500">
                      <span>team</span>
                      <span
                        class="cursor-help"
                        title="Combined Team Value: A team rating out of 10 for this criterion. Each person's score is graded (green=2, amber=1, red=0), then averaged and scaled. 10 = everyone scored well, 0 = everyone scored poorly."
                      >
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                          />
                        </svg>
                      </span>
                    </div>
                  <% else %>
                    <div class="text-gray-500 text-sm">No scores</div>
                  <% end %>
                </div>
              </div>
              
    <!-- Individual Scores with names -->
              <%= if length(question_scores) > 0 do %>
                <% score_count = length(question_scores) %>
                <div
                  class="grid gap-2"
                  style={"grid-template-columns: repeat(#{min(score_count, 10)}, minmax(0, 1fr))"}
                >
                  <%= for s <- question_scores do %>
                    <div class={[
                      "rounded p-2 text-center",
                      case s.color do
                        :green -> "bg-green-900/50 border border-green-700"
                        :amber -> "bg-yellow-900/50 border border-yellow-700"
                        :red -> "bg-red-900/50 border border-red-700"
                        _ -> "bg-gray-700"
                      end
                    ]}>
                      <div class={[
                        "text-lg font-bold",
                        case s.color do
                          :green -> "text-green-400"
                          :amber -> "text-yellow-400"
                          :red -> "text-red-400"
                          _ -> "text-gray-400"
                        end
                      ]}>
                        <%= if score.scale_type == "balance" and s.value > 0 do %>
                          +{s.value}
                        <% else %>
                          {s.value}
                        <% end %>
                      </div>
                      <div class="text-xs text-gray-400 truncate" title={s.participant_name}>
                        {s.participant_name}
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
              
    <!-- Notes for this question (inline) -->
              <%= if length(question_notes) > 0 do %>
                <div class="mt-3 pt-3 border-t border-gray-700/50">
                  <div class="text-xs text-gray-500 mb-2">Notes</div>
                  <ul class="space-y-1.5">
                    <%= for note <- question_notes do %>
                      <li class="text-sm text-gray-300 bg-gray-700/50 rounded px-2 py-1.5">
                        {note.content}
                        <span class="text-xs text-gray-500 ml-1">— {note.author_name}</span>
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Navigation Footer -->
        <div class="bg-gray-800 rounded-lg p-6">
          <%= if @participant.is_facilitator do %>
            <div class="flex gap-3">
              <button
                phx-click="go_back"
                class="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-gray-300 hover:text-white font-medium rounded-lg transition-colors flex items-center gap-2"
              >
                <span>←</span>
                <span>Back</span>
              </button>
              <button
                phx-click="continue_to_wrapup"
                class="flex-1 px-6 py-3 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
              >
                Continue to Wrap-Up →
              </button>
            </div>
            <p class="text-center text-gray-500 text-sm mt-2">
              Proceed to create action items and finish the workshop.
            </p>
          <% else %>
            <div class="text-center text-gray-400">
              Reviewing summary. Waiting for facilitator to continue...
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_actions(assigns) do
    ~H"""
    <div class="flex flex-col items-center min-h-screen px-4 py-8">
      <div class="max-w-3xl w-full">
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-white mb-2">Action Items</h1>
          <p class="text-gray-400">
            Capture commitments and next steps from your discussion.
          </p>
        </div>
        
    <!-- Create Action Form -->
        <.live_component
          module={ActionFormComponent}
          id="action-form"
          session={@session}
        />
        
    <!-- Existing Actions -->
        <%= if @action_count > 0 do %>
          <div class="bg-gray-800 rounded-lg p-6">
            <ul class="space-y-3">
              <%= for action <- @all_actions do %>
                {render_action_item(assigns, action)}
              <% end %>
            </ul>
          </div>
        <% else %>
          <div class="bg-gray-800 rounded-lg p-6 text-center">
            <p class="text-gray-400">No action items yet. Add your first action above.</p>
          </div>
        <% end %>
        
    <!-- Finish Workshop Button -->
        <div class="bg-gray-800 rounded-lg p-6 mt-6">
          <%= if @participant.is_facilitator do %>
            <button
              phx-click="finish_workshop"
              class="w-full px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-semibold rounded-lg transition-colors"
            >
              Finish Workshop
            </button>
            <p class="text-center text-gray-500 text-sm mt-2">
              Complete the workshop and view the final summary.
            </p>
          <% else %>
            <div class="text-center text-gray-400">
              Adding action items. Waiting for facilitator to finish workshop...
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_action_item(assigns, action) do
    assigns = Map.put(assigns, :action, action)

    ~H"""
    <li class="rounded-lg p-3 flex items-start gap-3 bg-gray-700">
      <div class="flex-1">
        <p class="text-gray-300">
          {@action.description}
        </p>
        <%= if @action.owner_name && @action.owner_name != "" do %>
          <p class="text-sm text-gray-500 mt-1">Owner: {@action.owner_name}</p>
        <% end %>
      </div>
      <button
        type="button"
        phx-click="delete_action"
        phx-value-id={@action.id}
        class="text-gray-500 hover:text-red-400 transition-colors text-sm"
        title="Delete action"
      >
        ✕
      </button>
    </li>
    """
  end

  defp render_completed(assigns) do
    ~H"""
    <div class="flex flex-col items-center min-h-screen px-4 py-8">
      <div class="max-w-4xl w-full">
        <!-- Header -->
        <div class="text-center mb-8">
          <h1 class="text-3xl font-bold text-white mb-2">Workshop Wrap-Up</h1>
          <p class="text-gray-400">
            Review key findings and create action items.
          </p>
          <p class="text-sm text-gray-500 mt-2">
            Session code: <span class="font-mono text-white">{@session.code}</span>
          </p>
        </div>
        
    <!-- Score Grid -->
        <div class="bg-gray-800 rounded-lg p-4 mb-6">
          <h2 class="text-lg font-semibold text-white mb-3">All Scores</h2>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <%= for score <- @scores_summary do %>
              <div class={[
                "rounded-lg p-3 text-center border",
                case score.color do
                  :green -> "bg-green-900/30 border-green-700"
                  :amber -> "bg-yellow-900/30 border-yellow-700"
                  :red -> "bg-red-900/30 border-red-700"
                  _ -> "bg-gray-700 border-gray-600"
                end
              ]}>
                <div class="text-xs text-gray-400 mb-1">Q{score.question_index + 1}</div>
                <div class={[
                  "text-2xl font-bold",
                  case score.color do
                    :green -> "text-green-400"
                    :amber -> "text-yellow-400"
                    :red -> "text-red-400"
                    _ -> "text-gray-400"
                  end
                ]}>
                  <%= if score.combined_team_value do %>
                    {round(score.combined_team_value)}/10
                  <% else %>
                    —
                  <% end %>
                </div>
                <div class="text-xs text-gray-400 truncate mt-1" title={score.title}>
                  {score.title}
                </div>
              </div>
            <% end %>
          </div>
          <div class="flex items-center justify-center gap-1 text-xs text-gray-500 mt-2">
            <span>Combined Team Values</span>
            <span
              class="cursor-help"
              title="Each person's score is graded (green=2, amber=1, red=0), then averaged and scaled to 0-10. 10 = everyone scored well, 0 = everyone scored poorly."
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </span>
          </div>
        </div>
        
    <!-- Pattern Highlighting -->
        <%= if length(@strengths) > 0 or length(@concerns) > 0 do %>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <!-- Strengths -->
            <%= if length(@strengths) > 0 do %>
              <div class="bg-green-900/30 border border-green-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold text-green-400 mb-3">
                  Strengths ({length(@strengths)})
                </h3>
                <ul class="space-y-2">
                  <%= for item <- @strengths do %>
                    <li class="flex items-center gap-2 text-gray-300">
                      <span class="text-green-400">✓</span>
                      <span>{item.title}</span>
                      <span class="text-green-400 font-semibold ml-auto">
                        {round(item.combined_team_value)}/10
                      </span>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
            
    <!-- Concerns -->
            <%= if length(@concerns) > 0 do %>
              <div class="bg-red-900/30 border border-red-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold text-red-400 mb-3">
                  Areas of Concern ({length(@concerns)})
                </h3>
                <ul class="space-y-2">
                  <%= for item <- @concerns do %>
                    <li class="flex items-center gap-2 text-gray-300">
                      <span class="text-red-400">!</span>
                      <span>{item.title}</span>
                      <span class="text-red-400 font-semibold ml-auto">
                        {round(item.combined_team_value)}/10
                      </span>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
        <% end %>
        
    <!-- Action Items Section (Editable) -->
        <div class="bg-gray-800 rounded-lg p-4 mb-6">
          <h2 class="text-lg font-semibold text-white mb-3">
            Action Items
          </h2>
          
    <!-- Add Action Form -->
          <.live_component
            module={ActionFormComponent}
            id="action-form"
            session={@session}
          />
          
    <!-- Existing Actions -->
          <%= if @action_count > 0 do %>
            <ul class="space-y-2">
              <%= for action <- @all_actions do %>
                {render_action_item(assigns, action)}
              <% end %>
            </ul>
          <% else %>
            <p class="text-gray-400 text-center py-2">
              No action items yet. Add your first action above.
            </p>
          <% end %>
        </div>
        
    <!-- Notes Summary -->
        <%= if length(@all_notes) > 0 do %>
          <div class="bg-gray-800 rounded-lg p-4 mb-6">
            <h2 class="text-lg font-semibold text-white mb-3">
              Discussion Notes ({length(@all_notes)})
            </h2>
            <ul class="space-y-2">
              <%= for note <- @all_notes do %>
                <li class="bg-gray-700 rounded-lg p-3">
                  <%= if note.question_index do %>
                    <div class="text-xs text-gray-500 mb-1">Question {note.question_index + 1}</div>
                  <% end %>
                  <p class="text-gray-300">{note.content}</p>
                  <p class="text-xs text-gray-500 mt-1">— {note.author_name}</p>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
        
    <!-- Export -->
        <div class="bg-gray-800 rounded-lg p-4 mb-6" id="export-container" phx-hook="FileDownload">
          <button
            type="button"
            phx-click="toggle_export_modal"
            class="w-full px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors flex items-center justify-center gap-2"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
              />
            </svg>
            <span>Export Results</span>
          </button>
        </div>
        
    <!-- Export Modal -->
        <%= if @show_export_modal do %>
          <div
            class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
            phx-click="close_export_modal"
          >
            <div
              class="bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4"
              phx-click-away="close_export_modal"
            >
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white">Export Workshop Data</h3>
                <button
                  type="button"
                  phx-click="close_export_modal"
                  class="text-gray-400 hover:text-white"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>

              <p class="text-gray-400 text-sm mb-6">
                Choose what to export and the format.
              </p>

              <div class="space-y-4">
                <div class="grid grid-cols-2 gap-3">
                  <div class="col-span-2">
                    <p class="text-sm text-gray-300 mb-2 font-medium">CSV Format</p>
                  </div>
                  <button
                    type="button"
                    phx-click="export"
                    phx-value-format="csv"
                    phx-value-content="results"
                    class="px-4 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors text-sm"
                  >
                    Results Only
                  </button>
                  <button
                    type="button"
                    phx-click="export"
                    phx-value-format="csv"
                    phx-value-content="actions"
                    class="px-4 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors text-sm"
                  >
                    Actions Only
                  </button>
                  <button
                    type="button"
                    phx-click="export"
                    phx-value-format="csv"
                    phx-value-content="all"
                    class="col-span-2 px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors text-sm font-medium"
                  >
                    Export All (CSV)
                  </button>
                </div>

                <div class="border-t border-gray-700 pt-4">
                  <div class="grid grid-cols-2 gap-3">
                    <div class="col-span-2">
                      <p class="text-sm text-gray-300 mb-2 font-medium">JSON Format</p>
                    </div>
                    <button
                      type="button"
                      phx-click="export"
                      phx-value-format="json"
                      phx-value-content="results"
                      class="px-4 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors text-sm"
                    >
                      Results Only
                    </button>
                    <button
                      type="button"
                      phx-click="export"
                      phx-value-format="json"
                      phx-value-content="actions"
                      class="px-4 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors text-sm"
                    >
                      Actions Only
                    </button>
                    <button
                      type="button"
                      phx-click="export"
                      phx-value-format="json"
                      phx-value-content="all"
                      class="col-span-2 px-4 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors text-sm"
                    >
                      Export All (JSON)
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Navigation Footer -->
        <div class="bg-gray-800 rounded-lg p-6">
          <%= if @participant.is_facilitator do %>
            <div class="flex gap-3">
              <button
                phx-click="go_back"
                class="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-gray-300 hover:text-white font-medium rounded-lg transition-colors flex items-center gap-2"
              >
                <span>←</span>
                <span>Back</span>
              </button>
              <button
                phx-click="finish_workshop"
                class="flex-1 px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-semibold rounded-lg transition-colors"
              >
                Finish Workshop
              </button>
            </div>
            <p class="text-center text-gray-500 text-sm mt-2">
              Finish the workshop and return to the home page.
            </p>
          <% else %>
            <p class="text-center text-gray-400">
              Waiting for facilitator to finish the workshop...
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
