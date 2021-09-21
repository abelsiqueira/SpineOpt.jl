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

@testset "node-based constraints" begin
    url_in = "sqlite://"
    test_data = Dict(
        :objects => [
            ["model", "instance"],
            ["model", "master"],
            ["temporal_block", "hourly"],
            ["temporal_block", "two_hourly"],
            ["temporal_block", "investments_hourly"],
            ["stochastic_structure", "deterministic"],
            ["stochastic_structure", "stochastic"],
            ["stochastic_structure", "investments_deterministic"],
            ["unit", "unit_ab"],
            ["connection", "connection_bc"],
            ["connection", "connection_ca"],
            ["node", "node_a"],
            ["node", "node_b"],
            ["node", "node_c"],
            ["node", "node_group_bc"],
            ["stochastic_scenario", "parent"],
            ["stochastic_scenario", "child"],
        ],
        :relationships => [
            ["model__temporal_block", ["instance", "hourly"]],
            ["model__temporal_block", ["instance", "two_hourly"]],
            ["model__temporal_block", ["master", "investments_hourly"]],
            ["model__stochastic_structure", ["instance", "deterministic"]],
            ["model__stochastic_structure", ["instance", "stochastic"]],
            ["model__stochastic_structure", ["master", "investments_deterministic"]],
            ["unit__from_node", ["unit_ab", "node_a"]],
            ["unit__to_node", ["unit_ab", "node_b"]],
            ["units_on__temporal_block", ["unit_ab", "two_hourly"]],
            ["units_on__stochastic_structure", ["unit_ab", "deterministic"]],
            ["connection__from_node", ["connection_bc", "node_b"]],
            ["connection__to_node", ["connection_bc", "node_c"]],
            ["connection__from_node", ["connection_ca", "node_c"]],
            ["connection__to_node", ["connection_ca", "node_a"]],
            ["node__temporal_block", ["node_a", "two_hourly"]],
            ["node__temporal_block", ["node_b", "hourly"]],
            ["node__temporal_block", ["node_c", "hourly"]],
            ["node__temporal_block", ["node_group_bc", "hourly"]],
            ["node__stochastic_structure", ["node_a", "deterministic"]],
            ["node__stochastic_structure", ["node_b", "stochastic"]],
            ["node__stochastic_structure", ["node_c", "stochastic"]],
            ["node__stochastic_structure", ["node_group_bc", "stochastic"]],
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
            ["model", "instance", "model_type", "spineopt_operations"],
            ["model", "master", "model_start", Dict("type" => "date_time", "data" => "2000-01-01T00:00:00")],
            ["model", "master", "model_end", Dict("type" => "date_time", "data" => "2000-01-01T02:00:00")],
            ["model", "master", "duration_unit", "hour"],
            ["model", "master", "model_type", "spineopt_other"],
            ["model", "master", "max_gap", "0.05"],
            ["model", "master", "max_iterations", "2"],
            ["temporal_block", "hourly", "resolution", Dict("type" => "duration", "data" => "1h")],
            ["temporal_block", "two_hourly", "resolution", Dict("type" => "duration", "data" => "2h")],
            ["temporal_block", "investments_hourly", "resolution", Dict("type" => "duration", "data" => "1h")],
            ["node", "node_group_bc", "balance_type", "balance_type_none"]
        ],
        :relationship_parameter_values => [[
            "stochastic_structure__stochastic_scenario",
            ["stochastic", "parent"],
            "stochastic_scenario_end",
            Dict("type" => "duration", "data" => "1h"),
        ]],
    )
    
    @testset "constraint_nodal_balance" begin
        _load_test_data(url_in, test_data)
        object_parameter_values = [["node", "node_a", "node_slack_penalty", 0.5]]
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values)
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_injection = m.ext[:variables][:node_injection]
        var_connection_flow = m.ext[:variables][:connection_flow]
        var_node_slack_pos = m.ext[:variables][:node_slack_pos]
        var_node_slack_neg = m.ext[:variables][:node_slack_neg]
        constraint = m.ext[:constraints][:nodal_balance]

        @test length(constraint) == 5

        conn = connection(:connection_ca)
        # node_a
        n = node(:node_a)
        key_tail = (stochastic_scenario(:parent), time_slice(m; temporal_block=temporal_block(:two_hourly))[1])
        node_key = (n, key_tail...)
        conn_key = (conn, n, direction(:to_node), key_tail...)
        var_n_inj = var_node_injection[node_key...]
        var_n_sl_pos = var_node_slack_pos[node_key...]
        var_n_sl_neg = var_node_slack_neg[node_key...]
        var_conn_flow = var_connection_flow[conn_key...]
        expected_con = @build_constraint(var_n_inj + var_conn_flow + var_n_sl_pos - var_n_sl_neg == 0)
        con = constraint[node_key...]
        observed_con = constraint_object(con)       

        # node_b
        n = node(:node_b)
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_n_inj = var_node_injection[n, s, t]
            var_conn_flows = (                
                - var_connection_flow[connection(:connection_bc), node(:node_b), direction(:from_node), s, t]                
            )
            expected_con = @build_constraint(var_n_inj + var_conn_flows == 0)
            con = constraint[n, s, t]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
        
        @test _is_constraint_equal(observed_con, expected_con)
    end

    @testset "constraint_nodal_balance_group" begin
        _load_test_data(url_in, test_data)
        object_parameter_values = [
            ["node", "node_a", "node_slack_penalty", 0.5],
            ["node", "node_group_bc", "balance_type", "balance_type_group"]
        ]
        
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values)
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_injection = m.ext[:variables][:node_injection]
        var_connection_flow = m.ext[:variables][:connection_flow]
        var_node_slack_pos = m.ext[:variables][:node_slack_pos]
        var_node_slack_neg = m.ext[:variables][:node_slack_neg]
        constraint = m.ext[:constraints][:nodal_balance]
        @test length(constraint) == 3
        conn = connection(:connection_ca)
        # node_a
        n = node(:node_a)
        key_tail = (stochastic_scenario(:parent), time_slice(m; temporal_block=temporal_block(:two_hourly))[1])
        node_key = (n, key_tail...)
        conn_key = (conn, n, direction(:to_node), key_tail...)
        var_n_inj = var_node_injection[node_key...]
        var_n_sl_pos = var_node_slack_pos[node_key...]
        var_n_sl_neg = var_node_slack_neg[node_key...]
        var_conn_flow = var_connection_flow[conn_key...]
        expected_con = @build_constraint(var_n_inj + var_conn_flow + var_n_sl_pos - var_n_sl_neg == 0)
        con = constraint[node_key...]
        observed_con = constraint_object(con)
        
        @test _is_constraint_equal(observed_con, expected_con)
        # node_group_bc
        n = node(:node_group_bc)
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            var_n_inj = var_node_injection[node(:node_group_bc), s, t]
            var_conn_flows = (                            
                - var_connection_flow[connection(:connection_ca), node(:node_c), direction(:from_node), s, t]
            )
            
            expected_con = @build_constraint(var_n_inj + var_conn_flows == 0)
            con = constraint[node(:node_group_bc), s, t]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_node_injection" begin
        demand_a = 100
        demand_b = 20
        demand_c = -80
        demand_group = 200
        fractional_demand_b = 0.6
        fractional_demand_c = 0.4
        frac_state_loss_b = 0.15
        frac_state_loss_c = 0.25
        state_coeff_b = 0.9
        state_coeff_c = 0.8
        diff_coeff_bc = 0.2
        diff_coeff_cb = 0.3
        _load_test_data(url_in, test_data)
        relationships = [["node__node", ["node_b", "node_c"]], ["node__node", ["node_c", "node_b"]]]
        object_parameter_values = [
            ["node", "node_a", "demand", demand_a],
            ["node", "node_b", "demand", demand_b],
            ["node", "node_c", "demand", demand_c],
            ["node", "node_group_bc", "demand", demand_group],
            ["node", "node_b", "has_state", true],
            ["node", "node_c", "has_state", true],
            ["node", "node_b", "frac_state_loss", frac_state_loss_b],
            ["node", "node_c", "frac_state_loss", frac_state_loss_c],
            ["node", "node_b", "state_coeff", state_coeff_b],
            ["node", "node_c", "state_coeff", state_coeff_c],
            ["node", "node_b", "fractional_demand", fractional_demand_b],
            ["node", "node_c", "fractional_demand", fractional_demand_c],
        ]
        relationship_parameter_values = [
            ["node__node", ["node_b", "node_c"], "diff_coeff", diff_coeff_bc],
            ["node__node", ["node_c", "node_b"], "diff_coeff", diff_coeff_cb],
        ]
        SpineInterface.import_data(
            url_in;
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_injection = m.ext[:variables][:node_injection]
        var_unit_flow = m.ext[:variables][:unit_flow]
        var_node_state = m.ext[:variables][:node_state]
        constraint = m.ext[:constraints][:node_injection]
        @test length(constraint) == 7
        u = unit(:unit_ab)
        # node_a
        n = node(:node_a)
        s = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:two_hourly))
        @testset for t1 in time_slices
            var_n_inj = var_node_injection[n, s, t1]
            var_u_flow = var_unit_flow[u, node(:node_a), direction(:from_node), s, t1]
            expected_con = @build_constraint(var_n_inj + var_u_flow + demand_a == 0)
            @testset for (n, t0, t1) in node_dynamic_time_indices(m; node=n, t_after=t1)
                con = constraint[n, [s], t0, t1]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
        # node_group_bc
        n = node(:node_group_bc)
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t1) in zip(scenarios, time_slices)
            var_n_inj = var_node_injection[n, s, t1]
            var_u_flow = var_unit_flow[u, node(:node_b), direction(:to_node), s, t1]
            expected_con = @build_constraint(var_n_inj - var_u_flow + demand_group == 0)
            @testset for (n, t0, t1) in node_dynamic_time_indices(m; node=n, t_after=t1)
                con = constraint[n, [s], t0, t1]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
        # node_b
        n = node(:node_b)
        s0 = stochastic_scenario(:parent)
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_n_st_b1 = var_node_state[n, s1, t1]
            var_n_st_c1 = var_node_state[node(:node_c), s1, t1]
            var_n_inj = var_node_injection[n, s1, t1]
            var_u_flow = var_unit_flow[u, node(:node_b), direction(:to_node), s1, t1]
            @testset for (n, t0, t1) in node_dynamic_time_indices(m; node=n, t_after=t1)
                var_n_st_b0 = get(var_node_state, (n, s0, t0), 0)
                expected_con = @build_constraint(
                    var_n_inj + (state_coeff_b + frac_state_loss_b + diff_coeff_bc) * var_n_st_b1
                    - state_coeff_b * var_n_st_b0 - diff_coeff_cb * var_n_st_c1 - var_u_flow +
                    demand_b +
                    demand_group * fractional_demand_b == 0
                )
                con = constraint[n, path, t0, t1]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
        # node_c
        n = node(:node_c)
        s0 = stochastic_scenario(:parent)
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_n_st_c1 = var_node_state[n, s1, t1]
            var_n_st_b1 = var_node_state[node(:node_b), s1, t1]
            var_n_inj = var_node_injection[n, s1, t1]
            @testset for (n, t0, t1) in node_dynamic_time_indices(m; node=n, t_after=t1)
                var_n_st_c0 = get(var_node_state, (n, s0, t0), 0)
                expected_con = @build_constraint(
                    var_n_inj + (state_coeff_c + frac_state_loss_c + diff_coeff_cb) * var_n_st_c1
                    - state_coeff_c * var_n_st_c0 - diff_coeff_bc * var_n_st_b1 +
                    demand_c +
                    demand_group * fractional_demand_c == 0
                )
                con = constraint[n, path, t0, t1]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_node_state_capacity" begin
        _load_test_data(url_in, test_data)
        node_capacity = Dict("node_b" => 120, "node_c" => 400)
        object_parameter_values = [
            ["node", "node_b", "node_state_cap", node_capacity["node_b"]],
            ["node", "node_c", "node_state_cap", node_capacity["node_c"]],
            ["node", "node_b", "has_state", true],
            ["node", "node_c", "has_state", true],
        ]
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values)
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_state = m.ext[:variables][:node_state]
        constraint = m.ext[:constraints][:node_state_capacity]
        @test length(constraint) == 4
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for (name, cap) in node_capacity
                n = node(Symbol(name))
                var_n_st_key = (n, s, t)
                con_key = (n, [s], t)
                var_n_st = var_node_state[var_n_st_key...]
                expected_con = @build_constraint(var_n_st <= cap)
                con = constraint[con_key...]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_cyclic_node_state" begin
        _load_test_data(url_in, test_data)
        node_capacity = Dict("node_b" => 120, "node_c" => 400)
        cyc_cond = Dict(("node_b", "hourly") => true, ("node_c", "hourly") => true)
        object_parameter_values = [
            ["node", "node_b", "node_state_cap", node_capacity["node_b"]],
            ["node", "node_c", "node_state_cap", node_capacity["node_c"]],
            ["node", "node_b", "has_state", true],
            ["node", "node_c", "has_state", true],
        ]
        relationship_parameter_values = [
            ["node__temporal_block", ["node_b", "hourly"], "cyclic_condition",cyc_cond[("node_b", "hourly")]],
            ["node__temporal_block", ["node_c", "hourly"],"cyclic_condition", cyc_cond[("node_c", "hourly")]],
        ]
        SpineInterface.import_data(url_in; object_parameter_values=object_parameter_values, relationship_parameter_values=relationship_parameter_values)
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_state = m.ext[:variables][:node_state]
        constraint = m.ext[:constraints][:cyclic_node_state]
        @test length(constraint) == 2
        scenario0 = stochastic_scenario(:parent)
        scenario1 = stochastic_scenario(:child)
        @testset for ((n,blk), cyc) in cyc_cond
            n = node(Symbol(n))
            blk = temporal_block(Symbol(blk))
            t0 = filter(x -> blk in blocks(x),t_before_t(m;t_after=first(time_slice(m;temporal_block=blk))))[1]
            t1 = last(time_slice(m;temporal_block=blk))
            var_n_st_key0 = (n, scenario0, t0)
            var_n_st_key1 = (n, scenario1, t1)
            con_key = (n, [scenario0, scenario1], t0, t1)
            var_n_st0 = var_node_state[var_n_st_key0...]
            var_n_st1 = var_node_state[var_n_st_key1...]
            expected_con = @build_constraint(var_n_st1 >= var_n_st0)
            con = constraint[con_key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_storage_line_pack" begin
        _load_test_data(url_in, test_data)
        pressure = Dict("node_b" => true, "node_c" => true)
        state = Dict("node_a" => true)
        object_parameter_values = [
            ["node", "node_b", "has_pressure", pressure["node_b"]],
            ["node", "node_c", "has_pressure", pressure["node_c"]],
            ["node", "node_a", "has_state", state["node_a"]],
        ]
        conn_linepack = Dict(("connection_bc","node_a","node_group_bc") => 28)
        relationships = [
            ["connection__to_node", ["connection_bc", "node_a"]],
            ["connection__from_node", ["connection_bc", "node_a"]],
            ["connection__node__node",["connection_bc","node_a","node_group_bc"]],
        ]
        relationship_parameter_values = [
            ["connection__node__node",["connection_bc","node_a","node_group_bc"],"connection_linepack_constant", conn_linepack[("connection_bc","node_a","node_group_bc")]]
        ]
        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
            relationships=relationships,
        )
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_pressure = m.ext[:variables][:node_pressure]
        var_node_state = m.ext[:variables][:node_state]
        constraint = m.ext[:constraints][:storage_line_pack]
        @test length(constraint) == 1
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        scenario_det = stochastic_scenario(:parent)
        time_slices = [time_slice(m; temporal_block=temporal_block(:two_hourly))[1],]
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for ((conn,n_stor,ng), conn_lp) in conn_linepack
                conn = connection(Symbol(conn))
                n_stor = node(Symbol(n_stor))
                ng = node(Symbol(ng))
                (n1,n2) = members(ng)
                var_n_stor_key = (n_stor, scenario_det, t)
                (t1,t2) = sort(filter(x -> temporal_block(:hourly) in blocks(x),t_in_t(m;t_long=t)))
                var_n1_press_key_t1 = (n1, s, t1)
                var_n1_press_key_t2 = (n1, stochastic_scenario(:child), t2)
                var_n2_press_key_t1 = (n2, s, t1)
                var_n2_press_key_t2 = (n2, stochastic_scenario(:child), t2)
                con_key = (conn, n_stor, ng, [scenarios...], t)
                var_n_st = var_node_state[var_n_stor_key...]
                var_pr1_t1 = var_node_pressure[var_n1_press_key_t1...]
                var_pr1_t2 = var_node_pressure[var_n1_press_key_t2...]
                var_pr2_t1 = var_node_pressure[var_n2_press_key_t1...]
                var_pr2_t2 = var_node_pressure[var_n2_press_key_t2...]
                expected_con = @build_constraint(var_n_st*2 == conn_lp*0.5*((var_pr1_t1+var_pr1_t2)+(var_pr2_t1+var_pr2_t2)))
                con = constraint[con_key...]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    #TODO
    end
    @testset "constraint_compression_ratio" begin
        _load_test_data(url_in, test_data)
        has_pressure = Dict("node_b" => true, "node_c" => true)
        relationships = [["connection__node__node", [ "connection_bc", "node_b", "node_c"]]]
        compression_ratio = Dict(("connection_bc","node_b", "node_c") => 1.2) #fromnodetonode
        object_parameter_values = [
            ["node", "node_b", "has_pressure", has_pressure["node_b"]],
            ["node", "node_c", "has_pressure", has_pressure["node_c"]],
        ]
        relationship_parameter_values = [
            ["connection__node__node", ["connection_bc", "node_b", "node_c"], "compression_factor", compression_ratio[(("connection_bc","node_b", "node_c"))]]]
        SpineInterface.import_data(
            url_in;
            relationships=relationships,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_pressure = m.ext[:variables][:node_pressure]
        constraint = m.ext[:constraints][:compression_ratio]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for ((conn,n1,n2), comp_ratio) in compression_ratio
                conn = connection(Symbol(conn))
                n1 = node(Symbol(n1))
                n2 = node(Symbol(n2))
                var_n_pressure_key1 = (n1, s, t)
                var_n_pressure_key2 = (n2, s, t)
                con_key = (conn, n1, n2, [s], t)
                var_n1 = var_node_pressure[var_n_pressure_key1...]
                var_n2 = var_node_pressure[var_n_pressure_key2...]
                expected_con = @build_constraint(var_n2 <= comp_ratio*var_n1)
                con = constraint[con_key...]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_min_node_pressure" begin
        _load_test_data(url_in, test_data)
        has_pressure = Dict("node_b" => true)
        min_pressure = Dict("node_b" => 350)
        object_parameter_values = [
            ["node", "node_b", "has_pressure", has_pressure["node_b"]],
            ["node", "node_b", "min_node_pressure", min_pressure["node_b"]]
        ]
        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values
        )
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_pressure = m.ext[:variables][:node_pressure]
        constraint = m.ext[:constraints][:min_node_pressure]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for (n, min_press) in min_pressure
                n = node(Symbol(n))
                var_n_pressure_key1 = (n, s, t)
                con_key = (n, [s], t)
                var_n1 = var_node_pressure[var_n_pressure_key1...]
                expected_con = @build_constraint(var_n1 >= min_press)
                con = constraint[con_key...]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_max_node_pressure" begin
        _load_test_data(url_in, test_data)
        has_pressure = Dict("node_b" => true)
        max_pressure = Dict("node_b" => 470)
        object_parameter_values = [
            ["node", "node_b", "has_pressure", has_pressure["node_b"]],
            ["node", "node_b", "max_node_pressure", max_pressure["node_b"]]
        ]
        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values
        )
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_pressure = m.ext[:variables][:node_pressure]
        constraint = m.ext[:constraints][:max_node_pressure]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for (n, max_press) in max_pressure
                n = node(Symbol(n))
                var_n_pressure_key1 = (n, s, t)
                con_key = (n, [s], t)
                var_n1 = var_node_pressure[var_n_pressure_key1...]
                expected_con = @build_constraint(var_n1 <= max_press)
                con = constraint[con_key...]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_min_node_voltage_angle" begin
        _load_test_data(url_in, test_data)
        has_voltage_angle = Dict("node_b" => true)
        min_voltage_angle = Dict("node_b" => -3.14)
        object_parameter_values = [
            ["node", "node_b", "has_voltage_angle", has_voltage_angle["node_b"]],
            ["node", "node_b", "min_voltage_angle", min_voltage_angle["node_b"]]
        ]
        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values
        )
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_voltage_angle = m.ext[:variables][:node_voltage_angle]
        constraint = m.ext[:constraints][:min_node_voltage_angle]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for (n, min_volt_ang) in min_voltage_angle
                n = node(Symbol(n))
                var_n_voltage_key1 = (n, s, t)
                con_key = (n, [s], t)
                var_n1 = var_node_voltage_angle[var_n_voltage_key1...]
                expected_con = @build_constraint(var_n1 >= min_volt_ang)
                con = constraint[con_key...]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_max_node_voltage_angle" begin
        _load_test_data(url_in, test_data)
        has_voltage_angle = Dict("node_b" => true)
        max_voltage_angle = Dict("node_b" => 3.14)
        object_parameter_values = [
            ["node", "node_b", "has_voltage_angle", has_voltage_angle["node_b"]],
            ["node", "node_b", "max_voltage_angle", max_voltage_angle["node_b"]]
        ]
        SpineInterface.import_data(
            url_in;
            object_parameter_values=object_parameter_values
        )
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_voltage_angle = m.ext[:variables][:node_voltage_angle]
        constraint = m.ext[:constraints][:max_node_voltage_angle]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            @testset for (n, max_volt_ang) in max_voltage_angle
                n = node(Symbol(n))
                var_n_voltage_key1 = (n, s, t)
                con_key = (n, [s], t)
                var_n1 = var_node_voltage_angle[var_n_voltage_key1...]
                expected_con = @build_constraint(var_n1 <= max_volt_ang)
                con = constraint[con_key...]
                observed_con = constraint_object(con)
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_node_state_capacity_investments" begin
        _load_test_data(url_in, test_data)
        candidate_storages = 1
        node_capacity = 400
        object_parameter_values = [
            ["node", "node_c", "node_state_cap", node_capacity],
            ["node", "node_c", "has_state", true],
            ["node", "node_c", "candidate_storages", candidate_storages],
        ]
        relationships = [
            ["node__investment_temporal_block", ["node_c", "hourly"]],
            ["node__investment_stochastic_structure", ["node_c", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_node_state = m.ext[:variables][:node_state]
        var_storages_invested_available = m.ext[:variables][:storages_invested_available]
        constraint = m.ext[:constraints][:node_state_capacity]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        path = [stochastic_scenario(:parent), stochastic_scenario(:child)]
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            n = node(:node_c)
            var_n_st_key = (n, s, t)
            var_s_in_av_key = (n, s, t)
            con_key = (n, [s], t)
            var_n_st = var_node_state[var_n_st_key...]
            var_s_inv_av = var_storages_invested_available[var_s_in_av_key...]
            expected_con = @build_constraint(var_n_st <= node_capacity * var_s_inv_av)
            con = constraint[con_key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_storages_invested_available" begin
        _load_test_data(url_in, test_data)
        candidate_storages = 1
        node_capacity = 500
        object_parameter_values = [
            ["node", "node_c", "candidate_storages", candidate_storages],
            ["node", "node_c", "node_state_cap", node_capacity],
            ["node", "node_b", "has_state", true],
        ]
        relationships = [
            ["node__investment_temporal_block", ["node_c", "hourly"]],
            ["node__investment_stochastic_structure", ["node_c", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_storages_invested_available = m.ext[:variables][:storages_invested_available]
        constraint = m.ext[:constraints][:storages_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (node(:node_c), s, t)
            var = var_storages_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_storages)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_storages_invested_available_mp" begin
        _load_test_data(url_in, test_data)
        candidate_storages = 7
        node_capacity = 500
        object_parameter_values = [
            ["node", "node_c", "candidate_storages", candidate_storages],
            ["node", "node_c", "node_state_cap", node_capacity],
            ["node", "node_b", "has_state", true],
            ["model", "master", "model_type", "spineopt_master"],
        ]
        relationships = [
            ["node__investment_temporal_block", ["node_c", "hourly"]],
            ["node__investment_temporal_block", ["node_c", "investments_hourly"]],
            ["node__investment_stochastic_structure", ["node_c", "stochastic"]],
            ["node__investment_stochastic_structure", ["node_c", "investments_deterministic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
        
        m, mp = run_spineopt(url_in; log_level=0, optimize=false)
        var_storages_invested_available = m.ext[:variables][:storages_invested_available]
        constraint = m.ext[:constraints][:storages_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (node(:node_c), s, t)
            var = var_storages_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_storages)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
        var_storages_invested_available = mp.ext[:variables][:storages_invested_available]
        constraint = mp.ext[:constraints][:storages_invested_available]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        time_slices = time_slice(mp; temporal_block=temporal_block(:investments_hourly))
        @testset for (s, t) in zip(scenarios, time_slices)
            key = (node(:node_c), s, t)
            var = var_storages_invested_available[key...]
            expected_con = @build_constraint(var <= candidate_storages)
            con = constraint[key...]
            observed_con = constraint_object(con)
            @test _is_constraint_equal(observed_con, expected_con)
        end
    end
    @testset "constraint_storages_invested_transition" begin
        _load_test_data(url_in, test_data)
        candidate_storages = 1
        node_capacity = 500
        object_parameter_values = [
            ["node", "node_c", "candidate_storages", candidate_storages],
            ["node", "node_c", "node_state_cap", node_capacity],
            ["node", "node_b", "has_state", true],
        ]
        relationships = [
            ["node__investment_temporal_block", ["node_c", "hourly"]],
            ["node__investment_stochastic_structure", ["node_c", "stochastic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
        
        m = run_spineopt(url_in; log_level=0, optimize=false)
        var_storages_invested_available = m.ext[:variables][:storages_invested_available]
        var_storages_invested = m.ext[:variables][:storages_invested]
        var_storages_decommissioned = m.ext[:variables][:storages_decommissioned]
        constraint = m.ext[:constraints][:storages_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (node(:node_c), s1, t1)
            var_s_inv_av1 = var_storages_invested_available[var_key1...]
            var_s_inv_1 = var_storages_invested[var_key1...]
            var_s_decom_1 = var_storages_decommissioned[var_key1...]
            @testset for (n, t0, t1) in node_investment_dynamic_time_indices(m; node=node(:node_c), t_after=t1)
                var_key0 = (n, s0, t0)
                var_s_inv_av0 = get(var_storages_invested_available, var_key0, 0)
                con_key = (n, path, t0, t1)
                expected_con = @build_constraint(var_s_inv_av1 - var_s_inv_1 + var_s_decom_1 == var_s_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_storages_invested_transition_mp" begin
        _load_test_data(url_in, test_data)
        candidate_storages = 1
        node_capacity = 500
        object_parameter_values = [
            ["node", "node_c", "candidate_storages", candidate_storages],
            ["node", "node_c", "node_state_cap", node_capacity],
            ["node", "node_b", "has_state", true],
            ["model", "master", "model_type", "spineopt_master"],
        ]
        relationships = [
            ["node__investment_temporal_block", ["node_c", "hourly"]],
            ["node__investment_temporal_block", ["node_c", "investments_hourly"]],
            ["node__investment_stochastic_structure", ["node_c", "stochastic"]],
            ["node__investment_stochastic_structure", ["node_c", "investments_deterministic"]],
        ]
        SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
        
        m, mp = run_spineopt(url_in; log_level=0, optimize=false)
        var_storages_invested_available = m.ext[:variables][:storages_invested_available]
        var_storages_invested = m.ext[:variables][:storages_invested]
        var_storages_decommissioned = m.ext[:variables][:storages_decommissioned]
        constraint = m.ext[:constraints][:storages_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent), stochastic_scenario(:child))
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(m; temporal_block=temporal_block(:hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (node(:node_c), s1, t1)
            var_s_inv_av1 = var_storages_invested_available[var_key1...]
            var_s_inv_1 = var_storages_invested[var_key1...]
            var_s_decom_1 = var_storages_decommissioned[var_key1...]
            @testset for (n, t0, t1) in node_investment_dynamic_time_indices(m; node=node(:node_c), t_after=t1)
                var_key0 = (n, s0, t0)
                var_s_inv_av0 = get(var_storages_invested_available, var_key0, 0)
                con_key = (n, path, t0, t1)
                expected_con = @build_constraint(var_s_inv_av1 - var_s_inv_1 + var_s_decom_1 == var_s_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end

        var_storages_invested_available = mp.ext[:variables][:storages_invested_available]
        var_storages_invested = mp.ext[:variables][:storages_invested]
        var_storages_decommissioned = mp.ext[:variables][:storages_decommissioned]
        constraint = mp.ext[:constraints][:storages_invested_transition]
        @test length(constraint) == 2
        scenarios = (stochastic_scenario(:parent),)
        s0 = stochastic_scenario(:parent)
        time_slices = time_slice(mp; temporal_block=temporal_block(:investments_hourly))
        @testset for (s1, t1) in zip(scenarios, time_slices)
            path = unique([s0, s1])
            var_key1 = (node(:node_c), s1, t1)
            var_s_inv_av1 = var_storages_invested_available[var_key1...]
            var_s_inv_1 = var_storages_invested[var_key1...]
            var_s_decom_1 = var_storages_decommissioned[var_key1...]
            @testset for (n, t0, t1) in node_investment_dynamic_time_indices(mp; node=node(:node_c), t_after=t1)
                var_key0 = (n, s0, t0)
                var_s_inv_av0 = get(var_storages_invested_available, var_key0, 0)
                con_key = (n, path, t0, t1)
                expected_con = @build_constraint(var_s_inv_av1 - var_s_inv_1 + var_s_decom_1 == var_s_inv_av0)
                observed_con = constraint_object(constraint[con_key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_storage_lifetime" begin
        candidate_storages = 1
        node_capacity = 500
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for lifetime_minutes in (30, 180, 240)
            _load_test_data(url_in, test_data)
            storage_investment_lifetime = Dict("type" => "duration", "data" => string(lifetime_minutes, "m"))
            object_parameter_values = [
                ["node", "node_c", "candidate_storages", candidate_storages],
                ["node", "node_c", "node_state_cap", node_capacity],
                ["node", "node_c", "has_state", true],
                ["node", "node_c", "storage_investment_lifetime", storage_investment_lifetime],
                ["model", "instance", "model_end", model_end],
            ]
            relationships = [
                ["node__investment_temporal_block", ["node_c", "hourly"]],
                ["node__investment_stochastic_structure", ["node_c", "stochastic"]],
            ]
            SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
            
            m = run_spineopt(url_in; log_level=0, optimize=false)
            var_storages_invested_available = m.ext[:variables][:storages_invested_available]
            var_storages_invested = m.ext[:variables][:storages_invested]
            constraint = m.ext[:constraints][:storage_lifetime]

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
                key = (node(:node_c), path, t)
                var_s_inv_av_key = (node(:node_c), s, t)
                var_s_inv_av = var_storages_invested_available[var_s_inv_av_key...]
                vars_s_inv = [var_storages_invested[node(:node_c), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_s_inv_av >= sum(vars_s_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end
    @testset "constraint_storage_lifetime_mp" begin
        candidate_storages = 1
        node_capacity = 500
        model_end = Dict("type" => "date_time", "data" => "2000-01-01T05:00:00")
        @testset for lifetime_minutes in (30, 180, 240)
            _load_test_data(url_in, test_data)
            storage_investment_lifetime = Dict("type" => "duration", "data" => string(lifetime_minutes, "m"))
            object_parameter_values = [
                ["node", "node_c", "candidate_storages", candidate_storages],
                ["node", "node_c", "node_state_cap", node_capacity],
                ["node", "node_c", "has_state", true],
                ["node", "node_c", "storage_investment_lifetime", storage_investment_lifetime],
                ["model", "instance", "model_end", model_end],
                ["model", "master", "model_end", model_end],
                ["model", "master", "model_type", "spineopt_master"],
            ]
            relationships = [
                ["node__investment_temporal_block", ["node_c", "hourly"]],
                ["node__investment_stochastic_structure", ["node_c", "stochastic"]],
                ["node__investment_temporal_block", ["node_c", "investments_hourly"]],
                ["node__investment_stochastic_structure", ["node_c", "investments_deterministic"]],
            ]
            SpineInterface.import_data(url_in; relationships=relationships, object_parameter_values=object_parameter_values)
            
            m, mp = run_spineopt(url_in; log_level=0, optimize=false)
            var_storages_invested_available = m.ext[:variables][:storages_invested_available]
            var_storages_invested = m.ext[:variables][:storages_invested]
            constraint = m.ext[:constraints][:storage_lifetime]

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
                key = (node(:node_c), path, t)
                var_s_inv_av_key = (node(:node_c), s, t)
                var_s_inv_av = var_storages_invested_available[var_s_inv_av_key...]
                vars_s_inv = [var_storages_invested[node(:node_c), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_s_inv_av >= sum(vars_s_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end

            var_storages_invested_available = mp.ext[:variables][:storages_invested_available]
            var_storages_invested = mp.ext[:variables][:storages_invested]
            constraint = mp.ext[:constraints][:storage_lifetime]
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
                key = (node(:node_c), path, t)
                var_s_inv_av_key = (node(:node_c), s, t)
                var_s_inv_av = var_storages_invested_available[var_s_inv_av_key...]
                vars_s_inv = [var_storages_invested[node(:node_c), s, t] for (s, t) in zip(s_set, t_set)]
                expected_con = @build_constraint(var_s_inv_av >= sum(vars_s_inv))
                observed_con = constraint_object(constraint[key...])
                @test _is_constraint_equal(observed_con, expected_con)
            end
        end
    end       
end