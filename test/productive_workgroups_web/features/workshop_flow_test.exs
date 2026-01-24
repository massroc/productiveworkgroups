defmodule ProductiveWorkgroupsWeb.Features.WorkshopFlowTest do
  use ProductiveWorkgroupsWeb.FeatureCase, async: false

  import Wallaby.Query
  alias ProductiveWorkgroups.Workshops

  setup do
    # Create the Six Criteria template
    {:ok, template} =
      Workshops.create_template(%{
        name: "Six Criteria Test",
        slug: "six-criteria",
        version: "1.0.0",
        default_duration_minutes: 210
      })

    {:ok, _} =
      Workshops.create_question(template, %{
        index: 0,
        title: "Elbow Room",
        criterion_name: "Elbow Room",
        explanation: "Test explanation",
        scale_type: "balance",
        scale_min: -5,
        scale_max: 5,
        optimal_value: 0
      })

    %{template: template}
  end

  @tag :e2e
  feature "user can create a new workshop session", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("h1", text: "Productive Work Groups"))
    |> click(link("Start New Workshop"))
    |> assert_has(css("h1", text: "Create New Workshop"))
  end

  @tag :e2e
  feature "user can join an existing session", %{session: session, template: template} do
    # Create a session directly via context
    {:ok, workshop_session} = ProductiveWorkgroups.Sessions.create_session(template)

    # Visit the join page directly
    session
    |> visit("/session/#{workshop_session.code}/join")
    |> assert_has(css("h1", text: "Join Workshop"))
    |> fill_in(text_field("participant[name]"), with: "Alice")
    |> click(button("Join Workshop"))
    |> assert_has(css("h1", text: "Waiting Room"))
    |> assert_has(css("span", text: "Alice"))
  end

  @tag :e2e
  feature "home page displays correctly", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("h1", text: "Productive Work Groups"))
    |> assert_has(link("Start New Workshop"))
  end
end
