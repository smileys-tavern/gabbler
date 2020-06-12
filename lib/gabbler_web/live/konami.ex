defmodule GabblerWeb.Live.Konami do
  @moduledoc """
  Add Konami code detection to any Live View. Requires a module and function be included to run upon
  success. The result of success will be assigned to the socket under key :konami. Note that another key
  called sequence will be maintained on the socket to track keystrokes.

  UP UP DOWN DOWN LEFT RIGHT LEFT RIGHT B A
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Phoenix.LiveView

      @timeout Keyword.get(opts, :timeout, 5000)

      def handle_info(:sequence_timeout, socket), do: {:noreply, assign(socket, sequence: [])}

      def handle_event("keydown", %{"key" => key}, socket), 
        do: input(socket, key)
        |> check_sequence()

      # PRIVATE FUNCTIONS
      ###################
      defp input(%{assigns: %{sequence: sequence}} = socket, "ArrowLeft"),
        do: assign(socket, sequence: [:left | sequence])

      defp input(%{assigns: %{sequence: sequence}} = socket, "ArrowRight"),
        do: assign(socket, sequence: [:right | sequence])

      defp input(%{assigns: %{sequence: sequence}} = socket, "ArrowUp"),
        do: assign(socket, sequence: [:up | sequence])

      defp input(%{assigns: %{sequence: sequence}} = socket, "ArrowDown"),
        do: assign(socket, sequence: [:down | sequence])

      defp input(%{assigns: %{sequence: sequence}} = socket, "a"),
        do: assign(socket, sequence: [:a | sequence])

      defp input(%{assigns: %{sequence: sequence}} = socket, "b"),
        do: assign(socket, sequence: [:b | sequence])

      defp input(socket, key)
        when key not in ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "a", "b"],
        do: assign(socket, sequence: [])

      defp input(socket, key), 
        do: assign(socket, sequence: []) 
        |> input(key)

      # Sequence Begun: start reset timer
      defp check_sequence(%{assigns: %{sequence: [:up]}} = socket) do
        Process.send_after(self(), :sequence_timeout, @timeout)

        {:noreply, socket}
      end

      # Success
      defp check_sequence(%{
        assigns: %{sequence: [:a, :b, :right, :left, :right, :left, :down, :down, :up, :up]}
      } = socket), do: {:noreply, assign(socket, konami: true)}

      defp check_sequence(%{assigns: %{sequence: sequence}} = socket) do
        cond do
          Enum.count(sequence) > 10 ->
            {:noreply, assign(socket, sequence: Enum.take(sequence, 10))}

          true ->
            {:noreply, socket}
        end
      end
    end
  end
end
