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

# NOTE: always pick the second (last) node in `connection__from_node` as 'to' node

"""
    constraint_connection_flow_lodf_indices()

Forms the stochastic index set for the `:connection_flow_lodf` constraint.
Uses stochastic path indices due to potentially different stochastic structures
between `connection_flow` variables.
"""
function constraint_connection_flow_lodf_indices()
    unique(
        (connection1=conn_cont, connection2=conn_mon, stochastic_path=path, t=t)
        for (conn_cont, conn_mon) in indices(lodf)
        for t in _constraint_connection_flow_lodf_lowest_resolution_t(conn_cont, conn_mon)
        for path in active_stochastic_paths(
            unique(ind.stochastic_scenario for ind in _constraint_connection_flow_lodf_indices(conn_cont, conn_mon, t))
        )
    )
end

"""
    _constraint_connection_flow_lodf_lowest_resolution_t(conn_cont, conn_mon)

Finds the lowest resolution `t`s between the `connection_flow` variables of the `conn_cont` contingency connection and
the `conn_mon` monitored connection.
"""
function _constraint_connection_flow_lodf_lowest_resolution_t(conn_cont, conn_mon)
    t_lowest_resolution(
        ind.t
        for conn in (conn_cont, conn_mon)
        for ind in connection_flow_indices(; connection=conn, last(connection__from_node(connection=conn))...)
    )
end

"""
    _constraint_connection_flow_lodf_indices(conn_cont, conn_mon, t)

Gathers the indices of the `connection_flow` variable for the contingency connection `conn_cont` and
the monitored connection `conn_mon` on time slice `t`.
"""
function _constraint_connection_flow_lodf_indices(conn_cont, conn_mon, t)
    Iterators.flatten(
        (
            connection_flow_indices(
                ; connection=conn_mon, last(connection__from_node(connection=conn_mon))..., t=t_in_t(t_long=t)
            ),  # Monitored connection
            connection_flow_indices(
                ; connection=conn_cont, last(connection__from_node(connection=conn_cont))..., t=t_in_t(t_long=t)
            )  # Excess flow due to outage on contingency connection
        )
    )
end

"""
    add_constraint_connection_flow_lodf!(m::Model)

Limit the post contingency flow on monitored connection mon to conn_emergency_capacity upon outage of connection cont.
"""
function add_constraint_connection_flow_lodf!(m::Model)
    @fetch connection_flow = m.ext[:variables]
    cons = m.ext[:constraints][:connection_flow_lodf] = Dict()
    for (conn_cont, conn_mon, stochastic_path, t) in constraint_connection_flow_lodf_indices()
        cons[conn_cont, conn_mon, stochastic_path, t] = @constraint(
            m,
            - 1
            <=
            (
                # flow in monitored connection
                + expr_sum(
                    + connection_flow[conn_mon, n_mon_to, direction(:to_node), s, t_short]
                    - connection_flow[conn_mon, n_mon_to, direction(:from_node), s, t_short]
                    for (conn_mon, n_mon_to, d, t_short) in connection_flow_indices(;
                        connection=conn_mon, 
                        last(connection__from_node(connection=conn_mon))...,
                        stochastic_scenario=stochastic_path,
                        t=t_in_t(t_long=t)
                    ); # NOTE: always assume the second (last) node in `connection__from_node` is the 'to' node
                    init=0
                )
                # excess flow due to outage on contingency connection
                + lodf(connection1=conn_cont, connection2=conn_mon)
                * expr_sum(
                    + connection_flow[conn_cont, n_cont_to, direction(:to_node), s, t_short]
                    - connection_flow[conn_cont, n_cont_to, direction(:from_node), s, t_short]
                    for (conn_cont, n_cont_to, d, t_short) in connection_flow_indices(;
                        connection=conn_cont, 
                        last(connection__from_node(connection=conn_cont))...,
                        stochastic_scenario=stochastic_path,
                        t=t_in_t(t_long=t)
                    ); # NOTE: always assume the second (last) node in `connection__from_node` is the 'to' node
                    init=0
                )
            ) 
            / minimum(
                + connection_emergency_capacity[(connection=conn_mon, node=n_mon, direction=d, t=t)]
                * connection_availability_factor[(connection=conn_mon, t=t)]
                * connection_conv_cap_to_flow[(connection=conn_mon, node=n_mon, direction=d, t=t)]
                for (conn_mon, n_mon, d) in indices(connection_emergency_capacity; connection=conn_mon)
            )
            <=
            + 1
        )
    end
end
