defmodule Server.Worker do
	use GenServer

	## Client API

	def start_link(opts \\ []) do
		GenServer.start_link(__MODULE__, :ok, opts)
	end

	def get_temperature(pid, location) do
		GenServer.call(pid, {:location, location})
	end

	
	## Server API

	def handle_call({:location, location, option},  _from, stats) do
		case temperature_of(location, option)
			{:ok, temp} ->
				new_stats = update_stats(stats, location, option)
				{:reply, "#{temp}*#{String.capitalize(option)}", new_stats}
			_ -> 
				{:reply, :error, stats}
		end
	end

	## Server callbacks

	def init(:ok) do
		{:ok, %{}}
	end

	## Helper functions

	defp temperature_of(location, option) do
		url_for(location) 
		|> HTTPoison.get 
		|> parse_response(option)
	end

	defp url_for(location) do
		location = URI.encode(location)
		"http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{apikey()}"
	end

	
	defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}, option) do
		body 
		|> JSON.decode! 
		|> computer_temperature(option)
	end

	defp computer_temperature(json, option) do
		try do
			temp = convert(json["main"]["temp"], option) |> Float.round(2)
			{:ok, temp}
		rescue
			_ -> :error
		end
	end

	defp apikey() do
		"8536c81ebcb074abbe45452b799dec42"
	end

	defp convert(temperature, option) do
		cond do 
			option in ["f", "F"] -> 
				temperature * (9/5) - 459.67
			option in ["c", "C"] ->
				temperature - 273.15
			true ->
				temperature
		end
	end

	defp update_stats(old_stats, location, option) do
		case Map.has_key?(old_stats, location) do
			true ->
				Map.update!(old_stats, location, &(&1 + 1))
			false ->
				Map.put_new(old_stats, location, 1)
		end
	end

end