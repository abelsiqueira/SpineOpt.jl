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
    connections_invested_available_vintage_indices(connection=anything, t=anything)

A list of `NamedTuple`s corresponding to indices of the `connections_invested_available` variable where
the keyword arguments act as filters for each dimension.
"""
function connections_invested_available_vintage_indices(
    m::Model;
    connection=anything,
    stochastic_scenario=anything,
    t_vintage=anything,
    t=anything,
    temporal_block=anything,
)
    connection = members(connection)
    unique([
        (connection=c, stochastic_scenario=s, t_vintage=t_v, t=t)
        for (c, tb) in connection__investment_temporal_block(connection=connection, temporal_block=temporal_block, _compact=false)
        for (c, s, t_v) in connection_investment_stochastic_time_indices(
            m;
            connection=c,
            stochastic_scenario=stochastic_scenario,
            temporal_block=tb,
            t=t_vintage,
        )
        for (c, s, t) in connection_investment_stochastic_time_indices(
            m;
            connection=c,
            stochastic_scenario=stochastic_scenario,
            temporal_block=tb,
            t=t,
        )
        if t >= t_v
    ])
end

"""
    add_variable_connections_invested_available_vintage!(m::Model)

Add `connections_invested_available` variables to model `m`.
"""
function add_variable_connections_invested_available_vintage!(m::Model)
    t0 = _analysis_time(m)
    add_variable!(
        m,
        :connections_invested_available_vintage,
        connections_invested_available_vintage_indices;
        lb=x -> 0,
        fix_value=x -> fix_connections_invested_available_vintage(
            connection=x.connection,
            stochastic_scenario=x.stochastic_scenario,
            analysis_time=t0,
            t=x.t,
            _strict=false,
        ),
        vintage=true,
    )
end
