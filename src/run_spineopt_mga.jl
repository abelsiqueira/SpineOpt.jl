function rerun_spineopt!(
    ::Nothing,
    ::Nothing,
    m_mga::Model,
    url_out::Union{String,Nothing};
    add_user_variables=m -> nothing,
    add_constraints=m -> nothing,
    update_constraints=m -> nothing,
    log_level=3,
    optimize=true,
    alternative_objective=m -> nothing,
    )
    outputs = Dict()
    mga_iterations = 0
    max_mga_iteration = max_mga_iterations(model=m.ext[:instance])
    name_mga_it = :mga_iteration
    mga_iteration = SpineOpt.ObjectClass(name_mga_it, [])
    @eval begin
        mga_iteration = $mga_iteration
    end
    @timelog log_level 2 "Preprocessing data structure..." preprocess_data_structure(; log_level=log_level)
    @timelog log_level 2 "Checking data structure..." check_data_structure(; log_level=log_level)
    @timelog log_level 2 "Creating temporal structure..." generate_temporal_structure!(m)
    @timelog log_level 2 "Creating stochastic structure..." generate_stochastic_structure!(m)
    init_model!(m; add_user_variables=add_user_variables, add_constraints=add_constraints, log_level=log_level,alternative_objective=alternative_objective)
    init_outputs!(m)
    k = 1
    while optimize
        @log log_level 1 "Window $k: $(current_window(m))"
        optimize_model!(
            m;
            log_level=log_level,
            iterations=mga_iterations
        ) || break
        @timelog log_level 2 "Fixing non-anticipativity values..." fix_non_anticipativity_values!(m)
        if @timelog log_level 2 "Rolling temporal structure...\n" !roll_temporal_structure!(m)
            @timelog log_level 2 " ... Rolling complete\n" break
        end
        update_model!(m; update_constraints=update_constraints, log_level=log_level)
        k += 1
    end
    m
    name_mga_obj = :objective_value_mga
    model.parameter_values[m.ext[:instance]][name_mga_obj] = parameter_value(objective_value(m))
    @eval begin
        $(name_mga_obj) = $(Parameter(name_mga_obj, [model]))
    end
    mga_iterations += 1
    add_mga_objective_constraint!(m)
    set_mga_objective!(m)
    while mga_iterations <= max_mga_iteration
        set_objective_mga_iteration!(m;iteration=mga_iteration()[end])
        optimize_model!(m;
                    log_level=log_level,
                    iterations=mga_iterations)  || break
        save_mga_objective_values!(m)
        mga_iterations += 1
    end
    write_report(m, url_out)
    m
end
