#############################################################################
# Copyright (C) 2017 - 2023  Spine Project
#
# This file is part of SpineOpt.
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
    units_invested_available_indices(unit=anything, t=anything)

A list of `NamedTuple`s corresponding to indices of the `units_invested_available` variable where
the keyword arguments act as filters for each dimension.
"""
function units_invested_available_indices(
    m::Model;
    unit=anything,
    stochastic_scenario=anything,
    t=anything,
    temporal_block=anything,
)
    unit = intersect(indices(candidate_units), members(unit))
    select(
        with_temporal_stochastic_indices(
            innerjoin(
                unit__investment_temporal_block(unit=unit, temporal_block=temporal_block, _compact=false),
                unit__investment_stochastic_structure(unit=unit, _compact=false);
                on=:unit
            );
            stochastic_scenario=stochastic_scenario,
            t=t,
            temporal_block=temporal_block,
        ),
        [:unit, :stochastic_scenario, :t];
        copycols=false,
    )
end

"""
    units_invested_available_int(x)

Check if unit investment variable type is defined to be an integer.
"""

units_invested_available_int(x) = unit_investment_variable_type(unit=x.unit) == :unit_investment_variable_type_integer

"""
    add_variable_units_invested_available!(m::Model)

Add `units_invested_available` variables to model `m`.
"""
function add_variable_units_invested_available!(m::Model)
    t0 = _analysis_time(m)
    add_variable!(
        m,
        :units_invested_available,
        units_invested_available_indices;
        lb=Constant(0),
        int=units_invested_available_int,
        replacement_value=units_on_replacement_value,
        fix_value=fix_units_invested_available,
        internal_fix_value=internal_fix_units_invested_available,
        initial_value=initial_units_invested_available
    )
end
