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

"""
    shut_down_costs(m::Model)

Shutdown cost term for units.
"""
function shut_down_costs(m::Model, t1)
    @fetch units_shut_down = m.ext[:variables]
    @expression(
        m,
        expr_sum(
            + units_shut_down[u, s, t]
            * shut_down_cost[(unit=u, stochastic_scenario=s, t=t)]
            * unit_stochastic_scenario_weight(unit=u, stochastic_scenario=s)
            for (u, s, t) in units_on_indices(unit=indices(shut_down_cost))
                if end_(t) <= t1;
            init=0
        )
    )
end
