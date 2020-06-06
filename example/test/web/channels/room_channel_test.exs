defmodule ElmPhoenix.Web.RoomChannelTest do
  use ElmPhoenix.Web.ChannelCase

  alias ElmPhoenix.Web.RoomChannel

  setup do
    {:ok, _, socket} =
      socket("user_id", %{some: :assign})
      |> subscribe_and_join(RoomChannel, "room:lobby", %{"user_name" => "user1"})

    {:ok, socket: socket}
  end

  test "new_msg replies with status ok", %{socket: socket} do
    ref = push(socket, "new_msg", %{"msg" => "hello"})
    assert_reply(ref, :ok)
  end

  test "new_msg broadcasts", %{socket: socket} do
    push(socket, "new_msg", %{"msg" => "hello"})
    assert_broadcast("new_msg", %{msg: "hello", user_name: "user1"})
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push("broadcast", %{"some" => "data"})
  end
end
