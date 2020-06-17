#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of Spine Model.
#
# Spine Model is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Spine Model is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
#TODO: stochastic_path
#TODO: define start_up_ramp_costs, ramp_up_costs
#TODO: leave for now but add later
"""
    constraint_ramp_cost(m::Model)

Limit the maximum in/out `unit_flow` of a `unit` for all `unit_capacity` indices.
Check if `unit_conv_cap_to_unit_flow` is defined.
"""
function add_constraint_ramp_cost!(m::Model)
    @fetch ramp_cost, units_started_up, units_shut_down, unit_flow = m.ext[:variables]
    cons = m.ext[:constraints][:ramp_cost] = Dict{NamedTuple,Any}()
    for (u,t) in ramp_cost_indices() ###history needed for
        @warn "add ramp_costs"
        for (u, c) in indices(ramp_up_costs;unit=u)
            cons[(unit=u, t=t)] = @constraint(
                m,
                ramp_cost[u,t]
                >=
                + ramp_up_costs(unit=u,commodity=c)
                * reduce(
                    +,
                    unit_flow[u1,n1,c1,d1,t1] - unit_flow[u1,n1,c1,d1,t_before] - units_started_up[u,t1]*unit_capacity(unit=u,commodity=c,direction=d1)
                    for (u1,n1,c1,d1,t1) in unit_flow_indices(unit=u, commodity=c, t=t_in_t(t_long=t))
                        for (u1,n1,c1,d1,t_before) in unit_flow_indices(unit=u1,node=n1,commodity=c1,direction=d1,t=t_before_t(t_after=t1));
                    init=0
                )
            )
        end
        for (u, c) in indices(ramp_down_costs;unit=u)
            cons[(unit=u, t=t)] = @constraint(
                m,
                ramp_cost[u,t]
                >=
                + ramp_down_costs(unit=u,commodity=c)
                * reduce(
                    +,
                    unit_flow[u1,n1,c1,d1,t_before] - unit_flow[u1,n1,c1,d1,t1] - units_shut_down[u,t1]*unit_capacity(unit=u,commodity=c,direction=d1)
                    for (u1,n1,c1,d1,t1) in unit_flow_indices(unit=u, commodity=c, t=t_in_t(t_long=t))
                        for (u1,n1,c1,d1,t_before) in unit_flow_indices(unit=u1,node=n1,commodity=c1,direction=d1,t=t_before_t(t_after=t1));
                    init=0
                )
            )
        end
    end
end
