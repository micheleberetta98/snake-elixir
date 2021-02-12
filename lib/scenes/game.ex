defmodule Snake.Scene.Game do
  use Scenic.Scene
  alias Scenic.Graph
  alias Scenic.ViewPort
  import Scenic.Primitives, only: [text: 3, rrect: 3]

  @graph Graph.build(font_size: 36)
  @tile_size 32
  @tile_radius 8
  @snake_starting_size 5
  @frame_ms 150
  @apple_score 1
  @game_over_scene Snake.Scene.GameOver

  # Initialize the viewport
  def init(_arg, opts) do
    viewport = opts[:viewport]

    {:ok, %ViewPort.Status{size: {vp_width, vp_height}}} = ViewPort.info(viewport)

    vp_tile_width = trunc(vp_width / @tile_size)
    vp_tile_height = trunc(vp_height / @tile_size)

    snake_start_coords = {
      trunc(vp_tile_width / 2),
      trunc(vp_tile_height / 2)
    }

    apple_start_coords = {
      vp_tile_width - 2,
      trunc(vp_tile_height / 2)
    }

    {:ok, timer} = :timer.send_interval(@frame_ms, :frame)

    state = %{
      viewport: viewport,
      tile_width: vp_tile_width,
      tile_height: vp_tile_height,
      graph: @graph,
      frame_count: 1,
      frame_timer: timer,
      score: 0,
      objects: %{
        snake: %{
          body: [snake_start_coords],
          size: @snake_starting_size,
          direction: {1, 0}
        },
        apple: apple_start_coords
      }
    }

    {
      :ok,
      state,
      push:
        state.graph
        |> draw_score(state.score)
        |> draw_game_objects(state.objects)
    }
  end

  # Handle the timer

  def handle_info(:frame, %{frame_count: frame_count} = state) do
    state = move_snake(state)

    {
      :noreply,
      %{state | frame_count: frame_count + 1},
      push:
        state.graph
        |> draw_score(state.score)
        |> draw_game_objects(state.objects)
    }
  end

  # Keyboard events

  def handle_input({:key, {"left", :press, _}}, _context, state) do
    {:noreply, update_snake_direction(state, {-1, 0})}
  end

  def handle_input({:key, {"right", :press, _}}, _context, state) do
    {:noreply, update_snake_direction(state, {1, 0})}
  end

  def handle_input({:key, {"up", :press, _}}, _context, state) do
    {:noreply, update_snake_direction(state, {0, -1})}
  end

  def handle_input({:key, {"down", :press, _}}, _context, state) do
    {:noreply, update_snake_direction(state, {0, 1})}
  end

  def handle_input(_input, _context, state), do: {:noreply, state}

  def update_snake_direction(state, direction) do
    put_in(state, [:objects, :snake, :direction], direction)
  end

  # Utilities for movement

  defp move_snake(%{objects: %{snake: snake}} = state) do
    [head | _] = snake.body
    new_head = move(state, head, snake.direction)
    new_body = Enum.take([new_head | snake.body], snake.size)

    state
    |> put_in([:objects, :snake, :body], new_body)
    |> maybe_eat_apple(new_head)
    |> maybe_die
  end

  defp move(%{tile_width: w, tile_height: h}, {x, y}, {dx, dy}) do
    {rem(x + dx + w, w), rem(y + dy + h, h)}
  end

  # Eating the apple

  defp maybe_eat_apple(state = %{objects: %{apple: apple_coords}}, head_coords)
       when apple_coords == head_coords do
    state
    |> random_apple()
    |> add_score(@apple_score)
    |> grow()
  end

  defp maybe_eat_apple(state, _), do: state

  defp random_apple(state = %{tile_width: w, tile_height: h}) do
    coords = {
      Enum.random(0..(w - 1)),
      Enum.random(0..(h - 1))
    }

    validate_apple_coords(state, coords)
  end

  defp validate_apple_coords(state = %{objects: %{snake: %{body: snake}}}, coords) do
    if coords in snake do
      random_apple(state)
    else
      put_in(state, [:objects, :apple], coords)
    end
  end

  # Snek is ded

  def maybe_die(state = %{viewport: vp, objects: %{snake: %{body: snake}}, score: score}) do
    if length(Enum.uniq(snake)) < length(snake) do
      ViewPort.set_root(vp, {@game_over_scene, score})
    end

    state
  end

  # Points and snake size

  defp add_score(state, score) do
    update_in(state, [:score], &(&1 + score))
  end

  defp grow(state) do
    update_in(state, [:objects, :snake, :size], &(&1 + 1))
  end

  # Utilities for drawing stuff

  defp draw_score(graph, score) do
    graph
    |> text("Score: #{score}", fill: :white, translate: {@tile_size, @tile_size})
  end

  defp draw_game_objects(graph, object_map) do
    object_map
    |> Enum.reduce(graph, fn {type, data}, graph ->
      draw_object(graph, type, data)
    end)
  end

  defp draw_object(graph, :snake, %{body: snake}) do
    snake
    |> Enum.reduce(graph, fn {x, y}, graph ->
      draw_tile(graph, x, y, fill: :lime)
    end)
  end

  defp draw_object(graph, :apple, {x, y}) do
    draw_tile(graph, x, y, fill: :red, id: :apple)
  end

  defp draw_tile(graph, x, y, opts) do
    tile_opts = Keyword.merge([fill: :white, translate: {x * @tile_size, y * @tile_size}], opts)
    graph |> rrect({@tile_size, @tile_size, @tile_radius}, tile_opts)
  end
end
