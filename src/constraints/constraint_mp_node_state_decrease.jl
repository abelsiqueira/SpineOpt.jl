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

"""
    add_constraint_mp_node_state_decrease!(m::Model)

Limit the decrease in node state between timeslices in the master problem to `decomposed_max_state_decrease`, if it exists.

"""
function add_constraint_mp_node_state_decrease!(m::Model)
    @fetch mp_node_state = m.ext[:variables]
    t0 = startref(current_window(m))
    m.ext[:constraints][:mp_node_state_decrease] = Dict(
        (node=ng, stochastic_scenario=s, t_before=t_before, t_after=t_after) => @constraint(
            m,
            - expr_sum(
                + mp_node_state[ng, s, t_after]
                for (ng, s, t_after) in mp_node_state_indices(m; node=ng, stochastic_scenario=s, t=t_after);
                init=0,
            )
            + expr_sum(
                + mp_node_state[ng, s, t_before]            
                for (ng, s, t_before) in mp_node_state_indices(m; node=ng, stochastic_scenario=s, t=t_before);                    
                init=0,
            )      

            <=

            unit_capacity[(unit=u, node=ng, direction=d, stochastic_scenario=s, analysis_time=t0, t=t)] *
            unit_conv_cap_to_flow[(unit=u, node=ng, direction=d, stochastic_scenario=s, analysis_time=t0, t=t)] *
            number_of_units[(unit=u, stochastic_scenario=s, analysis_time=t0, t=t)] *                  
            ( 
                + duration(t)*            
                + expr_sum(
                    units_invested_available[u, s, t] ) *
                    min(duration(t1), duration(t)) *
                    unit_capacity[(unit=u, node=ng, direction=d, stochastic_scenario=s, analysis_time=t0, t=t)] *
                    unit_conv_cap_to_flow[(unit=u, node=ng, direction=d, stochastic_scenario=s, analysis_time=t0, t=t)] for (u, s, t1) in units_invested_available_indices(m; unit=u, stochastic_scenario=s, t=t_overlaps_t(m; t=t));
                    init=0,
                )
            )  for (u, s, t) in units_invested_available_indices(m; unit=u);
            for u in unit__to_node(node=ng, direction=d) if (u, ng, d) in indices(unit_capacity)
            for d in direction=direction(:to_node)                            
        ) for (ng, s, t_before, t_after) in constraint_mp_node_state_decrease_indices(m)
    )
end


"""
    constraint_mp_node_state_decrease_indices(m::Model; filtering_options...)

Form the stochastic index array for the `:constraint_mp_node_state_increase` constraint.

Uses stochastic path indices of the `node_state` variables. Keyword arguments can be used to filter the resulting 
"""
function constraint_mp_node_state_decrease_indices(
    m::Model;    
    node=anything,    
    stochastic_path=anything,
    t_before=anything,
    t_after=anything,
)
    unique(
        (node=ng, stochastic_path=path, t_before=t_before, t_after=t_after)                       
        for (ng, s, t_after) in mp_node_state_indices(m; node=node) 
            if ng in mp_storage_node && ng in indices(decomposed_max_state_decrease)
        for (ng, t_before, t_after) in mp_node_dynamic_time_indices(m; node=ng, t_before=t_before, t_after=t_after)
        for path in active_stochastic_paths(unique(
            ind.stochastic_scenario for ind in mp_node_state_indices(m; node=ng, t=[t_before, t_after])
        )) if path == stochastic_path || path in stochastic_path
        
    )
end

