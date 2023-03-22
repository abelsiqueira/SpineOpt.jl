#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
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

@testset "unit-based constraints" begin
    url_in = "sqlite://"
    test_data = Dict(
        :objects => [
            ["model", "instance"],
            ["model", "master"],
            ["temporal_block", "hourly"],
            ["temporal_block", "investments_hourly"],
            ["temporal_block", "two_hourly"],
            ["stochastic_structure", "deterministic"],
            ["stochastic_structure", "investments_deterministic"],
            ["stochastic_structure", "stochastic"],
            ["unit", "unit_ab"],
            ["node", "node_a"],
            ["node", "node_b"],
            ["node", "node_c"],
            ["node", "node_group_bc"],
            ["stochastic_scenario", "parent"],
            ["stochastic_scenario", "child"],
        ],
        :relationships => [
            ["model__temporal_block", ["instance", "hourly"]],
            ["model__temporal_block", ["master", "investments_hourly"]],
            ["model__temporal_block", ["instance", "two_hourly"]],
            ["model__stochastic_structure", ["instance", "deterministic"]],
            ["model__stochastic_structure", ["master", "investments_deterministic"]],
            ["model__stochastic_structure", ["instance", "stochastic"]],
            ["units_on__temporal_block", ["unit_ab", "hourly"]],
            ["units_on__stochastic_structure", ["unit_ab", "stochastic"]],
            ["unit__from_node", ["unit_ab", "node_a"]],
            ["unit__to_node", ["unit_ab", "node_b"]],
            ["unit__to_node", ["unit_ab", "node_c"]],
            ["node__temporal_block", ["node_a", "hourly"]],
            ["node__temporal_block", ["node_b", "two_hourly"]],
            ["node__temporal_block", ["node_c", "hourly"]],
            ["node__stochastic_structure", ["node_a", "stochastic"]],
            ["node__stochastic_structure", ["node_b", "deterministic"]],
            ["node__stochastic_structure", ["node_c", "stochastic"]],
            ["stochastic_structure__stochastic_scenario", ["deterministic", "parent"]],
            ["stochastic_structure__stochastic_scenario", ["investments_deterministic", "parent"]],
            ["stochastic_structure__stochastic_scenario", ["stochastic", "parent"]],
            ["stochastic_structure__stochastic_scenario", ["stochastic", "child"]],
            ["parent_stochastic_scenario__child_stochastic_scenario", ["parent", "child"]],
        ],
        :object_groups => [["node", "node_group_bc", "node_b"], ["node", "node_group_bc", "node_c"]],
        :object_parameter_values => [
            ["model", "instance", "model_start", Dict("type" => "date_time", "data" => "2000-01-01T00:00:00")],
            ["model", "instance", "model_end", Dict("type" => "date_time", "data" => "2000-01-01T02:00:00")],
            ["model", "instance", "duration_unit", "hour"],
            ["model", "instance", "model_type", "spineopt_standard"],
            ["model", "master", "model_start", Dict("type" => "date_time", "data" => "2000-01-01T00:00:00")],
            ["model", "master", "model_end", Dict("type" => "date_time", "data" => "2000-01-01T02:00:00")],
            ["model", "master", "duration_unit", "hour"],
            ["model", "master", "model_type", "spineopt_other"],
            ["model", "master", "max_gap", "0.05"],
            ["model", "master", "max_iterations", "2"],
            ["temporal_block", "hourly", "resolution", Dict("type" => "duration", "data" => "1h")],
            ["temporal_block", "investments_hourly", "resolution", Dict("type" => "duration", "data" => "1h")],
            ["temporal_block", "two_hourly", "resolution", Dict("type" => "duration", "data" => "2h")],
            ["model", "instance", "db_mip_solver", "Cbc.jl"],
            ["model", "instance", "db_lp_solver", "Clp.jl"],
        ],
        :relationship_parameter_values => [[
            "stochastic_structure__stochastic_scenario",
            ["stochastic", "parent"],
            "stochastic_scenario_end",
            Dict("type" => "duration", "data" => "1h"),
        ]],
    )
    @testset "initial_units_on" begin
        _load_test_data(url_in, test_data)
        init_units_on = 123
        object_parameter_values = [
            ["unit", "unit_ab", "initial_units_on", init_units_on],
        ]
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values)
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_on = m.ext[:spineopt].variables[:units_on]
        for key in keys(var_units_on)
            is_history_t = start(key.t) < model_start(model=m.ext[:spineopt].instance)
            @test is_fixed(var_units_on[key]) == is_history_t
            if is_history_t
                @test fix_value(var_units_on[key]) == init_units_on
            end
        end
    end
    @testset "constraint_units_on" begin
        _load_test_data(url_in, test_data)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_on = m.ext[:spineopt].variables[:units_on]
        var_units_available = m.ext[:spineopt].variables[:units_available]
        constraint = m.ext[:spineopt].constraints[:units_on]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (unit(:unit_ab), s, t)
            var_u_on = var_units_on[key...]
            var_u_av = var_units_available[key...]
            expected_con = @build_constraint(var_u_on <= var_u_av)
            con_u_on = constraint[key...]
            observed_con = constraint_object(con_u_on)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_units_available" begin
        _load_test_data(url_in, test_data)
        number_of_units = 4
        candidate_units = 3
        object_parameter_values = [
            ["unit", "unit_ab", "candidate_units", candidate_units],
            ["unit", "unit_ab", "number_of_units", number_of_units],
        ]
        relationships = [
            ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
            ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_available = m.ext[:spineopt].variables[:units_available]
        var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
        constraint = m.ext[:spineopt].constraints[:units_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (unit(:unit_ab), s, t)
            var_u_av = var_units_available[key...]
            var_u_inv_av = var_units_invested_available[key...]
            expected_con = @build_constraint(var_u_av - var_u_inv_av <= number_of_units)
            con_key = (unit(:unit_ab), [s], t)
            con = constraint[con_key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_unit_state_transition" begin
        _load_test_data(url_in, test_data)
        object_parameter_values = [["unit", "unit_ab", "online_variable_type", "unit_online_variable_type_integer"]]
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_on = m.ext[:spineopt].variables[:units_on]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        var_units_shut_down = m.ext[:spineopt].variables[:units_shut_down]
        constraint = m.ext[:spineopt].constraints[:unit_state_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (unit(:unit_ab), s1, t1)
            var_u_on1 = var_units_on[var_key1...]
            var_u_su1 = var_units_started_up[var_key1...]
            var_u_sd1 = var_units_shut_down[var_key1...]
            @testset for (u, t0, t1) in unit_dynamic_time_indices(m; unit=unit(:unit_ab), t_after=t1)
                var_key0 = (u, s0, t0)
                var_u_on0 = get(var_units_on, var_key0, 0)
                con_key = (u, path, t0, t1)
                expected_con = @build_constraint(var_u_on1 - var_u_on0 == var_u_su1 - var_u_sd1)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_unit_flow_capacity" begin
        _load_test_data(url_in, test_data)
        unit_capacity = 100
        relationships = [
                ["unit__to_node", ["unit_ab", "node_group_bc"]],
        ]
        relationship_parameter_values = [["unit__to_node", ["unit_ab", "node_group_bc"], "unit_capacity", unit_capacity]]
        SpineInterface.import_data(url_in; relationships=relationships,relationship_parameter_values=relationship_parameter_values)
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_units_on = m.ext[:spineopt].variables[:units_on]
        constraint = m.ext[:spineopt].constraints[:unit_flow_capacity]
        @test length(constraint) == 1
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices_b = time_slice(m; temporal_block=temporal_block(:two_hourly))
        @testset for (s, t) in zip(scenarios, time_slices_b)
            t_short_1 = sort(SpineOpt.t_in_t_excl(m;t_long=t))[1]
            t_short_2 = sort(SpineOpt.t_in_t_excl(m;t_long=t))[2]
            s_child = stochastic_scenario(:child)
            var_u_flow_key_b = (unit(:unit_ab), node(:node_b), direction(:to_node), s, t)
            var_u_flow_key_c_1 = (unit(:unit_ab), node(:node_c), direction(:to_node), s, t_short_1)
            var_u_flow_key_c_2 = (unit(:unit_ab), node(:node_c), direction(:to_node), s_child, t_short_2)
            var_u_on_key_1 = (unit(:unit_ab), s, t_short_1)
            var_u_on_key_2 = (unit(:unit_ab), s_child, t_short_2)
            var_u_flow_b = var_unit_flow[var_u_flow_key_b...]
            var_u_flow_c_1 = var_unit_flow[var_u_flow_key_c_1...]
            var_u_flow_c_2 = var_unit_flow[var_u_flow_key_c_2...]
            var_u_on_1 = var_units_on[var_u_on_key_1...]
            var_u_on_2 = var_units_on[var_u_on_key_2...]
            con_key = (unit(:unit_ab), node(:node_group_bc), direction(:to_node), [s,s_child], t)
            expected_con = @build_constraint(var_u_flow_c_1 +  var_u_flow_c_2 + 2*var_u_flow_b <= unit_capacity * (var_u_on_1 +  var_u_on_2))
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_minimum_operating_point" begin
        _load_test_data(url_in, test_data)
        unit_capacity = 100
        minimum_operating_point = 0.25
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
            ["unit__from_node", ["unit_ab", "node_a"], "minimum_operating_point", minimum_operating_point],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_units_on = m.ext[:spineopt].variables[:units_on]
        constraint = m.ext[:spineopt].constraints[:minimum_operating_point]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_u_on_key = (unit(:unit_ab), s, t)
            var_u_flow = var_unit_flow[var_u_flow_key...]
            var_u_on = var_units_on[var_u_on_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_u_flow >= minimum_operating_point * unit_capacity * var_u_on)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_operating_point_bounds" begin
        _load_test_data(url_in, test_data)
        unit_capacity = 100
        points = [0.1, 0.5, 1.0]
        deltas = [points[1]; [points[i] - points[i - 1] for i in 2:length(points)]]
        operating_points = Dict("type" => "array", "value_type" => "float", "data" => PyVector(points))
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
            ["unit__from_node", ["unit_ab", "node_a"], "operating_points", operating_points]
        ]
        relationships = [
            ["unit__to_node", ["unit_ab", "node_a"]],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values, relationships=relationships)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow_op = m.ext[:spineopt].variables[:unit_flow_op]
        var_units_avail = m.ext[:spineopt].variables[:units_available]
        constraint = m.ext[:spineopt].constraints[:operating_point_bounds]
        @test length(constraint) == 6
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for (i, delta) in enumerate(deltas)
                var_u_flow_op_key = (unit(:unit_ab), node(:node_a), direction(:from_node), i, s, t)
                var_us_avail_key = (unit(:unit_ab), s, t)
                var_u_flow_op = var_unit_flow_op[var_u_flow_op_key...]
                var_us_avail = var_units_avail[var_us_avail_key...]
                expected_con = @build_constraint(var_u_flow_op - delta * var_us_avail * unit_capacity <= 0)
                observed_con = constraint_object(constraint[var_u_flow_op_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_operating_point_sum" begin
        _load_test_data(url_in, test_data)
        unit_capacity = 100
        points = [0.1, 0.5, 1.0]
        operating_points = Dict("type" => "array", "value_type" => "float", "data" => PyVector(points))
        relationship_parameter_values =
            [["unit__from_node", ["unit_ab", "node_a"], "operating_points", operating_points]]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_unit_flow_op = m.ext[:spineopt].variables[:unit_flow_op]
        constraint = m.ext[:spineopt].constraints[:operating_point_sum]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            subkey = (unit(:unit_ab), node(:node_a), direction(:from_node))
            key = (subkey..., s, t)
            var_u_flow = var_unit_flow[key...]
            vars_u_flow_op = [var_unit_flow_op[(subkey..., i, s, t)...] for i in 1:length(points)]
            expected_con = @build_constraint(var_u_flow == sum(vars_u_flow_op))
            observed_con = constraint_object(constraint[key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_ratio_unit_flow" begin
        flow_ratio = 0.8
        units_on_coeff = 0.2
        class = "unit__node__node"
        relationship = ["unit_ab", "node_a", "node_b"]
        senses_by_prefix = Dict("min" => >=, "fix" => ==, "max" => <=)
        classes_by_prefix = Dict("in" => "unit__from_node", "out" => "unit__to_node")
        @testset for (p, a, b) in (
            ("min", "in", "in"),
            ("fix", "in", "in"),
            ("max", "in", "in"),
            ("min", "in", "out"),
            ("fix", "in", "out"),
            ("max", "in", "out"),
            ("min", "out", "in"),
            ("fix", "out", "in"),
            ("max", "out", "in"),
            ("min", "out", "out"),
            ("fix", "out", "out"),
            ("max", "out", "out"),
        )
            _load_test_data(url_in, test_data)
            ratio = join([p, "ratio", a, b, "unit_flow"], "_")
            coeff = join([p, "units_on_coefficient", a, b], "_")
            relationships = [
                [classes_by_prefix[a], ["unit_ab", "node_a"]],
                [classes_by_prefix[b], ["unit_ab", "node_b"]],
                [class, relationship],
            ]
            relationship_parameter_values =
                [[class, relationship, ratio, flow_ratio], [class, relationship, coeff, units_on_coeff]]
            sense = senses_by_prefix[p]
            SpineInterface.import_data(
                url_in;
                relationships=relationships,
                relationship_parameter_values=relationship_parameter_values,
            )

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
            var_units_on = m.ext[:spineopt].variables[:units_on]
            constraint = m.ext[:spineopt].constraints[Symbol(ratio)]
            @test length(constraint) == 1
            path = [stochastic_scenario(:parent), stochastic_scenario(:child)]
            t_long = first(time_slice(m; temporal_block=temporal_block(:two_hourly)))
            t_short1, t_short2 = time_slice(m; temporal_block=temporal_block(:hourly))
            directions_by_prefix = Dict("in" => direction(:from_node), "out" => direction(:to_node))
            d_a = directions_by_prefix[a]
            d_b = directions_by_prefix[b]
            var_u_flow_b_key = (unit(:unit_ab), node(:node_b), d_b, stochastic_scenario(:parent), t_long)
            var_u_flow_a1_key = (unit(:unit_ab), node(:node_a), d_a, stochastic_scenario(:parent), t_short1)
            var_u_flow_a2_key = (unit(:unit_ab), node(:node_a), d_a, stochastic_scenario(:child), t_short2)
            var_u_on_a1_key = (unit(:unit_ab), stochastic_scenario(:parent), t_short1)
            var_u_on_a2_key = (unit(:unit_ab), stochastic_scenario(:child), t_short2)
            var_u_flow_b = var_unit_flow[var_u_flow_b_key...]
            var_u_flow_a1 = var_unit_flow[var_u_flow_a1_key...]
            var_u_flow_a2 = var_unit_flow[var_u_flow_a2_key...]
            var_u_on_a1 = var_units_on[var_u_on_a1_key...]
            var_u_on_a2 = var_units_on[var_u_on_a2_key...]
            con_key = (unit(:unit_ab), node(:node_a), node(:node_b), path, t_long)
            expected_con_ref = SpineOpt.sense_constraint(
                m,
                var_u_flow_a1 + var_u_flow_a2,
                sense,
                2 * flow_ratio * var_u_flow_b + units_on_coeff * (var_u_on_a1 + var_u_on_a2),
            )
            expected_con = constraint_object(expected_con_ref)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end

    @testset "constraint_total_cumulated_unit_flow" begin
        total_cumulated_flow_bound = 100
        # class = "unit_$(direction)_node"
        # relationship = ["unit_ab", "node_a", "node_b"]
        senses_by_prefix = Dict("min" => >=, "max" => <=)
        classes_by_prefix = Dict("from_node" => "unit__from_node", "to_node" => "unit__to_node")
        @testset for (p, a) in (
            ("min", "from_node"),
            ("min", "to_node"),
            ("max", "from_node"),
            ("max", "to_node"),
        )
            _load_test_data(url_in, test_data)
            cumulated = join([p,"total" , "cumulated", "unit_flow",a], "_")
            relationships = [
                [classes_by_prefix[a], ["unit_ab", "node_a"]],
            ]
            relationship_parameter_values =
                [[classes_by_prefix[a], ["unit_ab", "node_a"], cumulated, total_cumulated_flow_bound]]
            sense = senses_by_prefix[p]
            SpineInterface.import_data(
                url_in;
                relationships=relationships,
                relationship_parameter_values=relationship_parameter_values,
            )
            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
            constraint = m.ext[:spineopt].constraints[Symbol(cumulated)]
            @test length(constraint) == 1
            path = [stochastic_scenario(:parent), stochastic_scenario(:child)]
            t_long = first(time_slice(m; temporal_block=temporal_block(:two_hourly)))
            t_short1, t_short2 = time_slice(m; temporal_block=temporal_block(:hourly))
            directions_by_prefix = Dict("from_node" => direction(:from_node), "to_node" => direction(:to_node))
            d_a = directions_by_prefix[a]
            var_u_flow_a1_key = (unit(:unit_ab), node(:node_a), d_a, stochastic_scenario(:parent), t_short1)
            var_u_flow_a2_key = (unit(:unit_ab), node(:node_a), d_a, stochastic_scenario(:child), t_short2)
            var_u_flow_a1 = var_unit_flow[var_u_flow_a1_key...]
            var_u_flow_a2 = var_unit_flow[var_u_flow_a2_key...]
            con_key = (unit(:unit_ab), node(:node_a), path)
            expected_con_ref = SpineOpt.sense_constraint(
                m,
                var_u_flow_a1 + var_u_flow_a2,
                sense,
                total_cumulated_flow_bound ,
            )
            expected_con = constraint_object(expected_con_ref)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end



    @testset "constraint_min_up_time" begin
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for min_up_minutes in (60, 120, 210)
            _load_test_data(url_in, test_data)
            min_up_time = Dict("type" => "duration", "data" => string(min_up_minutes, "m"))
            object_parameter_values =
                [["unit", "unit_ab", "min_up_time", min_up_time], ["model", "instance", "model_end", model_end]]
            SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values)

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_units_on = m.ext[:spineopt].variables[:units_on]
            var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
            constraint = m.ext[:spineopt].constraints[:min_up_time]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                -(length(time_slice(m; temporal_block=temporal_block(:hourly))), round(parent_end, Hour(1)).value)
            tail_hours = round(Minute(min_up_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                var_u_on_key = (unit(:unit_ab), s, t)
                var_u_on = var_units_on[var_u_on_key...]
                vars_u_su = [var_units_started_up[unit(:unit_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_u_on >= sum(vars_u_su))
                con_key = (unit(:unit_ab), path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_min_up_time_with_non_spinning_reserves" begin
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for min_up_minutes in (60, 120, 210)
            _load_test_data(url_in, test_data)
            min_up_time = Dict("type" => "duration", "data" => string(min_up_minutes, "m"))
            object_parameter_values = [
                ["unit", "unit_ab", "min_up_time", min_up_time],
                ["model", "instance", "model_end", model_end],
                ["node", "node_a", "is_reserve_node", true],
            ]
            relationship_parameter_values = [
                ["unit__from_node", ["unit_ab", "node_a"], "max_res_shutdown_ramp", 1],
                ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", 0],
            ]
            SpineInterface.import_data(
                url_in;
                object_parameter_values=object_parameter_values,
                relationship_parameter_values=relationship_parameter_values,
            )

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_units_on = m.ext[:spineopt].variables[:units_on]
            var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
            var_nonspin_units_shut_down = m.ext[:spineopt].variables[:nonspin_units_shut_down]
            constraint = m.ext[:spineopt].constraints[:min_up_time]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                -(length(time_slice(m; temporal_block=temporal_block(:hourly))), round(parent_end, Hour(1)).value)
            tail_hours = round(Minute(min_up_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                var_u_on_key = (unit(:unit_ab), s, t)
                var_u_on = var_units_on[var_u_on_key...]
                vars_u_su = [var_units_started_up[unit(:unit_ab), s, t] for (s, t) in zip(s_set, t_set)]
                var_ns_sd_key = (unit(:unit_ab), node(:node_a), s, t)
                var_ns_sd = var_nonspin_units_shut_down[var_ns_sd_key...]
                expected_con = @build_constraint(var_u_on - var_ns_sd >= sum(vars_u_su))
                con_key = (unit(:unit_ab), path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_min_down_time" begin
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for min_down_minutes in (45, 150, 300)
            _load_test_data(url_in, test_data)
            number_of_units = 4
            candidate_units = 3
            min_down_time = Dict("type" => "duration", "data" => string(min_down_minutes, "m"))
            object_parameter_values = [
                ["unit", "unit_ab", "candidate_units", candidate_units],
                ["unit", "unit_ab", "number_of_units", number_of_units],
                ["unit", "unit_ab", "min_down_time", min_down_time],
                ["model", "instance", "model_end", model_end]
            ]
            relationships = [
                ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
                ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
            ]
            SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_units_on = m.ext[:spineopt].variables[:units_on]
            var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
            var_units_shut_down = m.ext[:spineopt].variables[:units_shut_down]
            constraint = m.ext[:spineopt].constraints[:min_down_time]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                length(time_slice(m; temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
            tail_hours = round(Minute(min_down_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                var_u_inv_av_on_key = (unit(:unit_ab), s, t)
                var_u_inv_av = var_units_invested_available[var_u_inv_av_on_key...]
                var_u_on = var_units_on[var_u_inv_av_on_key...]
                vars_u_sd = [var_units_shut_down[unit(:unit_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(number_of_units + var_u_inv_av - var_u_on >= sum(vars_u_sd))
                con_key = (unit(:unit_ab), path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_min_down_time_with_non_spinning_reserves" begin
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for min_down_minutes in (90, 150, 300)  # TODO: make it work for 45, 75
            _load_test_data(url_in, test_data)
            number_of_units = 4
            candidate_units = 3
            min_down_time = Dict("type" => "duration", "data" => string(min_down_minutes, "m"))
            is_reserve_node=true
            object_parameter_values = [
                ["unit", "unit_ab", "candidate_units", candidate_units],
                ["unit", "unit_ab", "number_of_units", number_of_units],
                ["unit", "unit_ab", "min_down_time", min_down_time],
                ["model", "instance", "model_end", model_end],
                ["node", "node_a", "is_reserve_node", is_reserve_node],
            ]
            relationships = [
                ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
                ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
            ]
            relationship_parameter_values = [
                ["unit__from_node", ["unit_ab", "node_a"], "max_res_startup_ramp", 1],
                ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", 0],
            ]
            SpineInterface.import_data(
                url_in;
                relationships=relationships,
                object_parameter_values=object_parameter_values,
                relationship_parameter_values=relationship_parameter_values,
            )

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_units_on = m.ext[:spineopt].variables[:units_on]
            var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
            var_units_shut_down = m.ext[:spineopt].variables[:units_shut_down]
            var_nonspin_units_started_up = m.ext[:spineopt].variables[:nonspin_units_started_up]
            constraint = m.ext[:spineopt].constraints[:min_down_time]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                length(time_slice(m; temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
            tail_hours = round(Minute(min_down_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                var_u_inv_av_on_key = (unit(:unit_ab), s, t)
                var_u_inv_av = var_units_invested_available[var_u_inv_av_on_key...]
                var_u_on = var_units_on[var_u_inv_av_on_key...]
                vars_u_sd = [var_units_shut_down[unit(:unit_ab), s, t] for (s, t) in zip(s_set, t_set)]
                var_ns_su_key = (unit(:unit_ab), node(:node_a), s, t)
                var_ns_su = var_nonspin_units_started_up[var_ns_su_key...]
                expected_con = @build_constraint(number_of_units + var_u_inv_av - var_u_on >= sum(vars_u_sd) + var_ns_su)
                con_key = (unit(:unit_ab), path, t)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_units_invested_available" begin
        _load_test_data(url_in, test_data)
        candidate_units = 7
        object_parameter_values = [["unit", "unit_ab", "candidate_units", candidate_units]]
        relationships = [
            ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
            ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
        constraint = m.ext[:spineopt].constraints[:units_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (unit(:unit_ab), s, t)
            var = var_units_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_units)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_units_invested_available_mp" begin
        _load_test_data(url_in, test_data)
        candidate_units = 7
        object_parameter_values = [
            ["unit", "unit_ab", "candidate_units", candidate_units],
            ["model", "master", "model_type", "spineopt_benders_master"],
            ["model", "instance", "model_type", "spineopt_standard"],
        ]
        relationships = [
            ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
            ["unit__investment_temporal_block", ["unit_ab", "investments_hourly"]],
            ["unit__investment_stochastic_structure", ["unit_ab", "investments_deterministic"]],
            ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m, mp = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
        constraint = m.ext[:spineopt].constraints[:units_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (unit(:unit_ab), s, t)
            var = var_units_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_units)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
        var_units_invested_available = mp.ext[:spineopt].variables[:units_invested_available]
        constraint = mp.ext[:spineopt].constraints[:units_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        time_slices = time_slice(mp; temporal_block=temporal_block(:investments_hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (unit(:unit_ab), s, t)
            var = var_units_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_units)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_units_invested_transition" begin
        _load_test_data(url_in, test_data)
        candidate_units = 4
        object_parameter_values = [["unit", "unit_ab", "candidate_units", candidate_units]]
        relationships = [
            ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
            ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
        var_units_invested = m.ext[:spineopt].variables[:units_invested]
        var_units_mothballed = m.ext[:spineopt].variables[:units_mothballed]
        constraint = m.ext[:spineopt].constraints[:units_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (unit(:unit_ab), s1, t1)
            var_u_inv_av1 = var_units_invested_available[var_key1...]
            var_u_inv_1 = var_units_invested[var_key1...]
            var_u_moth_1 = var_units_mothballed[var_key1...]
            @testset for (u, t0, t1) in unit_investment_dynamic_time_indices(m; unit=unit(:unit_ab), t_after=t1)
                var_key0 = (u, s0, t0)
                var_u_inv_av0 = get(var_units_invested_available, var_key0, 0)
                con_key = (u, path, t0, t1)
                expected_con = @build_constraint(var_u_inv_av1 - var_u_inv_1 + var_u_moth_1 == var_u_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_units_invested_transition_mp" begin
        _load_test_data(url_in, test_data)
        candidate_units = 4
        object_parameter_values = [
            ["unit", "unit_ab", "candidate_units", candidate_units],
            ["model", "master", "model_type", "spineopt_benders_master"],
            ["model", "instance", "model_type", "spineopt_standard"],
        ]
        relationships = [
            ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
            ["unit__investment_temporal_block", ["unit_ab", "investments_hourly"]],
            ["unit__investment_stochastic_structure", ["unit_ab", "investments_deterministic"]],
            ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

        m, mp = run_spineopt(url_in; log_level=0, optimize=false)
        var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
        var_units_invested = m.ext[:spineopt].variables[:units_invested]
        var_units_mothballed = m.ext[:spineopt].variables[:units_mothballed]
        constraint = m.ext[:spineopt].constraints[:units_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (unit(:unit_ab), s1, t1)
            var_u_inv_av1 = var_units_invested_available[var_key1...]
            var_u_inv_1 = var_units_invested[var_key1...]
            var_u_moth_1 = var_units_mothballed[var_key1...]
            @testset for (u, t0, t1) in unit_investment_dynamic_time_indices(m; unit=unit(:unit_ab), t_after=t1)
                var_key0 = (u, s0, t0)
                var_u_inv_av0 = get(var_units_invested_available, var_key0, 0)
                con_key = (u, path, t0, t1)
                expected_con = @build_constraint(var_u_inv_av1 - var_u_inv_1 + var_u_moth_1 == var_u_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end

        var_units_invested_available = mp.ext[:spineopt].variables[:units_invested_available]
        var_units_invested = mp.ext[:spineopt].variables[:units_invested]
        var_units_mothballed = mp.ext[:spineopt].variables[:units_mothballed]
        constraint = mp.ext[:spineopt].constraints[:units_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(mp; temporal_block=temporal_block(:investments_hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (unit(:unit_ab), s1, t1)
            var_u_inv_av1 = var_units_invested_available[var_key1...]
            var_u_inv_1 = var_units_invested[var_key1...]
            var_u_moth_1 = var_units_mothballed[var_key1...]
            @testset for (u, t0, t1) in unit_investment_dynamic_time_indices(mp; unit=unit(:unit_ab), t_after=t1)
                var_key0 = (u, s0, t0)
                var_u_inv_av0 = get(var_units_invested_available, var_key0, 0)
                con_key = (u, path, t0, t1)
                expected_con = @build_constraint(var_u_inv_av1 - var_u_inv_1 + var_u_moth_1 == var_u_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_unit_lifetime" begin
        candidate_units = 3
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for lifetime_minutes in (30, 180, 240)
            _load_test_data(url_in, test_data)
            unit_investment_lifetime = Dict("type" => "duration", "data" => string(lifetime_minutes, "m"))
            object_parameter_values = [
                ["unit", "unit_ab", "candidate_units", candidate_units],
                ["unit", "unit_ab", "unit_investment_lifetime", unit_investment_lifetime],
                ["model", "instance", "model_end", model_end],
            ]
            relationships = [
                ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
                ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
            ]
            SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
            var_units_invested = m.ext[:spineopt].variables[:units_invested]
            constraint = m.ext[:spineopt].constraints[:unit_lifetime]

            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                length(time_slice(m; temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
            tail_hours = round(Minute(lifetime_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                key = (unit(:unit_ab), path, t)
                var_u_inv_av_key = (unit(:unit_ab), s, t)
                var_u_inv_av = var_units_invested_available[var_u_inv_av_key...]
                vars_u_inv = [var_units_invested[unit(:unit_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_u_inv_av >= sum(vars_u_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_unit_lifetime_mp" begin
        candidate_units = 3
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for lifetime_minutes in (30, 180, 240)
            _load_test_data(url_in, test_data)
            unit_investment_lifetime = Dict("type" => "duration", "data" => string(lifetime_minutes, "m"))
            object_parameter_values = [
                ["unit", "unit_ab", "candidate_units", candidate_units],
                ["unit", "unit_ab", "unit_investment_lifetime", unit_investment_lifetime],
                ["model", "instance", "model_end", model_end],
                ["model", "master", "model_end", model_end],
                ["model", "master", "model_type", "spineopt_benders_master"],
                ["model", "instance", "model_type", "spineopt_standard"],
            ]
            relationships = [
                ["unit__investment_temporal_block", ["unit_ab", "hourly"]],
                ["unit__investment_temporal_block", ["unit_ab", "investments_hourly"]],
                ["unit__investment_stochastic_structure", ["unit_ab", "stochastic"]],
                ["unit__investment_stochastic_structure", ["unit_ab", "investments_deterministic"]],
            ]
            SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)

            m, mp = run_spineopt(url_in; log_level=0, optimize=false)
            var_units_invested_available = m.ext[:spineopt].variables[:units_invested_available]
            var_units_invested = m.ext[:spineopt].variables[:units_invested]
            constraint = m.ext[:spineopt].constraints[:unit_lifetime]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours =
                length(time_slice(m; temporal_block=temporal_block(:hourly))) - round(parent_end, Hour(1)).value
            tail_hours = round(Minute(lifetime_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:child)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(m; temporal_block=temporal_block(:hourly)))
                reverse(history_time_slice(m; temporal_block=temporal_block(:hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                key = (unit(:unit_ab), path, t)
                var_u_inv_av_key = (unit(:unit_ab), s, t)
                var_u_inv_av = var_units_invested_available[var_u_inv_av_key...]
                vars_u_inv = [var_units_invested[unit(:unit_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_u_inv_av >= sum(vars_u_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end

            var_units_invested_available = mp.ext[:spineopt].variables[:units_invested_available]
            var_units_invested = mp.ext[:spineopt].variables[:units_invested]
            constraint = mp.ext[:spineopt].constraints[:unit_lifetime]
            @test length(constraint) == 5
            parent_end = stochastic_scenario_end(
                stochastic_structure=stochastic_structure(:stochastic),
                stochastic_scenario=stochastic_scenario(:parent),
            )
            head_hours = length(time_slice(mp; temporal_block=temporal_block(:investments_hourly))) - Hour(1).value
            tail_hours = round(Minute(lifetime_minutes), Hour(1)).value
            scenarios = [
                repeat([stochastic_scenario(:parent)], head_hours)
                repeat([stochastic_scenario(:parent)], tail_hours)
            ]
            time_slices = [
                reverse(time_slice(mp; temporal_block=temporal_block(:investments_hourly)))
                reverse(history_time_slice(mp; temporal_block=temporal_block(:investments_hourly)))
            ][1:(head_hours + tail_hours)]
            @testset for h in 1:length(constraint)
                s_set, t_set = scenarios[h:(h + tail_hours - 1)], time_slices[h:(h + tail_hours - 1)]
                s, t = s_set[1], t_set[1]
                path = reverse(unique(s_set))
                key = (unit(:unit_ab), path, t)
                var_u_inv_av_key = (unit(:unit_ab), s, t)
                var_u_inv_av = var_units_invested_available[var_u_inv_av_key...]
                vars_u_inv = [var_units_invested[unit(:unit_ab), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_u_inv_av >= sum(vars_u_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_max_nonspin_start_up_ramp" begin
        _load_test_data(url_in, test_data)
        max_res_startup_ramp = 0.5
        unit_capacity = 200
        is_reserve_node = true
        object_parameter_values = [
            ["node","node_a","is_reserve_node", is_reserve_node],
        ]
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_res_startup_ramp", max_res_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_nonspin_ramp_up_unit_flow = m.ext[:spineopt].variables[:nonspin_ramp_up_unit_flow]
        var_nonspin_units_started_up = m.ext[:spineopt].variables[:nonspin_units_started_up]
        constraint = m.ext[:spineopt].constraints[:max_nonspin_start_up_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_ns_ru_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_ns_su_key = (unit(:unit_ab), node(:node_a), s, t)
            var_ns_ru_u_flow = var_nonspin_ramp_up_unit_flow[var_ns_ru_u_flow_key...]
            var_ns_su = var_nonspin_units_started_up[var_ns_su_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_ns_ru_u_flow <= unit_capacity * max_res_startup_ramp * var_ns_su)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_min_nonspin_start_up_ramp" begin
        _load_test_data(url_in, test_data)
        max_res_startup_ramp = 0.5
        min_res_startup_ramp = 0.25
        unit_capacity = 200
        object_parameter_values = [
            ["node", "node_a", "is_reserve_node", true],
        ]
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_res_startup_ramp", max_res_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "min_res_startup_ramp", min_res_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_nonspin_ramp_up_unit_flow = m.ext[:spineopt].variables[:nonspin_ramp_up_unit_flow]
        var_nonspin_units_started_up = m.ext[:spineopt].variables[:nonspin_units_started_up]
        constraint = m.ext[:spineopt].constraints[:min_nonspin_start_up_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_ns_ru_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_ns_su_key = (unit(:unit_ab), node(:node_a), s, t)
            var_ns_ru_u_flow = var_nonspin_ramp_up_unit_flow[var_ns_ru_u_flow_key...]
            var_ns_su = var_nonspin_units_started_up[var_ns_su_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_ns_ru_u_flow >= unit_capacity * min_res_startup_ramp * var_ns_su)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_max_start_up_ramp" begin
        _load_test_data(url_in, test_data)
        max_startup_ramp = 0.4
        unit_capacity = 200
        ramp_up_limit = 1
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_startup_ramp", max_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_up_limit", ramp_up_limit],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_start_up_unit_flow = m.ext[:spineopt].variables[:start_up_unit_flow]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        constraint = m.ext[:spineopt].constraints[:max_start_up_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_su_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_u_su_key = (unit(:unit_ab), s, t)
            var_su_u_flow = var_start_up_unit_flow[var_su_u_flow_key...]
            var_u_su = var_units_started_up[var_u_su_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_su_u_flow <= unit_capacity * max_startup_ramp * var_u_su)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_min_start_up_ramp" begin
        _load_test_data(url_in, test_data)
        max_startup_ramp = 0.4
        min_startup_ramp = 0.2
        unit_capacity = 200
        ramp_up_limit = 1
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_startup_ramp", max_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "min_startup_ramp", min_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_up_limit",ramp_up_limit],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_start_up_unit_flow = m.ext[:spineopt].variables[:start_up_unit_flow]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        constraint = m.ext[:spineopt].constraints[:min_start_up_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_su_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_u_su_key = (unit(:unit_ab), s, t)
            var_su_u_flow = var_start_up_unit_flow[var_su_u_flow_key...]
            var_u_su = var_units_started_up[var_u_su_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_su_u_flow >= unit_capacity * min_startup_ramp * var_u_su)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_ramp_up" begin
        _load_test_data(url_in, test_data)
        ramp_up_limit = 0.8
        unit_capacity = 200
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_up_limit", ramp_up_limit],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_ramp_up_unit_flow = m.ext[:spineopt].variables[:ramp_up_unit_flow]
        var_units_on = m.ext[:spineopt].variables[:units_on]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        constraint = m.ext[:spineopt].constraints[:ramp_up]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_ru_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_u_on_key = (unit(:unit_ab), s, t)
            var_ru_u_flow = var_ramp_up_unit_flow[var_ru_u_flow_key...]
            var_u_on = var_units_on[var_u_on_key...]
            var_u_su = var_units_started_up[var_u_on_key...]
            expected_con = @build_constraint(var_ru_u_flow <= unit_capacity * ramp_up_limit * (var_u_on - var_u_su))
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_split_ramp_up" begin
        _load_test_data(url_in, test_data)
        ramp_up_limit = 0.8
        max_startup_ramp = 0.4
        unit_capacity = 200
        ramp_down_limit = 0.8
        max_shutdown_ramp = 0.4
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_up_limit", ramp_up_limit],
            ["unit__from_node", ["unit_ab", "node_a"], "max_startup_ramp", max_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_down_limit", ramp_down_limit],
            ["unit__from_node", ["unit_ab", "node_a"], "max_shutdown_ramp", max_shutdown_ramp],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_start_up_unit_flow = m.ext[:spineopt].variables[:start_up_unit_flow]
        var_ramp_up_unit_flow = m.ext[:spineopt].variables[:ramp_up_unit_flow]
        var_shut_down_unit_flow = m.ext[:spineopt].variables[:shut_down_unit_flow]
        var_ramp_down_unit_flow = m.ext[:spineopt].variables[:ramp_down_unit_flow]
        constraint = m.ext[:spineopt].constraints[:split_ramps]
        @test length(constraint) == 2
        key_head = (unit(:unit_ab), node(:node_a), direction(:from_node))
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (key_head..., s1, t1)
            var_u_flow1 = var_unit_flow[var_key1...]
            var_su_u_flow1 = var_start_up_unit_flow[var_key1...]
            var_ru_u_flow1 = var_ramp_up_unit_flow[var_key1...]
            var_sd_u_flow1 = var_shut_down_unit_flow[var_key1...]
            var_rd_u_flow1 = var_ramp_down_unit_flow[var_key1...]
            @testset for (n, t0, t1) in node_dynamic_time_indices(m; node=node(:node_a), t_after=t1)
                var_key0 = (key_head..., s0, t0)
                var_u_flow0 = get(var_unit_flow, var_key0, 0)
                con_key = (key_head..., path, t0, t1)
                expected_con = @build_constraint(
                    var_u_flow1 - var_u_flow0 == var_su_u_flow1 + var_ru_u_flow1 - var_sd_u_flow1 - var_rd_u_flow1
                )
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_split_ramps_with_nonspin_units" begin
        _load_test_data(url_in, test_data)
        max_res_startup_ramp = 0.5
        unit_capacity = 200
        ramp_up_limit = 1
        is_reserve_node = true
        is_non_spinning = true
        upward_reserve = true
        object_parameter_values = [
            ["node", "node_a", "is_reserve_node", is_reserve_node],
            ["node", "node_a", "is_non_spinning", is_non_spinning],
            ["node", "node_a", "upward_reserve", upward_reserve],
        ]
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_res_startup_ramp", max_res_startup_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values, object_parameter_values =object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_start_up_unit_flow = m.ext[:spineopt].variables[:start_up_unit_flow]
        var_nonspin_ramp_up_unit_flow = m.ext[:spineopt].variables[:nonspin_ramp_up_unit_flow]
        var_shut_down_unit_flow = m.ext[:spineopt].variables[:shut_down_unit_flow]
        var_nonspin_ramp_down_unit_flow = m.ext[:spineopt].variables[:nonspin_ramp_down_unit_flow]
        constraint = m.ext[:spineopt].constraints[:split_ramps]
        @test length(constraint) == 2
        key_head = (unit(:unit_ab), node(:node_a), direction(:from_node))
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (key_head..., s1, t1)
            var_u_flow1 = var_unit_flow[var_key1...]
            var_ns_ru_u_flow1 = var_nonspin_ramp_up_unit_flow[var_key1...]
            @testset for (n, t0, t1) in node_dynamic_time_indices(m; node=node(:node_a), t_after=t1)
                var_key0 = (key_head..., s0, t0)
                var_u_flow0 = get(var_unit_flow, var_key0, 0)
                con_key = (key_head..., path, t0, t1)
                expected_con = @build_constraint(
                    var_u_flow1 ==
                    var_ns_ru_u_flow1
                )
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_max_nonspin_ramp_down_unit_flow" begin
        _load_test_data(url_in, test_data)
        max_res_shutdown_ramp = 0.5
        unit_capacity = 200
        is_reserve_node = true
        object_parameter_values = [
            ["node", "node_a", "is_reserve_node", is_reserve_node],
        ]
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_res_shutdown_ramp", max_res_shutdown_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_nonspin_ramp_down_unit_flow = m.ext[:spineopt].variables[:nonspin_ramp_down_unit_flow]
        var_nonspin_units_shut_down = m.ext[:spineopt].variables[:nonspin_units_shut_down]
        constraint = m.ext[:spineopt].constraints[:max_nonspin_shut_down_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_ns_rd_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_ns_sd_key = (unit(:unit_ab), node(:node_a), s, t)
            var_ns_rd_u_flow = var_nonspin_ramp_down_unit_flow[var_ns_rd_u_flow_key...]
            var_ns_sd = var_nonspin_units_shut_down[var_ns_sd_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_ns_rd_u_flow <= unit_capacity * max_res_shutdown_ramp * var_ns_sd)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_min_nonspin_shut_down_ramp" begin
        _load_test_data(url_in, test_data)
        max_res_shutdown_ramp = 0.5
        min_res_shutdown_ramp = 0.25
        unit_capacity = 200
        is_reserve_node = true
        object_parameter_values = [
            ["node", "node_a", "is_reserve_node", is_reserve_node],
        ]
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_res_shutdown_ramp", max_res_shutdown_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "min_res_shutdown_ramp", min_res_shutdown_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values, object_parameter_values=object_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_nonspin_ramp_down_unit_flow = m.ext[:spineopt].variables[:nonspin_ramp_down_unit_flow]
        var_nonspin_units_shut_down = m.ext[:spineopt].variables[:nonspin_units_shut_down]
        constraint = m.ext[:spineopt].constraints[:min_nonspin_shut_down_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_ns_rd_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_ns_sd_key = (unit(:unit_ab), node(:node_a), s, t)
            var_ns_rd_u_flow = var_nonspin_ramp_down_unit_flow[var_ns_rd_u_flow_key...]
            var_ns_sd = var_nonspin_units_shut_down[var_ns_sd_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_ns_rd_u_flow >= unit_capacity * min_res_shutdown_ramp * var_ns_sd)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_max_shut_down_ramp" begin
        _load_test_data(url_in, test_data)
        max_shutdown_ramp = 0.4
        unit_capacity = 200
        ramp_down_limit = 1
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_shutdown_ramp", max_shutdown_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_down_limit", ramp_down_limit],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_shut_down_unit_flow = m.ext[:spineopt].variables[:shut_down_unit_flow]
        var_units_shut_down = m.ext[:spineopt].variables[:units_shut_down]
        constraint = m.ext[:spineopt].constraints[:max_shut_down_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_sd_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_u_sd_key = (unit(:unit_ab), s, t)
            var_sd_u_flow = var_shut_down_unit_flow[var_sd_u_flow_key...]
            var_u_sd = var_units_shut_down[var_u_sd_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_sd_u_flow <= unit_capacity * max_shutdown_ramp * var_u_sd)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_min_shut_down_ramp" begin
        _load_test_data(url_in, test_data)
        max_shutdown_ramp = 0.4
        min_shutdown_ramp = 0.2
        unit_capacity = 200
        ramp_down_limit = 1
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "max_shutdown_ramp", max_shutdown_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "min_shutdown_ramp", min_shutdown_ramp],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_down_limit", ramp_down_limit],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_shut_down_unit_flow = m.ext[:spineopt].variables[:shut_down_unit_flow]
        var_units_shut_down = m.ext[:spineopt].variables[:units_shut_down]
        constraint = m.ext[:spineopt].constraints[:min_shut_down_ramp]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_sd_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_u_sd_key = (unit(:unit_ab), s, t)
            var_sd_u_flow = var_shut_down_unit_flow[var_sd_u_flow_key...]
            var_u_sd = var_units_shut_down[var_u_sd_key...]
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            expected_con = @build_constraint(var_sd_u_flow >= unit_capacity * min_shutdown_ramp * var_u_sd)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_ramp_down" begin
        _load_test_data(url_in, test_data)
        ramp_down_limit = 0.8
        unit_capacity = 200
        relationship_parameter_values = [
            ["unit__from_node", ["unit_ab", "node_a"], "ramp_down_limit", ramp_down_limit],
            ["unit__from_node", ["unit_ab", "node_a"], "unit_capacity", unit_capacity],
        ]
        SpineInterface.import_data(url_in; relationship_parameter_values=relationship_parameter_values)

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_ramp_down_unit_flow = m.ext[:spineopt].variables[:ramp_down_unit_flow]
        var_units_on = m.ext[:spineopt].variables[:units_on]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        constraint = m.ext[:spineopt].constraints[:ramp_down]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_ru_u_flow_key = (unit(:unit_ab), node(:node_a), direction(:from_node), s, t)
            var_u_on_key = (unit(:unit_ab), s, t)
            var_rd_u_flow = var_ramp_down_unit_flow[var_ru_u_flow_key...]
            var_u_on = var_units_on[var_u_on_key...]
            var_u_su = var_units_started_up[var_u_on_key...]
            expected_con = @build_constraint(var_rd_u_flow <= unit_capacity * ramp_down_limit * (var_u_on - var_u_su))
            con_key = (unit(:unit_ab), node(:node_a), direction(:from_node), [s], t)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_user_constraint(single unit)" begin
        @testset for sense in ("==", ">=", "<=")
            _load_test_data(url_in, test_data)
            rhs = 40
            unit_flow_coefficient_a = 25
            unit_flow_coefficient_b = 30
            units_on_coefficient = 20
            units_started_up_coefficient = 35
            objects = [["user_constraint", "constraint_x"]]
            relationships = [
                ["unit__from_node__user_constraint", ["unit_ab", "node_a", "constraint_x"]],
                ["unit__to_node__user_constraint", ["unit_ab", "node_b", "constraint_x"]],
                ["unit__user_constraint", ["unit_ab", "constraint_x"]],
            ]
            object_parameter_values = [
                ["user_constraint", "constraint_x", "constraint_sense", Symbol(sense)],
                ["user_constraint", "constraint_x", "right_hand_side", rhs],
            ]
            relationship_parameter_values = [
                [relationships[1]..., "unit_flow_coefficient", unit_flow_coefficient_a],
                [relationships[2]..., "unit_flow_coefficient", unit_flow_coefficient_b],
                [relationships[3]..., "units_on_coefficient", units_on_coefficient],
                [relationships[3]..., "units_started_up_coefficient", units_started_up_coefficient],
            ]
            SpineInterface.import_data(
                url_in;
                objects=objects,
                relationships=relationships,
                object_parameter_values=object_parameter_values,
                relationship_parameter_values=relationship_parameter_values,
            )

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
            var_units_on = m.ext[:spineopt].variables[:units_on]
            var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
            constraint = m.ext[:spineopt].constraints[:user_constraint]
            @test length(constraint) == 2
            key_a = (unit(:unit_ab), node(:node_a), direction(:from_node))
            key_b = (unit(:unit_ab), node(:node_b), direction(:to_node))
            s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
            t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
            t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
            expected_con_ref = SpineOpt.sense_constraint(
                m,
                + unit_flow_coefficient_a
                * (var_unit_flow[key_a..., s_parent, t1h1] + var_unit_flow[key_a..., s_child, t1h2]) +
                2 * unit_flow_coefficient_b * var_unit_flow[key_b..., s_parent, t2h] +
                units_on_coefficient
                * (var_units_on[unit(:unit_ab), s_parent, t1h1] + var_units_on[unit(:unit_ab), s_child, t1h2]) +
                units_started_up_coefficient * (
                    var_units_started_up[unit(:unit_ab), s_parent, t1h1]
                    + var_units_started_up[unit(:unit_ab), s_child, t1h2]
                ),
                Symbol(sense),
                2 * rhs,
            )
            expected_con = constraint_object(expected_con_ref)
            con_key = (user_constraint(:constraint_x), [s_parent, s_child], t2h)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_user_constraint_with_unit_operating_segments" begin
        @testset for sense in ("==", ">=", "<=")
            _load_test_data(url_in, test_data)
            rhs = 40
            unit_flow_coefficient_a = 25
            unit_flow_coefficient_b = 30
            units_on_coefficient = 20
            units_started_up_coefficient = 35
            points = [0.1, 0.5, 1.0]
            operating_points = Dict("type" => "array", "value_type" => "float", "data" => PyVector(points))
            objects = [["user_constraint", "constraint_x"]]
            relationships = [
                ["unit__from_node__user_constraint", ["unit_ab", "node_a", "constraint_x"]],
                ["unit__to_node__user_constraint", ["unit_ab", "node_b", "constraint_x"]],
                ["unit__user_constraint", ["unit_ab", "constraint_x"]],
            ]
            object_parameter_values = [
                ["user_constraint", "constraint_x", "constraint_sense", Symbol(sense)],
                ["user_constraint", "constraint_x", "right_hand_side", rhs],
            ]
            relationship_parameter_values = [
                ["unit__from_node", ["unit_ab", "node_a"], "operating_points", operating_points],
                ["unit__to_node", ["unit_ab", "node_b"], "operating_points", operating_points],
                [relationships[1]..., "unit_flow_coefficient", unit_flow_coefficient_a],
                [relationships[2]..., "unit_flow_coefficient", unit_flow_coefficient_b],
                [relationships[3]..., "units_on_coefficient", units_on_coefficient],
                [relationships[3]..., "units_started_up_coefficient", units_started_up_coefficient],
            ]
            SpineInterface.import_data(
                url_in;
                objects=objects,
                relationships=relationships,
                object_parameter_values=object_parameter_values,
                relationship_parameter_values=relationship_parameter_values,
            )

            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_unit_flow_op = m.ext[:spineopt].variables[:unit_flow_op]
            var_units_on = m.ext[:spineopt].variables[:units_on]
            var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
            constraint = m.ext[:spineopt].constraints[:user_constraint]
            @test length(constraint) == 2
            key_a = (unit(:unit_ab), node(:node_a), direction(:from_node))
            key_b = (unit(:unit_ab), node(:node_b), direction(:to_node))
            s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
            t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
            t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
            expected_con_ref = SpineOpt.sense_constraint(
                m,
                + unit_flow_coefficient_a * sum(
                    var_unit_flow_op[key_a..., i, s_parent, t1h1] + var_unit_flow_op[key_a..., i, s_child, t1h2]
                    for i in 1:3
                ) +
                2 * sum(unit_flow_coefficient_b * var_unit_flow_op[key_b..., i, s_parent, t2h] for i in 1:3) +
                units_on_coefficient
                * (var_units_on[unit(:unit_ab), s_parent, t1h1] + var_units_on[unit(:unit_ab), s_child, t1h2]) +
                units_started_up_coefficient * (
                    var_units_started_up[unit(:unit_ab), s_parent, t1h1]
                    + var_units_started_up[unit(:unit_ab), s_child, t1h2]
                ),
                Symbol(sense),
                2 * rhs,
            )
            expected_con = constraint_object(expected_con_ref)
            con_key = (user_constraint(:constraint_x), [s_parent, s_child], t2h)
            observed_con = constraint_object(constraint[con_key...])
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_pw_unit_heat_rate" begin
        _load_test_data(url_in, test_data)
        unit_idle_heat_rate = 200
        unit_start_flow = 100
        points = [0.1, 0.5, 1.0]
        inc_hrs = [10, 20, 30]
        operating_points = Dict("type" => "array", "value_type" => "float", "data" => PyVector(points))
        unit_incremental_heat_rate = Dict("type" => "array", "value_type" => "float", "data" => PyVector(inc_hrs))
        relationships = [["unit__node__node", ["unit_ab", "node_a", "node_b"]]]
        relationship_parameter_values = [
            ["unit__to_node", ["unit_ab", "node_b"], "operating_points", operating_points],
            [relationships[1]..., "unit_incremental_heat_rate", unit_incremental_heat_rate],
            [relationships[1]..., "unit_idle_heat_rate", unit_idle_heat_rate],
            [relationships[1]..., "unit_start_flow", unit_start_flow],
        ]
        SpineInterface.import_data(
            url_in;
            relationships=relationships,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_unit_flow_op = m.ext[:spineopt].variables[:unit_flow_op]
        var_units_on = m.ext[:spineopt].variables[:units_on]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        constraint = m.ext[:spineopt].constraints[:unit_pw_heat_rate]
        @test length(constraint) == 1
        key_a = (unit(:unit_ab), node(:node_a), direction(:from_node))
        key_b = (unit(:unit_ab), node(:node_b), direction(:to_node))
        key_u_a_b = (unit(:unit_ab), node(:node_a), node(:node_b))
        s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
        t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
        t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
        expected_con = @build_constraint(
            + var_unit_flow[key_a..., s_parent, t1h1] + var_unit_flow[key_a..., s_child, t1h2] ==
            2 * sum(inc_hrs[i] * var_unit_flow_op[key_b..., i, s_parent, t2h] for i in 1:3) +
            unit_idle_heat_rate
            * (var_units_on[unit(:unit_ab), s_parent, t1h1] + var_units_on[unit(:unit_ab), s_child, t1h2]) +
            unit_start_flow * (
                var_units_started_up[unit(:unit_ab), s_parent, t1h1]
                + var_units_started_up[unit(:unit_ab), s_child, t1h2]
            )
        )
        con_key = (key_u_a_b..., [s_parent, s_child], t2h)
        observed_con = constraint_object(constraint[con_key...])
        @test _is_constraint_equal(observed_con, expected_con)
    end
    @testset "constraint_pw_unit_heat_rate_simple" begin
        _load_test_data(url_in, test_data)
        unit_idle_heat_rate = 200
        unit_start_flow = 100
        points = [0.1, 0.5, 1.0]
        inc_hrs = 10
        operating_points = Dict("type" => "array", "value_type" => "float", "data" => PyVector(points))
        relationships = [["unit__node__node", ["unit_ab", "node_a", "node_b"]]]
        relationship_parameter_values = [
            ["unit__to_node", ["unit_ab", "node_b"], "operating_points", operating_points],
            [relationships[1]..., "unit_incremental_heat_rate", inc_hrs],
            [relationships[1]..., "unit_idle_heat_rate", unit_idle_heat_rate],
            [relationships[1]..., "unit_start_flow", unit_start_flow],
        ]
        SpineInterface.import_data(
            url_in;
            relationships=relationships,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_unit_flow_op = m.ext[:spineopt].variables[:unit_flow_op]
        var_units_on = m.ext[:spineopt].variables[:units_on]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        constraint = m.ext[:spineopt].constraints[:unit_pw_heat_rate]
        @test length(constraint) == 1
        key_a = (unit(:unit_ab), node(:node_a), direction(:from_node))
        key_b = (unit(:unit_ab), node(:node_b), direction(:to_node))
        key_u_a_b = (unit(:unit_ab), node(:node_a), node(:node_b))
        s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
        t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
        t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
        expected_con = @build_constraint(
            + var_unit_flow[key_a..., s_parent, t1h1] + var_unit_flow[key_a..., s_child, t1h2] ==
            2 * sum(inc_hrs * var_unit_flow_op[key_b..., i, s_parent, t2h] for i in 1:3) +
            unit_idle_heat_rate
            * (var_units_on[unit(:unit_ab), s_parent, t1h1] + var_units_on[unit(:unit_ab), s_child, t1h2]) +
            unit_start_flow * (
                var_units_started_up[unit(:unit_ab), s_parent, t1h1]
                + var_units_started_up[unit(:unit_ab), s_child, t1h2]
            )
        )
        con_key = (key_u_a_b..., [s_parent, s_child], t2h)
        observed_con = constraint_object(constraint[con_key...])
        @test _is_constraint_equal(observed_con, expected_con)
    end
    @testset "constraint_pw_unit_heat_rate_simple2" begin
        _load_test_data(url_in, test_data)
        unit_idle_heat_rate = 200
        unit_start_flow = 100
        inc_hrs = 10
        relationships = [["unit__node__node", ["unit_ab", "node_a", "node_b"]]]
        relationship_parameter_values = [
            [relationships[1]..., "unit_incremental_heat_rate", inc_hrs],
            [relationships[1]..., "unit_idle_heat_rate", unit_idle_heat_rate],
            [relationships[1]..., "unit_start_flow", unit_start_flow],
        ]
        SpineInterface.import_data(
            url_in;
            relationships=relationships,
            relationship_parameter_values=relationship_parameter_values,
        )

        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_unit_flow = m.ext[:spineopt].variables[:unit_flow]
        var_unit_flow_op = m.ext[:spineopt].variables[:unit_flow_op]
        var_units_on = m.ext[:spineopt].variables[:units_on]
        var_units_started_up = m.ext[:spineopt].variables[:units_started_up]
        constraint = m.ext[:spineopt].constraints[:unit_pw_heat_rate]
        @test length(constraint) == 1
        key_a = (unit(:unit_ab), node(:node_a), direction(:from_node))
        key_b = (unit(:unit_ab), node(:node_b), direction(:to_node))
        key_u_a_b = (unit(:unit_ab), node(:node_a), node(:node_b))
        s_parent, s_child = stochastic_scenario(:parent), stochastic_scenario(:child)
        t1h1, t1h2 = time_slice(m; temporal_block=temporal_block(:hourly))
        t2h = time_slice(m; temporal_block=temporal_block(:two_hourly))[1]
        expected_con = @build_constraint(
            + var_unit_flow[key_a..., s_parent, t1h1] + var_unit_flow[key_a..., s_child, t1h2] ==
            2 * inc_hrs * var_unit_flow[key_b..., s_parent, t2h] +
            unit_idle_heat_rate
            * (var_units_on[unit(:unit_ab), s_parent, t1h1] + var_units_on[unit(:unit_ab), s_child, t1h2]) +
            unit_start_flow * (
                var_units_started_up[unit(:unit_ab), s_parent, t1h1]
                + var_units_started_up[unit(:unit_ab), s_child, t1h2]
            )
        )
        con_key = (key_u_a_b..., [s_parent, s_child], t2h)
        observed_con = constraint_object(constraint[con_key...])
        @test _is_constraint_equal(observed_con, expected_con)
    end
end
