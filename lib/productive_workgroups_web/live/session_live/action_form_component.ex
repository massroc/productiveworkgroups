defmodule ProductiveWorkgroupsWeb.SessionLive.ActionFormComponent do
  @moduledoc """
  LiveComponent for the action creation form.
  Manages form state locally to avoid parent re-renders on input changes.
  """
  use ProductiveWorkgroupsWeb, :live_component

  alias ProductiveWorkgroups.Notes
  alias ProductiveWorkgroups.Sessions

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(action_description: "")
     |> assign(action_owner: "")}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, session: assigns.session)}
  end

  @impl true
  def handle_event("update_action_description", %{"description" => value}, socket) do
    {:noreply, assign(socket, action_description: value)}
  end

  @impl true
  def handle_event("update_action_owner", %{"owner" => value}, socket) do
    {:noreply, assign(socket, action_owner: value)}
  end

  @impl true
  def handle_event("create_action", _params, socket) do
    description = String.trim(socket.assigns.action_description)

    if description == "" do
      send(self(), {:flash, :error, "Please enter an action description"})
      {:noreply, socket}
    else
      session = socket.assigns.session

      attrs = %{
        description: description,
        owner_name: String.trim(socket.assigns.action_owner)
      }

      case Notes.create_action(session, attrs) do
        {:ok, action} ->
          broadcast_action_update(session, action.id)
          # Notify parent to reload actions
          send(self(), :reload_actions)

          {:noreply,
           socket
           |> assign(action_description: "")
           |> assign(action_owner: "")}

        {:error, _} ->
          send(self(), {:flash, :error, "Failed to create action"})
          {:noreply, socket}
      end
    end
  end

  defp broadcast_action_update(session, action_id) do
    Phoenix.PubSub.broadcast(
      ProductiveWorkgroups.PubSub,
      Sessions.session_topic(session),
      {:action_updated, action_id}
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 mb-6">
      <h2 class="text-lg font-semibold text-white mb-4">Add Action Item</h2>
      <form phx-submit="create_action" phx-target={@myself} class="space-y-4">
        <div>
          <label class="block text-sm text-gray-400 mb-1">What needs to be done?</label>
          <input
            type="text"
            name="description"
            value={@action_description}
            phx-change="update_action_description"
            phx-target={@myself}
            phx-debounce="300"
            placeholder="Describe the action..."
            class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
          />
        </div>
        <div>
          <label class="block text-sm text-gray-400 mb-1">Owner (optional)</label>
          <input
            type="text"
            name="owner"
            value={@action_owner}
            phx-change="update_action_owner"
            phx-target={@myself}
            phx-debounce="300"
            placeholder="Who will do this?"
            class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:border-green-500"
          />
        </div>
        <button
          type="submit"
          class="w-full px-4 py-2 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors"
        >
          Add Action
        </button>
      </form>
    </div>
    """
  end
end
