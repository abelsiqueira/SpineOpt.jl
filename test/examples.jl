examplepath = joinpath(dirname(@__DIR__),"examples")

for examplefile in readdir(examplepath)
    examplejson = joinpath(examplepath, examplefile)
    url_in = "sqlite://"
    test_data = JSON.parsefile(examplejson)
    test_data = Dict(Symbol(key) => value for (key, value) in test_data)
    _load_test_data(url_in, test_data)
    run_spineopt(url_in)
end