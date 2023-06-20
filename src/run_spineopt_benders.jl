#############################################################################
# Copyright (C) 2017 - 2023  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

function rerun_spineopt_benders!(
    m::Model,
    url_out::Union{String,Nothing};
    add_user_variables=m -> nothing,
    add_constraints=m -> nothing,
    update_constraints=m -> nothing,
    log_level=3,
    optimize=true,
    update_names=false,
    alternative="",
    alternative_objective=m -> nothing,
    write_as_roll=0,
    resume_file_path=nothing
)
    m_mp = master_problem_model(m)
    @timelog log_level 2 "Creating temporal structure..." begin
        generate_temporal_structure!(m)
        generate_temporal_structure!(m_mp; rolling=false)
    end
    @timelog log_level 2 "Creating stochastic structure..." begin
        generate_stochastic_structure!(m)
        generate_stochastic_structure!(m_mp)
    end
    sp_roll_count = _roll_count(m)
    @log log_level 2 """
    NOTE: We will first build model $(m.ext[:spineopt].instance) for the last optimisation window to make sure it can roll that far.
    We will bring it back to the first window whenever it is time to start solving it.
    """
    roll_temporal_structure!(m, 1:sp_roll_count)
    init_model!(m; add_constraints=add_constraints, log_level=log_level)
    _init_mp_model!(m_mp; add_constraints=add_constraints, log_level=log_level)
    max_benders_iterations = max_iterations(model=m_mp.ext[:spineopt].instance)
    j = 1
    while optimize
		@log log_level 0 "\nStarting Benders iteration $j"
        optimize_model!(m_mp; log_level=log_level) || break
        @timelog log_level 2 "Processing master problem solution" process_master_problem_solution!(m_mp)
        k = 1
        subproblem_solved = nothing
        @timelog log_level 2 "Bringing $(m.ext[:spineopt].instance) back to the first window..." begin
            roll_temporal_structure!(m, 1:sp_roll_count; rev=true)
            _update_variable_names!(m)
            _update_constraint_names!(m)
        end
        while true
            @log log_level 1 "\nBenders iteration $j - Window $k: $(current_window(m))"
            subproblem_solved = optimize_model!(m; log_level=log_level, calculate_duals=true)
            subproblem_solved || break
            @timelog log_level 2 "Processing subproblem solution..." process_subproblem_solution!(m)
            if @timelog log_level 2 "Rolling temporal structure...\n" !roll_temporal_structure!(m, k)
                @log log_level 2 "... Rolling complete\n"
                correct_sp_objective_value!(m)
                break
            end
            update_model!(m; update_constraints=update_constraints, log_level=log_level, update_names=update_names)
            k += 1
        end
        subproblem_solved || break
        @timelog log_level 2 "Computing benders gap..." save_mp_objective_bounds_and_gap!(m_mp)
        @log log_level 1 "Benders iteration $j complete"
        @log log_level 1 "Objective lower bound: $(@sprintf("%.5e", m_mp.ext[:spineopt].objective_lower_bound[])); "
        @log log_level 1 "Objective upper bound: $(@sprintf("%.5e", m_mp.ext[:spineopt].objective_upper_bound[])); "
        gaps = m_mp.ext[:spineopt].benders_gaps
        @log log_level 1 "Gap: $(@sprintf("%1.4f", last(gaps) * 100))%"
        if last(gaps) <= max_gap(model=m_mp.ext[:spineopt].instance)
            @log log_level 1 "Benders tolerance satisfied, terminating..."
            break
        end
        max_stale_iters = 3
        if length(gaps) >= max_stale_iters && all(gaps[end - i] == last(gaps) for i in 1:(max_stale_iters - 1))
            @log log_level 1 "Benders gap not improving for $max_stale_iters consecutive iterations, terminating..."
            break
        end
        if j >= max_benders_iterations
            @log log_level 1 "Maximum number of iterations reached ($j), terminating..."
            break
        end
        @timelog log_level 2 "Add MP cuts..." _add_mp_cuts!(m_mp; log_level=3)
        msg = "Resetting sub problem temporal structure. Rewinding $(k - 1) times..."
        if update_names
            _update_variable_names!(m)
            _update_constraint_names!(m)
        end
        j += 1
        global current_bi = add_benders_iteration(j)
    end
    write_report(m, url_out; alternative=alternative, log_level=log_level)
    m
