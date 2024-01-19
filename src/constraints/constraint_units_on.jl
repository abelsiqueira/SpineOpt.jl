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

@doc raw"""
The number of online units needs to be restricted to the aggregated available units:

```math
v^{units\_on}_{(u,s,t)} \leq v^{units\_available}_{(u,s,t)} \quad \forall u \in unit, \, \forall (s,t)
```

The investment formulation is described in chapter [Investments](@ref).
"""
function add_constraint_units_on!(m::Model)
    @fetch units_on, units_available = m.ext[:spineopt].variables
    t0 = _analysis_time(m)
    m.ext[:spineopt].constraints[:units_on] = Dict(
        (unit=u, stochastic_scenario=s, t=t) => @constraint(
            m, 
            + units_on[u, s, t] 
            <= 
            + units_available[u, s, t]
        )
        for (u, s, t) in units_on_indices(m)
    )
end
