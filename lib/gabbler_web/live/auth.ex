defmodule GabblerWeb.Live.Auth do
  @moduledoc """
  Functions that handle events related to auth such as requiring login for events from the UI
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Gabbler.Accounts
      alias Gabbler.Subscription, as: GabSub
      import Gabbler.Live.SocketUtil, only: [assign_to: 3]

      @auth_req Keyword.fetch!(opts, :auth_required)

      # Authorization required events as defined by the Module using Live.Auth
      @impl true
      def handle_event(event, _, %{assigns: %{user: nil, temp_token: token}} = socket)
      when event in @auth_req do
        GabSub.broadcast("user:#{token}", %{event: "login_show"})

        {:noreply, socket}
      end

      # PRIVATE FUNCTIONS
      ###################
      # Takes the token or user, adds to the socket and disqualifies mount from matching 
      # here again
      defp init(socket, params, %{"user" => user} = session) when user != nil do
        assign(socket, temp_token: nil, user: user)
        |> init(params, Map.drop(session, ["user_token", "temp_token", "user"]))
      end

      defp init(socket, params, %{"temp_token" => token} = session) do
        assign(socket, temp_token: token, user: nil)
        |> init(params, Map.drop(session, ["user_token", "temp_token", "user"]))
        |> check_authorization()
      end

      defp init(socket, params, %{"user_token" => user_token} = session) do
        # TODO: logic to clear session if token doesn't work
        Accounts.get_user_by_session_token(user_token)
        |> assign_to(:user, socket)
        |> init(params, Map.drop(session, ["user_token", "temp_token", "user"]))
      end

      defp check_authorization(socket) do
        # TODO: 403 logic
        case @auth_req do
          [:full_page] -> socket
          _ -> socket
        end
      end
    end
  end
end
