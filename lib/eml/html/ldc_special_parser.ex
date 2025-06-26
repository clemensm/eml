defmodule Eml.HTML.LDCSpecialParser do
  def filter_empty_content(parsed_html) do
    parsed_html
      |> Enum.map(&filter_element/1)
  end

  defp filter_element(element) when is_binary(element), do: element
  defp filter_element(%Eml.Element{} = element) do
    filtered_content = element.content
      |> filter_content()
      |> case do
        nil -> nil
      [] -> element.content
      [first_el | rest_content] -> 
        filter_empty_content(nil, nil, first_el, rest_content, [])
        |> Enum.reject(&is_nil/1)
        |> Enum.reverse()
      content when is_binary(content) -> content
    end

    %{element | content: filtered_content}
  end

  defp filter_content(nil), do: nil
  defp filter_content(content) when is_list(content), do: Enum.map(content, &filter_element/1)
  defp filter_content(content) when is_binary(content), do: maybe_trim_whitespace_content(content)


  defp filter_empty_content(%Eml.Element{} = prev_el, this_el, %Eml.Element{} = next_el, more_content, acc) when is_binary(this_el) do
    if String.starts_with?(to_string(prev_el.tag), "ldc") and String.starts_with?(to_string(next_el.tag), "ldc") do
      acc = [prev_el | acc]

      case more_content do 
        [] -> 
          [next_el | [this_el | acc]]
        [more_el | rest_content]  -> 
          # ensure that this_el is not trimmed in another call to filter_empty_content, so just skip it
          filter_empty_content(nil, next_el, more_el, rest_content, [this_el | acc])
      end
    else
      if String.trim(this_el) === "" do
        case more_content do
          [] -> 
            [next_el | [prev_el | acc]]
          [more_el | rest_content] -> 
            filter_empty_content(prev_el, next_el, more_el, rest_content, acc)
        end
      else
        case more_content do
          [] -> 
            [next_el | [this_el | [prev_el | acc]]]
          [more_el | rest_content] -> 
            acc = [prev_el | acc]
            filter_empty_content(this_el, next_el, more_el, rest_content, acc)
        end
      end
    end
  end

  defp filter_empty_content(prev_el, this_el, next_el, [], acc) do
    prev_el = maybe_trim_whitespace_content(prev_el) 
    this_el = maybe_trim_whitespace_content(this_el) 
    next_el = maybe_trim_whitespace_content(next_el)

    acc = if prev_el === "", do: acc, else: [prev_el | acc]
    acc = if this_el === "", do: acc, else: [this_el | acc]
    if next_el === "", do: acc, else: [next_el | acc]
  end
  defp filter_empty_content(prev_el, this_el, next_el, [more_el | rest_content], acc), do: 
    filter_empty_content(this_el, next_el, more_el, rest_content, [maybe_trim_whitespace_content(prev_el) | acc])

  defp maybe_trim_whitespace_content(content) when is_binary(content) do
    trimmed = String.trim(content)
    if trimmed === "", do: trimmed, else: content
  end
  defp maybe_trim_whitespace_content(element), do: element

end
