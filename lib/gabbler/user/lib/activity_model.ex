defmodule Gabbler.User.ActivityModel do
  @moduledoc """
  A struct representing a users activity and some cached state such as subscriptions.
  Activity represents a rolling list of recent activity of interest to a user.
  """
  @derive [Jason.Encoder]
  defstruct user: nil,
            posts: [],
            votes: [],
            subs: [],
            moderating: [],
            activity: [],
            requests: [],
            read_receipt: true
end
