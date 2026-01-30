defmodule ProductiveWorkgroupsWeb.SessionLive.New do
  @moduledoc """
  LiveView for creating a new workshop session as a facilitator.
  """
  use ProductiveWorkgroupsWeb, :live_view

  alias ProductiveWorkgroups.Workshops

  @impl true
  def mount(_params, _session, socket) do
    template = Workshops.get_template_by_slug("six-criteria")

    {:ok,
     socket
     |> assign(page_title: "Create Workshop")
     |> assign(template: template)
     |> assign(facilitator_name: "")
     |> assign(facilitator_participating: true)
     |> assign(duration_option: "none")
     |> assign(custom_duration: 120)
     |> assign(timer_expanded: false)
     |> assign(error: nil)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    name = params["facilitator_name"] || socket.assigns.facilitator_name

    {:noreply,
     socket
     |> assign(facilitator_name: name)
     |> assign(error: nil)}
  end

  @impl true
  def handle_event("select_duration", %{"option" => option}, socket) do
    {:noreply, assign(socket, duration_option: option)}
  end

  @impl true
  def handle_event("toggle_participating", _params, socket) do
    {:noreply,
     assign(socket, facilitator_participating: !socket.assigns.facilitator_participating)}
  end

  @impl true
  def handle_event("toggle_timer", _params, socket) do
    {:noreply, assign(socket, timer_expanded: !socket.assigns.timer_expanded)}
  end

  defp format_duration(minutes) do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)

    cond do
      hours == 0 -> "#{mins} min"
      mins == 0 -> "#{hours} hr"
      true -> "#{hours} hr #{mins} min"
    end
  end

  @impl true
  def render(assigns) do
    final_duration =
      case assigns.duration_option do
        "none" -> nil
        "custom" -> assigns.custom_duration
        option -> String.to_integer(option)
      end

    assigns = assign(assigns, :final_duration, final_duration)

    ~H"""
    <div class="min-h-screen bg-gray-900 flex flex-col items-center justify-center px-4">
      <div class="max-w-md w-full">
        <.link navigate={~p"/"} class="text-gray-400 hover:text-white mb-8 inline-flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10 19l-7-7m0 0l7-7m-7 7h18"
            />
          </svg>
          Back to Home
        </.link>

        <h1 class="text-2xl font-bold text-white mb-2 text-center">
          Create New Workshop
        </h1>
        <p class="text-gray-400 text-center mb-8">
          Set up your Six Criteria workshop and invite your team
        </p>

        <form action={~p"/session/create"} method="post" phx-change="validate" class="space-y-6">
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <input type="hidden" name="duration" value={@final_duration || ""} />
          <input
            type="hidden"
            name="facilitator_participating"
            value={to_string(@facilitator_participating)}
          />

          <div>
            <label for="facilitator_name" class="block text-sm font-medium text-gray-300 mb-2">
              Your Name (Facilitator)
            </label>
            <input
              type="text"
              name="facilitator_name"
              id="facilitator_name"
              value={@facilitator_name}
              placeholder="Enter your name"
              class="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-4 text-white text-lg placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              autofocus
              required
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Facilitator Role
            </label>
            <div class="flex gap-3">
              <button
                type="button"
                phx-click="toggle_participating"
                class={[
                  "px-8 py-3 rounded-lg border transition-colors flex items-center gap-3",
                  if(@facilitator_participating,
                    do: "bg-blue-600 border-blue-500 text-white",
                    else: "bg-gray-800 border-gray-700 text-gray-400 hover:border-gray-600"
                  )
                ]}
              >
                <svg
                  class={[
                    "w-5 h-5 flex-shrink-0",
                    if(@facilitator_participating, do: "text-white", else: "text-gray-500")
                  ]}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                </svg>
                <span>Participating</span>
              </button>

              <button
                type="button"
                phx-click="toggle_participating"
                class={[
                  "px-8 py-3 rounded-lg border transition-colors flex items-center gap-3",
                  if(!@facilitator_participating,
                    do: "bg-blue-600 border-blue-500 text-white",
                    else: "bg-gray-800 border-gray-700 text-gray-400 hover:border-gray-600"
                  )
                ]}
              >
                <svg
                  class={[
                    "w-5 h-5 flex-shrink-0",
                    if(!@facilitator_participating, do: "text-white", else: "text-gray-500")
                  ]}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                  />
                </svg>
                <span>Observer</span>
              </button>
            </div>
            <p class={[
              "text-sm mt-2 h-5",
              if(!@facilitator_participating, do: "text-amber-400", else: "text-transparent")
            ]}>
              <%= if !@facilitator_participating do %>
                As an observer, you'll need a team member to join before starting.
              <% else %>
                &nbsp;
              <% end %>
            </p>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-300 mb-3">
              Session Timer
            </label>

            <button
              type="button"
              phx-click="toggle_timer"
              class={[
                "w-full px-4 py-3 rounded-lg border transition-colors flex items-center gap-3",
                if(@timer_expanded,
                  do: "bg-gray-800 border-gray-600",
                  else: "bg-gray-800 border-gray-700 hover:border-gray-600"
                )
              ]}
            >
              <div class={[
                "w-10 h-10 rounded-lg flex items-center justify-center transition-colors",
                if(@duration_option != "none",
                  do: "bg-blue-600 text-white",
                  else: "bg-gray-700 text-gray-500"
                )
              ]}>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
              </div>
              <div class="flex-1 text-left">
                <div class="text-white font-medium">
                  <%= case @duration_option do %>
                    <% "none" -> %>
                      No timer
                    <% "120" -> %>
                      2 hours
                    <% "210" -> %>
                      3.5 hours
                    <% "custom" -> %>
                      {format_duration(@custom_duration)}
                  <% end %>
                </div>
              </div>
              <svg
                class={[
                  "w-5 h-5 text-gray-400 transition-transform",
                  if(@timer_expanded, do: "rotate-180")
                ]}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>

            <%= if @timer_expanded do %>
              <div class="mt-3 space-y-3">
                <div class="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    phx-click="select_duration"
                    phx-value-option="none"
                    class={[
                      "px-3 py-2 rounded-lg border transition-colors text-left text-sm",
                      if(@duration_option == "none",
                        do: "bg-blue-600 border-blue-500 text-white",
                        else: "bg-gray-800 border-gray-700 text-gray-300 hover:border-gray-600"
                      )
                    ]}
                  >
                    <div class="font-medium">No timer</div>
                  </button>
                  <button
                    type="button"
                    phx-click="select_duration"
                    phx-value-option="120"
                    class={[
                      "px-3 py-2 rounded-lg border transition-colors text-left text-sm",
                      if(@duration_option == "120",
                        do: "bg-blue-600 border-blue-500 text-white",
                        else: "bg-gray-800 border-gray-700 text-gray-300 hover:border-gray-600"
                      )
                    ]}
                  >
                    <div class="font-medium">2 hours</div>
                    <div class="text-xs opacity-75">Normal</div>
                  </button>
                  <button
                    type="button"
                    phx-click="select_duration"
                    phx-value-option="210"
                    class={[
                      "px-3 py-2 rounded-lg border transition-colors text-left text-sm",
                      if(@duration_option == "210",
                        do: "bg-blue-600 border-blue-500 text-white",
                        else: "bg-gray-800 border-gray-700 text-gray-300 hover:border-gray-600"
                      )
                    ]}
                  >
                    <div class="font-medium">3.5 hours</div>
                    <div class="text-xs opacity-75">Full session</div>
                  </button>
                  <button
                    type="button"
                    phx-click="select_duration"
                    phx-value-option="custom"
                    class={[
                      "px-3 py-2 rounded-lg border transition-colors text-left text-sm",
                      if(@duration_option == "custom",
                        do: "bg-blue-600 border-blue-500 text-white",
                        else: "bg-gray-800 border-gray-700 text-gray-300 hover:border-gray-600"
                      )
                    ]}
                  >
                    <div class="font-medium">Custom</div>
                    <div class="text-xs opacity-75">Set your own</div>
                  </button>
                </div>

                <%= if @duration_option == "custom" do %>
                  <div
                    id="duration-picker"
                    phx-hook="DurationPicker"
                    data-duration={@custom_duration}
                    class="flex items-center justify-center gap-4 bg-gray-800 rounded-lg p-4"
                  >
                    <button
                      type="button"
                      data-action="decrement"
                      class="w-12 h-12 flex-shrink-0 flex items-center justify-center bg-gray-700 hover:bg-gray-600 text-white text-2xl font-bold rounded-lg transition-colors select-none"
                    >
                      −
                    </button>
                    <div class="text-center" style="width: 140px;">
                      <div
                        data-display="formatted"
                        class="text-2xl font-bold text-white whitespace-nowrap"
                      >
                        {format_duration(@custom_duration)}
                      </div>
                      <div class="text-sm text-gray-400">
                        <span data-display="minutes">{@custom_duration}</span> minutes
                      </div>
                    </div>
                    <button
                      type="button"
                      data-action="increment"
                      class="w-12 h-12 flex-shrink-0 flex items-center justify-center bg-gray-700 hover:bg-gray-600 text-white text-2xl font-bold rounded-lg transition-colors select-none"
                    >
                      +
                    </button>
                    <input
                      type="hidden"
                      name="custom_duration"
                      data-input="duration"
                      value={@custom_duration}
                    />
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <%= if @error do %>
            <p class="text-red-400 text-sm">{@error}</p>
          <% end %>

          <button
            type="submit"
            class="w-full px-6 py-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors text-lg"
          >
            Create Workshop
          </button>
        </form>

        <p class="text-gray-500 text-sm text-center mt-6">
          You'll get a link to share with your team so they can join.
        </p>
      </div>
    </div>
    """
  end
end