end

"""
Initialize the given model for SpineOpt Master Problem: add variables, fix the necessary variables,
add constraints and set objective.
"""
function _init_mp_model!(m; add_constraints=m -> nothing, log_level=3)
    @timelog log_level 2 "Adding MP variables...\n" _add_mp_variables!(m; log_level=log_level)
    @timelog log_level 2 "Adding MP constraints...\n" _add_mp_constraints!(
        m; add_constraints=add_constraints, log_level=log_level
    )
    @timelog log_level 2 "Setting MP objective..." _set_mp_objective!(m)
end

"""
Add SpineOpt Master Problem variables to the given model.
"""
function _add_mp_variables!(m; log_level=3)
    for (name, add_variable!) in (
            ("mp_objective_lowerbound", add_variable_mp_objective_lowerbound!),
            ("mp_units_invested", add_variable_units_invested!),
            ("mp_units_invested_available", add_variable_units_invested_available!),
            ("mp_units_mothballed", add_variable_units_mothballed!),
            ("mp_connections_invested", add_variable_connections_invested!),
            ("mp_connections_invested_available", add_variable_connections_invested_available!),
            ("mp_connections_decommissioned", add_variable_connections_decommissioned!),
            ("mp_storages_invested", add_variable_storages_invested!),
            ("mp_storages_invested_available", add_variable_storages_invested_available!),
            ("mp_storages_decommissioned", add_variable_storages_decommissioned!),
        )
        @timelog log_level 3 "- [variable_$name]" add_variable!(m)
    end
end

"""
Add SpineOpt master problem constraints to the given model.
"""
function _add_mp_constraints!(m; add_constraints=m -> nothing, log_level=3)
    for (name, add_constraint!) in (
            ("constraint_mp_objective", _add_constraint_mp_objective!),
            ("constraint_unit_lifetime", add_constraint_unit_lifetime!),
            ("constraint_units_invested_transition", add_constraint_units_invested_transition!),
            ("constraint_units_invested_available", add_constraint_units_invested_available!),
            ("constraint_connection_lifetime", add_constraint_connection_lifetime!),
            ("constraint_connections_invested_transition", add_constraint_connections_invested_transition!),
            ("constraint_connections_invested_available", add_constraint_connections_invested_available!),
            ("constraint_storage_lifetime", add_constraint_storage_lifetime!),
            ("constraint_storages_invested_transition", add_constraint_storages_invested_transition!),
            ("constraint_storages_invested_available", add_constraint_storages_invested_available!),
        )
        @timelog log_level 3 "- [constraint_$name]" add_constraint!(m)
    end
    _update_constraint_names!(m)
end

"""
    add_constraint_units_on!(m::Model, units_on, units_available)

Limit the units_on by the number of available units.
"""
function _add_constraint_mp_objective!(m::Model)
    @fetch units_invested, mp_objective_lowerbound = m.ext[:spineopt].variables
    m.ext[:spineopt].constraints[:mp_objective] = Dict(
        (model=m.ext[:spineopt].instance,) => @constraint(
            m,
            + expr_sum(mp_objective_lowerbound[t] for (t,) in mp_objective_lowerbound_indices(m); init=0)
            >=
            + total_costs(m, anything; invesments_only=true)
        )
    )
end

"""
    _set_mp_objective!(m::Model)

Minimize total costs
"""
function _set_mp_objective!(m::Model)
    @fetch mp_objective_lowerbound = m.ext[:spineopt].variables
    @objective(m, Min, expr_sum(mp_objective_lowerbound[t] for (t,) in mp_objective_lowerbound_indices(m); init=0))
end

"""
Update (readd) SpineOpt master problem constraints that involve new objects (update doesn't work).
"""
function _add_mp_cuts!(m; log_level=3)
    @timelog log_level 3 " - [constraint_mp_any_invested_cuts]" add_constraint_mp_any_invested_cuts!(m)
    # Name constraints
    cons = m.ext[:spineopt].constraints[:mp_units_invested_cut]
    for (inds, con) in cons
        _set_name(con, string(:mp_units_invested_cut, inds))
    end
end
