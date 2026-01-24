defmodule ProductiveWorkgroups.SessionsPubSubTest do
  use ProductiveWorkgroups.DataCase, async: true

  alias ProductiveWorkgroups.Sessions
  alias ProductiveWorkgroups.Workshops

  describe "PubSub broadcasting" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "PubSub Test",
          slug: "pubsub-test",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session, template: template}
    end

    test "subscribe/1 subscribes to session topic", %{session: session} do
      :ok = Sessions.subscribe(session)
      # If we get here without error, subscription worked
      assert true
    end

    test "join_session broadcasts participant_joined", %{session: session} do
      Sessions.subscribe(session)

      {:ok, participant} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())

      assert_receive {:participant_joined, ^participant}
    end

    test "start_session broadcasts session_started", %{session: session} do
      Sessions.subscribe(session)

      {:ok, started_session} = Sessions.start_session(session)

      assert_receive {:session_started, received_session}
      assert received_session.id == started_session.id
      assert received_session.state == "intro"
    end

    test "advance_to_scoring broadcasts session_updated", %{session: session} do
      {:ok, started} = Sessions.start_session(session)
      Sessions.subscribe(started)

      {:ok, scoring_session} = Sessions.advance_to_scoring(started)

      assert_receive {:session_updated, received_session}
      assert received_session.id == scoring_session.id
      assert received_session.state == "scoring"
    end

    test "advance_question broadcasts session_updated", %{session: session} do
      {:ok, started} = Sessions.start_session(session)
      {:ok, scoring} = Sessions.advance_to_scoring(started)
      Sessions.subscribe(scoring)

      {:ok, advanced} = Sessions.advance_question(scoring)

      assert_receive {:session_updated, received_session}
      assert received_session.current_question_index == advanced.current_question_index
    end

    test "set_participant_ready broadcasts participant_ready", %{session: session} do
      {:ok, participant} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())
      Sessions.subscribe(session)

      {:ok, ready_participant} = Sessions.set_participant_ready(participant, true)

      assert_receive {:participant_ready, received}
      assert received.id == ready_participant.id
      assert received.is_ready == true
    end

    test "update_participant_status broadcasts participant_left when status is dropped", %{session: session} do
      {:ok, participant} = Sessions.join_session(session, "Charlie", Ecto.UUID.generate())
      Sessions.subscribe(session)

      {:ok, _dropped} = Sessions.update_participant_status(participant, "dropped")

      assert_receive {:participant_left, participant_id}
      assert participant_id == participant.id
    end

    test "update_participant_status broadcasts participant_updated for other statuses", %{session: session} do
      {:ok, participant} = Sessions.join_session(session, "Diana", Ecto.UUID.generate())
      Sessions.subscribe(session)

      {:ok, updated} = Sessions.update_participant_status(participant, "inactive")

      assert_receive {:participant_updated, received}
      assert received.id == updated.id
      assert received.status == "inactive"
    end
  end
end
