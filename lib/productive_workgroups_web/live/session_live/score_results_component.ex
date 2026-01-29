defmodule ProductiveWorkgroupsWeb.SessionLive.ScoreResultsComponent do
  @moduledoc """
  LiveComponent for displaying score results and notes capture.
  Isolates re-renders to just this section when scores change.

  Note: Facilitator tips (discussion prompts) are displayed on the question card
  during the scoring phase, not on this results component.
  """
  use ProductiveWorkgroupsWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # All events are handled by parent LiveView for test compatibility
  # This component is purely for render isolation

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Results summary -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h2 class="text-lg font-semibold text-white mb-4">Discuss the results as a team</h2>
        
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
      
    <!-- Toggle button for notes - events go to parent -->
      <div>
        <button
          type="button"
          phx-click="toggle_notes"
          class={[
            "w-full px-4 py-3 rounded-lg font-medium transition-colors flex items-center justify-center gap-2",
            if(@show_notes,
              do: "bg-blue-600 text-white",
              else: "bg-gray-700 text-gray-300 hover:bg-gray-600"
            )
          ]}
        >
          <span>{if @show_notes, do: "Hide", else: "Take"} Notes</span>
          <%= if length(@question_notes) > 0 do %>
            <span class="bg-gray-600 text-white text-xs px-2 py-0.5 rounded-full">
              {length(@question_notes)}
            </span>
          <% end %>
        </button>
      </div>
      
    <!-- Notes capture (collapsible) -->
      <%= if @show_notes do %>
        <div class="bg-gray-800 rounded-lg p-6 border border-blue-600/50">
          <h2 class="text-lg font-semibold text-blue-400 mb-4">
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
          
    <!-- Add note form - events go to parent LiveView for test compatibility -->
          <form phx-submit="add_note" class="flex gap-2">
            <input
              type="text"
              name="note"
              value={@note_input}
              phx-change="update_note_input"
              phx-debounce="300"
              placeholder="Capture a key discussion point..."
              class="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
            />
            <button
              type="submit"
              class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors"
            >
              Add
            </button>
          </form>
          <p class="text-xs text-gray-500 mt-2">
            Notes are visible to all participants and saved with the session.
          </p>
        </div>
      <% end %>
      
    <!-- Ready / Next controls -->
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
              phx-click="next_question"
              class="flex-1 px-6 py-3 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
            >
              <%= if @session.current_question_index + 1 >= 8 do %>
                Continue to Summary →
              <% else %>
                Next Question →
              <% end %>
            </button>
          </div>
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
end
