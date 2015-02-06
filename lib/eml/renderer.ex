defmodule Eml.Renderer do
  @moduledoc """
  Various helper functions for implementing an Eml renderer.
  """

  # Options helper

  @default_opts %{safe: true,
                  mode: :render}

  def new_opts(opts \\ %{}), do: Dict.merge(@default_opts, opts)
  # State helper

  @default_state %{type: :content,
                   chunks: [],
                   current_tag: nil}

  def new_state(state \\ %{}), do: Dict.merge(@default_state, state)

  # Content helpers

  def default_render_content({ :quoted, quoted }, _opts, %{chunks: chunks} = s) do
    %{s| type: :quoted, chunks: [quoted | chunks] }
  end

  def default_render_content({ :safe, data }, _opts, %{chunks: chunks} = s) do
    %{s| chunks: [data | chunks]}
  end

  def default_render_content(data, %{safe: false}, %{chunks: chunks} = s) when is_binary(data) do
    %{s| chunks: [data | chunks]}
  end

  def default_render_content(data, %{safe: true}, %{chunks: chunks} = s) when is_binary(data) do
    %{s| chunks: [escape(data) | chunks]}
  end

  def default_render_content(data, _, _) do
    raise Eml.CompileError, type: :unsupported_content_type, value: data
  end

  # Attribute helpers

  def default_render_attr_value({ :quoted, quoted }, _opts, %{chunks: chunks} = s) do
    %{s| type: :quoted, chunks: [quoted | chunks]}
  end

  def default_render_attr_value({ :safe, value }, _opts, %{chunks: chunks} = s) do
    %{s| chunks: [value | chunks]}
  end

  def default_render_attr_value(value, %{safe: false}, %{chunks: chunks} = s) when is_binary(value) do
    %{s| chunks: [value | chunks]}
  end

  def default_render_attr_value(value, %{safe: true}, %{chunks: chunks} = s) when is_binary(value) do
    %{s| chunks: [escape(value) | chunks]}
  end

  def default_render_attr_value(value, _, _) do
    raise Eml.CompileError, type: :unsupported_attribute_type, value: value
  end

  def attr_field(field) do
    field = Atom.to_string(field)
    if String.starts_with?(field, "_"),
      do: "data-" <> String.lstrip(field, ?_),
    else: field
  end

  def insert_whitespace(values) do
    insert_whitespace(values, [])
  end
  def insert_whitespace([v], acc) do
    :lists.reverse([v | acc])
  end
  def insert_whitespace([v | rest], acc) do
    insert_whitespace(rest, [" ", v | acc])
  end
  def insert_whitespace([], acc) do
    acc
  end

  # Text escaping

  def escape(s) do
    s
    |> :binary.replace("&", "&amp;", [:global])
    |> :binary.replace("<", "&lt;", [:global])
    |> :binary.replace(">", "&gt;", [:global])
    |> :binary.replace("'", "&#39;", [:global])
    |> :binary.replace("\"", "&quot;", [:global])
  end

  # Chunk helpers

  def chunk_type(_, :quoted), do: :quoted
  def chunk_type(type, _),   do: type

  # Create final result.

  def to_result(%{type: type, chunks: chunks}, %{safe: safe}, engine) do
    chunks
    |> :lists.reverse()
    |> maybe_quoted(type)
    |> generate_buffer(engine)
    |> maybe_safe(safe)
  end

  defp maybe_quoted(chunks, :quoted) do
    { :quoted, chunks }
  end
  defp maybe_quoted(chunks, _) do
    chunks
  end
  defp maybe_safe({ :quoted, chunks }, true) do
    { :quoted, { :safe, chunks } }
  end
  defp maybe_safe(chunks, true) do
    { :safe, chunks }
  end
  defp maybe_safe(chunks, false) do
    chunks
  end

  defp generate_buffer({ :quoted, chunks }, engine) do
    { :quoted, generate_buffer(chunks, "", engine) }
  end
  defp generate_buffer(chunks, _engine) do
    IO.iodata_to_binary(chunks)
  end

  defp generate_buffer([text | rest], buffer, engine) when is_binary(text) do
    buffer = engine.handle_text(buffer, text)
    generate_buffer(rest, buffer, engine)
  end
  defp generate_buffer([expr | rest], buffer, engine) do
    buffer = engine.handle_expr(buffer, "=", expr)
    generate_buffer(rest, buffer, engine)
  end
  defp generate_buffer([], buffer, engine) do
    engine.handle_body(buffer)
  end
end
