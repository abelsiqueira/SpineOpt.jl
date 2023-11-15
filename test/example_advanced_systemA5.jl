pathA5 = joinpath(dirname(@__DIR__), "system_A5.json")

url_in = "sqlite://"
test_data = JSON.parsefile(pathA5)
_load_test_data(url_in, test_data)
url_out = "sqlite:///$(@__DIR__)/test_systemA5.sqlite"
run_spineopt(url_in, url_out; upgrade=true, log_level=2)

some_week = temporal_block(:some_week)

# Vary resolution from 1 to 24 hours and rerun
for h in 1:24
    temporal_block.parameter_values[some_week][:resolution] =
        callable(db_api.from_database("""{"type": "duration", "data": "$(h) hours"}"""))
    m = rerun_spineopt(url_out; cleanup=false, log_level=1)
end
